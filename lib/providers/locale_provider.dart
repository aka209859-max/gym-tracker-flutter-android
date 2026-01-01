import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 言語設定を管理するProvider
/// 
/// サポート言語:
/// - ja: 日本語
/// - en: 英語（米国）
/// - ko: 韓国語
/// - zh: 中国語（簡体字）
/// - de: ドイツ語
/// - es: スペイン語
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('ja'); // デフォルト: 日本語
  
  static const String _localeKey = 'app_locale';
  
  /// サポートされている言語リスト
  static const List<LocaleInfo> supportedLocales = [
    LocaleInfo(locale: Locale('ja'), name: 'Japanese', nativeName: '日本語', flag: '🇯🇵'),
    LocaleInfo(locale: Locale('en'), name: 'English', nativeName: 'English', flag: '🇺🇸'),
    LocaleInfo(locale: Locale('ko'), name: 'Korean', nativeName: '한국어', flag: '🇰🇷'),
    LocaleInfo(locale: Locale('zh'), name: 'Chinese', nativeName: '中文', flag: '🇨🇳'),
    LocaleInfo(locale: Locale('de'), name: 'German', nativeName: 'Deutsch', flag: '🇩🇪'),
    LocaleInfo(locale: Locale('es'), name: 'Spanish', nativeName: 'Español', flag: '🇪🇸'),
  ];
  
  Locale get locale => _locale;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  LocaleProvider() {
    _loadLocale();
  }
  
  /// SharedPreferencesから保存された言語設定を読み込み
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_localeKey);
      
      if (languageCode != null) {
        // サポートされている言語かチェック
        final isSupported = supportedLocales.any((info) => info.locale.languageCode == languageCode);
        if (isSupported) {
          _locale = Locale(languageCode);
          print('✅ 保存された言語設定を読み込み: $languageCode');
        } else {
          print('⚠️ サポートされていない言語コード: $languageCode (デフォルト: ja)');
        }
      }
    } catch (e) {
      print('⚠️ 言語設定の読み込みに失敗: $e (デフォルト: ja)');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  /// 言語を変更してSharedPreferencesに保存
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    
    _locale = locale;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
      print('✅ 言語設定を保存: ${locale.languageCode}');
    } catch (e) {
      print('❌ 言語設定の保存に失敗: $e');
    }
  }
  
  /// 現在の言語情報を取得
  LocaleInfo get currentLocaleInfo {
    return supportedLocales.firstWhere(
      (info) => info.locale.languageCode == _locale.languageCode,
      orElse: () => supportedLocales[0], // デフォルト: 日本語
    );
  }
}

/// 言語情報クラス
class LocaleInfo {
  final Locale locale;
  final String name;        // 英語名
  final String nativeName;  // ネイティブ名（その言語での表記）
  final String flag;        // 国旗絵文字
  
  const LocaleInfo({
    required this.locale,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}
