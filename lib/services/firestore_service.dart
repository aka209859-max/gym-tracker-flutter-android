import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gym.dart';
import '../models/review.dart';
import '../models/crowd_report.dart';
import '../models/user_profile.dart';

/// Firestore操作を管理するサービスクラス
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ========== ジム関連 ==========

  /// 全ジム一覧を取得
  Stream<List<Gym>> getGyms() {
    return _db
        .collection('gyms')
        .orderBy('rating', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Gym.fromFirestore(doc)).toList());
  }

  /// 特定エリア内のジムを取得（緯度経度範囲）
  Stream<List<Gym>> getGymsInArea({
    required double centerLat,
    required double centerLng,
    double radiusKm = 5.0,
  }) {
    // 簡易的な範囲検索（実運用では GeoFlutterFire 等を推奨）
    final latDelta = radiusKm / 111.0; // 約1度 = 111km
    final lngDelta = radiusKm / (111.0 * 0.9); // 緯度による補正（簡易）

    return _db
        .collection('gyms')
        .where('latitude', isGreaterThan: centerLat - latDelta)
        .where('latitude', isLessThan: centerLat + latDelta)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Gym.fromFirestore(doc))
          .where((gym) {
            // 経度の範囲もチェック
            return gym.longitude >= (centerLng - lngDelta) &&
                gym.longitude <= (centerLng + lngDelta);
          })
          .toList();
    });
  }

  /// 特定ジムの詳細を取得
  Stream<Gym?> getGym(String gymId) {
    return _db
        .collection('gyms')
        .doc(gymId)
        .snapshots()
        .map((doc) => doc.exists ? Gym.fromFirestore(doc) : null);
  }

  /// ジムの混雑度を更新
  Future<void> updateGymCrowdLevel(String gymId, int crowdLevel) async {
    await _db.collection('gyms').doc(gymId).update({
      'currentCrowdLevel': crowdLevel,
      'lastCrowdUpdate': FieldValue.serverTimestamp(),
    });
  }

  // ========== 混雑度レポート関連 ==========

  /// 混雑度レポートを投稿
  Future<void> submitCrowdReport(CrowdReport report) async {
    await _db.collection('crowd_reports').add(report.toMap());
    // ジムの混雑度も更新
    await updateGymCrowdLevel(report.gymId, report.crowdLevel);
  }

  /// 特定ジムの最近の混雑度レポートを取得
  Stream<List<CrowdReport>> getRecentCrowdReports(String gymId, {int limit = 10}) {
    return _db
        .collection('crowd_reports')
        .where('gymId', isEqualTo: gymId)
        .orderBy('reportedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => CrowdReport.fromFirestore(doc)).toList());
  }

  // ========== レビュー関連 ==========

  /// レビューを投稿
  Future<void> submitReview(Review review) async {
    await _db.collection('reviews').add(review.toMap());
    // ジムの評価を再計算（簡易版）
    await _updateGymRating(review.gymId);
  }

  /// ジムの評価を再計算
  Future<void> _updateGymRating(String gymId) async {
    final reviewsSnapshot = await _db
        .collection('reviews')
        .where('gymId', isEqualTo: gymId)
        .get();

    if (reviewsSnapshot.docs.isEmpty) return;

    double totalRating = 0;
    for (var doc in reviewsSnapshot.docs) {
      final review = Review.fromFirestore(doc);
      totalRating += review.overallRating;
    }

    final avgRating = totalRating / reviewsSnapshot.docs.length;
    await _db.collection('gyms').doc(gymId).update({
      'rating': avgRating,
      'reviewCount': reviewsSnapshot.docs.length,
    });
  }

  /// 特定ジムのレビューを取得
  Stream<List<Review>> getGymReviews(String gymId) {
    return _db
        .collection('reviews')
        .where('gymId', isEqualTo: gymId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList());
  }

  // ========== ユーザープロフィール関連 ==========

  /// ユーザープロフィールを作成
  Future<void> createUserProfile(UserProfile profile) async {
    await _db.collection('users').doc(profile.id).set(profile.toMap());
  }

  /// ユーザープロフィールを取得
  Stream<UserProfile?> getUserProfile(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);
  }

  /// ユーザープロフィールを更新
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    await _db.collection('users').doc(userId).update(updates);
  }

  /// お気に入りジムを追加
  Future<void> addFavoriteGym(String userId, String gymId) async {
    await _db.collection('users').doc(userId).update({
      'favoriteGymIds': FieldValue.arrayUnion([gymId]),
    });
  }

  /// お気に入りジムを削除
  Future<void> removeFavoriteGym(String userId, String gymId) async {
    await _db.collection('users').doc(userId).update({
      'favoriteGymIds': FieldValue.arrayRemove([gymId]),
    });
  }
}
