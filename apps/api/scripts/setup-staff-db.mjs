import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
import { readFile } from 'node:fs/promises';
dotenv.config({ path: new URL('../../../.env.mysql.local', import.meta.url), quiet: true });
const database = process.env.MYSQL_DATABASE;
if (database !== 'smartres_staff') throw new Error('Setup chỉ dành cho database smartres_staff.');
const c = await mysql.createConnection({ host: process.env.MYSQL_HOST, port: Number(process.env.MYSQL_PORT || 3306),
  user: process.env.MYSQL_USER, password: process.env.MYSQL_PASSWORD, charset: 'utf8mb4' });
try {
  await c.query('CREATE DATABASE IF NOT EXISTS smartres_staff CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
  await c.changeUser({ database });
  const schema = await readFile(new URL('../../../database/staff-schema.sql', import.meta.url), 'utf8');
  for (const sql of schema.split(';').filter(s => s.trim())) await c.query(sql);
  await c.beginTransaction();
  for (const [index, code] of ['A01','A02','A03','A04','A05','A06','B01','B02'].entries()) {
    await c.execute('INSERT IGNORE INTO restaurant_tables (code,name,area,seats) VALUES (?,?,?,4)', [code, `Bàn ${code}`, index < 6 ? 'Tầng 1' : 'Tầng 2']);
  }
  for (const [index, name] of ['Khai vị','Món chính','Đồ uống'].entries()) {
    await c.execute('INSERT IGNORE INTO categories(name,sort_order) VALUES (?,?)', [name,index]);
  }
  const dishes = [
    ['Cơm chiên hải sản','Món chính','🍚',45000,1], ['Sườn nướng mật ong','Món chính','🍖',89000,1],
    ['Gỏi cuốn tôm','Khai vị','🥗',35000,1], ['Khoai tây chiên','Khai vị','🍟',30000,1],
    ['Trà đào cam sả','Đồ uống','🍑',25000,1], ['Lẩu hải sản','Món chính','🍲',250000,0],
  ];
  for (const [name,category,emoji,price,available] of dishes) {
    await c.execute(`INSERT IGNORE INTO menu_items(name,category_id,emoji,price,is_available)
      SELECT ?,id,?,?,? FROM categories WHERE name=?`, [name,emoji,price,available,category]);
  }
  await c.commit();
  console.log('Database smartres_staff sẵn sàng: 8 bàn và 6 món khởi tạo. Không tạo đơn hàng giả.');
} catch(e) { await c.rollback(); console.error('Không thể khởi tạo:', e.code ?? e.message); process.exitCode=1; }
finally { await c.end(); }
