from datetime import date

from fastapi import APIRouter, Depends, File, Query, Response, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import db_session
from app.models.record import CookingRecord
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
) -> list[CookingRecord]:
    stmt = record_select().order_by(CookingRecord.cooked_date.desc(), CookingRecord.updated_at.desc())
    return list(db.scalars(stmt.limit(limit)).unique())


@router.get("/today", response_model=list[CookingRecordSummary])
def list_today_records(db: Session = Depends(db_session)) -> list[CookingRecord]:
    today = date.today()
    stmt = (
        record_select()
        .where(CookingRecord.cooked_date == today)
        .order_by(CookingRecord.updated_at.desc())
    )
    return list(db.scalars(stmt).unique())


@router.get("/by-date", response_model=list[CookingRecordSummary])
def list_records_by_date(
    record_date: date = Query(alias="date"),
    db: Session = Depends(db_session),
) -> list[CookingRecord]:
    stmt = (
        record_select()
        .where(CookingRecord.cooked_date == record_date)
        .order_by(CookingRecord.updated_at.desc())
    )
    return list(db.scalars(stmt).unique())


@router.get("/calendar", response_model=list[CalendarDay])
def list_calendar_days(
    month: str = Query(pattern=r"^\d{4}-\d{2}$"),
    db: Session = Depends(db_session),
) -> list[CalendarDay]:
    year, month_number = (int(part) for part in month.split("-"))
    return [CalendarDay(date=item_date, count=count) for item_date, count in calendar_days(db, year=year, month=month_number)]


@router.get("/search", response_model=list[CookingRecordSummary])
def search(
    q: str = Query(min_length=1),
    search_filter: SearchFilter = Query(default="all", alias="filter"),
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(db_session),
) -> list[CookingRecord]:
    return search_records(db, query=q, search_filter=search_filter, limit=limit)


@router.get("/attachments/preview", response_model=AttachmentPreviewRead)
def preview_attachment_link(url: str = Query(min_length=1)) -> AttachmentPreviewRead:
    return preview_link(url)


@router.post("", response_model=CookingRecordRead, status_code=status.HTTP_201_CREATED)
def create(payload: CookingRecordCreate, db: Session = Depends(db_session)) -> CookingRecord:
    return create_record(db, payload)


@router.get("/{record_id}", response_model=CookingRecordRead)
def read(record_id: int, db: Session = Depends(db_session)) -> CookingRecord:
    return get_record(db, record_id)


@router.patch("/{record_id}", response_model=CookingRecordRead)
def update(
    record_id: int,
    payload: CookingRecordUpdate,
    db: Session = Depends(db_session),
) -> CookingRecord:
    return update_record(db, record_id, payload)


@router.delete("/{record_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete(record_id: int, db: Session = Depends(db_session)) -> Response:
    delete_record(db, record_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{record_id}/clone", response_model=CookingRecordRead, status_code=status.HTTP_201_CREATED)
def clone(
    record_id: int,
    payload: CloneRequest,
    db: Session = Depends(db_session),
) -> CookingRecord:
    return clone_record(db, record_id, payload.cooked_date)


@router.post("/{record_id}/attachments/links", response_model=AttachmentRead, status_code=status.HTTP_201_CREATED)
def attach_link(
    record_id: int,
    payload: AttachmentLinkCreate,
    db: Session = Depends(db_session),
) -> AttachmentRead:
    return add_link_attachment(db, record_id, payload)


@router.post("/{record_id}/attachments/images", response_model=AttachmentRead, status_code=status.HTTP_201_CREATED)
def attach_image(
    record_id: int,
    image: UploadFile = File(...),
    db: Session = Depends(db_session),
) -> AttachmentRead:
    object_key, thumbnail_url = storage_service.save_upload(image)
    return add_image_attachment(
        db,
        record_id,
        title=image.filename,
        object_key=object_key,
        thumbnail_url=thumbnail_url,
    )


@router.delete("/{record_id}/attachments/{attachment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_record_attachment(
    record_id: int,
    attachment_id: int,
    db: Session = Depends(db_session),
) -> Response:
    delete_attachment(db, record_id, attachment_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
