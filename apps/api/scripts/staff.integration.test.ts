import test from 'node:test';
import assert from 'node:assert/strict';
import mysql, {type RowDataPacket} from 'mysql2/promise';
import dotenv from 'dotenv';
import {readFile} from 'node:fs/promises';
import {randomBytes,randomUUID} from 'node:crypto';
import {once} from 'node:events';
import {createStaffApp} from '../src/staff-app.js';
dotenv.config({path:new URL('../../../.env.mysql.local',import.meta.url),quiet:true});

test('MySQL: nhận bàn, giá server, chống trùng, phục vụ và dữ liệu sau restart',async()=>{
  const config={host:process.env.MYSQL_HOST,port:Number(process.env.MYSQL_PORT||3306),user:process.env.MYSQL_USER,password:process.env.MYSQL_PASSWORD};
  const admin=await mysql.createConnection(config);
  const name=`smartres_staff_test_${randomBytes(6).toString('hex')}`;
  await admin.query(`CREATE DATABASE \`${name}\` CHARACTER SET utf8mb4`);
  const db=mysql.createPool({...config,database:name,connectionLimit:5});
  let server:ReturnType<ReturnType<typeof createStaffApp>['listen']>|undefined;
  try {
    const schema=await readFile(new URL('../../../database/staff-schema.sql',import.meta.url),'utf8');
    for(const sql of schema.split(';').filter(s=>s.trim())) await db.query(sql);
    await db.query("INSERT INTO restaurant_tables(id,code,name,area) VALUES (1,'TEST','Bàn kiểm thử','Test')");
    await db.query("INSERT INTO categories(id,name) VALUES (1,'Test')");
    await db.query("INSERT INTO menu_items(id,category_id,name,price,is_available) VALUES (1,1,'Cơm',45000,1),(2,1,'Trà',25000,1),(3,1,'Hết món',10000,0)");
    async function start(){server=createStaffApp(db).listen(0,'127.0.0.1');await once(server,'listening');return `http://127.0.0.1:${(server.address() as {port:number}).port}/api/staff`;}
    async function stop(){if(server)await new Promise<void>((resolve,reject)=>server!.close(e=>e?reject(e):resolve()));}
    let base=await start();
    const post=(path:string,body:unknown)=>fetch(`${base}/${path}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
    assert.equal((await post('tables/1/seat',{guests:5})).status,409);
    assert.equal((await post('tables/1/seat',{guests:2})).status,200);
    assert.equal((await post('tables/1/seat',{guests:2})).status,409);
    const requestId=randomUUID();
    const body={tableId:1,requestId,items:[{menuItemId:1,quantity:2,unitPrice:1},{menuItemId:2,quantity:1}]};
    const results=await Promise.all([post('orders',body),post('orders',body)]);
    const orders=await Promise.all(results.map(r=>r.json()));
    assert.equal(orders[0].orderCode,orders[1].orderCode);
    assert.equal(orders[0].totalAmount,115000);
    assert.equal((await post('orders',{...body,items:[{menuItemId:1,quantity:3}]})).status,409);
    assert.equal((await post('orders',{...body,requestId:randomUUID(),items:[{menuItemId:3,quantity:1}]})).status,409);
    assert.equal((await post('orders',{...body,requestId:randomUUID(),items:[{menuItemId:1,quantity:0}]})).status,400);
    const [rows]=await db.query<RowDataPacket[]>('SELECT id FROM order_items ORDER BY id');
    const itemId=rows[0].id;
    assert.equal((await post(`items/${itemId}/serve`,{})).status,409);
    assert.equal((await post(`items/${itemId}/kitchen`,{status:'completed'})).status,409);
    assert.equal((await post(`items/${itemId}/kitchen`,{status:'served'})).status,400);
    const kitchenStarts=await Promise.all([
      post(`items/${itemId}/kitchen`,{status:'cooking'}),post(`items/${itemId}/kitchen`,{status:'cooking'})]);
    assert.ok(kitchenStarts.every(r=>r.status===200));
    assert.equal((await post(`items/${itemId}/kitchen`,{status:'completed'})).status,200);
    assert.equal((await post(`items/${itemId}/kitchen`,{status:'completed'})).status,200);
    assert.equal((await post(`items/${itemId}/kitchen`,{status:'cooking'})).status,409);
    const kitchenState=await (await fetch(`${base}/snapshot`)).json();
    assert.equal(kitchenState.items.find((i:{id:number})=>i.id===itemId).status,'completed');
    assert.equal((await post(`items/${itemId}/serve`,{})).status,200);
    assert.equal((await post(`items/${itemId}/kitchen`,{status:'completed'})).status,409);
    assert.equal((await post(`items/${itemId}/serve`,{})).status,200);
    await stop();base=await start();
    const state=await (await fetch(`${base}/snapshot`)).json();
    assert.equal(state.tables[0].guests,2);
    assert.equal(state.items.length,2);
    assert.equal(state.items.find((i:{id:number})=>i.id===itemId).status,'served');
    assert.equal((await post('tables/1/request-payment',{})).status,200);
    assert.equal((await post('orders',{...body,requestId:randomUUID()})).status,409);
    await stop();server=undefined;
  }finally{
    if(server)await new Promise<void>(r=>server!.close(()=>r()));
    await db.end();
    // Chỉ xóa database kiểm thử ngẫu nhiên đã tạo thành công trong lượt này.
    await admin.query(`DROP DATABASE \`${name}\``);
    await admin.end();
  }
});
