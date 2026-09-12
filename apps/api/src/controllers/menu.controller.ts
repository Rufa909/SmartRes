import type { Request, Response } from "express";
import type { MenuRepository } from "../repositories/menu.repository.js";

export class MenuController {
  constructor(private readonly menuRepository: MenuRepository) {}

  list = async (_req: Request, res: Response) => {
    const items = await this.menuRepository.findAvailableMenu();
    res.json({ items });
  };
}

