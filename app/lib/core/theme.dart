// OmniPulse AI — OLED Dark Mode & Light Mode Renk Paleti ve Tema Sistemi (app/lib/core/theme.dart)
// Ana Arka Plan: #0B0F19 | Kart Arka Planı: #151C2C (16px köşe, 1px #232F46 çerçeve)
// Durum Renkleri: Viral #10B981 | Normal #3B82F6 | Uyarı #F59E0B | Kritik #EF4444
// Otonom AI Vurgusu: #8B5CF6 -> #EC4899 | Platformlar: TikTok #00F2FE, IG #E1306C, YT #FF0000

import 'package:flutter/material.dart';

class OmniPulseColors {
  OmniPulseColors._();

  // OLED Dark Mode Yüzey Renkleri
  static const Color backgroundDark = Color(0xFF0B0F19);
  static const Color cardDark = Color(0xFF151C2C);
  static const Color cardElevatedDark = Color(0xFF1C2539);
  static const Color borderDark = Color(0xFF232F46);

  // Light Mode Yüzey Renkleri
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Metin Renkleri
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // Durum Renkleri (Şartname Bölüm 7.1)
  static const Color emeraldViral = Color(0xFF10B981);
  static const Color oceanNormal = Color(0xFF3B82F6);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color coralCritical = Color(0xFFEF4444);

  // Otonom AI Mor-Pembe Vurgu Renkleri
  static const Color aiViolet = Color(0xFF8B5CF6);
  static const Color aiPink = Color(0xFFEC4899);

  // Platform Rozet Renkleri
  static const Color tiktokCyan = Color(0xFF00F2FE);
  static const Color instagramMagenta = Color(0xFFE1306C);
  static const Color youtubeRed = Color(0xFFFF0000);

  static const LinearGradient aiAutonomousGradient = LinearGradient(
    colors: [aiViolet, aiPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color platformColor(String platform) {
    switch (platform.toLowerCase().trim()) {
      case 'tiktok':
        return tiktokCyan;
      case 'instagram':
        return instagramMagenta;
      case 'youtube':
        return youtubeRed;
      default:
        return oceanNormal;
    }
  }

  static Color tierColor(String tierOrHealth) {
    switch (tierOrHealth.toLowerCase().trim()) {
      case 'viral_hit':
      case 'surging':
      case 'growing':
      case 'booster':
        return emeraldViral;
      case 'above_average':
      case 'normal':
      case 'stable':
      case 'neutral':
        return oceanNormal;
      case 'underperforming':
      case 'declining':
        return amberWarning;
      case 'flop':
      case 'anomaly_drop':
      case 'drag':
        return coralCritical;
      default:
        return oceanNormal;
    }
  }
}

class OmniPulseTheme {
  OmniPulseTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: OmniPulseColors.backgroundDark,
      primaryColor: OmniPulseColors.aiViolet,
      colorScheme: const ColorScheme.dark(
        primary: OmniPulseColors.aiViolet,
        secondary: OmniPulseColors.emeraldViral,
        surface: OmniPulseColors.cardDark,
        error: OmniPulseColors.coralCritical,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: OmniPulseColors.textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: OmniPulseColors.backgroundDark,
        foregroundColor: OmniPulseColors.textPrimaryDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: OmniPulseColors.textPrimaryDark,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: OmniPulseColors.cardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: OmniPulseColors.borderDark, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OmniPulseColors.cardElevatedDark,
        labelStyle: const TextStyle(color: OmniPulseColors.textSecondaryDark),
        hintStyle: const TextStyle(color: OmniPulseColors.textMutedDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OmniPulseColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OmniPulseColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OmniPulseColors.aiViolet, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: OmniPulseColors.borderDark,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: OmniPulseColors.cardDark,
        selectedColor: OmniPulseColors.aiViolet.withOpacity(0.25),
        side: const BorderSide(color: OmniPulseColors.borderDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(
          color: OmniPulseColors.textPrimaryDark,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: OmniPulseColors.backgroundLight,
      primaryColor: OmniPulseColors.aiViolet,
      colorScheme: const ColorScheme.light(
        primary: OmniPulseColors.aiViolet,
        secondary: OmniPulseColors.emeraldViral,
        surface: OmniPulseColors.cardLight,
        error: OmniPulseColors.coralCritical,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: OmniPulseColors.backgroundLight,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: OmniPulseColors.cardLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: OmniPulseColors.borderLight, width: 1),
        ),
      ),
    );
  }
}
