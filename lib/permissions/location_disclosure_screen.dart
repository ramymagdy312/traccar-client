import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// In-app prominent disclosure for background location collection.
///
/// This is a regular Flutter page — never an OS permission dialog — and it must
/// be presented and accepted before any location permission is requested.
/// Use [LocationPermissionService.ensureAccess] rather than pushing it directly.
class LocationDisclosureScreen extends StatelessWidget {
  const LocationDisclosureScreen({super.key});

  /// Presents the disclosure and resolves to `true` only when the driver
  /// explicitly taps *Continue*. Dismissing or going back counts as a refusal.
  static Future<bool> show(BuildContext context) async {
    final accepted = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const LocationDisclosureScreen(),
        fullscreenDialog: true,
      ),
    );
    return accepted ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 44,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l.locationDisclosureTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l.locationDisclosureIntro,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DisclosureBullet(text: l.locationDisclosureBulletTrip),
                        _DisclosureBullet(
                          text: l.locationDisclosureBulletDispatch,
                        ),
                        _DisclosureBullet(
                          text: l.locationDisclosureBulletMonitoring,
                        ),
                        _DisclosureBullet(text: l.locationDisclosureBulletSos),
                        const SizedBox(height: 12),
                        _DisclosureNote(
                          icon: Icons.lock_outline_rounded,
                          background: cs.surfaceContainerHighest.withValues(
                            alpha: 0.6,
                          ),
                          foreground: cs.onSurfaceVariant,
                          lines: [
                            l.locationDisclosureSecurity,
                            l.locationDisclosureStopped,
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DisclosureNote(
                          icon: Icons.info_outline_rounded,
                          background: cs.tertiaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          foreground: cs.onTertiaryContainer,
                          lines: [l.locationDisclosureWarning],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          l.locationDisclosureContinue,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          l.locationDisclosureNotNow,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisclosureBullet extends StatelessWidget {
  final String text;

  const _DisclosureBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 7, end: 10),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclosureNote extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final List<String> lines;

  const _DisclosureNote({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                for (final line in lines)
                  Text(
                    line,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                      height: 1.5,
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
