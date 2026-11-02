import {readFile} from 'node:fs/promises';
import {z} from 'zod';
import type {Pool,PoolConnection,RowDataPacket,ResultSetHeader} from 'mysql2/promise';

export class PromotionError extends Error {constructor(public status:number,message:string){super(message);}}
const date=z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(value=>{
  const time=Date.parse(value+'T00:00:00Z');
  return Number.isFinite(time)&&new Date(time).toISOString().slice(0,10)===value&&value>='2000-01-01'&&value<='2099-12-31';
});
const time=z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);
export const promotionInput=z.object({
  name:z.string().trim().min(1).max(120),discountType:z.enum(['percentage','fixed']),
  discountValue:z.number().positive().max(999999999).multipleOf(0.01),
  maxDiscountAmount:z.number().int().positive().max(999999999).nullable().default(null),
  minBillAmount:z.number().int().min(0).max(999999999).default(0),
  isActive:z.boolean(),isAlwaysActive:z.boolean(),allDay:z.boolean(),
  startTime:time.nullable().default(null),endTime:time.nullable().default(null),
  weekdays:z.array(z.number().int().min(1).max(7)).max(7),
  startDate:date.nullable().default(null),endDate:date.nullable().default(null),
}).strict().superRefine((p,ctx)=>{
  const fail=(path:string,message:string)=>ctx.addIssue({code:'custom',path:[path],message});
  if(p.discountType==='percentage'&&p.discountValue>100)fail('discountValue','Phần trăm giảm tối đa 100%.');
  if(p.discountType==='fixed'&&!Number.isInteger(p.discountValue))fail('discountValue','Tiền giảm phải là số nguyên đồng.');
  if(new Set(p.weekdays).size!==p.weekdays.length)fail('weekdays','Ngày trong tuần bị trùng.');
  if(!p.isAlwaysActive) {
    if(!p.weekdays.length)fail('weekdays','Chọn ít nhất một ngày trong tuần.');
    if(!p.startDate||!p.endDate||p.startDate>p.endDate)fail('endDate','Chọn khoảng ngày hợp lệ.');
    if(!p.allDay&&(!p.startTime||!p.endTime||p.startTime===p.endTime))fail('endTime','Chọn giờ bắt đầu và kết thúc khác nhau.');
  }
});
export type PromotionInput=z.infer<typeof promotionInput>;
export type Promotion=PromotionInput & {id:number;version:number};
export type PromotionOrder={subtotalAmount:number;paymentStatus?:string};

/** Evaluate at payment time in Vietnam. For overnight windows, weekdays/date range belong to the starting day. */
export function evaluatePromotion(order:PromotionOrder,promotion:PromotionInput,now=new Date()) {
  const reject=(reason:string)=>({applicable:false,reason,discountAmount:0});
  if(!promotion.isActive)return reject('Chương trình đang tạm dừng.');
  if(order.paymentStatus!==undefined&&order.paymentStatus!=='unpaid')return reject('Chỉ áp dụng cho hóa đơn chưa thanh toán.');
  if(!Number.isFinite(order.subtotalAmount)||order.subtotalAmount<=0)return reject('Hóa đơn chưa có giá trị hợp lệ.');
  if(!Number.isFinite(promotion.discountValue)||promotion.discountValue<=0||(promotion.discountType==='percentage'&&promotion.discountValue>100))return reject('Giá trị giảm không hợp lệ.');
  if(order.subtotalAmount<promotion.minBillAmount)return reject(`Hóa đơn cần tối thiểu ${promotion.minBillAmount.toLocaleString('vi-VN')} đ.`);
  if(!promotion.isAlwaysActive) {
    const local=new Date(now.getTime()+7*3600000);
    let anchor=new Date(local);
    const minute=local.getUTCHours()*60+local.getUTCMinutes();
    if(!promotion.allDay) {
      if(!promotion.startTime||!promotion.endTime||promotion.startTime===promotion.endTime)return reject('Khung giờ chưa hợp lệ.');
      const minutes=(value:string)=>Number(value.slice(0,2))*60+Number(value.slice(3));
      const start=minutes(promotion.startTime),end=minutes(promotion.endTime);
      if(start<end) {if(minute<start||minute>=end)return reject('Ngoài khung giờ khuyến mãi.');}
      else {
        if(minute>=end&&minute<start)return reject('Ngoài khung giờ khuyến mãi.');
        if(minute<end)anchor=new Date(local.getTime()-86400000);
      }
    }
    const day=anchor.toISOString().slice(0,10),weekday=anchor.getUTCDay()||7;
    if(!promotion.startDate||!promotion.endDate||day<promotion.startDate||day>promotion.endDate)return reject('Ngoài khoảng ngày khuyến mãi.');
    if(!promotion.weekdays.includes(weekday))return reject('Không áp dụng vào thứ này.');
  }
  const raw=promotion.discountType==='percentage'?Math.round(order.subtotalAmount*promotion.discountValue/100):Math.round(promotion.discountValue);
  const discountAmount=Math.max(0,Math.min(order.subtotalAmount,raw,promotion.maxDiscountAmount??Number.MAX_SAFE_INTEGER));
  return {applicable:true,reason:null,discountAmount};
}
export function checkPromoApplicable(order:PromotionOrder,promotion:PromotionInput,now=new Date()) {
  return evaluatePromotion(order,promotion,now).applicable;
}

export async function ensurePromotionStorage(db:Pool) {
  const schema=await readFile(new URL('../../../database/promotions.sql',import.meta.url),'utf8');
  for(const sql of schema.split(';').filter(s=>s.trim()))await db.query(sql);
}
const fields=`id,name,discount_type AS discountType,discount_value AS discountValue,max_discount_amount AS maxDiscountAmount,
  min_bill_amount AS minBillAmount,is_active AS isActive,is_always_active AS isAlwaysActive,all_day AS allDay,
  start_time AS startTime,end_time AS endTime,weekdays,DATE_FORMAT(start_date,'%Y-%m-%d') AS startDate,DATE_FORMAT(end_date,'%Y-%m-%d') AS endDate,version`;
const normalize=(p:RowDataPacket):Promotion=>({
  id:Number(p.id),name:p.name,discountType:p.discountType,discountValue:Number(p.discountValue),
  maxDiscountAmount:p.maxDiscountAmount===null?null:Number(p.maxDiscountAmount),minBillAmount:Number(p.minBillAmount),
  isActive:Boolean(p.isActive),isAlwaysActive:Boolean(p.isAlwaysActive),allDay:Boolean(p.allDay),
  startTime:p.startTime,endTime:p.endTime,weekdays:typeof p.weekdays==='string'?JSON.parse(p.weekdays):p.weekdays,
  startDate:p.startDate,endDate:p.endDate,version:Number(p.version),
});
export async function readPromotions(db:Pool|PoolConnection,activeOnly=false) {
  const [rows]=await db.query<RowDataPacket[]>(`SELECT ${fields} FROM promotions ${activeOnly?'WHERE is_active=1':''} ORDER BY id DESC`);
  return rows.map(normalize);
}
export async function readPromotion(c:PoolConnection,id:number) {
  const [rows]=await c.query<RowDataPacket[]>(`SELECT ${fields} FROM promotions WHERE id=? FOR SHARE`,[id]);
  return rows.length?normalize(rows[0]):null;
}
export async function savePromotion(db:Pool,input:PromotionInput,id?:number,version?:number) {
  const c=await db.getConnection();
  try {
    await c.beginTransaction();
    const values=[input.name,input.discountType,input.discountValue,input.maxDiscountAmount,input.minBillAmount,input.isActive,input.isAlwaysActive,input.allDay,input.startTime,input.endTime,JSON.stringify(input.weekdays),input.startDate,input.endDate];
    if(id===undefined) {
      const [created]=await c.execute<ResultSetHeader>(`INSERT INTO promotions(name,discount_type,discount_value,max_discount_amount,min_bill_amount,is_active,is_always_active,all_day,start_time,end_time,weekdays,start_date,end_date) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)`,values);
      id=created.insertId;
    } else {
      if(version===undefined)throw new PromotionError(400,'Thiếu phiên bản chương trình.');
      const [changed]=await c.execute<ResultSetHeader>(`UPDATE promotions SET name=?,discount_type=?,discount_value=?,max_discount_amount=?,min_bill_amount=?,is_active=?,is_always_active=?,all_day=?,start_time=?,end_time=?,weekdays=?,start_date=?,end_date=?,version=version+1 WHERE id=? AND version=?`,[...values,id,version]);
      if(!changed.affectedRows)throw new PromotionError(409,'Chương trình đã thay đổi hoặc không tồn tại. Tải lại rồi thử lại.');
    }
    const promotion=(await readPromotion(c,id))!;
    await c.commit();return {promotion};
  } catch(error){await c.rollback();throw error;} finally {c.release();}
}
export async function togglePromotion(db:Pool,id:number,version:number,isActive:boolean) {
  const [changed]=await db.execute<ResultSetHeader>('UPDATE promotions SET is_active=?,version=version+1 WHERE id=? AND version=?',[isActive,id,version]);
  if(!changed.affectedRows)throw new PromotionError(409,'Chương trình đã thay đổi hoặc không tồn tại. Tải lại rồi thử lại.');
  return {ok:true};
}
