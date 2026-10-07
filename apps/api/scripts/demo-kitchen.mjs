// Demo chủ động tạo dữ liệu thật: chỉ chạy khi muốn đặt một đơn thử mới.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { writeFile } from 'node:fs/promises';
import { setTimeout as pause } from 'node:timers/promises';
import dotenv from 'dotenv';
import mysql from 'mysql2/promise';

const base = 'http://127.0.0.1:4000/api/staff/';
const report = { at: new Date().toISOString(), checks: [] };
async function call(path, body, expected = 200) {
  const response = await fetch(base + path, body === undefined ? {} : {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  });
  const data = await response.json();
  assert.equal(response.status, expected, JSON.stringify(data));
  return data;
}
function check(text) { report.checks.push(text); console.log(text); }
async function items() {
  return (await call('snapshot')).items.filter(i => i.orderCode === report.orderCode);
}
async function save() {
  await writeFile(new URL('../../../demo-kitchen-result.json', import.meta.url), JSON.stringify(report, null, 2) + '\n');
}
try {
  const snapshot = await call('snapshot');
  const table = snapshot.tables.find(t => t.status === 'available' && t.seats >= 2);
  assert.ok(table, 'Không có bàn trống; không thay đổi bàn đang dùng.');
  const rice = snapshot.menu.find(m => m.id === 1 && m.available);
  const tea = snapshot.menu.find(m => m.id === 5 && m.available);
  assert.ok(rice && tea, 'Món demo không còn bán.');
  report.table = table.code;
  report.requestId = randomUUID();
  await call(`tables/${table.id}/seat`, { guests: 2 });
  const payload = { tableId: table.id, requestId: report.requestId, items: [
    { menuItemId: rice.id, quantity: 2 }, { menuItemId: tea.id, quantity: 1 },
  ] };
  const order = await call('orders', payload, 201);
  Object.assign(report, order);
  assert.equal(order.totalAmount, rice.price * 2 + tea.price);
  assert.equal((await call('orders', payload)).orderCode, order.orderCode);
  let lines = await items();
  assert.equal(lines.length, 2);
  assert.ok(lines.every(i => i.status === 'preparing'));
  check(`Đặt món bàn ${table.code}: 2 cơm + 1 trà, ${order.totalAmount} đồng. Gửi lại không trùng đơn.`);
  await save();
  await call(`items/${lines[0].id}/serve`, {}, 409);
  await call(`items/${lines[0].id}/kitchen`, { status: 'completed' }, 409);
  check('Chặn phục vụ sớm và chặn bỏ qua bước nấu: HTTP 409.');
  await pause(12000);
  for (const line of lines) await call(`items/${line.id}/kitchen`, { status: 'cooking' });
  assert.ok((await items()).every(i => i.status === 'cooking'));
  check('Bếp: cả hai dòng món đang nấu.');
  await pause(12000);
  for (const line of lines) await call(`items/${line.id}/kitchen`, { status: 'completed' });
  assert.ok((await items()).every(i => i.status === 'completed'));
  check('Bếp: hoàn thành, chờ nhân viên phục vụ.');
  await pause(12000);
  for (const line of lines) {
    await call(`items/${line.id}/serve`, {});
    await call(`items/${line.id}/serve`, {});
  }
  assert.ok((await items()).every(i => i.status === 'served'));
  await call(`items/${lines[0].id}/kitchen`, { status: 'cooking' }, 409);
  check('Đã phục vụ; xác nhận lại an toàn; không thể chuyển món đã phục vụ về nấu.');
  dotenv.config({ path: new URL('../../../.env.mysql.local', import.meta.url).pathname.replace(/^\/(\w:)/, '$1'), quiet: true });
  const db = await mysql.createConnection({host: process.env.MYSQL_HOST ?? '127.0.0.1', port: Number(process.env.MYSQL_PORT ?? 3306), user: process.env.MYSQL_USER, password: process.env.MYSQL_PASSWORD, database: 'smartres_staff'});
  try {
    const [rows] = await db.execute('SELECT i.item_name,i.quantity,i.status,i.served_at FROM order_items i JOIN orders o ON o.id=i.order_id WHERE o.order_code=?', [order.orderCode]);
    assert.equal(rows.length, 2);
    assert.ok(rows.every(i => i.status === 'served' && i.served_at));
    report.savedItems = rows;
    check('Đọc trực tiếp MySQL: 2 dòng món đã phục vụ, có thời điểm served_at.');
  } finally { await db.end(); }
  report.success = true;
} catch (error) {
  report.success = false;
  report.error = error.code ?? error.message;
  console.error('Demo chưa hoàn tất:', report.error);
  process.exitCode = 1;
} finally { await save(); }
