import {db} from '../src/infrastructure/database.js';
import {ensureInvoiceStorage} from '../src/invoice-storage.js';
try {
  await ensureInvoiceStorage(db);
  console.log('Đã sẵn sàng tạo, tra cứu và áp dụng mã giảm giá.');
} finally {await db.end();}
