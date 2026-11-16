import asyncio
import os
from pathlib import Path

from fastapi import FastAPI, HTTPException
from dotenv import dotenv_values

from app.schemas import ChatbotRecommendRequest, ChatbotRecommendResponse, ParseOrderRequest, ParseOrderResponse, UpsellRequest, UpsellResponse
from app.services.chatbot import parse_order_message
from app.services.gemini_chatbot import recommend_with_gemini

PROJECT_ROOT = Path(__file__).resolve().parents[3]
for env_file in (PROJECT_ROOT / ".env.mysql.local", PROJECT_ROOT / ".env"):
    for key in ("GEMINI_API_KEY", "GEMINI_MODEL"):
        value = dotenv_values(env_file).get(key)
        if value:
            os.environ.setdefault(key, value)
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


@app.post("/chatbot/recommend", response_model=ChatbotRecommendResponse)
async def chatbot_recommend(request: ChatbotRecommendRequest) -> ChatbotRecommendResponse:
    try:
        return await asyncio.to_thread(recommend_with_gemini, request)
    except Exception as error:
        raise HTTPException(status_code=503, detail="Gemini chatbot is unavailable") from error


@app.post("/upsell/suggest", response_model=UpsellResponse)
def upsell(request: UpsellRequest) -> UpsellResponse:
    suggestions, reason = suggest_upsell(request.cart_items)
    return UpsellResponse(suggestions=suggestions, reason=reason)

