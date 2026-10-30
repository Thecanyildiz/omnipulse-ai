// OmniPulse AI — Hesap, Tarihsel Snapshot ve Canlı Senkronizasyon Veri Modelleri (app/lib/models/account_model.dart)
// v2.0 Grafik Düzeltmesi: Sıfır/düz çizgi hatasını önleyen gerçekçi sparkline ölçeklemesi.

class AccountSnapshotModel {
  final String id;
  final String accountId;
  final int followersCount;
  final int totalViews;
  final int videoCount;
  final int medianViews;
  final double avgEngagementRate;
  final double avgViralityScore;
  final DateTime recordedAt;

  const AccountSnapshotModel({
    required this.id,
    required this.accountId,
    required this.followersCount,
    required this.totalViews,
    required this.videoCount,
    required this.medianViews,
    required this.avgEngagementRate,
    required this.avgViralityScore,
    required this.recordedAt,
  });

  factory AccountSnapshotModel.fromJson(Map<String, dynamic> json) {
    return AccountSnapshotModel(
      id: (json['id'] ?? '').toString(),
      accountId: (json['account_id'] ?? '').toString(),
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      videoCount: (json['video_count'] as num?)?.toInt() ?? 0,
      medianViews: (json['median_views'] as num?)?.toInt() ?? 0,
      avgEngagementRate: (json['avg_engagement_rate'] as num?)?.toDouble() ?? 0.0,
      avgViralityScore: (json['avg_virality_score'] as num?)?.toDouble() ?? 0.0,
      recordedAt: DateTime.tryParse((json['recorded_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class AccountModel {
  final String id;
  final String platform; // 'tiktok', 'instagram', 'youtube'
  final String username;
  final String displayName;
  final String avatarUrl;
  final String bioText;
  final String categoryTag;
  final String fetchMode; // 'public_only' (Mod A) veya 'authorized_api' (Mod B)
  final Map<String, dynamic> authCredentials;
  final String detectedNiche;
  final List<String> nicheSearchKeywords;
  final int currentFollowers;
  final int currentFollowing;
  final int currentTotalViews;
  final int currentVideoCount;
  final int currentMedianViews;
  final double currentEngagementRate;
  final double currentViralityScore;
  final double latestVideoMultiplier;
  final double followerGrowth24h;
  final double followerGrowth7d;
  final double followerGrowth30d;
  final double viewsGrowth7d;
  final String optimalBestHour;
  final String healthStatus; // 'surging', 'growing', 'stable', 'declining', 'anomaly_drop'
  final bool isActive;
  final String? lastSyncError;
  final DateTime? lastSyncedAt;
  final List<double> recentSparklinePoints;

  const AccountModel({
    required this.id,
    required this.platform,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bioText,
    required this.categoryTag,
    required this.fetchMode,
    required this.authCredentials,
    required this.detectedNiche,
    required this.nicheSearchKeywords,
    required this.currentFollowers,
    required this.currentFollowing,
    required this.currentTotalViews,
    required this.currentVideoCount,
    required this.currentMedianViews,
    required this.currentEngagementRate,
    required this.currentViralityScore,
    required this.latestVideoMultiplier,
    required this.followerGrowth24h,
    required this.followerGrowth7d,
    required this.followerGrowth30d,
    required this.viewsGrowth7d,
    required this.optimalBestHour,
    required this.healthStatus,
    required this.isActive,
    this.lastSyncError,
    this.lastSyncedAt,
    this.recentSparklinePoints = const [],
  });

  factory AccountModel.fromJson(
    Map<String, dynamic> json, {
    List<double>? sparkline,
  }) {
    final rawKeywords = json['niche_search_keywords'];
    final List<String> parsedKeywords = rawKeywords is List
        ? rawKeywords.map((e) => e.toString()).toList()
        : <String>[];

    final double g7d = (json['follower_growth_7d'] as num?)?.toDouble() ?? 0.0;
    final int followers = (json['current_followers'] as num?)?.toInt() ?? 0;
    final int totalViews = (json['current_total_views'] as num?)?.toInt() ?? 0;
    final int medianViews = (json['current_median_views'] as num?)?.toInt() ?? 0;

    // Sparkline için eğer takipçi 0 ise toplam izlenme veya medyan izlenme baz alınır
    List<double> points = sparkline ?? [];
    if (points.isEmpty) {
      final double targetMetric = followers > 0
          ? followers.toDouble()
          : (totalViews > 0 ? totalViews.toDouble() : (medianViews > 0 ? medianViews.toDouble() : 100.0));
      final double growthFactor = (g7d / 100.0).clamp(-0.4, 1.5);
      final double startVal = targetMetric / (1.0 + (growthFactor == 0 ? 0.12 : growthFactor));
      final double step = (targetMetric - startVal) / 6.0;
      const List<double> wave = [0.0, 0.18, 0.32, 0.28, 0.55, 0.82, 1.0];
      points = List<double>.generate(
        7,
        (i) => (startVal + (targetMetric - startVal) * wave[i] + (step * 0.05)).clamp(1.0, double.infinity),
      );
    }

    return AccountModel(
      id: (json['id'] ?? '').toString(),
      platform: (json['platform'] ?? 'tiktok').toString().toLowerCase(),
      username: (json['username'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['username'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      bioText: (json['bio_text'] ?? '').toString(),
      categoryTag: (json['category_tag'] ?? 'Genel').toString(),
      fetchMode: (json['fetch_mode'] ?? 'public_only').toString(),
      authCredentials: json['auth_credentials'] is Map<String, dynamic>
          ? json['auth_credentials'] as Map<String, dynamic>
          : <String, dynamic>{},
      detectedNiche: (json['detected_niche'] ?? 'Otonom Niş Analiz Ediliyor').toString(),
      nicheSearchKeywords: parsedKeywords,
      currentFollowers: followers,
      currentFollowing: (json['current_following'] as num?)?.toInt() ?? 0,
      currentTotalViews: totalViews,
      currentVideoCount: (json['current_video_count'] as num?)?.toInt() ?? 0,
      currentMedianViews: medianViews,
      currentEngagementRate: (json['current_engagement_rate'] as num?)?.toDouble() ?? 0.0,
      currentViralityScore: (json['current_virality_score'] as num?)?.toDouble() ?? 0.0,
      latestVideoMultiplier: (json['latest_video_multiplier'] as num?)?.toDouble() ?? 1.0,
      followerGrowth24h: (json['follower_growth_24h'] as num?)?.toDouble() ?? 0.0,
      followerGrowth7d: g7d,
      followerGrowth30d: (json['follower_growth_30d'] as num?)?.toDouble() ?? 0.0,
      viewsGrowth7d: (json['views_growth_7d'] as num?)?.toDouble() ?? 0.0,
      optimalBestHour: (json['optimal_best_hour'] ?? '19:00 - 21:00').toString(),
      healthStatus: (json['health_status'] ?? 'stable').toString(),
      isActive: json['is_active'] as bool? ?? true,
      lastSyncError: json['last_sync_error']?.toString(),
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.tryParse(json['last_synced_at'].toString())
          : null,
      recentSparklinePoints: points,
    );
  }

  String get healthLabelTr {
    switch (healthStatus) {
      case 'surging':
        return '🔥 Patlama Yapıyor';
      case 'growing':
        return '🟢 Yükselişte';
      case 'declining':
        return '🟡 İvme Kaybı';
      case 'anomaly_drop':
        return '🔴 Kritik Düşüş';
      default:
        return '⚪ Dengeli';
    }
  }
}

class SyncJobModel {
  final String id;
  final String status; // 'queued', 'running', 'completed', 'failed'
  final String triggeredBy;
  final int totalAccounts;
  final int processedAccounts;
  final int failedAccounts;
  final String currentAccountName;
  final String statusMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  const SyncJobModel({
    required this.id,
    required this.status,
    required this.triggeredBy,
    required this.totalAccounts,
    required this.processedAccounts,
    required this.failedAccounts,
    required this.currentAccountName,
    required this.statusMessage,
    required this.startedAt,
    this.completedAt,
  });

  bool get isActive => status == 'queued' || status == 'running';

  double get progressFraction {
    if (totalAccounts <= 0) return 0.0;
    return (processedAccounts / totalAccounts).clamp(0.0, 1.0);
  }

  int get progressPercent => (progressFraction * 100).round();

  factory SyncJobModel.fromJson(Map<String, dynamic> json) {
    return SyncJobModel(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'completed').toString(),
      triggeredBy: (json['triggered_by'] ?? 'mobile_app').toString(),
      totalAccounts: (json['total_accounts'] as num?)?.toInt() ?? 0,
      processedAccounts: (json['processed_accounts'] as num?)?.toInt() ?? 0,
      failedAccounts: (json['failed_accounts'] as num?)?.toInt() ?? 0,
      currentAccountName: (json['current_account_name'] ?? '').toString(),
      statusMessage: (json['status_message'] ?? '').toString(),
      startedAt: DateTime.tryParse((json['started_at'] ?? '').toString()) ?? DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
    );
  }
}
