import 'package:cloud_firestore/cloud_firestore.dart';

/// ジム施設のデータモデル
class Gym {
  final String id;              // Firestore Document ID
  final String? gymId;          // カスタムジムID (gym_announcementsとの紐付け用)
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String description;
  final List<String> facilities;
  final String phoneNumber;
  final String openingHours;
  final double monthlyFee;
  final double rating;
  final int reviewCount;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // リアルタイム混雑度 (1-5: 1=空いてる, 5=超混雑)
  int currentCrowdLevel;
  DateTime? lastCrowdUpdate;

  // パートナー機能
  final bool isPartner;            // β版パートナーかどうか
  final String? partnerBenefit;    // パートナー特典テキスト（例: 入会金50%OFF）
  final DateTime? partnerSince;    // パートナー開始日
  
  // キャンペーン情報 (オーナーが自由編集)
  final String? campaignTitle;       // キャンペーンタイトル
  final String? campaignDescription; // キャンペーン詳細
  final DateTime? campaignValidUntil; // キャンペーン期限
  final String? campaignCouponCode;  // クーポンコード
  final String? campaignBannerUrl;   // キャンペーンバナー画像URL
  final List<String>? photos;        // 店舗画像リスト (オーナーがアップロード)

  // 予約機能
  final bool acceptsVisitors;        // ビジター利用可能フラグ
  final String? reservationEmail;    // 予約通知先メールアドレス（複数店舗対応）

  // マシン・設備情報（オーナーが編集）
  final Map<String, int>? equipment; // マシン種類と台数 (例: {AppLocalizations.of(context)!.exerciseLegPress: 2, AppLocalizations.of(context)!.gym_8b54efdd: 1})

  Gym({
    required this.id,
    this.gymId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.description = '',
    this.facilities = const [],
    this.phoneNumber = '',
    this.openingHours = '',
    this.monthlyFee = 0.0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.imageUrl = '',
    required this.createdAt,
    required this.updatedAt,
    this.currentCrowdLevel = 3,
    this.lastCrowdUpdate,
    this.isPartner = false,
    this.partnerBenefit,
    this.partnerSince,
    this.campaignTitle,
    this.campaignDescription,
    this.campaignValidUntil,
    this.campaignCouponCode,
    this.campaignBannerUrl,
    this.photos,
    this.acceptsVisitors = false,
    this.reservationEmail,
    this.equipment,
  });

  /// Firestoreからジムデータを生成
  factory Gym.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Gym(
      id: doc.id,
      gymId: data['gymId'] ?? data['gym_id'] ?? doc.id,  // gymId優先、なければdoc.id
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      facilities: List<String>.from(data['facilities'] ?? []),
      phoneNumber: data['phoneNumber'] ?? '',
      openingHours: data['openingHours'] ?? '',
      monthlyFee: (data['monthlyFee'] ?? 0).toDouble(),
      rating: (data['rating'] ?? 0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      imageUrl: data['imageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentCrowdLevel: data['currentCrowdLevel'] ?? 3,
      lastCrowdUpdate: (data['lastCrowdUpdate'] as Timestamp?)?.toDate(),
      isPartner: data['isPartner'] ?? false,
      partnerBenefit: data['partnerBenefit'],
      partnerSince: (data['partnerSince'] as Timestamp?)?.toDate(),
      campaignTitle: data['campaignTitle'],
      campaignDescription: data['campaignDescription'],
      campaignValidUntil: (data['campaignValidUntil'] as Timestamp?)?.toDate(),
      campaignCouponCode: data['campaignCouponCode'],
      campaignBannerUrl: data['campaignBannerUrl'],
      photos: data['photos'] != null ? List<String>.from(data['photos']) : null,
      acceptsVisitors: data['acceptsVisitors'] ?? false,
      reservationEmail: data['reservationEmail'],
      equipment: data['equipment'] != null 
          ? Map<String, int>.from(data['equipment']) 
          : null,
    );
  }

  /// Firestore用にマップ形式に変換
  Map<String, dynamic> toMap() {
    return {
      'gymId': gymId,
      'name': name,
      'address': address,
      'lat': latitude,
      'lng': longitude,
      'description': description,
      'facilities': facilities,
      'phoneNumber': phoneNumber,
      'openingHours': openingHours,
      'monthlyFee': monthlyFee,
      'rating': rating,
      'reviewCount': reviewCount,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'currentCrowdLevel': currentCrowdLevel,
      'lastCrowdUpdate': lastCrowdUpdate != null 
          ? Timestamp.fromDate(lastCrowdUpdate!) 
          : null,
      'isPartner': isPartner,
      'partnerBenefit': partnerBenefit,
      'partnerSince': partnerSince != null
          ? Timestamp.fromDate(partnerSince!)
          : null,
      'campaignTitle': campaignTitle,
      'campaignDescription': campaignDescription,
      'campaignValidUntil': campaignValidUntil != null
          ? Timestamp.fromDate(campaignValidUntil!)
          : null,
      'campaignCouponCode': campaignCouponCode,
      'campaignBannerUrl': campaignBannerUrl,
      'photos': photos,
      'acceptsVisitors': acceptsVisitors,
      'reservationEmail': reservationEmail,
      'equipment': equipment,
    };
  }

  /// 混雑度の日本語表示
  String get crowdLevelText {
    switch (currentCrowdLevel) {
      case 1:
        return AppLocalizations.of(context)!.gym_e662330d;
      case 2:
        return AppLocalizations.of(context)!.moderatelyEmpty;
      case 3:
        return AppLocalizations.of(context)!.intensityModerate;
      case 4:
        return AppLocalizations.of(context)!.moderatelyCrowded;
      case 5:
        return AppLocalizations.of(context)!.gym_181af51b;
      default:
        return AppLocalizations.of(context)!.unknown;
    }
  }

  /// 混雑度の色コード (Material Design)
  int get crowdLevelColor {
    switch (currentCrowdLevel) {
      case 1:
        return 0xFF4CAF50; // Green
      case 2:
        return 0xFF8BC34A; // Light Green
      case 3:
        return 0xFFFFC107; // Amber
      case 4:
        return 0xFFFF9800; // Orange
      case 5:
        return 0xFFF44336; // Red
      default:
        return 0xFF9E9E9E; // Grey
    }
  }
}
