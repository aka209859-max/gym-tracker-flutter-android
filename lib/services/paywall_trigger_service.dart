import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ペイウォール表示トリガー管理サービス
/// 
/// ユーザーの行動に基づいて最適なタイミングでペイウォールを表示します
class PaywallTriggerService {
  static const String _keyDay7PaywallShown = 'paywall_day7_shown';
  static const String _keyFirstLaunchDate = 'first_launch_date';

  /// Day 7ペイウォールを表示すべきか判定
  Future<bool> shouldShowDay7Paywall() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 既に表示済みならfalse
    final shown = prefs.getBool(_keyDay7PaywallShown) ?? false;
    if (shown) return false;
    
    // 初回起動日を取得
    final firstLaunchStr = prefs.getString(_keyFirstLaunchDate);
    if (firstLaunchStr == null) {
      // 初回起動日を記録
      await prefs.setString(_keyFirstLaunchDate, DateTime.now().toIso8601String());
      return false;
    }
    
    // 7日経過しているかチェック
    final firstLaunch = DateTime.parse(firstLaunchStr);
    final now = DateTime.now();
    final daysSinceFirstLaunch = now.difference(firstLaunch).inDays;
    
    return daysSinceFirstLaunch >= 7;
  }

  /// Day 7ペイウォールを表示済みとしてマーク
  Future<void> markDay7PaywallShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDay7PaywallShown, true);
  }

  /// ペイウォール表示状態をリセット（デバッグ用）
  Future<void> resetPaywallTriggers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDay7PaywallShown);
  }

  /// アプリ起動日数を取得
  Future<int> getDaysSinceFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunchStr = prefs.getString(_keyFirstLaunchDate);
    
    if (firstLaunchStr == null) {
      await prefs.setString(_keyFirstLaunchDate, DateTime.now().toIso8601String());
      return 0;
    }
    
    final firstLaunch = DateTime.parse(firstLaunchStr);
    final now = DateTime.now();
    return now.difference(firstLaunch).inDays;
  }
}
