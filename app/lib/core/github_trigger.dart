// OmniPulse AI — Telefondan GitHub Actions Bulut Motorunu Uyandıran REST API Servisi (app/lib/core/github_trigger.dart)
// Kullanıcının bilgisayarı kapalıyken Android telefondan tek tuşla cloud_sync_engine.yml iş akışını tetikler.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

class CloudTriggerResult {
  final bool success;
  final String message;
  final String? syncJobId;

  const CloudTriggerResult({
    required this.success,
    required this.message,
    this.syncJobId,
  });
}

class GitHubCloudTriggerService {
  /// Supabase sync_jobs tablosunda 'queued' kaydı açar ve GitHub Actions workflow_dispatch uç noktasını tetikler.
  static Future<CloudTriggerResult> triggerCloudSync({
    String? targetAccountId,
    String triggeredBy = 'mobile_app',
    int totalAccountsEstimate = 15,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final githubToken = (prefs.getString(AppConstants.prefGithubToken) ?? '').trim();
    final githubRepo = (prefs.getString(AppConstants.prefGithubRepo) ?? AppConstants.defaultGithubRepo).trim();
    final githubBranch = (prefs.getString(AppConstants.prefGithubBranch) ?? AppConstants.defaultGithubBranch).trim();

    String? createdJobId;

    // 1. Önce Supabase sync_jobs tablosunda canlı takip kaydını oluştur
    try {
      final supabase = Supabase.instance.client;
      final inserted = await supabase
          .from('sync_jobs')
          .insert({
            'status': 'queued',
            'triggered_by': triggeredBy,
            'target_account_id': targetAccountId,
            'total_accounts': totalAccountsEstimate,
            'processed_accounts': 0,
            'current_account_name': 'Bulut sunucusu uyandırılıyor...',
            'status_message': 'GitHub Actions bulut motoruna sinyal gönderildi...',
          })
          .select('id')
          .single();
      createdJobId = inserted['id']?.toString();
    } catch (_) {
      // Supabase bağlantısı henüz yapılandırılmamışsa aşağıda kullanıcıya bilgi verilir
    }

    if (githubToken.isEmpty || !githubRepo.contains('/')) {
      return CloudTriggerResult(
        success: false,
        syncJobId: createdJobId,
        message:
            'GitHub Personal Access Token veya "kullanici/repo" bilgisi eksik. '
            'Lütfen Ayarlar sekmesinden GitHub Bulut Bağlantı bilgilerinizi kaydedin.',
      );
    }

    // 2. GitHub REST API üzerinden cloud_sync_engine.yml iş akışını tetikle
    final uri = Uri.parse(
      'https://api.github.com/repos/$githubRepo/actions/workflows/${AppConstants.defaultGithubWorkflowFile}/dispatches',
    );

    try {
      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer $githubToken',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ref': githubBranch.isEmpty ? 'main' : githubBranch,
          'inputs': {
            'triggered_by': triggeredBy,
            'target_account_id': targetAccountId ?? '',
            'sync_job_id': createdJobId ?? '',
          },
        }),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return CloudTriggerResult(
          success: true,
          syncJobId: createdJobId,
          message: 'Bulut motoru başarıyla tetiklendi! Canlı ilerleme çubuğundan takip edebilirsiniz.',
        );
      } else {
        return CloudTriggerResult(
          success: false,
          syncJobId: createdJobId,
          message: 'GitHub API Hatası (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      return CloudTriggerResult(
        success: false,
        syncJobId: createdJobId,
        message: 'Bulut tetikleme sırasında ağ hatası oluştu: $e',
      );
    }
  }
}
