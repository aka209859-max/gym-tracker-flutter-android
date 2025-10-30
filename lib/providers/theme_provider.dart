import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_themes.dart';

/// テーマ管理プロバイダー
class ThemeProvider with ChangeNotifier {
  String _currentThemeKey = 'energetic'; // デフォルト: エネルギッシュ系
  ThemeData _currentTheme = AppThemes.energeticTheme;

  String get currentThemeKey => _currentThemeKey;
  ThemeData get currentTheme => _currentTheme;

  ThemeProvider() {
    _loadThemePreference();
  }

  /// 保存されたテーマ設定を読み込む
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('app_theme') ?? 'energetic';
      _currentThemeKey = savedTheme;
      _currentTheme = AppThemes.themes[savedTheme] ?? AppThemes.energeticTheme;
      notifyListeners();
    } catch (e) {
      // デフォルトテーマを使用
      debugPrint('Failed to load theme preference: $e');
    }
  }

  /// テーマを変更
  Future<void> setTheme(String themeKey) async {
    if (AppThemes.themes.containsKey(themeKey)) {
      _currentThemeKey = themeKey;
      _currentTheme = AppThemes.themes[themeKey]!;
      
      // 設定を保存
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_theme', themeKey);
      } catch (e) {
        debugPrint('Failed to save theme preference: $e');
      }
      
      notifyListeners();
    }
  }

  /// 利用可能なテーマ一覧を取得
  List<String> getAvailableThemes() {
    return AppThemes.themes.keys.toList();
  }

  /// テーマ情報を取得
  Map<String, dynamic> getThemeInfo(String themeKey) {
    return AppThemes.themeDescriptions[themeKey] ?? {};
  }
}
