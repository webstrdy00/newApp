from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


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
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    api_prefix: str = "/api"
    api_public_base_url: str = "http://localhost:8000/api"
    database_url: str = "postgresql+psycopg://haemeoknote:haemeoknote@localhost:5432/haemeoknote"
    cors_origins: list[str] = Field(default_factory=lambda: ["*"], alias="API_CORS_ORIGINS")

    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket: str = "haemeoknote"
    minio_secure: bool = False
    image_upload_max_bytes: int = 10 * 1024 * 1024
    image_upload_allowed_content_types: list[str] = Field(
        default_factory=lambda: ["image/jpeg", "image/png", "image/webp"]
    )
    jwt_secret_key: str = "change-me-in-production-with-strong-secret"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value: str | list[str]) -> list[str]:
        return parse_list_setting(value)

    @field_validator("image_upload_allowed_content_types", mode="before")
    @classmethod
    def parse_allowed_content_types(cls, value: str | list[str]) -> list[str]:
        return [item.lower() for item in parse_list_setting(value)]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
