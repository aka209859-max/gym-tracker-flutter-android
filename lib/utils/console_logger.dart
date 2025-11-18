import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Production-safe ログ出力クラス
/// 
/// 特徴:
/// - すべてのプラットフォーム（Web/iOS/Android）で動作
/// - Release Buildでも確実に出力される（developer.log使用）
/// - プラットフォーム分岐不要
class ConsoleLogger {
  /// デバッグログ
  static void debug(String message, {String? tag}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final tagStr = tag != null ? '[$tag] ' : '';
    final output = '🔍 DEBUG [$timestamp] $tagStr$message';
    
    if (kDebugMode) {
      debugPrint(output);
    } else {
      // Release Buildでもログ出力
      developer.log(output, name: 'DEBUG', level: 500);
    }
  }
  
  /// 情報ログ
  static void info(String message, {String? tag}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final tagStr = tag != null ? '[$tag] ' : '';
    final output = '✅ INFO [$timestamp] $tagStr$message';
    
    if (kDebugMode) {
      debugPrint(output);
    } else {
      developer.log(output, name: 'INFO', level: 800);
    }
  }
  
  /// 警告ログ
  static void warn(String message, {String? tag}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final tagStr = tag != null ? '[$tag] ' : '';
    final output = '⚠️ WARN [$timestamp] $tagStr$message';
    
    if (kDebugMode) {
      debugPrint(output);
    } else {
      developer.log(output, name: 'WARN', level: 900);
    }
  }
  
  /// エラーログ
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final tagStr = tag != null ? '[$tag] ' : '';
    final output = '❌ ERROR [$timestamp] $tagStr$message';
    
    if (kDebugMode) {
      debugPrint(output);
      if (error != null) debugPrint('   Error: $error');
      if (stackTrace != null) debugPrint('   StackTrace: $stackTrace');
    } else {
      developer.log(
        output,
        name: 'ERROR',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// ユーザーアクションログ
  static void userAction(String action, {Map<String, dynamic>? data}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final dataStr = data != null ? ' | Data: $data' : '';
    final output = '👤 USER_ACTION [$timestamp] $action$dataStr';
    
    if (kDebugMode) {
      debugPrint(output);
    } else {
      developer.log(output, name: 'USER_ACTION', level: 800);
    }
  }
  
  /// 初期化ログ
  static void init() {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final platform = kIsWeb ? 'WEB' : 'MOBILE';
    final mode = kDebugMode ? 'DEBUG' : 'RELEASE';
    final output = '🚀 ConsoleLogger initialized [$platform/$mode] [$timestamp]';
    
    if (kDebugMode) {
      debugPrint(output);
    } else {
      developer.log(output, name: 'INIT', level: 800);
    }
  }
}
