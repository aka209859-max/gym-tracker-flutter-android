import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/exercise_master_data.dart'; // 🔧 v1.0.243

/// トレーニングログのモデル
class WorkoutLog {
  final String id;
  final String userId;
  final DateTime date;
  final String gymId;
  final String? gymName;
  final List<Exercise> exercises;
  final String? notes;
  final bool isAutoCompleted;
  final int consecutiveDays;
  final int? duration; // 分

  WorkoutLog({
    required this.id,
    required this.userId,
    required this.date,
    required this.gymId,
    this.gymName,
    required this.exercises,
    this.notes,
    this.isAutoCompleted = false,
    this.consecutiveDays = 1,
    this.duration,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'gymId': gymId,
      'gymName': gymName,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'notes': notes,
      'isAutoCompleted': isAutoCompleted,
      'consecutiveDays': consecutiveDays,
      'duration': duration,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory WorkoutLog.fromFirestore(Map<String, dynamic> data, String id) {
    // 🔧 v1.0.216: user_id (snake_case) と userId (camelCase) の両方に対応
    final userId = data['user_id'] as String? ?? data['userId'] as String? ?? '';
    
    // 🔧 v1.0.216: sets と exercises の両方に対応
    final rawSets = data['sets'] as List<dynamic>? ?? data['exercises'] as List<dynamic>? ?? [];
    
    return WorkoutLog(
      id: id,
      userId: userId,
      date: (data['date'] as Timestamp).toDate(),
      gymId: data['gymId'] ?? '',
      gymName: data['gymName'],
      exercises: rawSets
              .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
              .toList(),
      notes: data['notes'],
      isAutoCompleted: data['isAutoCompleted'] ?? false,
      consecutiveDays: data['consecutiveDays'] ?? 1,
      duration: data['duration'],
    );
  }
}

/// 種目のモデル
class Exercise {
  final String name;
  final String bodyPart; // 胸、背中、脚、肩、腕、腹筋
  final List<WorkoutSet> sets;

  Exercise({
    required this.name,
    required this.bodyPart,
    required this.sets,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'bodyPart': bodyPart,
      'sets': sets.map((s) => s.toMap()).toList(),
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    // 🔧 v1.0.216: exercise_name と name の両方に対応
    final exerciseName = map['exercise_name'] as String? ?? map['name'] as String? ?? '';
    
    // 🔧 v1.0.216: add_workout_screenのデータ形式に対応（setsがない場合は自分自身をセットとして扱う）
    List<WorkoutSet> workoutSets;
    if (map.containsKey('sets') && map['sets'] is List) {
      // 新しいフォーマット: exercises 配列に sets 配列
      workoutSets = (map['sets'] as List<dynamic>)
          .map((s) => WorkoutSet.fromMap(s as Map<String, dynamic>))
          .toList();
    } else if (map.containsKey('weight') && map.containsKey('reps')) {
      // add_workout_screenのフォーマット: 各セットが個別のオブジェクト
      workoutSets = [WorkoutSet.fromMap(map)];
    } else {
      workoutSets = [];
    }
    
    // 🔧 v1.0.245: bodyPartのランタイム補完強化 (Problem 1 fix)
    // 🔧 v1.0.317: AppLocalizations削除のため、'Other'文字列を直接使用
    String? bodyPart = map['bodyPart'] ?? map['muscle_group'];
    
    // bodyPartがnull、または'Other'の場合、ExerciseMasterDataで再評価
    if (bodyPart == null || bodyPart == 'Other') {
      bodyPart = ExerciseMasterData.getBodyPartByName(exerciseName);
    }
    
    // それでもnullなら'Other'（ExerciseMasterDataはデフォルトで'Other'を返すので通常不要）
    bodyPart ??= 'Other';
    
    return Exercise(
      name: exerciseName,
      bodyPart: bodyPart,
      sets: workoutSets,
    );
  }
}

/// セットタイプの列挙型
enum SetType {
  normal,     // 通常セット
  warmup,     // ウォームアップ
  superset,   // スーパーセット
  dropset,    // ドロップセット
  failure,    // フェイラーセット (限界まで)
}

/// セットのモデル
class WorkoutSet {
  final int targetReps;
  final int? actualReps;
  final double? weight;
  final DateTime? completedAt;
  final SetType setType;
  final String? supersetPairId; // スーパーセットのペア識別子
  final int? dropsetLevel;      // ドロップセットのレベル (1, 2, 3...)
  final int? rpe;               // RPE (Rate of Perceived Exertion) 1-10
  final bool? hasAssist;        // 補助有無
  final bool isCardio;          // 🔧 v1.0.243: 有酸素運動フラグ
  final bool isTimeMode;        // 🔧 v1.0.243: 時間モード（秒数 vs 回数）

  WorkoutSet({
    required this.targetReps,
    this.actualReps,
    this.weight,
    this.completedAt,
    this.setType = SetType.normal,
    this.supersetPairId,
    this.dropsetLevel,
    this.rpe,
    this.hasAssist,
    this.isCardio = false,    // デフォルトは筋トレ
    this.isTimeMode = false,  // デフォルトは回数モード
  });

  Map<String, dynamic> toMap() {
    return {
      'targetReps': targetReps,
      'actualReps': actualReps,
      'weight': weight,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'setType': setType.name,
      'supersetPairId': supersetPairId,
      'dropsetLevel': dropsetLevel,
      'rpe': rpe,
      'hasAssist': hasAssist,
      'isCardio': isCardio,      // 🔧 v1.0.243
      'isTimeMode': isTimeMode,  // 🔧 v1.0.243
    };
  }

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    // 🔧 v1.0.216: add_workout_screen.dartのデータ形式に対応
    // targetReps → reps, actualReps → reps, has_assist → hasAssist
    final reps = map['reps'] as int? ?? map['targetReps'] as int? ?? map['actualReps'] as int? ?? 0;
    final weight = (map['weight'] as num?)?.toDouble();
    
    return WorkoutSet(
      targetReps: reps,
      actualReps: map['is_completed'] == true ? reps : null,
      weight: weight,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      setType: SetType.values.firstWhere(
        (e) => e.name == (map['setType'] ?? map['set_type']),
        orElse: () => SetType.normal,
      ),
      supersetPairId: map['supersetPairId'],
      dropsetLevel: map['dropsetLevel'],
      rpe: map['rpe'],
      hasAssist: map['hasAssist'] ?? map['has_assist'],
      isCardio: map['isCardio'] ?? map['is_cardio'] ?? false,       // 🔧 v1.0.243: 両形式対応
      isTimeMode: map['isTimeMode'] ?? map['is_time_mode'] ?? false, // 🔧 v1.0.243: 両形式対応
    );
  }

  /// セットのボリューム (重量 × 回数) を計算
  double get volume {
    if (weight == null || actualReps == null) return 0;
    return weight! * actualReps!;
  }

  /// セットタイプの表示名を取得
  String get setTypeDisplayName {
    switch (setType) {
      case SetType.normal:
        return AppLocalizations.of(context)!.workout_9f784efd;
      case SetType.warmup:
        return 'W-UP';
      case SetType.superset:
        return 'SS';
      case SetType.dropset:
        return 'DS';
      case SetType.failure:
        return AppLocalizations.of(context)!.limit;
    }
  }
}
