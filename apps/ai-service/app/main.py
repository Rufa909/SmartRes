from fastapi import FastAPI

from app.schemas import ParseOrderRequest, ParseOrderResponse, UpsellRequest, UpsellResponse
from app.services.chatbot import parse_order_message
from app.services.upsell import suggest_upsell

app = FastAPI(title="SmartRes AI Service", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "smartres-ai-service"}


@app.post("/chatbot/parse-order", response_model=ParseOrderResponse)
def parse_order(request: ParseOrderRequest) -> ParseOrderResponse:
    items, confidence = parse_order_message(request.message)
    reply = "Da nhan dien mon trong yeu cau." if items else "Toi chua nhan dien duoc mon, ban co the noi ro hon khong?"

    return ParseOrderResponse(
        intent="create_order" if items else "clarify",
        items=items,
        confidence=confidence,
        reply=reply,
    )


@app.post("/upsell/suggest", response_model=UpsellResponse)
def upsell(request: UpsellRequest) -> UpsellResponse:
    suggestions, reason = suggest_upsell(request.cart_items)
    return UpsellResponse(suggestions=suggestions, reason=reason)

