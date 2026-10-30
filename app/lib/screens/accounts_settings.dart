// OmniPulse AI — Ekran 5: Hesap Ekleme/Çıkarma (Mod A / Mod B), Otomatik Güncelleyici ve Bulut Ayarları (app/lib/screens/accounts_settings.dart)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/auto_updater.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';
import '../widgets/metric_badge.dart';

class AccountsSettingsScreen extends ConsumerStatefulWidget {
  const AccountsSettingsScreen({super.key});

  @override
  ConsumerState<AccountsSettingsScreen> createState() => _AccountsSettingsScreenState();
}

class _AccountsSettingsScreenState extends ConsumerState<AccountsSettingsScreen> {
  String _selectedPlatform = 'tiktok';
  String _selectedCategory = AppConstants.defaultCategories.first;
  String _selectedFetchMode = 'public_only';
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _tokenOrSessionCtrl = TextEditingController();
  final TextEditingController _secondaryIdCtrl = TextEditingController();
  bool _isSavingAccount = false;

  final TextEditingController _supabaseUrlCtrl = TextEditingController();
  final TextEditingController _supabaseKeyCtrl = TextEditingController();
  final TextEditingController _githubRepoCtrl = TextEditingController();
  final TextEditingController _githubTokenCtrl = TextEditingController();
  final TextEditingController _geminiKeyCtrl = TextEditingController();
  bool _autoUpdateOnStartup = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCloudSettings();
  }

  bool _isTestingConnection = false;

  Future<void> _loadSavedCloudSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedUrl = (prefs.getString(AppConstants.prefSupabaseUrl) ?? '').trim();
    final savedKey = (prefs.getString(AppConstants.prefSupabaseAnonKey) ?? '').trim();
    final savedRepo = (prefs.getString(AppConstants.prefGithubRepo) ?? '').trim();
    final savedToken = (prefs.getString(AppConstants.prefGithubToken) ?? '').trim();
    final savedGemini = (prefs.getString(AppConstants.prefGeminiApiKey) ?? '').trim();

    setState(() {
      _supabaseUrlCtrl.text = savedUrl.isNotEmpty ? savedUrl : AppConstants.defaultSupabaseUrl;
      _supabaseKeyCtrl.text = savedKey.isNotEmpty ? savedKey : AppConstants.defaultSupabaseAnonKey;
      _githubRepoCtrl.text = (savedRepo.isNotEmpty && savedRepo.contains('/')) ? savedRepo : AppConstants.defaultGithubRepo;
      _githubTokenCtrl.text = savedToken.isNotEmpty ? savedToken : AppConstants.defaultGithubToken;
      _geminiKeyCtrl.text = savedGemini.isNotEmpty ? savedGemini : AppConstants.defaultGeminiApiKey;
      _autoUpdateOnStartup = prefs.getBool(AppConstants.prefAutoUpdateEnabled) ?? true;
    });
  }

  Future<void> _testCloudConnection() async {
    setState(() => _isTestingConnection = true);
    try {
      final client = Supabase.instance.client;
      final res = await client.from('accounts').select('id, username').eq('is_active', true);
      final count = (res as List).length;
      if (!mounted) return;
      setState(() => _isTestingConnection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: OmniPulseColors.emeraldViral,
          content: Text(
            '✅ Supabase Bulut Bağlantısı Başarılı: ' + count.toString() + ' Aktif Hesap Bağlandı!',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTestingConnection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: OmniPulseColors.coralCritical,
          content: Text(
            '❌ Bağlantı Hatası: ' + e.toString(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }

  Future<void> _saveCloudSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefSupabaseUrl, _supabaseUrlCtrl.text.trim());
    await prefs.setString(AppConstants.prefSupabaseAnonKey, _supabaseKeyCtrl.text.trim());
    await prefs.setString(AppConstants.prefGithubRepo, _githubRepoCtrl.text.trim());
    await prefs.setString(AppConstants.prefGithubToken, _githubTokenCtrl.text.trim());
    await prefs.setString(AppConstants.prefGeminiApiKey, _geminiKeyCtrl.text.trim());
    await prefs.setBool(AppConstants.prefAutoUpdateEnabled, _autoUpdateOnStartup);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: OmniPulseColors.emeraldViral,
        content: Text(
          'Bulut ve Otomatik Güncelleme ayarları kaydedildi.',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _handleAddAccount() async {
    final username = _usernameCtrl.text.trim().replaceAll('@', '');
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir @kullaniciadi girin.')),
      );
      return;
    }

    setState(() => _isSavingAccount = true);
    try {
      final Map<String, dynamic> creds = {};
      if (_selectedFetchMode == 'authorized_api') {
        final tokenVal = _tokenOrSessionCtrl.text.trim();
        final secondVal = _secondaryIdCtrl.text.trim();
        if (_selectedPlatform == 'tiktok') {
          creds['session_id'] = tokenVal;
          creds['access_token'] = tokenVal;
        } else if (_selectedPlatform == 'instagram') {
          creds['session_id'] = tokenVal;
          creds['access_token'] = tokenVal;
          if (secondVal.isNotEmpty) {
            creds['ig_business_id'] = secondVal;
          }
        } else if (_selectedPlatform == 'youtube') {
          creds['access_token'] = tokenVal;
          creds['refresh_token'] = secondVal;
        }
      }

      await AccountsRepository.addOrUpdateAccount(
        platform: _selectedPlatform,
        username: username,
        categoryTag: _selectedCategory,
        fetchMode: _selectedFetchMode,
        authCredentials: creds,
      );

      _usernameCtrl.clear();
      _tokenOrSessionCtrl.clear();
      _secondaryIdCtrl.clear();
      ref.invalidate(accountsStreamProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: OmniPulseColors.emeraldViral,
          content: Text(
            '@$username ($_selectedPlatform) kalıcı olarak bulut veritabanına eklendi!',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: OmniPulseColors.coralCritical,
          content: Text('Hesap eklenirken hata oluştu: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingAccount = false);
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _tokenOrSessionCtrl.dispose();
    _secondaryIdCtrl.dispose();
    _supabaseUrlCtrl.dispose();
    _supabaseKeyCtrl.dispose();
    _githubRepoCtrl.dispose();
    _githubTokenCtrl.dispose();
    _geminiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesap Yönetimi (15+) & Otomatik Güncelleyici'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===================================================================
          // 0. OTOMATİK GITHUB OTA GÜNCELLEME KARTI
          // ===================================================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  OmniPulseColors.aiViolet.withOpacity(0.18),
                  OmniPulseColors.emeraldViral.withOpacity(0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OmniPulseColors.aiViolet.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.refreshCw, color: OmniPulseColors.emeraldViral, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'GITHUB OTOMATİK GÜNCELLEYİCİ (${AppConstants.currentVersionTag})',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: OmniPulseColors.textPrimaryDark,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _autoUpdateOnStartup,
                      activeColor: OmniPulseColors.emeraldViral,
                      onChanged: (val) async {
                        setState(() => _autoUpdateOnStartup = val);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(AppConstants.prefAutoUpdateEnabled, val);
                      },
                    ),
                  ],
                ),
                const Text(
                  'Açık olduğunda uygulama her açılışta GitHub Releases üzerindeki en yeni sürümü otomatik indirir, kurar ve yeniden başlatır.',
                  style: TextStyle(fontSize: 12, color: OmniPulseColors.textSecondaryDark),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      GitHubAutoUpdater.checkAndAutoUpdateOnStartup(
                        context,
                        forceManualCheck: true,
                      );
                    },
                    icon: const Icon(Icons.cloud_download, size: 16),
                    label: const Text('Şimdi Güncellemeleri Kontrol Et'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ===================================================================
          // 1. YENİ HESAP EKLEME FORMU (MOD A / MOD B SEÇİMLİ)
          // ===================================================================
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
                const Row(
                  children: [
                    Icon(LucideIcons.userPlus, color: OmniPulseColors.emeraldViral, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'YENİ SOSYAL MEDYA HESABI EKLE (KALICI)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: OmniPulseColors.textPrimaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'tiktok', label: Text('TikTok')),
                    ButtonSegment(value: 'instagram', label: Text('Instagram')),
                    ButtonSegment(value: 'youtube', label: Text('YouTube')),
                  ],
                  selected: {_selectedPlatform},
                  onSelectionChanged: (s) => setState(() => _selectedPlatform = s.first),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(
                          labelText: '@kullaniciadi veya Kanal Handle',
                          hintText: 'ornek_hesap',
                          prefixIcon: Icon(LucideIcons.atSign, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'Kategori Etiketi'),
                        dropdownColor: OmniPulseColors.cardElevatedDark,
                        items: AppConstants.defaultCategories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCategory = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Veri Çekme Modu Seçimi:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: OmniPulseColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                RadioListTile<String>(
                  value: 'public_only',
                  groupValue: _selectedFetchMode,
                  onChanged: (v) => setState(() => _selectedFetchMode = v!),
                  contentPadding: EdgeInsets.zero,
                  activeColor: OmniPulseColors.emeraldViral,
                  title: const Text(
                    'Mod A: Sadece Kullanıcı Adıyla Hızlı Takip (Şifresiz / Açık Veri)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'TikTok\'ta kaydetme ve paylaşım dahil 6 metriğin tamamını; IG ve YouTube\'da izlenme, beğeni ve yorumları şifresiz çeker.',
                    style: TextStyle(fontSize: 11.5, color: OmniPulseColors.textSecondaryDark),
                  ),
                ),
                RadioListTile<String>(
                  value: 'authorized_api',
                  groupValue: _selectedFetchMode,
                  onChanged: (v) => setState(() => _selectedFetchMode = v!),
                  contentPadding: EdgeInsets.zero,
                  activeColor: OmniPulseColors.aiPink,
                  title: const Text(
                    'Mod B: Derin API / OAuth Yetkilendirmesi (Gizli Kaydetme & Paylaşım Dahil)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Instagram Graph API / Session Cookie veya YouTube Analytics OAuth bağlayarak gizli kaydetme, paylaşım ve tutma oranlarını çeker.',
                    style: TextStyle(fontSize: 11.5, color: OmniPulseColors.textSecondaryDark),
                  ),
                ),
                if (_selectedFetchMode == 'authorized_api') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenOrSessionCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: _selectedPlatform == 'instagram'
                          ? 'Instagram Graph API Access Token veya Session ID'
                          : _selectedPlatform == 'youtube'
                              ? 'YouTube OAuth 2.0 Access Token'
                              : 'TikTok Display API Token veya Session ID',
                      prefixIcon: const Icon(LucideIcons.key, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _secondaryIdCtrl,
                    decoration: InputDecoration(
                      labelText: _selectedPlatform == 'instagram'
                          ? 'Instagram Business Account ID (Opsiyonel)'
                          : 'OAuth Refresh Token (Opsiyonel)',
                      prefixIcon: const Icon(LucideIcons.shieldCheck, size: 18),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSavingAccount ? null : _handleAddAccount,
                    style: FilledButton.styleFrom(
                      backgroundColor: OmniPulseColors.emeraldViral,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(LucideIcons.plusCircle, size: 18),
                    label: Text(
                      _isSavingAccount ? 'Kaydediliyor...' : 'Hesabı Bulut Veritabanına Ekle',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ===================================================================
          // 2. MEVCUT HESAPLAR LİSTESİ (SİLME & MOD DEĞİŞTİRME)
          // ===================================================================
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
                const Text(
                  'KAYITLI HESAPLARINIZ (SİZ SİLENE KADAR KALICI)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: OmniPulseColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                accountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return const Text(
                        'Henüz kayıtlı hesap yok.',
                        style: TextStyle(color: OmniPulseColors.textSecondaryDark),
                      );
                    }
                    return Column(
                      children: accounts.map((acc) {
                        return Dismissible(
                          key: ValueKey(acc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            color: OmniPulseColors.coralCritical,
                            child: const Icon(LucideIcons.trash2, color: Colors.white),
                          ),
                          onDismissed: (_) async {
                            await AccountsRepository.deleteAccount(acc.id);
                            ref.invalidate(accountsStreamProvider);
                          },
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: PlatformBadge(platform: acc.platform),
                            title: Text(
                              '@${acc.username}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${acc.categoryTag}  •  ${acc.fetchMode == "authorized_api" ? "Mod B (Derin API)" : "Mod A (Açık Veri)"}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: OmniPulseColors.textSecondaryDark,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    final nextMode = acc.fetchMode == 'public_only'
                                        ? 'authorized_api'
                                        : 'public_only';
                                    await AccountsRepository.updateAccountFetchMode(
                                      accountId: acc.id,
                                      fetchMode: nextMode,
                                    );
                                    ref.invalidate(accountsStreamProvider);
                                  },
                                  child: Text(
                                    acc.fetchMode == 'public_only' ? 'Mod B\'ye Geç' : 'Mod A\'ya Geç',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.trash2,
                                    size: 18,
                                    color: OmniPulseColors.coralCritical,
                                  ),
                                  onPressed: () async {
                                    await AccountsRepository.deleteAccount(acc.id);
                                    ref.invalidate(accountsStreamProvider);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Hata: $e'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ===================================================================
          // 3. BULUT & API BAĞLANTI AYARLARI (SUPABASE & GITHUB ACTIONS)
          // ===================================================================
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
                const Row(
                  children: [
                    Icon(LucideIcons.cloudCog, color: OmniPulseColors.aiViolet, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'BULUT MOTORU VE SUPABASE BAĞLANTI AYARLARI',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: OmniPulseColors.textPrimaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _supabaseUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Supabase Project URL',
                    hintText: 'https://xyzcompany.supabase.co',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _supabaseKeyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Supabase Anon / Service Key',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _githubRepoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'GitHub Repository (kullanici/omnipulse-ai)',
                    hintText: 'kullanici/omnipulse-ai',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _githubTokenCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'GitHub Personal Access Token (workflow izni olan PAT)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _geminiKeyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Google Gemini API Key (İsteğe Bağlı)',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveCloudSettings,
                    style: FilledButton.styleFrom(
                      backgroundColor: OmniPulseColors.aiViolet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(LucideIcons.save, size: 18),
                    label: const Text(
                      'Bulut Bağlantı Ayarlarını Kaydet',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isTestingConnection ? null : _testCloudConnection,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OmniPulseColors.aiViolet,
                      side: const BorderSide(color: OmniPulseColors.aiViolet),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: OmniPulseColors.aiViolet),
                          )
                        : const Icon(LucideIcons.checkCircle2, size: 18),
                    label: const Text(
                      'Bulut Bağlantısını ve Hesapları Test Et',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
