import { db } from "../infrastructure/database.js";
import type {Pool} from 'mysql2/promise';

export class MenuRepository {
  constructor(private readonly database: Pool = db) {}
  async findAvailableMenu() {
    const c=await this.database.getConnection();
    try {
    const [rows] = await c.query(
      `SELECT m.id, m.category_id AS categoryId, c.name AS category, m.name, m.description,
              m.emoji, m.image_url AS imageUrl, m.price, m.is_available AS isAvailable
       FROM menu_items m
       JOIN categories c ON c.id = m.category_id
       WHERE is_available = TRUE
       ORDER BY c.sort_order, m.name`
    );
    const items=rows as Array<Record<string,unknown>>;
    if(!items.length)return items;
    const ids=items.map(item=>Number(item.id));
    const placeholders=ids.map(()=>'?').join(',');
    const [options]=await c.query(`SELECT menu_item_id AS menuItemId,group_name AS groupName,option_name AS name,extra_price AS extraPrice
      FROM menu_item_options WHERE group_name IN ('Khẩu phần','Món thêm') AND menu_item_id IN (${placeholders}) ORDER BY id`,ids);
    const sizes=new Map<number,Array<{name:string;price:number}>>();
    const extras=new Map<number,Array<{name:string;price:number}>>();
    for(const option of options as Array<Record<string,unknown>>) {
      const key=Number(option.menuItemId);
      if(option.groupName==='Khẩu phần') {
        const list=sizes.get(key)??[];
        list.push({name:String(option.name),price:Number(items.find(item=>Number(item.id)===key)?.price??0)+Number(option.extraPrice)});sizes.set(key,list);
      } else {
        const list=extras.get(key)??[];list.push({name:String(option.name),price:Number(option.extraPrice)});extras.set(key,list);
      }
    }
    return items.map(item=>({...item,sizes:sizes.get(Number(item.id))??[{name:'Tiêu chuẩn',price:Number(item.price)}],extras:extras.get(Number(item.id))??[]}));
    } finally { c.release(); }
  }
}

