import {z} from 'zod';
import type {Pool,PoolConnection,RowDataPacket,ResultSetHeader} from 'mysql2/promise';
import {hashPassword} from './auth.js';

export class UserManagementError extends Error {constructor(public status:number,message:string){super(message);}}
export const employeeRoles = ['staff','kitchen','cashier'] as const;
const version=z.number().int().min(0).max(Number.MAX_SAFE_INTEGER);
const password=z.string().min(6).max(200).refine(value=>value.trim().length>=6);
const profile=z.object({username:z.string().trim().regex(/^[A-Za-z0-9._-]{3,60}$/),displayName:z.string().trim().min(1).max(120),role:z.enum(employeeRoles)});
export const createUserInput=profile.extend({password}).strict();
export const updateUserInput=profile.extend({version}).strict();
export const resetPasswordInput=z.object({password,version}).strict();
export const deleteUserInput=z.object({version}).strict();
const fields='id,username,display_name AS displayName,role,session_version AS version';
const normalize=(row:RowDataPacket)=>({...row,id:Number(row.id),version:Number(row.version)});

export async function ensureUserManagementStorage(db:Pool) {
  const [columns]=await db.query<RowDataPacket[]>("SHOW COLUMNS FROM users LIKE 'session_version'");
  if(!columns.length) await db.query('ALTER TABLE users ADD COLUMN session_version INT UNSIGNED NOT NULL DEFAULT 0').catch((error:{code?:string})=>{
    if(error.code!=='ER_DUP_FIELDNAME')throw error;
  });
}
export async function readEmployees(db:Pool) {
  const [users]=await db.query<RowDataPacket[]>(`SELECT ${fields} FROM users WHERE is_active=1 AND role IN ('staff','kitchen','cashier') ORDER BY display_name,id`);
  return {users:users.map(normalize)};
}
async function transaction<T>(db:Pool,fn:(c:PoolConnection)=>Promise<T>) {
  const c=await db.getConnection();
  try {await c.beginTransaction();const value=await fn(c);await c.commit();return value;}
  catch(error){await c.rollback();if((error as {code?:string}).code==='ER_DUP_ENTRY')throw new UserManagementError(409,'Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác.');throw error;}
  finally {c.release();}
}
async function lockEmployee(c:PoolConnection,id:number,expectedVersion:number) {
  const [users]=await c.query<RowDataPacket[]>(`SELECT ${fields},is_active AS active FROM users WHERE id=? FOR UPDATE`,[id]);
  if(!users.length || !users[0].active)throw new UserManagementError(404,'Không tìm thấy tài khoản.');
  if(!employeeRoles.includes(users[0].role))throw new UserManagementError(403,'Chỉ được quản lý tài khoản nhân viên, bếp và thu ngân.');
  if(Number(users[0].version)!==expectedVersion)throw new UserManagementError(409,'Tài khoản đã thay đổi trên thiết bị khác. Tải lại danh sách rồi thử lại.');
}
export async function createEmployee(db:Pool,input:z.infer<typeof createUserInput>) {
  const passwordHash=hashPassword(input.password);
  return transaction(db,async c=>{
    const [created]=await c.execute<ResultSetHeader>('INSERT INTO users(username,display_name,role,password_hash) VALUES(?,?,?,?)',[input.username,input.displayName,input.role,passwordHash]);
    const [users]=await c.query<RowDataPacket[]>(`SELECT ${fields} FROM users WHERE id=?`,[created.insertId]);
    return {user:normalize(users[0])};
  });
}
export async function updateEmployee(db:Pool,id:number,input:z.infer<typeof updateUserInput>) {
  return transaction(db,async c=>{
    await lockEmployee(c,id,input.version);
    await c.execute('UPDATE users SET username=?,display_name=?,role=?,session_version=session_version+1 WHERE id=?',[input.username,input.displayName,input.role,id]);
    const [users]=await c.query<RowDataPacket[]>(`SELECT ${fields} FROM users WHERE id=?`,[id]);
    return {user:normalize(users[0])};
  });
}
export async function resetEmployeePassword(db:Pool,id:number,input:z.infer<typeof resetPasswordInput>) {
  const passwordHash=hashPassword(input.password);
  return transaction(db,async c=>{
    await lockEmployee(c,id,input.version);
    await c.execute('UPDATE users SET password_hash=?,session_version=session_version+1 WHERE id=?',[passwordHash,id]);
    return {ok:true};
  });
}
export async function deleteEmployee(db:Pool,id:number,input:z.infer<typeof deleteUserInput>) {
  return transaction(db,async c=>{
    await lockEmployee(c,id,input.version);
    // Preserve account identity for historical operational records.
    await c.execute('UPDATE users SET is_active=0,session_version=session_version+1 WHERE id=?',[id]);
    return {ok:true};
  });
}
