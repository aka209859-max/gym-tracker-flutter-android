import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'ai_credit_service.dart';
import 'achievement_service.dart';

/// 混雑度報告インセンティブサービス
/// 
/// ユーザーに混雑度報告を促すための報酬システム
/// - 即時報酬: AI 1回分無料
/// - マイルストーン報酬: バッジ、Premium/Pro割引クーポン
class CrowdReportIncentiveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AICreditService _aiCreditService = AICreditService();
  
  /// 混雑度報告を送信し、報酬を付与
  Future<ReportRewardResult> submitCrowdReport({
    required String gymId,
    required int crowdLevel,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return ReportRewardResult(
          success: false,
          message: AppLocalizations.of(context)!.loginRequired,
        );
      }
      
      // 1. 混雑度をFirestoreに保存（set with merge to avoid permission errors）
      try {
        if (kDebugMode) {
          print('📊 Updating crowd level for gym: $gymId -> Level: $crowdLevel');
        }
        await _firestore.collection('gyms').doc(gymId).set({
          'currentCrowdLevel': crowdLevel,
          'lastCrowdUpdate': FieldValue.serverTimestamp(),
          'last_reporter_id': user.uid,
        }, SetOptions(merge: true));
        if (kDebugMode) {
          print('✅ Crowd level updated successfully for gym: $gymId');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Gym update skipped (may not have permission): $e');
        }
        // Continue even if gym update fails - user still gets reward
      }
      
      // 2. 報告回数をインクリメント
      final reportCount = await _incrementReportCount(user.uid);
      
      // 3. 即時報酬: AI 1回分無料クレジット付与
      await _aiCreditService.addAICredit(1);
      
      // 4. マイルストーン報酬チェック
      final milestone = await _checkMilestone(user.uid, reportCount);
      
      if (kDebugMode) {
        print('✅ 混雑度報告完了: $reportCount回目');
      }
      
      return ReportRewardResult(
        success: true,
        message: AppLocalizations.of(context)!.general_abb85a78,
        aiCreditAwarded: 1,
        reportCount: reportCount,
        milestone: milestone,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 混雑度報告エラー: $e');
      }
      return ReportRewardResult(
        success: false,
        message: 'エラーが発生しました: ${e.toString()}',
      );
    }
  }
  
  /// ユーザーの報告回数をインクリメント
  Future<int> _incrementReportCount(String userId) async {
    final userDoc = _firestore.collection('users').doc(userId);
    final snapshot = await userDoc.get();
    
    final currentCount = snapshot.data()?['crowd_report_count'] as int? ?? 0;
    final newCount = currentCount + 1;
    
    await userDoc.set({
      'crowd_report_count': newCount,
      'last_crowd_report': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    return newCount;
  }
  
  /// マイルストーン報酬チェック
  Future<MilestoneReward?> _checkMilestone(String userId, int reportCount) async {
    MilestoneReward? reward;
    
    switch (reportCount) {
      case 10:
        // 10回報告: バッジ「混雑レポーター」
        reward = MilestoneReward(
          type: RewardType.badge,
          title: '🎖️ バッジ獲得！',
          description: AppLocalizations.of(context)!.general_d8b75b82,
          badgeId: 'crowd_reporter_10',
        );
        await _unlockBadge(userId, 'crowd_reporter_10');
        break;
        
      case 50:
        // 50回報告: Premium 1ヶ月無料クーポン
        reward = MilestoneReward(
          type: RewardType.premiumCoupon,
          title: '🎁 Premium 1ヶ月無料！',
          description: AppLocalizations.of(context)!.general_1a08e6bb,
          couponCode: 'PREMIUM_1MONTH_FREE',
        );
        await _issueCoupon(userId, 'PREMIUM_1MONTH_FREE', 'Premium 1ヶ月無料', 30);
        break;
        
      case 100:
        // 100回報告: Pro Plan 50% OFFクーポン
        reward = MilestoneReward(
          type: RewardType.proCoupon,
          title: '🔥 Pro Plan 50% OFF！',
          description: AppLocalizations.of(context)!.general_6f421e4c,
          couponCode: 'PRO_PLAN_50_OFF',
        );
        await _issueCoupon(userId, 'PRO_PLAN_50_OFF', 'Pro Plan 50% OFF (初月)', 90);
        break;
        
      case 200:
        // 200回報告: 特別バッジ + AI 50回分
        reward = MilestoneReward(
          type: RewardType.legendary,
          title: '👑 伝説の混雑レポーター！',
          description: '200回達成！AI 50回分プレゼント',
          badgeId: 'crowd_reporter_legendary',
        );
        await _unlockBadge(userId, 'crowd_reporter_legendary');
        await _aiCreditService.addAICredit(50);
        break;
    }
    
    return reward;
  }
  
  /// バッジを解除
  Future<void> _unlockBadge(String userId, String badgeId) async {
    try {
      await _firestore.collection('user_badges').add({
        'user_id': userId,
        'badge_id': badgeId,
        'unlocked_at': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        print('✅ バッジ解除: $badgeId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ バッジ解除エラー: $e');
      }
    }
  }
  
  /// クーポンを発行
  Future<void> _issueCoupon(String userId, String couponCode, String description, int validDays) async {
    try {
      final expiryDate = DateTime.now().add(Duration(days: validDays));
      
      await _firestore.collection('user_coupons').add({
        'user_id': userId,
        'coupon_code': couponCode,
        'description': description,
        'issued_at': FieldValue.serverTimestamp(),
        'expires_at': Timestamp.fromDate(expiryDate),
        'used': false,
      });
      
      if (kDebugMode) {
        print('✅ クーポン発行: $couponCode');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ クーポン発行エラー: $e');
      }
    }
  }
  
  /// ユーザーの報告回数を取得
  Future<int> getUserReportCount(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['crowd_report_count'] as int? ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 報告回数取得エラー: $e');
      }
      return 0;
    }
  }
  
  /// 次のマイルストーンまでの残り回数を取得
  Future<NextMilestone> getNextMilestone(String userId) async {
    final currentCount = await getUserReportCount(userId);
    
    final milestones = [10, 50, 100, 200];
    for (final milestone in milestones) {
      if (currentCount < milestone) {
        final remaining = milestone - currentCount;
        return NextMilestone(
          target: milestone,
          remaining: remaining,
          reward: _getMilestoneRewardDescription(milestone),
        );
      }
    }
    
    // 全マイルストーン達成済み
    return NextMilestone(
      target: 200,
      remaining: 0,
      reward: AppLocalizations.of(context)!.general_67e3473d,
    );
  }
  
  String _getMilestoneRewardDescription(int milestone) {
    switch (milestone) {
      case 10:
        return '🎖️ バッジ「混雑レポーター」';
      case 50:
        return '🎁 Premium 1ヶ月無料';
      case 100:
        return '🔥 Pro Plan 50% OFF';
      case 200:
        return '👑 伝説バッジ + AI 50回分';
      default:
        return AppLocalizations.of(context)!.general_945ccc14;
    }
  }
}

/// 報告報酬結果
class ReportRewardResult {
  final bool success;
  final String message;
  final int? aiCreditAwarded;
  final int? reportCount;
  final MilestoneReward? milestone;
  
  ReportRewardResult({
    required this.success,
    required this.message,
    this.aiCreditAwarded,
    this.reportCount,
    this.milestone,
  });
}

/// マイルストーン報酬
class MilestoneReward {
  final RewardType type;
  final String title;
  final String description;
  final String? badgeId;
  final String? couponCode;
  
  MilestoneReward({
    required this.type,
    required this.title,
    required this.description,
    this.badgeId,
    this.couponCode,
  });
}

/// 報酬タイプ
enum RewardType {
  badge,          // バッジ
  premiumCoupon,  // Premiumクーポン
  proCoupon,      // Proクーポン
  legendary,      // 伝説報酬
}

/// 次のマイルストーン
class NextMilestone {
  final int target;
  final int remaining;
  final String reward;
  
  NextMilestone({
    required this.target,
    required this.remaining,
    required this.reward,
  });
}
