import 'package:cloud_firestore/cloud_firestore.dart';

/// パーソナルレコード（自己ベスト）のモデル
class PersonalRecord {
  final String id;
  final String userId;
  final String exerciseName;
  final String bodyPart;
  final double weight;  // 筋トレ: 重量(kg), 有酸素: 時間(分)
  final int reps;       // 筋トレ: 回数, 有酸素: 距離(km)の整数部分
  final double calculated1RM; // Brzycki式による推定1RM (有酸素は時間をそのまま使用)
  final DateTime achievedAt;
  final String gymId;
  final bool isCardio;  // 🔧 v1.0.246: 有酸素運動フラグ

  PersonalRecord({
    required this.id,
    required this.userId,
    required this.exerciseName,
    this.bodyPart = '',
    required this.weight,
    required this.reps,
    required this.calculated1RM,
    required this.achievedAt,
    this.gymId = '',
    this.isCardio = false,  // 🔧 v1.0.246: デフォルトは筋トレ
  });

  /// Brzycki式で1RMを計算
  static double calculate1RM(double weight, int reps) {
    if (reps == 1) return weight;
    return weight * (36 / (37 - reps));
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'exerciseName': exerciseName,
      'bodyPart': bodyPart,
      'weight': weight,
      'reps': reps,
      'calculated1RM': calculated1RM,
      'achievedAt': Timestamp.fromDate(achievedAt),
      'gymId': gymId,
      'isCardio': isCardio,  // 🔧 v1.0.246
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory PersonalRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return PersonalRecord(
      id: id,
      userId: data['userId'] ?? '',
      exerciseName: data['exerciseName'] ?? '',
      bodyPart: data['bodyPart'] ?? '',
      weight: (data['weight'] ?? 0).toDouble(),
      reps: data['reps'] ?? 0,
      calculated1RM: (data['calculated1RM'] ?? 0).toDouble(),
      achievedAt: (data['achievedAt'] as Timestamp).toDate(),
      gymId: data['gymId'] ?? '',
      isCardio: data['isCardio'] as bool? ?? false,  // 🔧 v1.0.246
    );
  }
}
