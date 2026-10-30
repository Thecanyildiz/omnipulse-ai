// OmniPulse AI — Otonom Bulunan Rakip Video Modeli (app/lib/models/competitor_model.dart)

class CompetitorVideoModel {
  final String id;
  final String targetAccountId;
  final String platform;
  final String competitorUsername;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final List<String> hashtags;
  final String searchKeywordUsed;
  final int durationSeconds;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final double engagementRate;
  final double viralityScore;
  final String aiWhyItWentViral;
  final String aiHowToBeatIt;
  final DateTime discoveredAt;

  const CompetitorVideoModel({
    required this.id,
    required this.targetAccountId,
    required this.platform,
    required this.competitorUsername,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.caption,
    required this.hashtags,
    required this.searchKeywordUsed,
    required this.durationSeconds,
    required this.views,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.saves,
    required this.engagementRate,
    required this.viralityScore,
    required this.aiWhyItWentViral,
    required this.aiHowToBeatIt,
    required this.discoveredAt,
  });

  factory CompetitorVideoModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['hashtags'];
    final List<String> parsedTags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];

    final int viewsVal = (json['views'] as num?)?.toInt() ?? 0;
    final double vScore = (json['virality_score'] as num?)?.toDouble() ?? 0.0;

    final String whyViral = (json['ai_why_it_went_viral'] ?? '').toString().trim();
    final String howToBeat = (json['ai_how_to_beat_it'] ?? '').toString().trim();

    return CompetitorVideoModel(
      id: (json['id'] ?? '').toString(),
      targetAccountId: (json['target_account_id'] ?? '').toString(),
      platform: (json['platform'] ?? 'tiktok').toString(),
      competitorUsername: (json['competitor_username'] ?? 'rakip').toString(),
      videoUrl: (json['video_url'] ?? '').toString(),
      thumbnailUrl: (json['thumbnail_url'] ?? '').toString(),
      caption: (json['caption'] ?? '').toString(),
      hashtags: parsedTags,
      searchKeywordUsed: (json['search_keyword_used'] ?? '').toString(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      views: viewsVal,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      comments: (json['comments'] as num?)?.toInt() ?? 0,
      shares: (json['shares'] as num?)?.toInt() ?? 0,
      saves: (json['saves'] as num?)?.toInt() ?? 0,
      engagementRate: (json['engagement_rate'] as num?)?.toDouble() ?? 0.0,
      viralityScore: vScore,
      aiWhyItWentViral: whyViral.isNotEmpty
          ? whyViral
          : 'İlk 3 saniyede güçlü merak boşluğu ve yüksek kaydetme/paylaşım ivmesiyle ($vScore/100 viralite) keşfete çıktı.',
      aiHowToBeatIt: howToBeat.isNotEmpty
          ? howToBeat
          : 'Konuyu daha net görsel kanıtla 18 saniyeye sıkıştırıp ekran üzerinde adım adım kontrol listesi vererek kaydetme oranını geçin.',
      discoveredAt:
          DateTime.tryParse((json['discovered_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
