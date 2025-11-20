/// Google Places APIから取得したジム情報のモデル
class GooglePlace {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double? rating;
  final int? userRatingsTotal;
  final String? photoReference;
  final bool? openNow;
  final int? priceLevel;
  final List<String> types;
  
  /// 推定混雑度（1-5: Google Places APIデータから算出）
  /// null = データ不足で推定不可
  final int? estimatedCrowdLevel;

  GooglePlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.userRatingsTotal,
    this.photoReference,
    this.openNow,
    this.priceLevel,
    this.types = const [],
    this.estimatedCrowdLevel,
  });

  /// Google Places API JSONから変換
  factory GooglePlace.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    
    // 写真参照IDを取得
    String? photoRef;
    final photos = json['photos'] as List<dynamic>?;
    if (photos != null && photos.isNotEmpty) {
      photoRef = photos[0]['photo_reference'] as String?;
    }

    final rating = (json['rating'] as num?)?.toDouble();
    final userRatingsTotal = json['user_ratings_total'] as int?;
    final openNow = json['opening_hours']?['open_now'] as bool?;
    
    // 混雑度を推定（評価・レビュー数・営業状態から算出）
    final estimatedCrowdLevel = _estimateCrowdLevel(
      rating: rating,
      userRatingsTotal: userRatingsTotal,
      openNow: openNow,
    );
    
    return GooglePlace(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      address: json['vicinity'] as String? ?? json['formatted_address'] as String? ?? '',
      latitude: location?['lat'] as double? ?? 0.0,
      longitude: location?['lng'] as double? ?? 0.0,
      rating: rating,
      userRatingsTotal: userRatingsTotal,
      photoReference: photoRef,
      openNow: openNow,
      priceLevel: json['price_level'] as int?,
      types: (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      estimatedCrowdLevel: estimatedCrowdLevel,
    );
  }

  /// Google Places APIデータから混雑度を推定
  /// 
  /// アルゴリズム:
  /// - 評価が高い（4.0以上）+ レビュー多い（50+）→ 人気店 → 混雑しやすい
  /// - 営業中 + 現在時刻（平日夕方18-21時、土日10-18時）→ 混雑時間帯
  /// - 評価が低い or レビュー少ない → 空いている可能性
  static int? _estimateCrowdLevel({
    required double? rating,
    required int? userRatingsTotal,
    required bool? openNow,
  }) {
    // データ不足の場合は推定不可
    if (rating == null || userRatingsTotal == null) {
      return null;
    }
    
    // 営業時間外は混雑度0（空き）
    if (openNow == false) {
      return 1; // 営業時間外 = 空いている
    }
    
    // 現在時刻を取得（混雑時間帯判定用）
    final now = DateTime.now();
    final hour = now.hour;
    final isWeekend = now.weekday >= 6; // 土日
    
    // 混雑時間帯かどうか判定
    bool isPeakTime = false;
    if (isWeekend && hour >= 10 && hour <= 18) {
      isPeakTime = true; // 土日の昼間
    } else if (!isWeekend && hour >= 18 && hour <= 21) {
      isPeakTime = true; // 平日の夕方～夜
    }
    
    // スコアリング方式で混雑度を算出
    int crowdScore = 0;
    
    // 評価による加算（4.0以上は人気店）
    if (rating >= 4.5) {
      crowdScore += 3;
    } else if (rating >= 4.0) {
      crowdScore += 2;
    } else if (rating >= 3.5) {
      crowdScore += 1;
    }
    
    // レビュー数による加算（人気度）
    if (userRatingsTotal >= 100) {
      crowdScore += 3;
    } else if (userRatingsTotal >= 50) {
      crowdScore += 2;
    } else if (userRatingsTotal >= 20) {
      crowdScore += 1;
    }
    
    // ピークタイムによる加算
    if (isPeakTime) {
      crowdScore += 2;
    }
    
    // スコアを1-5レベルに変換
    if (crowdScore >= 7) {
      return 5; // 超混雑
    } else if (crowdScore >= 5) {
      return 4; // やや混雑
    } else if (crowdScore >= 3) {
      return 3; // 普通
    } else if (crowdScore >= 1) {
      return 2; // やや空き
    } else {
      return 1; // 空いている
    }
  }
  
  /// 既存のGymモデルに変換（互換性のため）
  Map<String, dynamic> toGymCompatible() {
    return {
      'id': placeId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating ?? 0.0,
      'reviewCount': userRatingsTotal ?? 0,
      'crowdLevel': estimatedCrowdLevel, // Google Places APIから推定
      'monthlyFee': null, // 推定値は表示しない（公式サイト確認を推奨）
      'facilities': [], // 推定値は表示しない（公式サイト確認を推奨）
      'phoneNumber': null, // Google Places API Details呼び出しが必要
      'openingHours': openNow == true ? '営業中' : openNow == false ? '営業時間外' : '営業時間不明',
      'imageUrl': photoReference != null 
          ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoReference&key=AIzaSyA9XmQSHA1llGg7gihqjmOOIaLA856fkLc'
          : 'https://via.placeholder.com/400x300?text=No+Image',
    };
  }
}
