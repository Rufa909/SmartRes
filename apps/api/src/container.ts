import { OrderController } from "./controllers/order.controller.js";
import { MenuController } from "./controllers/menu.controller.js";
import { PaymentController } from "./controllers/payment.controller.js";
import { MenuRepository } from "./repositories/menu.repository.js";
import { OrderRepository } from "./repositories/order.repository.js";
import { OrderService } from "./services/order.service.js";
import { PaymentService } from "./services/payment.service.js";

export function createContainer() {
  const menuRepository = new MenuRepository();
  const orderRepository = new OrderRepository();
  const orderService = new OrderService(orderRepository);
  const paymentService = new PaymentService(orderRepository);

  return {
    menuController: new MenuController(menuRepository),
    orderController: new OrderController(orderService),
    paymentController: new PaymentController(paymentService)
  };
}

