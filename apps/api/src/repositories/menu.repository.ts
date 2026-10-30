import { db } from "../infrastructure/database.js";
import type {Pool} from 'mysql2/promise';

export class MenuRepository {
  constructor(private readonly database: Pool = db) {}
  async findAvailableMenu() {
    const [rows] = await this.database.query(
      `SELECT m.id, m.category_id AS categoryId, c.name AS category, m.name, m.description,
              m.emoji, m.price, m.is_available AS isAvailable
       FROM menu_items m
       JOIN categories c ON c.id = m.category_id
       WHERE is_available = TRUE
       ORDER BY c.sort_order, m.name`
    );

    return rows;
  }
}

