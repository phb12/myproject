import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'register_page.dart';

Future<void> main() async {
  // 必須確保 Flutter Binding 被初始化，才能使用 Firebase 相關功能
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Firebase 核心服務
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 移除匿名登入，改由 LoginPage 處理正式登入

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '登入+主頁',
      // 設定應用程式的主題顏色，可根據需求調整
      theme: ThemeData(primarySwatch: Colors.blue),

      // 支援多國語言設定，這裡設定為支援中文和英文
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],

      // 應用程式的起始頁面
      home: const LoginPage(),

      // 命名路由定義
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        // 更多頁面可依需求隨時擴充...
      },
    );
  }
}
