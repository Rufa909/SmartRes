import { Banknote, CircleDollarSign, LayoutGrid, Users } from "lucide-react";

const tables = [
  { name: "Ban 01", status: "Dang dung bua", tone: "bg-saffron/20 text-ink" },
  { name: "Ban 02", status: "Cho thanh toan", tone: "bg-leaf/20 text-ink" },
  { name: "Ban 03", status: "Trong", tone: "bg-mist text-ink" },
  { name: "Ban 04", status: "Trong", tone: "bg-mist text-ink" }
];

export default function DashboardPage() {
  return (
    <main className="min-h-screen">
      <header className="border-b border-ink/10 bg-white px-6 py-4">
        <div className="mx-auto flex max-w-6xl items-center gap-3">
          <LayoutGrid className="text-leaf" />
          <h1 className="text-2xl font-semibold">Management Dashboard</h1>
        </div>
      </header>

      <section className="mx-auto grid max-w-6xl gap-4 px-6 py-6 md:grid-cols-3">
        <article className="rounded-lg border border-ink/10 bg-white p-4">
          <CircleDollarSign className="text-leaf" />
          <p className="mt-3 text-sm text-ink/60">Doanh thu hom nay</p>
          <strong className="text-2xl">8.450.000 d</strong>
        </article>
        <article className="rounded-lg border border-ink/10 bg-white p-4">
          <Banknote className="text-saffron" />
          <p className="mt-3 text-sm text-ink/60">Giao dich cho doi soat</p>
          <strong className="text-2xl">3</strong>
        </article>
        <article className="rounded-lg border border-ink/10 bg-white p-4">
          <Users className="text-leaf" />
          <p className="mt-3 text-sm text-ink/60">Nhan vien dang ca</p>
          <strong className="text-2xl">6</strong>
        </article>
      </section>

      <section className="mx-auto max-w-6xl px-6 pb-8">
        <h2 className="mb-4 text-xl font-semibold">So do ban real-time</h2>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {tables.map((table) => (
            <article key={table.name} className={`rounded-lg border border-ink/10 p-4 ${table.tone}`}>
              <h3 className="text-lg font-semibold">{table.name}</h3>
              <p className="mt-2 text-sm">{table.status}</p>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}

