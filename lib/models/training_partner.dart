import 'package:cloud_firestore/cloud_firestore.dart';

/// トレーニングパートナーモデル
class TrainingPartner {
  final String userId;
  final String displayName;
  final String? profileImageUrl;
  final String? bio;
  final String? location;
  final String? experienceLevel;
  final List<String> goals;
  final List<String> preferredExercises;
  final DateTime createdAt;
  final DateTime updatedAt;

  TrainingPartner({
    required this.userId,
    required this.displayName,
    this.profileImageUrl,
    this.bio,
    this.location,
    this.experienceLevel,
    this.goals = const [],
    this.preferredExercises = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestoreから取得
  factory TrainingPartner.fromFirestore(Map<String, dynamic> data) {
    return TrainingPartner(
      userId: data['user_id']?.toString() ?? '',
      displayName: data['display_name']?.toString() ?? AppLocalizations.of(context)!.general_5b6bca48,
      profileImageUrl: data['profile_image_url']?.toString(),
      bio: data['bio']?.toString(),
      location: data['location']?.toString(),
      experienceLevel: data['experience_level']?.toString(),
      goals: data['goals'] != null ? List<String>.from(data['goals']) : [],
      preferredExercises: data['preferred_exercises'] != null ? List<String>.from(data['preferred_exercises']) : [],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Firestoreへ保存
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'profile_image_url': profileImageUrl,
      'bio': bio,
      'location': location,
      'experience_level': experienceLevel,
      'goals': goals,
      'preferred_exercises': preferredExercises,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  /// コピー
  TrainingPartner copyWith({
    String? userId,
    String? displayName,
    String? profileImageUrl,
    String? bio,
    String? location,
    String? experienceLevel,
    List<String>? goals,
    List<String>? preferredExercises,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainingPartner(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      goals: goals ?? this.goals,
      preferredExercises: preferredExercises ?? this.preferredExercises,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
