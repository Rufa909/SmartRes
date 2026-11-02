import {db} from '../src/infrastructure/database.js';
import {ensurePromotionStorage} from '../src/promotions.js';
try {
  await ensurePromotionStorage(db);
  console.log('Đã sẵn sàng quản lý khuyến mãi và khung giờ áp dụng.');
} finally {await db.end();}
