// OmniPulse AI — Riverpod State Management & Supabase Realtime Dinleyicileri (app/lib/providers/app_providers.dart)
// Canlı bulut senkronizasyon çubuğu (sync_jobs), 15+ hesap portföyü, zaman serisi snapshot'lar,
// videolar, otonom rakipler ve AI strateji raporlarını yönetir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_model.dart';
import '../models/video_model.dart';
import '../models/competitor_model.dart';
import '../models/ai_report_model.dart';

/// Tema Modu Sağlayıcısı (OLED Dark varsayılan)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// Ana Komuta Paneli Filtre Seçimi ('all', 'tiktok', 'instagram', 'youtube', 'surging', 'declining')
final dashboardFilterProvider = StateProvider<String>((ref) => 'all');

/// AI Strateji Merkezinde seçili olan hesabın UUID'si
final selectedStrategyAccountIdProvider = StateProvider<String?>((ref) => null);

/// Supabase bağlantısının aktif olup olmadığını kontrol eden yardımcı
bool isSupabaseReady() {
  try {
    Supabase.instance.client;
    return true;
  } catch (_) {
    return false;
  }
}

/// 1. CANLI SENKRONİZASYON İLERLEME DİNLEYİCİSİ (Supabase Realtime sync_jobs)
final activeSyncJobStreamProvider = StreamProvider<SyncJobModel?>((ref) {
  if (!isSupabaseReady()) {
    return Stream.value(null);
  }
  final client = Supabase.instance.client;
  return client
      .from('sync_jobs')
      .stream(primaryKey: ['id'])
      .order('started_at', ascending: false)
      .limit(1)
      .map((rows) {
        if (rows.isEmpty) return null;
        return SyncJobModel.fromJson(rows.first);
      });
});

/// 2. HESAPLAR LİSTESİ CANLI DİNLEYİCİSİ (Supabase Realtime accounts)
/// Önce hızlı HTTPS REST ile anında veriyi doldurur, ardından Realtime Stream'i dinler.
final accountsStreamProvider = StreamProvider<List<AccountModel>>((ref) async* {
  if (!isSupabaseReady()) {
    yield const <AccountModel>[];
    return;
  }
  final client = Supabase.instance.client;

  // 1. ADIM: Masaüstü / mobil açılır açılmaz doğrudan REST ile anında verileri getir
  try {
    final initialRows = await client
        .from('accounts')
        .select('*')
        .eq('is_active', true)
        .order('created_at', ascending: true);
    final initialList = (initialRows as List)
        .map((r) => AccountModel.fromJson(r as Map<String, dynamic>))
        .toList();
    if (initialList.isNotEmpty) {
      yield initialList;
    }
  } catch (e) {
    debugPrint('İlk hesap yükleme hatası: ' + e.toString());
  }

  // 2. ADIM: Canlı Realtime Değişiklik Akışını Dinle
  try {
    final stream = client
        .from('accounts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((rows) {
          return rows
              .where((r) => (r['is_active'] as bool? ?? true))
              .map((r) => AccountModel.fromJson(r))
              .toList();
        });

    await for (final accounts in stream) {
      yield accounts;
    }
  } catch (e) {
    debugPrint('Supabase realtime stream hatası: ' + e.toString());
  }
});

/// Filtrelenmiş Hesaplar Listesi Sağlayıcısı
final filteredAccountsProvider = Provider<List<AccountModel>>((ref) {
  final accountsAsync = ref.watch(accountsStreamProvider);
  final filter = ref.watch(dashboardFilterProvider);
  final accounts = accountsAsync.valueOrNull ?? const <AccountModel>[];

  switch (filter) {
    case 'tiktok':
    case 'instagram':
    case 'youtube':
      return accounts.where((a) => a.platform == filter).toList();
    case 'surging':
      return accounts
          .where((a) =>
              a.healthStatus == 'surging' ||
              a.healthStatus == 'growing' ||
              a.latestVideoMultiplier >= 1.3)
          .toList();
    case 'declining':
      return accounts
          .where((a) =>
              a.healthStatus == 'declining' ||
              a.healthStatus == 'anomaly_drop' ||
              a.latestVideoMultiplier < 0.7)
          .toList();
    default:
      return accounts;
  }
});

/// 3. TOPLU PORTFÖY ÖZETİ HESAPLAYICISI
class PortfolioSummaryStats {
  final int totalAccounts;
  final int totalFollowers;
  final int totalViews;
  final double avgEngagementRate;
  final double avgFollowerGrowth7d;

  const PortfolioSummaryStats({
    required this.totalAccounts,
    required this.totalFollowers,
    required this.totalViews,
    required this.avgEngagementRate,
    required this.avgFollowerGrowth7d,
  });
}

final portfolioSummaryProvider = Provider<PortfolioSummaryStats>((ref) {
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const <AccountModel>[];
  if (accounts.isEmpty) {
    return const PortfolioSummaryStats(
      totalAccounts: 0,
      totalFollowers: 0,
      totalViews: 0,
      avgEngagementRate: 0.0,
      avgFollowerGrowth7d: 0.0,
    );
  }
  final totalF = accounts.fold<int>(0, (sum, a) => sum + a.currentFollowers);
  final totalV = accounts.fold<int>(0, (sum, a) => sum + a.currentTotalViews);
  final avgEr = accounts.fold<double>(0.0, (sum, a) => sum + a.currentEngagementRate) /
      accounts.length;
  final avgG7d = accounts.fold<double>(0.0, (sum, a) => sum + a.followerGrowth7d) /
      accounts.length;

  return PortfolioSummaryStats(
    totalAccounts: accounts.length,
    totalFollowers: totalF,
    totalViews: totalV,
    avgEngagementRate: avgEr,
    avgFollowerGrowth7d: avgG7d,
  );
});

/// 4. AI MASTER BRİFİNG SAĞLAYICISI (15 Hesabın Genel Özeti)
final masterBriefingProvider = FutureProvider<String>((ref) async {
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const <AccountModel>[];
  if (!isSupabaseReady()) {
    return 'Supabase bulut bağlantısı henüz yapılandırılmadı. Ayarlar ekranından Supabase URL ve Key bilgilerinizi girerek canlı senkronizasyonu başlatabilirsiniz.';
  }
  try {
    final client = Supabase.instance.client;
    final rows = await client
        .from('ai_strategy_reports')
        .select('executive_summary')
        .eq('report_type', 'master_briefing')
        .order('created_at', ascending: false)
        .limit(1);

    if (rows.isNotEmpty && (rows.first['executive_summary'] ?? '').toString().isNotEmpty) {
      return rows.first['executive_summary'].toString();
    }
  } catch (_) {}

  if (accounts.isEmpty) {
    return 'Portföyünüzde henüz hesap bulunmuyor. Ayarlar sekmesinden TikTok, Instagram ve YouTube hesaplarınızı ekleyip sağ üstteki "☁️ Şimdi Analiz Et" butonuna dokunun.';
  }

  final sortedByMult = [...accounts]
    ..sort((a, b) => b.latestVideoMultiplier.compareTo(a.latestVideoMultiplier));
  final best = sortedByMult.first;
  final worst = sortedByMult.last;
  return 'Portföydeki ${accounts.length} aktif hesap izleniyor. '
      '@${best.username} (${best.platform.toUpperCase()}) son videosunda ${best.latestVideoMultiplier.toStringAsFixed(1)}x medyan çarpanıyla lider durumda. '
      '@${worst.username} hesabında ise etkileşim ivmesini artırmak için bugün AI Strateji Merkezindeki ilk 3 saniye kanca reçetelerinden birini uygulamanız önerilir.';
});

/// 5. TEKİL HESAP ZAMAN SERİSİ SNAPSHOT SAĞLAYICISI
final accountSnapshotsProvider =
    FutureProvider.family<List<AccountSnapshotModel>, String>((ref, accountId) async {
  if (!isSupabaseReady() || accountId.isEmpty) return const [];
  final client = Supabase.instance.client;
  final rows = await client
      .from('account_snapshots')
      .select('*')
      .eq('account_id', accountId)
      .order('recorded_at', ascending: true)
      .limit(90);
  return rows.map((r) => AccountSnapshotModel.fromJson(r)).toList();
});

/// 6. TEKİL HESAP VİDEOLARI SAĞLAYICISI
final accountVideosProvider =
    FutureProvider.family<List<VideoModel>, String>((ref, accountId) async {
  if (!isSupabaseReady() || accountId.isEmpty) return const [];
  final client = Supabase.instance.client;
  final rows = await client
      .from('videos')
      .select('*')
      .eq('account_id', accountId)
      .order('published_at', ascending: false)
      .limit(25);
  return rows.map((r) => VideoModel.fromJson(r)).toList();
});

/// 7. OTONOM KEŞFEDİLEN RAKİPLER SAĞLAYICISI
final accountCompetitorsProvider =
    FutureProvider.family<List<CompetitorVideoModel>, String>((ref, accountId) async {
  if (!isSupabaseReady() || accountId.isEmpty) return const [];
  final client = Supabase.instance.client;
  final rows = await client
      .from('autonomous_competitors')
      .select('*')
      .eq('target_account_id', accountId)
      .order('virality_score', ascending: false)
      .limit(10);
  return rows.map((r) => CompetitorVideoModel.fromJson(r)).toList();
});

/// 8. HASHTAG PERFORMANS MATRİSİ SAĞLAYICISI
final accountHashtagsProvider =
    FutureProvider.family<List<HashtagMetricModel>, String>((ref, accountId) async {
  if (!isSupabaseReady() || accountId.isEmpty) return const [];
  final client = Supabase.instance.client;
  final rows = await client
      .from('hashtag_analytics')
      .select('*')
      .eq('account_id', accountId)
      .order('lift_multiplier', ascending: false)
      .limit(40);
  return rows.map((r) => HashtagMetricModel.fromJson(r)).toList();
});

/// 9. TEKİL HESAP DERİN AI STRATEJİ RAPORU SAĞLAYICISI
final accountStrategyReportProvider =
    FutureProvider.family<AiStrategyReportModel?, String>((ref, accountId) async {
  if (!isSupabaseReady() || accountId.isEmpty) return null;
  final client = Supabase.instance.client;
  final rows = await client
      .from('ai_strategy_reports')
      .select('*')
      .eq('account_id', accountId)
      .eq('report_type', 'account_deep_strategy')
      .order('created_at', ascending: false)
      .limit(1);
  if (rows.isEmpty) return null;
  return AiStrategyReportModel.fromJson(rows.first);
});

/// 10. HESAP EKLEME / SİLME / MOD DEĞİŞTİRME SERVİSİ
class AccountsRepository {
  static Future<void> addOrUpdateAccount({
    required String platform,
    required String username,
    required String categoryTag,
    required String fetchMode,
    required Map<String, dynamic> authCredentials,
  }) async {
    final cleanUsername = username.trim().replaceAll('@', '');
    if (cleanUsername.isEmpty) {
      throw ArgumentError('Kullanıcı adı boş olamaz.');
    }
    final client = Supabase.instance.client;
    await client.from('accounts').upsert(
      {
        'platform': platform.toLowerCase().trim(),
        'username': cleanUsername,
        'display_name': cleanUsername,
        'category_tag': categoryTag.trim().isEmpty ? 'Genel' : categoryTag.trim(),
        'fetch_mode': fetchMode,
        'auth_credentials': authCredentials,
        'is_active': true,
      },
      onConflict: 'platform,username',
    );
  }

  static Future<void> updateAccountFetchMode({
    required String accountId,
    required String fetchMode,
    Map<String, dynamic>? authCredentials,
  }) async {
    final client = Supabase.instance.client;
    final payload = <String, dynamic>{'fetch_mode': fetchMode};
    if (authCredentials != null) {
      payload['auth_credentials'] = authCredentials;
    }
    await client.from('accounts').update(payload).eq('id', accountId);
  }

  static Future<void> deleteAccount(String accountId) async {
    final client = Supabase.instance.client;
    await client.from('accounts').delete().eq('id', accountId);
  }
}
