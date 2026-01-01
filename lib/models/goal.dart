import 'package:cloud_firestore/cloud_firestore.dart';

/// 目標の種類
enum GoalType {
  weeklyWorkoutCount,  // 週間トレーニング回数
  monthlyTotalWeight,  // 月間総重量
}

/// 目標の期間
enum GoalPeriod {
  weekly,  // 週間
  monthly, // 月間
}

/// 目標モデル
class Goal {
  final String id;
  final String userId;
  final GoalType type;
  final GoalPeriod period;
  final int targetValue;    // 目標値
  final int currentValue;   // 現在の進捗値
  final DateTime startDate; // 開始日
  final DateTime endDate;   // 終了日
  final bool isActive;      // アクティブフラグ
  final bool isCompleted;   // 達成フラグ
  final DateTime? completedAt;

  Goal({
    required this.id,
    required this.userId,
    required this.type,
    required this.period,
    required this.targetValue,
    required this.currentValue,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.isCompleted = false,
    this.completedAt,
  });

  /// Firestoreドキュメントから変換
  factory Goal.fromFirestore(Map<String, dynamic> data, String docId) {
    return Goal(
      id: docId,
      userId: data['user_id'] as String? ?? '',
      type: _typeFromString(data['type'] as String? ?? 'weeklyWorkoutCount'),
      period: _periodFromString(data['period'] as String? ?? 'weekly'),
      targetValue: data['target_value'] as int? ?? 0,
      currentValue: data['current_value'] as int? ?? 0,
      startDate: (data['start_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['end_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['is_active'] as bool? ?? true,
      isCompleted: data['is_completed'] as bool? ?? false,
      completedAt: (data['completed_at'] as Timestamp?)?.toDate(),
    );
  }

  /// Firestoreドキュメントに変換
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'type': type.name,
      'period': period.name,
      'target_value': targetValue,
      'current_value': currentValue,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
      'is_active': isActive,
      'is_completed': isCompleted,
      'completed_at': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  /// 進捗率を計算（0.0 〜 1.0）
  double get progress {
    if (targetValue == 0) return 0.0;
    final progressValue = currentValue / targetValue;
    return progressValue > 1.0 ? 1.0 : progressValue;
  }

  /// 進捗率をパーセントで取得
  int get progressPercent {
    return (progress * 100).toInt();
  }

  /// 残り日数
  int get daysRemaining {
    final now = DateTime.now();
    final difference = endDate.difference(now);
    return difference.inDays < 0 ? 0 : difference.inDays;
  }

  /// 目標が期限切れか
  bool get isExpired {
    return DateTime.now().isAfter(endDate);
  }

  /// 目標名を取得
  String get name {
    switch (type) {
      case GoalType.weeklyWorkoutCount:
        return AppLocalizations.of(context)!.general_e9b451c8;
      case GoalType.monthlyTotalWeight:
        return AppLocalizations.of(context)!.general_12bffb53;
    }
  }

  /// 目標の単位を取得
  String get unit {
    switch (type) {
      case GoalType.weeklyWorkoutCount:
        return AppLocalizations.of(context)!.workoutRepsLabel;
      case GoalType.monthlyTotalWeight:
        return AppLocalizations.of(context)!.kg;
    }
  }

  /// 目標のアイコンを取得
  String get iconName {
    switch (type) {
      case GoalType.weeklyWorkoutCount:
        return 'event_repeat';
      case GoalType.monthlyTotalWeight:
        return 'fitness_center';
    }
  }

  /// 文字列からGoalTypeに変換
  static GoalType _typeFromString(String value) {
    switch (value) {
      case 'weeklyWorkoutCount':
        return GoalType.weeklyWorkoutCount;
      case 'monthlyTotalWeight':
        return GoalType.monthlyTotalWeight;
      default:
        return GoalType.weeklyWorkoutCount;
    }
  }

  /// 文字列からGoalPeriodに変換
  static GoalPeriod _periodFromString(String value) {
    switch (value) {
      case 'weekly':
        return GoalPeriod.weekly;
      case 'monthly':
        return GoalPeriod.monthly;
      default:
        return GoalPeriod.weekly;
    }
  }

  /// 目標のコピーを作成
  Goal copyWith({
    String? id,
    String? userId,
    GoalType? type,
    GoalPeriod? period,
    int? targetValue,
    int? currentValue,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      period: period ?? this.period,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
