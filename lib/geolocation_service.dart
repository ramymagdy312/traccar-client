
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:serb_tracker_client/location_cache.dart';
import 'package:serb_tracker_client/permissions/location_permission_service.dart';
import 'package:serb_tracker_client/preferences.dart';
import 'package:wakelock_partial_android/wakelock_partial_android.dart';

class GeolocationService {
  static Future<void> init() async {
    await bg.BackgroundGeolocation.ready(Preferences.geolocationConfig(false));
    if (Platform.isAndroid) {
      await bg.BackgroundGeolocation.registerHeadlessTask(headlessTask);
    }
    FirebaseCrashlytics.instance.log('geolocation_init');
    bg.BackgroundGeolocation.onEnabledChange(onEnabledChange);
    bg.BackgroundGeolocation.onMotionChange(onMotionChange);
    bg.BackgroundGeolocation.onHeartbeat(onHeartbeat);
    bg.BackgroundGeolocation.onLocation(onLocation, (bg.LocationError error) {
      developer.log('Location error', error: error);
    });
  }

  static Future<void> onEnabledChange(bool enabled) async {
    FirebaseCrashlytics.instance.log('geolocation_enabled:$enabled');
    if (Preferences.instance.getBool(Preferences.wakelock) ?? false) {
      if (!enabled) {
        await WakelockPartialAndroid.release();
      }
    }
  }

  static Future<void> onMotionChange(bg.Location location) async {
    FirebaseCrashlytics.instance.log('geolocation_motion:${location.isMoving}');
    if (Preferences.instance.getBool(Preferences.wakelock) ?? false) {
      if (location.isMoving) {
        await WakelockPartialAndroid.acquire();
      } else {
        await WakelockPartialAndroid.release();
      }
    }
  }

  static Future<void> onHeartbeat(bg.HeartbeatEvent event) async {
    // Heartbeats can fire headlessly, where no disclosure could be presented.
    if (!await LocationPermissionService.hasAuthorization()) return;
    await bg.BackgroundGeolocation.getCurrentPosition(samples: 1, persist: true, extras: {'heartbeat': true});
  }

  static Future<void> onLocation(bg.Location location) async {
    if (_shouldDelete(location)) {
      try {
        await bg.BackgroundGeolocation.destroyLocation(location.uuid);
      } catch(error) {
        developer.log('Failed to delete location', error: error);
      }
    } else {
      LocationCache.set(location);
      try {
        await bg.BackgroundGeolocation.sync();
      } catch (error) {
        developer.log('Failed to send location', error: error);
      }
    }
  }

  static bool _shouldDelete(bg.Location location) {
    if (!location.isMoving) return false;
    if (location.extras?.isNotEmpty == true) return false;

    final lastLocation = LocationCache.get();
    if (lastLocation == null) return false;

    final isHighestAccuracy = Preferences.instance.getString(Preferences.accuracy) == 'highest';
    final duration = DateTime.parse(location.timestamp).difference(DateTime.parse(lastLocation.timestamp)).inSeconds;

    if (!isHighestAccuracy) {
      final fastestInterval = Preferences.instance.getInt(Preferences.fastestInterval);
      if (fastestInterval != null && duration < fastestInterval) return true;
    }

    final distance = _distance(lastLocation, location);

    final distanceFilter = Preferences.instance.getInt(Preferences.distance) ?? 0;
    if (distanceFilter > 0 && distance >= distanceFilter) return false;

    if (distanceFilter == 0 || isHighestAccuracy) {
      final intervalFilter = Preferences.instance.getInt(Preferences.interval) ?? 0;
      if (intervalFilter > 0 && duration >= intervalFilter) return false;
    }

    if (isHighestAccuracy && lastLocation.heading >= 0 && location.coords.heading > 0) {
      final angle = (location.coords.heading - lastLocation.heading).abs();
      final angleFilter = Preferences.instance.getInt(Preferences.angle) ?? 0;
      if (angleFilter > 0 && angle >= angleFilter) return false;
    }

    return true;
  }

  static double _distance(Location from, bg.Location to) {
    const earthRadius = 6371008.8; // meters
    final dLat = _degToRad(to.coords.latitude - from.latitude);
    final dLon = _degToRad(to.coords.longitude - from.longitude);
    final sinLat = sin(dLat / 2);
    final sinLon = sin(dLon / 2);
    final a = sinLat * sinLat + cos(_degToRad(from.latitude)) * cos(_degToRad(to.coords.latitude)) * sinLon * sinLon;
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double degree) => degree * pi / 180.0;

  /// Returns the best available current coordinates (fresh GPS, then cache).
  ///
  /// A fresh fix is only requested when location access has already been
  /// granted, so this never raises a permission dialog on its own.
  /// Prefer [resolveCoords] from UI flows that can present the disclosure.
  static Future<({double lat, double lng})?> currentCoordsOrNull() async {
    if (await LocationPermissionService.hasAuthorization()) {
      try {
        final location = await bg.BackgroundGeolocation.getCurrentPosition(
          samples: 1,
          persist: false,
        );
        final lat = location.coords.latitude;
        final lng = location.coords.longitude;
        if (_isValidCoord(lat, lng)) return (lat: lat, lng: lng);
      } catch (error) {
        developer.log('Failed to get current position', error: error);
      }
    }

    final cached = LocationCache.get();
    if (cached != null && _isValidCoord(cached.latitude, cached.longitude)) {
      return (lat: cached.latitude, lng: cached.longitude);
    }

    return null;
  }

  /// Ensures disclosure + permission, then returns a real GPS fix (or cache).
  /// Returns `null` when the driver declines, is denied, or no fix is available.
  static Future<({double lat, double lng})?> resolveCoords(
    BuildContext context,
  ) async {
    final access = await LocationPermissionService.ensureAccess(
      context,
      requireBackground: false,
    );
    if (access == LocationAccessResult.disclosureDeclined ||
        access == LocationAccessResult.denied) {
      return null;
    }
    return fetchCoords();
  }

  /// Reads a fresh GPS fix when already authorized, else the last cached point.
  /// Never prompts for permission — callers must run [ensureAccess] first.
  static Future<({double lat, double lng})?> fetchCoords() async {
    try {
      final location = await bg.BackgroundGeolocation.getCurrentPosition(
        samples: 1,
        persist: false,
      );
      final lat = location.coords.latitude;
      final lng = location.coords.longitude;
      if (_isValidCoord(lat, lng)) return (lat: lat, lng: lng);
    } catch (error) {
      developer.log('Failed to get current position', error: error);
    }

    final cached = LocationCache.get();
    if (cached != null && _isValidCoord(cached.latitude, cached.longitude)) {
      return (lat: cached.latitude, lng: cached.longitude);
    }

    return null;
  }

  /// Legacy helper used by callers that cannot show UI. Prefer [resolveCoords].
  static Future<({double lat, double lng})> currentCoords() async {
    return await currentCoordsOrNull() ?? (lat: 0.0, lng: 0.0);
  }

  static bool _isValidCoord(double lat, double lng) =>
      lat.abs() > 0.000001 || lng.abs() > 0.000001;
}

Future<void>? _firebaseInitialization;

@pragma('vm:entry-point')
void headlessTask(bg.HeadlessEvent headlessEvent) async {
  await (_firebaseInitialization ??= Firebase.initializeApp());
  await Preferences.init();
  FirebaseCrashlytics.instance.log('geolocation_headless:${headlessEvent.name}');
  switch (headlessEvent.name) {
    case bg.Event.ENABLEDCHANGE:
      await GeolocationService.onEnabledChange(headlessEvent.event);
    case bg.Event.MOTIONCHANGE:
      await GeolocationService.onMotionChange(headlessEvent.event);
    case bg.Event.HEARTBEAT:
      await GeolocationService.onHeartbeat(headlessEvent.event);
    case bg.Event.LOCATION:
      await GeolocationService.onLocation(headlessEvent.event);
  }
}
