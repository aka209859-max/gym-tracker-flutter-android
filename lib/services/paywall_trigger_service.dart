import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ペイウォール表示トリガー管理サービス
/// 
/// ユーザーの行動に基づいて最適なタイミングでペイウォールを表示します
/// Phase 1最適化: AI使用後、トレーニング記録後など最適なタイミングで表示
class PaywallTriggerService {
  static const String _keyDay7PaywallShown = 'paywall_day7_shown';
  static const String _keyFirstLaunchDate = 'first_launch_date';
  static const String _keyAiUsageCount = 'ai_usage_count';
  static const String _keyWorkoutCount = 'workout_count';
  static const String _keyAi3TimesPaywallShown = 'paywall_ai3_shown';
  static const String _keyWorkout5TimesPaywallShown = 'paywall_workout5_shown';

  /// AI使用回数をカウント
  Future<void> incrementAiUsageCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_keyAiUsageCount) ?? 0;
    await prefs.setInt(_keyAiUsageCount, count + 1);
  }

  /// トレーニング記録回数をカウント
  Future<void> incrementWorkoutCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_keyWorkoutCount) ?? 0;
    await prefs.setInt(_keyWorkoutCount, count + 1);
  }

  /// AI 3回使用後のペイウォール表示判定
  Future<bool> shouldShowAi3TimesPaywall() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 既に表示済みならfalse
    final shown = prefs.getBool(_keyAi3TimesPaywallShown) ?? false;
    if (shown) return false;
    
    // AI使用回数が3回以上か
    final count = prefs.getInt(_keyAiUsageCount) ?? 0;
    return count >= 3;
  }

  /// トレーニング5回記録後のペイウォール表示判定
  Future<bool> shouldShowWorkout5TimesPaywall() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 既に表示済みならfalse
    final shown = prefs.getBool(_keyWorkout5TimesPaywallShown) ?? false;
    if (shown) return false;
    
    // トレーニング記録回数が5回以上か
    final count = prefs.getInt(_keyWorkoutCount) ?? 0;
    return count >= 5;
  }

  /// AI 3回ペイウォールを表示済みとしてマーク
  Future<void> markAi3TimesPaywallShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAi3TimesPaywallShown, true);
  }

  /// トレーニング5回ペイウォールを表示済みとしてマーク
  Future<void> markWorkout5TimesPaywallShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWorkout5TimesPaywallShown, true);
  }

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
    
    // 3日経過しているかチェック（7日 → 3日に短縮）
    final firstLaunch = DateTime.parse(firstLaunchStr);
    final now = DateTime.now();
    final daysSinceFirstLaunch = now.difference(firstLaunch).inDays;
    
    return daysSinceFirstLaunch >= 3;
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
