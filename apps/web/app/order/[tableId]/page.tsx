import { OrderExperience } from "./order-experience";

export default async function OrderPage({ params }: { params: Promise<{ tableId: string }> }) {
  const { tableId } = await params;

  return <OrderExperience tableId={tableId} />;
}
