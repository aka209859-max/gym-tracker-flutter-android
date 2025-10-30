import 'package:cloud_firestore/cloud_firestore.dart';

/// レビュー・評価のデータモデル
class Review {
  final String id;
  final String gymId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final double overallRating;
  final double crowdAccuracy;
  final double cleanliness;
  final double staffFriendliness;
  final double beginnerFriendly;
  final String comment;
  final List<String> imageUrls;
  final DateTime createdAt;
  final int likeCount;

  Review({
    required this.id,
    required this.gymId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl = '',
    required this.overallRating,
    this.crowdAccuracy = 3.0,
    this.cleanliness = 3.0,
    this.staffFriendliness = 3.0,
    this.beginnerFriendly = 3.0,
    this.comment = '',
    this.imageUrls = const [],
    required this.createdAt,
    this.likeCount = 0,
  });

  /// Firestoreからレビューデータを生成
  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      gymId: data['gymId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '匿名ユーザー',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      overallRating: (data['overallRating'] ?? 3.0).toDouble(),
      crowdAccuracy: (data['crowdAccuracy'] ?? 3.0).toDouble(),
      cleanliness: (data['cleanliness'] ?? 3.0).toDouble(),
      staffFriendliness: (data['staffFriendliness'] ?? 3.0).toDouble(),
      beginnerFriendly: (data['beginnerFriendly'] ?? 3.0).toDouble(),
      comment: data['comment'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: data['likeCount'] ?? 0,
    );
  }

  /// Firestore用にマップ形式に変換
  Map<String, dynamic> toMap() {
    return {
      'gymId': gymId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'overallRating': overallRating,
      'crowdAccuracy': crowdAccuracy,
      'cleanliness': cleanliness,
      'staffFriendliness': staffFriendliness,
      'beginnerFriendly': beginnerFriendly,
      'comment': comment,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
    };
  }

  /// 平均評価の計算
  double get averageDetailRating {
    return (crowdAccuracy + cleanliness + staffFriendliness + beginnerFriendly) / 4;
  }
}
