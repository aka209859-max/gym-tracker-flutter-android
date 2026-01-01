import 'package:cloud_firestore/cloud_firestore.dart';

/// バッジのカテゴリー
enum BadgeCategory {
  streak,      // 継続日数
  totalWeight, // 総重量
  prCount,     // PR達成回数
}

/// 達成バッジモデル
class Achievement {
  final String id;
  final String userId;
  final BadgeCategory category;
  final String title;
  final String description;
  final String iconName;
  final int threshold; // 達成に必要な値
  final bool isUnlocked;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.description,
    required this.iconName,
    required this.threshold,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  /// Firestoreドキュメントから変換
  factory Achievement.fromFirestore(Map<String, dynamic> data, String docId) {
    return Achievement(
      id: docId,
      userId: data['user_id'] as String? ?? '',
      category: _categoryFromString(data['category'] as String? ?? 'streak'),
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      iconName: data['icon_name'] as String? ?? 'star',
      threshold: data['threshold'] as int? ?? 0,
      isUnlocked: data['is_unlocked'] as bool? ?? false,
      unlockedAt: (data['unlocked_at'] as Timestamp?)?.toDate(),
    );
  }

  /// Firestoreドキュメントに変換
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'category': category.name,
      'title': title,
      'description': description,
      'icon_name': iconName,
      'threshold': threshold,
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt != null ? Timestamp.fromDate(unlockedAt!) : null,
    };
  }

  /// 文字列からカテゴリーに変換
  static BadgeCategory _categoryFromString(String value) {
    switch (value) {
      case 'streak':
        return BadgeCategory.streak;
      case 'totalWeight':
        return BadgeCategory.totalWeight;
      case 'prCount':
        return BadgeCategory.prCount;
      default:
        return BadgeCategory.streak;
    }
  }

  /// バッジのコピーを作成
  Achievement copyWith({
    String? id,
    String? userId,
    BadgeCategory? category,
    String? title,
    String? description,
    String? iconName,
    int? threshold,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      threshold: threshold ?? this.threshold,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

/// 定義済みバッジリスト
class PredefinedBadges {
  /// 継続日数バッジ
  static List<Map<String, dynamic>> streakBadges = [
    {
      'category': 'streak',
      'title': AppLocalizations.of(context)!.general_0e1dfb49,
      'description': AppLocalizations.of(context)!.general_7918b385,
      'icon_name': 'directions_run',
      'threshold': 3,
    },
    {
      'category': 'streak',
      'title': AppLocalizations.of(context)!.general_33726008,
      'description': AppLocalizations.of(context)!.general_c1afadf1,
      'icon_name': 'military_tech',
      'threshold': 7,
    },
    {
      'category': 'streak',
      'title': AppLocalizations.of(context)!.general_30670083,
      'description': AppLocalizations.of(context)!.general_fb30b296,
      'icon_name': 'emoji_events',
      'threshold': 30,
    },
    {
      'category': 'streak',
      'title': AppLocalizations.of(context)!.general_60dd6506,
      'description': AppLocalizations.of(context)!.general_eb76fad2,
      'icon_name': 'workspace_premium',
      'threshold': 100,
    },
  ];

  /// 総重量バッジ
  static List<Map<String, dynamic>> totalWeightBadges = [
    {
      'category': 'totalWeight',
      'title': AppLocalizations.of(context)!.general_2be03497,
      'description': AppLocalizations.of(context)!.general_1df69d21,
      'icon_name': 'fitness_center',
      'threshold': 1000,
    },
    {
      'category': 'totalWeight',
      'title': AppLocalizations.of(context)!.general_d88f8ae1,
      'description': AppLocalizations.of(context)!.general_a5ea4432,
      'icon_name': 'sports_gymnastics',
      'threshold': 5000,
    },
    {
      'category': 'totalWeight',
      'title': AppLocalizations.of(context)!.general_4a2af6c0,
      'description': AppLocalizations.of(context)!.general_884be91b,
      'icon_name': 'sports_martial_arts',
      'threshold': 10000,
    },
    {
      'category': 'totalWeight',
      'title': AppLocalizations.of(context)!.general_c4181a9f,
      'description': AppLocalizations.of(context)!.general_a694f96e,
      'icon_name': 'star',
      'threshold': 50000,
    },
  ];

  /// PR達成回数バッジ
  static List<Map<String, dynamic>> prCountBadges = [
    {
      'category': 'prCount',
      'title': AppLocalizations.of(context)!.general_f29a491c,
      'description': AppLocalizations.of(context)!.general_f41f8cd7,
      'icon_name': 'celebration',
      'threshold': 1,
    },
    {
      'category': 'prCount',
      'title': AppLocalizations.of(context)!.general_57c5777e,
      'description': AppLocalizations.of(context)!.general_1170680c,
      'icon_name': 'trending_up',
      'threshold': 10,
    },
    {
      'category': 'prCount',
      'title': AppLocalizations.of(context)!.general_cd728982,
      'description': AppLocalizations.of(context)!.general_dc26fbc6,
      'icon_name': 'auto_awesome',
      'threshold': 50,
    },
    {
      'category': 'prCount',
      'title': AppLocalizations.of(context)!.general_3f5d6c23,
      'description': AppLocalizations.of(context)!.general_f11516f0,
      'icon_name': 'diamond',
      'threshold': 100,
    },
  ];

  /// すべてのバッジを取得
  static List<Map<String, dynamic>> getAllBadges() {
    return [
      ...streakBadges,
      ...totalWeightBadges,
      ...prCountBadges,
    ];
  }
}
