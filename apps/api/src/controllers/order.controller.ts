import type { Request, Response } from "express";
import { z } from "zod";
import type { OrderService } from "../services/order.service.js";

const createOrderSchema = z.object({
  tableCode: z.string().trim().min(1).max(32),
  customerNote: z.string().trim().max(1000).optional(),
  items: z.array(
    z.object({
      menuItemId: z.coerce.number().int().positive(),
      quantity: z.number().int().min(1).max(99),
      options: z.array(z.unknown()).max(10).optional(),
      note: z.string().trim().max(500).optional()
    })
  ).min(1).max(30)
});

const updateStatusSchema = z.object({
  status: z.enum(["new", "preparing", "cooking", "completed", "cancelled"])
});

export class OrderController {
  constructor(private readonly orderService: OrderService) {}

  create = async (req: Request, res: Response) => {
    const input = createOrderSchema.parse(req.body);
    const order = await this.orderService.createOrder(input, req.header('authorization')?.replace(/^Bearer /, ''));
    res.status(201).json({ order });
  };

  updateStatus = async (req: Request, res: Response) => {
    const { status } = updateStatusSchema.parse(req.body);
    const orderId = String(req.params.id);
    const order = await this.orderService.updateStatus(orderId, status);
    res.json({ order });
  };

  requestPayment = async (req: Request, res: Response) => {
    const orderCode = z.string().regex(/^SR-[0-9a-f-]{36}$/i).parse(req.params.orderCode);
    res.json(await this.orderService.requestPayment(orderCode, req.header('authorization')?.replace(/^Bearer /, '')));
  };
}
