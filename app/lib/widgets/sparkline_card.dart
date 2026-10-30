// OmniPulse AI — Hesap Kartı ve 7 Günlük Mini Çizgi Grafik (app/lib/widgets/sparkline_card.dart)
// Avatar, platform ikonu, takipçi sayısı, fl_chart Sparkline, sağlık rozeti ve son video çarpanını içerir.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/account_model.dart';
import 'metric_badge.dart';

class SparklineAccountCard extends StatelessWidget {
  final AccountModel account;
  final VoidCallback onTap;

  const SparklineAccountCard({
    super.key,
    required this.account,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color lineColor = account.followerGrowth7d >= 0
        ? OmniPulseColors.emeraldViral
        : OmniPulseColors.coralCritical;
    final Color healthColor = OmniPulseColors.tierColor(account.healthStatus);

    final List<double> points = account.recentSparklinePoints.isNotEmpty
        ? account.recentSparklinePoints
        : [100, 102, 104, 103, 108, 112, 115];

    final double minY = points.reduce((a, b) => a < b ? a : b) * 0.98;
    final double maxY = points.reduce((a, b) => a > b ? a : b) * 1.02;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OmniPulseColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OmniPulseColors.borderDark, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: Avatar + Kullanıcı Adı + Platform Rozeti + Son Video Çarpanı
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: OmniPulseColors.platformColor(account.platform).withOpacity(0.2),
                  backgroundImage:
                      account.avatarUrl.isNotEmpty ? NetworkImage(account.avatarUrl) : null,
                  child: account.avatarUrl.isEmpty
                      ? Text(
                          account.username.isNotEmpty
                              ? account.username[0].toUpperCase()
                              : 'A',
                          style: TextStyle(
                            color: OmniPulseColors.platformColor(account.platform),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${account.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: OmniPulseColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          PlatformBadge(platform: account.platform),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              account.categoryTag,
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
                    ],
                  ),
                ),
                MultiplierBadge(
                  multiplier: account.latestVideoMultiplier,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Orta Satır: Takipçi Sayısı + 7 Günlük Sparkline Grafiği
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Takipçi',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: OmniPulseColors.textSecondaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppConstants.formatCompactNumber(account.currentFollowers),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: OmniPulseColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GrowthPercentBadge(
                        growthPercent: account.followerGrowth7d,
                        suffixLabel: '7g',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: SizedBox(
                    height: 52,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (points.length - 1).toDouble(),
                        minY: minY == maxY ? minY - 1 : minY,
                        maxY: minY == maxY ? maxY + 1 : maxY,
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List<FlSpot>.generate(
                              points.length,
                              (i) => FlSpot(i.toDouble(), points[i]),
                            ),
                            isCurved: true,
                            color: lineColor,
                            barWidth: 2.4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: lineColor.withOpacity(0.14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Alt Satır: Sağlık Rozeti + Etkileşim Oranı + Viralite Puanı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: healthColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    account.healthLabelTr,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: healthColor,
                    ),
                  ),
                ),
                Text(
                  'ER: %${account.currentEngagementRate.toStringAsFixed(1)}  •  Viral: ${account.currentViralityScore.toStringAsFixed(0)}/100',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: OmniPulseColors.textSecondaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
