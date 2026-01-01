import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// サブスクリプション管理サービス
/// 
/// 一時停止・ダウングレード・解約理由収集など、
/// チャーン防止のための柔軟なプラン管理機能を提供
class SubscriptionManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 一時停止期間の選択肢
  static const List<int> pauseDurationMonths = [1, 2, 3];

  /// 解約・ダウングレード理由
  static const List<String> churnReasons = [
    AppLocalizations.of(context)!.subscription_d0ec979f,
    AppLocalizations.of(context)!.subscription_650df3a4,
    AppLocalizations.of(context)!.subscription_296022b1,
    AppLocalizations.of(context)!.subscription_89e60591,
    AppLocalizations.of(context)!.subscription_21666f45,
    AppLocalizations.of(context)!.subscription_0cdfb519,
    AppLocalizations.of(context)!.bodyPartOther,
  ];

  /// サブスクリプションを一時停止
  /// 
  /// Parameters:
  /// - [durationMonths]: 停止期間（1-3ヶ月）
  /// - [reason]: 停止理由
  /// 
  /// Returns: 停止成功時 true
  Future<bool> pauseSubscription({
    required int durationMonths,
    String? reason,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final pauseUntil = DateTime.now().add(Duration(days: durationMonths * 30));
      
      await _firestore.collection('subscription_pauses').add({
        'userId': userId,
        'pausedAt': FieldValue.serverTimestamp(),
        'pauseUntil': Timestamp.fromDate(pauseUntil),
        'durationMonths': durationMonths,
        'reason': reason,
        'status': 'active', // active, resumed, cancelled
      });

      // ユーザープロフィールにも記録
      await _firestore.collection('users').doc(userId).update({
        'subscriptionPaused': true,
        'subscriptionPauseUntil': Timestamp.fromDate(pauseUntil),
      });

      print('✅ サブスクリプション一時停止: $durationMonths ヶ月（理由: $reason）');
      return true;
    } catch (e) {
      print('❌ 一時停止エラー: $e');
      return false;
    }
  }

  /// 一時停止を解除（早期再開）
  Future<bool> resumeSubscription() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      // アクティブな一時停止を探す
      final pausesSnapshot = await _firestore
          .collection('subscription_pauses')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in pausesSnapshot.docs) {
        await doc.reference.update({
          'status': 'resumed',
          'resumedAt': FieldValue.serverTimestamp(),
        });
      }

      // ユーザープロフィールを更新
      await _firestore.collection('users').doc(userId).update({
        'subscriptionPaused': false,
        'subscriptionPauseUntil': FieldValue.delete(),
      });

      print('✅ サブスクリプション再開');
      return true;
    } catch (e) {
      print('❌ 再開エラー: $e');
      return false;
    }
  }

  /// ダウングレード申請を記録
  /// 
  /// Parameters:
  /// - [currentPlan]: 現在のプラン（premium/pro）
  /// - [targetPlan]: 移行先プラン（free/premium）
  /// - [reason]: ダウングレード理由
  Future<bool> requestDowngrade({
    required String currentPlan,
    required String targetPlan,
    String? reason,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      await _firestore.collection('subscription_downgrades').add({
        'userId': userId,
        'currentPlan': currentPlan,
        'targetPlan': targetPlan,
        'reason': reason,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, completed, cancelled
      });

      print('✅ ダウングレード申請: $currentPlan → $targetPlan（理由: $reason）');
      return true;
    } catch (e) {
      print('❌ ダウングレード申請エラー: $e');
      return false;
    }
  }

  /// 解約理由を記録
  /// 
  /// 今後の改善のために解約理由を収集
  Future<bool> recordCancellationReason({
    required String plan,
    required List<String> reasons,
    String? additionalFeedback,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      await _firestore.collection('subscription_cancellations').add({
        'userId': userId,
        'plan': plan,
        'reasons': reasons,
        'additionalFeedback': additionalFeedback,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      print('✅ 解約理由記録: $reasons');
      return true;
    } catch (e) {
      print('❌ 解約理由記録エラー: $e');
      return false;
    }
  }

  /// 一時停止中かチェック
  Future<bool> isPaused() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      if (data == null) return false;
      
      final isPaused = data['subscriptionPaused'] as bool? ?? false;
      final pauseUntil = data['subscriptionPauseUntil'] as Timestamp?;

      // 停止中で、かつ期限が過ぎていない
      if (isPaused && pauseUntil != null) {
        final now = DateTime.now();
        final pauseEnd = pauseUntil.toDate();
        
        if (pauseEnd.isAfter(now)) {
          return true;
        } else {
          // 期限切れなので自動的に再開
          await resumeSubscription();
          return false;
        }
      }

      return false;
    } catch (e) {
      print('❌ 一時停止チェックエラー: $e');
      return false;
    }
  }

  /// 一時停止の残り日数を取得
  Future<int?> getRemainingPauseDays() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      if (data == null) return null;
      
      final pauseUntil = data['subscriptionPauseUntil'] as Timestamp?;
      if (pauseUntil == null) return null;

      final pauseEnd = pauseUntil.toDate();
      final now = DateTime.now();
      final remainingDays = pauseEnd.difference(now).inDays;

      return remainingDays > 0 ? remainingDays : 0;
    } catch (e) {
      print('❌ 残り日数取得エラー: $e');
      return null;
    }
  }

  /// チャーン防止のための代替案を提案
  /// 
  /// Returns: {type: 'pause' | 'downgrade' | 'ai_pack', message: String}
  Map<String, String> suggestRetentionOption(String currentPlan, String reason) {
    // 理由に応じて最適な代替案を提案
    switch (reason) {
      case AppLocalizations.of(context)!.subscription_d0ec979f:
        if (currentPlan == 'pro') {
          return {
            'type': 'downgrade',
            'message': AppLocalizations.of(context)!.subscription_9f2715bb,
          };
        } else {
          return {
            'type': 'pause',
            'message': '1-3ヶ月の一時停止で料金を抑えられます',
          };
        }
      
      case AppLocalizations.of(context)!.subscription_650df3a4:
        return {
          'type': 'pause',
          'message': AppLocalizations.of(context)!.subscription_6ec3ee80,
        };
      
      case AppLocalizations.of(context)!.subscription_89e60591:
        return {
          'type': 'pause',
          'message': AppLocalizations.of(context)!.subscription_d6d20930,
        };
      
      case AppLocalizations.of(context)!.subscription_0cdfb519:
        return {
          'type': 'pause',
          'message': AppLocalizations.of(context)!.subscription_74863211,
        };
      
      case AppLocalizations.of(context)!.subscription_296022b1:
        if (currentPlan == 'pro' || currentPlan == 'premium') {
          return {
            'type': 'ai_pack',
            'message': '無料プラン + AI追加パック（¥300/5回）なら必要な機能だけ使えます',
          };
        }
        return {
          'type': 'downgrade',
          'message': AppLocalizations.of(context)!.subscription_b18ca5da,
        };
      
      default:
        return {
          'type': 'pause',
          'message': AppLocalizations.of(context)!.subscription_0c7f8762,
        };
    }
  }
}
