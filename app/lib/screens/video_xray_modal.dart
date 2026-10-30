// OmniPulse AI — Ekran 3: Video Röntgen ve "Neden İzlendi / Neden İzlenmedi" Ekranı (app/lib/screens/video_xray_modal.dart)
// 5 Boyutlu Radar Grafiği (fl_chart RadarChart) ile videonun İzlenme, Beğeni, Yorum, Paylaşma ve Kaydetme
// performansını kanalın kendi ortalamasıyla kıyaslar ve AI Kök Neden Karnesini gösterir.

import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/account_model.dart';
import '../models/video_model.dart';
import '../widgets/metric_badge.dart';

class VideoXrayModal extends StatelessWidget {
  final VideoModel video;
  final AccountModel account;
  final List<VideoModel> allAccountVideos;

  const VideoXrayModal({
    super.key,
    required this.video,
    required this.account,
    required this.allAccountVideos,
  });

  double _normalizeRatio(num value, num baseline) {
    final double safeBase = math.max(baseline.toDouble(), 1.0);
    final double ratio = value.toDouble() / safeBase;
    return (ratio * 50.0).clamp(10.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    final int count = math.max(allAccountVideos.length, 1);
    final double avgViews = allAccountVideos.fold<double>(0, (s, v) => s + v.views) / count;
    final double avgLikes = allAccountVideos.fold<double>(0, (s, v) => s + v.likes) / count;
    final double avgComments = allAccountVideos.fold<double>(0, (s, v) => s + v.comments) / count;
    final double avgShares = allAccountVideos.fold<double>(0, (s, v) => s + v.shares) / count;
    final double avgSaves = allAccountVideos.fold<double>(0, (s, v) => s + v.saves) / count;

    final List<double> videoRadarValues = [
      _normalizeRatio(video.views, avgViews),
      _normalizeRatio(video.likes, avgLikes),
      _normalizeRatio(video.comments, avgComments),
      _normalizeRatio(video.shares, avgShares),
      _normalizeRatio(video.saves, avgSaves),
    ];

    const List<String> radarTitles = [
      '👁️ İzlenme',
      '❤️ Beğeni',
      '💬 Yorum',
      '🔄 Paylaşım',
      '🔖 Kaydetme',
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: OmniPulseColors.backgroundDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: OmniPulseColors.borderDark, width: 1.5)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Üst Tutamaç
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: OmniPulseColors.borderDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Başlık ve Medyan Çarpanı
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VİDEO RÖNTGEN & KÖK NEDEN ANALİZİ',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: OmniPulseColors.aiPink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          video.titleOrCaption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: OmniPulseColors.textPrimaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  MultiplierBadge(
                    multiplier: video.performanceMultiplier,
                    tier: video.performanceTier,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 1. 5 Boyutlu Radar Grafiği (Video vs Kanal Ortalaması)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: OmniPulseColors.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OmniPulseColors.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '5 BOYUTLU ALGORİTMA RADAR KIYASLAMASI',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: OmniPulseColors.textSecondaryDark,
                          ),
                        ),
                        Text(
                          'Yeşil: Bu Video  |  Gri: Kanal Ort.',
                          style: TextStyle(
                            fontSize: 11,
                            color: OmniPulseColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 240,
                      child: RadarChart(
                        RadarChartData(
                          radarShape: RadarShape.polygon,
                          tickCount: 4,
                          ticksTextStyle: const TextStyle(
                            color: Colors.transparent,
                            fontSize: 8,
                          ),
                          radarBorderData: const BorderSide(color: OmniPulseColors.borderDark),
                          gridBorderData: const BorderSide(color: OmniPulseColors.borderDark),
                          tickBorderData: const BorderSide(color: OmniPulseColors.borderDark),
                          getTitle: (index, _) => RadarChartTitle(
                            text: radarTitles[index],
                            angle: 0,
                          ),
                          titleTextStyle: const TextStyle(
                            color: OmniPulseColors.textPrimaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          dataSets: [
                            // Kanal Ortalaması Baz Çizgisi (50.0)
                            RadarDataSet(
                              fillColor: OmniPulseColors.textSecondaryDark.withOpacity(0.12),
                              borderColor: OmniPulseColors.textSecondaryDark,
                              entryRadius: 2,
                              borderWidth: 1.5,
                              dataEntries: const [
                                RadarEntry(value: 50),
                                RadarEntry(value: 50),
                                RadarEntry(value: 50),
                                RadarEntry(value: 50),
                                RadarEntry(value: 50),
                              ],
                            ),
                            // Seçili Videonun Performansı
                            RadarDataSet(
                              fillColor: OmniPulseColors.emeraldViral.withOpacity(0.25),
                              borderColor: OmniPulseColors.emeraldViral,
                              entryRadius: 3.5,
                              borderWidth: 2.5,
                              dataEntries: videoRadarValues
                                  .map((v) => RadarEntry(value: v))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Yan Yana Sayısal Tablo Özeti
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ComparisonMiniCol(
                          label: 'İzlenme',
                          videoVal: AppConstants.formatCompactNumber(video.views),
                          avgVal: AppConstants.formatCompactNumber(avgViews),
                        ),
                        _ComparisonMiniCol(
                          label: 'Beğeni',
                          videoVal: AppConstants.formatCompactNumber(video.likes),
                          avgVal: AppConstants.formatCompactNumber(avgLikes),
                        ),
                        _ComparisonMiniCol(
                          label: 'Yorum',
                          videoVal: AppConstants.formatCompactNumber(video.comments),
                          avgVal: AppConstants.formatCompactNumber(avgComments),
                        ),
                        _ComparisonMiniCol(
                          label: 'Paylaşım',
                          videoVal: AppConstants.formatCompactNumber(video.shares),
                          avgVal: AppConstants.formatCompactNumber(avgShares),
                        ),
                        _ComparisonMiniCol(
                          label: 'Kaydetme',
                          videoVal: AppConstants.formatCompactNumber(video.saves),
                          avgVal: AppConstants.formatCompactNumber(avgSaves),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. AI Teşhis Başlığı (Primary Reason Headline)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: OmniPulseColors.aiAutonomousGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.cpu, color: Colors.white, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI TEŞHİSİ (${video.rootCause.verdict})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            video.rootCause.primaryReasonHeadline,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. 4'lü Kök Neden Detay Kutuları
              _XraySectionCard(
                icon: LucideIcons.timer,
                title: '1. Süre Kontrolü ve İzleyici Tutma Etkisi',
                body: video.rootCause.durationImpact,
                accentColor: OmniPulseColors.oceanNormal,
              ),
              const SizedBox(height: 10),
              _XraySectionCard(
                icon: LucideIcons.barChart,
                title: '2. Algoritma Sinyali (Kaydetme & Paylaşım Oranı)',
                body: video.rootCause.algorithmSignalBreakdown,
                accentColor: OmniPulseColors.emeraldViral,
              ),
              const SizedBox(height: 10),
              _XraySectionCard(
                icon: LucideIcons.zap,
                title: '3. Kanca (Hook), Başlık ve Yayın Saati Analizi',
                body: video.rootCause.hookAndTimingEvaluation,
                accentColor: OmniPulseColors.amberWarning,
              ),
              const SizedBox(height: 10),
              _XraySectionCard(
                icon: LucideIcons.checkCircle2,
                title: '4. Hemen Uygulanacak Aksiyon Reçetesi',
                body: video.rootCause.immediateFixOrReplicateAction,
                accentColor: OmniPulseColors.aiPink,
              ),
              const SizedBox(height: 18),

              // Videoyu Platformda Aç Butonu
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(video.videoUrl);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(LucideIcons.externalLink, size: 18),
                label: const Text('Videoyu Orijinal Platformda Aç'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ComparisonMiniCol extends StatelessWidget {
  final String label;
  final String videoVal;
  final String avgVal;

  const _ComparisonMiniCol({
    required this.label,
    required this.videoVal,
    required this.avgVal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: OmniPulseColors.textSecondaryDark),
        ),
        const SizedBox(height: 3),
        Text(
          videoVal,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: OmniPulseColors.emeraldViral,
          ),
        ),
        Text(
          'Ort: $avgVal',
          style: const TextStyle(fontSize: 10.5, color: OmniPulseColors.textMutedDark),
        ),
      ],
    );
  }
}

class _XraySectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accentColor;

  const _XraySectionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OmniPulseColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OmniPulseColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: OmniPulseColors.textPrimaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
