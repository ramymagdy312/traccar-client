import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:serb_tracker_client/main.dart';
import 'package:serb_tracker_client/password_service.dart';
import 'package:serb_tracker_client/preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import '../l10n/app_localizations.dart';
import '../permissions/location_permission_service.dart';
import '../status_screen.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool trackingEnabled = false;
  bool? isMoving;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void _initState() async {
    final state = await bg.BackgroundGeolocation.state;
    setState(() {
      trackingEnabled = state.enabled;
      isMoving = state.isMoving;
    });
    bg.BackgroundGeolocation.onEnabledChange((bool enabled) {
      setState(() => trackingEnabled = enabled);
    });
    bg.BackgroundGeolocation.onMotionChange((bg.Location location) {
      setState(() => isMoving = location.isMoving);
    });
  }

  /// Shows the prominent disclosure when needed and requests location
  /// permissions. Returns `true` only when the SDK may be asked for location.
  Future<bool> _ensureLocationAccess({required bool requireBackground}) async {
    final l = AppLocalizations.of(context)!;
    final result = await LocationPermissionService.ensureAccess(
      context,
      requireBackground: requireBackground,
    );
    if (!mounted) return false;
    switch (result) {
      case LocationAccessResult.granted:
        return true;
      case LocationAccessResult.foregroundOnly:
        messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(l.locationBackgroundLimitedMessage)),
        );
        return true;
      case LocationAccessResult.denied:
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(l.locationPermissionDeniedMessage),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: l.settingsTitle,
              onPressed: () => AppSettings.openAppSettings(
                type: AppSettingsType.settings,
              ),
            ),
          ),
        );
        return false;
      case LocationAccessResult.disclosureDeclined:
        return false;
    }
  }

  Future<void> _startTracking() async {
    final l = AppLocalizations.of(context)!;
    final access = await LocationPermissionService.ensureAccess(
      context,
      requireBackground: true,
    );
    if (!mounted) return;

    switch (access) {
      case LocationAccessResult.disclosureDeclined:
        return;
      case LocationAccessResult.denied:
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(l.locationPermissionDeniedMessage),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: l.settingsTitle,
              onPressed: () => AppSettings.openAppSettings(
                type: AppSettingsType.settings,
              ),
            ),
          ),
        );
        return;
      case LocationAccessResult.foregroundOnly:
        messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(l.locationBackgroundLimitedMessage)),
        );
      case LocationAccessResult.granted:
        break;
    }

    try {
      FirebaseCrashlytics.instance.log('tracking_toggle_start');
      await bg.BackgroundGeolocation.start();
      if (mounted) _checkBatteryOptimizations(context);
    } on PlatformException catch (error) {
      final providerState = await bg.BackgroundGeolocation.providerState;
      final isPermissionError =
          providerState.status ==
              bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED ||
          providerState.status ==
              bg.ProviderChangeEvent.AUTHORIZATION_STATUS_RESTRICTED;
      if (!mounted) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(error.message ?? error.code),
          duration: const Duration(seconds: 4),
          action: isPermissionError
              ? SnackBarAction(
                  label: l.settingsTitle,
                  onPressed: () => AppSettings.openAppSettings(
                    type: AppSettingsType.settings,
                  ),
                )
              : null,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  /// Requests a single location fix. Returns `true` when it was recorded.
  Future<bool> _sendCurrentPosition(Map<String, dynamic> extras) async {
    if (!await _ensureLocationAccess(requireBackground: false)) return false;
    if (!mounted) return false;
    try {
      await bg.BackgroundGeolocation.getCurrentPosition(
        samples: 1,
        persist: true,
        extras: extras,
      );
      return true;
    } on PlatformException catch (error) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(error.message ?? error.code)),
      );
      return false;
    }
  }

  Future<void> _checkBatteryOptimizations(BuildContext context) async {
    try {
      if (!await bg.DeviceSettings.isIgnoringBatteryOptimizations) {
        final request = await bg.DeviceSettings.showIgnoreBatteryOptimizations();
        if (!request.seen && context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              scrollable: true,
              content: Text(AppLocalizations.of(context)!.optimizationMessage),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    bg.DeviceSettings.show(request);
                  },
                  child: Text(AppLocalizations.of(context)!.okButton),
                ),
              ],
            ),
          );
        }
      }
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  ({
    Color accent,
    Color soft,
    IconData icon,
    String badge,
    String subtitle,
  }) _stateVisuals(ThemeData theme, AppLocalizations l) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    if (!trackingEnabled) {
      return (
        accent: cs.outline,
        soft: cs.surfaceContainerHighest,
        icon: Icons.pause_circle_filled_rounded,
        badge: l.trackingBadgePaused,
        subtitle: l.trackingSubtitlePaused,
      );
    }
    if (isMoving == true) {
      return (
        accent: cs.primary,
        soft: cs.primaryContainer,
        icon: Icons.navigation_rounded,
        badge: l.trackingBadgeMoving,
        subtitle: l.trackingSubtitleMoving,
      );
    }
    final green = isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
    final greenSoft = isDark ? const Color(0xFF1B3D24) : const Color(0xFFE8F5E9);
    return (
      accent: green,
      soft: greenSoft,
      icon: Icons.location_on_rounded,
      badge: l.trackingBadgeActive,
      subtitle: l.trackingSubtitleActive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final v = _stateVisuals(theme, l);
    final repId = Preferences.instance.getString(Preferences.id) ?? '';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    v.accent.withValues(alpha: 0.14),
                    cs.surfaceContainerHighest.withValues(alpha: 0.55),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: v.accent.withValues(alpha: 0.22)),
                boxShadow: [
                  BoxShadow(
                    color: v.accent.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: v.soft.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(v.icon, color: v.accent, size: 26),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.trackingTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                v.subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: v.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            child: Text(
                              v.badge,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: v.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.badge_outlined, size: 20, color: cs.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l.idLabel,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                repId.isEmpty ? '—' : repId,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsetsDirectional.only(start: 14, end: 8),
                        title: Text(
                          l.trackingLabel,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        value: trackingEnabled,
                        activeTrackColor: isMoving == false ? cs.secondary : null,
                        onChanged: (bool value) async {
                          if (!await PasswordService.authenticate(context)) return;
                          if (!context.mounted) return;
                          if (value) {
                            await _startTracking();
                          } else {
                            FirebaseCrashlytics.instance.log('tracking_toggle_stop');
                            bg.BackgroundGeolocation.stop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _sendCurrentPosition({'manual': true}),
                    icon: const Icon(Icons.my_location_rounded),
                    label: Text(l.locationButton),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StatusScreen()),
                      );
                    },
                    icon: const Icon(Icons.analytics_outlined),
                    label: Text(l.statusButton),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  FirebaseCrashlytics.instance.log('sos_button');
                  final sent = await _sendCurrentPosition({'alarm': 'sos'});
                  if (!sent || !context.mounted) return;
                  messengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text(l.sosSentSuccess),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.emergency_rounded),
                label: Text(l.sosAction),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
