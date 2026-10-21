import cors from "cors";
import express from "express";
import helmet from "helmet";
import { ZodError } from "zod";
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

  app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    if (error instanceof ZodError) {
      res.status(400).json({ message: "Dữ liệu gọi món không hợp lệ." });
      return;
    }
    const message = error instanceof Error ? error.message : "Không thể xử lý yêu cầu. Vui lòng thử lại.";
    res.status(400).json({ message });
  });

  return { app, container };
}

