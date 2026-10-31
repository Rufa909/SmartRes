import test from 'node:test';
import assert from 'node:assert/strict';
import mysql from 'mysql2/promise';
import {readFile} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import {once} from 'node:events';
import {createStaffApp} from '../src/staff-app.js';
import {createToken,type Role} from '../src/auth.js';
import {ensureInvoiceStorage} from '../src/invoice-storage.js';
import {overviewPeriod} from '../src/management-overview.js';
import dotenv from 'dotenv';
dotenv.config({path:new URL('../../../.env.mysql.local',import.meta.url),quiet:true});
dotenv.config({path:new URL('../../../.env',import.meta.url),quiet:true});

test('Khoảng ngày theo giờ Việt Nam và kiểm tra ngày nhuận/khoảng tối đa',()=>{
  assert.deepEqual(overviewPeriod({from:'2026-10-31',to:'2026-10-31'}),{
    from:'2026-10-31',to:'2026-10-31',start:Date.parse('2026-10-30T17:00:00Z')/1000,end:Date.parse('2026-10-31T17:00:00Z')/1000,days:1,
  });
  assert.equal(overviewPeriod({from:'2024-02-29',to:'2024-02-29'}).days,1);
  assert.throws(()=>overviewPeriod({from:'2026-02-29',to:'2026-02-29'}));
  assert.throws(()=>overviewPeriod({from:'2026-11-01',to:'2026-10-31'}));
  assert.throws(()=>overviewPeriod({from:'2025-01-01',to:'2026-01-02'}));
  const fallback=overviewPeriod({},Date.parse('2026-10-30T18:00:00Z'));
  assert.equal(fallback.to,'2026-10-31');assert.equal(fallback.from,'2026-10-25');
});

test('Tổng quan: doanh thu sau giảm giá, không đếm trùng, biên ngày, phương thức và quyền manager',async()=>{
  const config={host:process.env.MYSQL_HOST,port:Number(process.env.MYSQL_PORT||3306),user:process.env.MYSQL_USER,password:process.env.MYSQL_PASSWORD};
  const admin=await mysql.createConnection(config);
  const name=`smartres_overview_test_${randomBytes(6).toString('hex')}`;
  await admin.query(`CREATE DATABASE \`${name}\` CHARACTER SET utf8mb4`);
  const db=mysql.createPool({...config,database:name,connectionLimit:1});
  let server:ReturnType<ReturnType<typeof createStaffApp>['listen']>|undefined;
  try {
    const schema=await readFile(new URL('../../../database/staff-schema.sql',import.meta.url),'utf8');
    for(const sql of schema.split(';').filter(s=>s.trim()))await db.query(sql);
    await ensureInvoiceStorage(db);
    // Chứng minh báo cáo không phụ thuộc MySQL đang cấu hình UTC hay UTC+7.
    await db.query("SET time_zone='+00:00'");
    await db.query("INSERT INTO restaurant_tables(id,code,name,area,status,guests) VALUES(1,'A01','A01','Test','available',0),(2,'A02','A02','Test','dining',3),(3,'A03','A03','Test','waiting_payment',2),(4,'A04','A04','Test','disabled',0)");
    await db.query("INSERT INTO categories(id,name) VALUES(1,'Test')");
    await db.query("INSERT INTO menu_items(id,category_id,name,price,is_available) VALUES(1,1,'Tên món đã đổi',999000,1),(2,1,'Trà',10000,0)");
    const line=(id:number,name:string,quantity:number,unitPrice:number)=>({menuItemId:id,name,quantity,unitPrice,lineTotal:quantity*unitPrice});
    let seq=0;
    async function receipt(iso:string,total:number,discount:number,method:string,items:unknown[]){
      seq++;
      await db.execute(`INSERT INTO cashier_invoices(invoice_code,table_id,table_code,total_amount,payment_method,paid_at,cashier_name,snapshot)
        VALUES(?,1,'A01',?,?,FROM_UNIXTIME(?),'Thu ngân test',?)`,[`REPORT-${seq}`,total,method,Date.parse(iso)/1000,JSON.stringify({discountAmount:discount,items})]);
    }
    await receipt('2026-10-27T16:59:59Z',999999,0,'cash',[]); // Ngoài kỳ trước.
    await receipt('2026-10-27T17:00:00Z',80000,0,'cash',[]); // Kỳ trước: 28/10 00h.
    await receipt('2026-10-30T17:00:00Z',90000,10000,'cash',[line(1,'Cơm lịch sử',1,50000),line(1,'Cơm lịch sử',1,50000)]);
    await receipt('2026-10-31T16:59:59Z',50000,0,'bank_transfer',[line(1,'Cơm lịch sử',1,50000)]);
    await receipt('2026-10-31T17:00:00Z',20000,0,'card',[line(2,'Trà',2,10000)]);
    await receipt('2026-11-02T16:59:59Z',0,30000,'cash',[line(3,'Món tặng',1,30000)]);
    await receipt('2026-11-02T17:00:00Z',777777,0,'cash',[]); // Không lẫn sang 03/11.
    await db.query(`INSERT INTO orders(id,order_code,request_id,request_hash,table_id,total_amount,status,payment_status) VALUES
      (1,'UNPAID-1','UNPAID-1',REPEAT('0',64),2,77777,'new','unpaid'),
      (2,'UNPAID-2','UNPAID-2',REPEAT('0',64),3,22223,'new','unpaid'),
      (3,'CANCELLED','CANCELLED',REPEAT('0',64),3,99999,'cancelled','unpaid'),
      (4,'PAID','PAID',REPEAT('0',64),1,123456,'completed','paid')`);
    await db.query(`INSERT INTO order_items(order_id,menu_item_id,item_name,quantity,unit_price,status) VALUES
      (1,1,'Cơm',2,10000,'preparing'),(1,1,'Cơm',3,10000,'cooking'),(2,1,'Cơm',1,10000,'completed'),
      (2,1,'Cơm',5,10000,'served'),(3,1,'Hủy',99,10000,'preparing'),(4,1,'Đã trả',99,10000,'preparing')`);
    server=createStaffApp(db).listen(0,'127.0.0.1');await once(server,'listening');
    const root=`http://127.0.0.1:${(server.address() as {port:number}).port}/api/staff/management/overview`;
    const token=(role:Role)=>createToken({id:1,username:role,displayName:role,role});
    const get=(query:string,role:Role='manager')=>fetch(root+query,{headers:{Authorization:`Bearer ${token(role)}`}});
    assert.equal((await fetch(root)).status,401);
    for(const role of ['staff','kitchen','cashier'] as Role[])assert.equal((await get('',role)).status,403);
    for(const query of ['?from=2026-02-30&to=2026-03-01','?from=2026-11-01&to=2026-10-01','?from=2025-01-01&to=2026-12-31','?from[]=2026-10-31'])assert.equal((await get(query)).status,400);
    const response=await get('?from=2026-10-31&to=2026-11-02');
    assert.equal(response.status,200);assert.equal(response.headers.get('cache-control'),'no-store');
    const report=await response.json();
    assert.equal(report.summary.revenue,160000); // Không nhân tiền theo 2 dòng món của receipt.
    assert.equal(report.summary.invoiceCount,4);assert.equal(report.summary.averageBill,40000);
    assert.equal(report.summary.discountAmount,40000);assert.equal(report.summary.previousRevenue,80000);
    assert.equal(report.summary.changePercent,100);
    assert.deepEqual(report.daily,[{date:'2026-10-31',revenue:140000,invoiceCount:2},{date:'2026-11-01',revenue:20000,invoiceCount:1},{date:'2026-11-02',revenue:0,invoiceCount:1}]);
    assert.equal(report.topItems[0].name,'Cơm lịch sử');assert.equal(report.topItems[0].quantity,3);assert.equal(report.topItems[0].grossAmount,150000);
    assert.equal(report.paymentMethods.find((p:{method:string})=>p.method==='cash').revenue,90000);
    assert.equal(report.recentInvoices.length,4);assert.equal(report.recentInvoices[0].totalAmount,0);
    assert.equal(report.operations.totalTables,3);assert.equal(report.operations.availableTables,1);
    assert.equal(report.operations.diningTables,1);assert.equal(report.operations.waitingPaymentTables,1);
    assert.equal(report.operations.guests,5);assert.equal(report.operations.unpaidAmount,100000);
    assert.equal(report.operations.pendingKitchen,5);assert.equal(report.operations.readyToServe,1);assert.equal(report.operations.outOfStock,1);
    const empty=await (await get('?from=2025-01-01&to=2025-01-03')).json();
    assert.equal(empty.summary.revenue,0);assert.equal(empty.summary.averageBill,0);assert.equal(empty.summary.changePercent,null);
    assert.equal(empty.daily.length,3);assert.ok(empty.daily.every((d:{revenue:number})=>d.revenue===0));assert.deepEqual(empty.topItems,[]);
    const boundary=await (await get('?from=2026-10-31&to=2026-10-31')).json();
    assert.equal(boundary.summary.revenue,140000);assert.equal(boundary.summary.invoiceCount,2);
    await db.query("SET time_zone='+07:00'");
    const local=await (await get('?from=2026-10-31&to=2026-11-02')).json();
    assert.deepEqual(local.summary,report.summary);assert.deepEqual(local.daily,report.daily);
  } finally {
    if(server)await new Promise<void>(resolve=>server!.close(()=>resolve()));
    await db.end();await admin.query(`DROP DATABASE \`${name}\``);await admin.end();
  }
});
