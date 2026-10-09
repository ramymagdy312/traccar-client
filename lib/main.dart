import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:serb_tracker_client/geolocation_service.dart';
import 'package:serb_tracker_client/password_service.dart';
import 'package:serb_tracker_client/push_service.dart';
import 'package:serb_tracker_client/quick_actions.dart';

import 'api/dio_client.dart';
import 'app_update.dart';
import 'auth/auth_storage.dart';
import 'auth/session_manager.dart';
import 'l10n/app_localizations.dart';
import 'auth/auth_gate.dart';
import 'preferences.dart';
import 'configuration_service.dart';
import 'dev_http_overrides.dart';
import 'theme/brand.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

/// Notifier for app theme mode (light/dark/system). Updated from Settings.
final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.system,
);

/// Notifier for app locale override. null = follow system.
final ValueNotifier<Locale?> appLocaleNotifier = ValueNotifier<Locale?>(null);

ThemeMode _themeModeFromString(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

Locale? _localeFromString(String? value) {
  if (value == null || value.isEmpty || value == 'system') return null;
  return Locale(value);
}

SystemUiOverlayStyle _overlayFor(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  // Transparent status bar with correct icon contrast (modern edge-to-edge look).
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark, // Android
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light, // iOS
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Production-friendly edge-to-edge system UI.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // fleet.hoppataxi.com currently presents an incomplete certificate chain;
  // allow only that host (see DioClient.trustedHosts).
  HttpOverrides.global = TrustedHostHttpOverrides();
  await Firebase.initializeApp();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  await Preferences.init();
  await PasswordService.migrate();
  await DioClient.init();
  await const AuthStorage().purgeLegacyCredentials();
  // Arm the silent token-refresh timer against any pre-existing session.
  await SessionManager.scheduleProactiveRefresh();
  await GeolocationService.init();
  await PushService.init();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final NewVersionPlus _newVersion = NewVersionPlus();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final saved = Preferences.instance.getString(Preferences.themeMode);
    if (saved != null) appThemeModeNotifier.value = _themeModeFromString(saved);
    final savedLocale = Preferences.instance.getString(Preferences.localeCode);
    appLocaleNotifier.value = _localeFromString(savedLocale);
    _initLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final didShowUpdate = await _checkForAppUpdate();
      if (didShowUpdate || !mounted) return;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers don't tick reliably while the app is backgrounded, so re-arm
    // the silent refresh whenever we come back to the foreground.
    if (state == AppLifecycleState.resumed) {
      SessionManager.scheduleProactiveRefresh();
    }
  }

  Future<bool> _checkForAppUpdate() async {
    try {
      final versionStatus = await _newVersion.getVersionStatus();
      if (!mounted || versionStatus == null) return false;

      final info = await PackageInfo.fromPlatform();
      if (!mounted) return false;
      final store =
          versionStatus.originalStoreVersion ?? versionStatus.storeVersion;
      developer.log(
        'Update check: local=${info.version}+${info.buildNumber} store=$store',
        name: 'AppUpdate',
      );
      if (!AppUpdate.isStoreNewer(
        localVersion: info.version,
        buildNumber: info.buildNumber,
        storeVersion: store,
      )) {
        return false;
      }
      final dialogContext = navigatorKey.currentContext;
      if (dialogContext == null) return false;
      if (!dialogContext.mounted) return false;
      final l = AppLocalizations.of(dialogContext)!;

      _newVersion.showUpdateDialog(
        context: dialogContext,
        versionStatus: versionStatus,
        dialogTitle: l.updateDialogTitle,
        dialogText: l.updateDialogMessage,
        updateButtonText: l.updateDialogUpdateButton,
        dismissButtonText: l.updateDialogLaterButton,
        dismissAction: () => Navigator.of(dialogContext).pop(),
      );
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to check for app updates',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _initLinks() async {
    final appLinks = AppLinks();
    final uri = await appLinks.getInitialLink();
    if (uri != null) {
      await ConfigurationService.applyUri(uri);
    }
    appLinks.uriLinkStream.listen((uri) async {
      await ConfigurationService.applyUri(uri);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder:
          (context, themeMode, child) => ValueListenableBuilder<Locale?>(
            valueListenable: appLocaleNotifier,
            builder:
                (context, locale, child) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  navigatorKey: navigatorKey,
                  scaffoldMessengerKey: messengerKey,
                  themeMode: themeMode,
                  locale: locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) {
                    final brightness = Theme.of(context).brightness;
                    final style = _overlayFor(brightness);
                    SystemChrome.setSystemUIOverlayStyle(style);
                    return AnnotatedRegion<SystemUiOverlayStyle>(
                      value: style,
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                  theme: Brand.light,
                  darkTheme: Brand.dark,
                  home: Stack(
                    children: const [QuickActionsInitializer(), AuthGate()],
                  ),
                ),
          ),
    );
  }
}
