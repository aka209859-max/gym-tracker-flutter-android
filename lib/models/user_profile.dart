import 'package:cloud_firestore/cloud_firestore.dart';

/// ユーザープロフィールのデータモデル
class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String photoUrl;
  final String bio;
  final String experienceLevel; // 'beginner', 'intermediate', 'advanced'
  final List<String> favoriteGymIds;
  final List<String> interests; // 'cardio', 'weight_training', 'yoga', etc.
  final bool isWomenOnly; // 女性専用マッチング希望
  final DateTime createdAt;
  final DateTime lastActiveAt;

  UserProfile({
    required this.id,
    required this.email,
    this.displayName = '',
    this.photoUrl = '',
    this.bio = '',
    this.experienceLevel = 'beginner',
    this.favoriteGymIds = const [],
    this.interests = const [],
    this.isWomenOnly = false,
    required this.createdAt,
    required this.lastActiveAt,
  });

  /// Firestoreからユーザープロフィールを生成
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      bio: data['bio'] ?? '',
      experienceLevel: data['experienceLevel'] ?? 'beginner',
      favoriteGymIds: List<String>.from(data['favoriteGymIds'] ?? []),
      interests: List<String>.from(data['interests'] ?? []),
      isWomenOnly: data['isWomenOnly'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Firestore用にマップ形式に変換
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'experienceLevel': experienceLevel,
      'favoriteGymIds': favoriteGymIds,
      'interests': interests,
      'isWomenOnly': isWomenOnly,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
    };
  }

  /// 経験レベルの日本語表示
  String get experienceLevelText {
    switch (experienceLevel) {
      case 'beginner':
        return '初心者';
      case 'intermediate':
        return '中級者';
      case 'advanced':
        return '上級者';
      default:
        return '未設定';
    }
  }

  /// コピーメソッド（更新用）
  UserProfile copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    String? bio,
    String? experienceLevel,
    List<String>? favoriteGymIds,
    List<String>? interests,
    bool? isWomenOnly,
    DateTime? lastActiveAt,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      favoriteGymIds: favoriteGymIds ?? this.favoriteGymIds,
      interests: interests ?? this.interests,
      isWomenOnly: isWomenOnly ?? this.isWomenOnly,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}
