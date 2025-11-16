/// Phase 2b: ユーザープロファイルモデル
/// Personal Factor Multipliersの計算に使用
class UserProfile {
  // 静的要因 (Static Factors)
  final int age; // 年齢
  final int trainingExperienceYears; // トレーニング経験年数
  
  // 動的要因 (Dynamic Factors)
  final double sleepHoursLastNight; // 昨夜の睡眠時間
  final double dailyProteinIntakeGrams; // 1日のタンパク質摂取量 (g)
  final int alcoholUnitsLastDay; // 前日のアルコール摂取量 (標準単位)
  
  // メタデータ
  final DateTime lastUpdated;

  UserProfile({
    required this.age,
    required this.trainingExperienceYears,
    required this.sleepHoursLastNight,
    required this.dailyProteinIntakeGrams,
    required this.alcoholUnitsLastDay,
    required this.lastUpdated,
  });

  /// デフォルトプロファイル（初回ユーザー用）
  factory UserProfile.defaultProfile() {
    return UserProfile(
      age: 30,
      trainingExperienceYears: 1,
      sleepHoursLastNight: 7.0,
      dailyProteinIntakeGrams: 100.0,
      alcoholUnitsLastDay: 0,
      lastUpdated: DateTime.now(),
    );
  }

  /// JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'training_experience_years': trainingExperienceYears,
      'sleep_hours_last_night': sleepHoursLastNight,
      'daily_protein_intake_grams': dailyProteinIntakeGrams,
      'alcohol_units_last_day': alcoholUnitsLastDay,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  /// JSON deserialization
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      age: json['age'] as int? ?? 30,
      trainingExperienceYears: json['training_experience_years'] as int? ?? 1,
      sleepHoursLastNight: (json['sleep_hours_last_night'] as num?)?.toDouble() ?? 7.0,
      dailyProteinIntakeGrams: (json['daily_protein_intake_grams'] as num?)?.toDouble() ?? 100.0,
      alcoholUnitsLastDay: json['alcohol_units_last_day'] as int? ?? 0,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : DateTime.now(),
    );
  }

  /// copyWith method
  UserProfile copyWith({
    int? age,
    int? trainingExperienceYears,
    double? sleepHoursLastNight,
    double? dailyProteinIntakeGrams,
    int? alcoholUnitsLastDay,
    DateTime? lastUpdated,
  }) {
    return UserProfile(
      age: age ?? this.age,
      trainingExperienceYears: trainingExperienceYears ?? this.trainingExperienceYears,
      sleepHoursLastNight: sleepHoursLastNight ?? this.sleepHoursLastNight,
      dailyProteinIntakeGrams: dailyProteinIntakeGrams ?? this.dailyProteinIntakeGrams,
      alcoholUnitsLastDay: alcoholUnitsLastDay ?? this.alcoholUnitsLastDay,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
