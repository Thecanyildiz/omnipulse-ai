// OmniPulse AI — Ekran 4: Otonom AI Strateji, Rakip Radarı ve Fikir Merkezi (app/lib/screens/ai_strategy_hub.dart)
// Üstte Hesap Seçici Dropdown; altında 3 Sekme:
// Sekme 1: Otonom Rakip Radarı ("Neden Patladı?" & "Onu Nasıl Geçersin?")
// Sekme 2: Hashtag Performans Matrisi (Yeşil Booster, Gri Nötr, Kırmızı Drag, Mor Trend + Kopyala Butonu)
// Sekme 3: Sıradaki 5 Video & İlk 3 Saniye Kanca (Hook) Üretici

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/account_model.dart';
import '../models/ai_report_model.dart';
import '../models/competitor_model.dart';
import '../providers/app_providers.dart';
import '../widgets/metric_badge.dart';

class AiStrategyHubScreen extends ConsumerWidget {
  const AiStrategyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final selectedId = ref.watch(selectedStrategyAccountIdProvider);

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Otonom AI Strateji Merkezi')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz aktif hesap bulunmuyor. Lütfen önce "Hesaplar & Ayar" sekmesinden hesap ekleyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: OmniPulseColors.textSecondaryDark),
                ),
              ),
            ),
          );
        }

        final AccountModel activeAccount = accounts.firstWhere(
          (a) => a.id == selectedId,
          orElse: () => accounts.first,
        );

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Otonom AI Strateji & Rakip Merkezi'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(112),
                child: Column(
                  children: [
                    // Hesap Seçici Dropdown
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: OmniPulseColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: OmniPulseColors.borderDark),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: activeAccount.id,
                            isExpanded: true,
                            dropdownColor: OmniPulseColors.cardElevatedDark,
                            items: accounts.map((acc) {
                              return DropdownMenuItem<String>(
                                value: acc.id,
                                child: Row(
                                  children: [
                                    PlatformBadge(platform: acc.platform),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '@${acc.username}  •  Niş: ${acc.detectedNiche}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newId) {
                              if (newId != null) {
                                ref.read(selectedStrategyAccountIdProvider.notifier).state = newId;
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const TabBar(
                      indicatorColor: OmniPulseColors.aiPink,
                      labelColor: OmniPulseColors.textPrimaryDark,
                      unselectedLabelColor: OmniPulseColors.textSecondaryDark,
                      tabs: [
                        Tab(icon: Icon(LucideIcons.radar, size: 18), text: 'Otonom Rakipler'),
                        Tab(icon: Icon(LucideIcons.hash, size: 18), text: 'Hashtag Matrisi'),
                        Tab(icon: Icon(LucideIcons.Lightbulb, size: 18), text: '5 Video & Kanca'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            body: TabBarView(
              children: [
                _AutonomousCompetitorRadarTab(account: activeAccount),
                _HashtagPerformanceMatrixTab(account: activeAccount),
                _Next5VideoBlueprintsTab(account: activeAccount),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
    );
  }
}

// ============================================================================
// SEKME 1: Otonom Rakip Radarı
// ============================================================================
class _AutonomousCompetitorRadarTab extends ConsumerWidget {
  final AccountModel account;

  const _AutonomousCompetitorRadarTab({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitorsAsync = ref.watch(accountCompetitorsProvider(account.id));
    final strategyAsync = ref.watch(accountStrategyReportProvider(account.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Otonom Tespit Edilen Niş ve Arama Kelimeleri Kutusu
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: OmniPulseColors.aiAutonomousGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.sparkles, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'SIFIR MANUEL EKLEME — OTONOM NİŞ & RAKİP RADARI',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tespit Edilen Niş: ${account.detectedNiche}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (account.nicheSearchKeywords.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: account.nicheSearchKeywords.map((kw) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🔍 $kw',
                        style: const TextStyle(fontSize: 11.5, color: Colors.white),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // AI Rakip Fark Özeti (Competitor Gap Summary)
        strategyAsync.when(
          data: (report) {
            if (report == null || report.competitorGapSummary.isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OmniPulseColors.cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OmniPulseColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚔️ RAKİPLERİ GEÇMEK İÇİN YARIN DEĞİŞTİRİLECEK 3 SOMUT FARK',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: OmniPulseColors.emeraldViral,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.competitorGapSummary,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: OmniPulseColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        competitorsAsync.when(
          data: (competitors) {
            if (competitors.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: OmniPulseColors.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OmniPulseColors.borderDark),
                ),
                child: const Text(
                  'Henüz otonom rakip videosu taranmadı. Bulut motoru çalıştığında aynı nişteki en viral 5 rakip video otomatik olarak buraya düşer.',
                  style: TextStyle(color: OmniPulseColors.textSecondaryDark),
                ),
              );
            }

            return Column(
              children: competitors.map((comp) => _CompetitorCard(comp: comp)).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Rakip verileri alınamadı: $e'),
        ),
      ],
    );
  }
}

class _CompetitorCard extends StatelessWidget {
  final CompetitorVideoModel comp;

  const _CompetitorCard({required this.comp});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              Row(
                children: [
                  PlatformBadge(platform: comp.platform),
                  const SizedBox(width: 8),
                  Text(
                    '@${comp.competitorUsername}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: OmniPulseColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: OmniPulseColors.emeraldViral.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Viralite: ${comp.viralityScore.toStringAsFixed(0)}/100 🔥',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OmniPulseColors.emeraldViral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comp.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              color: OmniPulseColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                '👁️ ${AppConstants.formatCompactNumber(comp.views)} İzlenme',
                style: const TextStyle(fontSize: 12, color: OmniPulseColors.textSecondaryDark),
              ),
              Text(
                '❤️ ${AppConstants.formatCompactNumber(comp.likes)} Beğeni',
                style: const TextStyle(fontSize: 12, color: OmniPulseColors.textSecondaryDark),
              ),
              Text(
                '🔖 ${AppConstants.formatCompactNumber(comp.saves)} Kaydetme',
                style: const TextStyle(fontSize: 12, color: OmniPulseColors.textSecondaryDark),
              ),
              Text(
                '🔄 ${AppConstants.formatCompactNumber(comp.shares)} Paylaşım',
                style: const TextStyle(fontSize: 12, color: OmniPulseColors.textSecondaryDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OmniPulseColors.cardElevatedDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔥 NEDEN PATLADI?',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: OmniPulseColors.amberWarning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comp.aiWhyItWentViral,
                  style: const TextStyle(fontSize: 12.5, color: OmniPulseColors.textPrimaryDark),
                ),
                const SizedBox(height: 10),
                const Text(
                  '🚀 ONU NASIL GEÇERSİN?',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: OmniPulseColors.emeraldViral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comp.aiHowToBeatIt,
                  style: const TextStyle(fontSize: 12.5, color: OmniPulseColors.textPrimaryDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(comp.videoUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(LucideIcons.externalLink, size: 16),
              label: const Text('Rakip Videoyu İzle'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEKME 2: Hashtag Performans Matrisi
// ============================================================================
class _HashtagPerformanceMatrixTab extends ConsumerWidget {
  final AccountModel account;

  const _HashtagPerformanceMatrixTab({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hashtagsAsync = ref.watch(accountHashtagsProvider(account.id));
    final reportAsync = ref.watch(accountStrategyReportProvider(account.id));

    return hashtagsAsync.when(
      data: (hashtags) {
        final boosters = hashtags.where((h) => h.statusCategory == 'booster').toList();
        final neutrals = hashtags.where((h) => h.statusCategory == 'neutral').toList();
        final drags = hashtags.where((h) => h.statusCategory == 'drag').toList();
        final trendTags = reportAsync.valueOrNull?.newCompetitorTrends ?? const <String>[];

        final List<String> bestTagSet = [
          ...boosters.take(5).map((e) => e.hashtag),
          ...trendTags.take(4),
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: () {
                final copyStr = bestTagSet.isNotEmpty
                    ? bestTagSet.join(' ')
                    : '#keşfet #viral #${account.username}';
                Clipboard.setData(ClipboardData(text: copyStr));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: OmniPulseColors.emeraldViral,
                    content: Text('En iyi etiket seti panoya kopyalandı: $copyStr'),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: OmniPulseColors.emeraldViral,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(LucideIcons.copy, size: 18),
              label: const Text(
                'En İyi Etiket Setini Kopyala',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 16),

            _HashtagGroupCard(
              title: '🟢 İZLENMEYİ ARTIRANLAR (BOOSTER — LIFT ≥ 1.35x)',
              subtitle: 'Bu etiketler kullanıldığında izlenmeler kanal medyanının üstüne çıkıyor.',
              color: OmniPulseColors.emeraldViral,
              items: boosters,
            ),
            const SizedBox(height: 14),

            _TrendHashtagCard(trendTags: trendTags),
            const SizedBox(height: 14),

            _HashtagGroupCard(
              title: '⚪ NÖTR ETİKETLER (0.75x ≤ LIFT < 1.35x)',
              subtitle: 'Kanal ortalamasında seyreden standart etiketler.',
              color: OmniPulseColors.textSecondaryDark,
              items: neutrals,
            ),
            const SizedBox(height: 14),

            _HashtagGroupCard(
              title: '🔴 BIRAKILMASI GEREKEN ÖLÜ ETİKETLER (DRAG — LIFT < 0.75x)',
              subtitle: 'Bu etiketlerin kullanıldığı videolar kanal medyanının altında kaldı.',
              color: OmniPulseColors.coralCritical,
              items: drags,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hashtag matrisi yüklenemedi: $e')),
    );
  }
}

class _HashtagGroupCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<HashtagMetricModel> items;

  const _HashtagGroupCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OmniPulseColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OmniPulseColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: OmniPulseColors.textSecondaryDark),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              'Bu kategoride etiket bulunmuyor.',
              style: TextStyle(fontSize: 12.5, color: OmniPulseColors.textMutedDark),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((h) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.45)),
                  ),
                  child: Text(
                    '${h.hashtag}  •  ${h.liftMultiplier.toStringAsFixed(2)}x (${AppConstants.formatCompactNumber(h.avgViewsWhenUsed)} ort.)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _TrendHashtagCard extends StatelessWidget {
  final List<String> trendTags;

  const _TrendHashtagCard({required this.trendTags});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OmniPulseColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OmniPulseColors.aiViolet.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✨ RAKİPLERDEN BULUNAN YENİ TREND ETİKETLER',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: OmniPulseColors.aiPink,
            ),
          ),
          const SizedBox(height: 8),
          if (trendTags.isEmpty)
            const Text(
              'Otonom rakip taraması sonrasında yeni trend etiketler burada listelenir.',
              style: TextStyle(fontSize: 12, color: OmniPulseColors.textSecondaryDark),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: trendTags.map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: OmniPulseColors.aiViolet.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: OmniPulseColors.aiPink.withOpacity(0.45)),
                  ),
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OmniPulseColors.aiPink,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEKME 3: Sıradaki 5 Video & İlk 3 Saniye Kanca (Hook) Üretici
// ============================================================================
class _Next5VideoBlueprintsTab extends ConsumerWidget {
  final AccountModel account;

  const _Next5VideoBlueprintsTab({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(accountStrategyReportProvider(account.id));

    return reportAsync.when(
      data: (report) {
        final blueprints = report?.next5VideoBlueprints ?? const <VideoBlueprintModel>[];
        if (blueprints.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Bu hesap için henüz 5 video kanca reçetesi oluşturulmadı. Komuta Panelinden "☁️ Şimdi Analiz Et" butonuna basarak AI üretimini başlatabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: OmniPulseColors.textSecondaryDark),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: blueprints.length,
          itemBuilder: (context, index) {
            final bp = blueprints[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: OmniPulseColors.aiAutonomousGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'VİDEO FİKRİ #${bp.ideaNumber}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        '⏱️ İdeal Süre: ${bp.optimalDurationSeconds} sn  •  Hedef: ${bp.targetAlgorithmMetric} (${bp.expectedMultiplierPotential})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: OmniPulseColors.emeraldViral,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bp.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: OmniPulseColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OmniPulseColors.cardElevatedDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: OmniPulseColors.aiPink.withOpacity(0.45)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎙️ İLK 3 SANİYEDE SÖYLENECEK BİREBİR KANCA (HOOK) CÜMLESİ:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: OmniPulseColors.aiPink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '"${bp.first3SecondsHook}"',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: OmniPulseColors.textPrimaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '🎬 İlk 3 Saniye Görsel Kurgu: ${bp.visualDirection}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: OmniPulseColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fikirler yüklenemedi: $e')),
    );
  }
}
