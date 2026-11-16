import type { Pool, RowDataPacket } from 'mysql2/promise';

const DAY_SECONDS = 86_400;
const DEFAULT_DAYS = 30;
const DEFAULT_LIMIT = 5;

export type PopularMenuItem = {
  id: number;
  name: string;
  description: string | null;
  price: number;
  category: string;
  imageUrl: string | null;
  quantity: number;
  invoiceCount: number;
};

export async function readPopularItems(
  db: Pool,
  now = Date.now(),
  days = DEFAULT_DAYS,
  limit = DEFAULT_LIMIT,
) {
  const end = Math.floor(now / 1000);
  const start = end - days * DAY_SECONDS;
  const [rows] = await db.query<RowDataPacket[]>(`SELECT
      m.id,m.name,m.description,m.price,m.image_url AS imageUrl,c.name AS category,
      SUM(item.quantity) AS quantity,COUNT(DISTINCT h.id) AS invoiceCount,
      SUM(item.quantity*item.unitPrice) AS grossAmount
    FROM cashier_invoices h
    JOIN JSON_TABLE(h.snapshot,'$.items[*]' COLUMNS(
      menuItemId BIGINT PATH '$.menuItemId' NULL ON EMPTY,
      quantity INT PATH '$.quantity' DEFAULT '0' ON EMPTY,
      unitPrice DECIMAL(12,2) PATH '$.unitPrice' DEFAULT '0' ON EMPTY
    )) AS item ON TRUE
    JOIN menu_items m ON m.id=item.menuItemId AND m.is_available=1
    JOIN categories c ON c.id=m.category_id
    WHERE h.paid_at>=FROM_UNIXTIME(?) AND h.paid_at<FROM_UNIXTIME(?)
    GROUP BY m.id,m.name,m.description,m.price,m.image_url,c.name
    HAVING quantity>0
    ORDER BY quantity DESC,invoiceCount DESC,grossAmount DESC,m.id
    LIMIT ?`, [start, end, limit]);

  const items: PopularMenuItem[] = rows.map(row => ({
    id: Number(row.id),
    name: String(row.name),
    description: row.description === null ? null : String(row.description),
    price: Number(row.price),
    category: String(row.category),
    imageUrl: row.imageUrl === null ? null : String(row.imageUrl),
    quantity: Number(row.quantity),
    invoiceCount: Number(row.invoiceCount),
  }));

  return {
    generatedAt: new Date(now).toISOString(),
    period: {
      days,
      from: new Date(start * 1000).toISOString(),
      to: new Date(end * 1000).toISOString(),
    },
    items,
  };
}
