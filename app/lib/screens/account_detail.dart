// OmniPulse AI — Ekran 2: Hesap Detay ve Zaman Serisi Ekranı (app/lib/screens/account_detail.dart)
// 24 Saat / 7 Gün / 30 Gün sekmeli fl_chart büyüme grafiği, 4'lü Hesap Karnesi
// ve 5 Metrik Rozetli (İzlenme, Beğeni, Yorum, Paylaşma, Kaydetme) + Medyan Çarpanlı Son Videolar Listesi.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/account_model.dart';
import '../models/video_model.dart';
import '../providers/app_providers.dart';
import '../widgets/metric_badge.dart';
import 'video_xray_modal.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final AccountModel account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  String _selectedWindow = '7d'; // '24h', '7d', '30d'

  List<AccountSnapshotModel> _filterSnapshots(List<AccountSnapshotModel> all) {
    final now = DateTime.now();
    final Duration lookback;
    if (_selectedWindow == '24h') {
      lookback = const Duration(hours: 24);
    } else if (_selectedWindow == '30d') {
      lookback = const Duration(days: 30);
    } else {
      lookback = const Duration(days: 7);
    }
    final cutoff = now.subtract(lookback);
    final filtered = all.where((s) => s.recordedAt.isAfter(cutoff)).toList();
    return filtered.isNotEmpty ? filtered : all;
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final snapshotsAsync = ref.watch(accountSnapshotsProvider(account.id));
    final videosAsync = ref.watch(accountVideosProvider(account.id));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            PlatformBadge(platform: account.platform),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '@${account.username}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Niş Etiketi ve Hesap Özeti Başlığı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OmniPulseColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OmniPulseColors.borderDark),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: OmniPulseColors.platformColor(account.platform).withOpacity(0.2),
                  backgroundImage:
                      account.avatarUrl.isNotEmpty ? NetworkImage(account.avatarUrl) : null,
                  child: account.avatarUrl.isEmpty
                      ? Text(
                          account.username[0].toUpperCase(),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: OmniPulseColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI Tespit Edilen Niş: ${account.detectedNiche}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: OmniPulseColors.aiPink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                GrowthPercentBadge(
                  growthPercent: account.followerGrowth7d,
                  suffixLabel: '7g',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Hesap Karnesi (4 Kutu: Medyan İzlenme, Etkileşim Oranı, Viralite Puanı, En İyi Paylaşım Saati)
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width >= 720 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.75,
            children: [
              _ScorecardBox(
                title: 'Medyan İzlenme',
                value: AppConstants.formatCompactNumber(account.currentMedianViews),
                subtitle: 'Kanal Baz Çizgisi',
                icon: LucideIcons.barChart2,
                color: OmniPulseColors.oceanNormal,
              ),
              _ScorecardBox(
                title: 'Etkileşim Oranı',
                value: '%${account.currentEngagementRate.toStringAsFixed(2)}',
                subtitle: 'Beğeni+Yorum+Paylaş+Kaydet',
                icon: LucideIcons.heart,
                color: OmniPulseColors.emeraldViral,
              ),
              _ScorecardBox(
                title: 'Viralite Puanı',
                value: '${account.currentViralityScore.toStringAsFixed(1)} / 100',
                subtitle: 'Kaydetme & Paylaşım Ağırlıklı',
                icon: LucideIcons.flame,
                color: OmniPulseColors.aiPink,
              ),
              _ScorecardBox(
                title: 'En İyi Paylaşım Saati',
                value: account.optimalBestHour,
                subtitle: 'Maksimum Keşfet Penceresi',
                icon: LucideIcons.clock,
                color: OmniPulseColors.amberWarning,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Tarihsel Gelişim Grafiği (24 Saat / 7 Gün / 30 Gün Sekmeli)
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TARİHSEL GELİŞİM GRAFİĞİ (TAKİPÇİ & İZLENME)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OmniPulseColors.textSecondaryDark,
                      ),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: '24h', label: Text('24 Saat')),
                        ButtonSegment(value: '7d', label: Text('7 Gün')),
                        ButtonSegment(value: '30d', label: Text('30 Gün')),
                      ],
                      selected: {_selectedWindow},
                      onSelectionChanged: (s) => setState(() => _selectedWindow = s.first),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 220,
                  child: snapshotsAsync.when(
                    data: (snaps) {
                      final items = _filterSnapshots(snaps);
                      final List<FlSpot> spots;
                      if (items.length >= 2) {
                        spots = List<FlSpot>.generate(
                          items.length,
                          (i) => FlSpot(i.toDouble(), items[i].followersCount.toDouble()),
                        );
                      } else {
                        final pts = account.recentSparklinePoints;
                        spots = List<FlSpot>.generate(
                          pts.length,
                          (i) => FlSpot(i.toDouble(), pts[i]),
                        );
                      }
                      final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) * 0.98;
                      final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.02;

                      return LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => const FlLine(
                              color: OmniPulseColors.borderDark,
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minY: minY == maxY ? minY - 10 : minY,
                          maxY: minY == maxY ? maxY + 10 : maxY,
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 52,
                                getTitlesWidget: (val, _) => Text(
                                  AppConstants.formatCompactNumber(val),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: OmniPulseColors.textSecondaryDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final idx = spot.x.toInt();
                                  String extraViews = '';
                                  if (idx >= 0 && idx < items.length) {
                                    final snap = items[idx];
                                    final dateStr = DateFormat('dd MMM HH:mm').format(snap.recordedAt);
                                    extraViews =
                                        '\n$dateStr\nİzlenme: ${AppConstants.formatCompactNumber(snap.totalViews)}';
                                  }
                                  return LineTooltipItem(
                                    'Takipçi: ${AppConstants.formatCompactNumber(spot.y)}$extraViews',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: OmniPulseColors.emeraldViral,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: OmniPulseColors.emeraldViral.withOpacity(0.16),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Grafik yüklenemedi: $e')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Son Videolar Listesi Başlığı
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SON VİDEOLAR VE ALGORİTMA PERFORMANSI',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: OmniPulseColors.textPrimaryDark,
                ),
              ),
              Text(
                'Röntgen için videoya dokunun',
                style: TextStyle(fontSize: 12, color: OmniPulseColors.aiPink),
              ),
            ],
          ),
          const SizedBox(height: 12),

          videosAsync.when(
            data: (videos) {
              if (videos.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: OmniPulseColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: OmniPulseColors.borderDark),
                  ),
                  child: const Text(
                    'Bu hesap için henüz video verisi çekilmedi. Komuta Panelinden "☁️ Şimdi Analiz Et" butonunu çalıştırın.',
                    style: TextStyle(color: OmniPulseColors.textSecondaryDark),
                  ),
                );
              }

              return Column(
                children: videos.map((video) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _VideoMetricCard(
                      video: video,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => VideoXrayModal(
                            video: video,
                            account: account,
                            allAccountVideos: videos,
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text('Videolar yüklenemedi: $e'),
          ),
        ],
      ),
    );
  }
}

class _ScorecardBox extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ScorecardBox({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: OmniPulseColors.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: OmniPulseColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: OmniPulseColors.textMutedDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoMetricCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;

  const _VideoMetricCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String pubDateStr = DateFormat('dd MMM yyyy • HH:mm').format(video.publishedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OmniPulseColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OmniPulseColors.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Küçük Kapak Resmi
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 64,
                    height: 84,
                    color: OmniPulseColors.cardElevatedDark,
                    child: video.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            video.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(LucideIcons.video, color: OmniPulseColors.textSecondaryDark),
                          )
                        : const Icon(LucideIcons.video, color: OmniPulseColors.textSecondaryDark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              video.titleOrCaption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: OmniPulseColors.textPrimaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          MultiplierBadge(
                            multiplier: video.performanceMultiplier,
                            tier: video.performanceTier,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$pubDateStr  •  Süre: ${video.durationSeconds} sn  •  Viralite: ${video.viralityScore.toStringAsFixed(0)}/100',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: OmniPulseColors.textSecondaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '🧠 ${video.rootCause.primaryReasonHeadline}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: OmniPulseColors.aiPink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // 5 Temel Metrik Rozeti (👁️ İzlenme, ❤️ Beğeni, 💬 Yorum, 🔄 Paylaşma, 🔖 Kaydetme)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _FiveMetricChip(emoji: '👁️', label: 'İzlenme', value: video.views),
                _FiveMetricChip(emoji: '❤️', label: 'Beğeni', value: video.likes),
                _FiveMetricChip(emoji: '💬', label: 'Yorum', value: video.comments),
                _FiveMetricChip(emoji: '🔄', label: 'Paylaşma', value: video.shares),
                _FiveMetricChip(emoji: '🔖', label: 'Kaydetme', value: video.saves),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FiveMetricChip extends StatelessWidget {
  final String emoji;
  final String label;
  final int value;

  const _FiveMetricChip({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: OmniPulseColors.cardElevatedDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OmniPulseColors.borderDark),
      ),
      child: Text(
        '$emoji ${AppConstants.formatCompactNumber(value)} $label',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: OmniPulseColors.textPrimaryDark,
        ),
      ),
    );
  }
}
