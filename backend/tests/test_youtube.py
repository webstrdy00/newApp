from app.services import youtube as youtube_service
from app.services.youtube import (
    extract_youtube_video_id,
    fetch_youtube_oembed_title,
    youtube_thumbnail_url,
)


def test_extract_youtube_video_id_from_watch_url() -> None:
    assert extract_youtube_video_id("https://www.youtube.com/watch?v=abc123") == "abc123"


def test_extract_youtube_video_id_from_short_url() -> None:
    assert extract_youtube_video_id("https://youtu.be/xyz789") == "xyz789"


def test_extract_youtube_video_id_rejects_lookalike_host() -> None:
    assert extract_youtube_video_id("https://notyoutube.com/watch?v=abc123") is None


def test_youtube_thumbnail_url() -> None:
    assert youtube_thumbnail_url("abc123") == "https://img.youtube.com/vi/abc123/hqdefault.jpg"


def test_fetch_youtube_oembed_title_skips_non_youtube_url() -> None:
    assert fetch_youtube_oembed_title("https://example.com/recipe") is None


def test_fetch_youtube_oembed_title_uses_oembed(monkeypatch) -> None:
    class Response:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, traceback):
            return False

        def read(self) -> bytes:
            return b'{"title": "Cooking video"}'

    def fake_urlopen(endpoint: str, timeout: float):
        assert "youtube.com/oembed" in endpoint
        assert timeout == 2.0
        return Response()

    monkeypatch.setattr(youtube_service, "urlopen", fake_urlopen)

    assert fetch_youtube_oembed_title("https://www.youtube.com/watch?v=abc123") == "Cooking video"
