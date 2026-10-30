"""
OmniPulse AI — Hashtag Performans ve Kaldıraç Çarpanı Analizörü (engine/analytics/hashtag_analyzer.py)
Her #etiket için kullanıldığı videoların ortalama izlenmesini kanalın medyan izlenmesiyle oranlar:
Lift = V_tag / max(V_median, 1)
- Lift >= 1.35: 'booster' (Yeşil — İzlenmeyi Yükselten Etiket)
- 0.75 <= Lift < 1.35: 'neutral' (Gri — Etkisiz / Nötr Etiket)
- Lift < 0.75: 'drag' (Kırmızı — Keşfeti Düşüren / Yorgun Etiket)
"""

from typing import Any, Dict, List


class HashtagAnalyzer:
    """Videolarda kullanılan etiketlerin kaldıraç çarpanlarını (Lift Multiplier) hesaplar."""

    @staticmethod
    def classify_lift_status(lift_multiplier: float) -> str:
        """
        Lift >= 1.35 -> 'booster'
        0.75 <= Lift < 1.35 -> 'neutral'
        Lift < 0.75 -> 'drag'
        """
        if lift_multiplier >= 1.35:
            return "booster"
        if lift_multiplier >= 0.75:
            return "neutral"
        return "drag"

    @classmethod
    def analyze_account_hashtags(
        cls, enriched_videos: List[Dict[str, Any]], channel_median_views: int
    ) -> List[Dict[str, Any]]:
        """
        Hesabın videolarındaki tüm etiketleri toplar, kullanım sayısı, ortalama izlenme,
        ortalama kaydetme oranı, Lift çarpanı ve durum sınıfını hesaplar.
        """
        if not enriched_videos:
            return []

        safe_median = max(int(channel_median_views), 1)
        tag_buckets: Dict[str, List[Dict[str, Any]]] = {}

        for video in enriched_videos:
            tags = video.get("hashtags") or []
            if not isinstance(tags, list):
                continue
            seen_in_video = set()
            for raw_tag in tags:
                clean_tag = str(raw_tag).strip().lower()
                if not clean_tag:
                    continue
                if not clean_tag.startswith("#"):
                    clean_tag = f"#{clean_tag}"
                if clean_tag in seen_in_video:
                    continue
                seen_in_video.add(clean_tag)
                tag_buckets.setdefault(clean_tag, []).append(video)

        results: List[Dict[str, Any]] = []
        for tag, vid_list in tag_buckets.items():
            usage_count = len(vid_list)
            avg_views = int(
                round(sum(int(v.get("views") or 0) for v in vid_list) / usage_count)
            )
            avg_er = round(
                sum(float(v.get("engagement_rate") or 0.0) for v in vid_list)
                / usage_count,
                2,
            )

            saves_rates: List[float] = []
            for v in vid_list:
                v_views = max(int(v.get("views") or 0), 1)
                v_saves = int(v.get("saves") or 0)
                saves_rates.append((v_saves / v_views) * 100.0)
            avg_saves_rate = round(sum(saves_rates) / usage_count, 2)

            lift_multiplier = round(avg_views / safe_median, 2)
            status_category = cls.classify_lift_status(lift_multiplier)

            results.append(
                {
                    "hashtag": tag,
                    "usage_count": usage_count,
                    "avg_views_when_used": avg_views,
                    "avg_engagement_rate": avg_er,
                    "avg_saves_rate": avg_saves_rate,
                    "lift_multiplier": lift_multiplier,
                    "status_category": status_category,
                }
            )

        results.sort(key=lambda x: (x["lift_multiplier"], x["avg_views_when_used"]), reverse=True)
        return results
