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
  // 修正: 直接Google Places APIのエンドポイントを指定
  static const String _googlePlacesBaseUrl = 'https://maps.googleapis.com/maps/api/place';
  
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

      // 修正: Google Places APIを直接呼び出し
      final url = Uri.parse(
        '$_googlePlacesBaseUrl/nearbysearch/json' // 変更: /jsonを追加
        '?location=$latitude,$longitude'
        '&radius=$radiusMeters'
        '&type=gym'
        '&keyword=フィットネス|トレーニング|ジム|スポーツクラブ'
        '&language=${ApiKeys.defaultLanguage}'
        '&key=${ApiKeys.googlePlacesApiKey}', // 追加: 必須のAPIキー
      );

      if (kDebugMode) {
        print('🌐 Google Places API via Proxy (Nearby Search)');
        print('   Proxy URL: $url');
      }

      final response = await http.get(
        url,
        headers: {
          'X-Ios-Bundle-Identifier': 'com.nexa.gymmatch',
        },
      );

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
        
        if (data['status'] == AppLocalizations.of(context)!.ok) {
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
      AppLocalizations.of(context)!.general_3b55a7d0,
      AppLocalizations.of(context)!.general_48a8a611,
      AppLocalizations.of(context)!.general_6b9cb4c6,
      AppLocalizations.of(context)!.general_2d0e8920,
      AppLocalizations.of(context)!.general_882737a5,
      AppLocalizations.of(context)!.general_d0f4f4d4,
      AppLocalizations.of(context)!.general_d93877f1,
      AppLocalizations.of(context)!.general_e7cd7823,
      AppLocalizations.of(context)!.general_54f5e1c6,
      AppLocalizations.of(context)!.general_1802e11f,
      AppLocalizations.of(context)!.general_3a087c8f,
      AppLocalizations.of(context)!.gym_dcf4ca1a,
      AppLocalizations.of(context)!.general_c5dba1e4,
      AppLocalizations.of(context)!.general_0d197c3d,
      AppLocalizations.of(context)!.general_ff2f16ae,
      AppLocalizations.of(context)!.general_e93e2341,
      AppLocalizations.of(context)!.general_fbc72a92,
      AppLocalizations.of(context)!.general_b8b93fa6,
      AppLocalizations.of(context)!.general_0c2a7e83,
      AppLocalizations.of(context)!.general_07a89d29,
      AppLocalizations.of(context)!.general_ac507aa1,
      AppLocalizations.of(context)!.general_1508cdb1,
      AppLocalizations.of(context)!.general_f02c20e2,
      AppLocalizations.of(context)!.general_a1de7ecf,
      AppLocalizations.of(context)!.general_63e0b89e,
      AppLocalizations.of(context)!.general_c133a12e,
      AppLocalizations.of(context)!.general_1b40e42d,
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

      // 修正: Google Places APIを直接呼び出し
      final url = Uri.parse(
        '$_googlePlacesBaseUrl/textsearch/json' // 変更: /jsonを追加
        '?query=$query ジム'
        '&type=gym'
        '&language=${ApiKeys.defaultLanguage}'
        '&region=${ApiKeys.defaultRegion}'
        '&key=${ApiKeys.googlePlacesApiKey}', // 追加: 必須のAPIキー
      );

      if (kDebugMode) {
        print('🌐 Google Places API via Proxy (Text Search)');
        print('   Query: "$query"');
        print('   Proxy URL: $url');
      }

      final response = await http.get(
        url,
        headers: {
          'X-Ios-Bundle-Identifier': 'com.nexa.gymmatch',
        },
      );

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
        
        if (data['status'] == AppLocalizations.of(context)!.ok || data['status'] == 'ZERO_RESULTS') {
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

  /// ジムの詳細情報を取得（Place Details API - コスト最適化版）
  /// 
  /// 💰 コスト最適化:
  /// - Hiveキャッシュで重複API呼び出しを削減（30日TTL）
  /// - フィールドマスキングで高コストフィールド（photos）をオプション化
  /// - 月額$2.98削減/1000ユーザー（photosなし時）
  /// 
  /// [placeId] Google Places ID
  /// [includePhotos] 写真を含めるか（デフォルト: false）
  ///   - false: Basic Data ($0.017/1000) のみ
  ///   - true: Contact Data ($3.00/1000) を含む
  /// [forceRefresh] キャッシュを無視して強制再取得
  Future<Map<String, dynamic>> getGymDetails(
    String placeId, {
    bool includePhotos = false,
    bool forceRefresh = false,
  }) async {
    try {
      // 🚀 キャッシュチェック（30日TTL）
      if (!forceRefresh) {
        final cached = _cacheService.getCachedPlaceDetails(placeId);
        if (cached != null) {
          if (kDebugMode) {
            print('🚀 Using cached place details (API call saved!): $placeId');
          }
          return cached;
        }
      }

      // 💰 フィールドマスキング（コスト最適化）
      // Basic Data: name, address, phone, hours, website, rating ($0.017/1000)
      final baseFields = 'name,formatted_address,formatted_phone_number,opening_hours,website,rating,user_ratings_total,price_level';
      
      // Contact Data: photos ($3.00/1000 - 約176倍高い！)
      final photoFields = includePhotos ? ',photos' : '';
      
      final url = Uri.parse(
        '${ApiKeys.placesApiBaseUrl}/details/json'
        '?place_id=$placeId'
        '&fields=$baseFields$photoFields' // ← 動的フィールド選択
        '&language=${ApiKeys.defaultLanguage}'
        '&key=${ApiKeys.googlePlacesApiKey}',
      );

      if (kDebugMode) {
        print('🌐 Google Places API (Place Details)');
        print('   Place ID: $placeId');
        print('   Include Photos: $includePhotos');
        print('   Expected Cost: ${includePhotos ? "\$0.003" : "\$0.000017"} per request');
      }

      final response = await http.get(
        url,
        headers: {
          'X-Ios-Bundle-Identifier': 'com.nexa.gymmatch',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == AppLocalizations.of(context)!.ok) {
          final result = data['result'] as Map<String, dynamic>;
          
          // 🎯 Hiveにキャッシュ（30日TTL - Google規約準拠）
          _cacheService.cachePlaceDetails(placeId, result);
          
          if (kDebugMode) {
            print('   ✅ Place details retrieved and cached');
          }
          
          return result;
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
