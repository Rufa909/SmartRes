import { db } from "../infrastructure/database.js";

export class MenuRepository {
  async findAvailableMenu() {
    const [rows] = await db.query(
      `SELECT id, category_id AS categoryId, name, description, price, image_url AS imageUrl, is_available AS isAvailable
       FROM menu_items
       WHERE is_available = TRUE
       ORDER BY category_id, name`
    );

    return rows;
  }
}

