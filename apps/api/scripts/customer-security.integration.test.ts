import test from 'node:test';
import assert from 'node:assert/strict';
import mysql, {type RowDataPacket} from 'mysql2/promise';
import {randomBytes} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {once} from 'node:events';
import type {Server} from 'node:http';
import {createStaffApp} from '../src/staff-app.js';
import {createApp} from '../src/app.js';
import {createToken} from '../src/auth.js';
import {ensureInvoiceStorage} from '../src/invoice-storage.js';
import {ensureCustomerSessions,hashCustomerToken} from '../src/customer-sessions.js';

test('Quét QR tự cấp phiên: bàn trống, sai bàn, hết hạn, thanh toán và mở lượt mới',async()=>{
  const config={host:process.env.MYSQL_HOST,port:Number(process.env.MYSQL_PORT||3306),user:process.env.MYSQL_USER,password:process.env.MYSQL_PASSWORD};
  const admin=await mysql.createConnection(config);
  const name=`smartres_security_test_${randomBytes(6).toString('hex')}`;
  await admin.query(`CREATE DATABASE \`${name}\` CHARACTER SET utf8mb4`);
  const db=mysql.createPool({...config,database:name,connectionLimit:8});
  const servers: Server[]=[];
  try {
    const schema=await readFile(new URL('../../../database/staff-schema.sql',import.meta.url),'utf8');
    for(const sql of schema.split(';').filter(s=>s.trim())) await db.query(sql);
    await ensureInvoiceStorage(db);
    await ensureCustomerSessions(db);
    await ensureCustomerSessions(db); // migration chạy lại không mất dữ liệu
    await db.query("INSERT INTO restaurant_tables(id,code,name,area) VALUES(1,'A01','A01','Test'),(2,'A02','A02','Test')");
    await db.query("INSERT INTO categories(id,name) VALUES(1,'Test')");
    await db.query("INSERT INTO menu_items(id,category_id,name,price) VALUES(1,1,'Cơm',45000)");
    async function start(app:ReturnType<typeof createStaffApp>) {
      const server=app.listen(0,'127.0.0.1');
      servers.push(server);await once(server,'listening');
      return `http://127.0.0.1:${(server.address() as {port:number}).port}`;
    }
    const staff=await start(createStaffApp(db));
    let customer=await start(createApp(db).app);
    const userToken=createToken({id:1,username:'staff-test',displayName:'Staff test',role:'staff'});
    const kitchenToken=createToken({id:2,username:'kitchen-test',displayName:'Kitchen test',role:'kitchen'});
    async function request(base:string,path:string,body?:unknown,token?:string,method?:string) {
      return fetch(base+path,{method:method || (body===undefined?'GET':'POST'),headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
    }
    const staffPost=(path:string,body:unknown={})=>request(staff,'/api/staff/'+path,body,userToken);
    const join=(tableCode='A01')=>request(customer,'/api/customer-sessions/join',{tableCode});
    const orderBody={tableCode:'A01',items:[{menuItemId:1,quantity:1}]};
    const order=(token?:string,body=orderBody)=>request(customer,'/api/orders',body,token);
    assert.equal((await join()).status,403);
    assert.equal((await order()).status,400); // bàn trống không được tự nhận bàn
    const seat=await staffPost('tables/1/seat',{guests:2});
    assert.equal(seat.status,200);
    const session=(await seat.json()).customerSession;
    assert.equal(session.joinCode,undefined);
    assert.ok(session.sessionId);
    assert.equal((await order()).status,401);
    assert.equal((await order('a'.repeat(64))).status,401);
    assert.equal((await request(staff,'/api/staff/tables/1/seat',{guests:1},kitchenToken)).status,403);
    const joined=await join();
    assert.equal(joined.status,200);
    const {token}=await joined.json();
    const [stored]=await db.query<RowDataPacket[]>('SELECT token_hash FROM customer_session_tokens');
    assert.equal(stored[0].token_hash,hashCustomerToken(token));
    assert.notEqual(stored[0].token_hash,token);
    await staffPost('tables/2/seat',{guests:1});
    assert.equal((await order(token,{...orderBody,tableCode:'A02'})).status,401);
    assert.equal((await request(customer,'/api/orders/1/status',{status:'cancelled'},token,'PATCH')).status,404);
    assert.equal((await request(customer,'/api/payments/sepay/webhook',{referenceCode:'SR-test'},token)).status,404);
    assert.equal((await order(token,{...orderBody,items:[{menuItemId:1,quantity:100}]})).status,400);
    const firstOrder=await order(token);
    assert.equal(firstOrder.status,201);
    const firstCode=(await firstOrder.json()).order.orderCode;
    // Hai khách quét cùng QR, mỗi điện thoại nhận token riêng của cùng lượt.
    const nextToken=(await (await join()).json()).token;
    assert.notEqual(nextToken,token);
    assert.equal((await request(customer,`/api/orders/${firstCode}/request-payment`,{},nextToken)).status,200);
    assert.equal((await order(nextToken)).status,400); // chờ thanh toán không nhận thêm món
    await db.query("UPDATE order_items SET status='served',served_at=NOW()");
    assert.equal((await staffPost('tables/1/pay',{paymentMethod:'cash'})).status,200);
    assert.equal((await join()).status,403);
    assert.equal((await request(customer,'/api/customer-sessions/check/A01',undefined,nextToken)).status,401);
    // Lượt khách mới không thể dùng lại token hoặc đơn của lượt trước.
    await staffPost('tables/1/seat',{guests:1});
    assert.equal((await order(nextToken)).status,401);
    const thirdToken=(await (await join()).json()).token;
    assert.equal((await request(customer,`/api/orders/${firstCode}/request-payment`,{},thirdToken)).status,400);
    // Phiên được lưu DB, vẫn có hiệu lực khi API khởi động lại.
    customer=await start(createApp(db).app);
    assert.equal((await request(customer,'/api/customer-sessions/check/A01',undefined,thirdToken)).status,200);
    for(let i=0;i<10;i++) assert.equal((await order(thirdToken)).status,201);
    assert.equal((await order(thirdToken)).status,429);
    await db.query('UPDATE dining_sessions SET expires_at=DATE_SUB(NOW(),INTERVAL 1 SECOND) WHERE table_id=1 AND revoked_at IS NULL');
    assert.equal((await order(thirdToken)).status,401);
    // Quét lại khi bàn vẫn phục vụ: tự cấp phiên, không yêu cầu mã.
    const renewedResponse=await join();
    assert.equal(renewedResponse.status,200);
    const renewedToken=(await renewedResponse.json()).token;
    assert.equal((await order(thirdToken)).status,401);
    await db.query('UPDATE orders SET created_at=DATE_SUB(NOW(),INTERVAL 2 MINUTE)');
    const race=await Promise.all([order(renewedToken),staffPost('tables/1/pay',{paymentMethod:'cash',confirmUnserved:true})]);
    assert.ok([201,400].includes(race[0].status));
    assert.equal(race[1].status,200);
    const [unpaid]=await db.query<RowDataPacket[]>("SELECT COUNT(*) AS total FROM orders WHERE table_id=1 AND payment_status='unpaid'");
    assert.equal(Number(unpaid[0].total),0);
    const [tables]=await db.query<RowDataPacket[]>('SELECT status FROM restaurant_tables WHERE id=2');
    assert.equal(tables[0].status,'dining');
  } finally {
    for(const server of servers) await new Promise<void>(resolve=>server.close(()=>resolve()));
    await db.end();
    await admin.query(`DROP DATABASE \`${name}\``);
    await admin.end();
  }
});
