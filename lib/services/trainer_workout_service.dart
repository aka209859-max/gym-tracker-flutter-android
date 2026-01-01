import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // debugPrint用

/// トレーナー共有トレーニング記録サービス
class TrainerWorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// トレーナーが共有したトレーニング記録を取得（メールアドレスで検索）
  /// 
  /// [memberEmail] 会員メールアドレス
  Future<List<TrainerWorkoutRecord>> getSharedWorkoutRecordsByEmail({
    required String memberEmail,
  }) async {
    try {
      // メールアドレスが空の場合は空リストを返す
      if (memberEmail.isEmpty) {
        debugPrint(AppLocalizations.of(context)!.workout_8982c109);
        return [];
      }

      // GYM MATCH Managerの sessions コレクションからメールアドレスで取得
      final querySnapshot = await _firestore
          .collection('sessions')
          .where('memberEmail', isEqualTo: memberEmail)
          .where('sharedWithMember', isEqualTo: true)
          .orderBy('date', descending: true)
          .get();

      debugPrint('トレーナー記録取得: ${querySnapshot.docs.length}件 (email: $memberEmail)');

      return querySnapshot.docs
          .map((doc) => TrainerWorkoutRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('トレーナー記録取得エラー: $e');
      return []; // エラー時は空リスト返却（自己記録は表示継続）
    }
  }

  /// 【旧バージョン】トレーナーが共有したトレーニング記録を取得
  /// 
  /// [memberId] 会員ID
  /// [gymId] ジムID
  @Deprecated('Use getSharedWorkoutRecordsByEmail instead')
  Future<List<TrainerWorkoutRecord>> getSharedWorkoutRecords({
    required String memberId,
    required String gymId,
  }) async {
    try {
      // GYM MATCH Managerの sessions コレクションから取得
      final querySnapshot = await _firestore
          .collection('sessions')
          .where('memberId', isEqualTo: memberId)
          .where('gymId', isEqualTo: gymId)
          .where('sharedWithMember', isEqualTo: true)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => TrainerWorkoutRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('トレーナー記録取得エラー: $e');
      rethrow;
    }
  }

  /// 単一のトレーナー記録を取得
  Future<TrainerWorkoutRecord?> getWorkoutRecord(String sessionId) async {
    try {
      final doc = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .get();

      if (!doc.exists) return null;

      return TrainerWorkoutRecord.fromFirestore(doc);
    } catch (e) {
      debugPrint('トレーナー記録取得エラー: $e');
      return null;
    }
  }
}

/// トレーナー共有トレーニング記録モデル
class TrainerWorkoutRecord {
  final String id;
  final String memberId;
  final String memberName;
  final String trainerId;
  final String trainerName;
  final String gymId;
  final DateTime date;
  final int duration;
  final String sessionType;
  final String status;
  final List<TrainerExercise> exercises;
  final TrainerBodyMetrics? bodyMetrics;
  final String trainerNotes;
  final String intensity;
  final DateTime? sharedAt;

  TrainerWorkoutRecord({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.trainerId,
    required this.trainerName,
    required this.gymId,
    required this.date,
    required this.duration,
    required this.sessionType,
    required this.status,
    required this.exercises,
    this.bodyMetrics,
    required this.trainerNotes,
    required this.intensity,
    this.sharedAt,
  });

  /// 日付フォーマット（例: 2025年11月14日）
  String get formattedDate {
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// セッションID（recordをsessionとして使用する場合）
  String get sessionId => id;

  factory TrainerWorkoutRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final workoutLog = data['workoutLog'] as Map<String, dynamic>?;

    return TrainerWorkoutRecord(
      id: doc.id,
      memberId: data['memberId'] ?? '',
      memberName: data['memberName'] ?? '',
      trainerId: data['trainerId'] ?? '',
      trainerName: data['trainerName'] ?? '',
      gymId: data['gymId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      duration: data['duration'] ?? 60,
      sessionType: data['sessionType'] ?? AppLocalizations.of(context)!.personalTraining,
      status: data['status'] ?? 'completed',
      exercises: workoutLog != null && workoutLog['exercises'] != null
          ? (workoutLog['exercises'] as List)
              .map((e) => TrainerExercise.fromMap(e as Map<String, dynamic>))
              .toList()
          : [],
      bodyMetrics: workoutLog != null && workoutLog['bodyMetrics'] != null
          ? TrainerBodyMetrics.fromMap(workoutLog['bodyMetrics'] as Map<String, dynamic>)
          : null,
      trainerNotes: workoutLog?['trainerNotes'] ?? '',
      intensity: workoutLog?['intensity'] ?? 'medium',
      sharedAt: data['sharedAt'] != null
          ? (data['sharedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

/// トレーナー記録の種目モデル
class TrainerExercise {
  final String name;
  final double? weight;
  final int? reps;
  final int? sets;

  TrainerExercise({
    required this.name,
    this.weight,
    this.reps,
    this.sets,
  });

  factory TrainerExercise.fromMap(Map<String, dynamic> map) {
    return TrainerExercise(
      name: map['name'] ?? '',
      weight: map['weight']?.toDouble(),
      reps: map['reps'],
      sets: map['sets'],
    );
  }

  String get formattedDetails {
    final parts = <String>[];
    if (weight != null) parts.add('${weight!}kg');
    if (reps != null) parts.add('${reps}回');
    if (sets != null) parts.add('${sets}セット');
    return parts.join(' × ');
  }
}

/// トレーナー記録の体組成モデル
class TrainerBodyMetrics {
  final double? weight;
  final double? bodyFat;
  final double? muscleMass;

  TrainerBodyMetrics({
    this.weight,
    this.bodyFat,
    this.muscleMass,
  });

  factory TrainerBodyMetrics.fromMap(Map<String, dynamic> map) {
    return TrainerBodyMetrics(
      weight: map['weight']?.toDouble(),
      bodyFat: map['bodyFat']?.toDouble(),
      muscleMass: map['muscleMass']?.toDouble(),
    );
  }
}
