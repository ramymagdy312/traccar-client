import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:serb_tracker_client/geolocation_service.dart';
import 'package:serb_tracker_client/password_service.dart';
import 'package:serb_tracker_client/push_service.dart';
import 'package:serb_tracker_client/quick_actions.dart';

import 'api/dio_client.dart';
import 'auth/auth_storage.dart';
import 'auth/session_manager.dart';
import 'l10n/app_localizations.dart';
import 'auth/auth_gate.dart';
import 'preferences.dart';
import 'configuration_service.dart';
import 'dev_http_overrides.dart';

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
  RateMyApp rateMyApp = RateMyApp(minDays: 0, minLaunches: 0);
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
      await rateMyApp.init();
      if (mounted && rateMyApp.shouldOpenDialog) {
        try {
          await rateMyApp.showRateDialog(context);
        } catch (error) {
          developer.log('Failed to show rate dialog', error: error);
        }
      }
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
      if (!mounted || versionStatus == null || !versionStatus.canUpdate) {
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

  static const Color _primaryLight = Color(0xFF0D7377);
  static const Color _primaryDark = Color(0xFF14A3A8);

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
                  theme: ThemeData(
                    useMaterial3: true,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: _primaryLight,
                      primary: _primaryLight,
                      brightness: Brightness.light,
                      surface: const Color(0xFFF7FAFA),
                    ),
                    appBarTheme: const AppBarTheme(
                      centerTitle: true,
                      elevation: 0,
                      scrolledUnderElevation: 1,
                    ),
                    cardTheme: CardThemeData(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                    ),
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE0E5E5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: _primaryLight,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    filledButtonTheme: FilledButtonThemeData(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                    chipTheme: ChipThemeData(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    navigationBarTheme: const NavigationBarThemeData(
                      elevation: 8,
                      height: 70,
                    ),
                  ),
                  darkTheme: ThemeData(
                    useMaterial3: true,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: _primaryDark,
                      primary: _primaryDark,
                      brightness: Brightness.dark,
                      surface: const Color(0xFF1A1C1E),
                    ),
                    appBarTheme: const AppBarTheme(
                      centerTitle: true,
                      elevation: 0,
                      scrolledUnderElevation: 1,
                    ),
                    cardTheme: CardThemeData(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                    ),
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF3D4043)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: _primaryDark,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    filledButtonTheme: FilledButtonThemeData(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                    chipTheme: ChipThemeData(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    navigationBarTheme: const NavigationBarThemeData(
                      elevation: 8,
                      height: 70,
                    ),
                  ),
                  home: Stack(
                    children: const [QuickActionsInitializer(), AuthGate()],
                  ),
                ),
          ),
    );
  }
}
