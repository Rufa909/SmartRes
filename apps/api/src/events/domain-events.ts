import { EventEmitter } from "node:events";

export type DomainEventName = "order.created" | "order.status_updated" | "payment.confirmed";

export const domainEvents = new EventEmitter();

export function publishDomainEvent(name: DomainEventName, payload: unknown) {
  domainEvents.emit(name, payload);
}

