// File generated for CodeXa Mobile & Firebase CLI configuration.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with CodeXa mobile apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDZcQ-NecC9S82VhqcIEy5lq1kwbjdKng8',
    appId: '1:268559658188:web:2f9920e7145498240e2669',
    messagingSenderId: '268559658188',
    projectId: 'codxa-agency',
    authDomain: 'codxa-agency.firebaseapp.com',
    storageBucket: 'codxa-agency.firebasestorage.app',
    measurementId: 'G-EZQL4W66WR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDZcQ-NecC9S82VhqcIEy5lq1kwbjdKng8',
    appId: '1:268559658188:android:agency-a8b33',
    messagingSenderId: '268559658188',
    projectId: 'codxa-agency',
    storageBucket: 'codxa-agency.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDZcQ-NecC9S82VhqcIEy5lq1kwbjdKng8',
    appId: '1:268559658188:ios:agency-a8b33',
    messagingSenderId: '268559658188',
    projectId: 'codxa-agency',
    storageBucket: 'codxa-agency.firebasestorage.app',
    iosBundleId: 'online.codexa.codexaMobile',
  );
}
