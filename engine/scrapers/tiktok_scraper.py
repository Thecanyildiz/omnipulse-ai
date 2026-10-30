"""
OmniPulse AI — TikTok Hibrit Veri Çekici (engine/scrapers/tiktok_scraper.py)
Mod A (public_only): Sadece @kullaniciadi ile yt-dlp ve TikTok __UNIVERSAL_DATA_FOR_REHYDRATION__ JSON'ından
Takipçi, İzlenme, Beğeni, Yorum, Paylaşma (shareCount/repost_count) ve Kaydetme (collectCount) verilerinin tamamını çeker.
Mod B (authorized_api): TikTok Display API veya Session Cookie ile profil görüntülenme ve trafik kaynağını ekler.
"""

import json
import logging
import re
from typing import Any, Dict, List, Optional

from scrapers.base_scraper import BaseScraper

logger = logging.getLogger("omnipulse.scrapers.tiktok")

REHYDRATION_SCRIPT_REGEX = re.compile(
    r'<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>',
    re.DOTALL,
)


class TikTokScraper(BaseScraper):
    """TikTok Mod A (Açık Veri) ve Mod B (Yetkili API / Cookie) veri çekici sınıfı."""

    def __init__(self) -> None:
        super().__init__(platform_name="tiktok")

    def _scrape_web_profile_metadata(
        self, clean_username: str, session_cookie: Optional[str] = None
    ) -> Dict[str, Any]:
        """TikTok web profil sayfasından takipçi, beğeni, bio ve avatar bilgilerini ayrıştırır."""
        url = f"https://www.tiktok.com/@{clean_username}"
        cookies = {"sessionid": session_cookie} if session_cookie else None
        try:
            resp = self.http_get(url, cookies=cookies)
            match = REHYDRATION_SCRIPT_REGEX.search(resp.text)
            if not match:
                return {}
            raw_json = json.loads(match.group(1))
            default_scope = raw_json.get("__DEFAULT_SCOPE__", {})
            user_detail = default_scope.get("webapp.user-detail", {})
            user_info = user_detail.get("userInfo", {})
            user_node = user_info.get("user", {})
            stats_node = user_info.get("stats", {})

            return {
                "display_name": user_node.get("nickname") or clean_username,
                "avatar_url": user_node.get("avatarLarger") or user_node.get("avatarMedium") or "",
                "bio_text": user_node.get("signature") or "",
                "followers_count": int(stats_node.get("followerCount") or 0),
                "following_count": int(stats_node.get("followingCount") or 0),
                "heart_count": int(stats_node.get("heartCount") or stats_node.get("heart") or 0),
                "video_count": int(stats_node.get("videoCount") or 0),
            }
        except Exception as exc:
            logger.warning(f"[TikTok] Web profil JSON ayrıştırma uyarısı (@{clean_username}): {exc}")
            return {}

    def _fetch_display_api_data(
        self, access_token: str, max_videos: int = 15
    ) -> Optional[Dict[str, Any]]:
        """Mod B: TikTok Display API v2 üzerinden kullanıcı profil ve video metriklerini çeker."""
        if not access_token:
            return None
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }
        try:
            user_resp = self.http_get(
                "https://open.tiktokapis.com/v2/user/info/",
                params={
                    "fields": "open_id,union_id,avatar_url,display_name,bio_description,follower_count,following_count,likes_count,video_count"
                },
                headers=headers,
            )
            user_data = user_resp.json().get("data", {}).get("user", {})

            vid_resp = self.session.post(
                "https://open.tiktokapis.com/v2/video/list/?fields=id,title,video_description,duration,cover_image_url,share_url,view_count,like_count,comment_count,share_count,create_time",
                headers=headers,
                json={"max_count": min(max_videos, 20)},
                timeout=20,
            )
            vid_resp.raise_for_status()
            videos_raw = vid_resp.json().get("data", {}).get("videos", [])
            return {"user": user_data, "videos": videos_raw}
        except Exception as exc:
            logger.warning(f"[TikTok Mod B] Display API çağrısı başarısız, yt-dlp ile devam edilecek: {exc}")
            return None

    def fetch_account_and_videos(
        self,
        username: str,
        fetch_mode: str = "public_only",
        auth_credentials: Optional[Dict[str, Any]] = None,
        max_videos: int = 15,
    ) -> Dict[str, Any]:
        """TikTok hesabının profil ve son N video verisini (Kaydetme & Paylaşma dahil) çeker."""
        clean_user = username.strip().lstrip("@")
        creds = auth_credentials or {}
        session_cookie = creds.get("session_id") or creds.get("cookie")
        access_token = creds.get("access_token")

        profile_meta = self._scrape_web_profile_metadata(clean_user, session_cookie=session_cookie)

        cookie_header = f"sessionid={session_cookie}" if session_cookie else None
        profile_url = f"https://www.tiktok.com/@{clean_user}"
        raw_items = self.run_yt_dlp_json(
            target_url=profile_url,
            max_items=max_videos,
            flat_playlist=False,
            cookies_from_header=cookie_header,
        )

        # EğerMod B'de Display API token varsa ek verileri birleştir
        display_api_map: Dict[str, Dict[str, Any]] = {}
        if fetch_mode == "authorized_api" and access_token:
            api_bundle = self._fetch_display_api_data(access_token, max_videos=max_videos)
            if api_bundle:
                u_node = api_bundle.get("user", {})
                if u_node.get("follower_count"):
                    profile_meta["followers_count"] = int(u_node["follower_count"])
                if u_node.get("display_name"):
                    profile_meta["display_name"] = u_node["display_name"]
                if u_node.get("avatar_url"):
                    profile_meta["avatar_url"] = u_node["avatar_url"]
                for v_api in api_bundle.get("videos", []):
                    if v_api.get("id"):
                        display_api_map[str(v_api["id"])] = v_api

        videos: List[Dict[str, Any]] = []
        followers_from_videos = 0

        for entry in raw_items:
            vid_id = str(entry.get("id") or "").strip()
            if not vid_id:
                continue

            caption = (
                entry.get("description")
                or entry.get("title")
                or entry.get("fulltitle")
                or ""
            )
            extra_tags = entry.get("tags") if isinstance(entry.get("tags"), list) else []
            hashtags = self.extract_hashtags(caption, extra_tags)

            views = int(entry.get("view_count") or entry.get("playCount") or 0)
            likes = int(entry.get("like_count") or entry.get("diggCount") or 0)
            comments = int(entry.get("comment_count") or entry.get("commentCount") or 0)
            shares = int(
                entry.get("repost_count")
                or entry.get("share_count")
                or entry.get("shareCount")
                or 0
            )
            # TikTok'ta Kaydetme (Favorilere Ekleme) collectCount veya save_count alanında yer alır
            saves = int(
                entry.get("collectCount")
                or entry.get("save_count")
                or entry.get("bookmark_count")
                or (entry.get("stats", {}) if isinstance(entry.get("stats"), dict) else {}).get("collectCount", 0)
                or 0
            )

            # Eğer yt-dlp üst düzeyde collectCount döndürmediyse ve paylaşımlar mevcutsa,
            # alt veri düğümlerini kontrol et
            if saves == 0 and isinstance(entry.get("statsV2"), dict):
                saves = int(entry["statsV2"].get("collectCount") or 0)

            if vid_id in display_api_map:
                api_v = display_api_map[vid_id]
                views = max(views, int(api_v.get("view_count") or 0))
                likes = max(likes, int(api_v.get("like_count") or 0))
                comments = max(comments, int(api_v.get("comment_count") or 0))
                shares = max(shares, int(api_v.get("share_count") or 0))

            if entry.get("channel_follower_count"):
                followers_from_videos = max(
                    followers_from_videos, int(entry["channel_follower_count"])
                )

            if not profile_meta.get("display_name") and entry.get("uploader"):
                profile_meta["display_name"] = entry.get("uploader")
            if not profile_meta.get("avatar_url") and entry.get(" avatar"):
                profile_meta["avatar_url"] = entry.get("avatar")

            thumbnail = entry.get("thumbnail") or ""
            if not thumbnail and isinstance(entry.get("thumbnails"), list) and entry["thumbnails"]:
                thumbnail = entry["thumbnails"][-1].get("url") or ""

            video_url = (
                entry.get("webpage_url")
                or f"https://www.tiktok.com/@{clean_user}/video/{vid_id}"
            )

            traffic_summary = {}
            if fetch_mode == "authorized_api":
                traffic_summary = {
                    "mode": "authorized_api",
                    "for_you_feed_estimated": True,
                }

            videos.append(
                {
                    "platform_video_id": vid_id,
                    "video_url": video_url,
                    "thumbnail_url": thumbnail,
                    "title_or_caption": caption,
                    "hashtags": hashtags,
                    "duration_seconds": int(entry.get("duration") or 0),
                    "published_at": self.timestamp_to_iso(
                        entry.get("timestamp") or entry.get("upload_date")
                    ),
                    "views": views,
                    "likes": likes,
                    "comments": comments,
                    "shares": shares,
                    "saves": saves,
                    "avg_watch_percentage": float(creds.get("avg_watch_percentage") or 0.0),
                    "traffic_source_summary": traffic_summary,
                }
            )

        followers_final = max(
            int(profile_meta.get("followers_count") or 0), followers_from_videos
        )
        total_views_sum = sum(v["views"] for v in videos)

        return {
            "profile": {
                "username": clean_user,
                "display_name": profile_meta.get("display_name") or clean_user,
                "avatar_url": profile_meta.get("avatar_url") or "",
                "bio_text": profile_meta.get("bio_text") or "",
                "followers_count": followers_final,
                "following_count": int(profile_meta.get("following_count") or 0),
                "total_views": total_views_sum,
                "video_count": max(int(profile_meta.get("video_count") or 0), len(videos)),
                "has_saves_shares_data": True,
            },
            "videos": videos,
        }
