import 'dart:async';

import 'package:flutter/material.dart';

// ignore_for_file: use_build_context_synchronously

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../preferences.dart';
import 'auth_api.dart';
import 'auth_gate.dart';
import 'auth_storage.dart';
import 'auth_token.dart';

class SessionManager {
  static final AuthStorage _storage = const AuthStorage();
  static final AuthApi _authApi = AuthApi();
  static const Duration _sessionTtl = Duration(hours: 12);

  /// How long before the access token's actual expiry we should preemptively
  /// refresh it. Keeps a comfortable buffer so in-flight requests don't race
  /// the expiry instant.
  static const Duration _refreshLeadTime = Duration(minutes: 1);

  /// Minimum delay we'll ever schedule a proactive refresh for, to avoid a
  /// tight loop when the lead time has already elapsed.
  static const Duration _minScheduledDelay = Duration(seconds: 5);

  static Future<bool>? _ongoingRefresh;
  static bool _isRedirecting = false;
  static Timer? _refreshTimer;

  static Future<bool> validateSession() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) {
      await _expireSessionAndRedirect();
      return false;
    }

    final tokenExpiry = await _storage.readTokenExpiryEpochMs();
    final loginEpoch = await _storage.readLoginEpochMs();
    final now = DateTime.now().millisecondsSinceEpoch;
    final tokenValid = tokenExpiry == null || now < tokenExpiry;
    final sessionExpired =
        loginEpoch == null || (now - loginEpoch) > _sessionTtl.inMilliseconds;

    if (tokenValid && !sessionExpired) return true;
    return extendSession();
  }

  /// Refresh the access token. If [silent] is true, suppresses the
  /// "Session extended" snackbar — used by the proactive timer.
  static Future<bool> extendSession({bool silent = false}) {
    final ongoing = _ongoingRefresh;
    if (ongoing != null) return ongoing;
    final future = _performExtendSession(silent: silent);
    _ongoingRefresh = future;
    future.whenComplete(() {
      _ongoingRefresh = null;
    });
    return future;
  }

  static Future<bool> _performExtendSession({bool silent = false}) async {
    try {
      final refreshed = await _authApi.refreshToken();
      await _persistSessionToken(refreshed);
      if (!silent) {
        final ctx = navigatorKey.currentContext;
        final message = ctx != null
            ? AppLocalizations.of(ctx)?.sessionExtended ?? 'Session extended'
            : 'Session extended';
        messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      // Re-arm the proactive refresh against the new expiry timestamp.
      await scheduleProactiveRefresh();
      return true;
    } catch (_) {
      await _expireSessionAndRedirect();
      return false;
    }
  }

  /// Schedule a silent refresh shortly before the access token expires.
  /// Cancels any previously scheduled refresh first, so it's safe to call
  /// after every login / refresh / app resume.
  static Future<void> scheduleProactiveRefresh() async {
    cancelScheduledRefresh();

    final accessToken = await _storage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;

    final tokenExpiry = await _storage.readTokenExpiryEpochMs();
    if (tokenExpiry == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final msUntilRefresh =
        tokenExpiry - now - _refreshLeadTime.inMilliseconds;

    // Already inside the lead-time window (or past expiry): refresh now.
    if (msUntilRefresh <= 0) {
      unawaited(extendSession(silent: true));
      return;
    }

    final delay = msUntilRefresh < _minScheduledDelay.inMilliseconds
        ? _minScheduledDelay
        : Duration(milliseconds: msUntilRefresh);

    _refreshTimer = Timer(delay, () {
      // Fire-and-forget; failure paths surface through _expireSessionAndRedirect.
      unawaited(extendSession(silent: true));
    });
  }

  static void cancelScheduledRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Persist server-side login state. Only stores the access token and
  /// session timestamps — the refresh token is kept by the Dio cookie jar,
  /// and the password is never written to disk.
  static Future<void> saveLoginSession({
    required String accessToken,
    int? expiresInSeconds,
  }) async {
    await _storage.writeAccessToken(accessToken);
    final now = DateTime.now();
    await _storage.writeLoginEpochMs(now.millisecondsSinceEpoch);
    if (expiresInSeconds != null && expiresInSeconds > 0) {
      await _storage.writeTokenExpiryEpochMs(
        now.add(Duration(seconds: expiresInSeconds)).millisecondsSinceEpoch,
      );
    }
    // Arm the proactive refresh as soon as a fresh session lands.
    await scheduleProactiveRefresh();
  }

  static Future<void> _persistSessionToken(AuthToken token) async {
    final now = DateTime.now();
    await _storage.writeAccessToken(token.accessToken);
    await _storage.writeLoginEpochMs(now.millisecondsSinceEpoch);
    final expiresEpoch = token.expiresAt?.millisecondsSinceEpoch;
    if (expiresEpoch != null && expiresEpoch > now.millisecondsSinceEpoch) {
      await _storage.writeTokenExpiryEpochMs(expiresEpoch);
    } else {
      final expiresIn = token.expiresIn ?? 0;
      if (expiresIn > 0) {
        await _storage.writeTokenExpiryEpochMs(
          now.add(Duration(seconds: expiresIn)).millisecondsSinceEpoch,
        );
      }
    }
    final repId = token.repId ?? token.userId;
    if (repId != null) {
      await Preferences.instance.setString(Preferences.id, repId.toString());
    }
    final userName = token.userName;
    if (userName != null && userName.isNotEmpty) {
      await Preferences.instance.setString(Preferences.username, userName);
    }
    await Preferences.instance.setString(
      Preferences.roles,
      token.roles.join(','),
    );
  }

  static Future<void> _expireSessionAndRedirect() async {
    cancelScheduledRefresh();
    await _storage.clearAll();
    await Preferences.instance.remove(Preferences.username);
    await Preferences.instance.remove(Preferences.roles);
    if (_isRedirecting) return;
    _isRedirecting = true;
    final ctx = navigatorKey.currentContext;
    final message = ctx != null
        ? AppLocalizations.of(ctx)?.sessionExpiredLoginAgain ??
            'Session expired. Please login again.'
        : 'Session expired. Please login again.';
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      await navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    }
    _isRedirecting = false;
  }
}
