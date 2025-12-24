// 設定主題與底部導覽列

import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 【新增】
import 'package:intl/date_symbol_data_local.dart';

import './services/database_helper.dart';
import './pages/login_page.dart';

import './pages/dashboard_home_page.dart';
import './pages/select_part_page.dart';
import './pages/workout_history_page.dart';
import './pages/settings_page.dart';
import '../pages/community_profile_page.dart';
import 'firebase_options.dart';

void main() async {
//firebase 初始化
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 【核心修正】使用 DefaultFirebaseOptions，它會自動處理所有平台
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase 初始化成功");
  } catch (e) {
    debugPrint("Firebase 初始化失敗: $e");
    // In release mode, if Firebase fails, we might want to know why on the UI if possible, 
    // or at least ensure we don't crash later.
  }

  await initializeDateFormatting();
  
  try {
    await DatabaseHelper.instance.initDB();
    debugPrint("Database initialized successfully");
  } catch (e) {
    debugPrint("Database initialization failed: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0A84FF);

    return MaterialApp(
      title: '智慧健身 App',
      debugShowCheckedModeBanner: false,
      // 【新增】本地化設定 (DatePicker 必須)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('zh', 'TW'),
      ],
      theme: ThemeData(
        useMaterial3: false,
        splashFactory: InkRipple.splashFactory,
        fontFamily: 'PingFang TC',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),

        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
          surface: const Color(0xFF1C1C1E),
          primary: primaryColor,
        ),

        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF00B900);
            }
            return Colors.grey.shade600;
          }),
        ),

        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: const Color(0xFF2C2C2E),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'PingFang TC',
              )),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2E),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          labelStyle: TextStyle(
            color: Colors.grey.shade500,
          ),
          floatingLabelStyle: const TextStyle(
            color: primaryColor,
          ),
        ),

        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0xFF1C1C1E),
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade600, // 未選中
          type: BottomNavigationBarType.fixed, // 確保
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// 導覽列框架
class MainAppShell extends StatefulWidget {
  final String account;
  const MainAppShell({super.key, required this.account});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      DashboardHomePage(account: widget.account),
      const SelectPartPage(),
      WorkoutHistoryPage(account: widget.account),
      
      // 【修改】直接使用 CommunityProfilePage 作為第四個分頁
      CommunityProfilePage(account: widget.account),
      
      SettingsPage(account: widget.account),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '首頁',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: '開始訓練',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: '日曆',
          ),
          // 【修改】將「建議課程」(燈泡) 改為「社群」(人群)
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined), // 未選中圖示
            activeIcon: Icon(Icons.person), // 選中圖示
            label: '個人',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        // 【重要】確認您的 bottomNavigationBarTheme 已設定
        // (這段應該已在您的 MyApp class 中，這裡只是提醒)
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
