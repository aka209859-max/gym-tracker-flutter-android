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
      SubscriptionType.free => '基本機能のみ利用可能',
      SubscriptionType.premium => 'トレーニングパートナー + メッセージング',
      SubscriptionType.pro => 'すべての機能 + 優先サポート',
    };
  }
  
  /// プラン価格を取得
  String getPlanPrice(SubscriptionType plan) {
    return switch (plan) {
      SubscriptionType.free => '¥0',
      SubscriptionType.premium => '¥980/月',
      SubscriptionType.pro => '¥1,980/月',
    };
  }
}
