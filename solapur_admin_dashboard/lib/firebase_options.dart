import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Replace these placeholder values by running:
/// flutterfire configure --project=solapur-road-monitoring --platforms=web
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are configured for web only in this project.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WEB_API_KEY',
    appId: 'REPLACE_WITH_WEB_APP_ID',
    messagingSenderId: '94080701473',
    projectId: 'solapur-road-monitoring',
    authDomain: 'solapur-road-monitoring.firebaseapp.com',
    storageBucket: 'solapur-road-monitoring.appspot.com',
  );
}
