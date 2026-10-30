// OmniPulse AI — Sabitler ve Varsayılan Yapılandırma Anahtarları (app/lib/core/constants.dart)

class AppConstants {
  AppConstants._();

  static const String appTitle = 'OmniPulse AI';
  static const String appSubtitle = 'Bulut Tabanlı Otonom Sosyal Medya Komuta Merkezi';

  // Derleme sırasında (--dart-define) gömülen veya Ayarlar ekranından değiştirilebilen varsayılanlar
  static const String defaultSupabaseUrl = String.fromEnvironment(
    'DEFAULT_SUPABASE_URL',
    defaultValue: 'https://riorunykrmzzlpwqpzyi.supabase.co',
  );
  static const String defaultSupabaseAnonKey = String.fromEnvironment(
    'DEFAULT_SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_ZQ8iwJo821rxAA5MzKwIZg_ERIZ1S94',
  );
  static const String defaultGithubRepo = String.fromEnvironment(
    'DEFAULT_GITHUB_REPO',
    defaultValue: 'Thecanyildiz/omnipulse-ai',
  );
  static const String defaultGithubWorkflowFile = 'cloud_sync_engine.yml';
  static const String defaultGithubBranch = 'main';

  // SharedPreferences Anahtarları
  static const String prefSupabaseUrl = 'omnipulse_supabase_url';
  static const String prefSupabaseAnonKey = 'omnipulse_supabase_anon_key';
  static const String prefGithubToken = 'omnipulse_github_pat_token';
  static const String prefGithubRepo = 'omnipulse_github_repo';
  static const String prefGithubBranch = 'omnipulse_github_branch';
  static const String prefGeminiApiKey = 'omnipulse_gemini_api_key';
  static const String prefThemeMode = 'omnipulse_theme_mode';

  // Responsive Kırılım Noktası (Mobil < 860px <= Masaüstü)
  static const double desktopBreakpoint = 860.0;

  // Desteklenen Platformlar
  static const List<String> supportedPlatforms = ['tiktok', 'instagram', 'youtube'];

  // Hazır Kategori Etiketleri
  static const List<String> defaultCategories = [
    'Genel',
    'Eğitim & Teknoloji',
    'Finans & Kripto',
    'E-Ticaret & Ürün',
    'Oyun & Eğlence',
    'Yemek & Tarif',
    'Spor & Sağlık',
    'Motivasyon & Kişisel Gelişim',
  ];

  /// Büyük sayıları okunabilir formata çevirir (Örn: 142500 -> "142.5K", 2400000 -> "2.4M")
  static String formatCompactNumber(num value) {
    final double n = value.toDouble();
    if (n.abs() >= 1000000000) {
      return '${(n / 1000000000).toStringAsFixed(1)}B';
    }
    if (n.abs() >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }
    if (n.abs() >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toInt().toString();
  }

  /// Yüzde değişimini işaretli metin olarak döndürür (Örn: 14.2 -> "+%14.2")
  static String formatGrowthPercent(double growth) {
    final String sign = growth > 0 ? '+' : '';
    return '$sign%${growth.toStringAsFixed(1)}';
  }
}
