"""
OmniPulse AI — Ortak Temel Veri Çekici Sınıfı (engine/scrapers/base_scraper.py)
User-Agent rotasyonu, üstel geri çekilmeli yeniden deneme (Retry), hashtag ayrıştırma ve yt-dlp yardımcılarını içerir.
"""

import json
import logging
import re
import subprocess
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import requests
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from config import CONFIG

logger = logging.getLogger("omnipulse.scrapers.base")

HASHTAG_REGEX = re.compile(r"#([\wğüşıöçĞÜŞİÖÇ0-9_]+)", re.UNICODE)


class BaseScraper(ABC):
    """TikTok, YouTube ve Instagram veri çekicileri için temel soyut sınıf."""

    def __init__(self, platform_name: str) -> None:
        self.platform_name = platform_name
        self.session = requests.Session()

    def get_headers(self, extra_headers: Optional[Dict[str, str]] = None) -> Dict[str, str]:
        """Rastgele User-Agent içeren standart HTTP başlıklarını oluşturur."""
        headers = {
            "User-Agent": CONFIG.get_random_user_agent(),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
            "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
            "Cache-Control": "no-cache",
            "Pragma": "no-cache",
        }
        if extra_headers:
            headers.update(extra_headers)
        return headers

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1.5, min=2, max=10),
        retry=retry_if_exception_type((requests.RequestException, TimeoutError)),
        reraise=True,
    )
    def http_get(
        self,
        url: str,
        params: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None,
        cookies: Optional[Dict[str, str]] = None,
    ) -> requests.Response:
        """Yeniden deneme mekanizmalı güvenli HTTP GET isteği."""
        merged_headers = self.get_headers(headers)
        response = self.session.get(
            url,
            params=params,
            headers=merged_headers,
            cookies=cookies,
            timeout=CONFIG.http_timeout_seconds,
        )
        response.raise_for_status()
        return response

    @staticmethod
    def extract_hashtags(text: Optional[str], extra_tags: Optional[List[str]] = None) -> List[str]:
        """Başlık veya açıklama metninden ve ek etiket listesinden normalize edilmiş #hashtag listesi çıkarır."""
        found: List[str] = []
        if text:
            matches = HASHTAG_REGEX.findall(text)
            for m in matches:
                tag = f"#{m.lower().strip()}"
                if tag not in found and len(tag) > 2:
                    found.append(tag)
        if extra_tags:
            for raw in extra_tags:
                clean = str(raw).strip().lstrip("#").lower()
                if clean:
                    tag = f"#{clean}"
                    if tag not in found and len(tag) > 2:
                        found.append(tag)
        return found

    @staticmethod
    def timestamp_to_iso(ts: Optional[Any]) -> str:
        """Unix epoch saniyesini veya tarih dizgesini UTC ISO-8601 formatına dönüştürür."""
        if ts is None:
            return datetime.now(timezone.utc).isoformat()
        if isinstance(ts, (int, float)) and ts > 0:
            return datetime.fromtimestamp(float(ts), tz=timezone.utc).isoformat()
        ts_str = str(ts).strip()
        if ts_str.isdigit() and len(ts_str) == 8:
            # YYYYMMDD formatı (yt-dlp upload_date)
            try:
                dt = datetime.strptime(ts_str, "%Y%m%d").replace(tzinfo=timezone.utc)
                return dt.isoformat()
            except ValueError:
                return datetime.now(timezone.utc).isoformat()
        try:
            dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
            return dt.isoformat()
        except ValueError:
            return datetime.now(timezone.utc).isoformat()

    def run_yt_dlp_json(
        self,
        target_url: str,
        max_items: int = 15,
        flat_playlist: bool = False,
        cookies_from_header: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """yt-dlp'yi alt süreç olarak çalıştırıp her video için tam JSON çıktısını döndürür."""
        cmd = [
            "yt-dlp",
            "--dump-json",
            "--no-warnings",
            "--ignore-errors",
            "--no-check-certificates",
            "--playlist-end",
            str(max_items),
            "--user-agent",
            CONFIG.get_random_user_agent(),
        ]
        if flat_playlist:
            cmd.append("--flat-playlist")
        if cookies_from_header:
            cmd.extend(["--add-header", f"Cookie:{cookies_from_header}"])
        cmd.append(target_url)

        logger.info(f"[{self.platform_name}] yt-dlp çalıştırılıyor: {target_url} (limit={max_items})")
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=120,
                check=False,
            )
        except subprocess.TimeoutExpired:
            logger.warning(f"[{self.platform_name}] yt-dlp zaman aşımına uğradı: {target_url}")
            return []

        items: List[Dict[str, Any]] = []
        for line in proc.stdout.splitlines():
            line_str = line.strip()
            if not line_str:
                continue
            try:
                items.append(json.loads(line_str))
            except json.JSONDecodeError:
                continue
        return items

    @abstractmethod
    def fetch_account_and_videos(
        self,
        username: str,
        fetch_mode: str = "public_only",
        auth_credentials: Optional[Dict[str, Any]] = None,
        max_videos: int = 15,
    ) -> Dict[str, Any]:
        """
        Her platform kendi Mod A (public_only) ve Mod B (authorized_api) mantığını uygular.
        Dönüş şeması:
        {
            "profile": {
                "username": str,
                "display_name": str,
                "avatar_url": str,
                "bio_text": str,
                "followers_count": int,
                "following_count": int,
                "total_views": int,
                "video_count": int,
                "has_saves_shares_data": bool
            },
            "videos": [
                {
                    "platform_video_id": str,
                    "video_url": str,
                    "thumbnail_url": str,
                    "title_or_caption": str,
                    "hashtags": List[str],
                    "duration_seconds": int,
                    "published_at": str,
                    "views": int,
                    "likes": int,
                    "comments": int,
                    "shares": int,
                    "saves": int,
                    "avg_watch_percentage": float,
                    "traffic_source_summary": dict
                }
            ]
        }
        """
        raise NotImplementedError
