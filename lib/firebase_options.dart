import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase app identifiers from Firebase Console > Project settings > Your apps.
/// Firebase API keys are public client identifiers; access must be controlled
/// with Firebase Security Rules.
class FirebaseOptionsForApp {
  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCizsEb5rDijonKdAef2xaCDWgxC5Ik_u0',
  );
  static const webAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '1:311840976544:web:253367ae431fd157a923c5',
  );
  static const androidApiKey = 'AIzaSyBoZRDrqpQLfv-r4wvYbLEuS9yomFM161c';
  static const androidAppId = '1:311840976544:android:9d96e4f761e97367a923c5';
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '311840976544',
  );
  static const projectId = 'appdoctruyen-5b8a7';
  static const authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'appdoctruyen-5b8a7.firebaseapp.com',
  );

  static bool get isConfigured => apiKey.isNotEmpty && webAppId.isNotEmpty && messagingSenderId.isNotEmpty;

  static FirebaseOptions get currentPlatform => FirebaseOptions(
        apiKey: kIsWeb ? apiKey : androidApiKey,
        appId: kIsWeb ? webAppId : androidAppId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: 'appdoctruyen-5b8a7.firebasestorage.app',
        authDomain: kIsWeb ? authDomain : null,
      );
}
