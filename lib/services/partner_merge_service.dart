import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/gym.dart';
import '../models/google_place.dart';

/// パートナージム情報統合サービス
/// 
/// Google Places APIで取得したジムと、Firestoreのパートナージム情報を統合
class PartnerMergeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // パートナージムキャッシュ（初回読み込み後はメモリキャッシュ）
  List<Map<String, dynamic>>? _partnerGymsCache;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Firestoreからパートナージム情報を取得（キャッシュ付き）
  /// 
  /// 【堅牢性強化】エラー時は空リストを返し、GPS検索を継続可能にする
  Future<List<Map<String, dynamic>>> _getPartnerGyms() async {
    // キャッシュが有効な場合はそれを返す
    if (_partnerGymsCache != null && _cacheTime != null) {
      final now = DateTime.now();
      if (now.difference(_cacheTime!) < _cacheDuration) {
        if (kDebugMode) {
          print('🚀 Using cached partner gyms data');
        }
        return _partnerGymsCache!;
      }
    }

    try {
      if (kDebugMode) {
        print('🔍 Fetching partner gyms from Firestore...');
      }
      
      final snapshot = await _firestore
          .collection('gyms')
          .get()  // 全ジムを取得してマッチング（パートナーフラグは後で確認）
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              if (kDebugMode) {
                print('⏱️ Firestore timeout - continuing without partner data');
              }
              throw TimeoutException('Firestore query timeout');
            },
          );
      
      final allGyms = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // gymIdがない場合はdoc.idを使用
        if (!data.containsKey('gymId')) {
          data['gymId'] = doc.id;
        }
        return data;
      }).toList();
      
      // キャッシュを更新
      _partnerGymsCache = allGyms;
      _cacheTime = DateTime.now();
      
      if (kDebugMode) {
        final partnerCount = allGyms.where((g) => g['isPartner'] == true).length;
        print('✅ Found ${allGyms.length} gyms in Firestore (${partnerCount} partners)');
      }
      
      return allGyms;
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('⚠️ Firestore timeout: $e - GPS検索は継続します');
      }
      // 空のキャッシュを設定して次回以降のタイムアウトを回避
      _partnerGymsCache = [];
      _cacheTime = DateTime.now();
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to fetch partner gyms from Firestore: $e');
        print('   GPS検索は通常通り継続されます（パートナージム情報なし）');
      }
      // エラー時も空のキャッシュを設定
      _partnerGymsCache = [];
      _cacheTime = DateTime.now();
      return [];
    }
  }

  /// Google PlaceとFirestoreジムを完全ID一致でマッチング（混雑度報告用）
  /// 
  /// ユーザーが混雑度を報告したジムを見つけるため、Google Place IDで完全一致チェック
  /// パートナージムの名前・住所マッチングとは**完全に分離**
  Map<String, dynamic>? _findExactIdMatch(
    GooglePlace place,
    List<Map<String, dynamic>> partnerGyms,
  ) {
    for (final gym in partnerGyms) {
      final gymId = gym['id'] as String? ?? gym['gymId'] as String?;
      if (gymId == place.placeId) {
        if (kDebugMode) {
          print('   🎯 Exact ID match found: $gymId (crowd report or user data)');
        }
        return gym;
      }
    }
    return null;
  }
  
  /// Google Placeとパートナージムを名前・住所でマッチング（パートナー用のみ）
  /// 
  /// ⚠️ 重要: この関数は isPartner=true のジムのみをマッチング対象にする
  /// 混雑度報告ジム（isPartnerなし）は対象外
  Map<String, dynamic>? _findFuzzyPartnerMatch(
    GooglePlace place,
    List<Map<String, dynamic>> partnerGyms,
  ) {
    // 🔧 CRITICAL FIX: isPartner=true のジムのみを対象にする
    final actualPartnerGyms = partnerGyms.where((g) => g['isPartner'] == true).toList();
    
    if (actualPartnerGyms.isEmpty) {
      return null;
    }
    
    // 名前と住所で類似度マッチング
    for (final partner in actualPartnerGyms) {
      final partnerName = (partner['name'] as String? ?? '').toLowerCase();
      final partnerAddress = (partner['address'] as String? ?? '').toLowerCase();
      final placeName = place.name.toLowerCase();
      final placeAddress = place.address.toLowerCase();
      
      // 名前の類似度チェック（部分一致）
      final nameMatch = _calculateNameSimilarity(placeName, partnerName);
      
      // 住所の類似度チェック（部分一致）
      final addressMatch = _calculateAddressSimilarity(placeAddress, partnerAddress);
      
      if (kDebugMode) {
        print('   Comparing:');
        print('     Place: "$placeName" / "$placeAddress"');
        print('     Partner: "$partnerName" / "$partnerAddress"');
        print('     Name Match: $nameMatch, Address Match: $addressMatch');
      }
      
      // 🔧 緩和された閾値: より多くのジムをマッチング
      // 名前0.4以上（キーワード40%一致） OR 住所0.2以上（都道府県レベル）
      // AND 両方が0でない（完全に無関係ではない）
      if ((nameMatch >= 0.4 && addressMatch >= 0.2) || 
          (nameMatch >= 0.6 && addressMatch >= 0.1) ||
          (nameMatch >= 0.3 && addressMatch >= 0.4)) {
        if (kDebugMode) {
          print('   ✅ MATCH FOUND!');
        }
        return partner;
      }
    }
    
    return null;
  }

  /// 名前の類似度を計算（0.0～1.0）
  /// キーワードベースマッチング：「ROYAL」「FITNESS」「CAFE」などの重要キーワードで判定
  double _calculateNameSimilarity(String name1, String name2) {
    // スペース・記号を除去して正規化
    final normalized1 = _normalizeString(name1);
    final normalized2 = _normalizeString(name2);
    
    // 完全一致
    if (normalized1 == normalized2) {
      return 1.0;
    }
    
    // 部分一致（どちらかがもう一方を含む）
    if (normalized1.contains(normalized2) || normalized2.contains(normalized1)) {
      return 0.8;
    }
    
    // 重要キーワード抽出とマッチング
    final keywords1 = _extractKeywords(normalized1);
    final keywords2 = _extractKeywords(normalized2);
    
    if (keywords1.isEmpty || keywords2.isEmpty) {
      return 0.0;
    }
    
    int matchCount = 0;
    for (final kw1 in keywords1) {
      for (final kw2 in keywords2) {
        // キーワードの部分一致を許容（例: "royal" と "ロイヤル"）
        if (kw1.contains(kw2) || kw2.contains(kw1)) {
          matchCount++;
          break;
        }
        // カタカナ・英語の対応チェック
        if (_isKanaEnglishMatch(kw1, kw2)) {
          matchCount++;
          break;
        }
      }
    }
    
    final maxKeywords = keywords1.length > keywords2.length ? keywords1.length : keywords2.length;
    return maxKeywords > 0 ? matchCount / maxKeywords : 0.0;
  }
  
  /// キーワード抽出（3文字以上の意味のある単語）
  List<String> _extractKeywords(String normalized) {
    // 英数字とカナの連続をキーワードとして抽出
    final keywords = <String>[];
    final parts = normalized.split(RegExp(r'[^\w]+'));
    
    for (final part in parts) {
      if (part.length >= 3) {
        keywords.add(part);
      }
    }
    
    return keywords;
  }
  
  /// カタカナと英語の対応チェック（簡易版）
  bool _isKanaEnglishMatch(String kw1, String kw2) {
    // よくある対応パターン
    final Map<String, String> kanaEnglishMap = {
      'royal': 'ロイヤル',
      'fitness': 'フィットネス',
      'cafe': 'カフェ',
      'wash': 'ウォッシュ',
    };
    
    for (final entry in kanaEnglishMap.entries) {
      final eng = entry.key;
      final kana = entry.value.toLowerCase();
      
      if ((kw1.contains(eng) && kw2.contains(kana)) ||
          (kw2.contains(eng) && kw1.contains(kana))) {
        return true;
      }
    }
    
    return false;
  }

  /// 住所の類似度を計算（0.0～1.0）
  double _calculateAddressSimilarity(String address1, String address2) {
    // 正規化
    final normalized1 = _normalizeString(address1);
    final normalized2 = _normalizeString(address2);
    
    // 完全一致
    if (normalized1 == normalized2) {
      return 1.0;
    }
    
    // 都道府県・市区町村の一致チェック
    final prefectures = ['北海道', '青森', '岩手', '宮城', '秋田', '山形', '福島',
                         '茨城', '栃木', '群馬', '埼玉', '千葉', '東京', '神奈川',
                         '新潟', '富山', '石川', '福井', '山梨', '長野', '岐阜',
                         '静岡', '愛知', '三重', '滋賀', '京都', '大阪', '兵庫',
                         '奈良', '和歌山', '鳥取', '島根', '岡山', '広島', '山口',
                         '徳島', '香川', '愛媛', '高知', '福岡', '佐賀', '長崎',
                         '熊本', '大分', '宮崎', '鹿児島', '沖縄'];
    
    String? prefecture1;
    String? prefecture2;
    
    for (final pref in prefectures) {
      if (normalized1.contains(pref)) prefecture1 = pref;
      if (normalized2.contains(pref)) prefecture2 = pref;
    }
    
    // 都道府県が異なる場合は0
    if (prefecture1 != null && prefecture2 != null && prefecture1 != prefecture2) {
      return 0.0;
    }
    
    // 都道府県一致 = 基本スコア0.3
    double score = (prefecture1 != null && prefecture2 != null && prefecture1 == prefecture2) ? 0.3 : 0.0;
    
    // 主要都市名の一致チェック（佐賀市、久留米市、鳥栖市など）
    final cities = ['佐賀市', '久留米市', '鳥栖市', '福岡市', '大和町', '津福', '西新町', '鍋島', '緑小路'];
    for (final city in cities) {
      final cityNorm = _normalizeString(city);
      if (normalized1.contains(cityNorm) && normalized2.contains(cityNorm)) {
        score += 0.4;  // 市レベル一致で+0.4
        break;
      }
    }
    
    // 部分一致（どちらかが含まれる）
    if (normalized1.contains(normalized2) || normalized2.contains(normalized1)) {
      score = score > 0.5 ? score : 0.5;
    }
    
    return score > 1.0 ? 1.0 : score;
  }

  /// 市区町村名を抽出
  String _extractCityName(String address, String marker) {
    final index = address.indexOf(marker);
    if (index == -1) return '';
    
    // マーカーの前の最大10文字を取得
    final start = index - 10 > 0 ? index - 10 : 0;
    return address.substring(start, index + marker.length);
  }

  /// 文字列を正規化（スペース・記号除去、小文字化）
  String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_&・]'), '')
        .replaceAll('ー', '')
        .replaceAll('－', '');
  }

  /// Google PlaceリストにFirestoreパートナー情報をマージ
  /// 
  /// マッチしたジムには isPartner=true とパートナー情報が追加される
  Future<List<Gym>> mergePartnerData(List<GooglePlace> places) async {
    if (places.isEmpty) {
      return [];
    }
    
    if (kDebugMode) {
      print('🔄 Merging partner data for ${places.length} places...');
    }
    
    // Firestoreからパートナージム情報取得
    final partnerGyms = await _getPartnerGyms();
    
    if (partnerGyms.isEmpty) {
      if (kDebugMode) {
        print('ℹ️ No partner gyms found, returning Google Places data only');
      }
      // パートナージムがない場合は通常のGymオブジェクトに変換
      return places.map((place) => _convertGooglePlaceToGym(place, null)).toList();
    }
    
    // 各Google PlaceをGymオブジェクトに変換し、パートナー情報をマージ
    final gyms = <Gym>[];
    
    for (final place in places) {
      if (kDebugMode) {
        print('\n🔍 Processing: ${place.name}');
      }
      
      // 🔧 CRITICAL FIX: 2段階マッチング
      // 1. 完全ID一致チェック（混雑度報告済みジム用）
      Map<String, dynamic>? matchedData = _findExactIdMatch(place, partnerGyms);
      
      // 2. ID一致なし → パートナージムを名前・住所でマッチング
      if (matchedData == null) {
        matchedData = _findFuzzyPartnerMatch(place, partnerGyms);
      }
      
      if (matchedData != null) {
        if (kDebugMode) {
          final isPartner = matchedData['isPartner'] == true;
          if (isPartner) {
            print('   🏆 Matched with partner: ${matchedData['name']}');
          } else {
            print('   📊 Matched with crowd-reported gym: ${matchedData['id']}');
          }
        }
      }
      
      // Google PlaceをGymに変換（マッチしたデータがあればマージ）
      final gym = _convertGooglePlaceToGym(place, matchedData);
      gyms.add(gym);
    }
    
    if (kDebugMode) {
      final partnerCount = gyms.where((g) => g.isPartner).length;
      print('\n✅ Merge complete: ${gyms.length} gyms (${partnerCount} partners)');
    }
    
    return gyms;
  }
  
  /// GooglePlaceをGymオブジェクトに変換（パートナー情報をマージ）
  Gym _convertGooglePlaceToGym(GooglePlace place, Map<String, dynamic>? partnerData) {
    // 🔧 CRITICAL FIX: Firestoreの実際のisPartnerフィールドの値を使用
    // partnerDataが存在するだけでisPartner=trueにしない
    final isPartner = partnerData?['isPartner'] as bool? ?? false;
    
    return Gym(
      id: partnerData?['id'] as String? ?? place.placeId,
      gymId: partnerData?['gymId'] as String? ?? partnerData?['id'] as String?,
      name: partnerData?['name'] as String? ?? place.name,
      address: partnerData?['address'] as String? ?? place.address,
      latitude: (partnerData?['lat'] as num?)?.toDouble() ?? (partnerData?['latitude'] as num?)?.toDouble() ?? place.latitude,
      longitude: (partnerData?['lng'] as num?)?.toDouble() ?? (partnerData?['longitude'] as num?)?.toDouble() ?? place.longitude,
      phoneNumber: partnerData?['phoneNumber'] as String? ?? '',
      description: partnerData?['description'] as String? ?? '',
      facilities: partnerData?['facilities'] != null 
          ? List<String>.from(partnerData!['facilities'] as List)
          : [],
      openingHours: place.openNow == true ? '営業中' : place.openNow == false ? '営業時間外' : '営業時間不明',
      monthlyFee: (partnerData?['monthlyFee'] as num?)?.toDouble() ?? 0.0,
      rating: place.rating ?? 0.0,
      reviewCount: place.userRatingsTotal ?? 0,
      imageUrl: place.photoReference != null 
          ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${place.photoReference}&key=AIzaSyBRJG8v0euVbxbMNbwXownQJA3_Ra8EzMM'
          : partnerData?['imageUrl'] as String? ?? 'https://via.placeholder.com/400x300?text=No+Image',
      createdAt: partnerData?['createdAt'] != null 
          ? (partnerData!['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: partnerData?['updatedAt'] != null 
          ? (partnerData!['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      // 💡 混雑度優先順位: ユーザー報告 > Google推定値
      currentCrowdLevel: partnerData?['currentCrowdLevel'] as int? ?? place.estimatedCrowdLevel ?? 3,
      lastCrowdUpdate: partnerData?['lastCrowdUpdate'] != null 
          ? (partnerData!['lastCrowdUpdate'] as Timestamp?)?.toDate()
          : (place.estimatedCrowdLevel != null ? DateTime.now() : null),
      isPartner: isPartner,
      // 🔧 CRITICAL FIX: パートナー関連フィールドはisPartner=trueの場合のみ設定
      partnerBenefit: isPartner && partnerData != null ? partnerData['partnerBenefit'] as String? : null,
      partnerSince: isPartner && partnerData != null && partnerData['partnerSince'] != null 
          ? (partnerData['partnerSince'] as Timestamp?)?.toDate()
          : null,
      campaignTitle: isPartner && partnerData != null ? partnerData['campaignTitle'] as String? : null,
      campaignDescription: isPartner && partnerData != null ? partnerData['campaignDescription'] as String? : null,
      campaignValidUntil: isPartner && partnerData != null && partnerData['campaignValidUntil'] != null 
          ? (partnerData['campaignValidUntil'] as Timestamp?)?.toDate()
          : null,
      campaignCouponCode: isPartner && partnerData != null ? partnerData['campaignCouponCode'] as String? : null,
      campaignBannerUrl: isPartner && partnerData != null ? partnerData['campaignBannerUrl'] as String? : null,
      photos: partnerData?['photos'] != null 
          ? List<String>.from(partnerData!['photos'] as List)
          : null,
      acceptsVisitors: isPartner && partnerData != null ? (partnerData['acceptsVisitors'] as bool? ?? false) : false,
      reservationEmail: isPartner && partnerData != null ? partnerData['reservationEmail'] as String? : null,
      equipment: isPartner && partnerData != null && partnerData['equipment'] != null 
          ? (partnerData['equipment'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, (value as num).toInt()),
            )
          : null,
    );
  }

  /// キャッシュをクリア（テスト用）
  void clearCache() {
    _partnerGymsCache = null;
    _cacheTime = null;
    if (kDebugMode) {
      print('🗑️ Partner gym cache cleared');
    }
  }
}
