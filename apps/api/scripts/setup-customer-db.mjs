import mysql from 'mysql2/promise';
import dotenv from 'dotenv';

dotenv.config({ path: new URL('../../../.env', import.meta.url), quiet: true });

const database = process.env.MYSQL_DATABASE;
if (!database) throw new Error('Thiếu MYSQL_DATABASE trong file .env.');

const connection = await mysql.createConnection({
  host: process.env.MYSQL_HOST,
  port: Number(process.env.MYSQL_PORT || 3306),
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database
});

try {
  const [orderColumns] = await connection.query(`SHOW COLUMNS FROM orders LIKE 'customer_note'`);
  if (!orderColumns.length) await connection.query('ALTER TABLE orders ADD COLUMN customer_note TEXT NULL AFTER total_amount');

  const [itemOptions] = await connection.query(`SHOW COLUMNS FROM order_items LIKE 'options_json'`);
  if (!itemOptions.length) await connection.query('ALTER TABLE order_items ADD COLUMN options_json JSON NULL AFTER served_at');

  const [itemNotes] = await connection.query(`SHOW COLUMNS FROM order_items LIKE 'note'`);
  if (!itemNotes.length) await connection.query('ALTER TABLE order_items ADD COLUMN note TEXT NULL AFTER options_json');

  console.log(`Customer ordering schema is ready in database ${database}.`);
} finally {
  await connection.end();
}
