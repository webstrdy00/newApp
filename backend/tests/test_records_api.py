from fastapi.testclient import TestClient

from app.main import create_app


def test_preview_attachment_link_requires_authentication() -> None:
    with TestClient(create_app()) as client:
        response = client.get(
            "/api/records/attachments/preview",
            params={"url": "https://www.youtube.com/watch?v=abc123"},
        )

    assert response.status_code == 401
    assert response.json()["detail"] == "로그인이 필요합니다."
