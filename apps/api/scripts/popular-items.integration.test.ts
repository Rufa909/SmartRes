import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { once } from 'node:events';
import { readFile } from 'node:fs/promises';
import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
import { createApp } from '../src/app.js';
import { ensureInvoiceStorage } from '../src/invoice-storage.js';
import { readPopularItems } from '../src/popular-items.js';

dotenv.config({path:new URL('../../../.env.mysql.local',import.meta.url),quiet:true});
dotenv.config({path:new URL('../../../.env',import.meta.url),quiet:true});

test('Món bán chạy chỉ tính hóa đơn đã thanh toán trong 30 ngày và món còn bán', async () => {
  const config={host:process.env.MYSQL_HOST,port:Number(process.env.MYSQL_PORT||3306),user:process.env.MYSQL_USER,password:process.env.MYSQL_PASSWORD};
  const admin=await mysql.createConnection(config);
  const name=`smartres_popular_test_${randomBytes(6).toString('hex')}`;
  await admin.query(`CREATE DATABASE \`${name}\` CHARACTER SET utf8mb4`);
  const db=mysql.createPool({...config,database:name,connectionLimit:2});
  let server:ReturnType<ReturnType<typeof createApp>['app']['listen']>|undefined;
  try {
    const schema=await readFile(new URL('../../../database/staff-schema.sql',import.meta.url),'utf8');
    for(const sql of schema.split(';').filter(statement=>statement.trim())) await db.query(sql);
    await ensureInvoiceStorage(db);
    await db.query("SET time_zone='+00:00'");
    await db.query("INSERT INTO restaurant_tables(id,code,name,area,status,guests) VALUES(1,'A01','A01','Test','available',0)");
    await db.query("INSERT INTO categories(id,name,sort_order) VALUES(1,'Món chính',0)");
    await db.query(`INSERT INTO menu_items(id,category_id,name,description,image_url,price,is_available) VALUES
      (1,1,'Cơm hiện tại','Mô tả mới','/menu/com.webp',45000,1),
      (2,1,'Sườn hiện tại','Mô tả sườn','/menu/suon.webp',89000,1),
      (3,1,'Món đã ngừng bán','Không hiện',NULL,10000,0)`);

    const receipt=(items:unknown[])=>JSON.stringify({paymentStatus:'paid',items});
    await db.execute(`INSERT INTO cashier_invoices(invoice_code,table_id,table_code,total_amount,payment_method,paid_at,cashier_name,snapshot) VALUES
      ('NEW-1',1,'A01',189000,'cash','2026-11-15 10:00:00','Test',?),
      ('NEW-2',1,'A01',401000,'card','2026-11-14 10:00:00','Test',?),
      ('OLD',1,'A01',4455000,'cash','2026-09-01 10:00:00','Test',?)`,[
      receipt([{menuItemId:1,name:'Tên cũ',quantity:2,unitPrice:45000},{menuItemId:2,name:'Tên cũ',quantity:1,unitPrice:89000},{menuItemId:3,name:'Ẩn',quantity:50,unitPrice:10000}]),
      receipt([{menuItemId:1,name:'Tên cũ',quantity:1,unitPrice:45000},{menuItemId:2,name:'Tên cũ',quantity:3,unitPrice:89000}]),
      receipt([{menuItemId:1,name:'Tên cũ',quantity:99,unitPrice:45000}]),
    ]);
    // Các đơn này chưa tạo hóa đơn thu ngân nên không được tính vào xếp hạng.
    await db.query(`INSERT INTO orders(id,order_code,request_id,request_hash,table_id,total_amount,status,payment_status) VALUES
      (1,'UNPAID','unpaid',REPEAT('a',64),1,450000,'new','unpaid'),
      (2,'CANCELLED','cancelled',REPEAT('b',64),1,450000,'cancelled','unpaid')`);

    const now=Date.parse('2026-11-16T12:00:00Z');
    const report=await readPopularItems(db,now);
    assert.deepEqual(report.items.map(item=>({id:item.id,name:item.name,quantity:item.quantity,invoiceCount:item.invoiceCount})),[
      {id:2,name:'Sườn hiện tại',quantity:4,invoiceCount:2},
      {id:1,name:'Cơm hiện tại',quantity:3,invoiceCount:2},
    ]);
    assert.equal(report.items[0].imageUrl,'/menu/suon.webp');
    assert.equal(report.items[0].price,89000);

    server=createApp(db).app.listen(0,'127.0.0.1');
    await once(server,'listening');
    const address=server.address();
    if(!address || typeof address==='string') throw new Error('Không mở được test server.');
    const response=await fetch(`http://127.0.0.1:${address.port}/api/popular-items`);
    assert.equal(response.status,200);
    assert.match(response.headers.get('cache-control')??'',/max-age=60/);
    const body=await response.json() as {items:Array<{id:number}>};
    assert.ok(Array.isArray(body.items));
  } finally {
    if(server) await new Promise<void>((resolve,reject)=>server!.close(error=>error?reject(error):resolve()));
    await db.end();
    await admin.query(`DROP DATABASE IF EXISTS \`${name}\``);
    await admin.end();
  }
});
