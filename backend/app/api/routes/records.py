from contextlib import suppress
from datetime import date

from fastapi import APIRouter, Depends, File, Query, Response, UploadFile, status
from sqlalchemy.orm import Session

from app.api.deps import current_user, db_session
from app.models.record import CookingRecord
from app.models.user import User
from app.schemas.record import (
    AttachmentLinkCreate,
    AttachmentPreviewRead,
    AttachmentRead,
    CalendarDay,
    CloneRequest,
    CookingRecordCreate,
    CookingRecordRead,
    CookingRecordSummary,
    CookingRecordUpdate,
    SearchFilter,
)
from app.services.records import (
    add_image_attachment,
    add_link_attachment,
    calendar_days,
    clone_record,
    create_record,
    delete_record,
    delete_attachment,
    ensure_image_attachment_allowed,
    get_record,
    preview_link,
    record_select,
    search_records,
    update_record,
)
from app.services.storage import storage_service

router = APIRouter(prefix="/records", tags=["records"])


@router.get("/recent", response_model=list[CookingRecordSummary])
def list_recent_records(
    limit: int = Query(default=10, ge=1, le=50),
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> list[CookingRecord]:
    stmt = record_select(user.id).order_by(
        CookingRecord.cooked_date.desc(),
        CookingRecord.updated_at.desc(),
    )
    return list(db.scalars(stmt.limit(limit)).unique())


@router.get("/today", response_model=list[CookingRecordSummary])
def list_today_records(
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> list[CookingRecord]:
    today = date.today()
    stmt = (
        record_select(user.id)
        .where(CookingRecord.cooked_date == today)
        .order_by(CookingRecord.updated_at.desc())
    )
    return list(db.scalars(stmt).unique())


@router.get("/by-date", response_model=list[CookingRecordSummary])
def list_records_by_date(
    record_date: date = Query(alias="date"),
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> list[CookingRecord]:
    stmt = (
        record_select(user.id)
        .where(CookingRecord.cooked_date == record_date)
        .order_by(CookingRecord.updated_at.desc())
    )
    return list(db.scalars(stmt).unique())


@router.get("/calendar", response_model=list[CalendarDay])
def list_calendar_days(
    month: str = Query(pattern=r"^\d{4}-\d{2}$"),
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> list[CalendarDay]:
    year, month_number = (int(part) for part in month.split("-"))
    return [
        CalendarDay(date=item_date, count=count)
        for item_date, count in calendar_days(db, user_id=user.id, year=year, month=month_number)
    ]


@router.get("/search", response_model=list[CookingRecordSummary])
def search(
    q: str = Query(min_length=1),
    search_filter: SearchFilter = Query(default="all", alias="filter"),
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> list[CookingRecord]:
    return search_records(db, user_id=user.id, query=q, search_filter=search_filter, limit=limit)


@router.get("/attachments/preview", response_model=AttachmentPreviewRead)
def preview_attachment_link(
    url: str = Query(min_length=1),
    _user: User = Depends(current_user),
) -> AttachmentPreviewRead:
    return preview_link(url)


@router.post("", response_model=CookingRecordRead, status_code=status.HTTP_201_CREATED)
def create(
    payload: CookingRecordCreate,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> CookingRecord:
    return create_record(db, payload, user.id)


@router.get("/{record_id}", response_model=CookingRecordRead)
def read(
    record_id: int,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> CookingRecord:
    return get_record(db, record_id, user.id)


@router.patch("/{record_id}", response_model=CookingRecordRead)
def update(
    record_id: int,
    payload: CookingRecordUpdate,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> CookingRecord:
    return update_record(db, record_id, user.id, payload)


@router.delete("/{record_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete(
    record_id: int,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> Response:
    delete_record(db, record_id, user.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{record_id}/clone",
    response_model=CookingRecordRead,
    status_code=status.HTTP_201_CREATED,
)
def clone(
    record_id: int,
    payload: CloneRequest,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> CookingRecord:
    return clone_record(db, record_id, user.id, payload.cooked_date)


@router.post(
    "/{record_id}/attachments/links",
    response_model=AttachmentRead,
    status_code=status.HTTP_201_CREATED,
)
def attach_link(
    record_id: int,
    payload: AttachmentLinkCreate,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> AttachmentRead:
    return add_link_attachment(db, record_id, user.id, payload)


@router.post(
    "/{record_id}/attachments/images",
    response_model=AttachmentRead,
    status_code=status.HTTP_201_CREATED,
)
def attach_image(
    record_id: int,
    image: UploadFile = File(...),
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> AttachmentRead:
    ensure_image_attachment_allowed(db, record_id, user.id)
    object_key, thumbnail_url = storage_service.save_upload(image)
    try:
        return add_image_attachment(
            db,
            record_id,
            user.id,
            title=image.filename,
            object_key=object_key,
            thumbnail_url=thumbnail_url,
        )
    except Exception:
        with suppress(Exception):
            storage_service.delete_object(object_key)
        raise


@router.delete("/{record_id}/attachments/{attachment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_record_attachment(
    record_id: int,
    attachment_id: int,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
) -> Response:
    delete_attachment(db, record_id, user.id, attachment_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
