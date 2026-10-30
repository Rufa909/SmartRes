import cors from "cors";
import express from "express";
import helmet from "helmet";
import { ZodError } from "zod";
import { createContainer } from "./container.js";
import { createMenuRouter } from "./routes/menu.routes.js";
import { createOrderRouter } from "./routes/order.routes.js";
import { db } from './infrastructure/database.js';
import { CustomerAccessError } from './customer-sessions.js';
import { createCustomerSessionsRouter } from './routes/customer-sessions.routes.js';
import type {Pool} from 'mysql2/promise';

export function createApp(database: Pool = db) {
  const app = express();
  const container = createContainer(database);

  app.use(helmet());
  app.use(cors());
  app.use(express.json({limit:'32kb'}));
  app.use((_req,res,next) => {res.set('Cache-Control','no-store');next();});

  app.get("/api/health", (_req, res) => {
    res.json({ status: "ok", service: "smartres-api" });
  });

  app.use("/api/menu", createMenuRouter(container.menuController));
  app.use("/api/orders", createOrderRouter(container.orderController));
  app.use('/api/customer-sessions',createCustomerSessionsRouter(database));
  // Customer API không công khai API sửa trạng thái hoặc webhook thanh toán mẫu.
  app.use((_req,res) => {res.status(404).json({message:'Không tìm thấy API.'});});

  app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    if (error instanceof ZodError) {
      res.status(400).json({ message: "Dữ liệu gọi món không hợp lệ." });
      return;
    }
    if (error instanceof CustomerAccessError) {res.status(error.status).json({message:error.message});return;}
    res.status(400).json({ message: 'Không thể xử lý yêu cầu. Kiểm tra bàn, món ăn hoặc kết nối máy chủ.' });
  });

  return { app, container };
}

