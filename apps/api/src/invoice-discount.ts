import type { PoolConnection, RowDataPacket } from 'mysql2/promise';

export async function invoiceDiscount(c: PoolConnection, firstOrderId: number, subtotal: number) {
  const [settings] = await c.query<RowDataPacket[]>('SELECT mode,percentage,voucher_code AS voucherCode FROM invoice_discounts WHERE first_order_id=?',[firstOrderId]);
  const selected = settings[0];
  let percentage = selected ? Number(selected.percentage) : 0;
  let discountError: string | null = null;
  if (selected?.mode === 'voucher') {
    const [vouchers] = await c.query<RowDataPacket[]>(`SELECT percentage,min_amount,is_active,
      (starts_at IS NULL OR starts_at<=CURRENT_TIMESTAMP) AND (ends_at IS NULL OR ends_at>=CURRENT_TIMESTAMP) AS inPeriod
      FROM cashier_vouchers WHERE code=? FOR SHARE`,[selected.voucherCode]);
    const voucher = vouchers[0];
    if (!voucher?.is_active || !voucher.inPeriod) discountError = 'Mã voucher không tồn tại, đã hết hạn hoặc ngừng áp dụng.';
    else if (subtotal < Number(voucher.min_amount)) discountError = `Voucher yêu cầu tiền món tối thiểu ${Number(voucher.min_amount).toLocaleString('vi-VN')} đ.`;
    if (voucher) percentage = Number(voucher.percentage);
  }
  if (!Number.isFinite(percentage) || percentage < 0 || percentage > 100) discountError = 'Mức giảm giá không hợp lệ.';
  // VND: round the discount once to a whole đồng, never above the food subtotal.
  const discountAmount = discountError ? 0 : Math.min(subtotal, Math.round(subtotal * percentage / 100));
  return {
    subtotalAmount: subtotal, discountMode: selected?.mode as 'manual' | 'voucher' | undefined ?? 'none',
    discountPercentage: percentage, voucherCode: selected?.voucherCode as string | null ?? null,
    discountAmount, totalAmount: subtotal - discountAmount, discountError,
  };
}
