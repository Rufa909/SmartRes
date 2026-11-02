import {db} from '../src/infrastructure/database.js';
import {ensureUserManagementStorage} from '../src/user-management.js';

try {
  await ensureUserManagementStorage(db);
  console.log('Đã sẵn sàng quản lý tài khoản nhân sự và phiên đăng nhập.');
} finally {
  await db.end();
}
