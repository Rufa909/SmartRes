def suggest_upsell(cart_items: list[str]) -> tuple[list[str], str]:
    normalized = " ".join(cart_items).lower()

    if "com" in normalized or "mi" in normalized:
        return ["Tra dao cam sa", "Soup trong ngay"], "Goi y do uong va mon phu hop voi mon chinh."

    if "tra" in normalized or "ca phe" in normalized:
        return ["Banh flan", "Combo an nhe"], "Goi y mon trang mieng de tang gia tri don hang."

    return ["Combo trua nhanh", "Tra dao cam sa"], "Goi y mac dinh cho khach moi bat dau chon mon."

