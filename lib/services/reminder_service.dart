// lib/services/reminder_service.dart
// トレーニングリマインダーサービス（アプリ内リマインダー）

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// リマインダータイプ
enum ReminderType {
  training48Hours, // トレーニング後48時間経過
  streak7Days, // 7日連続達成
  inactive7Days, // 7日間未記録
  aiAnalysisComplete, // AI分析完了
}

/// リマインダーサービス
/// アプリ内リマインダーの表示制御とロジックを管理
class ReminderService {
  static const String _keyLastTrainingDate = 'last_training_date';
  static const String _keyLastStreakReminderDate = 'last_streak_reminder_date';
  static const String _keyLastInactiveReminderDate =
      'last_inactive_reminder_date';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// トレーニング後48時間経過リマインダーを表示すべきか
  /// 
  /// 条件:
  /// - 最後のトレーニングから48時間以上経過
  /// - 今日まだトレーニングしていない
  Future<bool> shouldShow48HourReminder() async {
    try {
      final lastTrainingDate = await _getLastTrainingDate();
      if (lastTrainingDate == null) return false;

      final now = DateTime.now();
      final hoursSinceLastTraining =
          now.difference(lastTrainingDate).inHours;

      // 48時間以上経過 かつ 72時間未満（7日間未記録リマインダーと重複防止）
      if (hoursSinceLastTraining >= 48 && hoursSinceLastTraining < 168) {
        // 今日のトレーニング記録をチェック
        final hasTrainedToday = await _hasTrainedToday();
        return !hasTrainedToday;
      }

      return false;
    } catch (e) {
      print('Error checking 48-hour reminder: $e');
      return false;
    }
  }

  /// 7日連続達成リマインダーを表示すべきか
  /// 
  /// 条件:
  /// - 過去7日間連続でトレーニング記録がある
  /// - 今日まだこのリマインダーを表示していない
  Future<bool> shouldShow7DayStreakReminder() async {
    try {
      final streakDays = await _getStreakDays();
      if (streakDays < 7) return false;

      // 今日既に表示済みかチェック
      final prefs = await SharedPreferences.getInstance();
      final lastReminderDateStr =
          prefs.getString(_keyLastStreakReminderDate);

      if (lastReminderDateStr != null) {
        final lastReminderDate = DateTime.parse(lastReminderDateStr);
        final now = DateTime.now();
        if (_isSameDay(lastReminderDate, now)) {
          return false; // 今日既に表示済み
        }
      }

      return true;
    } catch (e) {
      print('Error checking 7-day streak reminder: $e');
      return false;
    }
  }

  /// 7日間未記録の再エンゲージリマインダーを表示すべきか
  /// 
  /// 条件:
  /// - 最後のトレーニングから7日以上経過
  /// - 過去24時間以内にこのリマインダーを表示していない
  Future<bool> shouldShow7DayInactiveReminder() async {
    try {
      final lastTrainingDate = await _getLastTrainingDate();
      if (lastTrainingDate == null) return false;

      final now = DateTime.now();
      final daysSinceLastTraining =
          now.difference(lastTrainingDate).inDays;

      if (daysSinceLastTraining < 7) return false;

      // 過去24時間以内に表示済みかチェック
      final prefs = await SharedPreferences.getInstance();
      final lastReminderDateStr =
          prefs.getString(_keyLastInactiveReminderDate);

      if (lastReminderDateStr != null) {
        final lastReminderDate = DateTime.parse(lastReminderDateStr);
        final hoursSinceLastReminder =
            now.difference(lastReminderDate).inHours;
        if (hoursSinceLastReminder < 24) {
          return false; // 過去24時間以内に表示済み
        }
      }

      return true;
    } catch (e) {
      print('Error checking 7-day inactive reminder: $e');
      return false;
    }
  }

  /// 7日連続達成リマインダーを表示済みとしてマーク
  Future<void> markStreak7DayReminderShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyLastStreakReminderDate,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('Error marking streak reminder shown: $e');
    }
  }

  /// 7日間未記録リマインダーを表示済みとしてマーク
  Future<void> markInactive7DayReminderShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyLastInactiveReminderDate,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('Error marking inactive reminder shown: $e');
    }
  }

  /// 最後のトレーニング日を取得
  Future<DateTime?> _getLastTrainingDate() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Firestoreから最新のトレーニング日を取得
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final dateTimestamp = snapshot.docs.first['date'] as Timestamp?;
      return dateTimestamp?.toDate();
    } catch (e) {
      print('Error getting last training date: $e');
      return null;
    }
  }

  /// 今日トレーニングしたかチェック
  Future<bool> _hasTrainedToday() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThan: Timestamp.fromDate(todayEnd))
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if trained today: $e');
      return false;
    }
  }

  /// 連続トレーニング日数を取得
  Future<int> _getStreakDays() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      // 過去30日分のトレーニング記録を取得
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('date', descending: true)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      // 日付のセットを作成（重複排除）
      final trainingDates = <DateTime>{};
      for (final doc in snapshot.docs) {
        final dateTimestamp = doc['date'] as Timestamp?;
        if (dateTimestamp != null) {
          final date = dateTimestamp.toDate();
          trainingDates.add(DateTime(date.year, date.month, date.day));
        }
      }

      // 連続日数をカウント
      int streakDays = 0;
      DateTime checkDate = DateTime(now.year, now.month, now.day);

      for (int i = 0; i < 30; i++) {
        if (trainingDates.contains(checkDate)) {
          streakDays++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streakDays;
    } catch (e) {
      print('Error getting streak days: $e');
      return 0;
    }
  }

  /// 同じ日かチェック
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// トレーニング記録後に呼ぶメソッド（最終トレーニング日を更新）
  Future<void> updateLastTrainingDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyLastTrainingDate,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('Error updating last training date: $e');
    }
  }
}
