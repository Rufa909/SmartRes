"use client";

import {
  ArrowLeft,
  Check,
  CheckCircle2,
  ChefHat,
  Clock3,
  ConciergeBell,
  Minus,
  Plus,
  ReceiptText,
  Search,
  ShoppingBag,
  Sparkles,
  UtensilsCrossed,
  X
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { CustomerAccess } from './customer-access';

type MenuItem = {
  id: number;
  name: string;
  description: string;
  price: number;
  category: string;
  badge?: string;
  color: string;
  symbol: string;
  imageUrl?: string | null;
};

type CartItem = {
  key: string;
  item: MenuItem;
  size: "Nhỏ" | "Vừa" | "Lớn";
  extras: string[];
  note: string;
  quantity: number;
  unitPrice: number;
};

// Các món hiện chưa cấu hình phụ thu theo size/topping trong database.
const sizePrices = { Nhỏ: 0, Vừa: 0, Lớn: 0 } as const;
const extraPrices: Record<string, number> = {};
// Gọi cùng tên miền với trang web; Next.js sẽ proxy tới Customer API ở máy chủ.
const apiBaseUrl = "/api/customer";

async function fetchWithTimeout(input: RequestInfo | URL, init?: RequestInit, timeoutMs = 10000) {
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } finally {
    window.clearTimeout(timeout);
  }
}

function formatPrice(value: number) {
  return `${new Intl.NumberFormat("vi-VN").format(value)}đ`;
}

function formatTable(tableId: string) {
  const match = tableId.match(/(\d+)$/);
  return match ? `Bàn ${match[1].padStart(2, "0")}` : tableId.replaceAll("-", " ");
}

function FoodArtwork({ item, large = false }: { item: MenuItem; large?: boolean }) {
  const [failed,setFailed]=useState(false);
  useEffect(()=>setFailed(false),[item.imageUrl]);
  return (
    <div
      className={`relative grid shrink-0 place-items-center overflow-hidden rounded-[22px] ${large ? "h-52 w-full sm:h-64" : "h-24 w-24"}`}
      style={{ background: item.color }}
      aria-hidden="true"
    >
      {item.imageUrl && !failed ? <img src={item.imageUrl} alt="" loading="lazy" referrerPolicy="no-referrer" onError={()=>setFailed(true)} className="absolute inset-0 h-full w-full object-cover" /> : <div className={`${large ? "text-8xl" : "text-5xl"} drop-shadow-sm`}>{item.symbol}</div>}
      <span className="absolute bottom-3 right-3 h-3 w-3 rounded-full bg-emerald-500 ring-4 ring-white" />
    </div>
  );
}

function QuantityControl({ value, onChange }: { value: number; onChange: (value: number) => void }) {
  return (
    <div className="inline-flex items-center gap-3 rounded-xl bg-slate-100 p-1.5">
      <button type="button" onClick={() => onChange(Math.max(0, value - 1))} className="grid h-8 w-8 place-items-center rounded-lg text-slate-500 transition hover:bg-white hover:text-slate-900" aria-label="Giảm số lượng">
        <Minus size={16} />
      </button>
      <span className="min-w-5 text-center text-sm font-bold">{value}</span>
      <button type="button" onClick={() => onChange(value + 1)} className="grid h-8 w-8 place-items-center rounded-lg text-coral transition hover:bg-white" aria-label="Tăng số lượng">
        <Plus size={16} />
      </button>
    </div>
  );
}

export function OrderExperience({ tableId }: { tableId: string }) {
  const tableCode=tableId.toUpperCase();
  return <CustomerAccess key={tableCode} tableCode={tableCode}>{(token,expired)=><ActiveOrderExperience tableId={tableCode} token={token} onExpired={expired} />}</CustomerAccess>;
}

function ActiveOrderExperience({ tableId, token, onExpired }: { tableId: string; token: string; onExpired: () => void }) {
  const tableName = formatTable(tableId);
  const [category, setCategory] = useState<string>("Tất cả");
  const [query, setQuery] = useState("");
  const [selectedItem, setSelectedItem] = useState<MenuItem | null>(null);
  const [selectedSize, setSelectedSize] = useState<"Nhỏ" | "Vừa" | "Lớn">("Vừa");
  const [extras, setExtras] = useState<string[]>([]);
  const [note, setNote] = useState("");
  const [detailQuantity, setDetailQuantity] = useState(1);
  const [cart, setCart] = useState<CartItem[]>([]);
  const [cartOpen, setCartOpen] = useState(false);
  const [orderPlaced, setOrderPlaced] = useState(false);
  const [liveMenuItems, setLiveMenuItems] = useState<MenuItem[]>([]);
  const [menuError, setMenuError] = useState<string | null>(null);
  const [isOrdering, setIsOrdering] = useState(false);
  const [orderError, setOrderError] = useState<string | null>(null);
  const [orderCode, setOrderCode] = useState<string | null>(null);
  const [requestingPayment, setRequestingPayment] = useState(false);
  const [paymentRequested, setPaymentRequested] = useState(false);
  const [paymentError, setPaymentError] = useState<string | null>(null);

  async function requestPayment() {
    if (!orderCode || requestingPayment || paymentRequested) return;
    setRequestingPayment(true);
    setPaymentError(null);
    try {
      const response = await fetchWithTimeout(`${apiBaseUrl}/orders/${encodeURIComponent(orderCode)}/request-payment`, { method: "POST", headers:{Authorization:`Bearer ${token}`} });
      const data = await response.json() as { message?: string };
      if (response.status===401) {onExpired();return;}
      if (!response.ok) throw new Error(data.message || "Không gửi được yêu cầu thanh toán.");
      setPaymentRequested(true);
    } catch (error) {
      setPaymentError(error instanceof Error ? error.message : "Không kết nối được máy chủ.");
    } finally {
      setRequestingPayment(false);
    }
  }

  useEffect(() => {
    let cancelled = false;
    let fetching=false;
    function reloadMenu() {
    if (fetching) return;
    fetching=true;
    void fetchWithTimeout(`${apiBaseUrl}/menu`)
      .then(async (response) => {
        if (!response.ok) throw new Error("Không tải được thực đơn.");
        const data = await response.json() as { items: Array<{ id: number; name: string; description: string | null; price: number | string; category: string; emoji?: string | null; imageUrl?: string | null }> };
        if (!cancelled) {
          const colors = ["#fff0eb", "#fff7da", "#edf8e8", "#fff0da", "#f3ebe6", "#f0edff"];
          setLiveMenuItems(data.items.map((item, index) => ({
            id: item.id,
            name: item.name,
            description: item.description || "Món ăn được chuẩn bị tươi ngon tại nhà hàng.",
            price: Number(item.price),
            category: item.category,
            color: colors[index % colors.length],
            symbol: item.emoji || "🍽️",
            imageUrl:item.imageUrl,
          })));
          setCategory(current=>current==='Tất cả' || data.items.some(i=>i.category===current)?current:'Tất cả');
          setMenuError(null);
        }
      })
      .catch(() => { if (!cancelled) setMenuError("Chưa kết nối được máy chủ. Vui lòng thử lại sau."); })
      .finally(()=>{fetching=false;});
    }
    reloadMenu();
    const timer=setInterval(reloadMenu,10000);
    window.addEventListener('focus',reloadMenu);
    return () => { cancelled = true;clearInterval(timer);window.removeEventListener('focus',reloadMenu); };
  }, []);

  const categories=useMemo(()=>['Tất cả',...new Set(liveMenuItems.map(i=>i.category))],[liveMenuItems]);

  useEffect(()=>{
    setCart(current=>current.map(line=>{
      const updated=liveMenuItems.find(item=>item.id===line.item.id);
      return updated ? {...line,item:updated,unitPrice:updated.price+sizePrices[line.size]+line.extras.reduce((sum,extra)=>sum+extraPrices[extra],0)} : line;
    }));
  },[liveMenuItems]);

  const filteredItems = useMemo(() => {
    const normalizedQuery = query.trim().toLocaleLowerCase("vi");
    return liveMenuItems.filter((item) => {
      const categoryMatches = category === "Tất cả" || item.category === category;
      const queryMatches = !normalizedQuery || `${item.name} ${item.description}`.toLocaleLowerCase("vi").includes(normalizedQuery);
      return categoryMatches && queryMatches;
    });
  }, [category, liveMenuItems, query]);

  const cartCount = cart.reduce((sum, cartItem) => sum + cartItem.quantity, 0);
  const subtotal = cart.reduce((sum, cartItem) => sum + cartItem.unitPrice * cartItem.quantity, 0);

  function openDetail(item: MenuItem) {
    setSelectedItem(item);
    setSelectedSize("Vừa");
    setExtras([]);
    setNote("");
    setDetailQuantity(1);
  }

  function addSelectedItem() {
    if (!selectedItem) return;
    const extraTotal = extras.reduce((sum, extra) => sum + extraPrices[extra], 0);
    const unitPrice = selectedItem.price + sizePrices[selectedSize] + extraTotal;
    const key = `${selectedItem.id}-${selectedSize}-${[...extras].sort().join("-")}-${note}`;

    setCart((current) => {
      const existing = current.find((cartItem) => cartItem.key === key);
      if (existing) {
        return current.map((cartItem) => cartItem.key === key ? { ...cartItem, quantity: cartItem.quantity + detailQuantity } : cartItem);
      }
      return [...current, { key, item: selectedItem, size: selectedSize, extras, note, quantity: detailQuantity, unitPrice }];
    });
    setSelectedItem(null);
  }

  function updateCartQuantity(key: string, quantity: number) {
    setCart((current) => quantity === 0 ? current.filter((cartItem) => cartItem.key !== key) : current.map((cartItem) => cartItem.key === key ? { ...cartItem, quantity } : cartItem));
  }

  async function placeOrder() {
    if (!cart.length || isOrdering) return;
    if (!token) {setOrderError('Bàn chưa sẵn sàng gọi món. Vui lòng nhờ nhân viên nhận bàn và kiểm tra Wi-Fi nhà hàng.');return;}
    if (menuError || cart.some(line=>!liveMenuItems.some(item=>item.id===line.item.id))) {setOrderError('Thực đơn đã thay đổi hoặc có món hết bán. Vui lòng kiểm tra lại giỏ hàng và kết nối.');return;}
    setIsOrdering(true);
    setOrderError(null);
    try {
      const response = await fetchWithTimeout(`${apiBaseUrl}/orders`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization:`Bearer ${token}` },
        body: JSON.stringify({
          tableCode: tableId.toUpperCase(),
          items: cart.map((item) => ({
            menuItemId: item.item.id,
            quantity: item.quantity,
            options: [{ size: item.size, extras: item.extras }],
            note: item.note || undefined
          }))
        })
      });
      const data = await response.json() as { order?: { orderCode?: string }; message?: string };
      if (response.status===401) {onExpired();return;}
      if (!response.ok) throw new Error(data.message || "Không thể gửi đơn. Vui lòng thử lại.");
      setOrderCode(data.order?.orderCode ?? null);
      setOrderPlaced(true);
      setCartOpen(false);
    } catch (error) {
      setOrderError(error instanceof Error ? error.message : "Không thể gửi đơn. Vui lòng thử lại.");
    } finally {
      setIsOrdering(false);
    }
  }

  const selectedPrice = selectedItem ? selectedItem.price + sizePrices[selectedSize] + extras.reduce((sum, extra) => sum + extraPrices[extra], 0) : 0;

  return (
    <main className="min-h-screen bg-[#f6f7fb] text-slate-950">
      <div className="mx-auto min-h-screen max-w-[1500px] xl:grid xl:grid-cols-[255px_minmax(0,1fr)_390px]">
        <aside className="hidden border-r border-slate-200 bg-white px-5 py-7 xl:flex xl:flex-col">
          <div className="flex items-center gap-3">
            <div className="grid h-11 w-11 place-items-center rounded-2xl bg-coral text-white shadow-lg shadow-coral/20"><UtensilsCrossed size={22} /></div>
            <div><p className="text-lg font-black tracking-tight">SmartRes</p><p className="text-xs text-slate-500">Gọi món tại bàn</p></div>
          </div>

          <div className="mt-9 rounded-3xl bg-slate-950 p-5 text-white">
            <p className="text-xs uppercase tracking-[0.18em] text-white/50">Bạn đang ngồi tại</p>
            <p className="mt-2 text-2xl font-black">{tableName}</p>
            <div className="mt-4 flex items-center gap-2 text-xs text-emerald-300"><span className="h-2 w-2 rounded-full bg-emerald-400" />{token ? 'Sẵn sàng gọi món' : 'Đang xem thực đơn'}</div>
          </div>

          <nav className="mt-8 space-y-2">
            <button className="flex w-full items-center gap-3 rounded-2xl bg-coral/10 px-4 py-3.5 text-sm font-bold text-coral"><UtensilsCrossed size={19} /> Thực đơn</button>
            <button onClick={() => setCartOpen(true)} className="flex w-full items-center justify-between rounded-2xl px-4 py-3.5 text-sm font-semibold text-slate-600 hover:bg-slate-100">
              <span className="flex items-center gap-3"><ShoppingBag size={19} /> Giỏ hàng</span>
              {cartCount > 0 && <span className="rounded-full bg-coral px-2 py-0.5 text-xs text-white">{cartCount}</span>}
            </button>
            <button className="flex w-full items-center gap-3 rounded-2xl px-4 py-3.5 text-sm font-semibold text-slate-600 hover:bg-slate-100"><ReceiptText size={19} /> Đơn của tôi</button>
          </nav>

          <div className="mt-auto rounded-3xl border border-coral/15 bg-[#fff7f4] p-4">
            <div className="flex items-center gap-2 font-bold"><ConciergeBell size={18} className="text-coral" /> Cần hỗ trợ?</div>
            <p className="mt-2 text-xs leading-5 text-slate-500">Gọi nhân viên đến bàn nếu bạn cần tư vấn hoặc thanh toán tiền mặt.</p>
            <button className="mt-4 w-full rounded-xl border border-coral/25 bg-white py-2.5 text-sm font-bold text-coral">Gọi nhân viên</button>
          </div>
        </aside>

        <section className="min-w-0 pb-28 xl:pb-10">
          <header className="sticky top-0 z-20 border-b border-slate-200/80 bg-white/90 px-4 py-3 backdrop-blur-xl sm:px-7 xl:relative xl:px-8 xl:py-6">
            <div className="mx-auto flex max-w-5xl items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="grid h-10 w-10 place-items-center rounded-full bg-coral text-white xl:hidden"><UtensilsCrossed size={18} /></div>
                <div><p className="text-lg font-black tracking-tight sm:text-xl">Thực đơn nhà hàng</p><p className="text-xs text-slate-500 xl:hidden">{tableName} · {token ? 'Đang phục vụ' : 'Xem thực đơn'}</p></div>
              </div>
              <button onClick={() => setCartOpen(true)} className="relative grid h-11 w-11 place-items-center rounded-full bg-slate-100 text-slate-700 xl:hidden" aria-label="Mở giỏ hàng">
                <ShoppingBag size={20} />
                {cartCount > 0 && <span className="absolute -right-1 -top-1 grid h-5 min-w-5 place-items-center rounded-full bg-coral px-1 text-[10px] font-bold text-white">{cartCount}</span>}
              </button>
              <div className="hidden items-center gap-3 xl:flex"><span className="inline-flex items-center gap-2 rounded-full bg-emerald-50 px-3 py-2 text-xs font-bold text-emerald-700"><Clock3 size={15} /> {token ? 'Bếp đang nhận món' : 'Xem thực đơn'}</span></div>
            </div>
          </header>

          <div className="mx-auto max-w-5xl px-4 py-5 sm:px-7 xl:px-8 xl:py-7">
            <section className="relative overflow-hidden rounded-[28px] bg-slate-950 px-5 py-6 text-white sm:px-8 sm:py-8">
              <div className="relative z-10 max-w-xl">
                <span className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1.5 text-xs font-semibold text-white/80"><Sparkles size={14} /> Gợi ý hôm nay</span>
                <h1 className="mt-4 text-2xl font-black leading-tight sm:text-4xl">Món ngon sẵn sàng<br className="hidden sm:block" /> cho bàn của bạn</h1>
                <p className="mt-3 max-w-md text-sm leading-6 text-white/60">Chọn món, tùy chỉnh khẩu phần và gửi thẳng yêu cầu đến bếp chỉ trong vài bước.</p>
              </div>
              <div className="absolute -bottom-16 -right-10 h-52 w-52 rounded-full bg-coral/80 blur-2xl" />
              <div className="absolute right-8 top-8 hidden text-8xl sm:block">🍲</div>
            </section>

            {menuError && <p className="mt-4 rounded-2xl bg-amber-50 px-4 py-3 text-sm font-semibold text-amber-800">{menuError}</p>}
            {orderCode && (
              <div className="mt-4 rounded-2xl border border-coral/20 bg-white p-4" aria-live="polite">
                <button type="button" disabled={requestingPayment || paymentRequested} onClick={requestPayment} className="rounded-xl bg-coral px-4 py-3 text-sm font-bold text-white disabled:opacity-60">
                  {paymentRequested ? "Đã gửi yêu cầu đến thu ngân" : requestingPayment ? "Đang gửi..." : "Yêu cầu thanh toán"}
                </button>
                {paymentRequested && <p className="mt-2 text-sm text-slate-600">Vui lòng chờ nhân viên kiểm tra hóa đơn và xác nhận phương thức thanh toán.</p>}
                {paymentError && <p role="alert" className="mt-2 text-sm text-red-700">{paymentError}</p>}
              </div>
            )}

            <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center">
              <label className="relative min-w-0 flex-1">
                <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Tìm món trong thực đơn" className="h-12 w-full rounded-2xl border border-slate-200 bg-white pl-11 pr-4 text-sm outline-none transition focus:border-coral focus:ring-4 focus:ring-coral/10" />
              </label>
              <button className="hidden h-12 items-center gap-2 rounded-2xl border border-slate-200 bg-white px-4 text-sm font-bold text-slate-600 sm:inline-flex"><ConciergeBell size={18} /> Gọi nhân viên</button>
            </div>

            <div className="no-scrollbar mt-4 flex gap-2 overflow-x-auto pb-1">
              {categories.map((item) => (
                <button key={item} onClick={() => setCategory(item)} className={`whitespace-nowrap rounded-full px-4 py-2.5 text-sm font-bold transition ${category === item ? "bg-coral text-white shadow-lg shadow-coral/20" : "border border-slate-200 bg-white text-slate-500 hover:border-coral/40"}`}>{item}</button>
              ))}
            </div>

            <div className="mt-7 flex items-end justify-between">
              <div><p className="text-xs font-bold uppercase tracking-[0.18em] text-coral">Khám phá</p><h2 className="mt-1 text-2xl font-black">{category === "Tất cả" ? "Món nổi bật" : category}</h2></div>
              <span className="text-sm text-slate-400">{filteredItems.length} món</span>
            </div>

            {filteredItems.length ? (
              <div className="mt-4 grid gap-4 md:grid-cols-2 2xl:grid-cols-3">
                {filteredItems.map((item) => (
                  <article key={item.id} className="group flex gap-4 rounded-[24px] border border-slate-200 bg-white p-3 shadow-sm transition hover:-translate-y-0.5 hover:border-coral/20 hover:shadow-xl hover:shadow-slate-200/60 md:flex-col">
                    <button onClick={() => openDetail(item)} className="text-left md:w-full" aria-label={`Xem ${item.name}`}><FoodArtwork item={item} large /></button>
                    <div className="flex min-w-0 flex-1 flex-col px-0 py-1 md:px-2 md:pb-2">
                      <div className="flex items-start justify-between gap-2">
                        <button onClick={() => openDetail(item)} className="text-left text-base font-black leading-5 hover:text-coral">{item.name}</button>
                        {item.badge && <span className="hidden shrink-0 rounded-full bg-coral/10 px-2.5 py-1 text-[10px] font-bold text-coral sm:inline">{item.badge}</span>}
                      </div>
                      <p className="mt-1.5 line-clamp-2 text-xs leading-5 text-slate-500">{item.description}</p>
                      <div className="mt-auto flex items-center justify-between pt-3">
                        <span className="text-base font-black text-coral">{formatPrice(item.price)}</span>
                        <button onClick={() => openDetail(item)} className="grid h-9 w-9 place-items-center rounded-xl bg-coral text-white shadow-md shadow-coral/20 transition group-hover:scale-105" aria-label={`Thêm ${item.name}`}><Plus size={18} /></button>
                      </div>
                    </div>
                  </article>
                ))}
              </div>
            ) : (
              <div className="mt-4 rounded-3xl border border-dashed border-slate-300 bg-white px-6 py-16 text-center"><Search className="mx-auto text-slate-300" size={32} /><p className="mt-3 font-bold">Không tìm thấy món phù hợp</p><p className="mt-1 text-sm text-slate-500">Thử từ khóa khác hoặc chọn lại danh mục.</p></div>
            )}
          </div>
        </section>

        <aside className="hidden border-l border-slate-200 bg-white xl:block">
          <CartPanel tableName={tableName} cart={cart} subtotal={subtotal} onQuantityChange={updateCartQuantity} onOrder={placeOrder} isOrdering={isOrdering} orderError={orderError} />
        </aside>
      </div>

      <nav className="fixed inset-x-0 bottom-0 z-30 mx-auto grid max-w-md grid-cols-3 border-t border-slate-200 bg-white/95 px-4 pb-[max(10px,env(safe-area-inset-bottom))] pt-2 shadow-[0_-8px_30px_rgba(15,23,42,0.08)] backdrop-blur-xl xl:hidden">
        <button className="flex flex-col items-center gap-1 py-1 text-[11px] font-bold text-coral"><UtensilsCrossed size={20} /> Thực đơn</button>
        <button onClick={() => setCartOpen(true)} className="relative flex flex-col items-center gap-1 py-1 text-[11px] font-semibold text-slate-500"><span className="relative"><ShoppingBag size={20} />{cartCount > 0 && <span className="absolute -right-3 -top-2 grid h-5 min-w-5 place-items-center rounded-full bg-coral px-1 text-[10px] font-bold text-white">{cartCount}</span>}</span>Giỏ hàng</button>
        <button className="flex flex-col items-center gap-1 py-1 text-[11px] font-semibold text-slate-500"><ReceiptText size={20} /> Đơn của tôi</button>
      </nav>

      {selectedItem && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-slate-950/50 p-0 backdrop-blur-sm sm:items-center sm:p-6" role="dialog" aria-modal="true" aria-label={`Tùy chọn ${selectedItem.name}`}>
          <div className="max-h-[94vh] w-full max-w-2xl overflow-y-auto rounded-t-[32px] bg-white shadow-2xl sm:rounded-[32px]">
            <div className="relative">
              <FoodArtwork item={selectedItem} large />
              <button onClick={() => setSelectedItem(null)} className="absolute left-4 top-4 grid h-11 w-11 place-items-center rounded-full bg-white text-slate-900 shadow-lg" aria-label="Đóng"><ArrowLeft size={20} /></button>
            </div>
            <div className="p-5 sm:p-7">
              <div className="flex items-start justify-between gap-4">
                <div><h2 className="text-2xl font-black">{selectedItem.name}</h2><p className="mt-2 text-sm leading-6 text-slate-500">{selectedItem.description}</p></div>
                {selectedItem.badge && <span className="shrink-0 rounded-full bg-coral/10 px-3 py-1.5 text-xs font-bold text-coral">{selectedItem.badge}</span>}
              </div>
              <p className="mt-3 text-xl font-black text-coral">{formatPrice(selectedItem.price)}</p>

              <div className="mt-6 border-t border-slate-100 pt-5">
                <div className="flex justify-between"><h3 className="font-black">Chọn khẩu phần</h3><span className="text-xs font-bold text-coral">Bắt buộc</span></div>
                <div className="mt-3 grid grid-cols-3 gap-2">
                  {(Object.keys(sizePrices) as Array<keyof typeof sizePrices>).map((size) => (
                    <button key={size} onClick={() => setSelectedSize(size)} className={`rounded-2xl border p-3 text-left transition ${selectedSize === size ? "border-coral bg-coral/5 ring-2 ring-coral/10" : "border-slate-200"}`}>
                      <span className={`block text-sm font-black ${selectedSize === size ? "text-coral" : ""}`}>{size}</span>
                      <span className="mt-1 block text-[11px] text-slate-400">{sizePrices[size] === 0 ? formatPrice(selectedItem.price) : `${sizePrices[size] > 0 ? "+" : "−"}${formatPrice(Math.abs(sizePrices[size]))}`}</span>
                    </button>
                  ))}
                </div>
              </div>

              <div className="mt-6">
                <div className="flex justify-between"><h3 className="font-black">Món thêm</h3><span className="text-xs text-slate-400">Tùy chọn</span></div>
                <div className="mt-2 space-y-1">
                  {Object.entries(extraPrices).map(([extra, price]) => {
                    const checked = extras.includes(extra);
                    return (
                      <button key={extra} onClick={() => setExtras((current) => checked ? current.filter((value) => value !== extra) : [...current, extra])} className="flex w-full items-center justify-between rounded-xl px-1 py-3 text-sm">
                        <span className="flex items-center gap-3"><span className={`grid h-5 w-5 place-items-center rounded-md border ${checked ? "border-coral bg-coral text-white" : "border-slate-300"}`}>{checked && <Check size={13} />}</span>{extra}</span>
                        <span className="text-slate-500">+{formatPrice(price)}</span>
                      </button>
                    );
                  })}
                </div>
              </div>

              <label className="mt-5 block"><span className="font-black">Ghi chú cho bếp</span><textarea value={note} onChange={(event) => setNote(event.target.value)} placeholder="Ví dụ: không hành, ít cay..." className="mt-3 min-h-20 w-full resize-none rounded-2xl border border-slate-200 bg-slate-50 p-4 text-sm outline-none focus:border-coral" /></label>
              <div className="mt-6 flex items-center gap-3"><QuantityControl value={detailQuantity} onChange={(value) => setDetailQuantity(Math.max(1, value))} /><button onClick={addSelectedItem} className="h-12 flex-1 rounded-2xl bg-coral px-4 text-sm font-black text-white shadow-lg shadow-coral/20">Thêm vào giỏ · {formatPrice(selectedPrice * detailQuantity)}</button></div>
            </div>
          </div>
        </div>
      )}

      {cartOpen && (
        <div className="fixed inset-0 z-50 bg-slate-950/50 backdrop-blur-sm xl:hidden" role="dialog" aria-modal="true" aria-label="Giỏ hàng">
          <div className="ml-auto h-full w-full max-w-md overflow-y-auto bg-white shadow-2xl">
            <button onClick={() => setCartOpen(false)} className="absolute right-4 top-4 z-10 grid h-10 w-10 place-items-center rounded-full bg-slate-100" aria-label="Đóng giỏ hàng"><X size={18} /></button>
            <CartPanel tableName={tableName} cart={cart} subtotal={subtotal} onQuantityChange={updateCartQuantity} onOrder={placeOrder} isOrdering={isOrdering} orderError={orderError} />
          </div>
        </div>
      )}

      {orderPlaced && (
        <div className="fixed inset-0 z-[60] grid place-items-center bg-slate-950/55 p-5 backdrop-blur-sm" role="dialog" aria-modal="true" aria-label="Đặt món thành công">
          <div className="w-full max-w-sm rounded-[32px] bg-white p-7 text-center shadow-2xl">
            <div className="mx-auto grid h-20 w-20 place-items-center rounded-full bg-emerald-100 text-emerald-600"><CheckCircle2 size={40} /></div>
            <h2 className="mt-5 text-2xl font-black">Đã gửi món đến bếp!</h2>
            <p className="mt-2 text-sm leading-6 text-slate-500">Đơn {orderCode ? `#${orderCode}` : ""} của {tableName} đã được ghi nhận. Bếp sẽ bắt đầu chuẩn bị trong ít phút.</p>
            <div className="mt-5 flex items-center justify-center gap-2 rounded-2xl bg-amber-50 px-4 py-3 text-sm font-bold text-amber-700"><ChefHat size={18} /> Trạng thái: Đơn mới</div>
            <button onClick={() => { setOrderPlaced(false); setCart([]); }} className="mt-5 h-12 w-full rounded-2xl bg-coral font-black text-white">Tiếp tục xem thực đơn</button>
          </div>
        </div>
      )}
    </main>
  );
}

function CartPanel({ tableName, cart, subtotal, onQuantityChange, onOrder, isOrdering, orderError }: { tableName: string; cart: CartItem[]; subtotal: number; onQuantityChange: (key: string, quantity: number) => void; onOrder: () => void; isOrdering: boolean; orderError: string | null }) {
  return (
    <div className="sticky top-0 flex min-h-screen flex-col px-5 py-6">
      <div className="pr-12 xl:pr-0">
        <p className="text-xs font-bold uppercase tracking-[0.18em] text-coral">{tableName}</p>
        <div className="mt-1 flex items-center justify-between"><h2 className="text-2xl font-black">Giỏ hàng</h2><span className="rounded-full bg-coral/10 px-3 py-1 text-xs font-bold text-coral">{cart.reduce((sum, item) => sum + item.quantity, 0)} món</span></div>
      </div>

      {cart.length ? (
        <>
          <div className="mt-6 space-y-3">
            {cart.map((cartItem) => (
              <article key={cartItem.key} className="rounded-2xl border border-slate-200 p-3">
                <div className="flex gap-3">
                  <FoodArtwork item={cartItem.item} />
                  <div className="min-w-0 flex-1">
                    <p className="font-black leading-5">{cartItem.item.name}</p>
                    <p className="mt-1 truncate text-xs text-slate-400">Khẩu phần {cartItem.size}{cartItem.extras.length ? ` · ${cartItem.extras.join(", ")}` : ""}</p>
                    {cartItem.note && <p className="mt-1 truncate text-xs text-slate-500">Ghi chú: {cartItem.note}</p>}
                    <div className="mt-3 flex items-center justify-between"><span className="font-black text-coral">{formatPrice(cartItem.unitPrice)}</span><QuantityControl value={cartItem.quantity} onChange={(value) => onQuantityChange(cartItem.key, value)} /></div>
                  </div>
                </div>
              </article>
            ))}
          </div>
          <label className="mt-5 block"><span className="text-sm font-black">Ghi chú đơn hàng</span><textarea placeholder="Ví dụ: phục vụ món nóng trước" className="mt-2 min-h-20 w-full resize-none rounded-2xl border border-slate-200 bg-slate-50 p-3 text-sm outline-none focus:border-coral" /></label>
          <div className="mt-5 rounded-2xl bg-slate-50 p-4">
            <div className="flex justify-between text-sm text-slate-500"><span>Tạm tính</span><span>{formatPrice(subtotal)}</span></div>
            <div className="mt-2 flex justify-between text-sm text-slate-500"><span>Phí phục vụ</span><span className="text-emerald-600">0đ</span></div>
            <div className="mt-4 flex justify-between border-t border-slate-200 pt-4"><span className="font-black">Tổng cộng</span><span className="text-xl font-black text-coral">{formatPrice(subtotal)}</span></div>
          </div>
          {orderError && <p className="mt-4 rounded-xl bg-red-50 px-3 py-2 text-sm font-semibold text-red-700">{orderError}</p>}
          <button disabled={isOrdering} onClick={onOrder} className="mt-5 w-full rounded-2xl bg-coral px-4 py-3.5 font-black text-white shadow-lg shadow-coral/20 disabled:cursor-not-allowed disabled:opacity-60">{isOrdering ? "Đang gửi đơn..." : "Xác nhận gọi món"}</button>
          <p className="mt-3 text-center text-xs leading-5 text-slate-400">Bạn có thể gọi thêm món trong cùng phiên bàn sau khi xác nhận.</p>
        </>
      ) : (
        <div className="flex flex-1 flex-col items-center justify-center py-16 text-center">
          <div className="grid h-20 w-20 place-items-center rounded-full bg-slate-100 text-slate-300"><ShoppingBag size={34} /></div>
          <h3 className="mt-5 text-lg font-black">Giỏ hàng đang trống</h3>
          <p className="mt-2 max-w-xs text-sm leading-6 text-slate-500">Chọn một món trong thực đơn để bắt đầu gọi món cho {tableName}.</p>
        </div>
      )}
    </div>
  );
}
