// OmniPulse AI — Ekran 1: Ana Komuta Paneli (app/lib/screens/master_dashboard.dart)
// Canlı Senkronizasyon Çubuğu, "☁️ Şimdi Analiz Et" bulut tetikleyici, 15 hesabın Toplu Portföy Kartı,
// AI Master Brifing Kutusu, Hızlı Filtre Çipleri ve Hesap Kartları Izgarasını içerir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants.dart';
import '../core/github_trigger.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';
import '../widgets/metric_badge.dart';
import '../widgets/sparkline_card.dart';
import '../widgets/sync_progress_bar.dart';
import 'account_detail.dart';

class MasterDashboardScreen extends ConsumerStatefulWidget {
  const MasterDashboardScreen({super.key});

  @override
  ConsumerState<MasterDashboardScreen> createState() => _MasterDashboardScreenState();
}

class _MasterDashboardScreenState extends ConsumerState<MasterDashboardScreen> {
  bool _isTriggeringCloud = false;

  Future<void> _handleTriggerCloudAnalysis() async {
    setState(() => _isTriggeringCloud = true);
    final totalAccounts = ref.read(portfolioSummaryProvider).totalAccounts;
    final result = await GitHubCloudTriggerService.triggerCloudSync(
      triggeredBy: 'mobile_app',
      totalAccountsEstimate: totalAccounts > 0 ? totalAccounts : 15,
    );
    if (!mounted) return;
    setState(() => _isTriggeringCloud = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.success
            ? OmniPulseColors.emeraldViral
            : OmniPulseColors.coralCritical,
        content: Text(
          result.message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioSummaryProvider);
    final filteredAccounts = ref.watch(filteredAccountsProvider);
    final activeFilter = ref.watch(dashboardFilterProvider);
    final masterBriefAsync = ref.watch(masterBriefingProvider);
    final double screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount = 1;
    if (screenWidth >= 1320) {
      crossAxisCount = 3;
    } else if (screenWidth >= 780) {
      crossAxisCount = 2;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.activity, color: OmniPulseColors.aiViolet, size: 22),
            SizedBox(width: 8),
            Text('OmniPulse Komuta Paneli'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 19),
            tooltip: 'Canlı Verileri Yenile',
            onPressed: () {
              ref.invalidate(accountsStreamProvider);
              ref.invalidate(masterBriefingProvider);
              ref.invalidate(portfolioSummaryProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Veriler yenilendi.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _isTriggeringCloud ? null : _handleTriggerCloudAnalysis,
              style: FilledButton.styleFrom(
                backgroundColor: OmniPulseColors.aiViolet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isTriggeringCloud
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.cloud, size: 17),
              label: const Text(
                '☁️ Şimdi Analiz Et',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsStreamProvider);
          ref.invalidate(masterBriefingProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Canlı Bulut Senkronizasyon İlerleme Çubuğu
            const CloudSyncProgressBar(),

            // 2. Toplu Portföy Kartı (15 Hesabın Özeti)
            Container(
              padding: const EdgeInsets.all(18),
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
                      Text(
                        'TOPLU PORTFÖY ÖZETİ (${portfolio.totalAccounts} HESAP)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: OmniPulseColors.textSecondaryDark,
                        ),
                      ),
                      GrowthPercentBadge(
                        growthPercent: portfolio.avgFollowerGrowth7d,
                        suffixLabel: '7 Günlük Net',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 24,
                    runSpacing: 14,
                    children: [
                      _PortfolioMetricTile(
                        label: 'Toplam Takipçi',
                        value: AppConstants.formatCompactNumber(portfolio.totalFollowers),
                        icon: LucideIcons.users,
                        color: OmniPulseColors.oceanNormal,
                      ),
                      _PortfolioMetricTile(
                        label: 'Toplam İzlenme',
                        value: AppConstants.formatCompactNumber(portfolio.totalViews),
                        icon: LucideIcons.eye,
                        color: OmniPulseColors.emeraldViral,
                      ),
                      _PortfolioMetricTile(
                        label: 'Ortalama Etkileşim (ER)',
                        value: '%${portfolio.avgEngagementRate.toStringAsFixed(2)}',
                        icon: LucideIcons.flame,
                        color: OmniPulseColors.aiPink,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. AI Master Brifing Kutusu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    OmniPulseColors.aiViolet.withOpacity(0.18),
                    OmniPulseColors.aiPink.withOpacity(0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OmniPulseColors.aiViolet.withOpacity(0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.sparkles, color: OmniPulseColors.aiPink, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'OTONOM AI MASTER BRİFİNG',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: OmniPulseColors.textPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  masterBriefAsync.when(
                    data: (text) => Text(
                      text,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: OmniPulseColors.textPrimaryDark,
                      ),
                    ),
                    loading: () => const Text(
                      'Portföy brifingi hazırlanıyor...',
                      style: TextStyle(color: OmniPulseColors.textSecondaryDark),
                    ),
                    error: (e, _) => Text(
                      'Brifing yüklenemedi: $e',
                      style: const TextStyle(color: OmniPulseColors.amberWarning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. Hızlı Filtre Çipleri
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChipItem(
                    label: 'Tümü (${portfolio.totalAccounts})',
                    value: 'all',
                    selectedValue: activeFilter,
                    onSelect: (v) => ref.read(dashboardFilterProvider.notifier).state = v,
                  ),
                  const SizedBox(width: 8),
                  _FilterChipItem(
                    label: 'TikTok',
                    value: 'tiktok',
                    selectedValue: activeFilter,
                    onSelect: (v) => ref.read(dashboardFilterProvider.notifier).state = v,
                  ),
                  const SizedBox(width: 8),
                  _FilterChipItem(
                    label: 'Instagram',
                    value: 'instagram',
                    selectedValue: activeFilter,
                    onSelect: (v) => ref.read(dashboardFilterProvider.notifier).state = v,
                  ),
                  const SizedBox(width: 8),
                  _FilterChipItem(
                    label: 'YouTube',
                    value: 'youtube',
                    selectedValue: activeFilter,
                    onSelect: (v) => ref.read(dashboardFilterProvider.notifier).state = v,
                  ),
                  const SizedBox(width: 8),
                  _FilterChipItem(
                    label: '🔥 Yükselenler',
                    value: 'surging',
                    selectedValue: activeFilter,
                    onSelect: (v) => ref.read(dashboardFilterProvider.notifier).state = v,
                  ),
                  const SizedBox(width: 8),
                  _FilterChipItem(
                    label: '📉 Düşüştekiler',
                    value: 'declining',
                    selectedValue: activeFilter,
                    onSelect: (v) => ref.read(dashboardFilterProvider.notifier).state = v,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. Hesap Kartları Izgarası
            if (filteredAccounts.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: OmniPulseColors.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OmniPulseColors.borderDark),
                ),
                child: const Column(
                  children: [
                    Icon(LucideIcons.folderPlus, size: 40, color: OmniPulseColors.textSecondaryDark),
                    SizedBox(height: 12),
                    Text(
                      'Bu filtrede gösterilecek hesap bulunamadı.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: OmniPulseColors.textPrimaryDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Alt menüdeki "Hesaplar & Ayar" sekmesinden 15+ TikTok, Instagram veya YouTube hesabınızı ekleyebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: OmniPulseColors.textSecondaryDark),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredAccounts.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 205,
                ),
                itemBuilder: (context, index) {
                  final acc = filteredAccounts[index];
                  return SparklineAccountCard(
                    account: acc,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AccountDetailScreen(account: acc),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PortfolioMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: OmniPulseColors.textSecondaryDark,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: OmniPulseColors.textPrimaryDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onSelect;

  const _FilterChipItem({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = value == selectedValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(value),
      selectedColor: OmniPulseColors.aiViolet.withOpacity(0.3),
      backgroundColor: OmniPulseColors.cardDark,
      side: BorderSide(
        color: isSelected ? OmniPulseColors.aiViolet : OmniPulseColors.borderDark,
      ),
    );
  }
}
