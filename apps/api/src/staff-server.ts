import { db } from './infrastructure/database.js';
import { env } from './config/env.js';
import { createStaffApp } from './staff-app.js';

// Bản phát triển cục bộ; cần đăng nhập và phân quyền trước khi triển khai mạng.
await db.query('SELECT 1');
const server=createStaffApp(db).listen(env.API_PORT,'127.0.0.1',()=>console.log(`Staff API + MySQL: http://127.0.0.1:${env.API_PORT}`));
process.on('SIGINT',()=>server.close(()=>{void db.end();}));
