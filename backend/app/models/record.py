from datetime import date, datetime
from enum import Enum as PyEnum

from sqlalchemy import Date, DateTime, Enum as SqlEnum, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class AttachmentType(str, PyEnum):
    IMAGE = "image"
    URL = "url"
    YOUTUBE = "youtube"


class CookingRecord(Base):
    __tablename__ = "cooking_records"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    dish_name: Mapped[str] = mapped_column(String(80), index=True)
    cooked_date: Mapped[date] = mapped_column(Date, index=True)
    recipe: Mapped[str | None] = mapped_column(Text)
    memo: Mapped[str | None] = mapped_column(Text)
    rating: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    ingredients: Mapped[list["RecordIngredient"]] = relationship(
        back_populates="record",
        cascade="all, delete-orphan",
        order_by="RecordIngredient.sort_order",
    )
    attachments: Mapped[list["RecordAttachment"]] = relationship(
        back_populates="record",
        cascade="all, delete-orphan",
        order_by="RecordAttachment.sort_order",
    )


class RecordIngredient(Base):
    __tablename__ = "record_ingredients"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    record_id: Mapped[int] = mapped_column(ForeignKey("cooking_records.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(80))
    quantity: Mapped[str | None] = mapped_column(String(80))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    record: Mapped[CookingRecord] = relationship(back_populates="ingredients")


class RecordAttachment(Base):
    __tablename__ = "record_attachments"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    record_id: Mapped[int] = mapped_column(ForeignKey("cooking_records.id", ondelete="CASCADE"))
    type: Mapped[AttachmentType] = mapped_column(
        SqlEnum(
            AttachmentType,
            values_callable=lambda enum: [item.value for item in enum],
            name="attachment_type",
        )
    )
    title: Mapped[str | None] = mapped_column(String(200))
    url: Mapped[str | None] = mapped_column(String(1000))
    description: Mapped[str | None] = mapped_column(Text)
    thumbnail_url: Mapped[str | None] = mapped_column(String(1000))
    object_key: Mapped[str | None] = mapped_column(String(1000))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    record: Mapped[CookingRecord] = relationship(back_populates="attachments")
