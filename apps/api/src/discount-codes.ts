import {readFile} from 'node:fs/promises';
import {z} from 'zod';
import type {Pool,PoolConnection,RowDataPacket,ResultSetHeader} from 'mysql2/promise';
import {promotionInput,evaluatePromotion,type PromotionInput} from './promotions.js';

export class DiscountCodeError extends Error {constructor(public status:number,message:string){super(message);}}
export const discountCodeText=z.string().trim().toUpperCase().regex(/^[A-Z0-9_-]{1,64}$/);
export const discountCodeInput=z.object({
  discountName:z.string().trim().min(1).max(120),totalQuantity:z.number().int().min(1).max(1000000000),
  codeMode:z.enum(['manual','auto']),discountCode:discountCodeText.optional(),
  discountType:z.enum(['percentage','fixed']),discountPercent:z.number().nullable().default(null),fixedAmount:z.number().nullable().default(null),
  maxDiscountAmount:z.number().int().positive().max(999999999).nullable().default(null),minOrderValue:z.number().int().min(0).max(999999999).default(0),
  isActive:z.boolean(),isAlwaysActive:z.boolean(),allDay:z.boolean(),startTime:z.string().nullable().default(null),endTime:z.string().nullable().default(null),
  weekdays:z.array(z.number()),startDate:z.string().nullable().default(null),endDate:z.string().nullable().default(null),
}).strict().superRefine((d,ctx)=>{
  if(d.codeMode==='manual'&&!d.discountCode)ctx.addIssue({code:'custom',path:['discountCode'],message:'Nhập mã giảm giá.'});
  const checked=promotionInput.safeParse(toPromotion(d));
  if(!checked.success)for(const issue of checked.error.issues)ctx.addIssue({code:'custom',path:issue.path,message:issue.message});
});
export type DiscountCodeInput=z.infer<typeof discountCodeInput>;
export type DiscountCode=DiscountCodeInput & {id:number;discountCode:string;usedQuantity:number;remainingQuantity:number;version:number};
function toPromotion(d:DiscountCodeInput):PromotionInput {
  return {name:d.discountName,discountType:d.discountType,discountValue:(d.discountType==='percentage'?d.discountPercent:d.fixedAmount)??0,
    maxDiscountAmount:d.maxDiscountAmount,minBillAmount:d.minOrderValue,isActive:d.isActive,isAlwaysActive:d.isAlwaysActive,allDay:d.allDay,
    startTime:d.startTime,endTime:d.endTime,weekdays:d.weekdays,startDate:d.startDate,endDate:d.endDate};
}
export function generateDiscountCode(discountName:string,totalQuantity:number,discountValue:number) {
  const words=discountName.normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[đĐ]/g,'D').toUpperCase().match(/[A-Z0-9]+/g)??[];
  if(!words.length||!Number.isInteger(totalQuantity)||totalQuantity<1||!Number.isFinite(discountValue)||discountValue<=0)throw new DiscountCodeError(400,'Tên hoặc giá trị sinh mã chưa hợp lệ.');
  const suffix=`${totalQuantity}${discountValue.toString().replace('.','')}`;
  return words.map(word=>word[0]).join('').slice(0,64-suffix.length)+suffix;
}
export async function ensureDiscountCodeStorage(db:Pool) {
  const schema=await readFile(new URL('../../../database/discount-codes.sql',import.meta.url),'utf8');
  for(const sql of schema.split(';').filter(s=>s.trim()))await db.query(sql);
}
const fields=`id,discount_name AS discountName,discount_code AS discountCode,code_mode AS codeMode,total_quantity AS totalQuantity,used_quantity AS usedQuantity,
  discount_type AS discountType,discount_percent AS discountPercent,fixed_amount AS fixedAmount,max_discount_amount AS maxDiscountAmount,min_order_value AS minOrderValue,
  is_active AS isActive,is_always_active AS isAlwaysActive,all_day AS allDay,start_time AS startTime,end_time AS endTime,weekdays,
  DATE_FORMAT(start_date,'%Y-%m-%d') AS startDate,DATE_FORMAT(end_date,'%Y-%m-%d') AS endDate,version`;
const normalize=(r:RowDataPacket):DiscountCode=>({
  id:Number(r.id),discountName:r.discountName,discountCode:r.discountCode,codeMode:r.codeMode,
  totalQuantity:Number(r.totalQuantity),usedQuantity:Number(r.usedQuantity),remainingQuantity:Number(r.totalQuantity)-Number(r.usedQuantity),
  discountType:r.discountType,discountPercent:r.discountPercent===null?null:Number(r.discountPercent),fixedAmount:r.fixedAmount===null?null:Number(r.fixedAmount),
  maxDiscountAmount:r.maxDiscountAmount===null?null:Number(r.maxDiscountAmount),minOrderValue:Number(r.minOrderValue),
  isActive:Boolean(r.isActive),isAlwaysActive:Boolean(r.isAlwaysActive),allDay:Boolean(r.allDay),startTime:r.startTime,endTime:r.endTime,
  weekdays:typeof r.weekdays==='string'?JSON.parse(r.weekdays):r.weekdays,startDate:r.startDate,endDate:r.endDate,version:Number(r.version),
});
export async function readDiscountCodes(db:Pool) {
  const [rows]=await db.query<RowDataPacket[]>(`SELECT ${fields} FROM discount_codes ORDER BY id DESC`);
  return {discounts:rows.map(normalize)};
}
export async function findDiscountCode(c:PoolConnection,value:number|string,lock:'share'|'update'='share') {
  const [rows]=await c.query<RowDataPacket[]>(`SELECT ${fields} FROM discount_codes WHERE ${typeof value==='number'?'id':'discount_code'}=? FOR ${lock==='update'?'UPDATE':'SHARE'}`,[value]);
  return rows.length?normalize(rows[0]):null;
}
export function validateDiscountCode(discount:DiscountCode|null,orderTotalAmount:number,now=new Date()) {
  const reject=(reason:string)=>({applicable:false,reason,discountAmount:0});
  if(!discount)return reject('Mã giảm giá không tồn tại.');
  if(!discount.isActive)return reject('Mã bị khóa.');
  // Time is checked before quota and minimum order value.
  const time=evaluatePromotion({subtotalAmount:Math.max(1,orderTotalAmount),paymentStatus:'unpaid'},{...toPromotion(discount),minBillAmount:0},now);
  if(!time.applicable)return reject(time.reason==='Ngoài khoảng ngày khuyến mãi.'?'Mã hết hạn hoặc chưa đến ngày áp dụng.':`Mã không hợp lệ: ${time.reason}`);
  if(discount.usedQuantity>=discount.totalQuantity)return reject('Mã đã hết lượt.');
  if(!Number.isFinite(orderTotalAmount)||orderTotalAmount<=0)return reject('Giá trị hóa đơn không hợp lệ.');
  if(orderTotalAmount<discount.minOrderValue)return reject(`Đơn chưa đủ giá trị tối thiểu ${discount.minOrderValue.toLocaleString('vi-VN')} đ.`);
  return evaluatePromotion({subtotalAmount:orderTotalAmount,paymentStatus:'unpaid'},toPromotion(discount),now);
}
export async function saveDiscountCode(db:Pool,input:DiscountCodeInput,id?:number,version?:number) {
  const code=input.codeMode==='auto'?generateDiscountCode(input.discountName,input.totalQuantity,(input.discountType==='percentage'?input.discountPercent:input.fixedAmount)!):input.discountCode!;
  const c=await db.getConnection();
  try{
    await c.beginTransaction();
    if(id!==undefined){
      const current=await findDiscountCode(c,id,'update');
      if(!current)throw new DiscountCodeError(404,'Không tìm thấy mã giảm giá.');
      if(current.version!==version)throw new DiscountCodeError(409,'Mã đã thay đổi. Tải lại rồi thử lại.');
      if(input.totalQuantity<current.usedQuantity)throw new DiscountCodeError(400,'Số lượng phát hành không thể nhỏ hơn số lượt đã dùng.');
    }
    const values=[input.discountName,code,input.codeMode,input.totalQuantity,input.discountType,input.discountType==='percentage'?input.discountPercent:null,input.discountType==='fixed'?input.fixedAmount:null,input.maxDiscountAmount,input.minOrderValue,input.isActive,input.isAlwaysActive,input.allDay,input.startTime,input.endTime,JSON.stringify(input.weekdays),input.startDate,input.endDate];
    if(id===undefined){
      const [created]=await c.execute<ResultSetHeader>(`INSERT INTO discount_codes(discount_name,discount_code,code_mode,total_quantity,discount_type,discount_percent,fixed_amount,max_discount_amount,min_order_value,is_active,is_always_active,all_day,start_time,end_time,weekdays,start_date,end_date) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,values);
      id=created.insertId;
    }else await c.execute('UPDATE discount_codes SET discount_name=?,discount_code=?,code_mode=?,total_quantity=?,discount_type=?,discount_percent=?,fixed_amount=?,max_discount_amount=?,min_order_value=?,is_active=?,is_always_active=?,all_day=?,start_time=?,end_time=?,weekdays=?,start_date=?,end_date=?,version=version+1 WHERE id=?',[...values,id]);
    const discount=(await findDiscountCode(c,id))!;
    await c.commit();return {discount};
  }catch(error){await c.rollback();if((error as {code?:string}).code==='ER_DUP_ENTRY')throw new DiscountCodeError(409,'Mã giảm giá đã tồn tại. Chọn mã khác hoặc đổi quy luật sinh mã.');throw error;}finally{c.release();}
}
export async function toggleDiscountCode(db:Pool,id:number,version:number,isActive:boolean) {
  const [result]=await db.execute<ResultSetHeader>('UPDATE discount_codes SET is_active=?,version=version+1 WHERE id=? AND version=?',[isActive,id,version]);
  if(!result.affectedRows)throw new DiscountCodeError(409,'Mã đã thay đổi hoặc không tồn tại. Tải lại rồi thử lại.');
  return {ok:true};
}
export async function lockInvoiceDiscountCode(c:PoolConnection,firstOrderId:number) {
  const [rows]=await c.query<RowDataPacket[]>('SELECT discount_id AS discountId FROM invoice_discount_codes WHERE first_order_id=? FOR UPDATE',[firstOrderId]);
  if(rows.length)await findDiscountCode(c,Number(rows[0].discountId),'update');
}
export async function redeemInvoiceDiscountCode(c:PoolConnection,firstOrderId:number,subtotal:number,invoiceCode:string) {
  const [rows]=await c.query<RowDataPacket[]>('SELECT discount_id AS discountId FROM invoice_discount_codes WHERE first_order_id=?',[firstOrderId]);
  if(!rows.length)return;
  const discount=await findDiscountCode(c,Number(rows[0].discountId),'update');
  const result=validateDiscountCode(discount,subtotal);
  if(!result.applicable)throw new DiscountCodeError(409,result.reason!);
  const [changed]=await c.execute<ResultSetHeader>('UPDATE discount_codes SET used_quantity=used_quantity+1 WHERE id=? AND used_quantity<total_quantity AND is_active=1',[discount!.id]);
  if(!changed.affectedRows)throw new DiscountCodeError(409,'Mã đã hết lượt hoặc bị khóa.');
  await c.execute('INSERT INTO discount_redemptions(discount_id,first_order_id,invoice_code) VALUES(?,?,?)',[discount!.id,firstOrderId,invoiceCode]);
}
