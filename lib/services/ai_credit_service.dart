import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'subscription_service.dart';
import 'ai_abuse_prevention_service.dart';

/// AI機能クレジット管理サービス（CEO戦略: 動画視聴で1回追加）
class AICreditService {
  static const String _aiCreditKey = 'ai_credit_count';
  static const String _lastResetDateKey = 'ai_credit_last_reset_date';
  
  final SubscriptionService _subscriptionService = SubscriptionService();
  final AIAbusePreventionService _abusePreventionService = AIAbusePreventionService();
  
  /// Firestoreへのバックアップフラグ
  static const bool _enableFirestoreBackup = true;
  
  /// AI機能が使用可能かチェック（サブスクまたはクレジットあり + 悪用防止）
  Future<CanUseAIResult> canUseAI() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return CanUseAIResult(
          allowed: false,
          reason: 'ログインが必要です',
        );
      }
      
      // 🛡️ Phase 1: ブロックチェック
      final isBlocked = await _abusePreventionService.isUserBlocked(user.uid);
      if (isBlocked) {
        return CanUseAIResult(
          allowed: false,
          reason: 'アカウントがブロックされています。\nサポートにお問い合わせください。',
        );
      }
      
      final plan = await _subscriptionService.getCurrentPlan();
      print('🔍 [canUseAI] 現在のプラン: $plan');
      
      // 🛡️ Phase 2: Pro会員のレート制限チェック
      if (plan == SubscriptionType.pro) {
        final rateLimitResult = await _abusePreventionService.checkRateLimit(user.uid);
        if (!rateLimitResult.allowed) {
          return CanUseAIResult(
            allowed: false,
            reason: rateLimitResult.reason ?? 'レート制限に達しました',
          );
        }
        
        // Pro会員は無制限（レート制限内なら利用可能）
        return CanUseAIResult(allowed: true);
      }
      
      if (plan != SubscriptionType.free) {
        // Premium: 月次制限チェック
        final remaining = await _subscriptionService.getRemainingAIUsage();
        print('🔍 [canUseAI] Premium残回数: $remaining');
        if (remaining > 0) {
          return CanUseAIResult(allowed: true);
        }
        return CanUseAIResult(
          allowed: false,
          reason: '今月のAI利用回数（20回）を使い切りました',
        );
      }
      
      // 無料プラン: まずAI追加パック（¥300）の残回数をチェック
      final addonUsage = await _subscriptionService.getAddonAIUsage();
      print('🔍 [canUseAI] AI追加パック残回数: $addonUsage');
      if (addonUsage > 0) {
        return CanUseAIResult(allowed: true);
      }
      
      // AI追加パックなし: クレジット残高をチェック
      final credits = await getAICredits();
      print('🔍 [canUseAI] 無料プラン AIクレジット: $credits');
      if (credits > 0) {
        return CanUseAIResult(allowed: true);
      }
      
      return CanUseAIResult(
        allowed: false,
        reason: '今月のAI利用回数（3回）を使い切りました',
      );
    } catch (e) {
      print('❌ [canUseAI] エラー: $e');
      return CanUseAIResult(
        allowed: false,
        reason: 'エラーが発生しました',
      );
    }
  }
  
  /// 現在のAIクレジット残高を取得（Firestore優先、SharedPreferencesフォールバック）
  Future<int> getAICredits() async {
    if (_enableFirestoreBackup) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.serverAndCache));
          
          if (userDoc.exists) {
            final data = userDoc.data();
            final firestoreCredits = data?['ai_credits'] as int? ?? 0;
            
            // Firestoreの値をローカルに同期
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_aiCreditKey, firestoreCredits);
            
            return firestoreCredits;
          }
        }
      } catch (e) {
        print('⚠️ Firestoreからのクレジット取得失敗、ローカルを使用: $e');
      }
    }
    
    // フォールバック: SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_aiCreditKey) ?? 0;
  }
  
  /// AIクレジットを追加（動画視聴報酬）- Firestoreとローカル両方に保存
  Future<void> addAICredit(int amount) async {
    final current = await getAICredits();
    final newTotal = current + amount;
    
    // SharedPreferencesに保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiCreditKey, newTotal);
    
    // Firestoreにバックアップ
    if (_enableFirestoreBackup) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'ai_credits': newTotal,
            'ai_credits_updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ AIクレジットFirestore保存: $newTotal');
        }
      } catch (e) {
        print('⚠️ FirestoreへのAIクレジット保存失敗（ローカルは保存済み）: $e');
      }
    }
    
    print('✅ AIクレジット追加: +$amount (合計: $newTotal)');
  }
  
  /// AIクレジットを消費（無料プランのAI利用時）+ ログ記録
  Future<bool> consumeAICredit({String featureType = 'unknown'}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    final plan = await _subscriptionService.getCurrentPlan();
    
    // 🛡️ AI利用ログを記録（悪用検出用）
    await _abusePreventionService.logAIUsage(user.uid, featureType);
    
    // 有料プランはサブスクリプションサービス経由
    if (plan != SubscriptionType.free) {
      return await _subscriptionService.incrementAIUsage();
    }
    
    // 無料プラン: まずAI追加パック（¥300）から消費
    final addonUsage = await _subscriptionService.getAddonAIUsage();
    if (addonUsage > 0) {
      final success = await _subscriptionService.consumeAddonAIUsage();
      if (success) {
        print('✅ AI追加パック消費: -1 (残り: ${addonUsage - 1})');
        return true;
      }
    }
    
    // AI追加パックなし: クレジット消費
    final credits = await getAICredits();
    if (credits <= 0) {
      return false;
    }
    
    final newTotal = credits - 1;
    
    // SharedPreferencesに保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiCreditKey, newTotal);
    
    // Firestoreにバックアップ
    if (_enableFirestoreBackup) {
      try {
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'ai_credits': newTotal,
            'ai_credits_updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ AIクレジットFirestore保存: $newTotal');
        }
      } catch (e) {
        print('⚠️ FirestoreへのAIクレジット保存失敗（ローカルは保存済み）: $e');
      }
    }
    
    print('✅ AIクレジット消費: -1 (残り: $newTotal)');
    return true;
  }
  
  /// AI利用可能回数を取得（プラン別）
  Future<String> getAIUsageStatus() async {
    final plan = await _subscriptionService.getCurrentPlan();
    
    if (plan == SubscriptionType.free) {
      // 無料プラン: AI追加パック + クレジット残高
      final addonUsage = await _subscriptionService.getAddonAIUsage();
      final credits = await getAICredits();
      if (addonUsage > 0) {
        return 'AI追加パック: $addonUsage回 | AIクレジット: $credits回';
      }
      return 'AIクレジット: $credits回';
    } else {
      // 有料プランは月次制限
      return await _subscriptionService.getAIUsageStatus();
    }
  }
  
  /// 動画視聴でAIクレジットを獲得可能か（月3回まで）
  Future<bool> canEarnCreditFromAd() async {
    try {
      final plan = await _subscriptionService.getCurrentPlan();
      print('🔍 [canEarnCreditFromAd] 現在のプラン: $plan');
      
      // 有料プランは動画視聴不要
      if (plan != SubscriptionType.free) {
        print('🔍 [canEarnCreditFromAd] 有料プランのため広告不要');
        return false;
      }
      
      // 今月の動画視聴回数をチェック
      final earnedThisMonth = await _getAdEarnedCountThisMonth();
      print('🔍 [canEarnCreditFromAd] 今月の広告視聴回数: $earnedThisMonth/3');
      return earnedThisMonth < 3; // CEO戦略: 月3回まで
    } catch (e) {
      print('❌ [canEarnCreditFromAd] エラー: $e');
      return false;
    }
  }
  
  /// 今月の動画視聴によるクレジット獲得回数
  Future<int> _getAdEarnedCountThisMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetDate = prefs.getString(_lastResetDateKey);
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    
    // 月が変わったらリセット
    if (lastResetDate != currentMonth) {
      await prefs.setString(_lastResetDateKey, currentMonth);
      await prefs.setInt('${_aiCreditKey}_earned_count', 0);
      return 0;
    }
    
    return prefs.getInt('${_aiCreditKey}_earned_count') ?? 0;
  }
  
  /// 動画視聴でクレジット獲得を記録
  Future<void> recordAdEarned() async {
    final count = await _getAdEarnedCountThisMonth();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_aiCreditKey}_earned_count', count + 1);
  }
}

/// AI利用可能判定結果
class CanUseAIResult {
  final bool allowed;
  final String? reason;
  
  CanUseAIResult({
    required this.allowed,
    this.reason,
  });
}
