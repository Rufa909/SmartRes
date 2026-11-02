import {db} from '../src/infrastructure/database.js';
import {ensureItemTimingStorage} from '../src/item-timing.js';
try {
  await ensureItemTimingStorage(db);
  console.log('Đã sẵn sàng lưu thời gian và trạng thái từng món.');
} finally {await db.end();}
