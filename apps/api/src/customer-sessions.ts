import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import type { Pool, PoolConnection, RowDataPacket } from 'mysql2/promise';

export class CustomerAccessError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

export async function ensureCustomerSessions(db: Pool) {
  const schema = await readFile(new URL('../../../database/customer-sessions.sql', import.meta.url), 'utf8');
  for (const sql of schema.split(';').filter(s => s.trim())) await db.query(sql);
  const [columns] = await db.query<RowDataPacket[]>("SHOW COLUMNS FROM orders LIKE 'dining_session_id'");
  if (!columns.length) await db.query('ALTER TABLE orders ADD COLUMN dining_session_id CHAR(36) NULL').catch((e: {code?: string}) => {
    if (e.code !== 'ER_DUP_FIELDNAME') throw e;
  });
}

// Caller holds the table lock, shared by seating, ordering, rotation and payment.
export async function openDiningSession(c: PoolConnection, tableId: number, rotate = false) {
  if (rotate) {
    const [existing]=await c.query<RowDataPacket[]>('SELECT id FROM dining_sessions WHERE table_id=? AND revoked_at IS NULL ORDER BY created_at DESC LIMIT 1',[tableId]);
    if (existing.length) {
      const sessionId=String(existing[0].id);
      await c.execute('DELETE FROM customer_session_tokens WHERE session_id=?',[sessionId]);
      await c.execute('UPDATE dining_sessions SET expires_at=DATE_ADD(NOW(), INTERVAL 8 HOUR) WHERE id=?',[sessionId]);
      const [rows]=await c.query<RowDataPacket[]>('SELECT expires_at AS expiresAt FROM dining_sessions WHERE id=?',[sessionId]);
      return {sessionId,expiresAt:rows[0].expiresAt};
    }
  }
  await c.execute('UPDATE dining_sessions SET revoked_at=NOW() WHERE table_id=? AND revoked_at IS NULL', [tableId]);
  const sessionId = randomUUID();
  // Cột join_code được giữ tương thích DB cũ; không dùng mã PIN trong luồng QR.
  await c.execute(`INSERT INTO dining_sessions(id,table_id,join_code,expires_at) VALUES(?,?,?,DATE_ADD(NOW(), INTERVAL 8 HOUR))`,
    [sessionId, tableId, '']);
  const [rows] = await c.query<RowDataPacket[]>('SELECT expires_at AS expiresAt FROM dining_sessions WHERE id=?', [sessionId]);
  return {sessionId, expiresAt: rows[0].expiresAt};
}

export const hashCustomerToken = (token: string) => createHash('sha256').update(token).digest('hex');

export async function requireCustomerSession(c: PoolConnection, tableId: number, token: string | undefined, allowWaiting = false) {
  if (!token || !/^[a-f0-9]{64}$/.test(token)) throw new CustomerAccessError(401, 'Vui lòng quét QR trên bàn để bắt đầu gọi món.');
  const [rows] = await c.query<RowDataPacket[]>(`SELECT s.id FROM customer_session_tokens k
    JOIN dining_sessions s ON s.id=k.session_id JOIN restaurant_tables t ON t.id=s.table_id
    WHERE k.token_hash=? AND s.table_id=? AND s.revoked_at IS NULL AND s.expires_at>NOW()
    AND (t.status='dining' OR (?=1 AND t.status='waiting_payment'))`, [hashCustomerToken(token), tableId, allowWaiting ? 1 : 0]);
  if (!rows.length) throw new CustomerAccessError(401, 'Phiên gọi món đã kết thúc hoặc không thuộc bàn này. Vui lòng liên hệ nhân viên.');
  return String(rows[0].id);
}

export async function joinDiningSession(db: Pool, tableCode: string) {
  const c = await db.getConnection();
  try {
    await c.beginTransaction();
    const [tables] = await c.query<RowDataPacket[]>('SELECT id,status FROM restaurant_tables WHERE code=? FOR UPDATE', [tableCode]);
    if (tables[0]?.status !== 'dining') throw new CustomerAccessError(403, 'Bàn chưa mở hoặc đang chờ thanh toán. Vui lòng liên hệ nhân viên.');
    const [sessions] = await c.query<RowDataPacket[]>(`SELECT id
      FROM dining_sessions WHERE table_id=? AND revoked_at IS NULL AND expires_at>NOW() ORDER BY created_at DESC LIMIT 1`, [tables[0].id]);
    // Tự cấp phiên cho bàn đang phục vụ từ bản cũ hoặc khi phiên đã hết hạn.
    const sessionId = sessions[0]?.id || (await openDiningSession(c,Number(tables[0].id),true)).sessionId;
    const token = randomBytes(32).toString('hex');
    await c.execute('INSERT INTO customer_session_tokens(token_hash,session_id) VALUES(?,?)', [hashCustomerToken(token), sessionId]);
    await c.commit();
    return {token, tableCode};
  } catch (e) { await c.rollback(); throw e; } finally { c.release(); }
}
