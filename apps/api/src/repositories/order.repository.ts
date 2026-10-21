import { db } from "../infrastructure/database.js";
import type { ResultSetHeader, RowDataPacket } from "mysql2";
import { createHash, randomUUID } from "node:crypto";

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
  async create(input: CreateOrderInput) {
    const connection = await db.getConnection();

    try {
      await connection.beginTransaction();

      const [tables] = await connection.query<TableRow[]>(
        "SELECT id, status FROM restaurant_tables WHERE code = ? FOR UPDATE",
        [input.tableCode]
      );
      const table = tables[0];
      if (!table || table.status === "disabled") {
        throw new Error("Bàn không hợp lệ hoặc đang tạm ngưng phục vụ.");
      }

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
        `INSERT INTO orders (order_code, request_id, request_hash, table_id, total_amount, customer_note)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [orderCode, requestId, requestHash, table.id, totalAmount, input.customerNote ?? null]
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
    await db.execute("UPDATE orders SET status = ? WHERE id = ?", [status, orderId]);
    return { id: orderId, status };
  }

  async markPaidByCode(orderCode: string, providerTransactionId: string, rawPayload: unknown) {
    await db.execute(
      `UPDATE orders SET payment_status = 'paid' WHERE order_code = ?`,
      [orderCode]
    );
    await db.execute(
      `INSERT INTO payments (order_id, method, status, amount, provider_transaction_id, raw_payload, confirmed_at)
       SELECT id, 'sepay_vietqr', 'confirmed', total_amount, ?, CAST(? AS JSON), NOW()
       FROM orders WHERE order_code = ?`,
      [providerTransactionId, JSON.stringify(rawPayload), orderCode]
    );
  }
}

