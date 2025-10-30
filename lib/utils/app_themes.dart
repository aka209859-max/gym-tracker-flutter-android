import 'package:flutter/material.dart';

/// FitSync デザインテーマ定義
class AppThemes {
  // ========== デザイン案A: エネルギッシュ系 ==========
  static ThemeData energeticTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1a237e), // ダークブルー
      primary: const Color(0xFF1a237e),
      secondary: const Color(0xFFff6f00), // エナジーオレンジ
      surface: const Color(0xFFffffff), // クリーンホワイト
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFffffff),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF1a237e),
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // 角丸強化
      ),
      shadowColor: Colors.orange.withValues(alpha: 0.3), // グラデーションシャドウ
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFff6f00),
        foregroundColor: Colors.white,
        elevation: 6, // 立体感
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFff6f00),
      foregroundColor: Colors.white,
      elevation: 8,
    ),
  );

  // ========== デザイン案B: モチベーション系 ==========
  static ThemeData motivationTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFc62828), // パワーレッド
      primary: const Color(0xFFc62828),
      secondary: const Color(0xFF757575), // シルバー
      surface: const Color(0xFF263238), // ダークグレー
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF263238),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFFc62828),
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 6,
      color: const Color(0xFF37474f),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: Colors.red.withValues(alpha: 0.4),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFc62828),
        foregroundColor: Colors.white,
        elevation: 8,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFc62828),
      foregroundColor: Colors.white,
      elevation: 10,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
  );

  // ========== デザイン案C: プロフェッショナル系 ==========
  static ThemeData professionalTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1976d2), // NexaJPブルー
      primary: const Color(0xFF1976d2),
      secondary: const Color(0xFF388e3c), // アクティブグリーン
      surface: const Color(0xFFf5f5f5), // ライトグレー
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFf5f5f5),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF1976d2),
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: Colors.blue.withValues(alpha: 0.2),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF388e3c),
        foregroundColor: Colors.white,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF388e3c),
      foregroundColor: Colors.white,
      elevation: 6,
    ),
  );

  // テーマ名のマッピング（2テーマ体制）
  static Map<String, ThemeData> themes = {
    'energetic': energeticTheme,
    'motivation': motivationTheme,
  };

  // テーマの説明
  static Map<String, Map<String, dynamic>> themeDescriptions = {
    'energetic': {
      'name': 'エネルギッシュ系',
      'description': 'ダークブルー × エナジーオレンジ\n活力とモチベーションを刺激',
      'colors': {
        'primary': Color(0xFF1a237e),
        'secondary': Color(0xFFff6f00),
        'background': Color(0xFFffffff),
      },
    },
    'motivation': {
      'name': 'モチベーション系',
      'description': 'パワーレッド × シルバー\n情熱と力強さを表現',
      'colors': {
        'primary': Color(0xFFc62828),
        'secondary': Color(0xFF757575),
        'background': Color(0xFF263238),
      },
    },
  };
}
