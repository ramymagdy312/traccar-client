import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

/// Initializes Firebase for Dart. On Android, `google-services` may already
/// have created `[DEFAULT]` before this runs; `Firebase.apps` can still look
/// empty, so we catch [duplicate-app] and continue.
Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') return;
    rethrow;
  } catch (e) {
    // Some platforms surface the error as a generic exception string.
    final msg = e.toString();
    if (msg.contains('duplicate-app') || msg.contains('already exists')) {
      return;
    }
    rethrow;
  }
}
