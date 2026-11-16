"use client";

import { LoaderCircle, MessageCircle, Send, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import type { FormEvent } from "react";

type MenuItem = { id: number; name: string; price: number; description: string; category: string; color: string; symbol: string; imageUrl?: string | null };
type ChatLine = { id: number; role: "assistant" | "user"; text: string; provider?: "gemini" | "rule-based"; suggestions?: Array<{ id: number; name: string; price: number; description: string; reason: string }> };

const money = (value: number) => `${new Intl.NumberFormat("vi-VN").format(value)}đ`;

function GeminiMark({ className = "h-6 w-6" }: { className?: string }) {
  return <svg aria-hidden="true" viewBox="0 0 24 24" className={className}>
    <defs>
      <linearGradient id="gemini-mark-gradient" x1="3" y1="3" x2="21" y2="21" gradientUnits="userSpaceOnUse">
        <stop stopColor="#4285F4" />
        <stop offset="0.32" stopColor="#9B72CB" />
        <stop offset="0.66" stopColor="#D96570" />
        <stop offset="1" stopColor="#F4AF39" />
      </linearGradient>
    </defs>
    <path fill="url(#gemini-mark-gradient)" d="M12 1.5c0 5.8-4.7 10.5-10.5 10.5C7.3 12 12 16.7 12 22.5 12 16.7 16.7 12 22.5 12 16.7 12 12 7.3 12 1.5Z" />
  </svg>;
}

export function MenuChatbot({ cartItemIds, onAdd }: { cartItemIds: number[]; onAdd: (item: MenuItem) => boolean }) {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);
  const [lines, setLines] = useState<ChatLine[]>([{ id: 1, role: "assistant", text: "Chào bạn! Mình có thể tư vấn món đang bán theo khẩu vị hoặc giúp bạn xem giá. Bạn đang muốn ăn món gì?" }]);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [lines, open]);

  async function sendMessage(event?: FormEvent, suggestedText?: string) {
    event?.preventDefault();
    const message = (suggestedText ?? draft).trim();
    if (!message || busy) return;
    const userLine: ChatLine = { id: Date.now(), role: "user", text: message };
    setLines((current) => [...current, userLine]);
    setDraft("");
    setBusy(true);
    try {
      const response = await fetch("/api/customer/chatbot/message", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message, cartItemIds }),
      });
      const data = await response.json() as { reply?: string; suggestions?: ChatLine["suggestions"]; provider?: ChatLine["provider"] };
      if (!response.ok) throw new Error("Chatbot chưa kết nối được. Bạn thử lại sau nhé.");
      setLines((current) => [...current, { id: Date.now() + 1, role: "assistant", text: data.reply || "Bạn nói rõ thêm một chút nhé.", suggestions: data.suggestions, provider: data.provider }]);
    } catch (error) {
      setLines((current) => [...current, { id: Date.now() + 1, role: "assistant", text: error instanceof Error ? error.message : "Mình chưa kết nối được. Bạn thử lại sau nhé." }]);
    } finally {
      setBusy(false);
    }
  }

  return <>
    <button type="button" onClick={() => setOpen(true)} className="fixed bottom-24 right-4 z-40 inline-flex items-center gap-2 rounded-full bg-slate-950 px-4 py-3 text-sm font-bold text-white shadow-xl shadow-slate-950/20 transition hover:bg-coral xl:bottom-6 xl:right-6" aria-label="Mở trợ lý chọn món">
      <MessageCircle size={18} /><span>Trợ lý chọn món</span>
    </button>
    {open && <div className="fixed inset-0 z-[70] flex items-end justify-center bg-slate-950/35 sm:items-center sm:p-5" role="dialog" aria-modal="true" aria-label="Trợ lý chọn món">
      <section className="flex h-[min(680px,92dvh)] w-full max-w-md flex-col overflow-hidden rounded-t-[28px] bg-white shadow-2xl sm:h-[min(680px,88dvh)] sm:rounded-[28px]">
        <header className="flex items-center justify-between bg-slate-950 px-5 py-4 text-white">
          <div className="flex items-center gap-3"><span className="grid h-10 w-10 place-items-center rounded-2xl bg-white"><GeminiMark /></span><div><h2 className="font-black">Trợ lý Gemini giúp chọn món</h2><p className="text-xs text-white/65">Tư vấn từ thực đơn nhà hàng</p></div></div>
          <button type="button" onClick={() => setOpen(false)} className="grid h-9 w-9 place-items-center rounded-full bg-white/10" aria-label="Đóng chatbot"><X size={18} /></button>
        </header>
        <div className="flex-1 space-y-4 overflow-y-auto bg-[#f7f7fa] p-4" aria-live="polite">
          {lines.map((line) => <div key={line.id} className={`flex ${line.role === "user" ? "justify-end" : "justify-start"}`}>
            <div className={`max-w-[90%] rounded-2xl px-3.5 py-3 ${line.role === "user" ? "rounded-br-md bg-coral text-white" : "rounded-bl-md border border-slate-200 bg-white text-slate-800"}`}>
              <p className="whitespace-pre-wrap text-sm leading-5">{line.text}</p>
              {line.role === "assistant" && line.provider && <p className="mt-1 text-[10px] text-slate-400">{line.provider === "gemini" ? "Gemini" : "Chế độ dự phòng"}</p>}
              {line.suggestions?.map((suggestion) => <article key={suggestion.id} className="mt-3 rounded-xl border border-slate-200 bg-white p-3 text-slate-900">
                <div className="flex items-start justify-between gap-2"><div><p className="text-sm font-black">{suggestion.name}</p><p className="mt-0.5 text-[11px] text-slate-500">{suggestion.reason}</p></div><span className="shrink-0 text-xs font-black text-coral">{money(suggestion.price)}</span></div>
                {suggestion.description && <p className="mt-2 line-clamp-2 text-xs leading-4 text-slate-500">{suggestion.description}</p>}
                <button type="button" onClick={() => { const added = onAdd({ ...suggestion, category: "", color: "#fff0eb", symbol: "🍽️" }); setLines((current) => [...current, { id: Date.now(), role: "assistant", text: added ? `Đã thêm ${suggestion.name} vào giỏ. Bạn vẫn có thể xem lại giỏ trước khi gửi món.` : `Món ${suggestion.name} vừa ngừng bán nên chưa được thêm vào giỏ.` }]); }} className="mt-2 rounded-lg bg-coral/10 px-3 py-1.5 text-xs font-bold text-coral hover:bg-coral hover:text-white">Thêm vào giỏ</button>
              </article>)}
            </div>
          </div>)}
          {busy && <div className="inline-flex items-center gap-2 rounded-2xl bg-white px-3 py-2 text-xs text-slate-500"><LoaderCircle size={14} className="animate-spin" /> Đang xem thực đơn…</div>}
          <div ref={endRef} />
        </div>
        <div className="flex gap-2 overflow-x-auto border-t border-slate-100 px-4 py-2.5">
          {["Món nào dễ ăn?", "Có món chay không?", "Gợi ý đồ uống"].map((text) => <button key={text} type="button" disabled={busy} onClick={() => void sendMessage(undefined, text)} className="shrink-0 rounded-full border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-600 disabled:opacity-50">{text}</button>)}
        </div>
        <form onSubmit={(event) => void sendMessage(event)} className="flex items-center gap-2 border-t border-slate-100 p-3 pb-[max(12px,env(safe-area-inset-bottom))]">
          <input value={draft} onChange={(event) => setDraft(event.target.value)} maxLength={400} placeholder="Ví dụ: Món nào ít cay?" className="h-11 min-w-0 flex-1 rounded-xl bg-slate-100 px-4 text-sm outline-none focus:ring-2 focus:ring-coral/30" />
          <button type="submit" disabled={!draft.trim() || busy} className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-coral text-white disabled:opacity-50" aria-label="Gửi tin nhắn"><Send size={17} /></button>
        </form>
      </section>
    </div>}
  </>;
}
