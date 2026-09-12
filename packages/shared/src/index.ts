export type TableStatus = "available" | "dining" | "waiting_payment" | "disabled";
export type OrderStatus = "new" | "preparing" | "cooking" | "completed" | "cancelled";
export type PaymentStatus = "unpaid" | "pending" | "paid" | "failed";

export interface MenuItem {
  id: string;
  categoryId: string;
  name: string;
  description: string;
  price: number;
  imageUrl?: string;
  isAvailable: boolean;
}

export interface CartItem {
  menuItemId: string;
  name: string;
  quantity: number;
  unitPrice: number;
  options?: Array<{ groupName: string; optionName: string; extraPrice: number }>;
  note?: string;
}

export interface Order {
  id: string;
  orderCode: string;
  tableId: string;
  status: OrderStatus;
  paymentStatus: PaymentStatus;
  totalAmount: number;
  items: CartItem[];
  createdAt: string;
}

