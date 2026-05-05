from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import db_session
from app.models.record import AttachmentType, RecordAttachment
from app.services.storage import storage_service

router = APIRouter(prefix="/files", tags=["files"])


@router.get("/{object_key:path}")
def read_file(
    object_key: str,
    token: str | None = Query(default=None),
    db: Session = Depends(db_session),
) -> StreamingResponse:
    storage_service.ensure_file_access_token(object_key, token)
    attachment_exists = db.scalar(
        select(RecordAttachment.id).where(
            RecordAttachment.type == AttachmentType.IMAGE,
            RecordAttachment.object_key == object_key,
        )
    )
    if attachment_exists is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="파일을 찾을 수 없어요.")

    try:
        result = storage_service.get_object(object_key)
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="파일을 찾을 수 없어요.") from exc

    content_type = result.get("ContentType") or "application/octet-stream"
    return StreamingResponse(result["Body"], media_type=content_type)
