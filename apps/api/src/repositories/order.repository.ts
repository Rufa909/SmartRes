import { db } from "../infrastructure/database.js";
import type { ResultSetHeader } from "mysql2";

export interface CreateOrderItemInput {
  menuItemId: string;
  name: string;
  quantity: number;
  unitPrice: number;
  options?: unknown[];
  note?: string;
}

export interface CreateOrderInput {
  tableId: string;
  customerNote?: string;
  items: CreateOrderItemInput[];
}

export class OrderRepository {
  async create(input: CreateOrderInput) {
    const connection = await db.getConnection();
    const totalAmount = input.items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
    const orderCode = `SR${Date.now()}`;

    try {
      await connection.beginTransaction();

      const [orderResult] = await connection.execute<ResultSetHeader>(
        `INSERT INTO orders (order_code, table_id, total_amount, customer_note)
         VALUES (?, ?, ?, ?)`,
        [orderCode, input.tableId, totalAmount, input.customerNote ?? null]
      );

      for (const item of input.items) {
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

      await connection.execute(
        "UPDATE restaurant_tables SET status = 'dining' WHERE id = ?",
        [input.tableId]
      );

      await connection.commit();

      return {
        id: String(orderResult.insertId),
        orderCode,
        tableId: input.tableId,
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

