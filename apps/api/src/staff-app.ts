import express, { type RequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { createHash, randomUUID } from 'node:crypto';
import { z, ZodError } from 'zod';
import type { Pool, RowDataPacket, ResultSetHeader } from 'mysql2/promise';
import { createToken, readToken, verifyPassword, type Role } from './auth.js';

class ApiError extends Error { constructor(public status: number, message: string) { super(message); } }
const id = z.coerce.number().int().positive();
const createOrder = z.object({ tableId: id, requestId: z.string().uuid(),
  items: z.array(z.object({ menuItemId: id, quantity: z.number().int().min(1).max(99) })).min(1).max(50) });

export function createStaffApp(db: Pool) {
  const app = express();
  app.use(helmet(), cors({origin: ['http://127.0.0.1:5178','http://localhost:5178']}), express.json({limit:'32kb'}));
  const route = (fn: RequestHandler): RequestHandler => (req,res,next) => { Promise.resolve(fn(req,res,next)).catch(next); };
  const requireRole = (...roles: Role[]): RequestHandler => (req,res,next) => {
    const header = req.header('authorization') || '';
    const user = header.startsWith('Bearer ') ? readToken(header.slice(7)) : null;
    if (!user) { res.status(401).json({message:'Bạn chưa đăng nhập hoặc phiên đã hết hạn.'}); return; }
    if (!roles.includes(user.role)) { res.status(403).json({message:'Tài khoản không có quyền thực hiện thao tác này.'}); return; }
    (req as express.Request & {user: typeof user}).user = user;
    next();
  };
  app.get('/api/health', route(async (_req,res) => { await db.query('SELECT 1'); res.json({status:'ok',storage:'mysql'}); }));
  app.post('/api/auth/login', route(async (req,res) => {
    const input = z.object({username:z.string().min(3).max(60),password:z.string().min(6).max(200)}).parse(req.body);
    const [rows] = await db.query<RowDataPacket[]>('SELECT id,username,display_name AS displayName,role,password_hash AS passwordHash FROM users WHERE username=? AND is_active=1 LIMIT 1',[input.username]);
    if (!rows[0] || !verifyPassword(input.password, rows[0].passwordHash)) throw new ApiError(401,'Tên đăng nhập hoặc mật khẩu không đúng.');
    const user = {id:Number(rows[0].id),username:rows[0].username,displayName:rows[0].displayName,role:rows[0].role as Role};
    res.json({token:createToken(user),user});
  }));
  app.get('/api/staff/snapshot', requireRole('staff','kitchen','manager'), route(async (_req,res) => {
    const c = await db.getConnection();
    try {
      await c.beginTransaction();
      const [tables] = await c.query<RowDataPacket[]>('SELECT id,code,area,seats,guests,status FROM restaurant_tables WHERE status <> "disabled" ORDER BY code');
      const [menu] = await c.query<RowDataPacket[]>(`SELECT m.id,m.name,m.emoji,m.price,m.is_available AS available,c.name AS category
        FROM menu_items m JOIN categories c ON c.id=m.category_id ORDER BY c.sort_order,m.id`);
      const [items] = await c.query<RowDataPacket[]>(`SELECT i.id,t.code AS tableCode,i.item_name AS name,i.quantity,i.status,
        i.unit_price AS unitPrice,o.order_code AS orderCode,o.created_at AS createdAt
        FROM order_items i JOIN orders o ON o.id=i.order_id JOIN restaurant_tables t ON t.id=o.table_id
        WHERE o.status <> 'cancelled' AND o.payment_status='unpaid' ORDER BY i.id DESC`);
      await c.commit();
      res.json({tables,menu:menu.map(m=>({...m,price:Number(m.price),available:Boolean(m.available)})),items});
    } catch(e) { await c.rollback(); throw e; } finally { c.release(); }
  }));
  app.post('/api/staff/tables/:id/seat', requireRole('staff','manager'), route(async (req,res) => {
    const tableId=id.parse(req.params.id), guests=z.number().int().min(1).max(99).parse(req.body.guests);
    const [result]=await db.execute<ResultSetHeader>(`UPDATE restaurant_tables SET status='dining',guests=?
      WHERE id=? AND status='available'`, [guests,tableId]);
    if (!result.affectedRows) throw new ApiError(409,'Bàn không còn trống hoặc không tồn tại.');
    res.json({ok:true});
  }));
  app.post('/api/staff/tables/:id/request-payment', requireRole('staff','manager'), route(async (req,res) => {
    const tableId = id.parse(req.params.id);
    const c = await db.getConnection();
    try {
      await c.beginTransaction();
      const [tables] = await c.query<RowDataPacket[]>('SELECT status FROM restaurant_tables WHERE id=? FOR UPDATE',[tableId]);
      if (tables[0]?.status !== 'dining') throw new ApiError(409,'Bàn không ở trạng thái đang phục vụ.');
      const [orders] = await c.query<RowDataPacket[]>(`SELECT id FROM orders
        WHERE table_id=? AND payment_status='unpaid' AND status<>'cancelled' LIMIT 1`,[tableId]);
      if (!orders.length) throw new ApiError(409,'Bàn chưa có đơn hàng chưa thanh toán.');
      await c.execute(`UPDATE restaurant_tables SET status='waiting_payment' WHERE id=? AND status='dining'`,[tableId]);
      await c.commit();
      res.json({ok:true});
    } catch(e) { await c.rollback(); throw e; } finally { c.release(); }
  }));
  app.get('/api/staff/cashier', requireRole('staff','cashier','manager'), route(async (_req,res) => {
    const [rows] = await db.query<RowDataPacket[]>(`SELECT t.id AS tableId,t.code AS tableCode,t.guests,
      bill.totalAmount,bill.orderCount,bill.openedAt,COALESCE(pending.pendingItems,0) AS pendingItems
      FROM restaurant_tables t
      JOIN (SELECT table_id,SUM(total_amount) AS totalAmount,COUNT(id) AS orderCount,MIN(created_at) AS openedAt
        FROM orders WHERE payment_status='unpaid' AND status<>'cancelled' GROUP BY table_id) bill ON bill.table_id=t.id
      LEFT JOIN (SELECT o.table_id,COUNT(*) AS pendingItems FROM order_items i JOIN orders o ON o.id=i.order_id
        WHERE o.payment_status='unpaid' AND o.status<>'cancelled' AND i.status<>'served' GROUP BY o.table_id) pending ON pending.table_id=t.id
      WHERE t.status='waiting_payment' ORDER BY t.code`);
    res.json({tables: rows.map(r => ({...r,totalAmount:Number(r.totalAmount),orderCount:Number(r.orderCount),pendingItems:Number(r.pendingItems)}))});
  }));
  app.post('/api/staff/tables/:id/pay', requireRole('staff','cashier','manager'), route(async (req,res) => {
    const tableId = id.parse(req.params.id);
    const method = z.enum(['cash','bank_transfer','card']).parse(req.body.paymentMethod);
    const c = await db.getConnection();
    try {
      await c.beginTransaction();
      const [tables] = await c.query<RowDataPacket[]>('SELECT status FROM restaurant_tables WHERE id=? FOR UPDATE',[tableId]);
      if (tables[0]?.status !== 'waiting_payment') throw new ApiError(409,'Bàn chưa được yêu cầu thanh toán.');
      const [pending] = await c.query<RowDataPacket[]>(`SELECT i.id FROM order_items i JOIN orders o ON o.id=i.order_id
        WHERE o.table_id=? AND o.payment_status='unpaid' AND o.status<>'cancelled' AND i.status<>'served' LIMIT 1`,[tableId]);
      if (pending.length) throw new ApiError(409,'Chưa thể thanh toán: vẫn còn món chưa phục vụ.');
      const [orders] = await c.query<RowDataPacket[]>('SELECT id,total_amount FROM orders WHERE table_id=? AND payment_status=\'unpaid\' AND status<>\'cancelled\' FOR UPDATE',[tableId]);
      if (!orders.length) throw new ApiError(409,'Bàn không còn hóa đơn chưa thanh toán.');
      await c.execute(`UPDATE orders SET payment_status='paid',payment_method=?,paid_at=CURRENT_TIMESTAMP WHERE table_id=? AND payment_status='unpaid' AND status<>'cancelled'`,[method,tableId]);
      await c.execute(`UPDATE restaurant_tables SET status='available',guests=0 WHERE id=? AND status='waiting_payment'`,[tableId]);
      await c.commit();
      res.json({ok:true,tableId,paymentMethod:method,totalAmount:orders.reduce((sum,o)=>sum+Number(o.total_amount),0)});
    } catch(e) { await c.rollback(); throw e; } finally { c.release(); }
  }));
  app.post('/api/staff/orders', requireRole('staff','manager'), route(async (req,res) => {
    const input=createOrder.parse(req.body);
    input.items.sort((a,b)=>a.menuItemId-b.menuItemId);
    if(new Set(input.items.map(i=>i.menuItemId)).size!==input.items.length) throw new ApiError(400,'Mã món bị trùng.');
    const hash=createHash('sha256').update(JSON.stringify({tableId:input.tableId,items:input.items})).digest('hex');
    const c=await db.getConnection();
    try {
      await c.beginTransaction();
      const [tables]=await c.query<RowDataPacket[]>('SELECT status FROM restaurant_tables WHERE id=? FOR UPDATE',[input.tableId]);
      const [previous]=await c.query<RowDataPacket[]>('SELECT order_code AS orderCode,total_amount AS totalAmount,request_hash FROM orders WHERE request_id=?',[input.requestId]);
      if(previous.length) {
        if(previous[0].request_hash!==hash) throw new ApiError(409,'Yêu cầu đã được dùng cho giỏ khác.');
        await c.commit(); res.json({orderCode:previous[0].orderCode,totalAmount:Number(previous[0].totalAmount)}); return;
      }
      if(tables[0]?.status!=='dining') throw new ApiError(409,'Hãy nhận bàn trước khi gọi món; bàn chờ thanh toán không nhận thêm món.');
      const lines=[]; let total=0;
      for(const item of input.items) {
        const [rows]=await c.query<RowDataPacket[]>('SELECT name,price,is_available FROM menu_items WHERE id=? FOR SHARE',[item.menuItemId]);
        if(!rows[0]?.is_available) throw new ApiError(409,'Một món đã hết hoặc không tồn tại. Tải lại menu.');
        const price=Number(rows[0].price); total+=price*item.quantity;
        lines.push({...item,name:rows[0].name,price});
      }
      const code=`SR-${randomUUID()}`;
      const [order]=await c.execute<ResultSetHeader>('INSERT INTO orders(order_code,request_id,request_hash,table_id,total_amount) VALUES(?,?,?,?,?)', [code,input.requestId,hash,input.tableId,total]);
      for(const line of lines) await c.execute('INSERT INTO order_items(order_id,menu_item_id,item_name,quantity,unit_price) VALUES(?,?,?,?,?)',[order.insertId,line.menuItemId,line.name,line.quantity,line.price]);
      await c.commit(); res.status(201).json({orderCode:code,totalAmount:total});
    } catch(e) {await c.rollback(); throw e;} finally {c.release();}
  }));
  app.post('/api/staff/items/:id/kitchen', requireRole('kitchen','manager'), route(async (req,res) => {
    const itemId=id.parse(req.params.id);
    const status=z.enum(['cooking','completed']).parse(req.body.status);
    const previous=status==='cooking'?'preparing':'cooking';
    // Cập nhật có điều kiện: hai thiết bị không thể đưa món lùi trạng thái.
    const [result]=await db.execute<ResultSetHeader>(`UPDATE order_items i JOIN orders o ON o.id=i.order_id
      SET i.status=? WHERE i.id=? AND i.status=? AND o.status<>'cancelled' AND o.payment_status='unpaid'`,[status,itemId,previous]);
    if(!result.affectedRows) {
      const [rows]=await db.query<RowDataPacket[]>(`SELECT i.status FROM order_items i JOIN orders o ON o.id=i.order_id
        WHERE i.id=? AND o.status<>'cancelled' AND o.payment_status='unpaid'`,[itemId]);
      if(rows[0]?.status!==status) throw new ApiError(409,'Món đã đổi trạng thái hoặc chưa tới bước này. Hãy tải lại danh sách.');
    }
    res.json({ok:true,status});
  }));
  app.post('/api/staff/items/:id/serve', requireRole('staff','manager'), route(async (req,res) => {
    const itemId=id.parse(req.params.id);
    const [result]=await db.execute<ResultSetHeader>(`UPDATE order_items i JOIN orders o ON o.id=i.order_id
      SET i.status='served',i.served_at=CURRENT_TIMESTAMP WHERE i.id=? AND i.status='completed' AND o.status<>'cancelled'`,[itemId]);
    if(!result.affectedRows) {
      const [rows]=await db.query<RowDataPacket[]>('SELECT status FROM order_items WHERE id=?',[itemId]);
      if(rows[0]?.status!=='served') throw new ApiError(409,'Món chưa hoàn thành hoặc không tồn tại.');
    }
    res.json({ok:true});
  }));
  app.use((_req,res)=>res.status(404).json({message:'Không tìm thấy API.'}));
  app.use((error: unknown,_req: express.Request,res: express.Response,_next: express.NextFunction) => {
    if(error instanceof ApiError) { res.status(error.status).json({message:error.message}); return; }
    if(error instanceof ZodError || error instanceof SyntaxError) {res.status(400).json({message:'Dữ liệu gửi lên không hợp lệ.'});return;}
    console.error('Staff API failed:', (error as {code?:string}).code ?? 'UNKNOWN');
    res.status(503).json({message:'Không thể lưu hoặc tải dữ liệu MySQL. Vui lòng thử lại.'});
  });
  return app;
}
