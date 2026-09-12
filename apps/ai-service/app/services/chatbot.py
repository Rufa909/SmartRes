from app.schemas import ParsedOrderItem


KNOWN_ITEMS = [
    "com ga",
    "mi y",
    "tra dao",
    "combo",
    "ca phe",
]


def parse_order_message(message: str) -> tuple[list[ParsedOrderItem], float]:
    normalized = message.lower()
    items: list[ParsedOrderItem] = []

    for item_name in KNOWN_ITEMS:
        if item_name in normalized:
            quantity = 2 if "hai" in normalized or "2" in normalized else 1
            note = "it cay" if "it cay" in normalized else None
            items.append(ParsedOrderItem(name=item_name, quantity=quantity, note=note))

    confidence = 0.82 if items else 0.35
    return items, confidence

