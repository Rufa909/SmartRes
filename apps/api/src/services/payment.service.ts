import type { OrderRepository } from "../repositories/order.repository.js";
import { publishDomainEvent } from "../events/domain-events.js";

export interface SepayWebhookPayload {
  content?: string;
  transferAmount?: number;
  referenceCode?: string;
  transactionId?: string;
}

export class PaymentService {
  constructor(private readonly orderRepository: OrderRepository) {}

  async handleSepayWebhook(payload: SepayWebhookPayload) {
    const orderCode = payload.referenceCode ?? payload.content?.match(/SR\d+/)?.[0];

    if (!orderCode) {
      return { accepted: false, reason: "Order code not found in webhook payload." };
    }

    await this.orderRepository.markPaidByCode(
      orderCode,
      payload.transactionId ?? `sepay-${Date.now()}`,
      payload
    );

    publishDomainEvent("payment.confirmed", { orderCode, provider: "sepay" });

    return { accepted: true, orderCode };
  }
}
