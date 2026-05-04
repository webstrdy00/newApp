import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.db.session import Base
from app.schemas.user import UserCreate
from app.services.auth import (
    authenticate_user,
    create_access_token,
    create_user,
    decode_access_token,
)


@pytest.fixture
def db() -> Session:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        yield session
    Base.metadata.drop_all(engine)
    engine.dispose()


def test_create_user_normalizes_email_and_hashes_password(db: Session) -> None:
    user = create_user(
        db,
        UserCreate(
            email=" Cook@Example.COM ",
            password="strong-password",
            display_name=" 요리사 ",
        ),
    )

    assert user.email == "cook@example.com"
    assert user.display_name == "요리사"
    assert user.hashed_password != "strong-password"


def test_create_user_rejects_duplicate_email(db: Session) -> None:
    payload = UserCreate(email="cook@example.com", password="strong-password")
    create_user(db, payload)

    with pytest.raises(HTTPException) as exc_info:
        create_user(db, payload)

    assert exc_info.value.status_code == 409
    assert exc_info.value.detail == "이미 가입된 이메일입니다."


def test_authenticate_user_and_decode_token(db: Session) -> None:
    user = create_user(db, UserCreate(email="cook@example.com", password="strong-password"))

    authenticated = authenticate_user(db, "COOK@example.com", "strong-password")
    token = create_access_token(authenticated)

    assert authenticated.id == user.id
    assert decode_access_token(token) == user.id


def test_authenticate_user_rejects_wrong_password(db: Session) -> None:
    create_user(db, UserCreate(email="cook@example.com", password="strong-password"))

    with pytest.raises(HTTPException) as exc_info:
        authenticate_user(db, "cook@example.com", "wrong-password")

    assert exc_info.value.status_code == 401
    assert exc_info.value.detail == "이메일 또는 비밀번호가 올바르지 않습니다."


def test_decode_access_token_rejects_invalid_token() -> None:
    with pytest.raises(HTTPException) as exc_info:
        decode_access_token("not-a-token")

    assert exc_info.value.status_code == 401
    assert exc_info.value.detail == "인증 정보가 유효하지 않습니다."
