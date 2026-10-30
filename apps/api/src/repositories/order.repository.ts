import { db } from "../infrastructure/database.js";
import type { ResultSetHeader, RowDataPacket } from "mysql2";
import type { Pool } from 'mysql2/promise';
import { createHash, randomUUID } from "node:crypto";
import { CustomerAccessError, requireCustomerSession } from '../customer-sessions.js';

export interface CreateOrderItemInput {
  menuItemId: number;
  quantity: number;
  options?: unknown[];
  note?: string;
}

export interface CreateOrderInput {
  tableCode: string;
  customerNote?: string;
  items: CreateOrderItemInput[];
}

interface TableRow extends RowDataPacket {
  id: number;
  status: string;
}

interface MenuItemRow extends RowDataPacket {
  id: number;
  name: string;
  price: number;
  is_available: number;
}

export class OrderRepository {
  constructor(private readonly database: Pool = db) {}

  async requestPayment(orderCode: string, token?: string) {
    const c = await this.database.getConnection();
    try {
      await c.beginTransaction();
      const [order] = await c.query<RowDataPacket[]>('SELECT table_id FROM orders WHERE order_code=?',[orderCode]);
      if (!order.length) throw new Error('Không tìm thấy đơn hàng.');
      const tableId = order[0].table_id;
      const [tables] = await c.query<RowDataPacket[]>('SELECT status FROM restaurant_tables WHERE id=? FOR UPDATE',[tableId]);
      const sessionId = await requireCustomerSession(c, Number(tableId), token, true);
      const [unpaid] = await c.query<RowDataPacket[]>(`SELECT id FROM orders WHERE order_code=? AND dining_session_id=? AND payment_status='unpaid' AND status<>'cancelled'`,[orderCode,sessionId]);
      if (!unpaid.length || !['dining','waiting_payment'].includes(tables[0]?.status)) throw new Error('Đơn hàng không còn chờ thanh toán.');
      await c.execute("UPDATE restaurant_tables SET status='waiting_payment' WHERE id=?",[tableId]);
      await c.commit();
      return {ok:true};
    } catch(e) { await c.rollback(); throw e; } finally { c.release(); }
  }

  async create(input: CreateOrderInput, token?: string) {
    const connection = await this.database.getConnection();

    try {
      await connection.beginTransaction();

      const [tables] = await connection.query<TableRow[]>(
        "SELECT id, status FROM restaurant_tables WHERE code = ? FOR UPDATE",
        [input.tableCode]
      );
      const table = tables[0];
      if (!table || table.status !== 'dining') {
        throw new Error("Bàn không hợp lệ hoặc đang tạm ngưng phục vụ.");
      }
      const sessionId = await requireCustomerSession(connection, Number(table.id), token);
      const [recent] = await connection.query<RowDataPacket[]>(`SELECT COUNT(*) AS total FROM orders
        WHERE dining_session_id=? AND created_at>DATE_SUB(NOW(), INTERVAL 1 MINUTE)`,[sessionId]);
      if (Number(recent[0].total)>=10) throw new CustomerAccessError(429,'Bàn gửi quá nhiều đơn trong một phút. Vui lòng chờ rồi thử lại.');

      const lines: Array<CreateOrderItemInput & { name: string; unitPrice: number }> = [];
      let totalAmount = 0;
      for (const item of input.items) {
        const [menuItems] = await connection.query<MenuItemRow[]>(
          "SELECT id, name, price, is_available FROM menu_items WHERE id = ? FOR SHARE",
          [item.menuItemId]
        );
        const menuItem = menuItems[0];
        if (!menuItem || !menuItem.is_available) {
          throw new Error("Một món đã hết hoặc không còn phục vụ. Vui lòng tải lại thực đơn.");
        }
        const unitPrice = Number(menuItem.price);
        totalAmount += unitPrice * item.quantity;
        lines.push({ ...item, name: menuItem.name, unitPrice });
      }

      const requestId = randomUUID();
      const requestHash = createHash("sha256").update(JSON.stringify({ tableCode: input.tableCode, items: input.items })).digest("hex");
      const orderCode = `SR-${randomUUID()}`;

      const [orderResult] = await connection.execute<ResultSetHeader>(
        `INSERT INTO orders (order_code, request_id, request_hash, table_id, total_amount, customer_note, dining_session_id)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [orderCode, requestId, requestHash, table.id, totalAmount, input.customerNote ?? null, sessionId]
      );

      for (const item of lines) {
        await connection.execute(
          `INSERT INTO order_items (order_id, menu_item_id, item_name, quantity, unit_price, options_json, note)
           VALUES (?, ?, ?, ?, ?, CAST(? AS JSON), ?)`,
          [
            orderResult.insertId,
            item.menuItemId,
            item.name,
            item.quantity,
            item.unitPrice,
            JSON.stringify(item.options ?? []),
            item.note ?? null
          ]
        );
      }

      await connection.execute("UPDATE restaurant_tables SET status = 'dining' WHERE id = ?", [table.id]);

      await connection.commit();

      return {
        id: String(orderResult.insertId),
        orderCode,
        tableCode: input.tableCode,
        status: "new",
        paymentStatus: "unpaid",
        totalAmount,
        items: input.items,
        createdAt: new Date().toISOString()
      };
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  async updateStatus(orderId: string, status: string) {
    await this.database.execute("UPDATE orders SET status = ? WHERE id = ?", [status, orderId]);
    return { id: orderId, status };
  }

  async markPaidByCode(orderCode: string, providerTransactionId: string, rawPayload: unknown) {
    await this.database.execute(
      `UPDATE orders SET payment_status = 'paid' WHERE order_code = ?`,
      [orderCode]
    );
    await this.database.execute(
      `INSERT INTO payments (order_id, method, status, amount, provider_transaction_id, raw_payload, confirmed_at)
       SELECT id, 'sepay_vietqr', 'confirmed', total_amount, ?, CAST(? AS JSON), NOW()
       FROM orders WHERE order_code = ?`,
      [providerTransactionId, JSON.stringify(rawPayload), orderCode]
    );
  }
}

