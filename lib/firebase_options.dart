// Placeholder until the app is connected to a Firebase project. Running
// `flutterfire configure` replaces this file with the project's real keys;
// until then the app runs offline only (see services/cloud.dart).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('Firebase is not configured yet: run `flutterfire configure`.');
}
