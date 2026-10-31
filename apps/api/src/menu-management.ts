import {z} from 'zod';
import type {Pool,PoolConnection,RowDataPacket,ResultSetHeader} from 'mysql2/promise';
import type {AuthUser} from './auth.js';

export class MenuError extends Error {constructor(public status:number,message:string){super(message);}}
const version=z.number().int().positive().max(Number.MAX_SAFE_INTEGER);
const imageUrl=z.string().trim().max(2048).refine(value=>{
  if(!value)return true;
  try {const url=new URL(value);return ['http:','https:'].includes(url.protocol)&&!url.username&&!url.password;} catch {return false;}
},'Ảnh phải là URL http/https hợp lệ.');
export const menuInput=z.object({
  name:z.string().trim().min(1).max(160),categoryId:z.number().int().positive(),
  price:z.number().int().min(0).max(999999999),description:z.string().trim().max(2000).default(''),
  emoji:z.string().trim().min(1).max(20).default('🍽️'),imageUrl:imageUrl.default(''),available:z.boolean(),
});
export const categoryInput=z.object({name:z.string().trim().min(1).max(120),sortOrder:z.number().int().min(0).max(9999)});
export const updateMenuInput=menuInput.extend({version});
export const updateCategoryInput=categoryInput.extend({version});
export const availabilityInput=z.object({version,available:z.boolean()});

const fields='id,category_id AS categoryId,name,description,emoji,image_url AS imageUrl,price,is_available AS available,version';
const normalize=(row:RowDataPacket)=>({...row,id:Number(row.id),categoryId:Number(row.categoryId),price:Number(row.price),available:Boolean(row.available),version:Number(row.version)});
async function audit(c:PoolConnection,actor:AuthUser,action:string,id:number,before:unknown,after:unknown) {
  await c.execute('INSERT INTO menu_audit(actor_id,actor_name,action,entity_id,before_data,after_data) VALUES(?,?,?,?,?,?)',
    [actor.id,actor.displayName,action,id,before===null?null:JSON.stringify(before),JSON.stringify(after)]);
}
async function transaction<T>(db:Pool,fn:(c:PoolConnection)=>Promise<T>) {
  const c=await db.getConnection();
  try {await c.beginTransaction();const value=await fn(c);await c.commit();return value;}
  catch(e){await c.rollback();if((e as {code?:string}).code==='ER_DUP_ENTRY')throw new MenuError(409,'Tên món hoặc danh mục đã tồn tại.');throw e;}
  finally {c.release();}
}

export async function readManagedMenu(db:Pool) {
  return transaction(db,async c=>{
    const [items]=await c.query<RowDataPacket[]>(`SELECT ${fields} FROM menu_items ORDER BY category_id,id`);
    const [categories]=await c.query<RowDataPacket[]>('SELECT id,name,sort_order AS sortOrder,version FROM categories ORDER BY sort_order,id');
    return {items:items.map(normalize),categories:categories.map(r=>({...r,id:Number(r.id),sortOrder:Number(r.sortOrder),version:Number(r.version)}))};
  });
}

export async function saveMenuItem(db:Pool,actor:AuthUser,input:z.infer<typeof menuInput>&{version?:number},id?:number) {
  return transaction(db,async c=>{
    let before:RowDataPacket|null=null;
    if(id!==undefined) {
      const [rows]=await c.query<RowDataPacket[]>(`SELECT ${fields} FROM menu_items WHERE id=? FOR UPDATE`,[id]);
      if(!rows.length)throw new MenuError(404,'Không tìm thấy món.');
      before=rows[0];
      if(Number(before.version)!==input.version)throw new MenuError(409,'Món đã được sửa trên thiết bị khác. Tải lại thực đơn rồi thử lại.');
    }
    const [category]=await c.query<RowDataPacket[]>('SELECT id FROM categories WHERE id=? FOR SHARE',[input.categoryId]);
    if(!category.length)throw new MenuError(400,'Danh mục không tồn tại.');
    const values=[input.categoryId,input.name,input.description||null,input.emoji,input.imageUrl||null,input.price,input.available?1:0];
    if(id===undefined) {
      const [created]=await c.execute<ResultSetHeader>('INSERT INTO menu_items(category_id,name,description,emoji,image_url,price,is_available) VALUES(?,?,?,?,?,?,?)',values);
      id=created.insertId;
    } else await c.execute('UPDATE menu_items SET category_id=?,name=?,description=?,emoji=?,image_url=?,price=?,is_available=?,version=version+1 WHERE id=?',[...values,id]);
    const [rows]=await c.query<RowDataPacket[]>(`SELECT ${fields} FROM menu_items WHERE id=?`,[id]);
    const item=normalize(rows[0]);
    await audit(c,actor,before?'menu.update':'menu.create',id,before?normalize(before):null,item);
    return {item};
  });
}

export async function setMenuAvailability(db:Pool,actor:AuthUser,id:number,input:z.infer<typeof availabilityInput>) {
  return transaction(db,async c=>{
    const [rows]=await c.query<RowDataPacket[]>(`SELECT ${fields} FROM menu_items WHERE id=? FOR UPDATE`,[id]);
    if(!rows.length)throw new MenuError(404,'Không tìm thấy món.');
    if(Number(rows[0].version)!==input.version)throw new MenuError(409,'Món đã thay đổi. Tải lại thực đơn rồi thử lại.');
    await c.execute('UPDATE menu_items SET is_available=?,version=version+1 WHERE id=?',[input.available?1:0,id]);
    const [updated]=await c.query<RowDataPacket[]>(`SELECT ${fields} FROM menu_items WHERE id=?`,[id]);
    const item=normalize(updated[0]);
    await audit(c,actor,'menu.availability',id,normalize(rows[0]),item);
    return {item};
  });
}

export async function saveCategory(db:Pool,actor:AuthUser,input:z.infer<typeof categoryInput>&{version?:number},id?:number) {
  return transaction(db,async c=>{
    let before:RowDataPacket|null=null;
    if(id!==undefined) {
      const [rows]=await c.query<RowDataPacket[]>('SELECT id,name,sort_order AS sortOrder,version FROM categories WHERE id=? FOR UPDATE',[id]);
      if(!rows.length)throw new MenuError(404,'Không tìm thấy danh mục.');
      before=rows[0];
      if(Number(before.version)!==input.version)throw new MenuError(409,'Danh mục đã thay đổi. Tải lại rồi thử lại.');
      await c.execute('UPDATE categories SET name=?,sort_order=?,version=version+1 WHERE id=?',[input.name,input.sortOrder,id]);
    } else {
      const [created]=await c.execute<ResultSetHeader>('INSERT INTO categories(name,sort_order) VALUES(?,?)',[input.name,input.sortOrder]);
      id=created.insertId;
    }
    const [rows]=await c.query<RowDataPacket[]>('SELECT id,name,sort_order AS sortOrder,version FROM categories WHERE id=?',[id]);
    await audit(c,actor,before?'category.update':'category.create',id,before,rows[0]);
    return {category:rows[0]};
  });
}
