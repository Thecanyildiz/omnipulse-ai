// OmniPulse AI — Uygulama Giriş Noktası ve Supabase Başlatıcı (app/lib/main.dart)
// Android Mobil ve Windows/Mac/Linux Masaüstü için paylaşımlı tercihleri (SharedPreferences)
// veya derleme zamanı (--dart-define) değişkenlerini okuyarak Supabase'i başlatır.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final String supabaseUrl =
      (prefs.getString(AppConstants.prefSupabaseUrl) ?? AppConstants.defaultSupabaseUrl).trim();
  final String supabaseAnonKey =
      (prefs.getString(AppConstants.prefSupabaseAnonKey) ?? AppConstants.defaultSupabaseAnonKey)
          .trim();

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
      );
    } catch (e) {
      debugPrint('Supabase başlatma uyarısı: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: OmniPulseAiApp(),
    ),
  );
}

class OmniPulseAiApp extends ConsumerWidget {
  const OmniPulseAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: OmniPulseTheme.lightTheme,
      darkTheme: OmniPulseTheme.darkTheme,
      themeMode: themeMode,
      home: const MainResponsiveShell(),
    );
  }
}
