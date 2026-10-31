import {readFile} from 'node:fs/promises';
import type {Pool} from 'mysql2/promise';

export async function ensureMenuStorage(db: Pool) {
  const schema=await readFile(new URL('../../../database/menu-management.sql',import.meta.url),'utf8');
  for(const sql of schema.split(';').filter(s=>s.trim())) {
    await db.query(sql).catch((e:{code?:string})=>{if(e.code!=='ER_DUP_FIELDNAME')throw e;});
  }
}
