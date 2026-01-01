// lib/services/habit_formation_service.dart
// 習慣形成サポートサービス

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 習慣形成マイルストーン
enum HabitMilestone {
  streak10(10, AppLocalizations.of(context)!.general_bcb900c4),
  streak30(30, AppLocalizations.of(context)!.general_b32b7934),
  streak50(50, AppLocalizations.of(context)!.general_119ecef6),
  streak100(100, AppLocalizations.of(context)!.general_0501c995),
  streak365(365, AppLocalizations.of(context)!.general_31b3e4e4);

  const HabitMilestone(this.days, this.message);
  final int days;
  final String message;
}

/// 習慣形成サービス
/// トレーニング習慣の維持・強化をサポート
class HabitFormationService {
  static const String _keyMilestonesShown = 'milestones_shown';
  static const String _keyWeeklyGoal = 'weekly_training_goal';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 現在の連続トレーニング日数を取得
  Future<int> getCurrentStreak() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      // 過去60日分のトレーニング記録を取得
      final now = DateTime.now();
      final sixtyDaysAgo = now.subtract(const Duration(days: 60));

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(sixtyDaysAgo))
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

      // 今日または昨日にトレーニングがあれば連続記録開始
      if (!trainingDates.contains(checkDate)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        if (!trainingDates.contains(checkDate)) {
          return 0; // 今日も昨日もトレーニングしていない
        }
      }

      // 連続日数をカウント
      for (int i = 0; i < 60; i++) {
        if (trainingDates.contains(checkDate)) {
          streakDays++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streakDays;
    } catch (e) {
      print('Error getting current streak: $e');
      return 0;
    }
  }

  /// 今週のトレーニング回数を取得
  /// 
  /// 戻り値: {current: 今週の実績, goal: 週間目標}
  Future<Map<String, int>> getWeeklyProgress() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'current': 0, 'goal': 3};

      // 今週の開始日（月曜日）と終了日（日曜日）を計算
      final now = DateTime.now();
      final weekday = now.weekday; // 1=月曜, 7=日曜
      final weekStart = now.subtract(Duration(days: weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final weekEnd = weekStartDate.add(const Duration(days: 7));

      // 今週のトレーニング記録を取得
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartDate))
          .where('date', isLessThan: Timestamp.fromDate(weekEnd))
          .get();

      // 日付のセットを作成（重複排除）
      final trainingDates = <DateTime>{};
      for (final doc in snapshot.docs) {
        final dateTimestamp = doc['date'] as Timestamp?;
        if (dateTimestamp != null) {
          final date = dateTimestamp.toDate();
          trainingDates.add(DateTime(date.year, date.month, date.day));
        }
      }

      final currentCount = trainingDates.length;
      final goalCount = await getWeeklyGoal();

      return {'current': currentCount, 'goal': goalCount};
    } catch (e) {
      print('Error getting weekly progress: $e');
      return {'current': 0, 'goal': 3};
    }
  }

  /// 週間目標を取得
  Future<int> getWeeklyGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyWeeklyGoal) ?? 3; // デフォルト: 週3回
    } catch (e) {
      print('Error getting weekly goal: $e');
      return 3;
    }
  }

  /// 週間目標を設定
  Future<void> setWeeklyGoal(int goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyWeeklyGoal, goal);
    } catch (e) {
      print('Error setting weekly goal: $e');
    }
  }

  /// 最もトレーニングしている曜日TOP3を取得
  /// 
  /// 戻り値: [{'weekday': AppLocalizations.of(context)!.wednesday, 'count': 10}, ...]
  Future<List<Map<String, dynamic>>> getTopTrainingDays() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // 過去3ヶ月分のトレーニング記録を取得
      final now = DateTime.now();
      final threeMonthsAgo = now.subtract(const Duration(days: 90));

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(threeMonthsAgo))
          .get();

      // 曜日ごとのカウント
      final weekdayCount = <int, int>{
        1: 0, // 月曜
        2: 0, // 火曜
        3: 0, // 水曜
        4: 0, // 木曜
        5: 0, // 金曜
        6: 0, // 土曜
        7: 0, // 日曜
      };

      for (final doc in snapshot.docs) {
        final dateTimestamp = doc['date'] as Timestamp?;
        if (dateTimestamp != null) {
          final date = dateTimestamp.toDate();
          weekdayCount[date.weekday] = (weekdayCount[date.weekday] ?? 0) + 1;
        }
      }

      // カウントが多い順にソート
      final sortedWeekdays = weekdayCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // TOP3を取得
      final top3 = sortedWeekdays.take(3).map((entry) {
        return {
          'weekday': _getWeekdayName(entry.key),
          'weekdayNum': entry.key,
          'count': entry.value,
        };
      }).toList();

      return top3;
    } catch (e) {
      print('Error getting top training days: $e');
      return [];
    }
  }

  /// 曜日番号から曜日名を取得
  String _getWeekdayName(int weekday) {
    const weekdayNames = {
      1: AppLocalizations.of(context)!.monday,
      2: AppLocalizations.of(context)!.tuesday,
      3: AppLocalizations.of(context)!.wednesday,
      4: AppLocalizations.of(context)!.thursday,
      5: AppLocalizations.of(context)!.friday,
      6: AppLocalizations.of(context)!.saturday,
      7: AppLocalizations.of(context)!.sunday,
    };
    return weekdayNames[weekday] ?? '';
  }

  /// マイルストーンをチェックして未表示のものを返す
  /// 
  /// 戻り値: 表示すべきマイルストーン（null なら表示不要）
  Future<HabitMilestone?> checkMilestone() async {
    try {
      final currentStreak = await getCurrentStreak();
      
      // マイルストーン達成をチェック（大きい順）
      final milestones = [
        HabitMilestone.streak365,
        HabitMilestone.streak100,
        HabitMilestone.streak50,
        HabitMilestone.streak30,
        HabitMilestone.streak10,
      ];

      for (final milestone in milestones) {
        if (currentStreak >= milestone.days) {
          final isShown = await _isMilestoneShown(milestone);
          if (!isShown) {
            return milestone;
          }
        }
      }

      return null;
    } catch (e) {
      print('Error checking milestone: $e');
      return null;
    }
  }

  /// マイルストーンが既に表示済みかチェック
  Future<bool> _isMilestoneShown(HabitMilestone milestone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownMilestones = prefs.getStringList(_keyMilestonesShown) ?? [];
      return shownMilestones.contains(milestone.name);
    } catch (e) {
      print('Error checking if milestone shown: $e');
      return false;
    }
  }

  /// マイルストーンを表示済みとしてマーク
  Future<void> markMilestoneShown(HabitMilestone milestone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownMilestones = prefs.getStringList(_keyMilestonesShown) ?? [];
      if (!shownMilestones.contains(milestone.name)) {
        shownMilestones.add(milestone.name);
        await prefs.setStringList(_keyMilestonesShown, shownMilestones);
      }
    } catch (e) {
      print('Error marking milestone shown: $e');
    }
  }

  /// 次のマイルストーンまでの残り日数を取得
  Future<Map<String, dynamic>?> getNextMilestone() async {
    try {
      final currentStreak = await getCurrentStreak();
      
      // 次に達成できるマイルストーンを探す
      final milestones = [
        HabitMilestone.streak10,
        HabitMilestone.streak30,
        HabitMilestone.streak50,
        HabitMilestone.streak100,
        HabitMilestone.streak365,
      ];

      for (final milestone in milestones) {
        if (currentStreak < milestone.days) {
          final daysRemaining = milestone.days - currentStreak;
          return {
            'milestone': milestone,
            'daysRemaining': daysRemaining,
            'targetDays': milestone.days,
          };
        }
      }

      return null; // 全てのマイルストーン達成済み
    } catch (e) {
      print('Error getting next milestone: $e');
      return null;
    }
  }
}
