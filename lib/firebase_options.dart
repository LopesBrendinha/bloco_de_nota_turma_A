import 'package:firebase_core/firebase_core.dart';

/// Public Firebase client configuration, supplied per environment.
/// No service-account credential is used by this application.
class DefaultFirebaseOptions {
  static const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static FirebaseOptions get currentPlatform {
    if (useEmulators) {
      return const FirebaseOptions(
        apiKey: 'demo-key',
        appId: '1:123456789:web:demo',
        messagingSenderId: '123456789',
        projectId: 'demo-bloco-notas',
        authDomain: 'demo-bloco-notas.firebaseapp.com',
      );
    }
    const key = String.fromEnvironment('FIREBASE_API_KEY');
    const app = String.fromEnvironment('FIREBASE_APP_ID');
    const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    if (key.isEmpty || app.isEmpty || project.isEmpty || sender.isEmpty) {
      throw StateError(
        'Configure seu próprio Firebase seguindo o README. Use --dart-define-from-file=config/firebase.local.json ou execute com os emuladores.',
      );
    }
    return const FirebaseOptions(
      apiKey: key,
      appId: app,
      projectId: project,
      messagingSenderId: sender,
      authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
    );
  }
}
