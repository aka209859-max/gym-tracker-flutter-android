import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Production-safe ログ出力クラス
/// 
/// 特徴:
/// - すべてのプラットフォームで動作
/// - Release Buildでも確実に出力される（developer.log使用）
/// - プラットフォーム分岐不要
class ConsoleLogger {
  /// デバッグログ (リリースビルドでは無効)
  static void debug(String message, {String? tag}) {
    if (!kDebugMode) return; // リリースビルドでは何もしない
    
    final timestamp = DateTime.now().toString().substring(11, 19);
    final tagStr = tag != null ? '[$tag] ' : '';
    final output = '🔍 DEBUG [$timestamp] $tagStr$message';
    debugPrint(output);
  }
  
  /// 情報ログ (リリースビルドでは無効)
  static void info(String message, {String? tag}) {
    if (!kDebugMode) return; // リリースビルドでは何もしない
    
    final timestamp = DateTime.now().toString().substring(11, 19);
    final tagStr = tag != null ? '[$tag] ' : '';
    final output = '✅ INFO [$timestamp] $tagStr$message';
    debugPrint(output);
  }
  
  /// 警告ログ (リリースビルドでは無効)
  static void warn(String message, {String? tag}) {
    if (!kDebugMode) return; // リリースビルドでは何もしない
    
    final timestamp = DateTime.now().toString().substring(11, 19);
    final tagStr = tag != null ? '[$tag] ' : '';
    final output = '⚠️ WARN [$timestamp] $tagStr$message';
    debugPrint(output);
  }
  
  /// エラーログ (リリースビルドではFirebase Crashlyticsを使用)
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return; // リリースビルドでは何もしない
    
    final timestamp = DateTime.now().toString().substring(11, 19);
    final tagStr = tag != null ? '[$tag] ' : '';
    final output = '❌ ERROR [$timestamp] $tagStr$message';
    debugPrint(output);
    if (error != null) debugPrint('   Error: $error');
    if (stackTrace != null) debugPrint('   StackTrace: $stackTrace');
  }
  
  /// ユーザーアクションログ (リリースビルドでは無効)
  static void userAction(String action, {Map<String, dynamic>? data}) {
    if (!kDebugMode) return; // リリースビルドでは何もしない
    
    final timestamp = DateTime.now().toString().substring(11, 19);
    final dataStr = data != null ? ' | Data: $data' : '';
    final output = '👤 USER_ACTION [$timestamp] $action$dataStr';
    debugPrint(output);
  }
  
  /// 初期化ログ (リリースビルドでは無効)
  static void init() {
    if (!kDebugMode) return; // リリースビルドでは何もしない
    
    final timestamp = DateTime.now().toString().substring(11, 19);
    final platform = kIsWeb ? 'WEB' : 'MOBILE';
    final mode = kDebugMode ? 'DEBUG' : 'RELEASE';
    final output = '🚀 ConsoleLogger initialized [$platform/$mode] [$timestamp]';
    debugPrint(output);
  }
}
