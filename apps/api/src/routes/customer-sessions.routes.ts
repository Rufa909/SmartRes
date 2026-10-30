import { Router } from 'express';
import { z } from 'zod';
import type { Pool, RowDataPacket } from 'mysql2/promise';
import { CustomerAccessError, joinDiningSession, requireCustomerSession } from '../customer-sessions.js';

export function createCustomerSessionsRouter(db: Pool) {
  const router=Router();
  router.post('/join',(req,res,next)=>{
    void (async()=>{
      const input=z.object({tableCode:z.string().trim().min(1).max(32)}).parse(req.body);
      res.set('Cache-Control','no-store').json(await joinDiningSession(db,input.tableCode));
    })().catch(next);
  });
  router.get('/check/:tableCode',(req,res,next)=>{
    void (async()=>{
      const c=await db.getConnection();
      try {
        const [tables]=await c.query<RowDataPacket[]>('SELECT id FROM restaurant_tables WHERE code=?',[req.params.tableCode]);
        if (!tables.length) throw new CustomerAccessError(401,'Phiên không hợp lệ.');
        await requireCustomerSession(c,Number(tables[0].id),req.header('authorization')?.replace(/^Bearer /,''),true);
        res.set('Cache-Control','no-store').json({ok:true});
      } finally {c.release();}
    })().catch(next);
  });
  return router;
}
