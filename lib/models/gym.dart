import 'package:cloud_firestore/cloud_firestore.dart';

/// ジム施設のデータモデル
class Gym {
  final String id;
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

  Gym({
    required this.id,
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
  });

  /// Firestoreからジムデータを生成
  factory Gym.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Gym(
      id: doc.id,
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
    );
  }

  /// Firestore用にマップ形式に変換
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
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
    };
  }

  /// 混雑度の日本語表示
  String get crowdLevelText {
    switch (currentCrowdLevel) {
      case 1:
        return '空いています';
      case 2:
        return 'やや空き';
      case 3:
        return '普通';
      case 4:
        return 'やや混雑';
      case 5:
        return '超混雑';
      default:
        return '不明';
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
