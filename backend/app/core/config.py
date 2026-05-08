from functools import lru_cache

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


DEFAULT_JWT_SECRET_KEY = "change-me-in-production-with-strong-secret"
DEFAULT_MINIO_ACCESS_KEY = "minioadmin"
DEFAULT_MINIO_SECRET_KEY = "minioadmin"
PRODUCTION_ENVIRONMENTS = {"prod", "production"}


def parse_list_setting(value: str | list[str]) -> list[str]:
    if isinstance(value, list):
        return value
    stripped = value.strip()
    if not stripped:
        return []
    if stripped.startswith("["):
        import json

        return json.loads(stripped)
    return [item.strip() for item in stripped.split(",") if item.strip()]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    environment: str = Field(default="local", alias="ENVIRONMENT")
    api_prefix: str = "/api"
    api_public_base_url: str = "http://localhost:8000/api"
    database_url: str = "postgresql+psycopg://haemeoknote:haemeoknote@localhost:5432/haemeoknote"
    cors_origins: list[str] = Field(default_factory=lambda: ["*"], alias="API_CORS_ORIGINS")

    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = DEFAULT_MINIO_ACCESS_KEY
    minio_secret_key: str = DEFAULT_MINIO_SECRET_KEY
    minio_bucket: str = "haemeoknote"
    minio_secure: bool = False
    image_upload_max_bytes: int = 10 * 1024 * 1024
    image_upload_allowed_content_types: list[str] = Field(
        default_factory=lambda: ["image/jpeg", "image/png", "image/webp"]
    )
    jwt_secret_key: str = DEFAULT_JWT_SECRET_KEY
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7
    file_access_token_expire_minutes: int = 60

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value: str | list[str]) -> list[str]:
        return parse_list_setting(value)

    @field_validator("image_upload_allowed_content_types", mode="before")
    @classmethod
    def parse_allowed_content_types(cls, value: str | list[str]) -> list[str]:
        return [item.lower() for item in parse_list_setting(value)]

    @field_validator("environment")
    @classmethod
    def normalize_environment(cls, value: str) -> str:
        return value.strip().lower()

    @model_validator(mode="after")
    def validate_production_security(self) -> "Settings":
        if self.environment not in PRODUCTION_ENVIRONMENTS:
            return self

        if self.jwt_secret_key == DEFAULT_JWT_SECRET_KEY or len(self.jwt_secret_key) < 32:
            raise ValueError("운영 환경에서는 강한 JWT_SECRET_KEY가 필요합니다.")
        if "*" in self.cors_origins:
            raise ValueError("운영 환경에서는 API_CORS_ORIGINS에 명시적 origin을 설정해야 합니다.")
        if (
            self.minio_access_key == DEFAULT_MINIO_ACCESS_KEY
            or self.minio_secret_key == DEFAULT_MINIO_SECRET_KEY
        ):
            raise ValueError("운영 환경에서는 기본 MinIO 인증 정보를 사용할 수 없습니다.")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
