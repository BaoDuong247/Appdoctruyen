import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (FirebaseOptionsForApp.isConfigured) {
    await Firebase.initializeApp(
      options: FirebaseOptionsForApp.currentPlatform,
    );
    // Detect network environments (proxies, extensions, restrictive Wi-Fi)
    // that block Firestore's streaming channel and fall back to long polling.
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        webExperimentalAutoDetectLongPolling: true,
      );
    }
  }
  runApp(const NovelApp());
}

class NovelApp extends StatelessWidget {
  const NovelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'App Đọc Truyện Phân Quyền',
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        themeMode: mode,
        home: FirebaseOptionsForApp.isConfigured
            ? const AuthScreen()
            : const _FirebaseSetupScreen(),
      ),
    );
  }
}

class _FirebaseSetupScreen extends StatelessWidget {
  const _FirebaseSetupScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Ứng dụng chưa có cấu hình Firebase. Hãy lấy API key, App ID và Sender ID trong Firebase Console, sau đó chạy app với các tham số FIREBASE_API_KEY, FIREBASE_APP_ID và FIREBASE_MESSAGING_SENDER_ID.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
