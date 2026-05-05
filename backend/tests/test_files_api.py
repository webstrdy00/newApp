from collections.abc import Generator
from datetime import date
from io import BytesIO

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.api import deps
from app.db.session import Base
from app.main import create_app
from app.models.record import AttachmentType, CookingRecord, RecordAttachment
from app.models.user import User
from app.schemas.record import AttachmentRead
from app.services.storage import storage_service


@pytest.fixture
def db() -> Generator[Session, None, None]:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        yield session
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture
def client(db: Session) -> Generator[TestClient, None, None]:
    app = create_app()

    def override_db_session() -> Generator[Session, None, None]:
        yield db

    app.dependency_overrides[deps.db_session] = override_db_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def create_image_attachment(db: Session, object_key: str = "records/images/owned.jpg") -> None:
    user = User(email="cook@example.com", hashed_password="unused")
    record = CookingRecord(user=user, dish_name="김치찌개", cooked_date=date(2026, 4, 26))
    record.attachments.append(
        RecordAttachment(
            type=AttachmentType.IMAGE,
            title="photo.jpg",
            object_key=object_key,
            sort_order=0,
        )
    )
    db.add(record)
    db.commit()


def test_read_file_requires_signed_token(client: TestClient, db: Session) -> None:
    object_key = "records/images/owned.jpg"
    create_image_attachment(db, object_key)

    response = client.get(f"/api/files/{object_key}")

    assert response.status_code == 404
    assert response.json()["detail"] == "파일을 찾을 수 없어요."


def test_read_file_rejects_token_for_different_object(client: TestClient, db: Session) -> None:
    object_key = "records/images/owned.jpg"
    create_image_attachment(db, object_key)
    token = storage_service.create_file_access_token("records/images/other.jpg")

    response = client.get(f"/api/files/{object_key}", params={"token": token})

    assert response.status_code == 404
    assert response.json()["detail"] == "파일을 찾을 수 없어요."


def test_read_file_rejects_unreferenced_object(client: TestClient) -> None:
    object_key = "records/images/missing.jpg"
    token = storage_service.create_file_access_token(object_key)

    response = client.get(f"/api/files/{object_key}", params={"token": token})

    assert response.status_code == 404
    assert response.json()["detail"] == "파일을 찾을 수 없어요."


def test_read_file_streams_owned_referenced_object(
    client: TestClient,
    db: Session,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    object_key = "records/images/owned.jpg"
    create_image_attachment(db, object_key)
    token = storage_service.create_file_access_token(object_key)

    def fake_get_object(received_key: str):
        assert received_key == object_key
        return {"ContentType": "image/jpeg", "Body": BytesIO(b"image-bytes")}

    monkeypatch.setattr(storage_service, "get_object", fake_get_object)

    response = client.get(f"/api/files/{object_key}", params={"token": token})

    assert response.status_code == 200
    assert response.headers["content-type"] == "image/jpeg"
    assert response.content == b"image-bytes"


def test_attachment_read_serializes_image_thumbnail_as_signed_url(db: Session) -> None:
    object_key = "records/images/owned.jpg"
    create_image_attachment(db, object_key)
    attachment = db.query(RecordAttachment).filter_by(object_key=object_key).one()

    payload = AttachmentRead.model_validate(attachment).model_dump()

    assert payload["thumbnail_url"].startswith(
        "http://localhost:8000/api/files/records/images/owned.jpg?token="
    )
