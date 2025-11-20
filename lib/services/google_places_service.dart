import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../models/google_place.dart';
import '../models/gym.dart';
import 'search_cache_service.dart';
import 'partner_merge_service.dart';

/// Google Places API検索サービス（プロキシ経由）
/// 全国のジム・フィットネス施設を検索
class GooglePlacesService {
  // プロキシサーバーURL（サンドボックス内部通信）
  static const String _proxyBaseUrl = 'https://8080-i1wzdi6c2urpgehncb6jg-583b4d74.sandbox.novita.ai/api/places';
  
  // 検索キャッシュサービス
  final SearchCacheService _cacheService = SearchCacheService();
  
  // パートナー情報統合サービス
  final PartnerMergeService _partnerMergeService = PartnerMergeService();
  /// GPS位置ベースでジムを検索（Nearby Search API）
  /// 
  /// [latitude] 緯度
  /// [longitude] 経度
  /// [radiusMeters] 検索半径（メートル）
  Future<List<GooglePlace>> searchNearbyGyms({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) async {
    try {
      // キャッシュチェック
      final cached = _cacheService.getCachedNearbySearch(
        latitude,
        longitude,
        radiusMeters,
      );
      if (cached != null) {
        if (kDebugMode) {
          print('🚀 Using cached nearby search results (API call saved!)');
        }
        return cached;
      }

      // プロキシサーバー経由でAPI呼び出し
      final url = Uri.parse(
        '$_proxyBaseUrl/nearbysearch'
        '?location=$latitude,$longitude'
        '&radius=$radiusMeters'
        '&type=gym'
        '&keyword=フィットネス|トレーニング|ジム|スポーツクラブ'
        '&language=${ApiKeys.defaultLanguage}',
      );

      if (kDebugMode) {
        print('🌐 Google Places API via Proxy (Nearby Search)');
        print('   Proxy URL: $url');
      }

      final response = await http.get(url);

      if (kDebugMode) {
        print('   Status Code: ${response.statusCode}');
        print('   Response Length: ${response.body.length} bytes');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          print('   API Status: ${data['status']}');
          if (data['error_message'] != null) {
            print('   ⚠️ Error Message: ${data['error_message']}');
          }
        }
        
        if (data['status'] == 'OK') {
          final results = data['results'] as List<dynamic>;
          if (kDebugMode) {
            print('   ✅ Found ${results.length} places');
          }
          final places = results
              .map((json) => GooglePlace.fromJson(json as Map<String, dynamic>))
              .toList();
          
          // 🔍 フィットネスジム以外の施設を除外
          final filteredPlaces = _filterNonGymFacilities(places);
          
          if (kDebugMode) {
            print('   🔍 Filtered: ${places.length} → ${filteredPlaces.length} (removed ${places.length - filteredPlaces.length} non-gym facilities)');
          }
          
          // 結果をキャッシュに保存
          _cacheService.cacheNearbySearch(latitude, longitude, radiusMeters, filteredPlaces);
          
          return filteredPlaces;
        } else if (data['status'] == 'ZERO_RESULTS') {
          if (kDebugMode) {
            print('   ℹ️ No results found');
          }
          final emptyList = <GooglePlace>[];
          // 空結果もキャッシュ（無駄なAPI呼び出し防止）
          _cacheService.cacheNearbySearch(latitude, longitude, radiusMeters, emptyList);
          return emptyList;
        } else {
          throw Exception('Google Places API error: ${data['status']} - ${data['error_message'] ?? "No details"}}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search nearby gyms: $e');
    }
  }

  /// フィットネスジム以外の施設を除外するフィルター
  /// 
  /// 公共体育館、直売所、公民館など無関係な施設を除外
  List<GooglePlace> _filterNonGymFacilities(List<GooglePlace> places) {
    // 除外キーワードリスト（施設名に含まれていたら除外）
    const excludeKeywords = [
      '体育館',
      '公園',
      '直売所',
      '市民センター',
      '公民館',
      '図書館',
      '役所',
      '学校',
      '武道館',
      '陸上競技場',
      '野球場',
      'テニスコート',
      '市役所',
      '町役場',
      '村役場',
      '区役所',
      '保健所',
      '病院',
      'クリニック',
      '歯科',
      'ホテル',
      '旅館',
      '温泉',
      '銭湯',
      'マッサージ',
      '整体',
      '接骨院',
    ];
    
    return places.where((place) {
      final nameLower = place.name.toLowerCase();
      
      // 除外キーワードが含まれていたら除外
      final shouldExclude = excludeKeywords.any((keyword) => nameLower.contains(keyword));
      
      if (shouldExclude && kDebugMode) {
        print('   ❌ Excluded: ${place.name} (non-gym facility)');
      }
      
      return !shouldExclude;
    }).toList();
  }

  /// テキストベースでジムを検索（Text Search API）
  /// 
  /// [query] 検索クエリ（例: "渋谷 ジム", "福岡 24時間"）
  Future<List<GooglePlace>> searchGymsByText(String query) async {
    try {
      // キャッシュチェック
      final cached = _cacheService.getCachedTextSearch(query);
      if (cached != null) {
        if (kDebugMode) {
          print('🚀 Using cached text search results (API call saved!)');
        }
        return cached;
      }

      // プロキシサーバー経由でAPI呼び出し
      final url = Uri.parse(
        '$_proxyBaseUrl/textsearch'
        '?query=$query ジム'
        '&type=gym'
        '&language=${ApiKeys.defaultLanguage}'
        '&region=${ApiKeys.defaultRegion}',
      );

      if (kDebugMode) {
        print('🌐 Google Places API via Proxy (Text Search)');
        print('   Query: "$query"');
        print('   Proxy URL: $url');
      }

      final response = await http.get(url);

      if (kDebugMode) {
        print('   Status Code: ${response.statusCode}');
        print('   Response Length: ${response.body.length} bytes');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          print('   API Status: ${data['status']}');
          if (data['error_message'] != null) {
            print('   ⚠️ Error Message: ${data['error_message']}');
          }
        }
        
        if (data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS') {
          final results = data['results'] as List<dynamic>? ?? [];
          if (kDebugMode) {
            print('   ✅ Found ${results.length} places');
          }
          final places = results
              .map((json) => GooglePlace.fromJson(json as Map<String, dynamic>))
              .toList();
          
          // 🔍 フィットネスジム以外の施設を除外
          final filteredPlaces = _filterNonGymFacilities(places);
          
          if (kDebugMode) {
            print('   🔍 Filtered: ${places.length} → ${filteredPlaces.length} (removed ${places.length - filteredPlaces.length} non-gym facilities)');
          }
          
          // 結果をキャッシュに保存
          _cacheService.cacheTextSearch(query, filteredPlaces);
          
          return filteredPlaces;
        } else {
          throw Exception('Google Places API error: ${data['status']} - ${data['error_message'] ?? "No details"}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search gyms by text: $e');
    }
  }

  /// ジムの詳細情報を取得（Place Details API）
  /// 
  /// [placeId] Google Places ID
  Future<Map<String, dynamic>> getGymDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '${ApiKeys.placesApiBaseUrl}/details/json'
        '?place_id=$placeId'
        '&fields=name,formatted_address,formatted_phone_number,opening_hours,website,rating,user_ratings_total,photos,price_level'
        '&language=${ApiKeys.defaultLanguage}'
        '&key=${ApiKeys.googlePlacesApiKey}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return data['result'] as Map<String, dynamic>;
        } else {
          throw Exception('Google Places API error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get gym details: $e');
    }
  }

  /// 混雑度情報を取得（Google Places API経由 - 推定ベース）
  /// 
  /// 💡 低コスト実装: 追加API呼び出しなし！
  /// - 既存のNearby Search/Text Search結果から推定
  /// - rating + user_ratings_total + open_now を使用
  /// - コスト: $0（検索時に取得済み）
  /// 
  /// [placeId] Google Places ID
  /// 戻り値: 推定混雑度（1-5）またはnull
  Future<int?> getCurrentCrowdLevel(String placeId) async {
    if (kDebugMode) {
      print('📊 Estimating crowd level from existing Google Places data (zero cost)');
      print('   Place ID: $placeId');
    }
    
    // 注意: このメソッドはplaceIdから直接混雑度を取得できない
    // GooglePlaceモデルの推定値（estimatedCrowdLevel）を使用すること
    // 
    // CrowdLevelServiceがこのメソッドを呼び出している場合、
    // 代わりにGooglePlace.estimatedCrowdLevelを直接使用するよう修正が必要
    
    return null; // placeIdのみでは推定不可（GooglePlaceオブジェクトが必要）
  }

  /// 写真URLを生成
  /// 
  /// [photoReference] Google Places写真参照ID
  /// [maxWidth] 最大幅（デフォルト400px）
  String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return 'https://maps.googleapis.com/maps/api/place/photo'
        '?maxwidth=$maxWidth'
        '&photo_reference=$photoReference'
        '&key=${ApiKeys.googlePlacesApiKey}';
  }

  /// GPS検索とテキスト検索の複合検索
  /// 
  /// GPS優先 → テキスト検索でフォールバック
  Future<List<GooglePlace>> searchGyms({
    double? latitude,
    double? longitude,
    int? radiusMeters,
    String? textQuery,
  }) async {
    // GPS位置が指定されている場合
    if (latitude != null && longitude != null) {
      return await searchNearbyGyms(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters ?? ApiKeys.defaultSearchRadius,
      );
    }
    
    // テキスト検索
    if (textQuery != null && textQuery.isNotEmpty) {
      return await searchGymsByText(textQuery);
    }
    
    // どちらも指定されていない場合はエラー
    throw Exception('Either GPS coordinates or text query must be provided');
  }

  // ==================== 🔥 NEW: パートナー情報統合版API ====================

  /// GPS位置ベースでジムを検索（パートナー情報統合版）
  /// 
  /// Google Places APIの結果とFirestoreパートナー情報を統合
  Future<List<Gym>> searchNearbyGymsWithPartners({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) async {
    final places = await searchNearbyGyms(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
    return await _partnerMergeService.mergePartnerData(places);
  }

  /// テキストベースでジムを検索（パートナー情報統合版）
  /// 
  /// Google Places APIの結果とFirestoreパートナー情報を統合
  Future<List<Gym>> searchGymsByTextWithPartners(String query) async {
    final places = await searchGymsByText(query);
    return await _partnerMergeService.mergePartnerData(places);
  }

  /// GPS検索とテキスト検索の複合検索（パートナー情報統合版）
  /// 
  /// GPS優先 → テキスト検索でフォールバック
  Future<List<Gym>> searchGymsWithPartners({
    double? latitude,
    double? longitude,
    int? radiusMeters,
    String? textQuery,
  }) async {
    // GPS位置が指定されている場合
    if (latitude != null && longitude != null) {
      return await searchNearbyGymsWithPartners(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters ?? ApiKeys.defaultSearchRadius,
      );
    }
    
    // テキスト検索
    if (textQuery != null && textQuery.isNotEmpty) {
      return await searchGymsByTextWithPartners(textQuery);
    }
    
    // どちらも指定されていない場合はエラー
    throw Exception('Either GPS coordinates or text query must be provided');
  }
}
