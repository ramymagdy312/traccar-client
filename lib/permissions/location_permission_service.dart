import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import '../preferences.dart';
import 'location_disclosure_screen.dart';

/// Outcome of the disclosure + permission flow.
enum LocationAccessResult {
  /// Background ("Allow all the time") location access is in place.
  granted,

  /// Only foreground ("While using the app") access was granted. Tracking still
  /// works while the app is visible, but may stop once it is closed.
  foregroundOnly,

  /// The operating system denied location access.
  denied,

  /// The driver dismissed the disclosure with "Not now".
  disclosureDeclined,
}

/// Single entry point for obtaining location access.
///
/// Nothing in the app may call a `BackgroundGeolocation` API that is able to
/// raise an OS permission dialog (`start`, `getCurrentPosition`,
/// `startGeofences`, `requestPermission`) without first going through
/// [ensureAccess]. That guarantees Google Play's prominent-disclosure
/// requirement: the in-app explanation is always shown first, and permissions
/// are only requested as a direct result of the driver tapping *Continue*.
class LocationPermissionService {
  const LocationPermissionService._();

  /// `true` when the driver has accepted the disclosure on this device.
  static bool get hasAcceptedDisclosure =>
      Preferences.instance.getBool(Preferences.locationDisclosureAccepted) ??
      false;

  /// Current OS authorization, or [bg.ProviderChangeEvent
  /// .AUTHORIZATION_STATUS_NOT_DETERMINED] when it cannot be read.
  ///
  /// Reading the provider state never prompts the user.
  static Future<int> authorizationStatus() async {
    try {
      final providerState = await bg.BackgroundGeolocation.providerState;
      return providerState.status;
    } catch (error) {
      developer.log('Failed to read location authorization', error: error);
      return bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED;
    }
  }

  /// `true` when the app already holds usable location authorization, so no
  /// permission dialog would be raised by a location API call.
  static Future<bool> hasAuthorization({bool requireBackground = false}) async {
    final status = await authorizationStatus();
    return _isUsable(status, requireBackground: requireBackground);
  }

  /// Shows the disclosure when needed, then requests location permissions.
  ///
  /// Call this from an explicit driver action (starting tracking, sending a
  /// location, triggering SOS) — never on startup, after login, or on a timer.
  static Future<LocationAccessResult> ensureAccess(
    BuildContext context, {
    bool requireBackground = true,
  }) async {
    final status = await authorizationStatus();

    // Already have what we need — never prompt again.
    if (status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS) {
      return LocationAccessResult.granted;
    }
    if (!requireBackground &&
        status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE) {
      return LocationAccessResult.granted;
    }

    final needsOsPrompt = status ==
            bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED ||
        status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED ||
        status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_RESTRICTED;

    // Re-show the disclosure when:
    // - it was never accepted, or
    // - permissions were revoked (we are about to ask the OS again).
    // Do NOT re-show merely to upgrade WhenInUse → Always.
    final shouldShowDisclosure = !hasAcceptedDisclosure || needsOsPrompt;

    if (shouldShowDisclosure) {
      if (!context.mounted) return LocationAccessResult.disclosureDeclined;
      final accepted = await LocationDisclosureScreen.show(context);
      if (!accepted) return LocationAccessResult.disclosureDeclined;
      await Preferences.instance.setBool(
        Preferences.locationDisclosureAccepted,
        true,
      );
    }

    // Already WhenInUse and disclosure is on file: allow tracking to start.
    // The SDK may still offer a background upgrade from its own rationale when
    // start() runs; we must not block the toggle on Always alone.
    if (status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE) {
      return LocationAccessResult.foregroundOnly;
    }

    final grantedStatus = await _requestPermission();
    return _resultFor(grantedStatus, requireBackground: requireBackground);
  }

  /// Lets the plugin run its own WhenInUse → Always upgrade sequence in one
  /// call. A manual two-step request was hanging on some devices (MIUI) after
  /// the background-settings activity closed.
  static Future<int> _requestPermission() async {
    try {
      await bg.BackgroundGeolocation.setConfig(
        bg.Config(
          geolocation: const bg.GeoConfig(
            locationAuthorizationRequest: 'Always',
          ),
        ),
      );
      return await bg.BackgroundGeolocation.requestPermission();
    } catch (error) {
      // Refusal / cancel is expected; report whatever the OS currently holds.
      developer.log('Location permission not fully granted', error: error);
      return authorizationStatus();
    }
  }

  static bool _isUsable(int status, {required bool requireBackground}) {
    if (status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS) {
      return true;
    }
    return !requireBackground &&
        status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE;
  }

  static LocationAccessResult _resultFor(
    int status, {
    required bool requireBackground,
  }) {
    if (status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS) {
      return LocationAccessResult.granted;
    }
    if (status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE) {
      return requireBackground
          ? LocationAccessResult.foregroundOnly
          : LocationAccessResult.granted;
    }
    return LocationAccessResult.denied;
  }
}
