import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// EKENGE PLUS — Options Firebase par plateforme (projet `ekenge-plus`).
///
/// Android : extrait de google-services.json.
/// Web : app « EKENGE PLUS Web » creee dans le meme projet Firebase.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions non configuré pour cette plateforme.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-ehkmWb0936Iz43zfxJS6PuEHyzqY7DM',
    appId: '1:677245357032:android:d50062fb4ecd031d70f25d',
    messagingSenderId: '677245357032',
    projectId: 'ekenge-plus',
    storageBucket: 'ekenge-plus.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA0uXpLyjJ3sCScJwn0fVQ4-nu32ZzoIAc',
    appId: '1:677245357032:web:96eeba9fddacdc6670f25d',
    messagingSenderId: '677245357032',
    projectId: 'ekenge-plus',
    authDomain: 'ekenge-plus.firebaseapp.com',
    storageBucket: 'ekenge-plus.firebasestorage.app',
  );
}
