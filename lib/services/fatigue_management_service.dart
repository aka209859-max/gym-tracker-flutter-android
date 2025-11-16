import 'package:shared_preferences/shared_preferences.dart';

/// 疲労管理システムサービス
/// 
/// ユーザーの疲労管理システムのON/OFF状態を管理
class FatigueManagementService {
  static const String _fatigueManagementKey = 'fatigue_management_enabled';
  static const String _lastWorkoutDateKey = 'last_workout_date';

  /// 疲労管理システムが有効かどうかを取得
  Future<bool> isFatigueManagementEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // デフォルトはOFF（ユーザーが明示的に有効化する必要がある）
    return prefs.getBool(_fatigueManagementKey) ?? false;
  }

  /// 疲労管理システムのON/OFF状態を設定
  Future<void> setFatigueManagementEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fatigueManagementKey, enabled);
  }

  /// 最後のトレーニング日を保存
  Future<void> saveLastWorkoutDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastWorkoutDateKey, date.toIso8601String());
  }

  /// 最後のトレーニング日を取得
  Future<DateTime?> getLastWorkoutDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastWorkoutDateKey);
    
    if (dateString != null) {
      return DateTime.parse(dateString);
    }
    return null;
  }

  /// 本日トレーニングを実施したかチェック
  Future<bool> hasWorkoutToday() async {
    final lastWorkout = await getLastWorkoutDate();
    
    if (lastWorkout == null) return false;
    
    final now = DateTime.now();
    return lastWorkout.year == now.year &&
           lastWorkout.month == now.month &&
           lastWorkout.day == now.day;
  }
}
