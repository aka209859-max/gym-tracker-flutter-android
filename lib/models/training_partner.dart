import 'package:cloud_firestore/cloud_firestore.dart';

/// トレーニングパートナーモデル
class TrainingPartner {
  final String id; // ユーザーUID
  final String name; // 名前
  final String photoUrl; // プロフィール画像URL
  final String bio; // 自己紹介
  final String experienceLevel; // 経験レベル ('beginner', 'intermediate', 'advanced')
  final List<String> preferredExercises; // 好きな種目
  final List<String> goals; // 目標
  final String? gymId; // 所属ジムID
  final String? gymName; // 所属ジム名
  final double? latitude; // 位置情報（緯度）
  final double? longitude; // 位置情報（経度）
  final bool isAvailable; // マッチング可能かどうか
  final DateTime lastActive; // 最終アクティブ日時

  TrainingPartner({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.bio,
    required this.experienceLevel,
    required this.preferredExercises,
    required this.goals,
    this.gymId,
    this.gymName,
    this.latitude,
    this.longitude,
    this.isAvailable = true,
    required this.lastActive,
  });

  /// Firestoreから変換
  factory TrainingPartner.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrainingPartner(
      id: doc.id,
      name: data['name'] ?? 'Unknown',
      photoUrl: data['photoUrl'] ?? '',
      bio: data['bio'] ?? '',
      experienceLevel: data['experienceLevel'] ?? 'beginner',
      preferredExercises: List<String>.from(data['preferredExercises'] ?? []),
      goals: List<String>.from(data['goals'] ?? []),
      gymId: data['gymId'],
      gymName: data['gymName'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      isAvailable: data['isAvailable'] ?? true,
      lastActive: (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Firestoreへ変換
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'bio': bio,
      'experienceLevel': experienceLevel,
      'preferredExercises': preferredExercises,
      'goals': goals,
      'gymId': gymId,
      'gymName': gymName,
      'latitude': latitude,
      'longitude': longitude,
      'isAvailable': isAvailable,
      'lastActive': Timestamp.fromDate(lastActive),
    };
  }

  /// 経験レベルを日本語で取得
  String get experienceLevelText {
    switch (experienceLevel) {
      case 'beginner':
        return '初心者';
      case 'intermediate':
        return '中級者';
      case 'advanced':
        return '上級者';
      default:
        return '初心者';
    }
  }

  /// 距離を計算（km）
  double? distanceFrom(double? userLat, double? userLon) {
    if (latitude == null || longitude == null || userLat == null || userLon == null) {
      return null;
    }

    // 簡易距離計算（緯度経度の差分ベース）
    const double kmPerDegree = 111.0; // 約111km/度
    final double latDiff = (latitude! - userLat).abs();
    final double lonDiff = (longitude! - userLon).abs();
    
    // ピタゴラスの定理による近似距離
    final double distance = (latDiff * latDiff + lonDiff * lonDiff).abs() * kmPerDegree;
    return distance;
  }
}

/// パートナーマッチングリクエスト
class PartnerRequest {
  final String id;
  final String requesterId; // リクエスト送信者UID
  final String requesterName; // リクエスト送信者名
  final String requesterPhotoUrl; // リクエスト送信者写真
  final String targetId; // リクエスト対象者UID
  final String targetName; // リクエスト対象者名
  final String targetPhotoUrl; // リクエスト対象者写真
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt; // 作成日時
  final DateTime? respondedAt; // 応答日時

  PartnerRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterPhotoUrl,
    required this.targetId,
    required this.targetName,
    required this.targetPhotoUrl,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  /// Firestoreから変換
  factory PartnerRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PartnerRequest(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? 'Unknown',
      requesterPhotoUrl: data['requesterPhotoUrl'] ?? '',
      targetId: data['targetId'] ?? '',
      targetName: data['targetName'] ?? 'Unknown',
      targetPhotoUrl: data['targetPhotoUrl'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Firestoreへ変換
  Map<String, dynamic> toMap() {
    return {
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterPhotoUrl': requesterPhotoUrl,
      'targetId': targetId,
      'targetName': targetName,
      'targetPhotoUrl': targetPhotoUrl,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }
}
