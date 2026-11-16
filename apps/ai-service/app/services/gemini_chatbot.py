import json
import os
from typing import Any

from google import genai
from google.genai import types
from pydantic import BaseModel, Field

from app.schemas import ChatbotRecommendRequest, ChatbotRecommendResponse


class GeminiChatResponse(BaseModel):
    reply: str = Field(description="Câu trả lời ngắn, thân thiện bằng tiếng Việt")
    suggested_ids: list[int] = Field(description="ID món có trong thực đơn được cung cấp, tối đa 3 món")


def recommend_with_gemini(request: ChatbotRecommendRequest) -> ChatbotRecommendResponse:
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY is not configured")

    menu = [item.model_dump() for item in request.menu]
    prompt = f"""Bạn là trợ lý chọn món cho nhà hàng SmartRes. Hãy trả lời ngắn gọn bằng tiếng Việt, xưng mình/bạn.

Chỉ sử dụng dữ liệu trong thực đơn JSON bên dưới. Không tự nghĩ thêm món, giá, thành phần, độ cay, chất gây dị ứng, tình trạng còn hàng hoặc thông tin nhà hàng. Nếu dữ liệu không đủ để xác nhận một yêu cầu (ví dụ món chay hoặc dị ứng), hãy nói rõ chưa thể xác nhận và khuyên hỏi nhân viên. Không nhận đặt món, không nói rằng đã thêm món vào giỏ hoặc đã gửi đơn. Chỉ tư vấn và đề xuất tối đa 3 ID món đang có; không đề xuất ID trong giỏ. Nếu không có món phù hợp, trả suggested_ids là mảng rỗng và hỏi khách muốn loại món nào.

Câu hỏi khách: {request.message}
Số người (nếu có): {request.party_size or 'chưa cung cấp'}
ID món đã có trong giỏ: {request.cart_item_ids}
Thực đơn hiện đang bán (JSON): {json.dumps(menu, ensure_ascii=False)}"""

    client = genai.Client(api_key=api_key, http_options=types.HttpOptions(timeout=10_000))
    result = client.models.generate_content(
        model=os.getenv("GEMINI_MODEL", "gemini-3.8-flash"),
        contents=prompt,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=GeminiChatResponse,
            max_output_tokens=350,
        ),
    )
    if not result.text:
        raise RuntimeError("Gemini returned an empty response")

    parsed = GeminiChatResponse.model_validate_json(result.text)
    menu_ids = {item.id for item in request.menu}
    cart_ids = set(request.cart_item_ids)
    valid_ids = list(dict.fromkeys(item_id for item_id in parsed.suggested_ids if item_id in menu_ids and item_id not in cart_ids))[:3]
    return ChatbotRecommendResponse(reply=parsed.reply.strip()[:600], suggested_ids=valid_ids)
