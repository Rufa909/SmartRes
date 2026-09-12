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

