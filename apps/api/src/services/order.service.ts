import type { CreateOrderInput, OrderRepository } from "../repositories/order.repository.js";
import { publishDomainEvent } from "../events/domain-events.js";

export class OrderService {
  constructor(private readonly orderRepository: OrderRepository) {}

  async createOrder(input: CreateOrderInput) {
    if (input.items.length === 0) {
      throw new Error("Order must contain at least one item.");
    }

    const order = await this.orderRepository.create(input);
    publishDomainEvent("order.created", order);
    return order;
  }

  async updateStatus(orderId: string, status: string) {
    const order = await this.orderRepository.updateStatus(orderId, status);
    publishDomainEvent("order.status_updated", order);
    return order;
  }
}
