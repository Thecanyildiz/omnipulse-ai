// OmniPulse AI — Genel Strateji, Hashtag Performans Matrisi ve 5 Video Fikri Modeli (app/lib/models/ai_report_model.dart)

class HashtagMetricModel {
  final String id;
  final String accountId;
  final String hashtag;
  final int usageCount;
  final int avgViewsWhenUsed;
  final double avgSavesRate;
  final double liftMultiplier;
  final String statusCategory; // 'booster', 'neutral', 'drag'

  const HashtagMetricModel({
    required this.id,
    required this.accountId,
    required this.hashtag,
    required this.usageCount,
    required this.avgViewsWhenUsed,
    required this.avgSavesRate,
    required this.liftMultiplier,
    required this.statusCategory,
  });

  factory HashtagMetricModel.fromJson(Map<String, dynamic> json) {
    return HashtagMetricModel(
      id: (json['id'] ?? '').toString(),
      accountId: (json['account_id'] ?? '').toString(),
      hashtag: (json['hashtag'] ?? '#etiket').toString(),
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 1,
      avgViewsWhenUsed: (json['avg_views_when_used'] as num?)?.toInt() ?? 0,
      avgSavesRate: (json['avg_saves_rate'] as num?)?.toDouble() ?? 0.0,
      liftMultiplier: (json['lift_multiplier'] as num?)?.toDouble() ?? 1.0,
      statusCategory: (json['status_category'] ?? 'neutral').toString(),
    );
  }
}

class VideoBlueprintModel {
  final int ideaNumber;
  final String title;
  final String first3SecondsHook;
  final String visualDirection;
  final int optimalDurationSeconds;
  final String targetAlgorithmMetric;
  final String expectedMultiplierPotential;

  const VideoBlueprintModel({
    required this.ideaNumber,
    required this.title,
    required this.first3SecondsHook,
    required this.visualDirection,
    required this.optimalDurationSeconds,
    required this.targetAlgorithmMetric,
    required this.expectedMultiplierPotential,
  });

  factory VideoBlueprintModel.fromJson(Map<String, dynamic> json) {
    return VideoBlueprintModel(
      ideaNumber: (json['idea_number'] as num?)?.toInt() ?? 1,
      title: (json['title'] ?? '').toString(),
      first3SecondsHook: (json['first_3_seconds_hook'] ?? '').toString(),
      visualDirection: (json['visual_direction'] ?? '').toString(),
      optimalDurationSeconds: (json['optimal_duration_seconds'] as num?)?.toInt() ?? 18,
      targetAlgorithmMetric: (json['target_algorithm_metric'] ?? 'Saves').toString(),
      expectedMultiplierPotential:
          (json['expected_multiplier_potential'] ?? '3.0x - 5.0x').toString(),
    );
  }
}

class AiStrategyReportModel {
  final String id;
  final String? accountId;
  final String reportType; // 'master_briefing', 'account_deep_strategy'
  final String executiveSummary;
  final String competitorGapSummary;
  final List<String> optimalPostingWindows;
  final List<String> keepUsingBoosters;
  final List<String> stopUsingDrags;
  final List<String> newCompetitorTrends;
  final List<VideoBlueprintModel> next5VideoBlueprints;
  final DateTime createdAt;

  const AiStrategyReportModel({
    required this.id,
    this.accountId,
    required this.reportType,
    required this.executiveSummary,
    required this.competitorGapSummary,
    required this.optimalPostingWindows,
    required this.keepUsingBoosters,
    required this.stopUsingDrags,
    required this.newCompetitorTrends,
    required this.next5VideoBlueprints,
    required this.createdAt,
  });

  factory AiStrategyReportModel.fromJson(Map<String, dynamic> json) {
    final rawWindows = json['optimal_posting_windows'];
    final List<String> windows = rawWindows is List
        ? rawWindows.map((e) => e.toString()).toList()
        : <String>[];

    final rawRecTags = json['recommended_hashtags'];
    final Map<String, dynamic> recMap = rawRecTags is Map<String, dynamic>
        ? rawRecTags
        : <String, dynamic>{};

    List<String> parseTagList(dynamic node) {
      if (node is List) {
        return node.map((e) => e.toString()).toList();
      }
      return <String>[];
    }

    final rawBlueprints = json['next_5_video_blueprints'];
    final List<VideoBlueprintModel> blueprints = rawBlueprints is List
        ? rawBlueprints
            .whereType<Map<String, dynamic>>()
            .map(VideoBlueprintModel.fromJson)
            .toList()
        : <VideoBlueprintModel>[];

    return AiStrategyReportModel(
      id: (json['id'] ?? '').toString(),
      accountId: json['account_id']?.toString(),
      reportType: (json['report_type'] ?? 'account_deep_strategy').toString(),
      executiveSummary: (json['executive_summary'] ?? '').toString(),
      competitorGapSummary: (json['competitor_gap_summary'] ?? '').toString(),
      optimalPostingWindows: windows,
      keepUsingBoosters: parseTagList(recMap['keep_using_boosters']),
      stopUsingDrags: parseTagList(recMap['stop_using_drags']),
      newCompetitorTrends: parseTagList(recMap['new_competitor_trends']),
      next5VideoBlueprints: blueprints,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
