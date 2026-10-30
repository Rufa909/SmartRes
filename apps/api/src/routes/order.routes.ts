import { Router } from "express";
import type { OrderController } from "../controllers/order.controller.js";

export function createOrderRouter(controller: OrderController) {
  const router = Router();
  router.post("/", (req,res,next) => { void controller.create(req,res).catch(next); });
  router.post("/:orderCode/request-payment", (req,res,next) => { void controller.requestPayment(req,res).catch(next); });
  return router;
}

