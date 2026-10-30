// OmniPulse AI — Sabitler, Sürüm Bilgileri ve Sayı Formatlayıcılar (app/lib/core/constants.dart)

class AppConstants {
  AppConstants._();

  static const String appTitle = 'OmniPulse AI';
  static const String appSubtitle = 'Bulut Tabanlı Otonom Sosyal Medya Komuta Merkezi';

  // Otomatik Güncelleyici (OTA Auto-Updater) için derleme zamanı sürüm sabitleri
  static const int currentBuildNumber = int.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: 1,
  );
  static const String currentVersionTag = String.fromEnvironment(
    'APP_VERSION_TAG',
    defaultValue: 'v1.0.1',
  );

  // Derleme sırasında (--dart-define) gömülen veya Ayarlar ekranından değiştirilebilen varsayılanlar
  static const String _envSupabaseUrl = String.fromEnvironment('DEFAULT_SUPABASE_URL');
  static const String _fallbackSupabaseUrl = 'https://riorunykrmzzlpwqpzyi.supabase.co';
  static String get defaultSupabaseUrl =>
      _envSupabaseUrl.trim().isNotEmpty ? _envSupabaseUrl.trim() : _fallbackSupabaseUrl;

  static const String _envSupabaseAnonKey = String.fromEnvironment('DEFAULT_SUPABASE_ANON_KEY');
  static const String _fallbackSupabaseAnonKey = 'sb_publishable_ZQ8iwJo821rxAA5MzKwIZg_ERIZ1S94';
  static String get defaultSupabaseAnonKey =>
      _envSupabaseAnonKey.trim().isNotEmpty ? _envSupabaseAnonKey.trim() : _fallbackSupabaseAnonKey;

  static const String _envGithubRepo = String.fromEnvironment('DEFAULT_GITHUB_REPO');
  static const String _fallbackGithubRepo = 'Thecanyildiz/omnipulse-ai';
  static String get defaultGithubRepo =>
      _envGithubRepo.trim().isNotEmpty ? _envGithubRepo.trim() : _fallbackGithubRepo;

  static const String defaultGithubWorkflowFile = 'cloud_sync_engine.yml';
  static const String defaultGithubBranch = 'main';

  // Derleme zamanında gömülebilen veya SharedPreferences'tan okunan kimlik anahtarları
  static const String defaultGithubToken = String.fromEnvironment('DEFAULT_GITHUB_TOKEN', defaultValue: '');
  static const String defaultGeminiApiKey = String.fromEnvironment('DEFAULT_GEMINI_API_KEY', defaultValue: '');

  // SharedPreferences Anahtarları
  static const String prefSupabaseUrl = 'omnipulse_supabase_url';
  static const String prefSupabaseAnonKey = 'omnipulse_supabase_anon_key';
  static const String prefGithubToken = 'omnipulse_github_pat_token';
  static const String prefGithubRepo = 'omnipulse_github_repo';
  static const String prefGithubBranch = 'omnipulse_github_branch';
  static const String prefGeminiApiKey = 'omnipulse_gemini_api_key';
  static const String prefThemeMode = 'omnipulse_theme_mode';
  static const String prefAutoUpdateEnabled = 'omnipulse_auto_update_enabled';
  static const String prefLastInstalledTag = 'omnipulse_last_installed_tag';

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

  /// Büyük sayıları okunabilir formata çevirir; küçük sayıları (0-999) tam sayı olarak net gösterir.
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
    return n.round().toString();
  }

  /// Yüzde değişimini işaretli metin olarak döndürür (Örn: 14.2 -> "+%14.2")
  static String formatGrowthPercent(double growth) {
    final String sign = growth > 0 ? '+' : '';
    return '$sign%${growth.toStringAsFixed(1)}';
  }
}
