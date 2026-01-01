import 'package:cloud_firestore/cloud_firestore.dart';

/// キャンペーン申請モデル
/// 
/// ユーザーのキャンペーン申請状況を管理
class CampaignApplication {
  final String id;
  final String userId;
  final String planType; // 'premium' or 'pro'
  final String previousAppName; // 乗り換え前アプリ名
  final String uniqueCode; // ユニークコード（例: #GM2025A3B7C）
  final CampaignStatus status;
  final DateTime createdAt;
  final DateTime? snsPostedAt; // SNS投稿日時
  final String? snsPostUrl; // SNS投稿URL（オプション）
  final DateTime? verifiedAt; // 確認完了日時
  final DateTime? benefitAppliedAt; // 特典適用日時
  final String? rejectionReason; // 却下理由

  CampaignApplication({
    required this.id,
    required this.userId,
    required this.planType,
    required this.previousAppName,
    required this.uniqueCode,
    required this.status,
    required this.createdAt,
    this.snsPostedAt,
    this.snsPostUrl,
    this.verifiedAt,
    this.benefitAppliedAt,
    this.rejectionReason,
  });

  /// Firestoreから読み込み
  factory CampaignApplication.fromFirestore(Map<String, dynamic> data, String id) {
    return CampaignApplication(
      id: id,
      userId: data['user_id'] as String,
      planType: data['plan_type'] as String,
      previousAppName: data['previous_app_name'] as String,
      uniqueCode: data['unique_code'] as String,
      status: CampaignStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CampaignStatus.pending,
      ),
      createdAt: (data['created_at'] as Timestamp).toDate(),
      snsPostedAt: data['sns_posted_at'] != null
          ? (data['sns_posted_at'] as Timestamp).toDate()
          : null,
      snsPostUrl: data['sns_post_url'] as String?,
      verifiedAt: data['verified_at'] != null
          ? (data['verified_at'] as Timestamp).toDate()
          : null,
      benefitAppliedAt: data['benefit_applied_at'] != null
          ? (data['benefit_applied_at'] as Timestamp).toDate()
          : null,
      rejectionReason: data['rejection_reason'] as String?,
    );
  }

  /// Firestoreに保存
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'plan_type': planType,
      'previous_app_name': previousAppName,
      'unique_code': uniqueCode,
      'status': status.name,
      'created_at': Timestamp.fromDate(createdAt),
      'sns_posted_at': snsPostedAt != null ? Timestamp.fromDate(snsPostedAt!) : null,
      'sns_post_url': snsPostUrl,
      'verified_at': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'benefit_applied_at': benefitAppliedAt != null ? Timestamp.fromDate(benefitAppliedAt!) : null,
      'rejection_reason': rejectionReason,
    };
  }

  /// ステータス更新
  CampaignApplication copyWith({
    CampaignStatus? status,
    DateTime? snsPostedAt,
    String? snsPostUrl,
    DateTime? verifiedAt,
    DateTime? benefitAppliedAt,
    String? rejectionReason,
  }) {
    return CampaignApplication(
      id: id,
      userId: userId,
      planType: planType,
      previousAppName: previousAppName,
      uniqueCode: uniqueCode,
      status: status ?? this.status,
      createdAt: createdAt,
      snsPostedAt: snsPostedAt ?? this.snsPostedAt,
      snsPostUrl: snsPostUrl ?? this.snsPostUrl,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      benefitAppliedAt: benefitAppliedAt ?? this.benefitAppliedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

/// キャンペーン申請ステータス
enum CampaignStatus {
  pending,        // 申請受付中
  awaitingPost,   // SNS投稿待ち
  checking,       // 自動確認中
  approved,       // 承認済み
  rejected,       // 却下
}

extension CampaignStatusExtension on CampaignStatus {
  String get displayName {
    switch (this) {
      case CampaignStatus.pending:
        return AppLocalizations.of(context)!.general_a3b837e3;
      case CampaignStatus.awaitingPost:
        return AppLocalizations.of(context)!.general_8dbf9959;
      case CampaignStatus.checking:
        return AppLocalizations.of(context)!.general_15cea5d6;
      case CampaignStatus.approved:
        return AppLocalizations.of(context)!.general_179ff898;
      case CampaignStatus.rejected:
        return AppLocalizations.of(context)!.general_818296e9;
    }
  }

  String get icon {
    switch (this) {
      case CampaignStatus.pending:
        return '⏳';
      case CampaignStatus.awaitingPost:
        return '📱';
      case CampaignStatus.checking:
        return '🔍';
      case CampaignStatus.approved:
        return '✅';
      case CampaignStatus.rejected:
        return '❌';
    }
  }
}
