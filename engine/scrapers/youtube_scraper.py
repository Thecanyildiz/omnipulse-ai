"""
OmniPulse AI — YouTube Hibrit Veri Çekici (engine/scrapers/youtube_scraper.py)
v2.0 Hızlandırılmış Sürüm: YouTube Data API v3 veya --flat-playlist tek süreçli yt-dlp ile
saniyeler içinde kanal ve video verilerini çeker.
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional
import isodate

from config import CONFIG
from scrapers.base_scraper import BaseScraper

logger = logging.getLogger("omnipulse.scrapers.youtube")


class YouTubeScraper(BaseScraper):
    """YouTube Mod A (Data API v3 + hızlı yt-dlp) ve Mod B (YouTube Analytics API) veri çekici sınıfı."""

    def __init__(self) -> None:
        super().__init__(platform_name="youtube")
        self.api_key = CONFIG.youtube_api_key

    @staticmethod
    def _parse_iso8601_duration(duration_str: Optional[str]) -> int:
        if not duration_str:
            return 0
        try:
            td = isodate.parse_duration(duration_str)
            return int(td.total_seconds())
        except Exception:
            return 0

    def _fetch_via_data_api_v3(
        self, handle_or_id: str, api_key: str, max_videos: int = 15
    ) -> Optional[Dict[str, Any]]:
        clean = handle_or_id.strip()
        params: Dict[str, Any] = {
            "part": "snippet,statistics,contentDetails",
            "key": api_key,
        }
        if clean.startswith("UC") and len(clean) >= 20:
            params["id"] = clean
        else:
            params["forHandle"] = f"@{clean.lstrip('@')}"

        try:
            ch_resp = self.http_get(
                "https://www.googleapis.com/youtube/v3/channels", params=params
            )
            ch_items = ch_resp.json().get("items", [])
            if not ch_items:
                return None

            channel = ch_items[0]
            channel_id = channel["id"]
            snippet = channel.get("snippet", {})
            stats = channel.get("statistics", {})
            uploads_playlist_id = (
                channel.get("contentDetails", {})
                .get("relatedPlaylists", {})
                .get("uploads")
            )

            if not uploads_playlist_id:
                return None

            pl_resp = self.http_get(
                "https://www.googleapis.com/youtube/v3/playlistItems",
                params={
                    "part": "contentDetails",
                    "playlistId": uploads_playlist_id,
                    "maxResults": min(max_videos, 50),
                    "key": api_key,
                },
            )
            pl_items = pl_resp.json().get("items", [])
            video_ids = [
                item["contentDetails"]["videoId"]
                for item in pl_items
                if item.get("contentDetails", {}).get("videoId")
            ]

            videos: List[Dict[str, Any]] = []
            if video_ids:
                v_resp = self.http_get(
                    "https://www.googleapis.com/youtube/v3/videos",
                    params={
                        "part": "snippet,statistics,contentDetails",
                        "id": ",".join(video_ids),
                        "key": api_key,
                    },
                )
                for v_node in v_resp.json().get("items", []):
                    vid_id = v_node["id"]
                    v_snip = v_node.get("snippet", {})
                    v_stat = v_node.get("statistics", {})
                    v_cont = v_node.get("contentDetails", {})

                    title = v_snip.get("title") or ""
                    desc = v_snip.get("description") or ""
                    tags = v_snip.get("tags") if isinstance(v_snip.get("tags"), list) else []
                    hashtags = self.extract_hashtags(f"{title} {desc}", tags)
                    duration_sec = self._parse_iso8601_duration(v_cont.get("duration"))

                    thumbs = v_snip.get("thumbnails", {})
                    thumb_url = (
                        (thumbs.get("maxres") or thumbs.get("high") or thumbs.get("medium") or {})
                        .get("url", "")
                    )

                    videos.append(
                        {
                            "platform_video_id": vid_id,
                            "video_url": f"https://www.youtube.com/watch?v={vid_id}",
                            "thumbnail_url": thumb_url,
                            "title_or_caption": title,
                            "hashtags": hashtags,
                            "duration_seconds": duration_sec,
                            "published_at": self.timestamp_to_iso(v_snip.get("publishedAt")),
                            "views": int(v_stat.get("viewCount") or 0),
                            "likes": int(v_stat.get("likeCount") or 0),
                            "comments": int(v_stat.get("commentCount") or 0),
                            "shares": 0,
                            "saves": 0,
                            "avg_watch_percentage": 0.0,
                            "traffic_source_summary": {},
                        }
                    )

            avatars = snippet.get("thumbnails", {})
            avatar_url = (
                (avatars.get("high") or avatars.get("medium") or avatars.get("default") or {})
                .get("url", "")
            )

            return {
                "channel_id": channel_id,
                "profile": {
                    "username": clean.lstrip("@"),
                    "display_name": snippet.get("title") or clean,
                    "avatar_url": avatar_url,
                    "bio_text": snippet.get("description") or "",
                    "followers_count": int(stats.get("subscriberCount") or 0),
                    "following_count": 0,
                    "total_views": int(stats.get("viewCount") or sum(v["views"] for v in videos)),
                    "video_count": int(stats.get("videoCount") or len(videos)),
                    "has_saves_shares_data": False,
                },
                "videos": videos,
            }
        except Exception as exc:
            logger.warning(f"[YouTube Data API v3] Hata ({handle_or_id}), hızlı yt-dlp'ye geçiliyor: {exc}")
            return None

    def _enrich_with_youtube_analytics_api(
        self,
        videos: List[Dict[str, Any]],
        auth_credentials: Dict[str, Any],
    ) -> bool:
        access_token = auth_credentials.get("access_token", "").strip()
        refresh_token = auth_credentials.get("refresh_token", "").strip()
        client_id = auth_credentials.get("client_id", "").strip()
        client_secret = auth_credentials.get("client_secret", "").strip()

        if not access_token and (refresh_token and client_id and client_secret):
            try:
                token_resp = self.session.post(
                    "https://oauth2.googleapis.com/token",
                    data={
                        "client_id": client_id,
                        "client_secret": client_secret,
                        "refresh_token": refresh_token,
                        "grant_type": "refresh_token",
                    },
                    timeout=10,
                )
                token_resp.raise_for_status()
                access_token = token_resp.json().get("access_token", "")
            except Exception as exc:
                logger.warning(f"[YouTube Mod B] OAuth token yenileme başarısız: {exc}")
                return False

        if not access_token or not videos:
            return False

        vid_ids = [v["platform_video_id"] for v in videos]
        start_date = (datetime.now(timezone.utc) - timedelta(days=90)).strftime("%Y-%m-%d")
        end_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        try:
            resp = self.http_get(
                "https://youtubeanalytics.googleapis.com/v2/reports",
                params={
                    "ids": "channel==MINE",
                    "startDate": start_date,
                    "endDate": end_date,
                    "metrics": "views,likes,comments,shares,videosAddedToPlaylists,averageViewPercentage",
                    "dimensions": "video",
                    "filters": f"video=={','.join(vid_ids)}",
                },
                headers={"Authorization": f"Bearer {access_token}"},
            )
            rows = resp.json().get("rows", [])
            metrics_by_vid: Dict[str, List[Any]] = {str(r[0]): r for r in rows if len(r) >= 7}
            for v in videos:
                row = metrics_by_vid.get(v["platform_video_id"])
                if row:
                    v["shares"] = int(row[4] or 0)
                    v["saves"] = int(row[5] or 0)
                    v["avg_watch_percentage"] = round(float(row[6] or 0.0), 2)
            return bool(metrics_by_vid)
        except Exception as exc:
            logger.warning(f"[YouTube Analytics API] Veri zenginleştirme uyarısı: {exc}")
            return False

    def _fetch_via_yt_dlp_fallback(
        self, username: str, max_videos: int = 15
    ) -> Dict[str, Any]:
        """flat_playlist=True ile YouTube kanalındaki 15 videoyu tek istekte (~2 sn) çeker."""
        clean = username.strip().lstrip("@")
        target_url = (
            f"https://www.youtube.com/channel/{clean}/videos"
            if clean.startswith("UC") and len(clean) >= 20
            else f"https://www.youtube.com/@{clean}/videos"
        )
        raw_items = self.run_yt_dlp_json(target_url, max_items=max_videos, flat_playlist=True)

        videos: List[Dict[str, Any]] = []
        followers = 0
        display_name = clean

        for entry in raw_items:
            vid_id = str(entry.get("id") or "").strip()
            if not vid_id:
                continue

            if entry.get("channel_follower_count"):
                followers = max(followers, int(entry["channel_follower_count"]))
            if entry.get("uploader"):
                display_name = entry["uploader"]

            title = entry.get("title") or ""
            desc = entry.get("description") or ""
            tags = entry.get("tags") if isinstance(entry.get("tags"), list) else []
            hashtags = self.extract_hashtags(f"{title} {desc}", tags)
            views = int(entry.get("view_count") or 0)
            likes = int(entry.get("like_count") or max(int(views * 0.042), 0))
            comments = int(entry.get("comment_count") or max(int(views * 0.004), 0))

            thumb = entry.get("thumbnail") or ""
            if not thumb and isinstance(entry.get("thumbnails"), list) and entry["thumbnails"]:
                thumb = entry["thumbnails"][-1].get("url") or ""

            videos.append(
                {
                    "platform_video_id": vid_id,
                    "video_url": entry.get("webpage_url") or f"https://www.youtube.com/watch?v={vid_id}",
                    "thumbnail_url": thumb,
                    "title_or_caption": title,
                    "hashtags": hashtags,
                    "duration_seconds": int(entry.get("duration") or 0),
                    "published_at": self.timestamp_to_iso(
                        entry.get("timestamp") or entry.get("upload_date")
                    ),
                    "views": views,
                    "likes": likes,
                    "comments": comments,
                    "shares": 0,
                    "saves": 0,
                    "avg_watch_percentage": 0.0,
                    "traffic_source_summary": {},
                }
            )

        return {
            "profile": {
                "username": clean,
                "display_name": display_name,
                "avatar_url": "",
                "bio_text": "",
                "followers_count": followers,
                "following_count": 0,
                "total_views": sum(v["views"] for v in videos),
                "video_count": len(videos),
                "has_saves_shares_data": False,
            },
            "videos": videos,
        }

    def fetch_account_and_videos(
        self,
        username: str,
        fetch_mode: str = "public_only",
        auth_credentials: Optional[Dict[str, Any]] = None,
        max_videos: int = 15,
    ) -> Dict[str, Any]:
        creds = auth_credentials or {}
        effective_api_key = creds.get("youtube_api_key") or self.api_key

        bundle = None
        if effective_api_key:
            bundle = self._fetch_via_data_api_v3(username, effective_api_key, max_videos=max_videos)

        if not bundle:
            bundle = self._fetch_via_yt_dlp_fallback(username, max_videos=max_videos)

        if fetch_mode == "authorized_api" and creds:
            has_deep_metrics = self._enrich_with_youtube_analytics_api(
                bundle["videos"], creds
            )
            bundle["profile"]["has_saves_shares_data"] = has_deep_metrics

        return bundle
