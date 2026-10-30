"""
OmniPulse AI — Ortak Temel Veri Çekici Sınıfı (engine/scrapers/base_scraper.py)
v2.0 Ultra Hızlı Sürüm: --flat-playlist ve --dump-single-json kullanarak 15 videoyu
tek bir HTTP/süreç çağrısında (~2-4 saniye içinde) çeker.
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
        stop=stop_after_attempt(2),
        wait=wait_exponential(multiplier=1.0, min=1, max=4),
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
        """Yeniden deneme mekanizmalı hızlı HTTP GET isteği."""
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
        flat_playlist: bool = True,
        cookies_from_header: Optional[str] = None,
        timeout_sec: Optional[int] = None,
    ) -> List[Dict[str, Any]]:
        """
        yt-dlp'yi --flat-playlist ve --dump-single-json ile çalıştırarak
        tekil video sayfalarına tek tek girmeden tüm listeyi 2-4 saniye içinde döndürür.
        """
        effective_timeout = timeout_sec or CONFIG.yt_dlp_timeout_seconds
        cmd = [
            "yt-dlp",
            "--dump-single-json",
            "--no-warnings",
            "--ignore-errors",
            "--no-check-certificates",
            "--socket-timeout",
            "10",
            "--retries",
            "1",
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

        logger.info(
            f"[{self.platform_name}] Hızlı yt-dlp çağrısı: {target_url} (limit={max_items}, flat={flat_playlist})"
        )
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=effective_timeout,
                check=False,
            )
        except subprocess.TimeoutExpired:
            logger.warning(f"[{self.platform_name}] yt-dlp zaman aşımı ({effective_timeout}s): {target_url}")
            return []

        stdout_str = (proc.stdout or "").strip()
        if not stdout_str:
            return []

        items: List[Dict[str, Any]] = []
        for line in stdout_str.splitlines():
            line_str = line.strip()
            if not line_str:
                continue
            try:
                parsed = json.loads(line_str)
                if isinstance(parsed, dict):
                    if "entries" in parsed and isinstance(parsed["entries"], list):
                        # Üst kanal/profil bilgisini alt öğelere aktar
                        ch_followers = parsed.get("channel_follower_count") or parsed.get("follower_count")
                        uploader_name = parsed.get("uploader") or parsed.get("title")
                        for entry in parsed["entries"]:
                            if isinstance(entry, dict):
                                if ch_followers and not entry.get("channel_follower_count"):
                                    entry["channel_follower_count"] = ch_followers
                                if uploader_name and not entry.get("uploader"):
                                    entry["uploader"] = uploader_name
                                items.append(entry)
                    else:
                        items.append(parsed)
            except json.JSONDecodeError:
                continue
        return items[:max_items]

    @abstractmethod
    def fetch_account_and_videos(
        self,
        username: str,
        fetch_mode: str = "public_only",
        auth_credentials: Optional[Dict[str, Any]] = None,
        max_videos: int = 15,
    ) -> Dict[str, Any]:
        """Her platform kendi Mod A ve Mod B mantığını uygular."""
        raise NotImplementedError
