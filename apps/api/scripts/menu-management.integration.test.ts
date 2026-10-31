import test from 'node:test';
import assert from 'node:assert/strict';
import mysql,{type RowDataPacket} from 'mysql2/promise';
import {readFile} from 'node:fs/promises';
import {randomBytes,randomUUID} from 'node:crypto';
import {once} from 'node:events';
import type {Server} from 'node:http';
import {createStaffApp} from '../src/staff-app.js';
import {createApp} from '../src/app.js';
import {createToken,hashPassword,type Role} from '../src/auth.js';
import {ensureMenuStorage} from '../src/menu-storage.js';
import {ensureCustomerSessions,joinDiningSession} from '../src/customer-sessions.js';
import {ensureInvoiceStorage} from '../src/invoice-storage.js';

test('Quản lý thực đơn: phân quyền, migration, danh mục, món/ảnh, hết món, giá và lịch sử',async()=>{
  const config={host:process.env.MYSQL_HOST,port:Number(process.env.MYSQL_PORT||3306),user:process.env.MYSQL_USER,password:process.env.MYSQL_PASSWORD};
  const admin=await mysql.createConnection(config);
  const name=`smartres_menu_test_${randomBytes(6).toString('hex')}`;
  await admin.query(`CREATE DATABASE \`${name}\` CHARACTER SET utf8mb4`);
  const db=mysql.createPool({...config,database:name,connectionLimit:6});
  const servers:Server[]=[];
  try {
    const schema=await readFile(new URL('../../../database/staff-schema.sql',import.meta.url),'utf8');
    for(const sql of schema.split(';').filter(s=>s.trim()))await db.query(sql);
    await db.query('ALTER TABLE menu_items DROP COLUMN image_url,DROP COLUMN version');
    await db.query('ALTER TABLE categories DROP COLUMN version');
    await ensureMenuStorage(db);await ensureMenuStorage(db);
    await ensureCustomerSessions(db);await ensureInvoiceStorage(db);
    await db.execute('INSERT INTO users(username,display_name,role,password_hash) VALUES(?,?,?,?)',['manager_test','Quản lý test','manager',hashPassword('ManagerTest@123')]);
    await db.query("INSERT INTO restaurant_tables(id,code,name,area) VALUES(1,'TEST','TEST','Test')");
    async function start(app:ReturnType<typeof createStaffApp>){const server=app.listen(0,'127.0.0.1');servers.push(server);await once(server,'listening');return `http://127.0.0.1:${(server.address() as {port:number}).port}`;}
    const staff=await start(createStaffApp(db));
    const customer=await start(createApp(db).app);
    async function req(path:string,body?:unknown,token?:string){return fetch(staff+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});}
    const login=await req('/api/auth/login',{username:'manager_test',password:'ManagerTest@123'});
    assert.equal(login.status,200);
    const auth=await login.json();assert.equal(auth.user.role,'manager');
    const token=auth.token as string;
    const base='/api/staff/management';
    const paths=[['/menu',undefined],['/menu',{}],['/menu/1',{}],['/menu/1/availability',{}],['/categories',{}],['/categories/1',{}]] as const;
    for(const [path,body] of paths){
      assert.equal((await req(base+path,body)).status,401);
      for(const role of ['staff','kitchen','cashier'] as Role[]){
        const other=createToken({id:10,username:role,displayName:role,role});
        assert.equal((await req(base+path,body,other)).status,403);
      }
    }
    assert.equal((await fetch(customer+'/api/staff/management/menu')).status,404);
    const createCategory=await req(base+'/categories',{name:'Món mới',sortOrder:2},token);
    assert.equal(createCategory.status,201);
    let category=(await createCategory.json()).category;
    assert.equal((await req(base+'/categories',{name:'Món mới',sortOrder:3},token)).status,409);
    const originalCategory=category;
    category=(await (await req(base+`/categories/${category.id}`,{name:'Đặc sản',sortOrder:1,version:category.version},token)).json()).category;
    assert.equal((await req(base+`/categories/${category.id}`,{...originalCategory,sortOrder:2},token)).status,409);
    const input={name:'Cơm mới',categoryId:Number(category.id),price:45000,description:'Cơm nhà nấu',emoji:'🍚',imageUrl:'https://example.com/com.jpg',available:true};
    for(const invalid of [{...input,price:-1},{...input,price:1.5},{...input,name:' '},{...input,imageUrl:'javascript:alert(1)'},{...input,imageUrl:'https://user:pass@example.com/a.jpg'}])assert.equal((await req(base+'/menu',invalid,token)).status,400);
    assert.equal((await req(base+'/menu',{...input,categoryId:999},token)).status,400);
    const created=await req(base+'/menu',input,token);
    assert.equal(created.status,201);
    let item=(await created.json()).item;
    assert.equal(item.price,45000);assert.equal(item.imageUrl,input.imageUrl);assert.equal(item.version,1);
    assert.equal((await req(base+'/menu',input,token)).status,409);
    const publicMenu=()=>fetch(customer+'/api/menu').then(r=>r.json());
    assert.equal((await publicMenu()).items[0].category,'Đặc sản');
    assert.equal((await publicMenu()).items[0].imageUrl,input.imageUrl);
    const headers={'Content-Type':'application/json',Authorization:`Bearer ${token}`};
    assert.equal((await req('/api/staff/tables/1/seat',{guests:2},token)).status,200);
    const staffOrder=await req('/api/staff/orders',{tableId:1,requestId:randomUUID(),items:[{menuItemId:item.id,quantity:2}]},token);
    assert.equal(staffOrder.status,201);
    const customerToken=(await joinDiningSession(db,'TEST')).token;
    const customerOrder=()=>fetch(customer+'/api/orders',{method:'POST',headers:{...headers,Authorization:`Bearer ${customerToken}`},body:JSON.stringify({tableCode:'TEST',items:[{menuItemId:item.id,quantity:1}]})});
    const original=item;
    item=(await (await req(base+`/menu/${item.id}`,{...input,name:'Cơm đặc sản',price:55000,version:item.version},token)).json()).item;
    assert.equal(item.version,2);
    assert.equal((await req(base+`/menu/${item.id}`,{...input,version:original.version},token)).status,409);
    const newer=await customerOrder();assert.equal(newer.status,201);
    assert.equal((await newer.json()).order.totalAmount,55000);
    const [oldPrices]=await db.query<RowDataPacket[]>('SELECT item_name,unit_price FROM order_items ORDER BY id');
    assert.equal(oldPrices[0].item_name,'Cơm mới');assert.equal(Number(oldPrices[0].unit_price),45000);
    assert.equal(Number(oldPrices[1].unit_price),55000);
    // Hai thiết bị cùng sửa version: chỉ một yêu cầu thành công.
    const concurrent=await Promise.all([
      req(base+`/menu/${item.id}/availability`,{available:false,version:item.version},token),
      req(base+`/menu/${item.id}/availability`,{available:false,version:item.version},token),
    ]);
    assert.deepEqual(concurrent.map(r=>r.status).sort(),[200,409]);
    assert.equal((await publicMenu()).items.length,0);
    assert.equal((await customerOrder()).status,400);
    assert.equal((await req('/api/staff/orders',{tableId:1,requestId:randomUUID(),items:[{menuItemId:item.id,quantity:1}]},token)).status,409);
    const managed=await (await req(base+'/menu',undefined,token)).json();
    item=managed.items[0];assert.equal(item.available,false);
    const snapshot=await (await req('/api/staff/snapshot',undefined,token)).json();
    assert.equal(snapshot.menu[0].available,false);assert.equal(snapshot.menu[0].imageUrl,input.imageUrl);
    item=(await (await req(base+`/menu/${item.id}/availability`,{available:true,version:item.version},token)).json()).item;
    assert.equal((await publicMenu()).items.length,1);
    const [audits]=await db.query<RowDataPacket[]>('SELECT actor_name,action,before_data,after_data FROM menu_audit ORDER BY id');
    assert.equal(audits.length,6); // category create/update; item create/update; off/on
    assert.equal(audits[0].actor_name,'Quản lý test');
    assert.equal(audits[3].action,'menu.update');
    const c=await db.getConnection();await c.query('SELECT 1');c.release();
    const restarted=await start(createStaffApp(db));
    const durable=await fetch(restarted+base+'/menu',{headers});
    assert.equal((await durable.json()).items[0].price,55000);
  } finally {
    for(const server of servers)await new Promise<void>(resolve=>server.close(()=>resolve()));
    await db.end();await admin.query(`DROP DATABASE \`${name}\``);await admin.end();
  }
});
