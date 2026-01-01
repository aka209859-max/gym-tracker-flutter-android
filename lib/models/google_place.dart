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
  /// 📊 推定アルゴリズムの根拠とソース:
  /// 
  /// 1. ピークタイム判定（統計データベース）:
  ///    ソース: 国立体育・スポーツ大学論文 (NIFS)
  ///    - 平日: 18-21時に2つのピーク
  ///    - 土日: 10-15時に突出したピーク
  ///    URL: https://www.lib.nifs-k.ac.jp/wp-content/uploads/2023/01/38-1.pdf
  /// 
  ///    国際データ (PerfectGym, WOD Guru):
  ///    - 平日: 5-7 PM (17-19時) が最混雑 (41% of all workouts)
  ///    - 週末: 10 AM - 3 PM がピーク
  ///    URL: https://wod.guru/blog/busiest-gym-times/
  /// 
  /// 2. 人気度指標（評価 + レビュー数）:
  ///    - 高評価ジム (4.5+) + レビュー多 (100+) → 人気店 → 混雑しやすい
  ///    - 低評価 or レビュー少 → 利用者少 → 空きやすい
  /// 
  /// 3. 営業時間外判定:
  ///    - open_now = false → 確実に空き（レベル1）
  /// 
  /// 📝 注意: これは統計的推定であり、実際の混雑度と異なる場合があります。
  /// ユーザー報告が最も信頼性が高いデータです。
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
    
    // 📊 業界データに基づくピークタイム判定
    // ソース: NIFS論文 + PerfectGym/WOD Guru統計
    bool isPeakTime = false;
    if (isWeekend) {
      // 土日: 10:00-15:00 がピーク (国際データ + 国内データ一致)
      if (hour >= 10 && hour <= 15) {
        isPeakTime = true;
      }
    } else {
      // 平日: 18:00-21:00 がピーク (仕事後のトレーニング)
      // ソース: NIFS「18-21時に2つのピーク」
      if (hour >= 18 && hour <= 21) {
        isPeakTime = true;
      }
      // 準ピーク: 7:00-9:00 (朝トレ)
      // ソース: 国際データ "7AM-9AM: 41% of workouts"
      else if (hour >= 7 && hour <= 9) {
        isPeakTime = true; // 準ピーク時間帯
      }
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
  
  /// JSON形式に変換（Hiveキャッシュ用）
  Map<String, dynamic> toJson() {
    return {
      'place_id': placeId,
      'name': name,
      'vicinity': address,
      'geometry': {
        'location': {
          'lat': latitude,
          'lng': longitude,
        },
      },
      'rating': rating,
      'user_ratings_total': userRatingsTotal,
      'photos': photoReference != null 
          ? [{'photo_reference': photoReference}] 
          : null,
      'opening_hours': openNow != null 
          ? {'open_now': openNow} 
          : null,
      'price_level': priceLevel,
      'types': types,
    };
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
      'openingHours': openNow == true ? AppLocalizations.of(context)!.open : openNow == false ? AppLocalizations.of(context)!.general_a2082b23 : AppLocalizations.of(context)!.general_88133d74,
      'imageUrl': photoReference != null 
          ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoReference&key=AIzaSyBRJG8v0euVbxbMNbwXownQJA3_Ra8EzMM'
          : 'https://via.placeholder.com/400x300?text=No+Image',
    };
  }
}
