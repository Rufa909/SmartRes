"use client";

import { Clock3, LoaderCircle, RefreshCw, ReceiptText, X } from "lucide-react";
import { useEffect, useState } from "react";

type CustomerOrder = {
  orderCode: string;
  status: string;
  paymentStatus: string;
  totalAmount: number;
  createdAt: string;
  customerNote: string | null;
  items: Array<{ id: number; name: string; quantity: number; unitPrice: number; status: string; note: string | null }>;
};

type OrderSnapshot = { tableStatus: string; orders: CustomerOrder[] };

const formatPrice = (value: number) => `${new Intl.NumberFormat("vi-VN").format(value)}đ`;
const orderStatusLabels: Record<string, string> = { new: "Đã tiếp nhận", preparing: "Chờ bếp", cooking: "Đang chế biến", completed: "Đã hoàn thành", cancelled: "Đã hủy" };
const itemStatusLabels: Record<string, string> = { preparing: "Chờ bếp", cooking: "Đang nấu", completed: "Chờ phục vụ", served: "Đã phục vụ" };

export function CustomerOrdersDialog({
  tableCode,
  token,
  onClose,
  onExpired,
  onRequestPayment,
  requestingPayment,
  paymentRequested,
  paymentError,
}: {
  tableCode: string;
  token: string;
  onClose: () => void;
  onExpired: () => void;
  onRequestPayment: (orderCode: string) => void;
  requestingPayment: boolean;
  paymentRequested: boolean;
  paymentError: string | null;
}) {
  const [snapshot, setSnapshot] = useState<OrderSnapshot | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [refreshNow, setRefreshNow] = useState(0);

  useEffect(() => {
    if (!token) {
      setSnapshot(null);
      setError("Phiên bàn chưa sẵn sàng. Hãy quét QR trên bàn hoặc nhờ nhân viên mở bàn.");
      setLoading(false);
      return;
    }
    let active = true;
    let fetching = false;
    async function reload(quiet = false) {
      if (fetching) return;
      fetching = true;
      if (quiet) setRefreshing(true); else setLoading(true);
      try {
        const response = await fetch(`/api/customer/orders/mine/${encodeURIComponent(tableCode)}`, {
          headers: { Authorization: `Bearer ${token}` },
          cache: "no-store",
          signal: AbortSignal.timeout(10000),
        });
        const data = await response.json() as OrderSnapshot & { message?: string };
        if (response.status === 401) {
          onExpired();
          throw new Error(data.message || "Phiên bàn đã kết thúc. Hãy quét lại QR để xem đơn hiện tại.");
        }
        if (!response.ok) throw new Error(data.message || "Chưa tải được danh sách đơn.");
        if (active) { setSnapshot(data); setError(null); }
      } catch (requestError) {
        if (active) setError(requestError instanceof Error ? requestError.message : "Không kết nối được máy chủ.");
      } finally {
        fetching = false;
        if (active) { setLoading(false); setRefreshing(false); }
      }
    }
    void reload();
    const timer = window.setInterval(() => { void reload(true); }, 5000);
    return () => { active = false; window.clearInterval(timer); };
  }, [onExpired, refreshNow, tableCode, token]);

  const orders = snapshot?.orders ?? [];
  const canRequestPayment = snapshot?.tableStatus === "dining" && orders.some((order) => order.paymentStatus === "unpaid" && order.status !== "cancelled");

  return <div className="fixed inset-0 z-[65] flex items-end justify-center bg-slate-950/45 p-0 backdrop-blur-sm sm:items-center sm:p-5" role="dialog" aria-modal="true" aria-label="Đơn của tôi">
    <section className="flex max-h-[92dvh] w-full max-w-xl flex-col overflow-hidden rounded-t-[28px] bg-white shadow-2xl sm:rounded-[28px]">
      <header className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
        <div className="flex items-center gap-3"><span className="grid h-10 w-10 place-items-center rounded-2xl bg-coral/10 text-coral"><ReceiptText size={20} /></span><div><h2 className="font-black">Đơn của tôi</h2><p className="text-xs text-slate-500">{tableCode} · Cập nhật tự động mỗi 5 giây</p></div></div>
        <div className="flex items-center gap-1"><button type="button" onClick={() => setRefreshNow((value) => value + 1)} className="grid h-9 w-9 place-items-center rounded-full text-slate-500 hover:bg-slate-100" aria-label="Tải lại đơn">{refreshing ? <LoaderCircle size={17} className="animate-spin" /> : <RefreshCw size={17} />}</button><button type="button" onClick={onClose} className="grid h-9 w-9 place-items-center rounded-full text-slate-500 hover:bg-slate-100" aria-label="Đóng"><X size={18} /></button></div>
      </header>
      <div className="min-h-48 flex-1 space-y-3 overflow-y-auto bg-[#f7f7fa] p-4">
        {loading && <div className="flex items-center justify-center gap-2 py-12 text-sm text-slate-500"><LoaderCircle size={18} className="animate-spin" /> Đang tải đơn…</div>}
        {!loading && error && <div role="alert" className="rounded-2xl bg-amber-50 p-4 text-sm leading-6 text-amber-900">{error}</div>}
        {!loading && !error && orders.length === 0 && <div className="rounded-2xl border border-dashed border-slate-300 bg-white px-5 py-12 text-center"><ReceiptText className="mx-auto text-slate-300" size={30} /><p className="mt-3 font-bold">Chưa có đơn trong lượt này</p><p className="mt-1 text-sm text-slate-500">Các món trong giỏ chỉ hiện sau khi bạn xác nhận gọi món.</p></div>}
        {!loading && orders.map((order) => <article key={order.orderCode} className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className="flex items-start justify-between gap-3"><div><p className="text-[11px] font-bold uppercase tracking-wide text-slate-400">Mã đơn</p><p className="mt-0.5 text-sm font-black">#{order.orderCode.slice(-8).toUpperCase()}</p><p className="mt-1 flex items-center gap-1 text-[11px] text-slate-500"><Clock3 size={12} />{new Intl.DateTimeFormat("vi-VN", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "2-digit" }).format(new Date(order.createdAt))}</p></div><span className={`rounded-full px-2.5 py-1 text-[10px] font-bold ${order.status === "cancelled" ? "bg-rose-50 text-rose-700" : order.status === "completed" ? "bg-emerald-50 text-emerald-700" : "bg-amber-50 text-amber-800"}`}>{orderStatusLabels[order.status] || order.status}</span></div>
          {order.customerNote && <p className="mt-3 rounded-xl bg-amber-50 px-3 py-2 text-xs text-amber-900">Ghi chú đơn hàng: {order.customerNote}</p>}
          <div className="mt-3 divide-y divide-slate-100 border-y border-slate-100">
            {order.items.map((item) => <div key={item.id} className="flex items-start justify-between gap-3 py-2.5 text-sm"><div className="min-w-0"><p className="font-semibold text-slate-800">{item.quantity} × {item.name}</p>{item.note && <p className="mt-0.5 text-xs text-slate-500">Ghi chú: {item.note}</p>}<p className="mt-1 text-[11px] font-medium text-slate-500">{itemStatusLabels[item.status] || item.status}</p></div><span className="shrink-0 text-xs font-bold text-slate-600">{formatPrice(item.unitPrice * item.quantity)}</span></div>)}
          </div>
          <div className="mt-3 flex items-center justify-between"><span className="text-xs text-slate-500">{order.paymentStatus === "paid" ? "Đã thanh toán" : "Chưa thanh toán"}</span><span className="font-black text-coral">{formatPrice(order.totalAmount)}</span></div>
        </article>)}
      </div>
      {(paymentError || snapshot?.tableStatus === "waiting_payment" || canRequestPayment) && <footer className="border-t border-slate-100 bg-white p-4 pb-[max(16px,env(safe-area-inset-bottom))]">
        {paymentError && <p role="alert" className="mb-3 rounded-xl bg-red-50 px-3 py-2 text-sm text-red-700">{paymentError}</p>}
        {snapshot?.tableStatus === "waiting_payment" || paymentRequested ? <p className="text-center text-sm font-semibold text-amber-800">Đã gửi yêu cầu thanh toán. Vui lòng chờ thu ngân.</p> : canRequestPayment && <button type="button" disabled={requestingPayment} onClick={() => { const firstOpenOrder = orders.find((order) => order.paymentStatus === "unpaid" && order.status !== "cancelled"); if (firstOpenOrder) onRequestPayment(firstOpenOrder.orderCode); }} className="h-12 w-full rounded-xl bg-coral font-bold text-white disabled:opacity-60">{requestingPayment ? "Đang gửi yêu cầu…" : "Yêu cầu thanh toán"}</button>}
      </footer>}
    </section>
  </div>;
}
