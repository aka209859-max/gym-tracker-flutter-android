import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gym.dart';
import '../models/workout_log.dart';

/// オフライン対応サービス
/// Hiveを使用してローカルにデータをキャッシュし、オフライン環境でもアプリを使用可能にする
class OfflineService {
  static const String _gymsCacheBox = 'gyms_cache';
  static const String _workoutsCacheBox = 'workouts_cache';
  static const String _pendingSyncBox = 'pending_sync';

  /// Hive初期化
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // キャッシュ用ボックスを開く
    await Hive.openBox(_gymsCacheBox);
    await Hive.openBox(_workoutsCacheBox);
    await Hive.openBox(_pendingSyncBox);
  }

  // ============================================
  // ジム情報のキャッシュ管理
  // ============================================

  /// ジム情報をキャッシュに保存
  static Future<void> cacheGym(Gym gym) async {
    final box = Hive.box(_gymsCacheBox);
    await box.put(gym.id, {
      'id': gym.id,
      'name': gym.name,
      'address': gym.address,
      'latitude': gym.latitude,
      'longitude': gym.longitude,
      'description': gym.description,
      'facilities': gym.facilities,
      'isPartner': gym.isPartner,
      'partnerBenefit': gym.partnerBenefit,
      'campaignTitle': gym.campaignTitle,
      'campaignDescription': gym.campaignDescription,
      'photos': gym.photos,
      'equipment': gym.equipment,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  /// キャッシュからジム情報を取得
  static Future<Gym?> getCachedGym(String gymId) async {
    final box = Hive.box(_gymsCacheBox);
    final data = box.get(gymId);
    
    if (data == null) return null;

    return Gym(
      id: data['id'],
      name: data['name'],
      address: data['address'],
      latitude: data['latitude'],
      longitude: data['longitude'],
      description: data['description'] ?? '',
      facilities: List<String>.from(data['facilities'] ?? []),
      isPartner: data['isPartner'] ?? false,
      partnerBenefit: data['partnerBenefit'],
      campaignTitle: data['campaignTitle'],
      campaignDescription: data['campaignDescription'],
      photos: data['photos'] != null ? List<String>.from(data['photos']) : null,
      equipment: data['equipment'] != null ? Map<String, int>.from(data['equipment']) : null,
    );
  }

  /// 全てのキャッシュされたジムを取得
  static Future<List<Gym>> getAllCachedGyms() async {
    final box = Hive.box(_gymsCacheBox);
    final List<Gym> gyms = [];

    for (var key in box.keys) {
      final gym = await getCachedGym(key);
      if (gym != null) {
        gyms.add(gym);
      }
    }

    return gyms;
  }

  // ============================================
  // トレーニング記録のオフライン保存
  // ============================================

  /// トレーニング記録をローカルに保存（オフライン時）
  static Future<String> saveWorkoutOffline(WorkoutLog workout) async {
    final box = Hive.box(_workoutsCacheBox);
    final localId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    
    await box.put(localId, {
      'localId': localId,
      'userId': workout.userId,
      'date': workout.date.toIso8601String(),
      'exercises': workout.exercises.map((e) => {
        'name': e.name,
        'sets': e.sets.map((s) => {
          'weight': s.weight,
          'reps': s.reps,
          'hasAssist': s.hasAssist,
        }).toList(),
        'bodyPart': e.bodyPart,
        'note': e.note,
      }).toList(),
      'totalDuration': workout.totalDuration,
      'needsSync': true,
    });

    // 同期待ちリストに追加
    await _addToPendingSync(localId, 'workout');

    return localId;
  }

  /// キャッシュからトレーニング記録を取得
  static Future<List<Map<String, dynamic>>> getCachedWorkouts() async {
    final box = Hive.box(_workoutsCacheBox);
    final List<Map<String, dynamic>> workouts = [];

    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        workouts.add(Map<String, dynamic>.from(data));
      }
    }

    // 日付順にソート
    workouts.sort((a, b) {
      final dateA = DateTime.parse(a['date']);
      final dateB = DateTime.parse(b['date']);
      return dateB.compareTo(dateA);
    });

    return workouts;
  }

  // ============================================
  // オンライン復帰時の同期処理
  // ============================================

  /// 同期待ちのデータをFirestoreにアップロード
  static Future<void> syncPendingData() async {
    final pendingBox = Hive.box(_pendingSyncBox);
    final workoutsBox = Hive.box(_workoutsCacheBox);

    for (var key in pendingBox.keys.toList()) {
      final syncData = pendingBox.get(key);
      if (syncData == null) continue;

      final type = syncData['type'];
      final localId = syncData['localId'];

      try {
        if (type == 'workout') {
          // トレーニング記録を同期
          final workoutData = workoutsBox.get(localId);
          if (workoutData != null) {
            // Firestoreに保存
            final docRef = await FirebaseFirestore.instance
                .collection('workout_logs')
                .add({
              'userId': workoutData['userId'],
              'date': Timestamp.fromDate(DateTime.parse(workoutData['date'])),
              'exercises': workoutData['exercises'],
              'totalDuration': workoutData['totalDuration'],
              'createdAt': FieldValue.serverTimestamp(),
            });

            // 同期成功したらローカルデータを削除
            await workoutsBox.delete(localId);
            await pendingBox.delete(key);

            print('✅ Synced workout: $localId → ${docRef.id}');
          }
        }
      } catch (e) {
        print('❌ Sync failed for $localId: $e');
        // エラー時は次回リトライのため残しておく
      }
    }
  }

  /// 同期待ちリストに追加
  static Future<void> _addToPendingSync(String localId, String type) async {
    final box = Hive.box(_pendingSyncBox);
    await box.put('${type}_$localId', {
      'localId': localId,
      'type': type,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// 同期待ちのデータ数を取得
  static Future<int> getPendingSyncCount() async {
    final box = Hive.box(_pendingSyncBox);
    return box.keys.length;
  }

  // ============================================
  // ネットワーク状態の確認
  // ============================================

  /// オンライン状態かチェック
  static Future<bool> isOnline() async {
    try {
      // Firestoreへの軽量なクエリでネットワーク確認
      await FirebaseFirestore.instance
          .collection('_health_check')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // キャッシュクリア
  // ============================================

  /// 全てのキャッシュをクリア（デバッグ用）
  static Future<void> clearAllCache() async {
    await Hive.box(_gymsCacheBox).clear();
    await Hive.box(_workoutsCacheBox).clear();
    await Hive.box(_pendingSyncBox).clear();
  }

  /// キャッシュ情報を取得（デバッグ用）
  static Future<Map<String, int>> getCacheInfo() async {
    return {
      'gyms': Hive.box(_gymsCacheBox).length,
      'workouts': Hive.box(_workoutsCacheBox).length,
      'pending': Hive.box(_pendingSyncBox).length,
    };
  }
}
