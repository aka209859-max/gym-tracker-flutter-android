/// パートナープロフィールモデル
/// 
/// Pro プランユーザーのトレーニングパートナー検索用プロフィール
/// Firestore collection: partner_profiles
class PartnerProfile {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final int age;
  final String gender; // 'male', 'female', 'other', 'not_specified'
  
  // トレーニング情報
  final List<String> trainingGoals; // 'muscle_gain', 'weight_loss', 'endurance', 'flexibility'
  final String experienceLevel; // 'beginner', 'intermediate', 'advanced', 'expert'
  final List<String> preferredExercises; // 'chest', 'back', 'legs', 'shoulders', 'arms'
  final List<String> availableDays; // 'monday', 'tuesday', 'wednesday', ...
  final List<String> availableTimeSlots; // 'morning', 'afternoon', 'evening', 'night'
  
  // 位置情報
  final double? latitude;
  final double? longitude;
  final String? preferredLocation;
  final double searchRadiusKm;
  
  // マッチング設定
  final bool isVisible; // プロフィールを公開するか
  final List<String> preferredGenders; // マッチング希望の性別
  final int? minAge;
  final int? maxAge;
  
  // メタデータ
  final DateTime createdAt;
  final DateTime updatedAt;
  final int matchCount; // マッチング回数
  final double rating; // レーティング (0-5)
  
  // ✅ 実力ベースマッチング（±15% 1RM）
  final double? average1RM; // BIG3の平均1RM（kg）
  final DateTime? average1RMUpdatedAt; // 最終更新日時
  
  // ✅ 時空間コンテキストマッチング
  final String? mostFrequentGymId; // 最もよく通うジムID
  final List<int>? preferredHours; // よく行く時間帯（0-23）
  final DateTime? spatiotemporalUpdatedAt; // 最終更新日時

  PartnerProfile({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    this.bio,
    required this.age,
    required this.gender,
    required this.trainingGoals,
    required this.experienceLevel,
    required this.preferredExercises,
    required this.availableDays,
    required this.availableTimeSlots,
    this.latitude,
    this.longitude,
    this.preferredLocation,
    this.searchRadiusKm = 10.0,
    this.isVisible = true,
    required this.preferredGenders,
    this.minAge,
    this.maxAge,
    required this.createdAt,
    required this.updatedAt,
    this.matchCount = 0,
    this.rating = 0.0,
    this.average1RM,
    this.average1RMUpdatedAt,
    this.mostFrequentGymId,
    this.preferredHours,
    this.spatiotemporalUpdatedAt,
  });

  /// Firestore からのデータ読み込み
  factory PartnerProfile.fromFirestore(Map<String, dynamic> data, String userId) {
    return PartnerProfile(
      userId: userId,
      displayName: data['display_name'] as String? ?? 'Unknown User',
      photoUrl: data['photo_url'] as String?,
      bio: data['bio'] as String?,
      age: data['age'] as int? ?? 0,
      gender: data['gender'] as String? ?? 'not_specified',
      trainingGoals: List<String>.from(data['training_goals'] ?? []),
      experienceLevel: data['experience_level'] as String? ?? 'beginner',
      preferredExercises: List<String>.from(data['preferred_exercises'] ?? []),
      availableDays: List<String>.from(data['available_days'] ?? []),
      availableTimeSlots: List<String>.from(data['available_time_slots'] ?? []),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      preferredLocation: data['preferred_location'] as String?,
      searchRadiusKm: (data['search_radius_km'] as num?)?.toDouble() ?? 10.0,
      isVisible: data['is_visible'] as bool? ?? true,
      preferredGenders: List<String>.from(data['preferred_genders'] ?? ['male', 'female', 'other']),
      minAge: data['min_age'] as int?,
      maxAge: data['max_age'] as int?,
      createdAt: DateTime.parse(data['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(data['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      matchCount: data['match_count'] as int? ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      average1RM: (data['average_1rm'] as num?)?.toDouble(),
      average1RMUpdatedAt: data['average_1rm_updated_at'] != null
          ? DateTime.parse(data['average_1rm_updated_at'] as String)
          : null,
      mostFrequentGymId: data['most_frequent_gym_id'] as String?,
      preferredHours: (data['preferred_hours'] as List<dynamic>?)
          ?.map((h) => h as int)
          .toList(),
      spatiotemporalUpdatedAt: data['spatiotemporal_updated_at'] != null
          ? DateTime.parse(data['spatiotemporal_updated_at'] as String)
          : null,
    );
  }

  /// Firestore への保存用データ変換
  Map<String, dynamic> toFirestore() {
    return {
      'display_name': displayName,
      'photo_url': photoUrl,
      'bio': bio,
      'age': age,
      'gender': gender,
      'training_goals': trainingGoals,
      'experience_level': experienceLevel,
      'preferred_exercises': preferredExercises,
      'available_days': availableDays,
      'available_time_slots': availableTimeSlots,
      'latitude': latitude,
      'longitude': longitude,
      'preferred_location': preferredLocation,
      'search_radius_km': searchRadiusKm,
      'is_visible': isVisible,
      'preferred_genders': preferredGenders,
      'min_age': minAge,
      'max_age': maxAge,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'match_count': matchCount,
      'rating': rating,
      'average_1rm': average1RM,
      'average_1rm_updated_at': average1RMUpdatedAt?.toIso8601String(),
      'most_frequent_gym_id': mostFrequentGymId,
      'preferred_hours': preferredHours,
      'spatiotemporal_updated_at': spatiotemporalUpdatedAt?.toIso8601String(),
    };
  }

  /// コピーメソッド
  PartnerProfile copyWith({
    String? displayName,
    String? photoUrl,
    String? bio,
    int? age,
    String? gender,
    List<String>? trainingGoals,
    String? experienceLevel,
    List<String>? preferredExercises,
    List<String>? availableDays,
    List<String>? availableTimeSlots,
    double? latitude,
    double? longitude,
    String? preferredLocation,
    double? searchRadiusKm,
    bool? isVisible,
    List<String>? preferredGenders,
    int? minAge,
    int? maxAge,
    DateTime? updatedAt,
    int? matchCount,
    double? rating,
    double? average1RM,
    DateTime? average1RMUpdatedAt,
    String? mostFrequentGymId,
    List<int>? preferredHours,
    DateTime? spatiotemporalUpdatedAt,
  }) {
    return PartnerProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      trainingGoals: trainingGoals ?? this.trainingGoals,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      preferredExercises: preferredExercises ?? this.preferredExercises,
      availableDays: availableDays ?? this.availableDays,
      availableTimeSlots: availableTimeSlots ?? this.availableTimeSlots,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      preferredLocation: preferredLocation ?? this.preferredLocation,
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
      isVisible: isVisible ?? this.isVisible,
      preferredGenders: preferredGenders ?? this.preferredGenders,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      matchCount: matchCount ?? this.matchCount,
      rating: rating ?? this.rating,
      average1RM: average1RM ?? this.average1RM,
      average1RMUpdatedAt: average1RMUpdatedAt ?? this.average1RMUpdatedAt,
      mostFrequentGymId: mostFrequentGymId ?? this.mostFrequentGymId,
      preferredHours: preferredHours ?? this.preferredHours,
      spatiotemporalUpdatedAt: spatiotemporalUpdatedAt ?? this.spatiotemporalUpdatedAt,
    );
  }
}

/// パートナーマッチングモデル
/// Firestore collection: partner_matches
class PartnerMatch {
  final String matchId;
  final String requesterId; // マッチングリクエスト送信者
  final String targetId; // マッチング対象者
  final String status; // 'pending', 'accepted', 'declined', 'expired'
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? message; // リクエストメッセージ

  PartnerMatch({
    required this.matchId,
    required this.requesterId,
    required this.targetId,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.message,
  });

  factory PartnerMatch.fromFirestore(Map<String, dynamic> data, String matchId) {
    return PartnerMatch(
      matchId: matchId,
      requesterId: data['requester_id'] as String,
      targetId: data['target_id'] as String,
      status: data['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(data['created_at'] as String),
      respondedAt: data['responded_at'] != null 
          ? DateTime.parse(data['responded_at'] as String)
          : null,
      message: data['message'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requester_id': requesterId,
      'target_id': targetId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'message': message,
    };
  }
}
