// OmniPulse AI — Mobil Alt Menü (BottomNavBar) ve Masaüstü Yan Menü (NavigationRail) Kabuğu (app/lib/screens/main_shell.dart)

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import 'master_dashboard.dart';
import 'ai_strategy_hub.dart';
import 'accounts_settings.dart';

class MainResponsiveShell extends StatefulWidget {
  const MainResponsiveShell({super.key});

  @override
  State<MainResponsiveShell> createState() => _MainResponsiveShellState();
}

class _MainResponsiveShellState extends State<MainResponsiveShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    MasterDashboardScreen(),
    AiStrategyHubScreen(),
    AccountsSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= AppConstants.desktopBreakpoint;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              extended: width >= 1180,
              backgroundColor: OmniPulseColors.cardDark,
              selectedIconTheme: const IconThemeData(color: OmniPulseColors.aiViolet),
              unselectedIconTheme:
                  const IconThemeData(color: OmniPulseColors.textSecondaryDark),
              selectedLabelTextStyle: const TextStyle(
                color: OmniPulseColors.textPrimaryDark,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: OmniPulseColors.textSecondaryDark,
              ),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: OmniPulseColors.aiAutonomousGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.activity, color: Colors.white, size: 22),
                    ),
                    if (width >= 1180) ...[
                      const SizedBox(width: 10),
                      const Text(
                        'OmniPulse AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: OmniPulseColors.textPrimaryDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(LucideIcons.layoutDashboard),
                  label: Text('Komuta Paneli'),
                ),
                NavigationRailDestination(
                  icon: Icon(LucideIcons.sparkles),
                  label: Text('Otonom AI & Radar'),
                ),
                NavigationRailDestination(
                  icon: Icon(LucideIcons.sliders),
                  label: Text('Hesaplar & Bulut'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: _pages[_selectedIndex]),
          ],
        ),
      );
    }

    // Android Mobil Görünümü: Tek elle kullanıma uygun BottomNavigationBar
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        backgroundColor: OmniPulseColors.cardDark,
        indicatorColor: OmniPulseColors.aiViolet.withOpacity(0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.layoutDashboard),
            label: 'Komuta Paneli',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.sparkles),
            label: 'AI Strateji',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.sliders),
            label: 'Hesaplar & Ayar',
          ),
        ],
      ),
    );
  }
}
