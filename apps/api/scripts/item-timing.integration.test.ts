import test from 'node:test';
import assert from 'node:assert/strict';
import mysql,{type RowDataPacket} from 'mysql2/promise';
import dotenv from 'dotenv';
import {readFile} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import {once} from 'node:events';
import {createStaffApp} from '../src/staff-app.js';
import {createToken,hashPassword,type Role} from '../src/auth.js';
import {ensureItemTimingStorage,itemTiming,readItemTimings} from '../src/item-timing.js';
dotenv.config({path:new URL('../../../.env.mysql.local',import.meta.url),quiet:true});
dotenv.config({path:new URL('../../../.env',import.meta.url),quiet:true});

test('Thời gian món: migration không đoán dữ liệu cũ, chuyển bước nguyên tử, tính thời lượng và phân quyền',async()=>{
  const config={host:process.env.MYSQL_HOST,port:Number(process.env.MYSQL_PORT||3306),user:process.env.MYSQL_USER,password:process.env.MYSQL_PASSWORD};
  const admin=await mysql.createConnection(config);
  const name=`smartres_timing_test_${randomBytes(6).toString('hex')}`;
  await admin.query(`CREATE DATABASE \`${name}\` CHARACTER SET utf8mb4`);
  const db=mysql.createPool({...config,database:name,connectionLimit:5});
  let server:ReturnType<ReturnType<typeof createStaffApp>['listen']>|undefined;
  try {
    const schema=await readFile(new URL('../../../database/staff-schema.sql',import.meta.url),'utf8');
    for(const sql of schema.split(';').filter(s=>s.trim()))await db.query(sql);
    const roles:Role[]=['manager','staff','kitchen','cashier'];
    for(const [index,role] of roles.entries())await db.execute('INSERT INTO users(id,username,display_name,role,password_hash) VALUES(?,?,?,?,?)',[index+1,role,role,role,hashPassword('Test@123')]);
    await db.query("INSERT INTO restaurant_tables(id,code,name,area,status) VALUES(1,'A01','A01','Test','dining')");
    await db.query("INSERT INTO categories(id,name) VALUES(1,'Test')");
    await db.query("INSERT INTO menu_items(id,category_id,name,price) VALUES(1,1,'Cơm',45000)");
    await db.query("INSERT INTO orders(id,order_code,request_id,request_hash,table_id,total_amount) VALUES(1,'TIMING','TIMING',REPEAT('a',64),1,45000)");
    await db.query("INSERT INTO order_items(id,order_id,menu_item_id,item_name,quantity,unit_price,status,served_at) VALUES(1,1,1,'Món cũ',1,45000,'served','2026-01-01 10:00:00')");
    await db.query('ALTER TABLE order_items DROP INDEX idx_item_timing_created');
    await db.query('ALTER TABLE order_items DROP COLUMN created_at,DROP COLUMN cooking_started_at,DROP COLUMN completed_at');
    await ensureItemTimingStorage(db);await ensureItemTimingStorage(db);
    const [legacy]=await db.query<RowDataPacket[]>('SELECT created_at,cooking_started_at,completed_at,served_at FROM order_items WHERE id=1');
    assert.equal(legacy[0].created_at,null);assert.equal(legacy[0].cooking_started_at,null);assert.equal(legacy[0].completed_at,null);assert.ok(legacy[0].served_at);
    await db.query("INSERT INTO order_items(id,order_id,menu_item_id,item_name,quantity,unit_price) VALUES(2,1,1,'Món mới',2,45000)");
    const [fresh]=await db.query<RowDataPacket[]>('SELECT created_at FROM order_items WHERE id=2');assert.ok(fresh[0].created_at);
    server=createStaffApp(db).listen(0,'127.0.0.1');await once(server,'listening');
    const origin=`http://127.0.0.1:${(server.address() as {port:number}).port}/api/staff/`;
    const tokens=Object.fromEntries(roles.map((role,index)=>[role,createToken({id:index+1,username:role,displayName:role,role})]));
    const req=(path:string,role?:Role,body?:unknown)=>fetch(origin+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(role?{Authorization:`Bearer ${tokens[role]}`}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
    const route='management/item-timings';
    assert.equal((await req(route)).status,401);
    for(const role of ['staff','kitchen','cashier'] as Role[])assert.equal((await req(route,role)).status,403);
    assert.equal((await req('items/2/kitchen','kitchen',{status:'completed'})).status,409);
    const starts=await Promise.all([req('items/2/kitchen','kitchen',{status:'cooking'}),req('items/2/kitchen','kitchen',{status:'cooking'})]);
    assert.ok(starts.every(r=>r.status===200));
    const [started]=await db.query<RowDataPacket[]>('SELECT cooking_started_at FROM order_items WHERE id=2');assert.ok(started[0].cooking_started_at);
    await req('items/2/kitchen','kitchen',{status:'cooking'});
    const [repeated]=await db.query<RowDataPacket[]>('SELECT created_at,cooking_started_at FROM order_items WHERE id=2');
    assert.equal(repeated[0].cooking_started_at.getTime(),started[0].cooking_started_at.getTime());
    assert.equal(repeated[0].created_at.getTime(),fresh[0].created_at.getTime());
    assert.equal((await req('items/2/serve','staff',{})).status,409);
    assert.equal((await req('items/2/kitchen','kitchen',{status:'completed'})).status,200);
    const [done]=await db.query<RowDataPacket[]>('SELECT completed_at FROM order_items WHERE id=2');assert.ok(done[0].completed_at);
    await req('items/2/kitchen','kitchen',{status:'completed'});
    const [doneAgain]=await db.query<RowDataPacket[]>('SELECT completed_at FROM order_items WHERE id=2');
    assert.equal(done[0].completed_at.getTime(),doneAgain[0].completed_at.getTime());
    const serves=await Promise.all([req('items/2/serve','staff',{}),req('items/2/serve','staff',{})]);assert.ok(serves.every(r=>r.status===200));
    assert.equal((await req('items/2/kitchen','kitchen',{status:'cooking'})).status,409);
    const [clockRows]=await db.query<RowDataPacket[]>('SELECT UNIX_TIMESTAMP(NOW()) AS now');
    const today=new Date(Number(clockRows[0].now)*1000+7*3600000).toISOString().slice(0,10);
    const todayStart=Date.parse(`${today}T00:00:00+07:00`)/1000;
    const historyDate=new Date((todayStart-86400)*1000+7*3600000).toISOString().slice(0,10);
    const start=todayStart-86400+120;
    const report=(query='')=>`${route}?date=${historyDate}${query?'&'+query:''}`;
    await db.execute(`INSERT INTO order_items(id,order_id,menu_item_id,item_name,quantity,unit_price,status,created_at,cooking_started_at,completed_at,served_at)
      VALUES(3,1,1,'Món %_đặc biệt',3,45000,'served',FROM_UNIXTIME(?),FROM_UNIXTIME(?),FROM_UNIXTIME(?),FROM_UNIXTIME(?))`,[start,start+120,start+420,start+480]);
    await db.query("INSERT INTO order_items(id,order_id,menu_item_id,item_name,quantity,unit_price,status,created_at,cooking_started_at) VALUES(4,1,1,'Đang nấu',1,45000,'cooking',DATE_SUB(NOW(),INTERVAL 10 MINUTE),DATE_SUB(NOW(),INTERVAL 2 MINUTE))");
    await db.query("INSERT INTO order_items(id,order_id,menu_item_id,item_name,quantity,unit_price) VALUES(5,1,1,'Chờ bếp',1,45000)");
    // Same day's creation and serving order deliberately differ.
    await db.execute('UPDATE order_items SET created_at=FROM_UNIXTIME(?),cooking_started_at=FROM_UNIXTIME(?),completed_at=FROM_UNIXTIME(?),served_at=FROM_UNIXTIME(?) WHERE id=2',[start+300,start+310,start+350,start+400]);
    await db.execute('UPDATE order_items SET created_at=FROM_UNIXTIME(?),cooking_started_at=FROM_UNIXTIME(?) WHERE id=4',[start+1200,start+1260]);
    await db.execute('UPDATE order_items SET created_at=FROM_UNIXTIME(?) WHERE id=5',[start+1800]);
    await db.query("INSERT INTO orders(id,order_code,request_id,request_hash,table_id,total_amount,status) VALUES(2,'CANCELLED','CANCELLED',REPEAT('b',64),1,45000,'cancelled')");
    await db.query("INSERT INTO order_items(order_id,menu_item_id,item_name,quantity,unit_price) VALUES(2,1,'Món hủy',1,45000)");
    // Older dishes have larger IDs: ordering must use creation time, then ID for ties.
    await db.execute("INSERT INTO order_items(id,order_id,menu_item_id,item_name,quantity,unit_price,status,created_at,completed_at) VALUES(7,1,1,'Chờ bưng lâu',1,45000,'completed',FROM_UNIXTIME(?),FROM_UNIXTIME(?))",[start-60,start-1]);
    await db.execute("INSERT INTO order_items(id,order_id,menu_item_id,item_name,quantity,unit_price,status,created_at) VALUES(8,1,1,'Chờ bếp lâu',1,45000,'preparing',FROM_UNIXTIME(?))",[start-60]);
    await db.query("UPDATE orders SET payment_status='paid' WHERE id=1");
    await db.query("INSERT INTO order_items(id,order_id,menu_item_id,item_name,quantity,unit_price,status,served_at) VALUES(9,1,1,'Món hôm nay',1,45000,'served',NOW())");
    const current=(await (await req(route,'manager')).json());
    assert.equal(current.date,today);assert.equal(current.total,1);assert.equal(current.items[0].id,9);
    const response=await req(report(),'manager');assert.equal(response.status,200);assert.equal(response.headers.get('cache-control'),'no-store');
    const data=await response.json();assert.equal(data.total,6);assert.equal(data.counts.served,2);assert.equal(data.counts.cooking,1);assert.equal(data.counts.preparing,2);assert.equal(data.counts.completed,1);
    assert.deepEqual(data.items.slice(0,3).map((item:{id:number})=>item.id),[7,8,3]);
    const pending=(await (await req(report('status=pending'),'manager')).json());
    assert.equal(pending.total,4);
    assert.ok(pending.items.every((item:{status:string})=>['preparing','cooking','completed'].includes(item.status)));
    assert.deepEqual(pending.items.slice(0,2).map((item:{id:number})=>item.id),[7,8]);
    const pendingPage=(await (await req(report('status=pending&limit=1&offset=1'),'manager')).json());
    assert.equal(pendingPage.total,4);assert.equal(pendingPage.items[0].id,8);
    const historical=data.items.find((item:{id:number})=>item.id===3);
    assert.deepEqual(historical.durations,{waitingKitchenSeconds:120,cookingSeconds:300,waitingServiceSeconds:60,totalSeconds:480});
    assert.equal(historical.createdAt,new Date(start*1000).toISOString());
    assert.equal(historical.paymentStatus,'paid');
    assert.ok(!data.items.some((item:{id:number})=>item.id===1)); // Missing creation date is never assigned to an arbitrary day.
    const live=data.items.find((item:{id:number})=>item.id===4);
    assert.equal(live.durations.cookingSeconds,null);
    assert.equal(live.currentStageElapsedSeconds,(Date.parse(data.generatedAt)-Date.parse(live.cookingStartedAt))/1000);
    const served=(await (await req(report('status=served'),'manager')).json());
    assert.deepEqual(served.items.map((item:{id:number})=>item.id),[3,2]);
    assert.equal((await (await req(report('status=served&limit=1&offset=1'),'manager')).json()).items[0].id,2);
    const timezoneDb=mysql.createPool({...config,database:name,connectionLimit:1});
    try {
      for(const timezone of ['+00:00','+07:00']) {
        await timezoneDb.query('SET time_zone=?',[timezone]);
        const localReport=await readItemTimings(timezoneDb,{date:historyDate});
        assert.equal(localReport.total,6);
        const localItem=localReport.items.find(item=>item.id===3)!;
        assert.deepEqual(localItem.durations,historical.durations);
        assert.equal(localItem.createdAt,historical.createdAt);
        const localToday=await readItemTimings(timezoneDb,{});
        assert.equal(localToday.date,today);assert.equal(localToday.total,1);assert.equal(localToday.items[0].id,9);
      }
    } finally {await timezoneDb.end();}
    assert.equal((await (await req(report('q=%25_'),'manager')).json()).total,1);
    assert.equal((await (await req(report('status=cooking'),'manager')).json()).total,1);
    assert.equal((await (await req(report('limit=1&offset=1'),'manager')).json()).items[0].id,8);
    await db.execute("INSERT INTO order_items(id,order_id,menu_item_id,item_name,quantity,unit_price,created_at) VALUES(10,1,1,'boundary hôm nay',1,45000,FROM_UNIXTIME(?)),(11,1,1,'boundary hôm qua',1,45000,FROM_UNIXTIME(?))",[todayStart,todayStart-1]);
    const boundaryToday=(await (await req(route+'?q=boundary','manager')).json());
    assert.equal(boundaryToday.total,1);assert.equal(boundaryToday.items[0].id,10);
    const boundaryHistory=(await (await req(report('q=boundary'),'manager')).json());
    assert.equal(boundaryHistory.total,1);assert.equal(boundaryHistory.items[0].id,11);
    for(const query of ['?status=ready','?date=2026-02-30','?limit=0','?offset=-1'])assert.equal((await req(route+query,'manager')).status,400);
    const invalid=itemTiming({status:'served',createdEpoch:200,cookingEpoch:100,completedEpoch:null,servedEpoch:50} as RowDataPacket,300);
    assert.equal(invalid.durations.waitingKitchenSeconds,null);assert.equal(invalid.durations.totalSeconds,null);
  } finally {
    if(server)await new Promise<void>(resolve=>server!.close(()=>resolve()));
    await db.end();await admin.query(`DROP DATABASE \`${name}\``);await admin.end();
  }
});
