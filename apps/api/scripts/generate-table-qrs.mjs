import mysql from 'mysql2/promise';
import QRCode from 'qrcode';
import { mkdir, writeFile } from 'node:fs/promises';
import { getWebUrl } from '../../../scripts/local-config.mjs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const webUrl = getWebUrl();
const outputDir = fileURLToPath(new URL('../../../apps/web/public/qr/', import.meta.url));
const database = process.env.MYSQL_DATABASE;
if (!database) throw new Error('Thiếu MYSQL_DATABASE trong file .env.');

if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(webUrl)) {
  console.warn(`Cảnh báo: ${webUrl} chỉ mở được trên chính máy tính, điện thoại sẽ không truy cập được.`);
  console.warn('Hãy đặt NEXT_PUBLIC_WEB_URL bằng URL LAN/HTTPS trước khi in mã QR.');
}

const connection = await mysql.createConnection({
  host: process.env.MYSQL_HOST,
  port: Number(process.env.MYSQL_PORT || 3306),
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database
});

try {
  const [tables] = await connection.query('SELECT code, name FROM restaurant_tables WHERE status <> \'disabled\' ORDER BY code');
  await mkdir(outputDir, { recursive: true });

  const cards = [];
  for (const table of tables) {
    const url = `${webUrl}/order/${encodeURIComponent(table.code)}`;
    const filename = `${table.code}.png`;
    await QRCode.toFile(resolve(outputDir, filename), url, {
      type: 'png', width: 720, margin: 2,
      color: { dark: '#111827', light: '#FFFFFFFF' },
      errorCorrectionLevel: 'M'
    });
    const escapeHtml = value => String(value).replace(/[&<>"']/g, character => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[character]));
    cards.push(`<article><img src="${escapeHtml(filename)}" alt="QR ${escapeHtml(table.code)}"><h2>${escapeHtml(table.name)}</h2><p>${escapeHtml(table.code)}</p><small>${escapeHtml(url)}</small></article>`);
  }

  await writeFile(resolve(outputDir, 'index.html'), `<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>QR bàn SmartRes</title><style>body{font-family:Arial;margin:24px;color:#111827}.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:18px}article{border:1px solid #d1d5db;border-radius:14px;padding:18px;text-align:center;break-inside:avoid}img{width:220px;height:220px}h2{margin:8px 0 2px}p{margin:0;font-weight:bold}small{display:block;margin-top:8px;color:#6b7280;word-break:break-all}@media print{body{margin:0}.grid{gap:8px}article{border-color:#aaa}}</style></head><body><h1>Mã QR bàn SmartRes</h1><div class="grid">${cards.join('')}</div></body></html>`);
  console.log(`Đã tạo ${tables.length} mã QR tại apps/web/public/qr với URL ${webUrl}.`);
} finally {
  await connection.end();
}
