import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traccar_client/main.dart';
import 'package:traccar_client/password_service.dart';
import 'package:traccar_client/preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import '../l10n/app_localizations.dart';
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.trackingTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppLocalizations.of(context)!.idLabel),
                  subtitle: Text(Preferences.instance.getString(Preferences.id) ?? ''),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppLocalizations.of(context)!.trackingLabel),
                  value: trackingEnabled,
                  activeTrackColor: isMoving == false ? Theme.of(context).colorScheme.secondary : null,
                  onChanged: (bool value) async {
                    if (!await PasswordService.authenticate(context)) return;
                    if (!context.mounted) return;
                    if (value) {
                      try {
                        FirebaseCrashlytics.instance.log('tracking_toggle_start');
                        await bg.BackgroundGeolocation.start();
                        if (context.mounted) _checkBatteryOptimizations(context);
                      } on PlatformException catch (error) {
                        final providerState = await bg.BackgroundGeolocation.providerState;
                        final isPermissionError = providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED ||
                            providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_RESTRICTED;
                        if (!context.mounted) return;
                        messengerKey.currentState?.showSnackBar(
                          SnackBar(
                            content: Text(error.message ?? error.code),
                            duration: const Duration(seconds: 4),
                            action: isPermissionError
                                ? SnackBarAction(
                                    label: AppLocalizations.of(context)!.settingsTitle,
                                        onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.settings),
                                  )
                                : null,
                          ),
                        );
                      }
                    } else {
                      FirebaseCrashlytics.instance.log('tracking_toggle_stop');
                      bg.BackgroundGeolocation.stop();
                    }
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonal(
                      onPressed: () async {
                        try {
                          await bg.BackgroundGeolocation.getCurrentPosition(
                            samples: 1,
                            persist: true,
                            extras: {'manual': true},
                          );
                        } on PlatformException catch (error) {
                          messengerKey.currentState?.showSnackBar(
                            SnackBar(content: Text(error.message ?? error.code)),
                          );
                        }
                      },
                      child: Text(AppLocalizations.of(context)!.locationButton),
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StatusScreen()),
                        );
                      },
                      child: Text(AppLocalizations.of(context)!.statusButton),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
