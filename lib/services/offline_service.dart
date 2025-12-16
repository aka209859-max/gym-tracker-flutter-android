import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';  // ✅ v1.0.177: Network detection
import '../models/gym.dart';
import '../models/workout_log.dart';

/// オフライン対応サービス
/// Hiveを使用してローカルにデータをキャッシュし、オフライン環境でもアプリを使用可能にする
class OfflineService {
  static const String _gymsCacheBox = 'gyms_cache';
  static const String _workoutsCacheBox = 'workouts_cache';
  static const String _bodyMeasurementsBox = 'body_measurements_cache'; // ✅ v1.0.161
  static const String _pendingSyncBox = 'pending_sync';

  /// Hive初期化
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // キャッシュ用ボックスを開く
    await Hive.openBox(_gymsCacheBox);
    await Hive.openBox(_workoutsCacheBox);
    await Hive.openBox(_bodyMeasurementsBox); // ✅ v1.0.161
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
      createdAt: DateTime.parse(data['cachedAt']),
      updatedAt: DateTime.parse(data['cachedAt']),
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
  static Future<String> saveWorkoutOffline(Map<String, dynamic> workoutData) async {
    final box = Hive.box(_workoutsCacheBox);
    final localId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    
    // DateTime を ISO8601 文字列に変換
    final data = Map<String, dynamic>.from(workoutData);
    if (data['date'] is DateTime) {
      data['date'] = (data['date'] as DateTime).toIso8601String();
    }
    if (data['start_time'] is DateTime) {
      data['start_time'] = (data['start_time'] as DateTime).toIso8601String();
    }
    if (data['end_time'] is DateTime) {
      data['end_time'] = (data['end_time'] as DateTime).toIso8601String();
    }
    if (data['created_at'] is DateTime) {
      data['created_at'] = (data['created_at'] as DateTime).toIso8601String();
    }
    
    await box.put(localId, {
      ...data,
      'localId': localId,
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
  // ✅ v1.0.161: 体重記録のオフライン保存
  // ============================================

  /// 体重記録をローカルに保存（オフライン時）
  static Future<String> saveBodyMeasurementOffline(Map<String, dynamic> measurementData) async {
    final box = Hive.box(_bodyMeasurementsBox);
    final localId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    
    // DateTime を ISO8601 文字列に変換
    final data = Map<String, dynamic>.from(measurementData);
    if (data['date'] is DateTime) {
      data['date'] = (data['date'] as DateTime).toIso8601String();
    }
    if (data['created_at'] is DateTime) {
      data['created_at'] = (data['created_at'] as DateTime).toIso8601String();
    }
    
    await box.put(localId, {
      ...data,
      'localId': localId,
      'needsSync': true,
    });

    // 同期待ちリストに追加
    await _addToPendingSync(localId, 'body_measurement');

    return localId;
  }

  // ============================================
  // オンライン復帰時の同期処理
  // ============================================

  /// 同期待ちのデータをFirestoreにアップロード
  static Future<void> syncPendingData() async {
    final pendingBox = Hive.box(_pendingSyncBox);
    final workoutsBox = Hive.box(_workoutsCacheBox);
    final bodyMeasurementsBox = Hive.box(_bodyMeasurementsBox); // ✅ v1.0.161

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
              'user_id': workoutData['user_id'],
              'muscle_group': workoutData['muscle_group'],
              'date': Timestamp.fromDate(DateTime.parse(workoutData['date'])),
              'start_time': Timestamp.fromDate(DateTime.parse(workoutData['start_time'])),
              'end_time': Timestamp.fromDate(DateTime.parse(workoutData['end_time'])),
              'sets': workoutData['sets'],
              'created_at': FieldValue.serverTimestamp(),
            });

            // 同期成功したらローカルデータを削除
            await workoutsBox.delete(localId);
            await pendingBox.delete(key);

            print('✅ Synced workout: $localId → ${docRef.id}');
          }
        } else if (type == 'body_measurement') {
          // ✅ v1.0.161: 体重記録を同期
          final measurementData = bodyMeasurementsBox.get(localId);
          if (measurementData != null) {
            // Firestoreに保存
            final docRef = await FirebaseFirestore.instance
                .collection('body_measurements')
                .add({
              'user_id': measurementData['user_id'],
              'date': Timestamp.fromDate(DateTime.parse(measurementData['date'])),
              'weight': measurementData['weight'],
              'body_fat_percentage': measurementData['body_fat_percentage'],
              'created_at': FieldValue.serverTimestamp(),
            });

            // 同期成功したらローカルデータを削除
            await bodyMeasurementsBox.delete(localId);
            await pendingBox.delete(key);

            print('✅ Synced body measurement: $localId → ${docRef.id}');
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
  /// v1.0.187: オンライン状態を確認（タイムアウト改善）
  static Future<bool> isOnline() async {
    try {
      // Step 1: connectivity_plus でネットワーク接続を確認
      final List<ConnectivityResult> connectivityResults = await Connectivity().checkConnectivity();
      
      // 接続なしの場合は即座にオフライン判定
      if (connectivityResults.contains(ConnectivityResult.none) || connectivityResults.isEmpty) {
        debugPrint('📴 [Offline] ネットワーク接続なし');
        return false;
      }
      
      debugPrint('🔍 [Network] 接続検出: $connectivityResults');
      
      // Step 2: Firestore への実際の接続を確認（タイムアウト 500ms）
      try {
        debugPrint('🔍 [Firestore] サーバー接続テスト開始...');
        final startTime = DateTime.now();
        
        final result = await FirebaseFirestore.instance
            .collection('_connection_test')  // テスト用コレクション
            .limit(1)
            .get(const GetOptions(source: Source.server))  // 強制的にサーバーから取得
            .timeout(
              const Duration(milliseconds: 500),  // ✅ v1.0.187: 1秒→500msに短縮
              onTimeout: () {
                debugPrint('📴 [Firestore] タイムアウト (500ms)');
                throw TimeoutException('Firestore connection timeout');
              },
            );
        
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        
        // メタデータからキャッシュの使用状況を確認
        final isFromCache = result.metadata.isFromCache;
        final hasPendingWrites = result.metadata.hasPendingWrites;
        
        if (isFromCache) {
          debugPrint('📴 [Firestore] キャッシュから取得（オフライン） - ${duration}ms');
          return false;
        }
        
        if (hasPendingWrites) {
          debugPrint('📴 [Firestore] 保留中の書き込みあり（オフライン） - ${duration}ms');
          return false;
        }
        
        debugPrint('🌐 [Firestore] サーバー接続成功 ✅ - ${duration}ms');
        return true;
        
      } on TimeoutException catch (e) {
        debugPrint('📴 [Firestore] タイムアウトエラー: $e');
        return false;
      } catch (e) {
        debugPrint('📴 [Firestore] 接続失敗: $e');
        return false;
      }
    } catch (e) {
      debugPrint('📴 [Network] チェックエラー: $e');
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
