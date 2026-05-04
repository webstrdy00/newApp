from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import current_user, db_session
from app.models.user import User
from app.schemas.auth import LoginRequest, TokenResponse
from app.schemas.user import UserCreate, UserRead
from app.services.auth import authenticate_user, create_access_token, create_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def register(payload: UserCreate, db: Session = Depends(db_session)) -> User:
    return create_user(db, payload)


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(db_session)) -> TokenResponse:
    user = authenticate_user(db, payload.email, payload.password)
    return TokenResponse(access_token=create_access_token(user))


@router.get("/me", response_model=UserRead)
def me(user: User = Depends(current_user)) -> User:
    return user
