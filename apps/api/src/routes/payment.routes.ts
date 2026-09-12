import { Router } from "express";
import type { PaymentController } from "../controllers/payment.controller.js";

export function createPaymentRouter(controller: PaymentController) {
  const router = Router();
  router.post("/sepay/webhook", controller.sepayWebhook);
  return router;
}

