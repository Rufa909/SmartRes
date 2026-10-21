import type { Request, Response } from "express";
import { z } from "zod";
import type { OrderService } from "../services/order.service.js";

const createOrderSchema = z.object({
  tableCode: z.string().trim().min(1).max(32),
  customerNote: z.string().trim().max(1000).optional(),
  items: z.array(
    z.object({
      menuItemId: z.coerce.number().int().positive(),
      quantity: z.number().int().positive(),
      options: z.array(z.unknown()).optional(),
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
    const order = await this.orderService.createOrder(input);
    res.status(201).json({ order });
  };

  updateStatus = async (req: Request, res: Response) => {
    const { status } = updateStatusSchema.parse(req.body);
    const orderId = String(req.params.id);
    const order = await this.orderService.updateStatus(orderId, status);
    res.json({ order });
  };
}
