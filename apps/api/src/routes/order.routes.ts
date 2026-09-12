import { Router } from "express";
import type { OrderController } from "../controllers/order.controller.js";

export function createOrderRouter(controller: OrderController) {
  const router = Router();
  router.post("/", controller.create);
  router.patch("/:id/status", controller.updateStatus);
  return router;
}

