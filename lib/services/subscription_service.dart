import 'package:shared_preferences/shared_preferences.dart';

/// プラン種類
enum SubscriptionType {
  free,      // 無料プラン
  premium,   // プレミアムプラン
  pro        // プロプラン
}

/// 有料プラン管理サービス
class SubscriptionService {
  static const String _subscriptionKey = 'subscription_status';
  static const String _subscriptionTypeKey = 'subscription_type';
  
  /// 現在のプラン種類を取得
  Future<SubscriptionType> getCurrentPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final planString = prefs.getString(_subscriptionTypeKey);
      
      if (planString == null) {
        return SubscriptionType.free;
      }
      
      return SubscriptionType.values.firstWhere(
        (e) => e.toString() == planString,
        orElse: () => SubscriptionType.free,
      );
    } catch (e) {
      print('❌ プラン取得エラー: $e');
      return SubscriptionType.free;
    }
  }
  
  /// プランを変更
  Future<void> setPlan(SubscriptionType plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subscriptionTypeKey, plan.toString());
    await prefs.setBool(_subscriptionKey, plan != SubscriptionType.free);
    print('✅ プラン変更: $plan');
  }
  
  /// プランを変更（ブール値を返す）
  Future<bool> changePlan(SubscriptionType plan) async {
    try {
      await setPlan(plan);
      return true;
    } catch (e) {
      print('❌ プラン変更エラー: $e');
      return false;
    }
  }
  
  /// プレミアム機能が利用可能かチェック
  Future<bool> isPremiumFeatureAvailable() async {
    final plan = await getCurrentPlan();
    return plan == SubscriptionType.premium || plan == SubscriptionType.pro;
  }
  
  /// プロ機能が利用可能かチェック
  Future<bool> isProFeatureAvailable() async {
    final plan = await getCurrentPlan();
    return plan == SubscriptionType.pro;
  }
  
  /// 有料プランかチェック
  Future<bool> hasActivePlan() async {
    final plan = await getCurrentPlan();
    return plan != SubscriptionType.free;
  }
  
  /// プラン名を取得
  String getPlanName(SubscriptionType plan) {
    return switch (plan) {
      SubscriptionType.free => '無料プラン',
      SubscriptionType.premium => 'プレミアムプラン',
      SubscriptionType.pro => 'プロプラン',
    };
  }
  
  /// プラン説明を取得
  String getPlanDescription(SubscriptionType plan) {
    return switch (plan) {
      SubscriptionType.free => 'ジム検索 + トレーニング記録',
      SubscriptionType.premium => 'AI機能（月10回） + お気に入り無制限 + レビュー投稿',
      SubscriptionType.pro => 'AI機能（月30回） + パートナー検索 + メッセージング',
    };
  }
  
  /// AI機能が利用可能かチェック（新課金モデル）
  Future<bool> isAIFeatureAvailable() async {
    final plan = await getCurrentPlan();
    return plan == SubscriptionType.premium || plan == SubscriptionType.pro;
  }
  
  /// AI週次レポートが利用可能かチェック
  Future<bool> isAIWeeklyReportAvailable() async {
    final plan = await getCurrentPlan();
    return plan == SubscriptionType.pro;
  }
  
  /// プラン価格を取得
  String getPlanPrice(SubscriptionType plan) {
    return switch (plan) {
      SubscriptionType.free => '¥0',
      SubscriptionType.premium => '¥500/月',
      SubscriptionType.pro => '¥980/月',
    };
  }
  
  /// AI使用回数上限を取得
  int getAIUsageLimit(SubscriptionType plan) {
    return switch (plan) {
      SubscriptionType.free => 0,
      SubscriptionType.premium => 10,
      SubscriptionType.pro => 30,
    };
  }
  
  /// 今月のAI使用回数を取得
  Future<int> getCurrentMonthAIUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastResetDate = prefs.getString('ai_usage_reset_date');
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      // 月が変わっていたらリセット
      if (lastResetDate != currentMonth) {
        await prefs.setInt('ai_usage_count', 0);
        await prefs.setString('ai_usage_reset_date', currentMonth);
        return 0;
      }
      
      return prefs.getInt('ai_usage_count') ?? 0;
    } catch (e) {
      print('❌ AI使用回数取得エラー: $e');
      return 0;
    }
  }
  
  /// AI使用回数をインクリメント
  Future<bool> incrementAIUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUsage = await getCurrentMonthAIUsage();
      await prefs.setInt('ai_usage_count', currentUsage + 1);
      print('✅ AI使用回数: ${currentUsage + 1}');
      return true;
    } catch (e) {
      print('❌ AI使用回数更新エラー: $e');
      return false;
    }
  }
  
  /// AI機能が使用可能かチェック（回数制限含む）
  Future<bool> canUseAIFeature() async {
    final plan = await getCurrentPlan();
    final limit = getAIUsageLimit(plan);
    
    // 無料プランはAI機能なし
    if (limit == 0) {
      return false;
    }
    
    final currentUsage = await getCurrentMonthAIUsage();
    return currentUsage < limit;
  }
  
  /// 残りAI使用回数を取得
  Future<int> getRemainingAIUsage() async {
    final plan = await getCurrentPlan();
    final limit = getAIUsageLimit(plan);
    final currentUsage = await getCurrentMonthAIUsage();
    return (limit - currentUsage).clamp(0, limit);
  }
  
  /// AI使用状況メッセージを取得
  Future<String> getAIUsageStatus() async {
    final plan = await getCurrentPlan();
    final limit = getAIUsageLimit(plan);
    
    if (limit == 0) {
      return 'AI機能は有料プランで利用可能です';
    }
    
    final currentUsage = await getCurrentMonthAIUsage();
    final remaining = limit - currentUsage;
    
    if (remaining <= 0) {
      return '今月のAI使用回数を使い切りました (${currentUsage}/${limit}回)';
    }
    
    return '残り${remaining}回 (${currentUsage}/${limit}回使用)';
  }
}
