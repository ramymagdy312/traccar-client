import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_storage.dart';
import '../preferences.dart';
import 'services_list_screen.dart';
import 'tracking_screen.dart';
import '../settings_screen.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

/// الشاشة الرئيسية بعد تسجيل الدخول: قائمة التشغيلات كافتراضية + تنقل سفلي للتتبع والإعدادات.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  static const List<_NavItemData> _tabData = [
    _NavItemData(key: 'services', icon: Icons.list_alt),
    _NavItemData(key: 'tracking', icon: Icons.location_on),
    _NavItemData(key: 'settings', icon: Icons.settings),
  ];

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    await const AuthStorage().clear();
    await Preferences.instance.remove(Preferences.username);
    if (!mounted) return;
    try {
      await bg.BackgroundGeolocation.stop();
    } catch (_) {}
    if (!mounted) return;
    await navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = Preferences.instance.getString(Preferences.username);
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.welcomeLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.0,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  final offsetTween = Tween<Offset>(
                                    begin: const Offset(0, 0.15),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(position: offsetTween, child: child),
                                  );
                                },
                                child: Text(
                                  username != null && username.isNotEmpty ? username : '—',
                                  key: ValueKey(username ?? '—'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                    height: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: l.logoutTooltip,
                              onPressed: _logout,
                              icon: const Icon(Icons.logout_rounded),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                ServicesListScreen(),
                TrackingScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (int index) => setState(() => _currentIndex = index),
          destinations: _tabLabels(context),
        ),
      ),
    );
  }

  List<NavigationDestination> _tabLabels(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return [
      NavigationDestination(icon: Icon(_tabData[0].icon), label: l.servicesTabLabel),
      NavigationDestination(icon: Icon(_tabData[1].icon), label: l.trackingTabLabel),
      NavigationDestination(icon: Icon(_tabData[2].icon), label: l.settingsTabLabel),
    ];
  }
}

class _NavItemData {
  final String key;
  final IconData icon;
  const _NavItemData({required this.key, required this.icon});
}
