from urllib.parse import parse_qs, urlparse


def extract_youtube_video_id(raw_url: str) -> str | None:
    parsed = urlparse(raw_url)
    hostname = parsed.hostname or ""

    if hostname in {"youtu.be", "www.youtu.be"}:
        return parsed.path.lstrip("/") or None

    if hostname.endswith("youtube.com"):
        if parsed.path == "/watch":
            return parse_qs(parsed.query).get("v", [None])[0]
        if parsed.path.startswith("/shorts/") or parsed.path.startswith("/embed/"):
            return parsed.path.split("/")[2] if len(parsed.path.split("/")) > 2 else None

    return None


def youtube_thumbnail_url(video_id: str) -> str:
    return f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"
