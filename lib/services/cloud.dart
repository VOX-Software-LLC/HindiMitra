import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'crash_reporter.dart';

/// Connection to the Firebase project (accounts, sync, homework). The app is
/// local-first: everything works without it, so when Firebase is not
/// configured, unreachable or fails to start, [ready] stays false and the
/// app carries on offline.
///
/// Run with `--dart-define=USE_FIREBASE_EMULATOR=true` (and
/// `firebase emulators:start --project demo-hindimitra`) to use the local
/// Auth and Firestore emulators instead of a real project.
class Cloud {
  static const useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
  static const emulatorProject = 'demo-hindimitra';

  static bool ready = false;
  /// Why the cloud is off, for the parent screens and debugging (null when [ready]).
  static String? offlineReason = 'Not started';

  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;

  static FirebaseOptions get _options => useEmulator
      // A "demo-" project never touches real Firebase servers; the keys are dummies.
      ? const FirebaseOptions(apiKey: 'demo-key', appId: '1:000000000000:web:0000000000000000',
          messagingSenderId: '000000000000', projectId: emulatorProject, authDomain: '$emulatorProject.firebaseapp.com')
      : DefaultFirebaseOptions.currentPlatform;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: _options).timeout(const Duration(seconds: 8));
      // Keep a local copy of everything read or written, so the app keeps
      // working offline and catches up when the connection comes back.
      // (On by default on Android/iOS; web has to ask for it.) Settings come
      // first: the emulator host set below lives in them.
      db.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
      if (useEmulator) {
        // Android emulators reach the host machine at 10.0.2.2.
        final host = defaultTargetPlatform == TargetPlatform.android && !kIsWeb ? '10.0.2.2' : 'localhost';
        db.useFirestoreEmulator(host, 8080);
        await auth.useAuthEmulator(host, 9099);
      }
      ready = true;
      offlineReason = null;
    } on UnsupportedError catch (e) {
      offlineReason = e.message;
    } catch (e, st) {
      offlineReason = '$e';
      CrashReporter.record(e, st, reason: 'Firebase init');
    }
    debugPrint(ready
        ? 'Cloud: connected to ${Firebase.app().options.projectId}${useEmulator ? ' (emulator)' : ''}'
        : 'Cloud: offline ($offlineReason)');
  }
}
