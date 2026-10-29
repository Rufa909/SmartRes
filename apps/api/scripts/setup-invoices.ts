import { db } from '../src/infrastructure/database.js';
import { ensureInvoiceStorage } from '../src/invoice-storage.js';

try {
  await ensureInvoiceStorage(db);
  console.log('Đã sẵn sàng lưu hóa đơn, lịch sử thanh toán và nhật ký chỉnh sửa.');
} finally {
  await db.end();
}
