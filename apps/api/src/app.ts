import cors from "cors";
import express from "express";
import helmet from "helmet";
import { createContainer } from "./container.js";
import { createMenuRouter } from "./routes/menu.routes.js";
import { createOrderRouter } from "./routes/order.routes.js";
import { createPaymentRouter } from "./routes/payment.routes.js";

export function createApp() {
  const app = express();
  const container = createContainer();

  app.use(helmet());
  app.use(cors());
  app.use(express.json());

  app.get("/api/health", (_req, res) => {
    res.json({ status: "ok", service: "smartres-api" });
  });

  app.use("/api/menu", createMenuRouter(container.menuController));
  app.use("/api/orders", createOrderRouter(container.orderController));
  app.use("/api/payments", createPaymentRouter(container.paymentController));

  return { app, container };
}

