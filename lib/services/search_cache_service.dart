import 'package:flutter/foundation.dart';
import '../models/gym.dart';
import '../models/google_place.dart';

/// 検索結果キャッシュサービス
/// 
/// Google Places API呼び出しを削減するため、
/// 検索結果を24時間キャッシュして再利用
class SearchCacheService {
  // シングルトンパターン
  static final SearchCacheService _instance = SearchCacheService._internal();
  factory SearchCacheService() => _instance;
  SearchCacheService._internal();

  // キャッシュストレージ（メモリベース）
  final Map<String, _CachedSearchResult> _cache = {};

  // キャッシュ有効期限（24時間）
  static const Duration _cacheExpiration = Duration(hours: 24);

  /// テキスト検索結果をキャッシュから取得
  /// 
  /// キャッシュが無い、または期限切れの場合はnullを返す
  List<GooglePlace>? getCachedTextSearch(String query) {
    final cacheKey = _generateTextSearchKey(query);
    final cached = _cache[cacheKey];

    if (cached == null) {
      if (kDebugMode) {
        print('💾 Cache MISS: Text search "$query"');
      }
      return null;
    }

    // 期限切れチェック
    if (DateTime.now().difference(cached.timestamp) > _cacheExpiration) {
      if (kDebugMode) {
        print('⏰ Cache EXPIRED: Text search "$query"');
      }
      _cache.remove(cacheKey);
      return null;
    }

    if (kDebugMode) {
      print('✅ Cache HIT: Text search "$query" (${cached.results.length} results)');
    }

    return cached.results as List<GooglePlace>;
  }

  /// テキスト検索結果をキャッシュに保存
  void cacheTextSearch(String query, List<GooglePlace> results) {
    final cacheKey = _generateTextSearchKey(query);
    
    _cache[cacheKey] = _CachedSearchResult(
      results: results,
      timestamp: DateTime.now(),
    );

    if (kDebugMode) {
      print('💾 Cached text search: "$query" (${results.length} results)');
    }

    // キャッシュサイズ制限（100件まで）
    _limitCacheSize();
  }

  /// GPS検索結果をキャッシュから取得
  List<GooglePlace>? getCachedNearbySearch(
    double latitude,
    double longitude,
    int radiusMeters,
  ) {
    final cacheKey = _generateNearbySearchKey(latitude, longitude, radiusMeters);
    final cached = _cache[cacheKey];

    if (cached == null) {
      if (kDebugMode) {
        print('💾 Cache MISS: Nearby search (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})');
      }
      return null;
    }

    // 期限切れチェック
    if (DateTime.now().difference(cached.timestamp) > _cacheExpiration) {
      if (kDebugMode) {
        print('⏰ Cache EXPIRED: Nearby search');
      }
      _cache.remove(cacheKey);
      return null;
    }

    if (kDebugMode) {
      print('✅ Cache HIT: Nearby search (${cached.results.length} results)');
    }

    return cached.results as List<GooglePlace>;
  }

  /// GPS検索結果をキャッシュに保存
  void cacheNearbySearch(
    double latitude,
    double longitude,
    int radiusMeters,
    List<GooglePlace> results,
  ) {
    final cacheKey = _generateNearbySearchKey(latitude, longitude, radiusMeters);
    
    _cache[cacheKey] = _CachedSearchResult(
      results: results,
      timestamp: DateTime.now(),
    );

    if (kDebugMode) {
      print('💾 Cached nearby search: (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}) - ${results.length} results');
    }

    _limitCacheSize();
  }

  /// キャッシュをクリア
  void clearCache() {
    final count = _cache.length;
    _cache.clear();
    
    if (kDebugMode) {
      print('🗑️ Cache cleared: $count entries removed');
    }
  }

  /// キャッシュ統計情報を取得
  Map<String, dynamic> getCacheStats() {
    int validCount = 0;
    int expiredCount = 0;

    for (final entry in _cache.values) {
      if (DateTime.now().difference(entry.timestamp) > _cacheExpiration) {
        expiredCount++;
      } else {
        validCount++;
      }
    }

    return {
      'total': _cache.length,
      'valid': validCount,
      'expired': expiredCount,
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
  void _limitCacheSize({int maxSize = 100}) {
    if (_cache.length <= maxSize) return;

    // タイムスタンプ順にソートして古いものから削除
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

    final toRemove = entries.take(_cache.length - maxSize);
    for (final entry in toRemove) {
      _cache.remove(entry.key);
    }

    if (kDebugMode) {
      print('🗑️ Cache size limited: removed ${toRemove.length} old entries');
    }
  }
}

/// キャッシュされた検索結果
class _CachedSearchResult {
  final List<dynamic> results; // List<GooglePlace>
  final DateTime timestamp;

  _CachedSearchResult({
    required this.results,
    required this.timestamp,
  });
}
