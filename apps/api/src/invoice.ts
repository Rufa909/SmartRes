import type { PoolConnection, RowDataPacket } from 'mysql2/promise';
import { createHash } from 'node:crypto';
import { invoiceDiscount } from './invoice-discount.js';

// Read using the caller's transaction so the preview/receipt has one consistent snapshot.
export async function readInvoice(c: PoolConnection, tableId: number) {
  const [tables] = await c.query<RowDataPacket[]>('SELECT code,guests FROM restaurant_tables WHERE id=?',[tableId]);
  const [orders] = await c.query<RowDataPacket[]>(`SELECT id,order_code AS orderCode,total_amount AS totalAmount,created_at AS createdAt
    FROM orders WHERE table_id=? AND payment_status='unpaid' AND status<>'cancelled' ORDER BY id`,[tableId]);
  if (!tables.length || !orders.length) return null;
  const [items] = await c.query<RowDataPacket[]>(`SELECT i.id,i.menu_item_id AS menuItemId,i.item_name AS name,i.quantity,i.unit_price AS unitPrice,i.status,i.note
    FROM order_items i JOIN orders o ON o.id=i.order_id
    WHERE o.table_id=? AND o.payment_status='unpaid' AND o.status<>'cancelled' ORDER BY o.id,i.id`,[tableId]);
  const discount = await invoiceDiscount(c,Number(orders[0].id),orders.reduce((sum,o)=>sum+Number(o.totalAmount),0));
  return {
    invoiceCode: `HD-${orders[0].id}`, tableId, tableCode: tables[0].code, guests: Number(tables[0].guests),
    version: createHash('sha256').update(JSON.stringify({orders:orders.map(o=>[o.id,Number(o.totalAmount)]),items:items.map(i=>[i.id,i.name,Number(i.quantity),Number(i.unitPrice),i.note]),discount})).digest('hex'),
    openedAt: orders[0].createdAt, issuedAt: new Date().toISOString(), paidAt: null as string | null,
    paymentStatus: 'unpaid', paymentMethod: null as string | null,
    orderCodes: orders.map(o=>o.orderCode as string),
    ...discount,
    pendingItems: items.filter(i=>i.status!=='served').length,
    items: items.map(i=>({id:Number(i.id),menuItemId:Number(i.menuItemId),name:String(i.name),note:i.note as string | null,status:String(i.status),quantity:Number(i.quantity),unitPrice:Number(i.unitPrice),lineTotal:Number(i.quantity)*Number(i.unitPrice)}))
  };
}
