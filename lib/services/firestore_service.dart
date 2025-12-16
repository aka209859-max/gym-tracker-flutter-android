import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gym.dart';
import '../models/review.dart';
import '../models/crowd_report.dart';
import '../models/user_profile.dart';
import '../models/workout_log.dart';

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

  // ========== ワークアウトログ関連 ==========

  /// 前回の同種目ワークアウトを取得 (リアルタイム前回比較用)
  Future<Exercise?> getPreviousExercise(String userId, String exerciseName) async {
    try {
      // 過去30日以内の同種目ワークアウトを検索
      final querySnapshot = await _db
          .collection('workout_logs')
          .where('user_id', isEqualTo: userId)
          .where('date', isLessThan: Timestamp.now())
          .orderBy('date', descending: true)
          .limit(20) // 最近20件を取得
          .get();

      // 同じ種目を含むワークアウトを検索
      for (var doc in querySnapshot.docs) {
        final workoutLog = WorkoutLog.fromFirestore(doc.data(), doc.id);
        for (var exercise in workoutLog.exercises) {
          if (exercise.name == exerciseName) {
            return exercise;
          }
        }
      }

      return null;
    } catch (e) {
      print('前回ワークアウト取得エラー: $e');
      return null;
    }
  }

  /// ワークアウトログを保存
  Future<void> saveWorkoutLog(WorkoutLog log) async {
    await _db.collection('workout_logs').add(log.toFirestore());
  }

  /// ユーザーのワークアウトログ一覧を取得
  Stream<List<WorkoutLog>> getUserWorkoutLogs(String userId, {int limit = 30}) {
    return _db
        .collection('workout_logs')
        .where('user_id', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => WorkoutLog.fromFirestore(doc.data(), doc.id)).toList());
  }

  // ========== 🆕 v1.0.229: 集計データ自動更新（PR/週次レポート/メモ） ==========

  /// 🆕 PR（自己ベスト）を自動更新
  Future<void> _updatePersonalRecords(String userId, WorkoutLog log) async {
    try {
      for (var exercise in log.exercises) {
        if (exercise.sets.isEmpty) continue;

        // 最大重量を計算（1RM換算: weight * (1 + reps / 30)）
        double maxEstimated1RM = 0;
        for (var set in exercise.sets) {
          if (!set.isCompleted) continue;
          final estimated1RM = set.weight * (1 + set.reps / 30);
          if (estimated1RM > maxEstimated1RM) {
            maxEstimated1RM = estimated1RM;
          }
        }

        if (maxEstimated1RM == 0) continue;

        // 既存のPRを確認
        final prDocId = '${userId}_${exercise.name}';
        final prDoc = await _db.collection('personalRecords').doc(prDocId).get();

        if (!prDoc.exists || (prDoc.data()?['estimated1RM'] ?? 0) < maxEstimated1RM) {
          // PR更新
          await _db.collection('personalRecords').doc(prDocId).set({
            'user_id': userId,
            'exercise_name': exercise.name,
            'estimated1RM': maxEstimated1RM,
            'date': log.date,
            'updated_at': FieldValue.serverTimestamp(),
          });
          print('✅ PR更新: ${exercise.name} → ${maxEstimated1RM.toStringAsFixed(1)}kg');
        }
      }
    } catch (e) {
      print('❌ PR更新エラー: $e');
    }
  }

  /// 🆕 週次レポートを自動更新
  Future<void> _updateWeeklyReport(String userId, WorkoutLog log) async {
    try {
      // 該当週のドキュメントIDを生成（例: 2025-W50）
      final logDate = log.date.toDate();
      final weekNumber = _getWeekNumber(logDate);
      final year = logDate.year;
      final weekId = '$year-W$weekNumber';
      final docId = '${userId}_$weekId';

      // 総負荷量を計算
      double totalVolume = 0;
      Map<String, int> bodyPartCount = {};

      for (var exercise in log.exercises) {
        for (var set in exercise.sets) {
          if (set.isCompleted) {
            totalVolume += set.weight * set.reps;
          }
        }
        // 部位カウント（簡易版：種目名から推定）
        final bodyPart = _inferBodyPart(exercise.name);
        bodyPartCount[bodyPart] = (bodyPartCount[bodyPart] ?? 0) + 1;
      }

      // 既存の週次レポートを取得または作成
      final weekDoc = await _db.collection('weeklyReports').doc(docId).get();

      if (weekDoc.exists) {
        // 既存レポートに加算
        await _db.collection('weeklyReports').doc(docId).update({
          'workout_count': FieldValue.increment(1),
          'total_volume': FieldValue.increment(totalVolume),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        // 新規作成
        await _db.collection('weeklyReports').doc(docId).set({
          'user_id': userId,
          'week_id': weekId,
          'year': year,
          'week_number': weekNumber,
          'workout_count': 1,
          'total_volume': totalVolume,
          'body_part_count': bodyPartCount,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      print('✅ 週次レポート更新: $weekId (回数: +1, 負荷: +${totalVolume.toStringAsFixed(0)}kg)');
    } catch (e) {
      print('❌ 週次レポート更新エラー: $e');
    }
  }

  /// 🆕 メモを自動保存
  Future<void> _saveWorkoutNotes(String userId, WorkoutLog log) async {
    try {
      if (log.notes == null || log.notes!.isEmpty) return;

      await _db.collection('workout_notes').add({
        'user_id': userId,
        'workout_log_id': log.id,
        'notes': log.notes,
        'date': log.date,
        'created_at': FieldValue.serverTimestamp(),
      });
      print('✅ メモ保存: ${log.notes}');
    } catch (e) {
      print('❌ メモ保存エラー: $e');
    }
  }

  /// 週番号を取得（ISO 8601形式）
  int _getWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final daysSinceStart = date.difference(startOfYear).inDays;
    return (daysSinceStart / 7).ceil() + 1;
  }

  /// 種目名から部位を推定（簡易版）
  String _inferBodyPart(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('胸') || name.contains('ベンチ') || name.contains('chest')) return '胸';
    if (name.contains('背') || name.contains('ラット') || name.contains('デッド') || name.contains('back')) return '背中';
    if (name.contains('脚') || name.contains('スクワット') || name.contains('leg')) return '脚';
    if (name.contains('肩') || name.contains('ショルダー') || name.contains('shoulder')) return '肩';
    if (name.contains('腕') || name.contains('カール') || name.contains('arm')) return '腕';
    return 'その他';
  }

  /// 🆕 v1.0.229: ワークアウトログを保存 + 集計データ自動更新
  Future<void> saveWorkoutLogWithAggregation(String userId, WorkoutLog log) async {
    try {
      // 1. ワークアウトログを保存
      await saveWorkoutLog(log);

      // 2. PR自動更新
      await _updatePersonalRecords(userId, log);

      // 3. 週次レポート自動更新
      await _updateWeeklyReport(userId, log);

      // 4. メモ自動保存
      await _saveWorkoutNotes(userId, log);

      print('✅ ワークアウトログ保存 + 集計完了');
    } catch (e) {
      print('❌ ワークアウトログ保存エラー: $e');
      rethrow;
    }
  }
}
