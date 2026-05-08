from datetime import date, datetime
from typing import Literal

from pydantic import AnyUrl, BaseModel, ConfigDict, Field, field_serializer, field_validator

from app.models.record import AttachmentType
from app.services.storage import storage_service


class IngredientCreate(BaseModel):
    name: str = Field(default="", max_length=80)
    quantity: str | None = Field(default=None, max_length=80)


class IngredientRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    quantity: str | None = None
    sort_order: int


class AttachmentLinkCreate(BaseModel):
    url: AnyUrl
    title: str | None = Field(default=None, max_length=200)
    description: str | None = None

    @field_validator("url")
    @classmethod
    def require_http_url(cls, value: AnyUrl) -> AnyUrl:
        if value.scheme not in {"http", "https"}:
            raise ValueError("http 또는 https URL만 사용할 수 있습니다.")
        return value


class AttachmentCreate(BaseModel):
    type: AttachmentType
    title: str | None = Field(default=None, max_length=200)
    url: AnyUrl | None = None
    description: str | None = None
    thumbnail_url: str | None = None
    object_key: str | None = None

    @field_validator("url")
    @classmethod
    def require_http_url(cls, value: AnyUrl | None) -> AnyUrl | None:
        if value is not None and value.scheme not in {"http", "https"}:
            raise ValueError("http 또는 https URL만 사용할 수 있습니다.")
        return value


class AttachmentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    type: AttachmentType
    title: str | None = None
    url: str | None = None
    description: str | None = None
    thumbnail_url: str | None = None
    object_key: str | None = None
    sort_order: int
    created_at: datetime

    @field_serializer("thumbnail_url")
    def serialize_thumbnail_url(self, value: str | None) -> str | None:
        if self.type == AttachmentType.IMAGE and self.object_key:
            return storage_service.file_url(self.object_key)
        return value


class AttachmentPreviewRead(BaseModel):
    type: AttachmentType
    url: str
    title: str | None = None
    thumbnail_url: str | None = None


class CookingRecordBase(BaseModel):
    dish_name: str = Field(..., min_length=1, max_length=80)
    cooked_date: date
    recipe: str | None = Field(default=None, max_length=5000)
    memo: str | None = Field(default=None, max_length=1000)
    rating: int | None = Field(default=None, ge=1, le=5)

    @field_validator("dish_name")
    @classmethod
    def strip_dish_name(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("요리명을 입력해주세요.")
        return stripped


class CookingRecordCreate(CookingRecordBase):
    ingredients: list[IngredientCreate] = Field(default_factory=list, max_length=50)
    attachments: list[AttachmentCreate] = Field(default_factory=list, max_length=15)


class CookingRecordUpdate(BaseModel):
    dish_name: str | None = Field(default=None, min_length=1, max_length=80)
    cooked_date: date | None = None
    recipe: str | None = Field(default=None, max_length=5000)
    memo: str | None = Field(default=None, max_length=1000)
    rating: int | None = Field(default=None, ge=1, le=5)
    ingredients: list[IngredientCreate] | None = Field(default=None, max_length=50)
    attachments: list[AttachmentCreate] | None = Field(default=None, max_length=15)

    @field_validator("dish_name")
    @classmethod
    def strip_dish_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        if not stripped:
            raise ValueError("요리명을 입력해주세요.")
        return stripped


class CookingRecordSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    dish_name: str
    cooked_date: date
    memo: str | None = None
    rating: int | None = None
    created_at: datetime
    updated_at: datetime
    ingredients: list[IngredientRead] = Field(default_factory=list)
    attachments: list[AttachmentRead] = Field(default_factory=list)


class CookingRecordRead(CookingRecordSummary):
    recipe: str | None = None


class CloneRequest(BaseModel):
    cooked_date: date


class CalendarDay(BaseModel):
    date: date
    count: int


SearchFilter = Literal["all", "dish", "ingredient", "memo", "link"]
