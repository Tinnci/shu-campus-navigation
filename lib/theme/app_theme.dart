import 'package:flutter/material.dart';

class AppTheme {
  // 定义浅色主题
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8dea88),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
    ),
    textTheme: _lightTextTheme,
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    inputDecorationTheme: _inputDecorationTheme,
  );

  // 定义深色主题
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4a8c4e),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1f1f1f),
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    textTheme: _darkTextTheme,
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    inputDecorationTheme: _inputDecorationTheme,
  );

  // 定义浅色主题的文本样式
  static const TextTheme _lightTextTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, color: Colors.black),
    titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w500, color: Colors.black),
    bodyLarge: TextStyle(fontSize: 16.0, color: Colors.black87),
    bodyMedium: TextStyle(fontSize: 14.0, color: Colors.black54),
    bodySmall: TextStyle(fontSize: 12.0, color: Colors.black45),
  );

  // 定义深色主题的文本样式
  static const TextTheme _darkTextTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, color: Colors.white),
    titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w500, color: Colors.white),
    bodyLarge: TextStyle(fontSize: 16.0, color: Colors.white70),
    bodyMedium: TextStyle(fontSize: 14.0, color: Colors.white60),
    bodySmall: TextStyle(fontSize: 12.0, color: Colors.white38),
  );

  // 定义按钮样式
  static final ElevatedButtonThemeData _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
      textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    ),
  );

  static final OutlinedButtonThemeData _outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
      textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    ),
  );

  // 定义输入框样式
  static const InputDecorationTheme _inputDecorationTheme = InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.green, width: 2.0),
    ),
    labelStyle: TextStyle(color: Colors.black54),
    hintStyle: TextStyle(color: Colors.black38),
  );
}
