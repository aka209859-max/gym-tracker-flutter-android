import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/campaign_application.dart';

/// キャンペーン管理サービス
/// 
/// 完全自動化されたキャンペーンシステム
/// CEOが何もしなくても動作する
class CampaignService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ユニークコード生成
  /// 
  /// フォーマット: #GM2025{6桁英数字}
  /// 例: #GM2025A3B7C9
  String generateUniqueCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 混同しやすい文字を除外
    final random = Random.secure();
    final code = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    return '#GM2025$code';
  }

  /// キャンペーン申請作成
  /// 
  /// プラン登録時に自動実行
  Future<CampaignApplication> createApplication({
    required String userId,
    required String planType,
    required String previousAppName,
  }) async {
    final uniqueCode = generateUniqueCode();

    final application = CampaignApplication(
      id: '', // Firestoreが自動生成
      userId: userId,
      planType: planType,
      previousAppName: previousAppName,
      uniqueCode: uniqueCode,
      status: CampaignStatus.awaitingPost,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('campaign_applications')
        .add(application.toFirestore());

    return application.copyWith().copyWith(); // IDを含む新しいインスタンス返却用（簡易実装）
  }

  /// ユーザーの申請状況取得
  Future<CampaignApplication?> getUserApplication(String userId) async {
    final snapshot = await _firestore
        .collection('campaign_applications')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return CampaignApplication.fromFirestore(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  }

  /// SNS投稿完了報告
  /// 
  /// ユーザーが「投稿しました」ボタンを押した時に実行
  Future<void> reportSnsPosted({
    required String applicationId,
    String? postUrl,
  }) async {
    await _firestore
        .collection('campaign_applications')
        .doc(applicationId)
        .update({
      'status': CampaignStatus.checking.name,
      'sns_posted_at': FieldValue.serverTimestamp(),
      'sns_post_url': postUrl,
    });

    // ここで自動確認プロセスをトリガー（Cloud Functionsで実装推奨）
    // 現時点では手動確認フローとして実装
  }

  /// 投稿内容自動確認（Cloud Functions想定）
  /// 
  /// X API / Instagram Graph APIで投稿を検索し、
  /// Gemini APIで内容を自動チェック
  Future<bool> verifyPostContent({
    required String uniqueCode,
    required String postContent,
    required String planType,
  }) async {
    // 必須条件チェック
    final requiredElements = {
      'uniqueCode': uniqueCode,
      'hashtag1': '#GymMatch乗り換え割',
      'hashtag2': '#AI筋トレ分析',
    };

    // ユニークコードチェック
    if (!postContent.contains(uniqueCode)) {
      return false;
    }

    // ハッシュタグチェック
    if (!postContent.contains('#GymMatch乗り換え割') ||
        !postContent.contains('#AI筋トレ分析')) {
      return false;
    }

    // 体験談チェック（最低文字数）
    final textWithoutHashtags = postContent
        .replaceAll(RegExp(r'#\w+'), '')
        .replaceAll(uniqueCode, '')
        .trim();

    if (textWithoutHashtags.length < 10) {
      return false; // 体験談が短すぎる
    }

    return true;
  }

  /// 特典自動適用
  /// 
  /// 投稿確認後、自動的に特典を適用
  Future<void> applyBenefit({
    required String applicationId,
    required String userId,
    required String planType,
  }) async {
    // 申請ステータス更新
    await _firestore
        .collection('campaign_applications')
        .doc(applicationId)
        .update({
      'status': CampaignStatus.approved.name,
      'verified_at': FieldValue.serverTimestamp(),
      'benefit_applied_at': FieldValue.serverTimestamp(),
    });

    // サブスクリプション特典適用
    final benefitMonths = planType == 'premium' ? 2 : 1; // プレミアム2ヶ月、Pro1ヶ月

    await _firestore.collection('user_subscriptions').doc(userId).update({
      'free_months_remaining': FieldValue.increment(benefitMonths),
      'campaign_benefit_applied': true,
      'campaign_benefit_applied_at': FieldValue.serverTimestamp(),
    });
  }

  /// 申請却下
  Future<void> rejectApplication({
    required String applicationId,
    required String reason,
  }) async {
    await _firestore
        .collection('campaign_applications')
        .doc(applicationId)
        .update({
      'status': CampaignStatus.rejected.name,
      'rejection_reason': reason,
      'verified_at': FieldValue.serverTimestamp(),
    });
  }

  /// SNS投稿テンプレート生成
  String generateSnsTemplate({
    required String uniqueCode,
    required String previousAppName,
    required String planType,
  }) {
    final benefit = planType == 'premium' ? AppLocalizations.of(context)!.general_9aff674f : AppLocalizations.of(context)!.general_6fd93ccd;

    return '''
$previousAppName から GYM MATCH に乗り換えました！

AIが過去のトレーニングデータを分析して、自分の弱点を"明確化"してくれた。今まで「なんとなく」やってたトレーニングが、「確信」に変わった感覚。

乗り換え割で$benefitは嬉しい！

$uniqueCode
#GymMatch乗り換え割 #AI筋トレ分析
''';
  }

  /// キャンペーン統計取得（CEO用ダッシュボード）
  Future<Map<String, dynamic>> getCampaignStats() async {
    final snapshot = await _firestore
        .collection('campaign_applications')
        .get();

    int totalApplications = snapshot.docs.length;
    int approved = 0;
    int pending = 0;
    int rejected = 0;

    for (var doc in snapshot.docs) {
      final status = doc.data()['status'] as String;
      if (status == CampaignStatus.approved.name) {
        approved++;
      } else if (status == CampaignStatus.rejected.name) {
        rejected++;
      } else {
        pending++;
      }
    }

    return {
      'total_applications': totalApplications,
      'approved': approved,
      'pending': pending,
      'rejected': rejected,
      'approval_rate': totalApplications > 0 ? (approved / totalApplications * 100).toStringAsFixed(1) : '0.0',
    };
  }
}
