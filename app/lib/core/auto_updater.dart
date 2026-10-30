// OmniPulse AI — GitHub Üzerinden Sıfır Dokunuşlu Otomatik Güncelleyici (app/lib/core/auto_updater.dart)
// Uygulama her açıldığında GitHub Releases API'sini (/releases/latest) kontrol eder.
// Yeni bir sürüm varsa:
// - Windows Masaüstünde: OmniPulse-Windows.zip dosyasını arka planda indirir, PowerShell ile
//   mevcut klasörün üzerine çıkartır ve uygulamayı otomatik olarak yeni sürümle yeniden başlatır.
// - Android Telefonda: OmniPulse-Android.apk dosyasını indirir ve kurulum ekranını otomatik açar.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';
import 'theme.dart';

class ReleaseUpdateInfo {
  final String tagName;
  final int remoteBuildNumber;
  final String releaseNotes;
  final String? windowsZipUrl;
  final String? androidApkUrl;
  final String htmlUrl;

  const ReleaseUpdateInfo({
    required this.tagName,
    required this.remoteBuildNumber,
    required this.releaseNotes,
    this.windowsZipUrl,
    this.androidApkUrl,
    required this.htmlUrl,
  });
}

class GitHubAutoUpdater {
  static bool _hasCheckedThisSession = false;

  /// v1.0.42 gibi bir sürüm etiketinden son yapı numarasını (42) ayrıştırır.
  static int parseBuildNumberFromTag(String tag) {
    final clean = tag.trim().replaceAll('v', '').replaceAll('V', '');
    final parts = clean.split('.');
    if (parts.isNotEmpty) {
      final lastPart = int.tryParse(parts.last.replaceAll(RegExp(r'[^0-9]'), ''));
      if (lastPart != null) return lastPart;
    }
    return 0;
  }

  /// GitHub Releases API üzerinden en son sürümü sorgular.
  static Future<ReleaseUpdateInfo?> checkLatestRelease() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = (prefs.getString(AppConstants.prefGithubRepo) ?? AppConstants.defaultGithubRepo).trim();
    final token = (prefs.getString(AppConstants.prefGithubToken) ?? '').trim();

    if (repo.isEmpty || !repo.contains('/') || repo == 'kullanici/omnipulse-ai') {
      return null;
    }

    final uri = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final Map<String, dynamic> data = jsonDecode(resp.body) as Map<String, dynamic>;
      final String tagName = (data['tag_name'] ?? '').toString().trim();
      if (tagName.isEmpty) return null;

      final int remoteBuild = parseBuildNumberFromTag(tagName);
      final String lastInstalledTag = prefs.getString(AppConstants.prefLastInstalledTag) ?? '';

      // Hem derleme zamanı numarasından hem de yerel kayıtlı etiketten büyük mü kontrol et
      final bool isNewerBuild = remoteBuild > AppConstants.currentBuildNumber &&
          tagName != AppConstants.currentVersionTag &&
          tagName != lastInstalledTag;

      if (!isNewerBuild) {
        return null;
      }

      String? winUrl;
      String? apkUrl;
      final assets = data['assets'];
      if (assets is List) {
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final name = (asset['name'] ?? '').toString().toLowerCase();
            final dlUrl = (asset['browser_download_url'] ?? '').toString();
            if (name.endsWith('.zip') || name.contains('windows')) {
              winUrl = dlUrl;
            } else if (name.endsWith('.apk') || name.contains('android')) {
              apkUrl = dlUrl;
            }
          }
        }
      }

      return ReleaseUpdateInfo(
        tagName: tagName,
        remoteBuildNumber: remoteBuild,
        releaseNotes: (data['body'] ?? 'Yeni performans ve grafik iyileştirmeleri.').toString(),
        windowsZipUrl: winUrl,
        androidApkUrl: apkUrl,
        htmlUrl: (data['html_url'] ?? '').toString(),
      );
    } catch (e) {
      debugPrint('[AutoUpdater] Sürüm kontrol uyarısı: $e');
      return null;
    }
  }

  /// Uygulama açılışında çağrılır; yeni sürüm varsa otomatik indirip kurar ve yeniden başlatır.
  static Future<void> checkAndAutoUpdateOnStartup(
    BuildContext context, {
    bool forceManualCheck = false,
  }) async {
    if (kIsWeb) return;
    if (_hasCheckedThisSession && !forceManualCheck) return;
    _hasCheckedThisSession = true;

    final prefs = await SharedPreferences.getInstance();
    final bool autoEnabled = prefs.getBool(AppConstants.prefAutoUpdateEnabled) ?? true;
    if (!autoEnabled && !forceManualCheck) return;

    final updateInfo = await checkLatestRelease();
    if (updateInfo == null) {
      if (forceManualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: OmniPulseColors.emeraldViral,
            content: Text(
              'Uygulamanız güncel! En son GitHub sürümünü kullanıyorsunuz.',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // Otomatik indirme ve kurulum diyalogunu başlat
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AutoUpdateProgressDialog(updateInfo: updateInfo),
    );
  }
}

class _AutoUpdateProgressDialog extends StatefulWidget {
  final ReleaseUpdateInfo updateInfo;

  const _AutoUpdateProgressDialog({required this.updateInfo});

  @override
  State<_AutoUpdateProgressDialog> createState() => _AutoUpdateProgressDialogState();
}

class _AutoUpdateProgressDialogState extends State<_AutoUpdateProgressDialog> {
  double _progress = 0.0;
  String _statusText = 'Yeni sürüm algılandı, GitHub üzerinden otomatik indiriliyor...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startAutomaticDownloadAndInstall();
  }

  Future<void> _startAutomaticDownloadAndInstall() async {
    try {
      if (Platform.isWindows && widget.updateInfo.windowsZipUrl != null) {
        await _downloadAndApplyWindowsUpdate(widget.updateInfo.windowsZipUrl!);
      } else if (Platform.isAndroid && widget.updateInfo.androidApkUrl != null) {
        await _downloadAndLaunchAndroidUpdate(widget.updateInfo.androidApkUrl!);
      } else {
        final uri = Uri.tryParse(widget.updateInfo.htmlUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _statusText = 'Otomatik güncelleme sırasında hata oluştu: $e';
      });
    }
  }

  Future<void> _downloadFileWithProgress(String url, File targetFile) async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString(AppConstants.prefGithubToken) ?? '').trim();

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      if (token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }
      final streamedResp = await client.send(req);
      final totalBytes = streamedResp.contentLength ?? 0;
      int receivedBytes = 0;

      final sink = targetFile.openWrite();
      await for (final chunk in streamedResp.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() {
            _progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
            final pct = (_progress * 100).round();
            _statusText = 'Yeni sürüm (${widget.updateInfo.tagName}) indiriliyor... %$pct';
          });
        }
      }
      await sink.flush();
      await sink.close();
    } finally {
      client.close();
    }
  }

  /// Windows Masaüstünde ZIP'i indirir, PowerShell betiğiyle mevcut .exe ve .dll dosyalarını
  /// otomatik günceller ve yeni sürümü anında yeniden başlatır.
  Future<void> _downloadAndApplyWindowsUpdate(String zipUrl) async {
    final tempDir = Directory.systemTemp.createTempSync('omnipulse_ota_');
    final zipFile = File('${tempDir.path}\\OmniPulse-Windows.zip');

    await _downloadFileWithProgress(zipUrl, zipFile);

    if (mounted) {
      setState(() {
        _statusText = 'Güncelleme dosyaları çıkartılıyor ve uygulama yeniden başlatılıyor...';
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLastInstalledTag, widget.updateInfo.tagName);

    final String currentExePath = Platform.resolvedExecutable;
    final String appDir = File(currentExePath).parent.path;
    final int currentPid = pid;
    final String extractDir = '${tempDir.path}\\extracted';
    final String psScriptPath = '${tempDir.path}\\apply_update.ps1';

    final String psScript = '''
\$ErrorActionPreference = "SilentlyContinue"
Wait-Process -Id $currentPid -Timeout 10
Start-Sleep -Seconds 1
Expand-Archive -Path "${zipFile.path}" -DestinationPath "$extractDir" -Force
Copy-Item -Path "$extractDir\\*" -Destination "$appDir" -Recurse -Force
Start-Process -FilePath "$currentExePath"
Remove-Item -Path "${tempDir.path}" -Recurse -Force
''';

    await File(psScriptPath).writeAsString(psScript);

    await Process.start(
      'powershell',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        psScriptPath,
      ],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }

  /// Android'de yeni APK'yı indirir ve kurulum paketini otomatik tetikler.
  Future<void> _downloadAndLaunchAndroidUpdate(String apkUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLastInstalledTag, widget.updateInfo.tagName);

    final uri = Uri.tryParse(apkUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: OmniPulseColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: OmniPulseColors.aiViolet, width: 1.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.cloud_download, color: OmniPulseColors.aiPink, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Otomatik Güncelleme (${widget.updateInfo.tagName})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: OmniPulseColors.textPrimaryDark,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusText,
            style: const TextStyle(
              fontSize: 13.5,
              color: OmniPulseColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 14),
          if (!_hasError)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 8,
                backgroundColor: OmniPulseColors.backgroundDark,
                valueColor: const AlwaysStoppedAnimation<Color>(OmniPulseColors.emeraldViral),
              ),
            ),
        ],
      ),
      actions: [
        if (_hasError)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
      ],
    );
  }
}