import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
import { readFile } from 'node:fs/promises';
import { randomBytes, scryptSync } from 'node:crypto';
dotenv.config({ path: new URL('../../../.env.mysql.local', import.meta.url), quiet: true });
dotenv.config({ path: new URL('../../../.env', import.meta.url), quiet: true });
const database = process.env.MYSQL_DATABASE;
if (database !== 'smartres_staff') throw new Error('Setup chỉ dành cho database smartres_staff.');
const c = await mysql.createConnection({ host: process.env.MYSQL_HOST, port: Number(process.env.MYSQL_PORT || 3306),
  user: process.env.MYSQL_USER, password: process.env.MYSQL_PASSWORD, charset: 'utf8mb4' });
try {
  await c.query('CREATE DATABASE IF NOT EXISTS smartres_staff CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
  await c.changeUser({ database });
  const schema = await readFile(new URL('../../../database/staff-schema.sql', import.meta.url), 'utf8');
  for (const sql of schema.split(';').filter(s => s.trim())) await c.query(sql);
  const cashierSchema = await readFile(new URL('../../../database/cashier-schema.sql', import.meta.url), 'utf8');
  for (const sql of cashierSchema.split(';').filter(s => s.trim())) await c.query(sql);
  await c.query("ALTER TABLE users MODIFY COLUMN role ENUM('staff','kitchen','cashier','manager') NOT NULL");
  const passwordHash = (password) => {
    const salt = randomBytes(16).toString('hex');
    return `${salt}:${scryptSync(password, salt, 64).toString('hex')}`;
  };
  for (const user of [
    ['nhanvien', 'Nhân viên demo', 'staff', 'Staff@123'],
    ['bep', 'Bếp demo', 'kitchen', 'Bep@12345'],
    ['thungan', 'Thu ngân demo', 'cashier', 'ThuNgan@123'],
    ['quanly', 'Quản lý demo', 'manager', 'QuanLy@123'],
  ]) {
    await c.execute('INSERT IGNORE INTO users(username,display_name,role,password_hash) VALUES (?,?,?,?)', [user[0],user[1],user[2],passwordHash(user[3])]);
  }
  await c.query("ALTER TABLE orders ADD COLUMN payment_method ENUM('cash','bank_transfer','card') NULL").catch(e => { if (e.code !== 'ER_DUP_FIELDNAME') throw e; });
  await c.query('ALTER TABLE orders ADD COLUMN paid_at TIMESTAMP NULL').catch(e => { if (e.code !== 'ER_DUP_FIELDNAME') throw e; });
  await c.beginTransaction();
  for (const [index, code] of ['A01','A02','A03','A04','A05','A06','B01','B02'].entries()) {
    await c.execute('INSERT IGNORE INTO restaurant_tables (code,name,area,seats) VALUES (?,?,?,4)', [code, `Bàn ${code}`, index < 6 ? 'Tầng 1' : 'Tầng 2']);
  }
  for (const [index, name] of ['Khai vị','Món chính','Đồ uống'].entries()) {
    await c.execute('INSERT IGNORE INTO categories(name,sort_order) VALUES (?,?)', [name,index]);
  }
  const dishes = [
    ['Cơm chiên hải sản','Món chính','🍚',45000,1,'Cơm chiên tơi hạt cùng tôm, mực và rau củ, thơm nóng vừa vị.','/menu/com-chien-hai-san.webp'],
    ['Sườn nướng mật ong','Món chính','🍖',89000,1,'Sườn nướng mềm mọng, phủ sốt mật ong óng nhẹ và thơm mùi than nướng.','/menu/suon-nuong-mat-ong.webp'],
    ['Gỏi cuốn tôm','Khai vị','🥗',35000,1,'Tôm tươi, bún và rau thơm cuốn bánh tráng, dùng cùng sốt đậu phộng đậm vị.','/menu/goi-cuon-tom.webp'],
    ['Khoai tây chiên','Khai vị','🍟',30000,1,'Khoai chiên vàng giòn bên ngoài, mềm bùi bên trong, ăn kèm tương cà.','/menu/khoai-tay-chien.webp'],
    ['Trà đào cam sả','Đồ uống','🍑',25000,1,'Trà đào thanh mát với cam tươi và sả, cân bằng vị chua ngọt dễ uống.','/menu/tra-dao-cam-sa.webp'],
    ['Lẩu hải sản','Món chính','🍲',250000,0,'Lẩu hải sản nóng hổi với tôm, mực và rau tươi dùng chung tại bàn.',null],
    ['Chả giò hải sản','Khai vị','🥟',49000,1,'Chả giò nhân tôm mực chiên vàng giòn, dùng cùng rau sống và nước mắm chua ngọt.','/menu/cha-gio-hai-san.webp'],
    ['Salad bò nướng','Khai vị','🥗',69000,1,'Rau xanh tươi mát trộn cùng bò nướng mềm, cà chua, hành tây và đậu phộng rang.','/menu/salad-bo-nuong.webp'],
    ['Cánh gà chiên mắm','Khai vị','🍗',65000,1,'Cánh gà chiên giòn áo sốt nước mắm tỏi đậm đà, thơm nhẹ vị ớt.','/menu/canh-ga-chien-mam.webp'],
    ['Bò lúc lắc','Món chính','🥩',119000,1,'Bò cắt khối áp chảo mềm mọng cùng ớt chuông và hành tây, dùng kèm xà lách.','/menu/bo-luc-lac.webp'],
    ['Gà nướng muối ớt','Món chính','🍗',109000,1,'Gà nướng da vàng giòn, thấm vị muối ớt cay nhẹ và thơm mùi than.','/menu/ga-nuong-muoi-ot.webp'],
    ['Cá hồi áp chảo','Món chính','🐟',159000,1,'Cá hồi áp chảo vàng mặt, thịt mềm ẩm, ăn cùng rau củ và sốt bơ chanh.','/menu/ca-hoi-ap-chao.webp'],
    ['Mì xào hải sản','Món chính','🍜',79000,1,'Mì xào săn sợi với tôm, mực và rau củ, nêm vừa vị và phục vụ nóng.','/menu/mi-xao-hai-san.webp'],
    ['Cơm gà xối mỡ','Món chính','🍛',69000,1,'Cơm gà thơm dẻo dùng cùng đùi gà da giòn, dưa leo và cà chua tươi.','/menu/com-ga-xoi-mo.webp'],
    ['Bún bò Nam Bộ','Món chính','🍜',75000,1,'Bún tươi trộn bò xào, rau thơm, giá, đậu phộng và hành phi cùng nước mắm chua ngọt.','/menu/bun-bo-nam-bo.webp'],
    ['Lẩu Thái','Món chính','🍲',289000,1,'Nồi lẩu Thái chua cay với tôm, mực, nấm và rau tươi, phù hợp dùng chung 2–3 người.','/menu/lau-thai.webp'],
    ['Nước chanh dây','Đồ uống','🥤',29000,1,'Chanh dây tươi pha chua ngọt cân bằng, thêm đá mát lạnh.','/menu/nuoc-chanh-day.webp'],
    ['Soda chanh bạc hà','Đồ uống','🍋',35000,1,'Soda sủi bọt pha chanh tươi và bạc hà, thanh mát và dễ uống.','/menu/soda-chanh-bac-ha.webp'],
    ['Cà phê sữa đá','Đồ uống','☕',29000,1,'Cà phê Việt đậm thơm hòa cùng sữa đặc và đá lạnh.','/menu/ca-phe-sua-da.webp'],
    ['Nước ép dưa hấu','Đồ uống','🍉',32000,1,'Dưa hấu tươi ép nguyên vị, ngọt dịu và mát lành.','/menu/nuoc-ep-dua-hau.webp'],
    ['Trà sữa trân châu đường đen','Đồ uống','🧋',45000,1,'Trà sữa béo thơm với trân châu dai mềm và sốt đường đen đậm vị.','/menu/tra-sua-tran-chau-duong-den.webp'],
  ];
  for (const [name,category,emoji,price,available,description,imageUrl] of dishes) {
    await c.execute(`INSERT INTO menu_items(name,category_id,emoji,price,is_available,description,image_url)
      SELECT ?,id,?,?,?,?,? FROM categories WHERE name=?
      ON DUPLICATE KEY UPDATE
        emoji=IF(emoji IS NULL OR emoji='' OR emoji='?',VALUES(emoji),emoji),
        description=IF(description IS NULL OR description='',VALUES(description),description),
        image_url=IF(image_url IS NULL OR image_url='',VALUES(image_url),image_url)`,
      [name,emoji,price,available,description,imageUrl,category]);
  }
  await c.commit();
  console.log('Database smartres_staff sẵn sàng: 8 bàn và 21 món khởi tạo. Không tạo đơn hàng giả.');
} catch(e) { await c.rollback(); console.error('Không thể khởi tạo:', e.code ?? e.message); process.exitCode=1; }
finally { await c.end(); }
