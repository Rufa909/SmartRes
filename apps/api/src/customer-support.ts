import { readFile } from 'node:fs/promises';
import { Router } from 'express';
import { z } from 'zod';
import type { Pool, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { CustomerAccessError, requireCustomerSession } from './customer-sessions.js';

export async function ensureCustomerSupportStorage(db: Pool) {
  const schema = await readFile(new URL('../../../database/customer-support.sql', import.meta.url), 'utf8');
  for (const sql of schema.split(';').filter(statement => statement.trim())) await db.query(sql);
}

export function createCustomerSupportRouter(db: Pool) {
  const router = Router();
  router.post('/:tableCode/request', (req,res,next) => {
    void (async () => {
      const tableCode=z.string().trim().min(1).max(32).parse(req.params.tableCode);
      const token=req.header('authorization')?.replace(/^Bearer /,'');
      const c=await db.getConnection();
      try {
        await c.beginTransaction();
        const [tables]=await c.query<RowDataPacket[]>('SELECT id FROM restaurant_tables WHERE code=? FOR UPDATE',[tableCode]);
        if(!tables.length)throw new CustomerAccessError(404,'Không tìm thấy bàn này.');
        const tableId=Number(tables[0].id);
        const sessionId=await requireCustomerSession(c,tableId,token,true);
        const [pending]=await c.query<RowDataPacket[]>(`SELECT id FROM customer_service_requests
          WHERE dining_session_id=? AND status='pending' ORDER BY id DESC LIMIT 1`,[sessionId]);
        if(pending.length) {
          await c.commit();
          res.set('Cache-Control','no-store').json({ok:true,requestId:Number(pending[0].id),alreadyPending:true});
          return;
        }
        const [created]=await c.execute<ResultSetHeader>(`INSERT INTO customer_service_requests(table_id,dining_session_id) VALUES(?,?)`,[tableId,sessionId]);
        await c.commit();
        res.set('Cache-Control','no-store').status(201).json({ok:true,requestId:Number(created.insertId)});
      } catch(error) {await c.rollback();throw error;} finally {c.release();}
    })().catch(next);
  });
  return router;
}
