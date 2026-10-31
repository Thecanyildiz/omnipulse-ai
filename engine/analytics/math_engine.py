"""
OmniPulse AI — Matematiksel ve Algoritmik Analiz Motoru (engine/analytics/math_engine.py)
Standart Etkileşim Oranı, Algoritmik Viralite Skoru (0-100), Kanal Medyan Çarpanı,
Performans Sınıfı, Saatlik İzlenme İvmesi ve 24s/7g/30g Büyüme Yüzdelerini hesaplar.
"""

import statistics
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional


class MathEngine:
    """Sosyal medya videoları ve hesapları için tüm matematiksel formülleri çalıştıran sınıf."""

    # =========================================================================
    # 4.1. Standart Etkileşim Oranı (Engagement Rate - ER)
    # =========================================================================
    @staticmethod
    def calculate_engagement_rate(
        views: int, likes: int, comments: int, shares: int, saves: int
    ) -> float:
        """
        ER = ((Likes + Comments + Shares + Saves) / max(Views, 1)) * 100
        """
        safe_views = max(int(views), 1)
        total_interactions = int(likes) + int(comments) + int(shares) + int(saves)
        er = (total_interactions / safe_views) * 100.0
        return round(er, 2)

    # =========================================================================
    # 4.2. Algoritmik Viralite Skoru (V_score — 0 ile 100 Arası)
    # =========================================================================
    @staticmethod
    def calculate_virality_score(
        views: int,
        likes: int,
        comments: int,
        shares: int,
        saves: int,
        has_saves_shares: bool = True,
        median_views: int = 0,
    ) -> float:
        """
        Algoritmik Viralite Skoru (V_score: 0 - 100):
        Bir videonun 'viral' olması iki ana faktöre dayanır:
        1. Kanal Medyan Çarpanı (M_perf) ve Algoritmik Kırılma (Ağırlık: %65):
           Videonun kanalın olağan taban çizgisini (medyan) kaç kat aştığı.
        2. Etkileşim İvmesi (Ağırlık: %35):
           Beğeni, yorum, paylaşım ve kaydetme yoğunluğu; ancak küçük izlenmelerde
           (3-5 izlenme) oran patlamasını engellemek için Laplace/Bayesian yumuşatması (views + 25) uygulanır.
        """
        int_views = max(0, int(views))
        int_likes = max(0, int(likes))
        int_comments = max(0, int(comments))
        int_shares = max(0, int(shares))
        int_saves = max(0, int(saves))
        safe_median = max(1, int(median_views)) if median_views > 0 else max(1, int_views)

        # 1. Medyan Çarpanı (Multiplier) Skoru (0 - 100)
        if median_views > 0:
            multiplier = int_views / safe_median
            if multiplier < 0.2:
                # 0.2x altı (Örn: 3 izlenme / 116 medyan = 0.03x) -> Flop (0 - 10 puan)
                mult_score = (multiplier / 0.2) * 10.0
            elif multiplier < 0.7:
                # 0.2x - 0.7x arası -> Düşük / İvme Kaybı (10 - 35 puan)
                mult_score = 10.0 + ((multiplier - 0.2) / 0.5) * 25.0
            elif multiplier < 1.3:
                # 0.7x - 1.3x arası -> Dengeli / Kanal Medyanı civarı (35 - 60 puan)
                mult_score = 35.0 + ((multiplier - 0.7) / 0.6) * 25.0
            elif multiplier < 2.5:
                # 1.3x - 2.5x arası -> Güçlü Yükseliş / Keşfete Çıkış (60 - 85 puan)
                mult_score = 60.0 + ((multiplier - 1.3) / 1.2) * 25.0
            elif multiplier < 5.0:
                # 2.5x - 5.0x arası -> Viral Kırılma (85 - 95 puan)
                mult_score = 85.0 + ((multiplier - 2.5) / 2.5) * 10.0
            else:
                # 5.0x ve üzeri -> Süper Viral (95 - 100 puan)
                mult_score = min(100.0, 95.0 + (multiplier - 5.0) * 1.0)
        else:
            # Medyan yoksa (örn. rakip radarı), izlenme hacmi logaritmik skalada hesaplanır
            if int_views <= 10:
                mult_score = (int_views / 10.0) * 15.0
            else:
                # 10 izlenme -> 15 puan, 1.000 izlenme -> 60 puan, 100.000 izlenme -> 95 puan
                mult_score = min(100.0, 15.0 + math.log10(int_views / 10.0) * 20.0)

        # 2. Etkileşim İvmesi Skoru (Küçük sayılarda patlamayı önlemek için +25 payda yumuşatması)
        if has_saves_shares and (int_shares > 0 or int_saves > 0):
            weighted_actions = (
                (int_likes * 1.0)
                + (int_comments * 2.5)
                + (int_shares * 4.5)
                + (int_saves * 5.0)
            )
        else:
            weighted_actions = (int_likes * 1.5) + (int_comments * 4.0)

        # Bayesian / Laplace yumuşatma paydası: küçük izlenmelerde oran 100'e fırlayamaz
        smoothed_views = int_views + 25.0
        smoothed_action_rate = (weighted_actions / smoothed_views) * 100.0
        engagement_score = min(100.0, smoothed_action_rate * 5.0)

        # 3. İzlenme Tabanı Katsayısı: 10 izlenmenin altındaki videolar asla 25 puanı geçemez
        if int_views < 10:
            volume_dampener = max(0.1, int_views / 10.0)
            final_score = (mult_score * 0.70 + engagement_score * 0.30) * volume_dampener
        else:
            final_score = mult_score * 0.70 + engagement_score * 0.30

        return max(0.0, min(100.0, round(final_score, 1)))

    # =========================================================================
    # 4.3. Kanal Medyan Çarpanı (Performance Multiplier - M_perf) & Sınıfı
    # =========================================================================
    @staticmethod
    def calculate_median_views(video_views_list: List[int]) -> int:
        """Son 15 videonun Medyan (Ortanca) izlenmesini hesaplar."""
        if not video_views_list:
            return 0
        sample = [max(0, int(v)) for v in video_views_list[:15]]
        return int(statistics.median(sample))

    @staticmethod
    def calculate_performance_multiplier(video_views: int, median_views: int) -> float:
        """
        M_perf = round(Video Views / max(V_median, 1), 2)
        """
        safe_median = max(int(median_views), 1)
        return round(int(video_views) / safe_median, 2)

    @staticmethod
    def classify_performance_tier(multiplier: float) -> str:
        """
        Performans Sınıfı (performance_tier) Ataması:
        - M_perf >= 2.5: 'viral_hit'
        - 1.3 <= M_perf < 2.5: 'above_average'
        - 0.7 <= M_perf < 1.3: 'normal'
        - 0.35 <= M_perf < 0.7: 'underperforming'
        - M_perf < 0.35: 'flop'
        """
        if multiplier >= 2.5:
            return "viral_hit"
        if multiplier >= 1.3:
            return "above_average"
        if multiplier >= 0.7:
            return "normal"
        if multiplier >= 0.35:
            return "underperforming"
        return "flop"

    # =========================================================================
    # Saatlik İzlenme İvmesi (Views Velocity Per Hour)
    # =========================================================================
    @staticmethod
    def calculate_views_velocity_per_hour(
        current_views: int,
        published_at_iso: Optional[str],
        previous_video_record: Optional[Dict[str, Any]] = None,
    ) -> float:
        """
        Önceki senkronizasyon kaydı varsa iki tarama arasındaki saatlik izlenme farkını,
        yoksa yayınlandığı andan itibaren geçen saat başına ortalama izlenmeyi hesaplar.
        """
        now = datetime.now(timezone.utc)
        if previous_video_record and previous_video_record.get("last_updated_at"):
            try:
                prev_time = datetime.fromisoformat(
                    str(previous_video_record["last_updated_at"]).replace("Z", "+00:00")
                )
                elapsed_hours = max((now - prev_time).total_seconds() / 3600.0, 0.25)
                prev_views = int(previous_video_record.get("views") or 0)
                delta = max(0, int(current_views) - prev_views)
                if delta > 0:
                    return round(delta / elapsed_hours, 2)
            except Exception:
                pass

        if published_at_iso:
            try:
                pub_time = datetime.fromisoformat(
                    str(published_at_iso).replace("Z", "+00:00")
                )
                hours_since_pub = max((now - pub_time).total_seconds() / 3600.0, 1.0)
                return round(int(current_views) / hours_since_pub, 2)
            except Exception:
                pass

        return 0.0

    # =========================================================================
    # 4.4. Büyüme Yüzdeleri (24 Saat / 7 Gün / 30 Gün)
    # =========================================================================
    @staticmethod
    def calculate_growth_percentage(current_value: int, old_value: int) -> float:
        """
        Growth % = round(((F_now - F_old) / max(F_old, 1)) * 100, 2)
        """
        if old_value <= 0:
            return 0.0
        safe_old = max(int(old_value), 1)
        growth = ((int(current_value) - int(old_value)) / safe_old) * 100.0
        return round(growth, 2)

    @classmethod
    def compute_multi_window_growth(
        cls,
        current_followers: int,
        current_total_views: int,
        historical_snapshots: List[Dict[str, Any]],
    ) -> Dict[str, float]:
        """
        account_snapshots tablosundan 24 saat, 7 gün ve 30 gün öncesine en yakın kayıtları
        bularak takipçi ve izlenme büyüme yüzdelerini döndürür.
        """
        now = datetime.now(timezone.utc)
        targets = {
            "24h": now - timedelta(hours=24),
            "7d": now - timedelta(days=7),
            "30d": now - timedelta(days=30),
        }

        parsed_snaps = []
        for s in historical_snapshots:
            try:
                rec_dt = datetime.fromisoformat(
                    str(s["recorded_at"]).replace("Z", "+00:00")
                )
                parsed_snaps.append((rec_dt, s))
            except Exception:
                continue

        result = {
            "follower_growth_24h": 0.0,
            "follower_growth_7d": 0.0,
            "follower_growth_30d": 0.0,
            "views_growth_24h": 0.0,
            "views_growth_7d": 0.0,
            "views_growth_30d": 0.0,
        }

        if not parsed_snaps:
            return result

        for label, target_dt in targets.items():
            # Hedef zamana en yakın geçmiş snapshot'ı seç
            closest_snap = min(
                parsed_snaps,
                key=lambda item: abs((item[0] - target_dt).total_seconds()),
            )[1]

            old_f = int(closest_snap.get("followers_count") or 0)
            old_v = int(closest_snap.get("total_views") or 0)

            result[f"follower_growth_{label}"] = cls.calculate_growth_percentage(
                current_followers, old_f
            )
            result[f"views_growth_{label}"] = cls.calculate_growth_percentage(
                current_total_views, old_v
            )

        return result

    @staticmethod
    def determine_account_health_status(
        follower_growth_7d: float,
        views_growth_7d: float,
        latest_video_multiplier: float,
    ) -> str:
        """Hesabın genel büyüme ve son video çarpanına göre sağlık durumunu belirler."""
        if latest_video_multiplier >= 2.2 or follower_growth_7d >= 8.0 or views_growth_7d >= 20.0:
            return "surging"
        if latest_video_multiplier >= 1.2 or follower_growth_7d >= 1.5 or views_growth_7d >= 5.0:
            return "growing"
        if latest_video_multiplier < 0.35 and views_growth_7d < -10.0:
            return "anomaly_drop"
        if latest_video_multiplier < 0.65 or follower_growth_7d < -1.0:
            return "declining"
        return "stable"

    @classmethod
    def enrich_account_videos(
        cls,
        raw_videos: List[Dict[str, Any]],
        existing_videos_map: Dict[str, Dict[str, Any]],
        has_saves_shares: bool = True,
    ) -> Dict[str, Any]:
        """
        Bir hesabın tüm videoları için ER, Viralite Skoru, Medyan Çarpanı, Velocity ve
        Performans Sınıfını hesaplayarak zenginleştirilmiş video listesini ve hesap özetini döndürür.
        """
        if not raw_videos:
            return {
                "videos": [],
                "median_views": 0,
                "avg_engagement_rate": 0.0,
                "avg_virality_score": 0.0,
                "latest_video_multiplier": 1.0,
                "optimal_best_hour": "19:00 - 21:00",
            }

        views_list = [int(v.get("views") or 0) for v in raw_videos]
        median_views = cls.calculate_median_views(views_list)

        enriched: List[Dict[str, Any]] = []
        hour_buckets: Dict[int, List[int]] = {}

        for v in raw_videos:
            vid_id = str(v["platform_video_id"])
            views = int(v.get("views") or 0)
            likes = int(v.get("likes") or 0)
            comments = int(v.get("comments") or 0)
            shares = int(v.get("shares") or 0)
            saves = int(v.get("saves") or 0)

            er = cls.calculate_engagement_rate(views, likes, comments, shares, saves)
            v_score = cls.calculate_virality_score(
                views,
                likes,
                comments,
                shares,
                saves,
                has_saves_shares=has_saves_shares,
                median_views=median_views,
            )
            multiplier = cls.calculate_performance_multiplier(views, median_views)
            tier = cls.classify_performance_tier(multiplier)

            prev_record = existing_videos_map.get(vid_id)
            velocity = cls.calculate_views_velocity_per_hour(
                views, v.get("published_at"), prev_record
            )

            # Eski AI kök neden analizi varsa koru (yeni analiz üretilene kadar)
            existing_ai = (
                prev_record.get("ai_root_cause_analysis")
                if prev_record and isinstance(prev_record.get("ai_root_cause_analysis"), dict)
                else {}
            )

            try:
                pub_dt = datetime.fromisoformat(
                    str(v.get("published_at")).replace("Z", "+00:00")
                )
                hour_buckets.setdefault(pub_dt.hour, []).append(views)
            except Exception:
                pass

            v_copy = dict(v)
            v_copy.update(
                {
                    "engagement_rate": er,
                    "virality_score": v_score,
                    "performance_multiplier": multiplier,
                    "views_velocity_per_hour": velocity,
                    "performance_tier": tier,
                    "ai_root_cause_analysis": v.get("ai_root_cause_analysis") or existing_ai,
                }
            )
            enriched.append(v_copy)

        avg_er = round(
            sum(item["engagement_rate"] for item in enriched) / len(enriched), 2
        )
        avg_v_score = round(
            sum(item["virality_score"] for item in enriched) / len(enriched), 1
        )
        latest_multiplier = enriched[0]["performance_multiplier"]

        best_hour_str = "19:00 - 21:00"
        if hour_buckets:
            best_h = max(
                hour_buckets.items(), key=lambda kv: sum(kv[1]) / max(len(kv[1]), 1)
            )[0]
            end_h = (best_h + 2) % 24
            best_hour_str = f"{best_h:02d}:00 - {end_h:02d}:00"

        return {
            "videos": enriched,
            "median_views": median_views,
            "avg_engagement_rate": avg_er,
            "avg_virality_score": avg_v_score,
            "latest_video_multiplier": latest_multiplier,
            "optimal_best_hour": best_hour_str,
        }
