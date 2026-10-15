import 'core/config/app_gate.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/router.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/cx_theme.dart';
import 'core/services/cx_notification_service.dart';
import 'features/stickers/data/local_sticker_repository.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Set dark system status bar & navigation styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: CxColors.secondaryDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize storage
  await CxStorage.init();

  // Initialize Push Notifications & Native Message Channels
  await CxNotificationService.init();

  // Initialize Offline Sticker Library
  try {
    await LocalStickerRepository().initialize();
  } catch (e) {
    debugPrint('Sticker repository initialization error: $e');
  }

  runApp(const ProviderScope(child: CodeXaMobileApp()));
}

class CodeXaMobileApp extends StatelessWidget {
  const CodeXaMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CodeXa',
      debugShowCheckedModeBanner: false,
      theme: CxTheme.darkTheme,
      routerConfig: appRouter,
      builder: (context, child) =>
          AppGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
