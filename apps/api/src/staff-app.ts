import express, { type RequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { createHash, randomUUID } from 'node:crypto';
import { z, ZodError } from 'zod';
import type { Pool, RowDataPacket, ResultSetHeader } from 'mysql2/promise';
import { createToken, readToken, verifyPassword, type Role, type AuthUser } from './auth.js';
import { readInvoice } from './invoice.js';
import { parseInvoiceSnapshot } from './invoice-storage.js';
import { openDiningSession } from './customer-sessions.js';

class ApiError extends Error { constructor(public status: number, message: string) { super(message); } }
const id = z.coerce.number().int().positive();
const createOrder = z.object({ tableId: id, requestId: z.string().uuid(),
  items: z.array(z.object({ menuItemId: id, quantity: z.number().int().min(1).max(99) })).min(1).max(50) });
const adjustmentLine = z.union([
  z.object({itemId:id,quantity:z.number().int().min(1).max(99)}).strict(),
  z.object({menuItemId:id,quantity:z.number().int().min(1).max(99),served:z.boolean().default(false),note:z.string().trim().max(500).default('')}).strict(),
]);
const currentUser = (req: express.Request) => (req as express.Request & {user:AuthUser}).user;

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
        i.unit_price AS unitPrice,i.note,o.order_code AS orderCode,o.created_at AS createdAt
        FROM order_items i JOIN orders o ON o.id=i.order_id JOIN restaurant_tables t ON t.id=o.table_id
        WHERE o.status <> 'cancelled' AND o.payment_status='unpaid' ORDER BY i.id DESC`);
      await c.commit();
      res.json({tables,menu:menu.map(m=>({...m,price:Number(m.price),available:Boolean(m.available)})),items});
    } catch(e) { await c.rollback(); throw e; } finally { c.release(); }
  }));
  app.get('/api/staff/tables/:id/details', requireRole('staff','manager'), route(async (req,res) => {
    const c=await db.getConnection();
    try {
      await c.beginTransaction();
      const [tables]=await c.query<RowDataPacket[]>('SELECT id,code,area,seats,guests,status FROM restaurant_tables WHERE id=? FOR UPDATE',[id.parse(req.params.id)]);
      if (!tables.length) throw new ApiError(404,'Không tìm thấy bàn.');
      const table=tables[0];
      const [rows]=await c.query<RowDataPacket[]>(`SELECT i.id,i.item_name AS name,i.quantity,i.unit_price AS unitPrice,i.status,i.note,
        o.order_code AS orderCode,o.created_at AS createdAt FROM order_items i JOIN orders o ON o.id=i.order_id
        WHERE o.table_id=? AND o.payment_status='unpaid' AND o.status<>'cancelled' AND ? IN ('dining','waiting_payment')
        ORDER BY o.id,i.id`,[table.id,table.status]);
      const items=rows.map(i=>({...i,quantity:Number(i.quantity),unitPrice:Number(i.unitPrice),lineTotal:Number(i.quantity)*Number(i.unitPrice)}));
      await c.commit();
      res.set('Cache-Control','no-store').json({table,items,subtotalAmount:items.reduce((total,i)=>total+i.lineTotal,0)});
    } catch(e) {await c.rollback();throw e;} finally {c.release();}
  }));
  app.post('/api/staff/tables/:id/seat', requireRole('staff','manager'), route(async (req,res) => {
    const tableId=id.parse(req.params.id), guests=z.number().int().min(1).max(99).parse(req.body.guests);
    const c = await db.getConnection();
    try {
      await c.beginTransaction();
      const [result]=await c.execute<ResultSetHeader>(`UPDATE restaurant_tables SET status='dining',guests=?,seated_at=CURRENT_TIMESTAMP
        WHERE id=? AND status='available'`, [guests,tableId]);
      if (!result.affectedRows) throw new ApiError(409,'Bàn không còn trống hoặc không tồn tại.');
      const customerSession = await openDiningSession(c,tableId);
      await c.commit();
      res.json({ok:true,customerSession});
    } catch(e) {await c.rollback();throw e;} finally {c.release();}
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
  app.get('/api/staff/cashier/tables', requireRole('staff','cashier','manager'), route(async (_req,res) => {
    const [tables] = await db.query<RowDataPacket[]>(`SELECT t.id AS tableId,t.code AS tableCode,t.area,t.seats,t.guests,t.status,
      t.seated_at AS openedAt,EXISTS(SELECT 1 FROM orders o WHERE o.table_id=t.id
        AND o.payment_status='unpaid' AND o.status<>'cancelled') AS hasInvoice
      FROM restaurant_tables t WHERE t.status<>'disabled' ORDER BY t.code`);
    res.json({tables:tables.map(t=>({...t,tableId:Number(t.tableId),seats:Number(t.seats),guests:Number(t.guests),hasInvoice:Boolean(t.hasInvoice)}))});
  }));
  app.get('/api/staff/cashier', requireRole('staff','cashier','manager'), route(async (_req,res) => {
    const c=await db.getConnection();
    try {
      await c.beginTransaction();
      const [tables]=await c.query<RowDataPacket[]>("SELECT id FROM restaurant_tables WHERE status='waiting_payment' ORDER BY code");
      const rows=[];
      for (const table of tables) {
        const bill=await readInvoice(c,Number(table.id));
        if (bill) rows.push({invoiceCode:bill.invoiceCode,tableId:bill.tableId,tableCode:bill.tableCode,guests:bill.guests,openedAt:bill.openedAt,
          orderCount:bill.orderCodes.length,pendingItems:bill.pendingItems,totalAmount:bill.totalAmount,
          subtotalAmount:bill.subtotalAmount,discountAmount:bill.discountAmount});
      }
      await c.commit();
      res.json({tables:rows});
    } catch(e) {await c.rollback();throw e;} finally {c.release();}
  }));
  app.get('/api/staff/tables/:id/invoice', requireRole('staff','cashier','manager'), route(async (req,res) => {
    const tableId = id.parse(req.params.id);
    const c = await db.getConnection();
    try {
      await c.beginTransaction();
      const [tables] = await c.query<RowDataPacket[]>('SELECT status FROM restaurant_tables WHERE id=? FOR UPDATE',[tableId]);
      if (!['dining','waiting_payment'].includes(tables[0]?.status)) throw new ApiError(409,'Bàn không còn đang phục vụ hoặc chờ thanh toán.');
      const invoice = await readInvoice(c,tableId);
      if (!invoice) throw new ApiError(409,'Bàn không còn hóa đơn chưa thanh toán.');
      await c.commit();
      res.json({invoice});
    } catch(e) { await c.rollback(); throw e; } finally { c.release(); }
  }));
  app.get('/api/staff/cashier/menu', requireRole('cashier','manager'), route(async (_req,res) => {
    const [rows] = await db.query<RowDataPacket[]>(`SELECT id,name,price FROM menu_items WHERE is_available=1 ORDER BY name`);
    res.json({items:rows.map(i=>({...i,price:Number(i.price)}))});
  }));
  app.post('/api/staff/tables/:id/invoice', requireRole('cashier','manager'), route(async (req,res) => {
    const tableId = id.parse(req.params.id);
    const input = z.object({version:z.string().length(64),items:z.array(adjustmentLine).min(1).max(200),reason:z.string().trim().max(500).default('Điều chỉnh hóa đơn')}).parse(req.body);
    const c = await db.getConnection();
    try {
      await c.beginTransaction();
      const [tables] = await c.query<RowDataPacket[]>('SELECT status FROM restaurant_tables WHERE id=? FOR UPDATE',[tableId]);
      if (!['dining','waiting_payment'].includes(tables[0]?.status)) throw new ApiError(409,'Chỉ được sửa hóa đơn chưa thanh toán.');
      const [orders] = await c.query<RowDataPacket[]>(`SELECT id FROM orders WHERE table_id=? AND payment_status='unpaid' AND status<>'cancelled' ORDER BY id FOR UPDATE`,[tableId]);
      await c.query(`SELECT i.id FROM order_items i JOIN orders o ON o.id=i.order_id WHERE o.table_id=? AND o.payment_status='unpaid' AND o.status<>'cancelled' FOR UPDATE`,[tableId]);
      const before = await readInvoice(c,tableId);
      if (!before || !orders.length) throw new ApiError(409,'Không còn hóa đơn để chỉnh sửa.');
      if (before.version !== input.version) throw new ApiError(409,'Hóa đơn đã thay đổi trên thiết bị khác. Đóng và mở lại chi tiết để tải bản mới.');
      const previous = new Map(before.items.map(i=>[Number(i.id),i]));
      const retained = new Set<number>();
      for (const line of input.items) {
        if ('itemId' in line) {
          if (!previous.has(line.itemId) || retained.has(line.itemId)) throw new ApiError(400,'Món không thuộc hóa đơn hoặc bị trùng.');
          retained.add(line.itemId);
          // Existing line prices and preparation status remain at their recorded values.
          await c.execute('UPDATE order_items SET quantity=? WHERE id=?',[line.quantity,line.itemId]);
        } else {
          const [menu] = await c.query<RowDataPacket[]>('SELECT name,price,is_available FROM menu_items WHERE id=? FOR SHARE',[line.menuItemId]);
          if (!menu[0]?.is_available) throw new ApiError(409,'Món thêm đã hết hoặc không còn trong thực đơn.');
          await c.execute(`INSERT INTO order_items(order_id,menu_item_id,item_name,quantity,unit_price,status,served_at,note)
            VALUES(?,?,?,?,?,?,IF(?=1,CURRENT_TIMESTAMP,NULL),?)`,[orders[0].id,line.menuItemId,menu[0].name,line.quantity,menu[0].price,line.served?'served':'preparing',line.served?1:0,line.note||null]);
        }
      }
      for (const item of before.items) {
        if (!retained.has(Number(item.id))) await c.execute('DELETE FROM order_items WHERE id=?',[item.id]);
      }
      for (const order of orders) {
        await c.execute('UPDATE orders SET total_amount=(SELECT COALESCE(SUM(quantity*unit_price),0) FROM order_items WHERE order_id=?) WHERE id=?',[order.id,order.id]);
      }
      const invoice = (await readInvoice(c,tableId))!;
      if (invoice.version !== before.version) {
        await c.execute(`INSERT INTO invoice_adjustments(invoice_code,table_id,actor_name,reason,before_snapshot,after_snapshot) VALUES(?,?,?,?,?,?)`,
          [invoice.invoiceCode,tableId,currentUser(req).displayName,input.reason || 'Điều chỉnh hóa đơn',JSON.stringify(before),JSON.stringify(invoice)]);
      }
      await c.commit();
      res.json({invoice});
    } catch(e) { await c.rollback(); throw e; } finally { c.release(); }
  }));
  app.get('/api/staff/cashier/history', requireRole('staff','cashier','manager'), route(async (req,res) => {
    const input=z.object({q:z.string().trim().max(100).default(''),offset:z.coerce.number().int().min(0).default(0),limit:z.coerce.number().int().min(1).max(50).default(30)}).parse(req.query);
    const filter='%'+input.q.replace(/[\\%_]/g,'\\$&')+'%';
    const where='WHERE invoice_code LIKE ? OR table_code LIKE ?';
    const [rows]=await db.query<RowDataPacket[]>(`SELECT id AS historyId,invoice_code AS invoiceCode,table_code AS tableCode,total_amount AS totalAmount,
      payment_method AS paymentMethod,paid_at AS paidAt,cashier_name AS cashierName FROM cashier_invoices ${where} ORDER BY paid_at DESC,id DESC LIMIT ? OFFSET ?`,[filter,filter,input.limit,input.offset]);
    const [counts]=await db.query<RowDataPacket[]>(`SELECT COUNT(*) AS total FROM cashier_invoices ${where}`,[filter,filter]);
    res.json({invoices:rows.map(r=>({...r,totalAmount:Number(r.totalAmount)})),total:Number(counts[0].total),offset:input.offset,limit:input.limit});
  }));
  app.post('/api/staff/tables/:id/discount', requireRole('cashier','manager'), route(async (req,res) => {
    const tableId=id.parse(req.params.id);
    const input=z.discriminatedUnion('mode',[
      z.object({mode:z.literal('none'),version:z.string().length(64)}).strict(),
      z.object({mode:z.literal('manual'),version:z.string().length(64),percentage:z.number().min(0).max(100).multipleOf(0.01)}).strict(),
      z.object({mode:z.literal('voucher'),version:z.string().length(64),code:z.string().trim().toUpperCase().regex(/^[A-Z0-9_-]{1,40}$/)}).strict(),
    ]).parse(req.body);
    const c=await db.getConnection();
    try {
      await c.beginTransaction();
      const [tables]=await c.query<RowDataPacket[]>('SELECT status FROM restaurant_tables WHERE id=? FOR UPDATE',[tableId]);
      if (!['dining','waiting_payment'].includes(tables[0]?.status)) throw new ApiError(409,'Chỉ áp dụng giảm giá cho hóa đơn chưa thanh toán.');
      const [orders]=await c.query<RowDataPacket[]>(`SELECT id FROM orders WHERE table_id=? AND payment_status='unpaid' AND status<>'cancelled' ORDER BY id FOR UPDATE`,[tableId]);
      const before=await readInvoice(c,tableId);
      if (!before || !orders.length) throw new ApiError(409,'Không còn hóa đơn chờ thanh toán.');
      if (before.version!==input.version) throw new ApiError(409,'Hóa đơn đã thay đổi. Vui lòng tải lại trước khi áp dụng giảm giá.');
      if (input.mode==='none' || (input.mode==='manual' && input.percentage===0)) {
        await c.execute('DELETE FROM invoice_discounts WHERE first_order_id=?',[orders[0].id]);
      } else {
        await c.execute(`INSERT INTO invoice_discounts(first_order_id,mode,percentage,voucher_code) VALUES(?,?,?,?)
          ON DUPLICATE KEY UPDATE mode=VALUES(mode),percentage=VALUES(percentage),voucher_code=VALUES(voucher_code)`,
          [orders[0].id,input.mode,input.mode==='manual'?input.percentage:0,input.mode==='voucher'?input.code:null]);
      }
      const invoice=(await readInvoice(c,tableId))!;
      if (invoice.discountError) throw new ApiError(409,invoice.discountError);
      if (invoice.version!==before.version) await c.execute(`INSERT INTO invoice_adjustments(invoice_code,table_id,actor_name,reason,before_snapshot,after_snapshot) VALUES(?,?,?,?,?,?)`,
        [invoice.invoiceCode,tableId,currentUser(req).displayName,'Cập nhật giảm giá',JSON.stringify(before),JSON.stringify(invoice)]);
      await c.commit();
      res.json({invoice});
    } catch(e) {await c.rollback();throw e;} finally {c.release();}
  }));
  app.get('/api/staff/cashier/history/:id', requireRole('staff','cashier','manager'), route(async (req,res) => {
    const [rows]=await db.query<RowDataPacket[]>('SELECT id,snapshot FROM cashier_invoices WHERE id=?',[id.parse(req.params.id)]);
    if (!rows.length) throw new ApiError(404,'Không tìm thấy hóa đơn đã lưu.');
    res.json({invoice:{...parseInvoiceSnapshot(rows[0].snapshot),historyId:Number(rows[0].id)}});
  }));
  app.post('/api/staff/tables/:id/pay', requireRole('staff','cashier','manager'), route(async (req,res) => {
    const tableId = id.parse(req.params.id);
    const method = z.enum(['cash','bank_transfer','card']).parse(req.body.paymentMethod);
    const confirmUnserved = z.boolean().default(false).parse(req.body.confirmUnserved);
    const c = await db.getConnection();
    try {
      await c.beginTransaction();
      const [tables] = await c.query<RowDataPacket[]>('SELECT status FROM restaurant_tables WHERE id=? FOR UPDATE',[tableId]);
      if (!['dining','waiting_payment'].includes(tables[0]?.status)) throw new ApiError(409,'Bàn không còn đang phục vụ hoặc chờ thanh toán.');
      const [pending] = await c.query<RowDataPacket[]>(`SELECT i.id FROM order_items i JOIN orders o ON o.id=i.order_id
        WHERE o.table_id=? AND o.payment_status='unpaid' AND o.status<>'cancelled' AND i.status<>'served' LIMIT 1`,[tableId]);
      if (pending.length && !confirmUnserved) throw new ApiError(409,'Đơn hàng còn món chưa phục vụ. Vui lòng xác nhận thanh toán ngay.');
      const [orders] = await c.query<RowDataPacket[]>('SELECT id,total_amount FROM orders WHERE table_id=? AND payment_status=\'unpaid\' AND status<>\'cancelled\' FOR UPDATE',[tableId]);
      if (!orders.length) throw new ApiError(409,'Bàn không còn hóa đơn chưa thanh toán.');
      const invoice = (await readInvoice(c,tableId))!;
      const version = z.string().length(64).optional().parse(req.body.version);
      if (version && version !== invoice.version) throw new ApiError(409,'Hóa đơn đã thay đổi. Vui lòng mở lại chi tiết trước khi thanh toán.');
      if (!invoice.items.length) throw new ApiError(409,'Hóa đơn chưa có món ăn.');
      if (invoice.discountError) throw new ApiError(409,invoice.discountError);
      const expected = z.array(z.string()).optional().parse(req.body.orderCodes);
      if (expected && JSON.stringify(expected) !== JSON.stringify(invoice.orderCodes)) throw new ApiError(409,'Hóa đơn đã thay đổi. Vui lòng mở lại chi tiết.');
      await c.execute(`UPDATE orders SET payment_status='paid',payment_method=?,paid_at=CURRENT_TIMESTAMP WHERE table_id=? AND payment_status='unpaid' AND status<>'cancelled'`,[method,tableId]);
      const [paidRows] = await c.query<RowDataPacket[]>('SELECT paid_at FROM orders WHERE id=?',[orders[0].id]);
      invoice.paidAt = new Date(paidRows[0].paid_at).toISOString();
      invoice.issuedAt = invoice.paidAt;
      invoice.paymentStatus = 'paid';
      invoice.paymentMethod = method;
      const receipt = {...invoice,cashierName:currentUser(req).displayName};
      const [saved] = await c.execute<ResultSetHeader>(`INSERT INTO cashier_invoices(invoice_code,table_id,table_code,total_amount,payment_method,paid_at,cashier_name,snapshot)
        VALUES(?,?,?,?,?,?,?,?)`,[invoice.invoiceCode,tableId,invoice.tableCode,invoice.totalAmount,method,paidRows[0].paid_at,receipt.cashierName,JSON.stringify(receipt)]);
      await c.execute(`UPDATE restaurant_tables SET status='available',guests=0,seated_at=NULL WHERE id=? AND status IN ('dining','waiting_payment')`,[tableId]);
      await c.execute('UPDATE dining_sessions SET revoked_at=NOW() WHERE table_id=? AND revoked_at IS NULL',[tableId]);
      await c.commit();
      res.json({ok:true,tableId,paymentMethod:method,totalAmount:invoice.totalAmount,invoice:{...receipt,historyId:saved.insertId}});
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
      await c.execute(`UPDATE orders SET dining_session_id=(SELECT id FROM dining_sessions WHERE table_id=? AND revoked_at IS NULL AND expires_at>NOW() ORDER BY created_at DESC LIMIT 1) WHERE id=?`,[input.tableId,order.insertId]);
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
