from app.services.youtube import extract_youtube_video_id, youtube_thumbnail_url


def test_extract_youtube_video_id_from_watch_url() -> None:
    assert extract_youtube_video_id("https://www.youtube.com/watch?v=abc123") == "abc123"


def test_extract_youtube_video_id_from_short_url() -> None:
    assert extract_youtube_video_id("https://youtu.be/xyz789") == "xyz789"


def test_youtube_thumbnail_url() -> None:
    assert youtube_thumbnail_url("abc123") == "https://img.youtube.com/vi/abc123/hqdefault.jpg"
