from collections.abc import Iterable
from datetime import date
import logging
from urllib.parse import urlparse

from fastapi import HTTPException, status
from sqlalchemy import Select, and_, func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.models.record import AttachmentType, CookingRecord, RecordAttachment, RecordIngredient
from app.schemas.record import (
    AttachmentCreate,
    AttachmentLinkCreate,
    AttachmentPreviewRead,
    CookingRecordCreate,
    CookingRecordUpdate,
    IngredientCreate,
    SearchFilter,
)
from app.services.storage import storage_service
from app.services.youtube import (
    extract_youtube_video_id,
    fetch_youtube_oembed_title,
    youtube_thumbnail_url,
)


logger = logging.getLogger(__name__)


def record_select() -> Select[tuple[CookingRecord]]:
    return select(CookingRecord).options(
        selectinload(CookingRecord.ingredients),
        selectinload(CookingRecord.attachments),
    )


def image_object_keys(attachments: Iterable[RecordAttachment]) -> set[str]:
    return {
        item.object_key
        for item in attachments
        if item.type == AttachmentType.IMAGE and item.object_key
    }


def delete_unreferenced_storage_objects(db: Session, object_keys: Iterable[str]) -> None:
    keys = {key for key in object_keys if key}
    if not keys:
        return

    remaining_keys = set(
        db.scalars(
            select(RecordAttachment.object_key).where(RecordAttachment.object_key.in_(keys))
        )
    )
    for object_key in keys - remaining_keys:
        try:
            storage_service.delete_object(object_key)
        except Exception:
            logger.warning("Failed to delete storage object: %s", object_key, exc_info=True)


def get_record(db: Session, record_id: int) -> CookingRecord:
    record = db.scalar(record_select().where(CookingRecord.id == record_id))
    if record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="기록을 찾을 수 없어요.")
    return record


def ensure_not_future(cooked_date: date) -> None:
    if cooked_date > date.today():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="미래 날짜에는 기록을 저장할 수 없어요.",
        )


def build_ingredients(items: list[IngredientCreate]) -> list[RecordIngredient]:
    ingredients: list[RecordIngredient] = []
    for index, item in enumerate(items):
        name = item.name.strip()
        quantity = item.quantity.strip() if item.quantity else None
        if not name and quantity:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="재료명 없이 수량만 입력할 수 없어요.",
            )
        if not name:
            continue
        ingredients.append(RecordIngredient(name=name, quantity=quantity, sort_order=index))
    return ingredients


def infer_link_attachment(payload: AttachmentLinkCreate, sort_order: int = 0) -> RecordAttachment:
    raw_url = str(payload.url)
    video_id = extract_youtube_video_id(raw_url)
    attachment_type = AttachmentType.YOUTUBE if video_id else AttachmentType.URL
    thumbnail_url = youtube_thumbnail_url(video_id) if video_id else None
    return RecordAttachment(
        type=attachment_type,
        title=payload.title,
        url=raw_url,
        description=payload.description,
        thumbnail_url=thumbnail_url,
        sort_order=sort_order,
    )


def preview_link(raw_url: str) -> AttachmentPreviewRead:
    parsed = urlparse(raw_url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="올바른 URL을 입력해주세요.",
        )

    video_id = extract_youtube_video_id(raw_url)
    if video_id is None:
        return AttachmentPreviewRead(type=AttachmentType.URL, url=raw_url)

    return AttachmentPreviewRead(
        type=AttachmentType.YOUTUBE,
        url=raw_url,
        title=fetch_youtube_oembed_title(raw_url) or "YouTube 영상",
        thumbnail_url=youtube_thumbnail_url(video_id),
    )


def build_attachments(items: list[AttachmentCreate]) -> list[RecordAttachment]:
    attachments: list[RecordAttachment] = []
    seen_urls: set[str] = set()
    for index, item in enumerate(items):
        raw_url = str(item.url) if item.url else None
        if raw_url and raw_url in seen_urls:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="이미 추가된 링크입니다.",
            )
        if raw_url:
            seen_urls.add(raw_url)

        attachment_type = item.type
        thumbnail_url = item.thumbnail_url
        if raw_url:
            video_id = extract_youtube_video_id(raw_url)
            if video_id:
                attachment_type = AttachmentType.YOUTUBE
                thumbnail_url = youtube_thumbnail_url(video_id)

        attachments.append(
            RecordAttachment(
                type=attachment_type,
                title=item.title,
                url=raw_url,
                description=item.description,
                thumbnail_url=thumbnail_url,
                object_key=item.object_key,
                sort_order=index,
            )
        )
    return attachments


def create_record(db: Session, payload: CookingRecordCreate) -> CookingRecord:
    ensure_not_future(payload.cooked_date)
    record = CookingRecord(
        dish_name=payload.dish_name,
        cooked_date=payload.cooked_date,
        recipe=payload.recipe,
        memo=payload.memo,
        rating=payload.rating,
        ingredients=build_ingredients(payload.ingredients),
        attachments=build_attachments(payload.attachments),
    )
    db.add(record)
    db.commit()
    return get_record(db, record.id)


def update_record(db: Session, record_id: int, payload: CookingRecordUpdate) -> CookingRecord:
    record = get_record(db, record_id)
    data = payload.model_dump(exclude_unset=True)
    deleted_object_keys: set[str] = set()

    if "cooked_date" in data and data["cooked_date"] is not None:
        ensure_not_future(data["cooked_date"])

    for field in ("dish_name", "cooked_date", "recipe", "memo", "rating"):
        if field in data:
            setattr(record, field, data[field])

    if payload.ingredients is not None:
        record.ingredients = build_ingredients(payload.ingredients)

    if payload.attachments is not None:
        previous_object_keys = image_object_keys(record.attachments)
        next_attachments = build_attachments(payload.attachments)
        next_object_keys = image_object_keys(next_attachments)
        deleted_object_keys = previous_object_keys - next_object_keys
        record.attachments = next_attachments

    db.add(record)
    db.commit()
    delete_unreferenced_storage_objects(db, deleted_object_keys)
    return get_record(db, record.id)


def clone_record(db: Session, record_id: int, cooked_date: date) -> CookingRecord:
    ensure_not_future(cooked_date)
    source = get_record(db, record_id)
    cloned = CookingRecord(
        dish_name=source.dish_name,
        cooked_date=cooked_date,
        recipe=source.recipe,
        memo=source.memo,
        rating=source.rating,
        ingredients=[
            RecordIngredient(name=item.name, quantity=item.quantity, sort_order=item.sort_order)
            for item in source.ingredients
        ],
        attachments=[
            RecordAttachment(
                type=item.type,
                title=item.title,
                url=item.url,
                description=item.description,
                thumbnail_url=item.thumbnail_url,
                object_key=item.object_key,
                sort_order=item.sort_order,
            )
            for item in source.attachments
        ],
    )
    db.add(cloned)
    db.commit()
    return get_record(db, cloned.id)


def delete_record(db: Session, record_id: int) -> None:
    record = get_record(db, record_id)
    deleted_object_keys = image_object_keys(record.attachments)
    db.delete(record)
    db.commit()
    delete_unreferenced_storage_objects(db, deleted_object_keys)


def add_link_attachment(
    db: Session,
    record_id: int,
    payload: AttachmentLinkCreate,
) -> RecordAttachment:
    record = get_record(db, record_id)
    raw_url = str(payload.url)
    if any(item.url == raw_url for item in record.attachments):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="이미 추가된 링크입니다.",
        )
    attachment = infer_link_attachment(payload, sort_order=len(record.attachments))
    record.attachments.append(attachment)
    db.add(record)
    db.commit()
    db.refresh(attachment)
    return attachment


def ensure_image_attachment_allowed(db: Session, record_id: int) -> None:
    record = get_record(db, record_id)
    current_images = [item for item in record.attachments if item.type == AttachmentType.IMAGE]
    if len(current_images) >= 5:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="사진은 최대 5장까지 첨부할 수 있어요.",
        )


def add_image_attachment(
    db: Session,
    record_id: int,
    *,
    title: str | None,
    object_key: str,
    thumbnail_url: str | None,
) -> RecordAttachment:
    record = get_record(db, record_id)
    ensure_image_attachment_allowed(db, record_id)
    attachment = RecordAttachment(
        type=AttachmentType.IMAGE,
        title=title,
        object_key=object_key,
        thumbnail_url=thumbnail_url,
        sort_order=len(record.attachments),
    )
    record.attachments.append(attachment)
    db.add(record)
    db.commit()
    db.refresh(attachment)
    return attachment


def delete_attachment(db: Session, record_id: int, attachment_id: int) -> None:
    record = get_record(db, record_id)
    attachment = next((item for item in record.attachments if item.id == attachment_id), None)
    if attachment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="첨부 자료를 찾을 수 없어요.",
        )
    deleted_object_keys = image_object_keys([attachment])
    db.delete(attachment)
    db.commit()
    delete_unreferenced_storage_objects(db, deleted_object_keys)


def search_records(
    db: Session,
    *,
    query: str,
    search_filter: SearchFilter = "all",
    limit: int = 30,
) -> list[CookingRecord]:
    trimmed = query.strip()
    if not trimmed:
        return []

    pattern = f"%{trimmed}%"
    conditions = []
    if search_filter in {"all", "dish"}:
        conditions.append(CookingRecord.dish_name.ilike(pattern))
    if search_filter in {"all", "memo"}:
        conditions.extend([CookingRecord.memo.ilike(pattern), CookingRecord.recipe.ilike(pattern)])
    if search_filter in {"all", "ingredient"}:
        conditions.append(RecordIngredient.name.ilike(pattern))
    if search_filter in {"all", "link"}:
        conditions.extend(
            [
                RecordAttachment.title.ilike(pattern),
                RecordAttachment.description.ilike(pattern),
                RecordAttachment.url.ilike(pattern),
            ]
        )

    stmt = (
        record_select()
        .outerjoin(RecordIngredient)
        .outerjoin(RecordAttachment)
        .where(or_(*conditions))
        .order_by(CookingRecord.cooked_date.desc(), CookingRecord.updated_at.desc())
        .limit(limit)
    )
    return list(db.scalars(stmt).unique())


def calendar_days(db: Session, *, year: int, month: int) -> list[tuple[date, int]]:
    start = date(year, month, 1)
    end = date(year + 1, 1, 1) if month == 12 else date(year, month + 1, 1)
    rows = db.execute(
        select(CookingRecord.cooked_date, func.count(CookingRecord.id))
        .where(and_(CookingRecord.cooked_date >= start, CookingRecord.cooked_date < end))
        .group_by(CookingRecord.cooked_date)
        .order_by(CookingRecord.cooked_date.asc())
    )
    return [(row[0], row[1]) for row in rows]
