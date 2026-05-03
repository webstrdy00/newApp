from io import BytesIO

import pytest
from fastapi import HTTPException

from app.core.config import settings
from app.services.storage import StorageService


class DummyUpload:
    def __init__(self, *, content_type: str, body: bytes) -> None:
        self.content_type = content_type
        self.file = BytesIO(body)


def test_validate_image_upload_accepts_allowed_type() -> None:
    upload = DummyUpload(content_type="image/png", body=b"image-bytes")

    StorageService().validate_image_upload(upload)  # type: ignore[arg-type]


def test_validate_image_upload_rejects_disallowed_type() -> None:
    upload = DummyUpload(content_type="text/plain", body=b"not-image")

    with pytest.raises(HTTPException) as exc_info:
        StorageService().validate_image_upload(upload)  # type: ignore[arg-type]

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail == "지원하지 않는 이미지 형식입니다."


def test_validate_image_upload_rejects_large_file(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "image_upload_max_bytes", 3)
    upload = DummyUpload(content_type="image/jpeg", body=b"1234")

    with pytest.raises(HTTPException) as exc_info:
        StorageService().validate_image_upload(upload)  # type: ignore[arg-type]

    assert exc_info.value.status_code == 413
    assert exc_info.value.detail == "이미지는 최대 3바이트까지 업로드할 수 있어요."
