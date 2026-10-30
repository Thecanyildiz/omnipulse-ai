// OmniPulse AI — Bulut Motoru Çalışırken Telefonda Canlı İlerleme Gösteren Bar (app/lib/widgets/sync_progress_bar.dart)
// Örnek Çıktı: "Bulut Motoru Çalışıyor: @hesap_3 analiz ediliyor (3/15) - %20"

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';

class CloudSyncProgressBar extends ConsumerWidget {
  const CloudSyncProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncJobAsync = ref.watch(activeSyncJobStreamProvider);

    return syncJobAsync.when(
      data: (job) {
        if (job == null || !job.isActive) {
          return const SizedBox.shrink();
        }

        final int current = job.processedAccounts;
        final int total = job.totalAccounts > 0 ? job.totalAccounts : 15;
        final int pct = job.progressPercent;
        final String accountLabel = job.currentAccountName.isNotEmpty
            ? job.currentAccountName
            : 'Hesaplar hazırlanıyor';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                OmniPulseColors.aiViolet.withOpacity(0.22),
                OmniPulseColors.aiPink.withOpacity(0.16),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: OmniPulseColors.aiViolet.withOpacity(0.6),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(OmniPulseColors.aiPink),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bulut Motoru Çalışıyor: $accountLabel analiz ediliyor ($current/$total) - %$pct',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: OmniPulseColors.textPrimaryDark,
                      ),
                    ),
                  ),
                  const Icon(
                    LucideIcons.cloudLightning,
                    size: 18,
                    color: OmniPulseColors.aiPink,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: job.totalAccounts > 0 ? job.progressFraction : null,
                  minHeight: 8,
                  backgroundColor: OmniPulseColors.backgroundDark,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    OmniPulseColors.emeraldViral,
                  ),
                ),
              ),
              if (job.statusMessage.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  job.statusMessage,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: OmniPulseColors.textSecondaryDark,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
