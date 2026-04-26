from fastapi import APIRouter, HTTPException, status
from fastapi.responses import StreamingResponse

from app.services.storage import storage_service

router = APIRouter(prefix="/files", tags=["files"])


@router.get("/{object_key:path}")
def read_file(object_key: str) -> StreamingResponse:
    try:
        result = storage_service.get_object(object_key)
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="파일을 찾을 수 없어요.") from exc

    content_type = result.get("ContentType") or "application/octet-stream"
    return StreamingResponse(result["Body"], media_type=content_type)
