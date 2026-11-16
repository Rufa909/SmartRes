from pydantic import BaseModel, Field


class ParsedOrderItem(BaseModel):
    name: str
    quantity: int = Field(default=1, ge=1)
    note: str | None = None


class ParseOrderRequest(BaseModel):
    message: str
    table_id: str | None = None


class ParseOrderResponse(BaseModel):
    intent: str
    items: list[ParsedOrderItem]
    confidence: float
    reply: str


class UpsellRequest(BaseModel):
    cart_items: list[str]


class UpsellResponse(BaseModel):
    suggestions: list[str]
    reason: str


class ChatbotMenuItem(BaseModel):
    id: int
    name: str
    description: str | None = None
    category: str


class ChatbotRecommendRequest(BaseModel):
    message: str = Field(min_length=1, max_length=400)
    menu: list[ChatbotMenuItem] = Field(max_length=100)
    cart_item_ids: list[int] = Field(default_factory=list, max_length=50)
    party_size: int | None = Field(default=None, ge=1, le=99)


class ChatbotRecommendResponse(BaseModel):
    reply: str
    suggested_ids: list[int] = Field(max_length=3)

