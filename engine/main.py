"""
OmniPulse AI — Ana Bulut Orkestrasyon Motoru (engine/main.py)
v2.0 Ultra Hızlı Paralel Sürüm:
1. Tekil veya çoklu hesapları ThreadPoolExecutor ile paralel olarak tarar.
2. Her hesabın veri çekme + matematik + otonom rakip + Gemini 2.5 Flash analizi ~8-15 saniye içinde biter.
"""

from concurrent.futures import ThreadPoolExecutor, as_completed
import logging
import sys
import threading
import traceback
from typing import Any, Dict, List

from ai_strategist.gemini_service import GeminiStrategistService
from analytics.hashtag_analyzer import HashtagAnalyzer
from analytics.math_engine import MathEngine
from config import CONFIG
from db_client import SupabaseDBClient
from scrapers.autonomous_radar import AutonomousCompetitorRadar
from scrapers.instagram_scraper import InstagramScraper
from scrapers.tiktok_scraper import TikTokScraper
from scrapers.youtube_scraper import YouTubeScraper

logger = logging.getLogger("omnipulse.main")


class OmniPulseOrchestrator:
    """Bulut veri çekme, matematik motoru ve otonom AI stratejistini paralel yöneten ana sınıf."""

    def __init__(self) -> None:
        CONFIG.validate()
        self.db = SupabaseDBClient()
        self.ai_service = GeminiStrategistService()
        self.radar = AutonomousCompetitorRadar()
        self._progress_lock = threading.Lock()

    def _get_scraper_for_platform(self, platform: str):
        if platform == "tiktok":
            return TikTokScraper()
        if platform == "youtube":
            return YouTubeScraper()
        if platform == "instagram":
            return InstagramScraper()
        raise ValueError(f"Desteklenmeyen platform: {platform}")

    def process_single_account(self, account: Dict[str, Any]) -> Dict[str, Any]:
        """Tek bir hesabı uçtan uca (~8-12 sn içinde) tarar ve analizlerini kaydeder."""
        account_id = str(account["id"])
        platform = str(account["platform"]).lower().strip()
        username = str(account["username"]).strip().lstrip("@")
        fetch_mode = str(account.get("fetch_mode") or "public_only")
        auth_credentials = account.get("auth_credentials") or {}
        category_tag = str(account.get("category_tag") or "Genel")

        scraper = self._get_scraper_for_platform(platform)
        logger.info(f"==> [{platform.upper()}] @{username} hızlı analiz başladı (Mod: {fetch_mode})...")

        # 1. Platformdan Profil ve Son Videoları Hızlı Modda Çek
        scraped_bundle = scraper.fetch_account_and_videos(
            username=username,
            fetch_mode=fetch_mode,
            auth_credentials=auth_credentials,
            max_videos=CONFIG.max_videos_per_account,
        )
        profile_data = scraped_bundle.get("profile", {})
        raw_videos = scraped_bundle.get("videos", [])

        # 2. Mevcut Videoları ve Geçmiş Snapshot'ları Çek
        existing_videos_map = self.db.get_existing_videos_for_account(account_id)
        historical_snapshots = self.db.get_account_snapshots_since(account_id, days_back=35)

        # 3. Matematiksel Analiz Motorunu Çalıştır
        has_saves_shares = bool(profile_data.get("has_saves_shares_data", platform == "tiktok"))
        math_summary = MathEngine.enrich_account_videos(
            raw_videos=raw_videos,
            existing_videos_map=existing_videos_map,
            has_saves_shares=has_saves_shares,
        )
        enriched_videos = math_summary["videos"]
        median_views = math_summary["median_views"]
        avg_er = math_summary["avg_engagement_rate"]
        avg_virality = math_summary["avg_virality_score"]
        latest_multiplier = math_summary["latest_video_multiplier"]
        optimal_best_hour = math_summary["optimal_best_hour"]

        current_followers = int(
            profile_data.get("followers_count") or account.get("current_followers") or 0
        )
        current_total_views = int(
            profile_data.get("total_views")
            or sum(v["views"] for v in enriched_videos)
            or account.get("current_total_views")
            or 0
        )
        current_video_count = int(
            profile_data.get("video_count") or len(enriched_videos)
        )

        # 4. 24s / 7g / 30g Büyüme Yüzdelerini ve Sağlık Durumunu Hesapla
        growth_metrics = MathEngine.compute_multi_window_growth(
            current_followers=current_followers,
            current_total_views=current_total_views,
            historical_snapshots=historical_snapshots,
        )
        health_status = MathEngine.determine_account_health_status(
            follower_growth_7d=growth_metrics["follower_growth_7d"],
            views_growth_7d=growth_metrics["views_growth_7d"],
            latest_video_multiplier=latest_multiplier,
        )

        # 5. Hashtag Performans ve Lift Çarpanı Matrisini Hesapla
        hashtag_records = HashtagAnalyzer.analyze_account_hashtags(
            enriched_videos=enriched_videos,
            channel_median_views=median_views,
        )
        self.db.upsert_hashtag_analytics(account_id, hashtag_records)

        # 6. Niş Kelimelerini Hazırla (Mevcut niş varsa ek LLM çağrısını atlayarak 4 saniye kazan,
        # derin strateji çağrısı zaten güncel niş ve kelimeleri tek seferde üretiyor!)
        existing_niche = str(account.get("detected_niche") or "").strip()
        existing_keywords = account.get("niche_search_keywords") or []
        if (
            existing_niche
            and existing_niche != "Otonom Niş Analiz Ediliyor"
            and isinstance(existing_keywords, list)
            and len(existing_keywords) >= 3
        ):
            detected_niche = existing_niche
            niche_keywords = [str(k) for k in existing_keywords[:5]]
        else:
            niche_info = self.ai_service.detect_niche_and_keywords(
                platform=platform,
                username=username,
                category_tag=category_tag,
                recent_videos=enriched_videos,
            )
            detected_niche = niche_info["detected_niche"]
            niche_keywords = niche_info["niche_search_keywords"]

        # 7. Otonom Rakip Keşif Radarı (5 sorgu paralel ~3 saniye)
        discovered_competitors = self.radar.discover_top_competitors(
            platform=platform,
            exclude_username=username,
            niche_keywords=niche_keywords,
            top_n=CONFIG.competitor_videos_per_account,
        )
        self.db.replace_autonomous_competitors(account_id, discovered_competitors)

        # 8. Gemini 2.5 Flash Derin Kök Neden Analizi, Rakip Kıyaslama ve 5 Video Planı (Tek Birleşik Çağrı)
        account_context = {
            **account,
            "current_followers": current_followers,
            "current_median_views": median_views,
            "current_engagement_rate": avg_er,
            "optimal_best_hour": optimal_best_hour,
        }
        ai_strategy = self.ai_service.generate_deep_account_strategy(
            account_info=account_context,
            enriched_videos=enriched_videos,
            hashtag_matrix=hashtag_records,
            competitor_videos=discovered_competitors,
            detected_niche=detected_niche,
            niche_keywords=niche_keywords,
        )

        root_cause_map = {
            str(item.get("platform_video_id")): item
            for item in ai_strategy.get("video_root_cause_analyses", [])
            if item.get("platform_video_id")
        }
        for v in enriched_videos:
            vid_id = str(v["platform_video_id"])
            if vid_id in root_cause_map:
                v["ai_root_cause_analysis"] = root_cause_map[vid_id]

        # 9. Videoları, Video Snapshot'larını ve Rakip AI Değerlendirmelerini Kaydet
        self.db.upsert_videos_and_snapshots(account_id, enriched_videos)
        if ai_strategy.get("competitor_evaluations"):
            self.db.update_competitor_ai_evaluations(
                account_id, ai_strategy["competitor_evaluations"]
            )

        # 10. Hesap Özeti ve Hesap Zaman Serisi Snapshot'ını Kaydet
        self.db.insert_account_snapshot(
            account_id=account_id,
            followers_count=current_followers,
            total_views=current_total_views,
            video_count=current_video_count,
            median_views=median_views,
            avg_engagement_rate=avg_er,
            avg_virality_score=avg_virality,
        )

        updated_account_fields = {
            "display_name": profile_data.get("display_name") or account.get("display_name") or username,
            "avatar_url": profile_data.get("avatar_url") or account.get("avatar_url") or "",
            "bio_text": profile_data.get("bio_text") or account.get("bio_text") or "",
            "detected_niche": ai_strategy.get("detected_niche") or detected_niche,
            "niche_search_keywords": ai_strategy.get("niche_search_keywords") or niche_keywords,
            "current_followers": current_followers,
            "current_following": int(profile_data.get("following_count") or 0),
            "current_total_views": current_total_views,
            "current_video_count": current_video_count,
            "current_median_views": median_views,
            "current_engagement_rate": avg_er,
            "current_virality_score": avg_virality,
            "latest_video_multiplier": latest_multiplier,
            "follower_growth_24h": growth_metrics["follower_growth_24h"],
            "follower_growth_7d": growth_metrics["follower_growth_7d"],
            "follower_growth_30d": growth_metrics["follower_growth_30d"],
            "views_growth_24h": growth_metrics["views_growth_24h"],
            "views_growth_7d": growth_metrics["views_growth_7d"],
            "views_growth_30d": growth_metrics["views_growth_30d"],
            "optimal_best_hour": optimal_best_hour,
            "health_status": health_status,
            "last_sync_error": None,
        }
        updated_account = self.db.update_account_metrics(account_id, updated_account_fields)

        # 11. Hesap Bazlı AI Strateji Raporunu Kaydet
        self.db.insert_ai_strategy_report(
            account_id=account_id,
            report_type="account_deep_strategy",
            executive_summary=ai_strategy.get("executive_summary", ""),
            competitor_gap_summary=ai_strategy.get("competitor_gap_summary", ""),
            optimal_posting_windows=ai_strategy.get("optimal_posting_windows", []),
            recommended_hashtags=ai_strategy.get("hashtag_recommendations", {}),
            next_5_video_blueprints=ai_strategy.get("next_5_video_blueprints", []),
            raw_ai_payload=ai_strategy,
        )

        return updated_account or {**account, **updated_account_fields}

    def run(self) -> None:
        """Tüm aktif hesapları paralel iş parçacıklarıyla (ThreadPoolExecutor) hızla tarar."""
        target_id = CONFIG.target_account_id or None
        accounts = self.db.get_active_accounts(target_account_id=target_id)
        total_accounts = len(accounts)

        job_id = self.db.start_or_attach_sync_job(
            total_accounts=total_accounts,
            triggered_by=CONFIG.triggered_by,
            target_account_id=target_id,
            existing_job_id=CONFIG.sync_job_id or None,
        )

        if total_accounts == 0:
            msg = "Taranacak aktif hesap bulunamadı. Uygulamadan hesap ekleyebilirsiniz."
            logger.info(msg)
            self.db.complete_sync_job(job_id, 0, 0, 0, msg, is_failed=False)
            return

        processed_count = 0
        failed_count = 0
        updated_portfolio_summaries: List[Dict[str, Any]] = []

        max_workers = min(total_accounts, CONFIG.max_parallel_accounts)
        logger.info(
            f"Paralel Bulut Motoru başlatıldı: {total_accounts} hesap, {max_workers} eşzamanlı işçi."
        )

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            future_to_acc = {
                executor.submit(self.process_single_account, acc): acc for acc in accounts
            }

            for future in as_completed(future_to_acc):
                account = future_to_acc[future]
                acc_label = f"@{account.get('username')} ({account.get('platform')})"

                with self._progress_lock:
                    try:
                        updated_acc = future.result()
                        processed_count += 1
                        updated_portfolio_summaries.append(
                            {
                                "platform": updated_acc.get("platform"),
                                "username": updated_acc.get("username"),
                                "current_followers": updated_acc.get("current_followers"),
                                "current_total_views": updated_acc.get("current_total_views"),
                                "current_engagement_rate": updated_acc.get("current_engagement_rate"),
                                "follower_growth_7d": updated_acc.get("follower_growth_7d"),
                                "latest_video_multiplier": updated_acc.get("latest_video_multiplier"),
                                "health_status": updated_acc.get("health_status"),
                            }
                        )
                        done_so_far = processed_count + failed_count
                        pct = int(round((done_so_far / total_accounts) * 100))
                        self.db.update_sync_job_progress(
                            job_id=job_id,
                            processed_accounts=processed_count,
                            total_accounts=total_accounts,
                            current_account_name=acc_label,
                            status_message=f"Hızlı Bulut Motoru: {acc_label} tamamlandı ({done_so_far}/{total_accounts}) - %{pct}",
                            failed_accounts=failed_count,
                        )
                    except Exception as exc:
                        failed_count += 1
                        done_so_far = processed_count + failed_count
                        err_str = f"{type(exc).__name__}: {exc}"
                        logger.error(f"[İzolasyon Koruması] {acc_label} hatası: {err_str}")
                        logger.debug(traceback.format_exc())
                        self.db.record_account_sync_error(str(account["id"]), err_str)
                        self.db.update_sync_job_progress(
                            job_id=job_id,
                            processed_accounts=processed_count,
                            total_accounts=total_accounts,
                            current_account_name=acc_label,
                            status_message=f"{acc_label} atlandı ({done_so_far}/{total_accounts})",
                            failed_accounts=failed_count,
                            error_entry={
                                "account_id": str(account["id"]),
                                "username": account.get("username"),
                                "error": err_str,
                            },
                        )

        if updated_portfolio_summaries:
            master_brief = self.ai_service.generate_portfolio_master_briefing(
                updated_portfolio_summaries
            )
            self.db.insert_ai_strategy_report(
                account_id=None,
                report_type="master_briefing",
                executive_summary=master_brief,
            )

        final_msg = (
            f"Hızlı senkronizasyon tamamlandı: {processed_count}/{total_accounts} hesap başarıyla analiz edildi"
            + (f" ({failed_count} hesapta uyarı)." if failed_count > 0 else ".")
        )
        self.db.complete_sync_job(
            job_id=job_id,
            processed_accounts=processed_count,
            total_accounts=total_accounts,
            failed_accounts=failed_count,
            final_message=final_msg,
            is_failed=(processed_count == 0 and failed_count > 0),
        )
        logger.info(final_msg)


if __name__ == "__main__":
    try:
        orchestrator = OmniPulseOrchestrator()
        orchestrator.run()
    except Exception as fatal_exc:
        logger.critical(f"Kritik sistem hatası: {fatal_exc}", exc_info=True)
        sys.exit(1)
