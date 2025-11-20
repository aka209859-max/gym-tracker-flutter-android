import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'google_places_service.dart';

/// 混雑度管理サービス
/// 
/// データソース優先順位:
/// 1. ユーザー報告（最優先）
/// 2. Firebaseキャッシュ（24時間）
/// 3. Google Places API統計データ
class CrowdLevelService {
  final GooglePlacesService _placesService = GooglePlacesService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// キャッシュ有効期間（24時間）
  static const Duration _cacheExpiration = Duration(hours: 24);

  /// ジムの混雑度を取得
  /// 
  /// [gymId] ジムID（FirestoreのドキュメントID）
  /// [placeId] Google Places ID（Google APIから取得する場合に使用）
  /// 
  /// 戻り値: 混雑度レベル（1-5）またはnull（データなし）
  Future<int?> getCrowdLevel({
    required String gymId,
    String? placeId,
  }) async {
    try {
      // 1. ユーザー報告をチェック（最優先）
      final userReportLevel = await _getUserReportedLevel(gymId);
      if (userReportLevel != null) {
        if (kDebugMode) {
          print('✅ Using user-reported crowd level: $userReportLevel');
        }
        return userReportLevel;
      }

      // 2. Firebaseキャッシュをチェック
      final cachedLevel = await _getCachedLevel(gymId);
      if (cachedLevel != null) {
        if (kDebugMode) {
          print('✅ Using cached crowd level: $cachedLevel');
        }
        return cachedLevel;
      }

      // 3. Google Places APIから取得（placeIdが必要）
      if (placeId != null && placeId.isNotEmpty) {
        if (kDebugMode) {
          print('🌐 Fetching crowd level from Google Places API...');
        }
        
        final apiLevel = await _placesService.getCurrentCrowdLevel(placeId);
        
        if (apiLevel != null) {
          // APIから取得したデータをキャッシュ
          await _cacheLevel(gymId, apiLevel);
          
          if (kDebugMode) {
            print('✅ Got crowd level from API and cached: $apiLevel');
          }
          
          return apiLevel;
        }
      }

      // データなし
      if (kDebugMode) {
        print('ℹ️ No crowd level data available for gym: $gymId');
      }
      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting crowd level: $e');
      }
      return null;
    }
  }

  /// ユーザー報告の混雑度を取得
  /// 
  /// 過去24時間以内の報告を有効とする
  Future<int?> _getUserReportedLevel(String gymId) async {
    try {
      final doc = await _firestore.collection('gyms').doc(gymId).get();
      
      if (!doc.exists) {
        return null;
      }
      
      final data = doc.data();
      if (data == null) {
        return null;
      }
      
      // ユーザー報告の混雑度とタイムスタンプをチェック
      final crowdLevel = data['currentCrowdLevel'] as int?;
      final lastUpdate = data['lastCrowdUpdate'] as Timestamp?;
      
      if (crowdLevel == null || lastUpdate == null) {
        return null;
      }
      
      // 24時間以内の報告のみ有効
      final updateTime = lastUpdate.toDate();
      final now = DateTime.now();
      final difference = now.difference(updateTime);
      
      if (difference <= _cacheExpiration) {
        return crowdLevel;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user-reported level: $e');
      }
      return null;
    }
  }

  /// キャッシュされた混雑度を取得
  Future<int?> _getCachedLevel(String gymId) async {
    try {
      final doc = await _firestore
          .collection('crowd_cache')
          .doc(gymId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      final data = doc.data();
      if (data == null) {
        return null;
      }
      
      final cachedLevel = data['crowd_level'] as int?;
      final cachedAt = data['cached_at'] as Timestamp?;
      
      if (cachedLevel == null || cachedAt == null) {
        return null;
      }
      
      // キャッシュ有効期限チェック
      final cacheTime = cachedAt.toDate();
      final now = DateTime.now();
      final difference = now.difference(cacheTime);
      
      if (difference <= _cacheExpiration) {
        return cachedLevel;
      }
      
      // 期限切れキャッシュは削除
      await _firestore.collection('crowd_cache').doc(gymId).delete();
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting cached level: $e');
      }
      return null;
    }
  }

  /// 混雑度をキャッシュに保存
  Future<void> _cacheLevel(String gymId, int level) async {
    try {
      await _firestore.collection('crowd_cache').doc(gymId).set({
        'crowd_level': level,
        'cached_at': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        print('✅ Cached crowd level: $level for gym: $gymId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error caching level: $e');
      }
    }
  }

  /// ユーザーが混雑度を報告
  /// 
  /// この報告は最優先で使用される
  Future<bool> reportCrowdLevel({
    required String gymId,
    required int level,
  }) async {
    try {
      if (level < 1 || level > 5) {
        throw Exception('Invalid crowd level: $level (must be 1-5)');
      }
      
      await _firestore.collection('gyms').doc(gymId).update({
        'currentCrowdLevel': level,
        'lastCrowdUpdate': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        print('✅ User reported crowd level: $level for gym: $gymId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error reporting crowd level: $e');
      }
      return false;
    }
  }
}
