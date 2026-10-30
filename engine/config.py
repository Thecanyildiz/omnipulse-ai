"""
OmniPulse AI — Bulut Motoru Yapılandırma ve Sabitler Modülü (engine/config.py)
Ortam değişkenleri, anti-ban bekleme süreleri, algoritma ağırlıkları ve sabitler.
"""

import os
import random
import time
import logging
from dataclasses import dataclass, field
from typing import List
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(name)-22s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("omnipulse.config")


USER_AGENTS: List[str] = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Linux; Android 15; Pixel 9 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.6778.81 Mobile Safari/537.36",
]


@dataclass(frozen=True)
class EngineConfig:
    """Bulut motorunun çalışma zamanı ayarlarını ve sabitlerini tutan veri sınıfı."""

    # Supabase Bağlantı Bilgileri
    supabase_url: str = field(default_factory=lambda: os.getenv("SUPABASE_URL", "").strip())
    supabase_key: str = field(
        default_factory=lambda: (
            os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
            or os.getenv("SUPABASE_KEY", "").strip()
        )
    )

    # Yapay Zeka ve Platform Anahtarları
    gemini_api_key: str = field(default_factory=lambda: os.getenv("GEMINI_API_KEY", "").strip())
    gemini_model_name: str = field(
        default_factory=lambda: os.getenv("GEMINI_MODEL_NAME", "gemini-3.8-flash").strip()
    )
    youtube_api_key: str = field(default_factory=lambda: os.getenv("YOUTUBE_API_KEY", "").strip())

    # Çalıştırma Bağlamı (GitHub Actions / Mobil Tetikleme)
    triggered_by: str = field(
        default_factory=lambda: os.getenv("TRIGGERED_BY", "mobile_app").strip() or "mobile_app"
    )
    target_account_id: str = field(
        default_factory=lambda: os.getenv("TARGET_ACCOUNT_ID", "").strip()
    )
    sync_job_id: str = field(default_factory=lambda: os.getenv("SYNC_JOB_ID", "").strip())

    # Anti-Ban (Engel Önleme) ve Tarama Limitleri
    min_jitter_seconds: float = 4.5
    max_jitter_seconds: float = 11.0
    max_videos_per_account: int = 15
    niche_detection_sample_size: int = 12
    competitor_videos_per_account: int = 5
    competitor_lookback_days: int = 14
    http_timeout_seconds: int = 25
    max_retries_per_request: int = 3

    # Matematiksel Eşik Değerleri
    tier_viral_hit_threshold: float = 2.5
    tier_above_avg_threshold: float = 1.3
    tier_normal_threshold: float = 0.7
    tier_underperforming_threshold: float = 0.35

    hashtag_booster_threshold: float = 1.35
    hashtag_neutral_threshold: float = 0.75

    def validate(self) -> None:
        """Zorunlu ortam değişkenlerinin eksiksiz olduğunu doğrular."""
        missing = []
        if not self.supabase_url:
            missing.append("SUPABASE_URL")
        if not self.supabase_key:
            missing.append("SUPABASE_KEY (veya SUPABASE_SERVICE_ROLE_KEY)")
        if not self.gemini_api_key:
            missing.append("GEMINI_API_KEY")
        if missing:
            raise EnvironmentError(
                f"Kritik ortam değişkenleri eksik: {', '.join(missing)}. "
                "Lütfen GitHub Secrets veya .env dosyanızı kontrol edin."
            )

    def apply_anti_ban_jitter(self, context_label: str = "account_scan") -> float:
        """Ardışık hesap veya platform istekleri arasında rastgele (4.5 - 11.0 sn) bekleme uygular."""
        sleep_duration = round(
            random.uniform(self.min_jitter_seconds, self.max_jitter_seconds), 2
        )
        logger.info(
            f"[Anti-Ban Jitter] '{context_label}' sonrası {sleep_duration} saniye bekleniyor..."
        )
        time.sleep(sleep_duration)
        return sleep_duration

    @staticmethod
    def get_random_user_agent() -> str:
        """Her HTTP / yt-dlp çağrısı için rastgele güncel bir User-Agent döndürür."""
        return random.choice(USER_AGENTS)


CONFIG = EngineConfig()
