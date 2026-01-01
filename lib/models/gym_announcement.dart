import 'package:cloud_firestore/cloud_firestore.dart';

/// ジムお知らせ・キャンペーン情報モデル
/// 
/// GYMMATCHManager側で写真やキャンペーン情報を入力後、
/// GYMMATCHアプリ側に反映される
class GymAnnouncement {
  final String id;
  final String gymId;              // 対象ジムID
  final String title;              // お知らせタイトル
  final String content;            // お知らせ本文
  final String? imageUrl;          // お知らせ画像URL
  final List<String>? imageUrls;   // 複数画像対応
  final AnnouncementType type;     // お知らせ種類
  final DateTime createdAt;        // 投稿日時
  final DateTime? validUntil;      // 有効期限
  final bool isActive;             // 表示中フラグ
  final String? couponCode;        // クーポンコード（キャンペーン用）
  final String? externalLink;      // 外部リンク（詳細ページなど）
  
  GymAnnouncement({
    required this.id,
    required this.gymId,
    required this.title,
    required this.content,
    this.imageUrl,
    this.imageUrls,
    required this.type,
    required this.createdAt,
    this.validUntil,
    this.isActive = true,
    this.couponCode,
    this.externalLink,
  });
  
  /// Firestoreから生成
  factory GymAnnouncement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GymAnnouncement(
      id: doc.id,
      gymId: data['gym_id'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['image_url'],
      imageUrls: data['image_urls'] != null 
          ? List<String>.from(data['image_urls']) 
          : null,
      type: AnnouncementType.values.firstWhere(
        (e) => e.toString() == 'AnnouncementType.${data['type']}',
        orElse: () => AnnouncementType.general,
      ),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      validUntil: (data['valid_until'] as Timestamp?)?.toDate(),
      isActive: data['is_active'] ?? true,
      couponCode: data['coupon_code'],
      externalLink: data['external_link'],
    );
  }
  
  /// Firestoreマップに変換
  Map<String, dynamic> toMap() {
    return {
      'gym_id': gymId,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'image_urls': imageUrls,
      'type': type.toString().split('.').last,
      'created_at': Timestamp.fromDate(createdAt),
      'valid_until': validUntil != null 
          ? Timestamp.fromDate(validUntil!) 
          : null,
      'is_active': isActive,
      'coupon_code': couponCode,
      'external_link': externalLink,
    };
  }
  
  /// 有効期限が切れているか
  bool get isExpired {
    if (validUntil == null) return false;
    return DateTime.now().isAfter(validUntil!);
  }
  
  /// 表示可能か（有効期限内 & アクティブ）
  bool get isDisplayable {
    return isActive && !isExpired;
  }
}

/// お知らせ種類
enum AnnouncementType {
  general,      // 一般お知らせ
  campaign,     // キャンペーン
  event,        // イベント
  maintenance,  // メンテナンス
  newEquipment, // 新規設備導入
  hours,        // 営業時間変更
}

/// お知らせ種類の日本語表示
extension AnnouncementTypeExtension on AnnouncementType {
  String get displayName {
    switch (this) {
      case AnnouncementType.general:
        return AppLocalizations.of(context)!.announcement;
      case AnnouncementType.campaign:
        return AppLocalizations.of(context)!.gym_275cef99;
      case AnnouncementType.event:
        return AppLocalizations.of(context)!.gym_a611a72b;
      case AnnouncementType.maintenance:
        return AppLocalizations.of(context)!.gym_2a5f33dd;
      case AnnouncementType.newEquipment:
        return AppLocalizations.of(context)!.gym_9246e93a;
      case AnnouncementType.hours:
        return AppLocalizations.of(context)!.hours;
    }
  }
  
  /// アイコン
  String get icon {
    switch (this) {
      case AnnouncementType.general:
        return '📢';
      case AnnouncementType.campaign:
        return '🎉';
      case AnnouncementType.event:
        return '🎪';
      case AnnouncementType.maintenance:
        return '🔧';
      case AnnouncementType.newEquipment:
        return '✨';
      case AnnouncementType.hours:
        return '🕐';
    }
  }
}
