import type { Request, Response } from "express";
import type { PaymentService } from "../services/payment.service.js";

export class PaymentController {
  constructor(private readonly paymentService: PaymentService) {}

  sepayWebhook = async (req: Request, res: Response) => {
    const result = await this.paymentService.handleSepayWebhook(req.body);
    res.json(result);
  };
}

