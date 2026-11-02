import {z} from 'zod';
import type {Pool,RowDataPacket} from 'mysql2/promise';
import {overviewPeriod} from './management-overview.js';

export async function ensureItemTimingStorage(db:Pool) {
  for(const column of ['created_at','cooking_started_at','completed_at','served_at']) {
    const [columns]=await db.query<RowDataPacket[]>('SHOW COLUMNS FROM order_items LIKE ?',[column]);
    // Existing items have unknown timestamps; never backfill them with migration time.
    if(!columns.length)await db.query(`ALTER TABLE order_items ADD COLUMN ${column} TIMESTAMP NULL DEFAULT NULL`).catch((error:{code?:string})=>{
      if(error.code!=='ER_DUP_FIELDNAME')throw error;
    });
  }
  const [createdColumn]=await db.query<RowDataPacket[]>("SHOW COLUMNS FROM order_items LIKE 'created_at'");
  if(!String(createdColumn[0].Default).toLowerCase().startsWith('current_timestamp')) {
    await db.query('ALTER TABLE order_items MODIFY COLUMN created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP');
  }
  const [indexes]=await db.query<RowDataPacket[]>("SHOW INDEX FROM order_items WHERE Key_name='idx_item_timing_created'");
  if(!indexes.length)await db.query('CREATE INDEX idx_item_timing_created ON order_items(created_at,id)').catch((error:{code?:string})=>{
    if(error.code!=='ER_DUP_KEYNAME')throw error;
  });
}

const epoch=(value:unknown)=>value===null || value===undefined ? null : Number(value);
const duration=(from:number|null,to:number|null)=>from!==null && to!==null && to>=from ? Math.floor(to-from) : null;
export function itemTiming(row:RowDataPacket,now:number) {
  const created=epoch(row.createdEpoch),cooking=epoch(row.cookingEpoch),completed=epoch(row.completedEpoch),served=epoch(row.servedEpoch);
  const iso=(value:number|null)=>value===null ? null : new Date(value*1000).toISOString();
  const start=row.status==='preparing'?created:row.status==='cooking'?cooking:row.status==='completed'?completed:null;
  return {
    id:Number(row.id),tableCode:row.tableCode,orderCode:row.orderCode,name:row.name,quantity:Number(row.quantity),status:row.status,note:row.note,
    paymentStatus:row.paymentStatus,
    createdAt:iso(created),cookingStartedAt:iso(cooking),completedAt:iso(completed),servedAt:iso(served),
    durations:{waitingKitchenSeconds:duration(created,cooking),cookingSeconds:duration(cooking,completed),waitingServiceSeconds:duration(completed,served),totalSeconds:duration(created,served)},
    currentStageElapsedSeconds:duration(start,now),
    totalElapsedSeconds:row.status==='served'?duration(created,served):duration(created,now),
  };
}

export async function readItemTimings(db:Pool,query:unknown) {
  const input=z.object({status:z.enum(['pending','preparing','cooking','completed','served']).optional(),q:z.string().trim().max(100).default(''),date:z.string().optional(),offset:z.coerce.number().int().min(0).max(1000000).default(0),limit:z.coerce.number().int().min(1).max(100).default(30)}).parse(query);
  const clauses=["o.status<>'cancelled'"];
  const params:(string|number)[]=[];
  if(input.q) {
    clauses.push("(i.item_name LIKE ? ESCAPE '=' OR t.code LIKE ? ESCAPE '=' OR o.order_code LIKE ? ESCAPE '=')");
    const pattern=`%${input.q.replace(/[=%_]/g,'=$&')}%`;params.push(pattern,pattern,pattern);
  }
  const join='FROM order_items i JOIN orders o ON o.id=i.order_id JOIN restaurant_tables t ON t.id=o.table_id';
  const c=await db.getConnection();
  try {
    await c.beginTransaction();
    const [clock]=await c.query<RowDataPacket[]>('SELECT UNIX_TIMESTAMP(CURRENT_TIMESTAMP) AS now');
    const now=Number(clock[0].now);
    const day=input.date??new Date(now*1000+7*3600000).toISOString().slice(0,10);
    const period=overviewPeriod({from:day,to:day});
    clauses.push('i.created_at>=FROM_UNIXTIME(?) AND i.created_at<FROM_UNIXTIME(?)');
    params.push(period.start,period.end);
    const [summary]=await c.query<RowDataPacket[]>(`SELECT i.status,COUNT(*) AS count ${join} WHERE ${clauses.join(' AND ')} GROUP BY i.status`,params);
    const counts=Object.fromEntries(['preparing','cooking','completed','served'].map(status=>[status,Number(summary.find(r=>r.status===status)?.count??0)]));
    const total=input.status==='pending'?counts.preparing+counts.cooking+counts.completed:input.status?counts[input.status]:Object.values(counts).reduce((sum,value)=>sum+value,0);
    if(input.status==='pending') clauses.push("i.status IN ('preparing','cooking','completed')");
    else if(input.status) {clauses.push('i.status=?');params.push(input.status);}
    const ordering=input.status==='served'?'i.served_at DESC,i.id DESC':'i.created_at ASC,i.id ASC';
    const [items]=await c.query<RowDataPacket[]>(`SELECT i.id,t.code AS tableCode,o.order_code AS orderCode,i.item_name AS name,i.quantity,i.status,i.note,o.payment_status AS paymentStatus,
      UNIX_TIMESTAMP(i.created_at) AS createdEpoch,UNIX_TIMESTAMP(i.cooking_started_at) AS cookingEpoch,
      UNIX_TIMESTAMP(i.completed_at) AS completedEpoch,UNIX_TIMESTAMP(i.served_at) AS servedEpoch
      ${join} WHERE ${clauses.join(' AND ')} ORDER BY ${ordering} LIMIT ? OFFSET ?`,[...params,input.limit,input.offset]);
    await c.commit();
    return {items:items.map(item=>itemTiming(item,now)),counts,total,offset:input.offset,limit:input.limit,date:period.from,generatedAt:new Date(now*1000).toISOString()};
  } catch(error){await c.rollback();throw error;} finally {c.release();}
}
