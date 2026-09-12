import { Router } from "express";
import type { MenuController } from "../controllers/menu.controller.js";

export function createMenuRouter(controller: MenuController) {
  const router = Router();
  router.get("/", controller.list);
  return router;
}

