import { Router } from "express";
import { z } from "zod";
import type { MenuRepository } from "../repositories/menu.repository.js";
import { replyToMenuQuestion } from "../services/chatbot.service.js";

const messageSchema = z.object({
  message: z.string().trim().min(1).max(400),
  cartItemIds: z.array(z.number().int().positive()).max(50).default([]),
  partySize: z.number().int().min(1).max(99).optional(),
});

export function createChatbotRouter(menuRepository: MenuRepository, aiServiceUrl: string) {
  const router = Router();
  router.post("/message", async (req, res, next) => {
    try {
      const input = messageSchema.parse(req.body);
      const menu = await menuRepository.findAvailableMenu();
      const menuItems = menu as Parameters<typeof replyToMenuQuestion>[1];
      const fallback = () => replyToMenuQuestion(input.message, menuItems, input.cartItemIds, input.partySize);
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 8000);
        let aiResponse: Response;
        try {
          aiResponse = await fetch(`${aiServiceUrl.replace(/\/$/, "")}/chatbot/recommend`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            signal: controller.signal,
            body: JSON.stringify({
              message: input.message,
              cart_item_ids: input.cartItemIds,
              party_size: input.partySize,
              menu: menuItems.map(({ id, name, description, category }) => ({ id, name, description, category })),
            }),
          });
        } finally {
          clearTimeout(timeout);
        }
        if (!aiResponse.ok) throw new Error("AI service unavailable");
        const generated = z.object({ reply: z.string().min(1).max(600), suggested_ids: z.array(z.number().int()).max(3) }).parse(await aiResponse.json());
        const allowed = new Set(menuItems.filter((item) => !input.cartItemIds.includes(item.id)).map((item) => item.id));
        const suggestions = [...new Set(generated.suggested_ids)].filter((id) => allowed.has(id)).map((id) => {
          const item = menuItems.find((candidate) => candidate.id === id)!;
          return { id: item.id, name: item.name, price: Number(item.price), description: item.description?.trim() || item.category, reason: "Gợi ý theo yêu cầu của bạn" };
        });
        res.json({ reply: generated.reply, suggestions, provider: "gemini" });
      } catch {
        res.json({ ...fallback(), provider: "rule-based" });
      }
    } catch (error) {
      next(error);
    }
  });
  return router;
}
