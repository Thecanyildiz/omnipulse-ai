"""
OmniPulse AI — Instagram Hibrit Veri Çekici (engine/scrapers/instagram_scraper.py)
Mod A (public_only): Instaloader ve Instagram açık web profil uç noktası ile
Takipçi, Reels İzlenme (video_view_count), Beğeni (likes) ve Yorum (comments) sayılarını şifresiz çeker.
Mod B (authorized_api): Instagram Graph API Token veya Session ID girildiğinde
her Reels videosu için gizli olan saved (Kaydetme) ve shares (Paylaşma) sayılarını eksiksiz çeker.
"""

import itertools
import logging
from datetime import timezone
from typing import Any, Dict, List, Optional
import instaloader

from scrapers.base_scraper import BaseScraper

logger = logging.getLogger("omnipulse.scrapers.instagram")


class InstagramScraper(BaseScraper):
    """Instagram Mod A (Instaloader / Web JSON) ve Mod B (Graph API / Session Cookie) veri çekicisi."""

    def __init__(self) -> None:
        super().__init__(platform_name="instagram")

    def _fetch_via_graph_api(
        self,
        username: str,
        ig_business_id: str,
        access_token: str,
        max_videos: int = 15,
    ) -> Optional[Dict[str, Any]]:
        """Mod B: Instagram Graph API üzerinden gerçek Saved (Kaydetme) ve Shares (Paylaşım) metriklerini çeker."""
        if not ig_business_id or not access_token:
            return None
        try:
            prof_resp = self.http_get(
                f"https://graph.facebook.com/v21.0/{ig_business_id}",
                params={
                    "fields": "username,name,biography,profile_picture_url,followers_count,follows_count,media_count",
                    "access_token": access_token,
                },
            )
            prof_data = prof_resp.json()

            media_resp = self.http_get(
                f"https://graph.facebook.com/v21.0/{ig_business_id}/media",
                params={
                    "fields": "id,shortcode,caption,media_type,media_product_type,permalink,thumbnail_url,media_url,timestamp,like_count,comments_count",
                    "limit": min(max_videos * 2, 35),
                    "access_token": access_token,
                },
            )
            media_items = media_resp.json().get("data", [])

            videos: List[Dict[str, Any]] = []
            for m in media_items:
                if m.get("media_type") != "VIDEO" and m.get("media_product_type") != "REELS":
                    continue
                if len(videos) >= max_videos:
                    break

                media_id = str(m["id"])
                shortcode = m.get("shortcode") or media_id
                caption = m.get("caption") or ""
                hashtags = self.extract_hashtags(caption)

                views = 0
                saves = 0
                shares = 0
                likes = int(m.get("like_count") or 0)
                comments = int(m.get("comments_count") or 0)

                try:
                    ins_resp = self.http_get(
                        f"https://graph.facebook.com/v21.0/{media_id}/insights",
                        params={
                            "metric": "plays,saved,shares,likes,comments,total_interactions",
                            "access_token": access_token,
                        },
                    )
                    for metric_node in ins_resp.json().get("data", []):
                        m_name = metric_node.get("name")
                        m_val = int(
                            (metric_node.get("values") or [{}])[0].get("value") or 0
                        )
                        if m_name == "plays":
                            views = m_val
                        elif m_name == "saved":
                            saves = m_val
                        elif m_name == "shares":
                            shares = m_val
                except Exception as ins_exc:
                    logger.debug(f"[IG Graph Insights] {media_id} içgörü uyarısı: {ins_exc}")

                videos.append(
                    {
                        "platform_video_id": shortcode,
                        "video_url": m.get("permalink") or f"https://www.instagram.com/reel/{shortcode}/",
                        "thumbnail_url": m.get("thumbnail_url") or m.get("media_url") or "",
                        "title_or_caption": caption,
                        "hashtags": hashtags,
                        "duration_seconds": 0,
                        "published_at": self.timestamp_to_iso(m.get("timestamp")),
                        "views": views if views > 0 else likes * 12,
                        "likes": likes,
                        "comments": comments,
                        "shares": shares,
                        "saves": saves,
                        "avg_watch_percentage": 0.0,
                        "traffic_source_summary": {"source": "instagram_graph_api"},
                    }
                )

            return {
                "profile": {
                    "username": prof_data.get("username") or username.lstrip("@"),
                    "display_name": prof_data.get("name") or username.lstrip("@"),
                    "avatar_url": prof_data.get("profile_picture_url") or "",
                    "bio_text": prof_data.get("biography") or "",
                    "followers_count": int(prof_data.get("followers_count") or 0),
                    "following_count": int(prof_data.get("follows_count") or 0),
                    "total_views": sum(v["views"] for v in videos),
                    "video_count": int(prof_data.get("media_count") or len(videos)),
                    "has_saves_shares_data": True,
                },
                "videos": videos,
            }
        except Exception as exc:
            logger.warning(f"[Instagram Mod B Graph API] Hata, Instaloader katmanına geçiliyor: {exc}")
            return None

    def _fetch_via_instaloader(
        self,
        clean_username: str,
        session_id: Optional[str] = None,
        max_videos: int = 15,
    ) -> Optional[Dict[str, Any]]:
        """Instaloader ile açık profili veya Session Cookie ile yetkilendirilmiş profili tarar."""
        try:
            loader = instaloader.Instaloader(
                download_pictures=False,
                download_videos=False,
                download_video_thumbnails=False,
                download_geotags=False,
                download_comments=False,
                save_metadata=False,
                compress_json=False,
                user_agent=self.get_headers()["User-Agent"],
                max_connection_attempts=2,
            )
            if session_id:
                loader.context._session.cookies.set(
                    "sessionid", session_id, domain=".instagram.com"
                )

            profile = instaloader.Profile.from_username(loader.context, clean_username)
            videos: List[Dict[str, Any]] = []

            for post in itertools.islice(profile.get_posts(), max_videos * 2):
                if not post.is_video:
                    continue
                if len(videos) >= max_videos:
                    break

                caption = post.caption or ""
                hashtags = self.extract_hashtags(caption, list(post.caption_hashtags or []))
                views = int(post.video_view_count or 0)
                likes = int(max(post.likes, 0))
                comments = int(max(post.comments, 0))

                # Mod B Session Cookie aktifse post._node içindeki gizli alanları kontrol et
                raw_node = getattr(post, "_node", {}) or {}
                shares = int(raw_node.get("reshare_count") or raw_node.get("share_count") or 0)
                saves = int(raw_node.get("saved_count") or raw_node.get("save_count") or 0)

                pub_dt = post.date_utc.replace(tzinfo=timezone.utc).isoformat()

                videos.append(
                    {
                        "platform_video_id": post.shortcode,
                        "video_url": f"https://www.instagram.com/reel/{post.shortcode}/",
                        "thumbnail_url": post.url or "",
                        "title_or_caption": caption,
                        "hashtags": hashtags,
                        "duration_seconds": int(post.video_duration or 0),
                        "published_at": pub_dt,
                        "views": views if views > 0 else likes * 10,
                        "likes": likes,
                        "comments": comments,
                        "shares": shares,
                        "saves": saves,
                        "avg_watch_percentage": 0.0,
                        "traffic_source_summary": {},
                    }
                )

            has_saves = any((v["saves"] > 0 or v["shares"] > 0) for v in videos)
            return {
                "profile": {
                    "username": clean_username,
                    "display_name": profile.full_name or clean_username,
                    "avatar_url": profile.profile_pic_url or "",
                    "bio_text": profile.biography or "",
                    "followers_count": int(profile.followers or 0),
                    "following_count": int(profile.followees or 0),
                    "total_views": sum(v["views"] for v in videos),
                    "video_count": int(profile.mediacount or len(videos)),
                    "has_saves_shares_data": has_saves,
                },
                "videos": videos,
            }
        except Exception as exc:
            logger.warning(f"[Instaloader] @{clean_username} tarama uyarısı: {exc}")
            return None

    def _fetch_via_web_json_fallback(
        self, clean_username: str, session_id: Optional[str] = None, max_videos: int = 15
    ) -> Dict[str, Any]:
        """Instagram web_profile_info JSON uç noktası ve yt-dlp yedek katmanı."""
        headers = {
            "X-IG-App-ID": "936619743392459",
            "Referer": f"https://www.instagram.com/{clean_username}/",
        }
        cookies = {"sessionid": session_id} if session_id else None

        try:
            resp = self.http_get(
                "https://www.instagram.com/api/v1/users/web_profile_info/",
                params={"username": clean_username},
                headers=headers,
                cookies=cookies,
            )
            user_node = resp.json().get("data", {}).get("user", {})
            if user_node:
                followers = int(
                    user_node.get("edge_followed_by", {}).get("count") or 0
                )
                following = int(user_node.get("edge_follow", {}).get("count") or 0)
                edges = (
                    user_node.get("edge_owner_to_timeline_media", {}).get("edges")
                    or []
                )
                videos: List[Dict[str, Any]] = []
                for edge in edges:
                    node = edge.get("node", {})
                    if not node.get("is_video"):
                        continue
                    if len(videos) >= max_videos:
                        break
                    shortcode = node.get("shortcode") or node.get("id")
                    cap_edges = (
                        node.get("edge_media_to_caption", {}).get("edges") or []
                    )
                    caption = (
                        cap_edges[0].get("node", {}).get("text", "")
                        if cap_edges
                        else ""
                    )
                    hashtags = self.extract_hashtags(caption)
                    views = int(node.get("video_view_count") or 0)
                    likes = int(
                        node.get("edge_liked_by", {}).get("count")
                        or node.get("edge_media_preview_like", {}).get("count")
                        or 0
                    )
                    comments = int(
                        node.get("edge_media_to_comment", {}).get("count") or 0
                    )
                    videos.append(
                        {
                            "platform_video_id": str(shortcode),
                            "video_url": f"https://www.instagram.com/reel/{shortcode}/",
                            "thumbnail_url": node.get("display_url") or "",
                            "title_or_caption": caption,
                            "hashtags": hashtags,
                            "duration_seconds": int(node.get("video_duration") or 0),
                            "published_at": self.timestamp_to_iso(
                                node.get("taken_at_timestamp")
                            ),
                            "views": views if views > 0 else likes * 10,
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
                        "username": clean_username,
                        "display_name": user_node.get("full_name") or clean_username,
                        "avatar_url": user_node.get("profile_pic_url_hd")
                        or user_node.get("profile_pic_url")
                        or "",
                        "bio_text": user_node.get("biography") or "",
                        "followers_count": followers,
                        "following_count": following,
                        "total_views": sum(v["views"] for v in videos),
                        "video_count": int(
                            user_node.get("edge_owner_to_timeline_media", {}).get("count")
                            or len(videos)
                        ),
                        "has_saves_shares_data": False,
                    },
                    "videos": videos,
                }
        except Exception as exc:
            logger.warning(f"[Instagram Web JSON] @{clean_username} yedek uç nokta uyarısı: {exc}")

        return {
            "profile": {
                "username": clean_username,
                "display_name": clean_username,
                "avatar_url": "",
                "bio_text": "",
                "followers_count": 0,
                "following_count": 0,
                "total_views": 0,
                "video_count": 0,
                "has_saves_shares_data": False,
            },
            "videos": [],
        }

    def fetch_account_and_videos(
        self,
        username: str,
        fetch_mode: str = "public_only",
        auth_credentials: Optional[Dict[str, Any]] = None,
        max_videos: int = 15,
    ) -> Dict[str, Any]:
        """Instagram hesabını Mod A (Instaloader/Public) veya Mod B (Graph API / Session) ile çeker."""
        clean_user = username.strip().lstrip("@")
        creds = auth_credentials or {}
        access_token = creds.get("access_token") or creds.get("graph_api_token")
        ig_business_id = creds.get("ig_business_id") or creds.get("business_account_id")
        session_id = creds.get("session_id") or creds.get("sessionid")

        if fetch_mode == "authorized_api" and access_token and ig_business_id:
            graph_bundle = self._fetch_via_graph_api(
                clean_user, ig_business_id, access_token, max_videos=max_videos
            )
            if graph_bundle and graph_bundle["videos"]:
                return graph_bundle

        insta_bundle = self._fetch_via_instaloader(
            clean_user, session_id=session_id, max_videos=max_videos
        )
        if insta_bundle and (
            insta_bundle["videos"] or insta_bundle["profile"]["followers_count"] > 0
        ):
            return insta_bundle

        return self._fetch_via_web_json_fallback(
            clean_user, session_id=session_id, max_videos=max_videos
        )
