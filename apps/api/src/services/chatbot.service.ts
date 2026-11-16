export type ChatMenuItem = {
  id: number;
  name: string;
  description: string | null;
  price: number | string;
  category: string;
};

export type ChatSuggestion = {
  id: number;
  name: string;
  price: number;
  description: string;
  reason: string;
};

export type ChatReply = { reply: string; suggestions: ChatSuggestion[] };

function normalize(value: string) {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase("vi");
}

export function replyToMenuQuestion(
  message: string,
  menu: ChatMenuItem[],
  cartItemIds: number[] = [],
  partySize?: number,
): ChatReply {
  const text = normalize(message.trim());
  const available = menu.filter((item) => !cartItemIds.includes(item.id));
  const mentioned = available.find((item) => {
    const name = normalize(item.name);
    return name.length >= 3 && (text.includes(name) || name.split(/\s+/).filter((word) => word.length > 2).every((word) => text.includes(word)));
  });

  if (!menu.length) return { reply: "Hiện thực đơn chưa có món đang bán. Bạn thử hỏi nhân viên giúp nhé.", suggestions: [] };

  if (mentioned) {
    const price = Number(mentioned.price);
    const description = mentioned.description?.trim();
    return {
      reply: `${mentioned.name} hiện có giá ${new Intl.NumberFormat("vi-VN").format(price)}đ.${description ? ` ${description}` : " Đây là món đang có trong thực đơn."}`,
      suggestions: [{ id: mentioned.id, name: mentioned.name, price, description: description || mentioned.category, reason: "Món bạn vừa hỏi" }],
    };
  }

  const wantsDrink = /nuoc|uong|tra|cafe|ca phe|giai khat/.test(text);
  const wantsVegetarian = /chay|rau|khong thit/.test(text);
  const wantsLight = /nhe|an vat|trang mieng|dessert|ngot/.test(text);
  const wantsSpicy = /cay|sa te/.test(text);
  const candidates = available.map((item) => {
    const haystack = normalize(`${item.name} ${item.description || ""} ${item.category}`);
    let score = 0;
    if (wantsDrink && /nuoc|uong|tra|cafe|ca phe|drink/.test(normalize(item.category + " " + item.name))) score += 5;
    if (wantsVegetarian && /rau|chay|nam|cu|dau/.test(haystack)) score += 4;
    if (wantsLight && /banh|kem|che|goi|salad|trang mieng|an vat/.test(haystack)) score += 4;
    if (wantsSpicy && /cay|sa te|ot/.test(haystack)) score += 3;
    if (/goi y|tu van|mon nao|an gi|phu hop|de xuat|recommend/.test(text)) score += 1;
    return { item, score };
  }).sort((a, b) => b.score - a.score || a.item.name.localeCompare(b.item.name, "vi"));

  const picks = candidates.slice(0, Math.min(3, candidates.length));
  const groupText = partySize ? `cho nhóm ${partySize} người` : "";
  const lead = wantsDrink ? "Nếu bạn muốn đồ uống" : wantsVegetarian ? "Nếu bạn đang tìm món chay hoặc nhiều rau" : wantsLight ? "Nếu muốn ăn nhẹ hoặc tráng miệng" : wantsSpicy ? "Nếu bạn thích vị cay" : "Mình gợi ý vài món đang bán";
  return {
    reply: `${lead} ${groupText}, bạn có thể tham khảo các món dưới đây. Mình chỉ gợi ý món đang có trong thực đơn; bạn chọn món để thêm vào giỏ nhé.`,
    suggestions: picks.map(({ item }) => ({
      id: item.id,
      name: item.name,
      price: Number(item.price),
      description: item.description?.trim() || item.category,
      reason: wantsDrink ? "Gợi ý đồ uống" : wantsVegetarian ? "Gợi ý món nhiều rau" : wantsLight ? "Gợi ý ăn nhẹ" : wantsSpicy ? "Dành cho khẩu vị cay" : "Đang có trong thực đơn",
    })),
  };
}
