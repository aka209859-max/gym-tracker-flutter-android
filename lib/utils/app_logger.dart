import 'package:flutter/foundation.dart';

/// アプリケーション統一ロガー（環境適応型）
/// 
/// 機能:
/// - Web環境: すべてのログを出力（デバッグ用）
/// - Mobile Debug: すべてのログを出力
/// - Mobile Release: 重要なログ（warn, error, userAction）のみ出力
/// 
/// 設計哲学:
/// - Web Release Buildでもログが見えるようにする（開発効率優先）
/// - Mobile Releaseでは本番用にログを最小化（パフォーマンス優先）
/// - 将来的なログレベル設定機能の拡張を見越した設計
/// 
/// 使用例:
/// ```dart
/// AppLogger.debug(AppLocalizations.of(context)!.general_6a780cce);
/// AppLogger.info(AppLocalizations.of(context)!.general_b4211e9a);
/// AppLogger.warn(AppLocalizations.of(context)!.general_77a42488);
/// AppLogger.error(AppLocalizations.of(context)!.error_7740d54f);
/// AppLogger.userAction('BUTTON_CLICKED');
/// ```
class AppLogger {
  /// ログレベル
  static const String _levelDebug = '🔍 DEBUG';
  static const String _levelInfo = '✅ INFO';
  static const String _levelWarn = '⚠️ WARN';
  static const String _levelError = '❌ ERROR';
  
  /// Web環境かどうかを判定
  static bool get _isWeb => kIsWeb;
  
  /// 初期化ログ（システム起動時に必ず出力）
  static void init() {
    final env = _isWeb ? 'WEB' : 'MOBILE';
    final mode = kDebugMode ? 'DEBUG' : 'RELEASE';
    print('🚀 AppLogger initialized [$env $mode]');
  }
  
  /// デバッグログ（Web環境では常に出力、Mobile Debugのみ出力）
  static void debug(String message, {String? tag}) {
    if (_isWeb || kDebugMode) {
      _log(_levelDebug, message, tag);
    }
  }
  
  /// 情報ログ（Web環境では常に出力、Mobile Debugのみ出力）
  static void info(String message, {String? tag}) {
    if (_isWeb || kDebugMode) {
      _log(_levelInfo, message, tag);
    }
  }
  
  /// 警告ログ（すべての環境で出力）
  static void warn(String message, {String? tag}) {
    _log(_levelWarn, message, tag);
  }
  
  /// エラーログ（すべての環境で出力）
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_levelError, message, tag);
    if (error != null) {
      print('   Error: $error');
    }
    if (stackTrace != null && (_isWeb || kDebugMode)) {
      print('   StackTrace: $stackTrace');
    }
  }
  
  /// ログ出力の内部実装
  static void _log(String level, String message, String? tag) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final tagStr = tag != null ? '[$tag] ' : '';
    print('$level [$timestamp] $tagStr$message');
  }
  
  /// ユーザーアクション専用ログ（常に出力、分析用）
  static void userAction(String action, {Map<String, dynamic>? data}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final dataStr = data != null ? ' | Data: $data' : '';
    print('👤 USER_ACTION [$timestamp] $action$dataStr');
  }
  
  /// パフォーマンス測定用ログ（Web環境またはDebug環境のみ）
  static void performance(String operation, Duration duration) {
    if (_isWeb || kDebugMode) {
      final timestamp = DateTime.now().toString().substring(11, 19);
      print('⚡ PERFORMANCE [$timestamp] $operation: ${duration.inMilliseconds}ms');
    }
  }
  
  /// セパレーター（視認性向上）
  static void separator({String? title}) {
    if (_isWeb || kDebugMode) {
      if (title != null) {
        print('\n${'=' * 60}');
        print('  $title');
        print('=' * 60);
      } else {
        print('-' * 60);
      }
    }
  }
}
