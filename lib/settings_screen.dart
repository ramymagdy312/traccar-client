import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:serb_tracker_client/main.dart';
import 'package:serb_tracker_client/password_service.dart';
import 'package:wakelock_partial_android/wakelock_partial_android.dart';

import 'l10n/app_localizations.dart';
import 'preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool advanced = false;

  String _getAccuracyLabel(String? key) {
    return switch (key) {
      'highest' => AppLocalizations.of(context)!.highestAccuracyLabel,
      'high' => AppLocalizations.of(context)!.highAccuracyLabel,
      'low' => AppLocalizations.of(context)!.lowAccuracyLabel,
      _ => AppLocalizations.of(context)!.mediumAccuracyLabel,
    };
  }

  Widget _tileLeading(IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: cs.primary, size: 22),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.14),
            cs.surfaceContainerHighest.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.tune_rounded, color: cs.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.settingsTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.settingsSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      color: cs.surface.withValues(alpha: theme.brightness == Brightness.dark ? 0.92 : 0.98),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.35,
              ),
            ),
          ),
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            children[i],
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final code = Preferences.instance.getString(Preferences.localeCode) ?? 'system';
    final subtitle = switch (code) {
      'ar' => l.languageArabic,
      'en' => l.languageEnglish,
      _ => l.languageSystem,
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _tileLeading(Icons.language_rounded),
      title: Text(l.languageLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
      onTap: () async {
        final chosen = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(l.languageLabel),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(l.languageSystem),
                  onTap: () => Navigator.pop(ctx, 'system'),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(l.languageArabic),
                  onTap: () => Navigator.pop(ctx, 'ar'),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(l.languageEnglish),
                  onTap: () => Navigator.pop(ctx, 'en'),
                ),
              ],
            ),
          ),
        );
        if (chosen != null) {
          await Preferences.instance.setString(Preferences.localeCode, chosen);
          appLocaleNotifier.value = chosen == 'system' ? null : Locale(chosen);
          if (mounted) setState(() {});
        }
      },
    );
  }

  Widget _buildThemeModeTile(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final mode = appThemeModeNotifier.value;
    final subtitle = mode == ThemeMode.light
        ? l.themeModeLight
        : mode == ThemeMode.dark
            ? l.themeModeDark
            : l.themeModeSystem;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _tileLeading(Icons.palette_rounded),
      title: Text(l.themeModeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
      onTap: () async {
        final chosen = await showDialog<ThemeMode>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(l.themeModeLabel),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(l.themeModeSystem),
                  onTap: () => Navigator.pop(ctx, ThemeMode.system),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(l.themeModeLight),
                  onTap: () => Navigator.pop(ctx, ThemeMode.light),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(l.themeModeDark),
                  onTap: () => Navigator.pop(ctx, ThemeMode.dark),
                ),
              ],
            ),
          ),
        );
        if (chosen != null) {
          appThemeModeNotifier.value = chosen;
          final value = chosen == ThemeMode.light ? 'light' : chosen == ThemeMode.dark ? 'dark' : 'system';
          await Preferences.instance.setString(Preferences.themeMode, value);
          if (mounted) setState(() {});
        }
      },
    );
  }

  Future<void> _editSetting(String title, String key, bool isInt) async {
    final initialValue =
        isInt
            ? Preferences.instance.getInt(key)?.toString() ?? '0'
            : Preferences.instance.getString(key) ?? '';

    final controller = TextEditingController(text: initialValue);
    final errorMessage = AppLocalizations.of(context)!.invalidValue;

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            scrollable: true,
            title: Text(title),
            content: TextField(
              controller: controller,
              keyboardType: isInt ? TextInputType.number : TextInputType.text,
              inputFormatters:
                  isInt ? [FilteringTextInputFormatter.digitsOnly] : [],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancelButton),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(AppLocalizations.of(context)!.saveButton),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      if (key == Preferences.url) {
        final uri = Uri.tryParse(result);
        if (uri == null ||
            uri.host.isEmpty ||
            !(uri.scheme == 'http' || uri.scheme == 'https')) {
          messengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
          return;
        }
      }
      if (isInt) {
        int? intValue = int.tryParse(result);
        if (intValue != null) {
          if (key == Preferences.heartbeat && intValue > 0 && intValue < 60) {
            intValue = 60; // minimum heartbeat is 60 seconds
          }
          await Preferences.instance.setInt(key, intValue);
        }
      } else {
        await Preferences.instance.setString(key, result);
      }
      await bg.BackgroundGeolocation.setConfig(Preferences.geolocationConfig());
      setState(() {});
    }
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            scrollable: true,
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.passwordLabel,
              ),
              obscureText: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancelButton),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppLocalizations.of(context)!.saveButton),
              ),
            ],
          ),
    );
    if (result == true) {
      await PasswordService.setPassword(controller.text);
    }
  }

  Widget _buildReadOnlyDeviceIdTile() {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final value = Preferences.instance.getString(Preferences.id) ?? '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _tileLeading(Icons.badge_outlined),
      title: Text(l.idLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        value.isEmpty ? '—' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      trailing: Icon(
        Icons.lock_outline_rounded,
        size: 20,
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
  }

  Widget _buildListTile(String title, String key, bool isInt, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    String? value;
    if (isInt) {
      final intValue = Preferences.instance.getInt(key);
      if (intValue != null && intValue > 0) {
        value = intValue.toString();
      } else {
        value = AppLocalizations.of(context)!.disabledValue;
      }
    } else {
      value = Preferences.instance.getString(key);
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _tileLeading(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        value ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      trailing: Icon(Icons.edit_outlined, size: 20, color: cs.onSurfaceVariant.withValues(alpha: 0.65)),
      onTap: () => _editSetting(title, key, isInt),
    );
  }

  Widget _buildAccuracyListTile() {
    final cs = Theme.of(context).colorScheme;
    final accuracyOptions = ['highest', 'high', 'medium', 'low'];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _tileLeading(Icons.gps_fixed_rounded),
      title: Text(
        AppLocalizations.of(context)!.accuracyLabel,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        _getAccuracyLabel(Preferences.instance.getString(Preferences.accuracy)),
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
      onTap: () async {
        final selectedAccuracy = await showDialog<String>(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(AppLocalizations.of(context)!.accuracyLabel),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      accuracyOptions
                          .map(
                            (option) => ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              title: Text(_getAccuracyLabel(option)),
                              onTap: () => Navigator.pop(context, option),
                            ),
                          )
                          .toList(),
                ),
              ),
        );
        if (selectedAccuracy != null) {
          await Preferences.instance.setString(
            Preferences.accuracy,
            selectedAccuracy,
          );
          await bg.BackgroundGeolocation.setConfig(
            Preferences.geolocationConfig(),
          );
          setState(() {});
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isHighestAccuracy =
        Preferences.instance.getString(Preferences.accuracy) == 'highest';
    final distance = Preferences.instance.getInt(Preferences.distance);

    final locationChildren = <Widget>[
      _buildAccuracyListTile(),
      _buildListTile(
        l.distanceLabel,
        Preferences.distance,
        true,
        Icons.straighten_rounded,
      ),
      if (isHighestAccuracy || Platform.isAndroid && distance == 0)
        _buildListTile(
          l.intervalLabel,
          Preferences.interval,
          true,
          Icons.schedule_rounded,
        ),
      if (isHighestAccuracy)
        _buildListTile(
          l.angleLabel,
          Preferences.angle,
          true,
          Icons.explore_rounded,
        ),
      _buildListTile(
        l.heartbeatLabel,
        Preferences.heartbeat,
        true,
        Icons.monitor_heart_outlined,
      ),
    ];

    final advancedChildren = <Widget>[
      SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: _tileLeading(Icons.tune_rounded),
        title: Text(l.advancedLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        value: advanced,
        activeTrackColor: cs.secondary.withValues(alpha: 0.65),
        onChanged: (value) {
          setState(() => advanced = value);
        },
      ),
      if (advanced) ...[
        _buildListTile(
          l.fastestIntervalLabel,
          Preferences.fastestInterval,
          true,
          Icons.speed_rounded,
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          secondary: _tileLeading(Icons.cloud_queue_rounded),
          title: Text(l.bufferLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          value: Preferences.instance.getBool(Preferences.buffer) ?? true,
          activeTrackColor: cs.secondary.withValues(alpha: 0.65),
          onChanged: (value) async {
            await Preferences.instance.setBool(Preferences.buffer, value);
            await bg.BackgroundGeolocation.setConfig(
              Preferences.geolocationConfig(),
            );
            setState(() {});
          },
        ),
        if (Platform.isAndroid)
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            secondary: _tileLeading(Icons.stay_current_portrait_rounded),
            title: Text(l.wakelockLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
            value:
                Preferences.instance.getBool(Preferences.wakelock) ?? false,
            activeTrackColor: cs.secondary.withValues(alpha: 0.65),
            onChanged: (value) async {
              await Preferences.instance.setBool(Preferences.wakelock, value);
              if (value) {
                final state = await bg.BackgroundGeolocation.state;
                if (state.isMoving == true) {
                  WakelockPartialAndroid.acquire();
                }
              } else {
                WakelockPartialAndroid.release();
              }
              setState(() {});
            },
          ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          secondary: _tileLeading(Icons.pause_circle_outline_rounded),
          title: Text(l.stopDetectionLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          value:
              Preferences.instance.getBool(Preferences.stopDetection) ??
              true,
          activeTrackColor: cs.secondary.withValues(alpha: 0.65),
          onChanged: (value) async {
            await Preferences.instance.setBool(
              Preferences.stopDetection,
              value,
            );
            await bg.BackgroundGeolocation.setConfig(
              Preferences.geolocationConfig(),
            );
            setState(() {});
          },
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: _tileLeading(Icons.lock_outline_rounded),
          title: Text(l.passwordLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
          onTap: _changePassword,
        ),
      ],
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            _buildPageHeader(context),
            const SizedBox(height: 6),
            _sectionCard(
              context,
              title: l.settingsSectionGeneral,
              children: [
                _buildLanguageTile(context),
                _buildThemeModeTile(context),
              ],
            ),
            _sectionCard(
              context,
              title: l.settingsSectionServer,
              children: [
                _buildReadOnlyDeviceIdTile(),
                _buildListTile(l.urlLabel, Preferences.url, false, Icons.link_rounded),
              ],
            ),
            _sectionCard(
              context,
              title: l.settingsSectionLocation,
              children: locationChildren,
            ),
            _sectionCard(
              context,
              title: l.settingsSectionAdvanced,
              children: advancedChildren,
            ),
          ],
        ),
      ),
    );
  }
}
