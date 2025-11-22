import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_service.dart';

/// AI機能クレジット管理サービス（CEO戦略: 動画視聴で1回追加）
class AICreditService {
  static const String _aiCreditKey = 'ai_credit_count';
  static const String _lastResetDateKey = 'ai_credit_last_reset_date';
  
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  /// AI機能が使用可能かチェック（サブスクまたはクレジットあり）
  Future<bool> canUseAI() async {
    try {
      // 有料プランなら直接OK
      final plan = await _subscriptionService.getCurrentPlan();
      print('🔍 [canUseAI] 現在のプラン: $plan');
      
      if (plan != SubscriptionType.free) {
        // 有料プランの月次制限チェック
        final remaining = await _subscriptionService.getRemainingAIUsage();
        print('🔍 [canUseAI] 有料プラン残回数: $remaining');
        return remaining > 0;
      }
      
      // 無料プラン: まずAI追加パック（¥300）の残回数をチェック
      final addonUsage = await _subscriptionService.getAddonAIUsage();
      print('🔍 [canUseAI] AI追加パック残回数: $addonUsage');
      if (addonUsage > 0) {
        return true; // AI追加パックがあれば広告なしで利用可能
      }
      
      // AI追加パックなし: クレジット残高をチェック
      final credits = await getAICredits();
      print('🔍 [canUseAI] 無料プラン AIクレジット: $credits');
      return credits > 0;
    } catch (e) {
      print('❌ [canUseAI] エラー: $e');
      return false;
    }
  }
  
  /// 現在のAIクレジット残高を取得（無料プランのみ）
  Future<int> getAICredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_aiCreditKey) ?? 0;
  }
  
  /// AIクレジットを追加（動画視聴報酬）
  Future<void> addAICredit(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getAICredits();
    await prefs.setInt(_aiCreditKey, current + amount);
    print('✅ AIクレジット追加: +$amount (合計: ${current + amount})');
  }
  
  /// AIクレジットを消費（無料プランのAI利用時）
  Future<bool> consumeAICredit() async {
    final plan = await _subscriptionService.getCurrentPlan();
    
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
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiCreditKey, credits - 1);
    print('✅ AIクレジット消費: -1 (残り: ${credits - 1})');
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
