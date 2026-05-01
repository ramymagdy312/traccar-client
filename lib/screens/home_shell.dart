import 'dart:ui';

import 'package:flutter/material.dart';

import '../api/dio_client.dart';
import '../l10n/app_localizations.dart';
import '../auth/auth_gate.dart';
import '../auth/auth_storage.dart';
import '../auth/session_manager.dart';
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
    _NavItemData(key: 'services', icon: Icons.list_alt_rounded, activeIcon: Icons.list_alt_rounded),
    _NavItemData(key: 'tracking', icon: Icons.location_on_outlined, activeIcon: Icons.location_on_rounded),
    _NavItemData(key: 'settings', icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded),
  ];

  Future<void> _logout() async {
    final l = AppLocalizations.of(context)!;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.logoutTooltip),
        content: Text(l.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.logoutTooltip),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;

    if (!mounted) return;
    final navigator = Navigator.of(context);
    SessionManager.cancelScheduledRefresh();
    try {
      await bg.BackgroundGeolocation.stop();
    } catch (_) {}
    await const AuthStorage().clearAll();
    await DioClient.clearCookies();
    await Preferences.instance.remove(Preferences.username);
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
      bottomNavigationBar: _PremiumNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: _tabData,
      ),
    );
  }
}

class _NavItemData {
  final String key;
  final IconData icon;
  final IconData activeIcon;
  const _NavItemData({required this.key, required this.icon, required this.activeIcon});
}

class _PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItemData> items;

  const _PremiumNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l = AppLocalizations.of(context)!;
    final labels = [l.servicesTabLabel, l.trackingTabLabel, l.settingsTabLabel];
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? cs.surface : cs.surfaceContainerLowest)
                .withValues(alpha: isDark ? 0.85 : 0.92),
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.15),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.only(bottom: bottomPadding, top: 6),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              return Expanded(
                child: _NavItem(
                  icon: items[i].icon,
                  activeIcon: items[i].activeIcon,
                  label: labels[i],
                  selected: selected,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final iconColor = selected ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.6);
    final labelColor = selected ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.55);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 20 : 12,
                vertical: selected ? 8 : 6,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withValues(alpha: isDark ? 0.15 : 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  key: ValueKey(selected),
                  size: selected ? 26 : 24,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: theme.textTheme.labelSmall!.copyWith(
                color: labelColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: selected ? 12 : 11,
                letterSpacing: selected ? 0.3 : 0,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
