import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 用于存储用户选择的主题模式
import 'ui/screens/map_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'theme/app_theme.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 引入 Riverpod
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy();

  // Initialize the databaseFactory
  databaseFactory = databaseFactoryFfi;
  
  runApp(
    const ProviderScope( // 包装 MyApp
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget { // 使用 ConsumerStatefulWidget 替换 StatefulWidget
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends ConsumerState<MyApp> { // 使用 ConsumerState 替换 State
  ThemeMode _themeMode = ThemeMode.system;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
  }

  Future<void> _initSharedPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadThemeMode();
    } catch (e) {
      print("Error initializing SharedPreferences: $e");
    }
  }

  Future<void> _loadThemeMode() async {
    final savedTheme = _prefs?.getString('theme_mode') ?? 'system';
    setState(() {
      _themeMode = _getThemeModeFromString(savedTheme);
    });
  }

  Future<void> _updateThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    await _prefs?.setString('theme_mode', mode.toString().split('.').last);
  }

  ThemeMode _getThemeModeFromString(String themeMode) {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map and Navigation App',
      theme: AppTheme.lightTheme, // 自定义浅色模式
      darkTheme: AppTheme.darkTheme, // 自定义深色模式
      themeMode: _themeMode, // 应用当前的主题模式
      home: MapScreen(onThemeChanged: _updateThemeMode),
      routes: <String, WidgetBuilder>{
        MapScreen.route: (context) => MapScreen(onThemeChanged: _updateThemeMode),
        SettingsScreen.route: (context) => SettingsScreen(onThemeChanged: _updateThemeMode),
      },
    );
  }
}
