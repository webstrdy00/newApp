import json
from urllib.parse import parse_qs, quote, urlparse
from urllib.request import urlopen


def extract_youtube_video_id(raw_url: str) -> str | None:
    parsed = urlparse(raw_url)
    hostname = parsed.hostname or ""

    if hostname in {"youtu.be", "www.youtu.be"}:
        return parsed.path.lstrip("/") or None

    if hostname == "youtube.com" or hostname.endswith(".youtube.com"):
        if parsed.path == "/watch":
            return parse_qs(parsed.query).get("v", [None])[0]
        if parsed.path.startswith("/shorts/") or parsed.path.startswith("/embed/"):
            return parsed.path.split("/")[2] if len(parsed.path.split("/")) > 2 else None

    return None


def youtube_thumbnail_url(video_id: str) -> str:
    return f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"


def fetch_youtube_oembed_title(raw_url: str, timeout: float = 2.0) -> str | None:
    """Return a YouTube oEmbed title when it is quickly available."""
    if extract_youtube_video_id(raw_url) is None:
        return None

    endpoint = f"https://www.youtube.com/oembed?url={quote(raw_url, safe='')}&format=json"
    try:
        with urlopen(endpoint, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except Exception:
        return None

    title = payload.get("title")
    return title if isinstance(title, str) and title.strip() else None
