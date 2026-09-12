import { Bot, ChefHat, CreditCard, LayoutDashboard, QrCode, Utensils } from "lucide-react";
import Link from "next/link";

const modules = [
  {
    href: "/order/demo-table-01",
    title: "Customer Web App",
    description: "Quet QR, xem menu, tuy bien mon, dat hang va thanh toan VietQR.",
    icon: QrCode
  },
  {
    href: "/kds",
    title: "Kitchen Display System",
    description: "Nhan don moi real-time, cap nhat trang thai che bien va in phieu bep.",
    icon: ChefHat
  },
  {
    href: "/dashboard",
    title: "Management Dashboard",
    description: "Theo doi so do ban, giao dich, menu, nhan vien va doanh thu nhanh.",
    icon: LayoutDashboard
  }
];

const highlights = [
  { label: "AI Chatbot", icon: Bot },
  { label: "Smart Upsell", icon: Utensils },
  { label: "SEPay VietQR", icon: CreditCard }
];

export default function HomePage() {
  return (
    <main className="min-h-screen">
      <section className="border-b border-ink/10 bg-white">
        <div className="mx-auto flex max-w-6xl flex-col gap-6 px-6 py-10">
          <div>
            <p className="text-sm font-semibold uppercase tracking-wide text-leaf">SmartRes</p>
            <h1 className="mt-2 max-w-3xl text-4xl font-semibold text-ink">
              He thong nha hang va tu phuc vu thong minh ung dung AI & real-time
            </h1>
          </div>
          <div className="flex flex-wrap gap-3">
            {highlights.map((item) => (
              <span key={item.label} className="inline-flex items-center gap-2 rounded-md border border-ink/10 bg-mist px-3 py-2 text-sm">
                <item.icon size={16} />
                {item.label}
              </span>
            ))}
          </div>
        </div>
      </section>

      <section className="mx-auto grid max-w-6xl gap-4 px-6 py-8 md:grid-cols-3">
        {modules.map((module) => (
          <Link
            key={module.href}
            href={module.href}
            className="rounded-lg border border-ink/10 bg-white p-5 shadow-sm transition hover:border-leaf/40 hover:shadow-md"
          >
            <module.icon className="text-leaf" size={28} />
            <h2 className="mt-4 text-xl font-semibold">{module.title}</h2>
            <p className="mt-2 text-sm leading-6 text-ink/70">{module.description}</p>
          </Link>
        ))}
      </section>
    </main>
  );
}

