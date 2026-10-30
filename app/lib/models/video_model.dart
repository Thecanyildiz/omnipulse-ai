// OmniPulse AI — Video Metrikleri ve Yapay Zeka "Neden İzlendi / Neden İzlenmedi" Modeli (app/lib/models/video_model.dart)

class AiVideoRootCause {
  final String verdict;
  final String primaryReasonHeadline;
  final String durationImpact;
  final String algorithmSignalBreakdown;
  final String hookAndTimingEvaluation;
  final String immediateFixOrReplicateAction;

  const AiVideoRootCause({
    required this.verdict,
    required this.primaryReasonHeadline,
    required this.durationImpact,
    required this.algorithmSignalBreakdown,
    required this.hookAndTimingEvaluation,
    required this.immediateFixOrReplicateAction,
  });

  bool get isEmpty => primaryReasonHeadline.trim().isEmpty;

  factory AiVideoRootCause.fromJson(Map<String, dynamic> json) {
    return AiVideoRootCause(
      verdict: (json['verdict'] ?? 'NORMAL').toString(),
      primaryReasonHeadline: (json['primary_reason_headline'] ?? '').toString(),
      durationImpact: (json['duration_impact'] ?? '').toString(),
      algorithmSignalBreakdown: (json['algorithm_signal_breakdown'] ?? '').toString(),
      hookAndTimingEvaluation: (json['hook_and_timing_evaluation'] ?? '').toString(),
      immediateFixOrReplicateAction:
          (json['immediate_fix_or_replicate_action'] ?? '').toString(),
    );
  }
}

class VideoModel {
  final String id;
  final String accountId;
  final String platformVideoId;
  final String videoUrl;
  final String thumbnailUrl;
  final String titleOrCaption;
  final List<String> hashtags;
  final int durationSeconds;
  final DateTime publishedAt;
  // 5 Temel Metrik
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  // Hesaplanan Matematiksel Metrikler
  final double engagementRate;
  final double viralityScore;
  final double performanceMultiplier;
  final double viewsVelocityPerHour;
  final String performanceTier; // 'viral_hit', 'above_average', 'normal', 'underperforming', 'flop'
  final AiVideoRootCause rootCause;

  const VideoModel({
    required this.id,
    required this.accountId,
    required this.platformVideoId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.titleOrCaption,
    required this.hashtags,
    required this.durationSeconds,
    required this.publishedAt,
    required this.views,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.saves,
    required this.engagementRate,
    required this.viralityScore,
    required this.performanceMultiplier,
    required this.viewsVelocityPerHour,
    required this.performanceTier,
    required this.rootCause,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['hashtags'];
    final List<String> parsedTags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];

    final rawRoot = json['ai_root_cause_analysis'];
    final Map<String, dynamic> rootMap = rawRoot is Map<String, dynamic>
        ? rawRoot
        : <String, dynamic>{};

    final int viewsVal = (json['views'] as num?)?.toInt() ?? 0;
    final int likesVal = (json['likes'] as num?)?.toInt() ?? 0;
    final int commentsVal = (json['comments'] as num?)?.toInt() ?? 0;
    final int sharesVal = (json['shares'] as num?)?.toInt() ?? 0;
    final int savesVal = (json['saves'] as num?)?.toInt() ?? 0;
    final int durVal = (json['duration_seconds'] as num?)?.toInt() ?? 0;
    final double multVal = (json['performance_multiplier'] as num?)?.toDouble() ?? 1.0;
    final double virVal = (json['virality_score'] as num?)?.toDouble() ?? 0.0;
    final String tierVal = (json['performance_tier'] ?? 'normal').toString();

    AiVideoRootCause parsedRoot = AiVideoRootCause.fromJson(rootMap);
    if (parsedRoot.isEmpty) {
      final int safeV = viewsVal > 0 ? viewsVal : 1;
      final String savesPct = ((savesVal / safeV) * 100).toStringAsFixed(2);
      final String sharesPct = ((sharesVal / safeV) * 100).toStringAsFixed(2);
      parsedRoot = AiVideoRootCause(
        verdict: tierVal.toUpperCase(),
        primaryReasonHeadline: multVal >= 1.3
            ? 'Yüksek Kaydetme (%$savesPct) ve Paylaşım (%$sharesPct) Videoyu Keşfette Tuttu'
            : 'Düşük Kaydetme (%$savesPct) ve Süre ($durVal sn) Akış İvmesini Sınırladı',
        durationImpact:
            'Video süresi $durVal saniye. Kanal medyan çarpanı ${multVal.toStringAsFixed(2)}x olarak gerçekleşti.',
        algorithmSignalBreakdown:
            'Kaydetme/İzlenme: %$savesPct | Paylaşım/İzlenme: %$sharesPct | Viralite Skoru: ${virVal.toStringAsFixed(1)}/100.',
        hookAndTimingEvaluation:
            'İlk 3 saniye merak boşluğu ve başlık yapısı izleyici tutma oranını doğrudan belirledi.',
        immediateFixOrReplicateAction: multVal >= 1.3
            ? 'Bu videodaki kanca yapısını ve süreyi koruyarak devam videosu çekin.'
            : 'İlk 3 saniyede doğrudan sonucu gösterin ve videoyu 15-22 saniye aralığında kurgulayın.',
      );
    }

    return VideoModel(
      id: (json['id'] ?? '').toString(),
      accountId: (json['account_id'] ?? '').toString(),
      platformVideoId: (json['platform_video_id'] ?? '').toString(),
      videoUrl: (json['video_url'] ?? '').toString(),
      thumbnailUrl: (json['thumbnail_url'] ?? '').toString(),
      titleOrCaption: (json['title_or_caption'] ?? 'Başlıksız Video').toString(),
      hashtags: parsedTags,
      durationSeconds: durVal,
      publishedAt: DateTime.tryParse((json['published_at'] ?? '').toString()) ?? DateTime.now(),
      views: viewsVal,
      likes: likesVal,
      comments: commentsVal,
      shares: sharesVal,
      saves: savesVal,
      engagementRate: (json['engagement_rate'] as num?)?.toDouble() ?? 0.0,
      viralityScore: virVal,
      performanceMultiplier: multVal,
      viewsVelocityPerHour: (json['views_velocity_per_hour'] as num?)?.toDouble() ?? 0.0,
      performanceTier: tierVal,
      rootCause: parsedRoot,
    );
  }
}
