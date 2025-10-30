import 'package:cloud_firestore/cloud_firestore.dart';

/// 混雑度レポートのデータモデル
class CrowdReport {
  final String id;
  final String gymId;
  final String userId;
  final int crowdLevel; // 1-5
  final String? comment;
  final DateTime reportedAt;
  final int helpfulCount; // 「役に立った」カウント

  CrowdReport({
    required this.id,
    required this.gymId,
    required this.userId,
    required this.crowdLevel,
    this.comment,
    required this.reportedAt,
    this.helpfulCount = 0,
  });

  /// Firestoreから混雑度レポートを生成
  factory CrowdReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CrowdReport(
      id: doc.id,
      gymId: data['gymId'] ?? '',
      userId: data['userId'] ?? '',
      crowdLevel: data['crowdLevel'] ?? 3,
      comment: data['comment'],
      reportedAt: (data['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      helpfulCount: data['helpfulCount'] ?? 0,
    );
  }

  /// Firestore用にマップ形式に変換
  Map<String, dynamic> toMap() {
    return {
      'gymId': gymId,
      'userId': userId,
      'crowdLevel': crowdLevel,
      'comment': comment,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'helpfulCount': helpfulCount,
    };
  }

  /// 混雑度の日本語表示
  String get crowdLevelText {
    switch (crowdLevel) {
      case 1:
        return '空いています';
      case 2:
        return 'やや空き';
      case 3:
        return '普通';
      case 4:
        return 'やや混雑';
      case 5:
        return '超混雑';
      default:
        return '不明';
    }
  }

  /// レポートが最新かどうか (30分以内)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(reportedAt);
    return difference.inMinutes <= 30;
  }
}
