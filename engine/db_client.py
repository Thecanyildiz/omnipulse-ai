"""
OmniPulse AI — Supabase Veritabanı İstemcisi ve Canlı İlerleme Yöneticisi (engine/db_client.py)
Tüm CRUD işlemlerini, zaman serisi snapshot kayıtlarını ve sync_jobs Realtime güncellemelerini yönetir.
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional
from supabase import Client, create_client

from config import CONFIG

logger = logging.getLogger("omnipulse.db_client")


class SupabaseDBClient:
    """Supabase PostgreSQL tabloları ile iletişim kuran üretim sınıfı."""

    def __init__(self, supabase_url: Optional[str] = None, supabase_key: Optional[str] = None) -> None:
        url = supabase_url or CONFIG.supabase_url
        key = supabase_key or CONFIG.supabase_key
        if not url or not key:
            raise ValueError("Supabase URL ve Key değerleri boş olamaz.")
        self.client: Client = create_client(url, key)

    # =========================================================================
    # 1. CANLI SENKRONİZASYON İŞ TAKİBİ (sync_jobs)
    # =========================================================================
    def start_or_attach_sync_job(
        self,
        total_accounts: int,
        triggered_by: str = "mobile_app",
        target_account_id: Optional[str] = None,
        existing_job_id: Optional[str] = None,
    ) -> str:
        """Yeni bir sync_jobs kaydı açar veya mobil uygulamanın oluşturduğu kayda bağlanır."""
        now_iso = datetime.now(timezone.utc).isoformat()
        payload: Dict[str, Any] = {
            "status": "running",
            "triggered_by": triggered_by if triggered_by in ("mobile_app", "desktop_app", "cron_schedule", "manual_cli") else "mobile_app",
            "total_accounts": total_accounts,
            "processed_accounts": 0,
            "failed_accounts": 0,
            "current_account_name": "Hazırlanıyor...",
            "status_message": f"Bulut motoru başlatıldı ({total_accounts} hesap sırada).",
            "started_at": now_iso,
        }
        if target_account_id:
            payload["target_account_id"] = target_account_id

        if existing_job_id:
            res = (
                self.client.table("sync_jobs")
                .update(payload)
                .eq("id", existing_job_id)
                .execute()
            )
            if res.data:
                logger.info(f"Mevcut sync_job kaydına bağlanıldı: {existing_job_id}")
                return existing_job_id

        res = self.client.table("sync_jobs").insert(payload).execute()
        job_id = res.data[0]["id"]
        logger.info(f"Yeni sync_job oluşturuldu: {job_id}")
        return job_id

    def update_sync_job_progress(
        self,
        job_id: str,
        processed_accounts: int,
        total_accounts: int,
        current_account_name: str,
        status_message: str,
        failed_accounts: int = 0,
        error_entry: Optional[Dict[str, Any]] = None,
    ) -> None:
        """Telefon ekranındaki ilerleme çubuğunu Supabase Realtime üzerinden anlık günceller."""
        update_data: Dict[str, Any] = {
            "status": "running",
            "processed_accounts": processed_accounts,
            "total_accounts": total_accounts,
            "failed_accounts": failed_accounts,
            "current_account_name": current_account_name,
            "status_message": status_message,
        }

        if error_entry is not None:
            existing = (
                self.client.table("sync_jobs")
                .select("error_log")
                .eq("id", job_id)
                .limit(1)
                .execute()
            )
            current_errors: List[Dict[str, Any]] = []
            if existing.data and isinstance(existing.data[0].get("error_log"), list):
                current_errors = existing.data[0]["error_log"]
            current_errors.append(error_entry)
            update_data["error_log"] = current_errors

        self.client.table("sync_jobs").update(update_data).eq("id", job_id).execute()

    def complete_sync_job(
        self,
        job_id: str,
        processed_accounts: int,
        total_accounts: int,
        failed_accounts: int,
        final_message: str,
        is_failed: bool = False,
    ) -> None:
        """Senkronizasyon işini tamamlandı veya başarısız olarak kapatır."""
        now_iso = datetime.now(timezone.utc).isoformat()
        self.client.table("sync_jobs").update(
            {
                "status": "failed" if is_failed else "completed",
                "processed_accounts": processed_accounts,
                "total_accounts": total_accounts,
                "failed_accounts": failed_accounts,
                "current_account_name": "Tamamlandı",
                "status_message": final_message,
                "completed_at": now_iso,
            }
        ).eq("id", job_id).execute()

    # =========================================================================
    # 2. HESAPLAR VE TARİHSEL SNAPSHOT İŞLEMLERİ (accounts & account_snapshots)
    # =========================================================================
    def get_active_accounts(self, target_account_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """Aktif hesapları (veya tek bir hedef hesabı) getirir."""
        query = self.client.table("accounts").select("*").eq("is_active", True)
        if target_account_id:
            query = query.eq("id", target_account_id)
        res = query.order("created_at", desc=False).execute()
        return res.data or []

    def get_account_snapshots_since(
        self, account_id: str, days_back: int = 35
    ) -> List[Dict[str, Any]]:
        """Büyüme yüzdesi hesaplamaları için son N günün snapshot kayıtlarını döner."""
        cutoff = (datetime.now(timezone.utc) - timedelta(days=days_back)).isoformat()
        res = (
            self.client.table("account_snapshots")
            .select("*")
            .eq("account_id", account_id)
            .gte("recorded_at", cutoff)
            .order("recorded_at", desc=True)
            .execute()
        )
        return res.data or []

    def insert_account_snapshot(
        self,
        account_id: str,
        followers_count: int,
        total_views: int,
        video_count: int,
        median_views: int,
        avg_engagement_rate: float,
        avg_virality_score: float,
    ) -> Dict[str, Any]:
        """Hesabın o anki metriklerini zaman serisi tablosuna kaydeder."""
        payload = {
            "account_id": account_id,
            "followers_count": int(followers_count),
            "total_views": int(total_views),
            "video_count": int(video_count),
            "median_views": int(median_views),
            "avg_engagement_rate": float(avg_engagement_rate),
            "avg_virality_score": float(avg_virality_score),
            "recorded_at": datetime.now(timezone.utc).isoformat(),
        }
        res = self.client.table("account_snapshots").insert(payload).execute()
        return res.data[0] if res.data else payload

    def update_account_metrics(
        self, account_id: str, update_fields: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Hesabın güncel özet metriklerini, niş bilgisini ve sağlık durumunu günceller."""
        update_fields["last_synced_at"] = datetime.now(timezone.utc).isoformat()
        res = (
            self.client.table("accounts")
            .update(update_fields)
            .eq("id", account_id)
            .execute()
        )
        return res.data[0] if res.data else {}

    def record_account_sync_error(self, account_id: str, error_msg: str) -> None:
        """Bir hesapta hata oluştuğunda diğer hesapları durdurmadan hatayı hesaba yazar."""
        self.client.table("accounts").update(
            {
                "last_sync_error": error_msg[:1000],
                "last_synced_at": datetime.now(timezone.utc).isoformat(),
            }
        ).eq("id", account_id).execute()

    # =========================================================================
    # 3. VİDEOLAR VE VİDEO İVME TAKİBİ (videos & video_snapshots)
    # =========================================================================
    def get_existing_videos_for_account(
        self, account_id: str
    ) -> Dict[str, Dict[str, Any]]:
        """Saatlik izlenme hızı (velocity) hesabı için mevcut videoları platform_video_id ile eşler."""
        res = (
            self.client.table("videos")
            .select("*")
            .eq("account_id", account_id)
            .execute()
        )
        rows = res.data or []
        return {str(row["platform_video_id"]): row for row in rows}

    def upsert_videos_and_snapshots(
        self, account_id: str, enriched_videos: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Hesaplanan video verilerini videos tablosuna upsert eder ve video_snapshots kaydı ekler."""
        if not enriched_videos:
            return []

        now_iso = datetime.now(timezone.utc).isoformat()
        upsert_rows: List[Dict[str, Any]] = []

        for v in enriched_videos:
            row = {
                "account_id": account_id,
                "platform_video_id": str(v["platform_video_id"]),
                "video_url": v["video_url"],
                "thumbnail_url": v.get("thumbnail_url") or "",
                "title_or_caption": v.get("title_or_caption") or "",
                "hashtags": v.get("hashtags") or [],
                "duration_seconds": int(v.get("duration_seconds") or 0),
                "published_at": v.get("published_at") or now_iso,
                "views": int(v.get("views") or 0),
                "likes": int(v.get("likes") or 0),
                "comments": int(v.get("comments") or 0),
                "shares": int(v.get("shares") or 0),
                "saves": int(v.get("saves") or 0),
                "avg_watch_percentage": float(v.get("avg_watch_percentage") or 0.0),
                "traffic_source_summary": v.get("traffic_source_summary") or {},
                "engagement_rate": float(v.get("engagement_rate") or 0.0),
                "virality_score": float(v.get("virality_score") or 0.0),
                "performance_multiplier": float(v.get("performance_multiplier") or 1.0),
                "views_velocity_per_hour": float(v.get("views_velocity_per_hour") or 0.0),
                "performance_tier": v.get("performance_tier") or "normal",
                "ai_root_cause_analysis": v.get("ai_root_cause_analysis") or {},
                "last_updated_at": now_iso,
            }
            upsert_rows.append(row)

        res = (
            self.client.table("videos")
            .upsert(upsert_rows, on_conflict="account_id,platform_video_id")
            .execute()
        )
        saved_videos = res.data or []

        snapshot_rows: List[Dict[str, Any]] = []
        for sv in saved_videos:
            snapshot_rows.append(
                {
                    "video_id": sv["id"],
                    "views": int(sv.get("views") or 0),
                    "likes": int(sv.get("likes") or 0),
                    "comments": int(sv.get("comments") or 0),
                    "shares": int(sv.get("shares") or 0),
                    "saves": int(sv.get("saves") or 0),
                    "recorded_at": now_iso,
                }
            )

        if snapshot_rows:
            self.client.table("video_snapshots").insert(snapshot_rows).execute()

        return saved_videos

    def update_video_root_cause_analyses(
        self, account_id: str, root_cause_list: List[Dict[str, Any]]
    ) -> None:
        """Gemini tarafından üretilen 'Neden İzlendi / Neden İzlenmedi' analizlerini ilgili videolara yazar."""
        for item in root_cause_list:
            platform_vid_id = str(item.get("platform_video_id") or "").strip()
            if not platform_vid_id:
                continue
            self.client.table("videos").update(
                {
                    "ai_root_cause_analysis": item,
                    "last_updated_at": datetime.now(timezone.utc).isoformat(),
                }
            ).eq("account_id", account_id).eq("platform_video_id", platform_vid_id).execute()

    # =========================================================================
    # 4. HASHTAG MATRİSİ VE OTONOM RAKİPLER (hashtag_analytics & autonomous_competitors)
    # =========================================================================
    def upsert_hashtag_analytics(
        self, account_id: str, hashtag_records: List[Dict[str, Any]]
    ) -> None:
        """Hesaplanan hashtag performans matrisini veritabanına kaydeder."""
        if not hashtag_records:
            return
        now_iso = datetime.now(timezone.utc).isoformat()
        rows = []
        for h in hashtag_records:
            rows.append(
                {
                    "account_id": account_id,
                    "hashtag": h["hashtag"],
                    "usage_count": int(h["usage_count"]),
                    "avg_views_when_used": int(h["avg_views_when_used"]),
                    "avg_engagement_rate": float(h.get("avg_engagement_rate", 0.0)),
                    "avg_saves_rate": float(h.get("avg_saves_rate", 0.0)),
                    "lift_multiplier": float(h["lift_multiplier"]),
                    "status_category": h["status_category"],
                    "updated_at": now_iso,
                }
            )
        self.client.table("hashtag_analytics").upsert(
            rows, on_conflict="account_id,hashtag"
        ).execute()

    def replace_autonomous_competitors(
        self, target_account_id: str, competitors: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Otonom radarın bulduğu güncel viral rakip videoları kaydeder."""
        if not competitors:
            return []

        now_iso = datetime.now(timezone.utc).isoformat()
        rows = []
        for comp in competitors:
            rows.append(
                {
                    "target_account_id": target_account_id,
                    "platform": comp["platform"],
                    "competitor_username": comp["competitor_username"],
                    "platform_video_id": str(comp.get("platform_video_id") or ""),
                    "video_url": comp["video_url"],
                    "thumbnail_url": comp.get("thumbnail_url") or "",
                    "caption": comp.get("caption") or "",
                    "hashtags": comp.get("hashtags") or [],
                    "search_keyword_used": comp.get("search_keyword_used") or "",
                    "duration_seconds": int(comp.get("duration_seconds") or 0),
                    "views": int(comp.get("views") or 0),
                    "likes": int(comp.get("likes") or 0),
                    "comments": int(comp.get("comments") or 0),
                    "shares": int(comp.get("shares") or 0),
                    "saves": int(comp.get("saves") or 0),
                    "engagement_rate": float(comp.get("engagement_rate") or 0.0),
                    "virality_score": float(comp.get("virality_score") or 0.0),
                    "published_at": comp.get("published_at") or now_iso,
                    "ai_why_it_went_viral": comp.get("ai_why_it_went_viral") or "",
                    "ai_how_to_beat_it": comp.get("ai_how_to_beat_it") or "",
                    "discovered_at": now_iso,
                }
            )

        res = (
            self.client.table("autonomous_competitors")
            .upsert(rows, on_conflict="target_account_id,video_url")
            .execute()
        )
        return res.data or []

    def update_competitor_ai_evaluations(
        self, target_account_id: str, evaluations: List[Dict[str, Any]]
    ) -> None:
        """Gemini'nin her rakip video için ürettiği 'Neden Patladı' ve 'Nasıl Geçersin' notlarını yazar."""
        for ev in evaluations:
            comp_user = str(ev.get("competitor_username") or "").strip().lstrip("@")
            if not comp_user:
                continue
            self.client.table("autonomous_competitors").update(
                {
                    "ai_why_it_went_viral": ev.get("why_it_went_viral", ""),
                    "ai_how_to_beat_it": ev.get("how_to_beat_it", ""),
                }
            ).eq("target_account_id", target_account_id).ilike(
                "competitor_username", f"%{comp_user}%"
            ).execute()

    # =========================================================================
    # 5. YAPAY ZEKA STRATEJİ VE FİKİR RAPORLARI (ai_strategy_reports)
    # =========================================================================
    def insert_ai_strategy_report(
        self,
        report_type: str,
        executive_summary: str,
        competitor_gap_summary: str = "",
        optimal_posting_windows: Optional[List[str]] = None,
        recommended_hashtags: Optional[Dict[str, Any]] = None,
        next_5_video_blueprints: Optional[List[Dict[str, Any]]] = None,
        raw_ai_payload: Optional[Dict[str, Any]] = None,
        account_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Hesap bazlı derin strateji raporunu veya 15 hesabın Master Brifing raporunu kaydeder."""
        payload: Dict[str, Any] = {
            "account_id": account_id,
            "report_type": report_type,
            "executive_summary": executive_summary,
            "competitor_gap_summary": competitor_gap_summary,
            "optimal_posting_windows": optimal_posting_windows or [],
            "recommended_hashtags": recommended_hashtags or {},
            "next_5_video_blueprints": next_5_video_blueprints or [],
            "raw_ai_payload": raw_ai_payload or {},
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        res = self.client.table("ai_strategy_reports").insert(payload).execute()
        return res.data[0] if res.data else payload
