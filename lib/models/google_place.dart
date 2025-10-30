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

    return GooglePlace(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      address: json['vicinity'] as String? ?? json['formatted_address'] as String? ?? '',
      latitude: location?['lat'] as double? ?? 0.0,
      longitude: location?['lng'] as double? ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: json['user_ratings_total'] as int?,
      photoReference: photoRef,
      openNow: json['opening_hours']?['open_now'] as bool?,
      priceLevel: json['price_level'] as int?,
      types: (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  /// 既存のGymモデルに変換（互換性のため）
  /// 注意: 推定値は含めず、Google Places APIの確実なデータのみ使用
  Map<String, dynamic> toGymCompatible() {
    return {
      'id': placeId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating ?? 0.0,
      'reviewCount': userRatingsTotal ?? 0,
      'crowdLevel': null, // ユーザー投稿データのみ表示（現在は未実装）
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
