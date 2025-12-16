import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/google_place.dart';

/// 検索結果キャッシュサービス（Hive永続化版）
/// 
/// 🎯 コスト最適化戦略:
/// - Google Places API呼び出しを削減するため、
///   検索結果を24時間Hiveにキャッシュして再利用
/// - アプリ再起動後もキャッシュが残る（月間$16-24削減）
/// 
/// 💰 期待される効果:
/// - 月間API呼び出し削減: 約50%
/// - コスト削減: 約¥4,000/月（1000ユーザー）
class SearchCacheService {
  // シングルトンパターン
  static final SearchCacheService _instance = SearchCacheService._internal();
  factory SearchCacheService() => _instance;
  SearchCacheService._internal();

  // Hiveボックス名
  static const String _cacheBoxName = 'google_places_cache';
  static const String _detailsCacheBoxName = 'google_place_details_cache';
  
  // キャッシュ有効期限
  static const Duration _searchCacheExpiration = Duration(hours: 24); // 検索結果: 24時間
  static const Duration _detailsCacheExpiration = Duration(days: 30); // 詳細情報: 30日

  // Hiveボックス（遅延初期化）
  Box<Map>? _cacheBox;
  Box<Map>? _detailsCacheBox;

  /// Hive初期化
  Future<void> init() async {
    try {
      _cacheBox = await Hive.openBox<Map>(_cacheBoxName);
      _detailsCacheBox = await Hive.openBox<Map>(_detailsCacheBoxName);
      
      if (kDebugMode) {
        print('✅ SearchCacheService (Hive) initialized');
        print('   Cache entries: ${_cacheBox?.length ?? 0}');
        print('   Details cache entries: ${_detailsCacheBox?.length ?? 0}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize SearchCacheService (Hive): $e');
      }
    }
  }

  /// テキスト検索結果をキャッシュから取得
  /// 
  /// キャッシュが無い、または期限切れの場合はnullを返す
  List<GooglePlace>? getCachedTextSearch(String query) {
    if (_cacheBox == null) return null;
    
    final cacheKey = _generateTextSearchKey(query);
    final cached = _cacheBox!.get(cacheKey);

    if (cached == null) {
      if (kDebugMode) {
        print('💾 Cache MISS: Text search "$query"');
      }
      return null;
    }

    // 期限切れチェック
    final timestamp = DateTime.fromMillisecondsSinceEpoch(cached['timestamp'] as int);
    if (DateTime.now().difference(timestamp) > _searchCacheExpiration) {
      if (kDebugMode) {
        print('⏰ Cache EXPIRED: Text search "$query"');
      }
      _cacheBox!.delete(cacheKey);
      return null;
    }

    // Hiveから復元
    try {
      final resultsJson = (cached['results'] as List<dynamic>).cast<Map>();
      final places = resultsJson
          .map((json) => GooglePlace.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      
      if (kDebugMode) {
        print('✅ Cache HIT (Hive): Text search "$query" (${places.length} results)');
      }
      
      return places;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Cache deserialization error: $e');
      }
      _cacheBox!.delete(cacheKey);
      return null;
    }
  }

  /// テキスト検索結果をキャッシュに保存
  void cacheTextSearch(String query, List<GooglePlace> results) {
    if (_cacheBox == null) return;
    
    final cacheKey = _generateTextSearchKey(query);
    
    try {
      _cacheBox!.put(cacheKey, {
        'results': results.map((place) => place.toJson()).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (kDebugMode) {
        print('💾 Cached (Hive) text search: "$query" (${results.length} results)');
      }

      // キャッシュサイズ制限
      _limitCacheSize();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to cache text search: $e');
      }
    }
  }

  /// GPS検索結果をキャッシュから取得
  List<GooglePlace>? getCachedNearbySearch(
    double latitude,
    double longitude,
    int radiusMeters,
  ) {
    if (_cacheBox == null) return null;
    
    final cacheKey = _generateNearbySearchKey(latitude, longitude, radiusMeters);
    final cached = _cacheBox!.get(cacheKey);

    if (cached == null) {
      if (kDebugMode) {
        print('💾 Cache MISS: Nearby search (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})');
      }
      return null;
    }

    // 期限切れチェック
    final timestamp = DateTime.fromMillisecondsSinceEpoch(cached['timestamp'] as int);
    if (DateTime.now().difference(timestamp) > _searchCacheExpiration) {
      if (kDebugMode) {
        print('⏰ Cache EXPIRED: Nearby search');
      }
      _cacheBox!.delete(cacheKey);
      return null;
    }

    // Hiveから復元
    try {
      final resultsJson = (cached['results'] as List<dynamic>).cast<Map>();
      final places = resultsJson
          .map((json) => GooglePlace.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      
      if (kDebugMode) {
        print('✅ Cache HIT (Hive): Nearby search (${places.length} results)');
      }
      
      return places;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Cache deserialization error: $e');
      }
      _cacheBox!.delete(cacheKey);
      return null;
    }
  }

  /// GPS検索結果をキャッシュに保存
  void cacheNearbySearch(
    double latitude,
    double longitude,
    int radiusMeters,
    List<GooglePlace> results,
  ) {
    if (_cacheBox == null) return;
    
    final cacheKey = _generateNearbySearchKey(latitude, longitude, radiusMeters);
    
    try {
      _cacheBox!.put(cacheKey, {
        'results': results.map((place) => place.toJson()).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (kDebugMode) {
        print('💾 Cached (Hive) nearby search: (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}) - ${results.length} results');
      }

      _limitCacheSize();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to cache nearby search: $e');
      }
    }
  }

  /// Place Details をキャッシュから取得
  /// 
  /// 💰 コスト削減: 同じジムの詳細画面を何度開いても1回のみAPI呼び出し
  Map<String, dynamic>? getCachedPlaceDetails(String placeId) {
    if (_detailsCacheBox == null) return null;
    
    final cached = _detailsCacheBox!.get(placeId);

    if (cached == null) {
      if (kDebugMode) {
        print('💾 Cache MISS: Place details "$placeId"');
      }
      return null;
    }

    // 期限切れチェック（30日）
    final timestamp = DateTime.fromMillisecondsSinceEpoch(cached['timestamp'] as int);
    if (DateTime.now().difference(timestamp) > _detailsCacheExpiration) {
      if (kDebugMode) {
        print('⏰ Cache EXPIRED: Place details "$placeId"');
      }
      _detailsCacheBox!.delete(placeId);
      return null;
    }

    if (kDebugMode) {
      print('✅ Cache HIT (Hive): Place details "$placeId"');
    }

    return Map<String, dynamic>.from(cached['data'] as Map);
  }

  /// Place Details をキャッシュに保存
  /// 
  /// 💰 コスト削減効果: 月額$5-10削減/1000ユーザー
  void cachePlaceDetails(String placeId, Map<String, dynamic> details) {
    if (_detailsCacheBox == null) return;
    
    try {
      _detailsCacheBox!.put(placeId, {
        'data': details,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (kDebugMode) {
        print('💾 Cached (Hive) place details: "$placeId"');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to cache place details: $e');
      }
    }
  }

  /// キャッシュをクリア
  Future<void> clearCache() async {
    try {
      final searchCount = _cacheBox?.length ?? 0;
      final detailsCount = _detailsCacheBox?.length ?? 0;
      
      await _cacheBox?.clear();
      await _detailsCacheBox?.clear();
      
      if (kDebugMode) {
        print('🗑️ Cache cleared (Hive):');
        print('   Search cache: $searchCount entries removed');
        print('   Details cache: $detailsCount entries removed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to clear cache: $e');
      }
    }
  }

  /// キャッシュ統計情報を取得
  Map<String, dynamic> getCacheStats() {
    int searchValid = 0;
    int searchExpired = 0;
    int detailsValid = 0;
    int detailsExpired = 0;

    // 検索キャッシュの統計
    if (_cacheBox != null) {
      for (final entry in _cacheBox!.values) {
        try {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(entry['timestamp'] as int);
          if (DateTime.now().difference(timestamp) > _searchCacheExpiration) {
            searchExpired++;
          } else {
            searchValid++;
          }
        } catch (e) {
          searchExpired++;
        }
      }
    }

    // 詳細キャッシュの統計
    if (_detailsCacheBox != null) {
      for (final entry in _detailsCacheBox!.values) {
        try {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(entry['timestamp'] as int);
          if (DateTime.now().difference(timestamp) > _detailsCacheExpiration) {
            detailsExpired++;
          } else {
            detailsValid++;
          }
        } catch (e) {
          detailsExpired++;
        }
      }
    }

    return {
      'search_cache': {
        'total': (_cacheBox?.length ?? 0),
        'valid': searchValid,
        'expired': searchExpired,
      },
      'details_cache': {
        'total': (_detailsCacheBox?.length ?? 0),
        'valid': detailsValid,
        'expired': detailsExpired,
      },
    };
  }

  /// テキスト検索用キャッシュキーを生成
  String _generateTextSearchKey(String query) {
    // クエリを正規化（大文字小文字、空白を統一）
    final normalized = query.trim().toLowerCase();
    return 'text:$normalized';
  }

  /// GPS検索用キャッシュキーを生成
  /// 
  /// 位置情報を0.01度（約1km）単位で丸めてキャッシュキーとする
  /// これにより、近接した位置からの検索を同一キャッシュで対応
  String _generateNearbySearchKey(
    double latitude,
    double longitude,
    int radiusMeters,
  ) {
    // 0.01度単位で丸める（約1km単位）
    final roundedLat = (latitude * 100).round() / 100;
    final roundedLng = (longitude * 100).round() / 100;
    
    return 'nearby:$roundedLat,$roundedLng,$radiusMeters';
  }

  /// キャッシュサイズを制限（古いエントリーを削除）
  /// 
  /// 🔧 改善: 100件 → 500件に増加（Hiveは軽量）
  void _limitCacheSize({int maxSize = 500}) {
    if (_cacheBox == null) return;
    if (_cacheBox!.length <= maxSize) return;

    try {
      // タイムスタンプ順にソートして古いものから削除
      final entries = _cacheBox!.toMap().entries.toList()
        ..sort((a, b) {
          final aTime = a.value['timestamp'] as int;
          final bTime = b.value['timestamp'] as int;
          return aTime.compareTo(bTime);
        });

      final toRemove = entries.take(_cacheBox!.length - maxSize);
      for (final entry in toRemove) {
        _cacheBox!.delete(entry.key);
      }

      if (kDebugMode) {
        print('🗑️ Cache size limited (Hive): removed ${toRemove.length} old entries');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to limit cache size: $e');
      }
    }
  }
}
