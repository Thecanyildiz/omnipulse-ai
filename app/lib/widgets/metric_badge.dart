// OmniPulse AI — Yeşil/Kırmızı Büyüme, Sağlık ve Medyan Çarpanı (3.4x 🔥) Rozetleri (app/lib/widgets/metric_badge.dart)

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';

class MultiplierBadge extends StatelessWidget {
  final double multiplier;
  final String? tier;
  final bool compact;

  const MultiplierBadge({
    super.key,
    required this.multiplier,
    this.tier,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String emoji;

    if (multiplier >= 2.5 || tier == 'viral_hit') {
      color = OmniPulseColors.emeraldViral;
      emoji = '🔥';
    } else if (multiplier >= 1.3 || tier == 'above_average') {
      color = OmniPulseColors.emeraldViral;
      emoji = '🟢';
    } else if (multiplier >= 0.7 || tier == 'normal') {
      color = OmniPulseColors.oceanNormal;
      emoji = '⚪';
    } else if (multiplier >= 0.35 || tier == 'underperforming') {
      color = OmniPulseColors.amberWarning;
      emoji = '🟡';
    } else {
      color = OmniPulseColors.coralCritical;
      emoji = '🔴';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.45), width: 1),
      ),
      child: Text(
        '${multiplier.toStringAsFixed(1)}x $emoji',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 11.5 : 12.5,
        ),
      ),
    );
  }
}

class GrowthPercentBadge extends StatelessWidget {
  final double growthPercent;
  final String suffixLabel;

  const GrowthPercentBadge({
    super.key,
    required this.growthPercent,
    this.suffixLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final bool isPositive = growthPercent >= 0;
    final Color badgeColor = isPositive
        ? OmniPulseColors.emeraldViral
        : OmniPulseColors.coralCritical;
    final String indicator = isPositive ? '🟢' : '🔴';
    final String text = AppConstants.formatGrowthPercent(growthPercent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.4)),
      ),
      child: Text(
        '$text $indicator${suffixLabel.isNotEmpty ? " $suffixLabel" : ""}',
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PlatformBadge extends StatelessWidget {
  final String platform;

  const PlatformBadge({super.key, required this.platform});

  @override
  Widget build(BuildContext context) {
    final Color color = OmniPulseColors.platformColor(platform);
    final String label = platform.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
