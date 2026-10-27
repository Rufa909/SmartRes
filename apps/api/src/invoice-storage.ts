import { readFile } from 'node:fs/promises';
import type { Pool, RowDataPacket } from 'mysql2/promise';

export function parseInvoiceSnapshot(value: unknown): Record<string, unknown> {
  return typeof value === 'string' ? JSON.parse(value) : value as Record<string, unknown>;
}

// Additive migration, also used by the local setup command and integration tests.
export async function ensureInvoiceStorage(db: Pool) {
  const [notes] = await db.query<RowDataPacket[]>("SHOW COLUMNS FROM order_items LIKE 'note'");
  if (!notes.length) {
    await db.query('ALTER TABLE order_items ADD COLUMN note TEXT NULL').catch((error: {code?:string}) => {
      if (error.code !== 'ER_DUP_FIELDNAME') throw error;
    });
  }
  const schema = await readFile(new URL('../../../database/cashier-schema.sql', import.meta.url), 'utf8');
  for (const statement of schema.split(';').filter(s=>s.trim())) await db.query(statement);
  // Restore receipts paid before persistent invoice history was introduced.
  const [groups] = await db.query<RowDataPacket[]>(`SELECT bill.* FROM (SELECT MIN(o.id) AS firstId,o.table_id AS tableId,t.code AS tableCode,
    o.paid_at AS paidAt,o.payment_method AS paymentMethod,SUM(o.total_amount) AS totalAmount
    FROM orders o JOIN restaurant_tables t ON t.id=o.table_id
    WHERE o.payment_status='paid' AND o.status<>'cancelled' AND o.paid_at IS NOT NULL
    GROUP BY o.table_id,t.code,o.paid_at,o.payment_method) bill
    LEFT JOIN cashier_invoices h ON h.invoice_code=CONCAT('HD-',bill.firstId) WHERE h.id IS NULL`);
  for (const group of groups) {
    const [orders] = await db.query<RowDataPacket[]>(`SELECT id,order_code AS orderCode,created_at AS createdAt
      FROM orders WHERE table_id=? AND paid_at=? AND payment_method <=> ? AND payment_status='paid' AND status<>'cancelled' ORDER BY id`,[group.tableId,group.paidAt,group.paymentMethod]);
    if (!orders.length) continue;
    const [items] = await db.query<RowDataPacket[]>(`SELECT i.id,i.menu_item_id AS menuItemId,i.item_name AS name,i.quantity,i.unit_price AS unitPrice,i.status
      FROM order_items i JOIN orders o ON o.id=i.order_id
      WHERE o.table_id=? AND o.paid_at=? AND o.payment_method <=> ? AND o.payment_status='paid' AND o.status<>'cancelled' ORDER BY o.id,i.id`,[group.tableId,group.paidAt,group.paymentMethod]);
    const paidAt = new Date(group.paidAt).toISOString();
    const snapshot = {
      invoiceCode:`HD-${group.firstId}`,tableId:Number(group.tableId),tableCode:group.tableCode,guests:null,
      openedAt:orders[0].createdAt,issuedAt:paidAt,paidAt,paymentStatus:'paid',paymentMethod:group.paymentMethod,
      totalAmount:Number(group.totalAmount),pendingItems:0,cashierName:'Không ghi nhận (hóa đơn cũ)',
      orderCodes:orders.map(o=>o.orderCode),
      items:items.map(i=>({...i,quantity:Number(i.quantity),unitPrice:Number(i.unitPrice),lineTotal:Number(i.quantity)*Number(i.unitPrice)})),
    };
    await db.execute(`INSERT IGNORE INTO cashier_invoices(invoice_code,table_id,table_code,total_amount,payment_method,paid_at,cashier_name,snapshot)
      VALUES(?,?,?,?,?,?,?,?)`,[snapshot.invoiceCode,group.tableId,group.tableCode,group.totalAmount,group.paymentMethod??'unknown',group.paidAt,snapshot.cashierName,JSON.stringify(snapshot)]);
  }
}
