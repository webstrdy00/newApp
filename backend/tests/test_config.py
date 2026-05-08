import pytest
from pydantic import ValidationError

from app.core.config import Settings
from app.main import allow_cors_credentials


def test_wildcard_cors_does_not_allow_credentials() -> None:
    assert allow_cors_credentials(["*"]) is False
    assert allow_cors_credentials(["https://app.example.com"]) is True


def test_production_settings_reject_insecure_defaults() -> None:
    with pytest.raises(ValidationError):
        Settings(
            environment="production",
            jwt_secret_key="change-me-in-production-with-strong-secret",
            minio_access_key="minioadmin",
            minio_secret_key="minioadmin",
            cors_origins=["*"],
        )


def test_production_settings_accept_explicit_security_values() -> None:
    settings = Settings(
        environment="production",
        jwt_secret_key="a-production-secret-that-is-long-enough",
        minio_access_key="prod-access-key",
        minio_secret_key="prod-secret-key",
        cors_origins=["https://app.example.com"],
    )

    assert settings.environment == "production"
