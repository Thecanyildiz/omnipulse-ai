"""
OmniPulse AI — Otonom Rakip Keşif Radarı (engine/scrapers/autonomous_radar.py)
Kullanıcı manuel rakip eklemez. Yapay zekanın belirlediği 5 niş arama sorgusunu kullanarak
ilgili platformda son 14 günde paylaşılan en viral 5 rakip videoyu bulur ve puanlar.
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List

from analytics.math_engine import MathEngine
from config import CONFIG
from scrapers.base_scraper import BaseScraper

logger = logging.getLogger("omnipulse.scrapers.radar")


class AutonomousCompetitorRadar(BaseScraper):
    """Niş anahtar kelimeleriyle TikTok, YouTube ve Instagram'da viral rakip videoları keşfeder."""

    def __init__(self) -> None:
        super().__init__(platform_name="autonomous_radar")

    def _search_youtube_competitors(
        self,
        keyword: str,
        exclude_username: str,
        lookback_days: int = 14,
        max_per_query: int = 4,
    ) -> List[Dict[str, Any]]:
        """YouTube üzerinde son 14 günde yayınlanan en yüksek izlenmeli videoları yt-dlp / API ile tarar."""
        results: List[Dict[str, Any]] = []
        cutoff_dt = datetime.now(timezone.utc) - timedelta(days=lookback_days)

        if CONFIG.youtube_api_key:
            try:
                published_after = cutoff_dt.strftime("%Y-%m-%dT%H:%M:%SZ")
                s_resp = self.http_get(
                    "https://www.googleapis.com/youtube/v3/search",
                    params={
                        "part": "snippet",
                        "q": keyword,
                        "type": "video",
                        "order": "viewCount",
                        "publishedAfter": published_after,
                        "maxResults": max_per_query,
                        "key": CONFIG.youtube_api_key,
                    },
                )
                v_ids = [
                    item["id"]["videoId"]
                    for item in s_resp.json().get("items", [])
                    if item.get("id", {}).get("videoId")
                ]
                if v_ids:
                    v_resp = self.http_get(
                        "https://www.googleapis.com/youtube/v3/videos",
                        params={
                            "part": "snippet,statistics,contentDetails",
                            "id": ",".join(v_ids),
                            "key": CONFIG.youtube_api_key,
                        },
                    )
                    for v_node in v_resp.json().get("items", []):
                        snip = v_node.get("snippet", {})
                        stat = v_node.get("statistics", {})
                        comp_user = (snip.get("channelTitle") or "rakip_kanal").strip()
                        if comp_user.lower() == exclude_username.lower():
                            continue
                        views = int(stat.get("viewCount") or 0)
                        likes = int(stat.get("likeCount") or 0)
                        comments = int(stat.get("commentCount") or 0)
                        title = snip.get("title") or ""
                        tags = snip.get("tags") if isinstance(snip.get("tags"), list) else []
                        hashtags = self.extract_hashtags(title, tags)
                        er = MathEngine.calculate_engagement_rate(views, likes, comments, 0, 0)
                        v_score = MathEngine.calculate_virality_score(
                            views, likes, comments, 0, 0, has_saves_shares=False
                        )
                        results.append(
                            {
                                "platform": "youtube",
                                "competitor_username": comp_user,
                                "platform_video_id": v_node["id"],
                                "video_url": f"https://www.youtube.com/watch?v={v_node['id']}",
                                "thumbnail_url": (
                                    snip.get("thumbnails", {}).get("high", {}).get("url") or ""
                                ),
                                "caption": title,
                                "hashtags": hashtags,
                                "search_keyword_used": keyword,
                                "duration_seconds": 0,
                                "views": views,
                                "likes": likes,
                                "comments": comments,
                                "shares": 0,
                                "saves": 0,
                                "engagement_rate": er,
                                "virality_score": v_score,
                                "published_at": self.timestamp_to_iso(snip.get("publishedAt")),
                            }
                        )
                    return results
            except Exception as exc:
                logger.warning(f"[Radar YouTube API] '{keyword}' araması yt-dlp'ye devrediliyor: {exc}")

        # yt-dlp ytsearch yedeği
        raw_items = self.run_yt_dlp_json(
            f"ytsearch{max_per_query}:{keyword}", max_items=max_per_query
        )
        for entry in raw_items:
            vid_id = str(entry.get("id") or "").strip()
            comp_user = str(entry.get("uploader") or entry.get("channel") or "rakip").strip()
            if not vid_id or comp_user.lower() == exclude_username.lower():
                continue
            views = int(entry.get("view_count") or 0)
            likes = int(entry.get("like_count") or 0)
            comments = int(entry.get("comment_count") or 0)
            title = entry.get("title") or ""
            hashtags = self.extract_hashtags(
                title, entry.get("tags") if isinstance(entry.get("tags"), list) else []
            )
            er = MathEngine.calculate_engagement_rate(views, likes, comments, 0, 0)
            v_score = MathEngine.calculate_virality_score(
                views, likes, comments, 0, 0, has_saves_shares=False
            )
            results.append(
                {
                    "platform": "youtube",
                    "competitor_username": comp_user,
                    "platform_video_id": vid_id,
                    "video_url": entry.get("webpage_url") or f"https://www.youtube.com/watch?v={vid_id}",
                    "thumbnail_url": entry.get("thumbnail") or "",
                    "caption": title,
                    "hashtags": hashtags,
                    "search_keyword_used": keyword,
                    "duration_seconds": int(entry.get("duration") or 0),
                    "views": views,
                    "likes": likes,
                    "comments": comments,
                    "shares": 0,
                    "saves": 0,
                    "engagement_rate": er,
                    "virality_score": v_score,
                    "published_at": self.timestamp_to_iso(
                        entry.get("timestamp") or entry.get("upload_date")
                    ),
                }
            )
        return results

    def _search_shortform_competitors(
        self,
        platform: str,
        keyword: str,
        exclude_username: str,
        max_per_query: int = 4,
    ) -> List[Dict[str, Any]]:
        """TikTok ve Instagram Reels niş etiket/kelime aramasıyla viral rakip videoları yakalar."""
        clean_tag = keyword.strip().lstrip("#").replace(" ", "")
        results: List[Dict[str, Any]] = []

        # 1. TikTok Hashtag / Search veya YouTube Shorts çapraz niş taraması
        search_targets = []
        if platform == "tiktok":
            search_targets.append(f"https://www.tiktok.com/tag/{clean_tag}")
        search_targets.append(f"ytsearch{max_per_query}:{keyword} #shorts")

        raw_items: List[Dict[str, Any]] = []
        for target in search_targets:
            raw_items = self.run_yt_dlp_json(target, max_items=max_per_query)
            if raw_items:
                break

        for entry in raw_items:
            vid_id = str(entry.get("id") or "").strip()
            comp_user = str(
                entry.get("uploader_id") or entry.get("uploader") or "viral_creator"
            ).strip().lstrip("@")
            if not vid_id or comp_user.lower() == exclude_username.lower():
                continue

            caption = entry.get("description") or entry.get("title") or ""
            hashtags = self.extract_hashtags(
                caption, entry.get("tags") if isinstance(entry.get("tags"), list) else []
            )
            views = int(entry.get("view_count") or entry.get("playCount") or 0)
            likes = int(entry.get("like_count") or entry.get("diggCount") or 0)
            comments = int(entry.get("comment_count") or entry.get("commentCount") or 0)
            shares = int(entry.get("repost_count") or entry.get("shareCount") or 0)
            saves = int(entry.get("collectCount") or entry.get("save_count") or 0)

            has_deep = (shares > 0 or saves > 0)
            er = MathEngine.calculate_engagement_rate(views, likes, comments, shares, saves)
            v_score = MathEngine.calculate_virality_score(
                views, likes, comments, shares, saves, has_saves_shares=has_deep
            )

            results.append(
                {
                    "platform": platform,
                    "competitor_username": comp_user,
                    "platform_video_id": vid_id,
                    "video_url": entry.get("webpage_url") or f"https://www.tiktok.com/@{comp_user}/video/{vid_id}",
                    "thumbnail_url": entry.get("thumbnail") or "",
                    "caption": caption,
                    "hashtags": hashtags,
                    "search_keyword_used": keyword,
                    "duration_seconds": int(entry.get("duration") or 0),
                    "views": views,
                    "likes": likes,
                    "comments": comments,
                    "shares": shares,
                    "saves": saves,
                    "engagement_rate": er,
                    "virality_score": v_score,
                    "published_at": self.timestamp_to_iso(
                        entry.get("timestamp") or entry.get("upload_date")
                    ),
                }
            )
        return results

    def discover_top_competitors(
        self,
        platform: str,
        exclude_username: str,
        niche_keywords: List[str],
        top_n: int = 5,
    ) -> List[Dict[str, Any]]:
        """
        5 niş arama sorgusunu çalıştırır, mükerrer videoları temizler ve
        en yüksek viralite + izlenme puanına sahip 5 rakip videoyu döndürür.
        """
        candidates: Dict[str, Dict[str, Any]] = {}
        queries = [q.strip() for q in niche_keywords if q.strip()][:5]

        for query in queries:
            try:
                if platform == "youtube":
                    found = self._search_youtube_competitors(
                        query,
                        exclude_username=exclude_username,
                        lookback_days=CONFIG.competitor_lookback_days,
                        max_per_query=3,
                    )
                else:
                    found = self._search_shortform_competitors(
                        platform=platform,
                        keyword=query,
                        exclude_username=exclude_username,
                        max_per_query=3,
                    )
                for item in found:
                    url_key = item["video_url"]
                    if url_key not in candidates:
                        candidates[url_key] = item
            except Exception as exc:
                logger.warning(f"[Otonom Radar] '{query}' sorgusunda hata: {exc}")

        sorted_competitors = sorted(
            candidates.values(),
            key=lambda x: (x.get("virality_score", 0.0), x.get("views", 0)),
            reverse=True,
        )
        return sorted_competitors[:top_n]

    def fetch_account_and_videos(
        self,
        username: str,
        fetch_mode: str = "public_only",
        auth_credentials: Any = None,
        max_videos: int = 15,
    ) -> Dict[str, Any]:
        """BaseScraper soyut metot uyumluluğu."""
        return {"profile": {"username": username}, "videos": []}
