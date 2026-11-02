import type { PoolConnection, RowDataPacket } from 'mysql2/promise';
import {readPromotion,evaluatePromotion} from './promotions.js';
import {findDiscountCode,validateDiscountCode} from './discount-codes.js';

export async function invoiceDiscount(c: PoolConnection, firstOrderId: number, subtotal: number) {
  const [codes]=await c.query<RowDataPacket[]>('SELECT discount_id AS discountId FROM invoice_discount_codes WHERE first_order_id=?',[firstOrderId]);
  if(codes.length){
    const discount=await findDiscountCode(c,Number(codes[0].discountId));
    const result=validateDiscountCode(discount,subtotal);
    return {subtotalAmount:subtotal,discountMode:'discount_code',discountPercentage:discount?.discountType==='percentage'?discount.discountPercent??0:0,
      voucherCode:null,discountAmount:result.discountAmount,totalAmount:subtotal-result.discountAmount,discountError:result.reason,
      discountCodeId:Number(codes[0].discountId),discountCode:discount?.discountCode??null,discountName:discount?.discountName??null,discountCodeVersion:discount?.version??null,
      discountType:discount?.discountType??null,discountValue:discount?.discountType==='percentage'?discount.discountPercent:discount?.fixedAmount,maxDiscountAmount:discount?.maxDiscountAmount??null};
  }
  const [selections]=await c.query<RowDataPacket[]>('SELECT promotion_id AS promotionId FROM invoice_promotions WHERE first_order_id=?',[firstOrderId]);
  if(selections.length) {
    const promotion=await readPromotion(c,Number(selections[0].promotionId));
    const result=promotion?evaluatePromotion({subtotalAmount:subtotal,paymentStatus:'unpaid'},promotion):{applicable:false,reason:'Chương trình không tồn tại.',discountAmount:0};
    return {subtotalAmount:subtotal,discountMode:'promotion',discountPercentage:promotion?.discountType==='percentage'?promotion.discountValue:0,
      voucherCode:null,discountAmount:result.discountAmount,totalAmount:subtotal-result.discountAmount,discountError:result.reason,
      promotionId:Number(selections[0].promotionId),promotionName:promotion?.name??null,promotionVersion:promotion?.version??null,
      discountType:promotion?.discountType??null,discountValue:promotion?.discountValue??0,maxDiscountAmount:promotion?.maxDiscountAmount??null};
  }
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
