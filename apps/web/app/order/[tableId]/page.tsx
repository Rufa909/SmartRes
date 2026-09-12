import { Bot, CreditCard, Plus, ShoppingCart } from "lucide-react";

const menu = [
  { id: "1", name: "Com ga sot nam", price: 69000, category: "Mon chinh" },
  { id: "2", name: "Mi y bo bam", price: 79000, category: "Mon chinh" },
  { id: "3", name: "Tra dao cam sa", price: 39000, category: "Do uong" },
  { id: "4", name: "Combo trua nhanh", price: 99000, category: "Combo" }
];

export default async function OrderPage({ params }: { params: Promise<{ tableId: string }> }) {
  const { tableId } = await params;

  return (
    <main className="min-h-screen bg-white">
      <header className="border-b border-ink/10 px-5 py-4">
        <div className="mx-auto flex max-w-5xl items-center justify-between">
          <div>
            <p className="text-sm text-ink/60">Ban</p>
            <h1 className="text-2xl font-semibold">{tableId}</h1>
          </div>
          <button className="inline-flex h-10 items-center gap-2 rounded-md bg-leaf px-4 text-sm font-semibold text-white">
            <ShoppingCart size={18} />
            Gio hang
          </button>
        </div>
      </header>

      <div className="mx-auto grid max-w-5xl gap-6 px-5 py-6 lg:grid-cols-[1fr_320px]">
        <section>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-xl font-semibold">Menu hom nay</h2>
            <span className="rounded-md bg-mist px-3 py-1 text-sm text-ink/70">Dynamic QR Session</span>
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            {menu.map((item) => (
              <article key={item.id} className="rounded-lg border border-ink/10 p-4">
                <p className="text-xs font-semibold uppercase text-saffron">{item.category}</p>
                <h3 className="mt-2 font-semibold">{item.name}</h3>
                <p className="mt-1 text-sm text-ink/60">Tuy chon size, topping va ghi chu rieng.</p>
                <div className="mt-4 flex items-center justify-between">
                  <span className="font-semibold">{item.price.toLocaleString("vi-VN")} d</span>
                  <button className="inline-flex h-9 w-9 items-center justify-center rounded-md bg-ink text-white" aria-label={`Them ${item.name}`}>
                    <Plus size={18} />
                  </button>
                </div>
              </article>
            ))}
          </div>
        </section>

        <aside className="space-y-4">
          <section className="rounded-lg border border-ink/10 bg-mist p-4">
            <div className="flex items-center gap-2 font-semibold">
              <Bot size={18} />
              AI goi mon
            </div>
            <textarea
              className="mt-3 min-h-28 w-full rounded-md border border-ink/10 bg-white p-3 text-sm outline-none focus:border-leaf"
              placeholder="Vi du: Cho toi mot com ga it cay va mot tra dao..."
            />
            <button className="mt-3 w-full rounded-md bg-leaf px-4 py-2 text-sm font-semibold text-white">Phan tich yeu cau</button>
          </section>
          <section className="rounded-lg border border-ink/10 p-4">
            <div className="flex items-center gap-2 font-semibold">
              <CreditCard size={18} />
              Thanh toan
            </div>
            <p className="mt-2 text-sm text-ink/60">Ho tro SEPay VietQR hoac thanh toan tien mat tai quay.</p>
          </section>
        </aside>
      </div>
    </main>
  );
}
