import 'dart:async';

final Completer<void> _appServicesReady = Completer<void>();

/// Completes after silent plugin warm-up so overlays (tour, update) do not
/// stack on iOS permission dialogs during launch.
Future<void> get appServicesReady => _appServicesReady.future;

void markAppServicesReady() {
  if (!_appServicesReady.isCompleted) {
    _appServicesReady.complete();
  }
}
