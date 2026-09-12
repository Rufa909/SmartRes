import { Bell, CheckCircle2, ChefHat, Clock } from "lucide-react";

const orders = [
  { code: "SR1001", table: "Ban 01", status: "Dang chuan bi", items: ["Com ga sot nam x2", "Tra dao x1"] },
  { code: "SR1002", table: "Ban 02", status: "Dang nau", items: ["Mi y bo bam x1"] }
];

export default function KdsPage() {
  return (
    <main className="min-h-screen bg-ink text-white">
      <header className="border-b border-white/10 px-6 py-4">
        <div className="mx-auto flex max-w-6xl items-center justify-between">
          <div className="flex items-center gap-3">
            <ChefHat className="text-saffron" />
            <h1 className="text-2xl font-semibold">Kitchen Display System</h1>
          </div>
          <button className="inline-flex items-center gap-2 rounded-md bg-saffron px-4 py-2 text-sm font-semibold text-ink">
            <Bell size={17} />
            Am bao don moi
          </button>
        </div>
      </header>

      <section className="mx-auto grid max-w-6xl gap-4 px-6 py-6 md:grid-cols-2">
        {orders.map((order) => (
          <article key={order.code} className="rounded-lg border border-white/10 bg-white p-5 text-ink">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-sm text-ink/60">{order.table}</p>
                <h2 className="text-2xl font-semibold">{order.code}</h2>
              </div>
              <span className="inline-flex items-center gap-2 rounded-md bg-mist px-3 py-2 text-sm">
                <Clock size={16} />
                {order.status}
              </span>
            </div>
            <ul className="mt-5 space-y-2">
              {order.items.map((item) => (
                <li key={item} className="rounded-md bg-mist px-3 py-2 text-sm">{item}</li>
              ))}
            </ul>
            <button className="mt-5 inline-flex w-full items-center justify-center gap-2 rounded-md bg-leaf px-4 py-3 font-semibold text-white">
              <CheckCircle2 size={18} />
              Hoan thanh
            </button>
          </article>
        ))}
      </section>
    </main>
  );
}

