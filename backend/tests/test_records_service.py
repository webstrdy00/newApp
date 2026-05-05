from datetime import date, timedelta

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.db.session import Base
from app.models.record import AttachmentType
from app.models.user import User
from app.schemas.record import (
    AttachmentCreate,
    CookingRecordCreate,
    CookingRecordUpdate,
    IngredientCreate,
)
from app.services import records as records_service
from app.services.records import (
    add_image_attachment,
    calendar_days,
    clone_record,
    create_record,
    delete_attachment,
    delete_record,
    search_records,
    update_record,
)


@pytest.fixture
def db() -> Session:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        yield session
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture
def user(db: Session) -> User:
    user = User(
        email="cook@example.com",
        hashed_password="unused",
        display_name="요리하는 사용자",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def other_user(db: Session) -> User:
    user = User(
        email="other@example.com",
        hashed_password="unused",
        display_name="다른 사용자",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def record_payload(
    *,
    dish_name: str = "김치찌개",
    cooked_date: date | None = None,
    ingredients: list[IngredientCreate] | None = None,
    attachments: list[AttachmentCreate] | None = None,
) -> CookingRecordCreate:
    return CookingRecordCreate(
        dish_name=dish_name,
        cooked_date=cooked_date or date(2026, 4, 26),
        recipe="끓인다",
        memo="다음에는 두부 추가",
        rating=4,
        ingredients=ingredients or [IngredientCreate(name="김치", quantity="200g")],
        attachments=attachments or [],
    )


def image_attachment(object_key: str) -> AttachmentCreate:
    return AttachmentCreate(
        type=AttachmentType.IMAGE,
        title="photo.jpg",
        object_key=object_key,
        thumbnail_url=f"http://localhost:8000/api/files/{object_key}",
    )


def test_create_search_calendar_and_clone_record(db: Session, user: User) -> None:
    record = create_record(
        db,
        record_payload(
            ingredients=[
                IngredientCreate(name="김치", quantity="200g"),
                IngredientCreate(name="두부", quantity="1모"),
            ],
            attachments=[
                AttachmentCreate(type=AttachmentType.URL, url="https://example.com/recipe")
            ],
        ),
        user.id,
    )

    assert record.id is not None
    assert record.dish_name == "김치찌개"
    assert [item.name for item in record.ingredients] == ["김치", "두부"]

    assert [item.id for item in search_records(db, user_id=user.id, query="두부")] == [record.id]
    assert calendar_days(db, user_id=user.id, year=2026, month=4) == [(date(2026, 4, 26), 1)]

    cloned = clone_record(db, record.id, user.id, date(2026, 4, 27))

    assert cloned.id != record.id
    assert cloned.user_id == user.id
    assert cloned.dish_name == record.dish_name
    assert cloned.cooked_date == date(2026, 4, 27)
    assert cloned.ingredients[0].id != record.ingredients[0].id


def test_create_record_rejects_future_date(db: Session, user: User) -> None:
    with pytest.raises(HTTPException) as exc_info:
        create_record(db, record_payload(cooked_date=date.today() + timedelta(days=1)), user.id)

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail == "미래 날짜에는 기록을 저장할 수 없어요."


def test_create_record_rejects_quantity_without_ingredient_name(db: Session, user: User) -> None:
    with pytest.raises(HTTPException) as exc_info:
        create_record(
            db,
            record_payload(ingredients=[IngredientCreate(name="", quantity="1개")]),
            user.id,
        )

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail == "재료명 없이 수량만 입력할 수 없어요."


def test_create_record_rejects_duplicate_links(db: Session, user: User) -> None:
    duplicate_url = "https://example.com/recipe"

    with pytest.raises(HTTPException) as exc_info:
        create_record(
            db,
            record_payload(
                attachments=[
                    AttachmentCreate(type=AttachmentType.URL, url=duplicate_url),
                    AttachmentCreate(type=AttachmentType.URL, url=duplicate_url),
                ],
            ),
            user.id,
        )

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail == "이미 추가된 링크입니다."


def test_update_record_deletes_removed_image_object(
    db: Session,
    user: User,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    deleted_keys: list[str] = []
    monkeypatch.setattr(records_service.storage_service, "delete_object", deleted_keys.append)

    record = create_record(db, record_payload(), user.id)
    add_image_attachment(
        db,
        record.id,
        user.id,
        title="photo.jpg",
        object_key="records/images/original.jpg",
        thumbnail_url=None,
    )

    update_record(db, record.id, user.id, CookingRecordUpdate(attachments=[]))

    assert deleted_keys == ["records/images/original.jpg"]


def test_delete_image_attachment_keeps_storage_object_while_clone_references_it(
    db: Session,
    user: User,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    deleted_keys: list[str] = []
    monkeypatch.setattr(records_service.storage_service, "delete_object", deleted_keys.append)

    record = create_record(db, record_payload(), user.id)
    add_image_attachment(
        db,
        record.id,
        user.id,
        title="photo.jpg",
        object_key="records/images/shared.jpg",
        thumbnail_url=None,
    )
    cloned = clone_record(db, record.id, user.id, date(2026, 4, 27))

    delete_attachment(db, record.id, user.id, record.attachments[0].id)

    assert deleted_keys == []

    delete_record(db, cloned.id, user.id)

    assert deleted_keys == ["records/images/shared.jpg"]


def test_create_record_rejects_unowned_image_object_key(db: Session, user: User) -> None:
    with pytest.raises(HTTPException) as exc_info:
        create_record(
            db,
            record_payload(attachments=[image_attachment("records/images/unowned.jpg")]),
            user.id,
        )

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail == "업로드된 본인 사진만 첨부할 수 있어요."


def test_create_record_allows_owned_image_object_key(db: Session, user: User) -> None:
    source = create_record(db, record_payload(), user.id)
    add_image_attachment(
        db,
        source.id,
        user.id,
        title="photo.jpg",
        object_key="records/images/owned.jpg",
        thumbnail_url=None,
    )

    copied = create_record(
        db,
        record_payload(attachments=[image_attachment("records/images/owned.jpg")]),
        user.id,
    )

    assert copied.attachments[0].object_key == "records/images/owned.jpg"


def test_delete_missing_attachment_returns_404(db: Session, user: User) -> None:
    record = create_record(db, record_payload(), user.id)

    with pytest.raises(HTTPException) as exc_info:
        delete_attachment(db, record.id, user.id, 999)

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "첨부 자료를 찾을 수 없어요."


def test_records_are_scoped_to_owner(db: Session, user: User, other_user: User) -> None:
    record = create_record(db, record_payload(dish_name="된장찌개"), user.id)
    create_record(db, record_payload(dish_name="파스타"), other_user.id)

    assert [item.id for item in search_records(db, user_id=user.id, query="찌개")] == [record.id]
    assert search_records(db, user_id=other_user.id, query="된장") == []

    with pytest.raises(HTTPException) as exc_info:
        update_record(
            db,
            record.id,
            other_user.id,
            CookingRecordUpdate(dish_name="권한 없는 수정"),
        )

    assert exc_info.value.status_code == 404
