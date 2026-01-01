import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:purchases_flutter/purchases_flutter.dart'; // ❌ Android版では使用しない

/// プラン種類
enum SubscriptionType {
  free,      // 無料プラン
  premium,   // プレミアムプラン
  pro        // プロプラン
}

/// 有料プラン管理サービス（シングルトン）
/// 
/// 🎯 最適化戦略:
/// - アプリ全体で1つのインスタンスを共有
/// - メモリキャッシュをアプリ起動中保持
/// - 初回取得後は即座にレスポンス（0ms）
class SubscriptionService {
  // ✅ Singleton パターン
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();
  
  static const String _subscriptionKey = 'subscription_status';
  static const String _subscriptionTypeKey = 'subscription_type';
  static const String _cachedPlanKey = 'cached_subscription_plan';
  static const String _cacheTimestampKey = 'cached_plan_timestamp';
  static const int _cacheValidityMinutes = 60; // キャッシュ有効期限: 60分
  
  // 永年プラン（非消耗型IAP）の製品ID
  static const String lifetimeProProductId = 'com.gymmatch.app.lifetime_pro';
  
  // ✅ static メモリキャッシュ（アプリ全体で共有）
  static SubscriptionType? _memoryCache;
  static DateTime? _memoryCacheTimestamp;
  
  /// 永年プラン（非消耗型IAP）を保持しているかチェック
  Future<bool> hasLifetimePlan() async {
    try {
      // 🔧 タイムアウト追加: 5秒以内に取得できない場合はスキップ
      final customerInfo = await Purchases.getCustomerInfo().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏱️ RevenueCat タイムアウト - キャッシュ使用');
          throw TimeoutException('RevenueCat timeout');
        },
      );
      
      // 非消耗型購入履歴から永年プランをチェック
      final hasLifetime = customerInfo.nonSubscriptionTransactions.any(
        (transaction) => transaction.productIdentifier == lifetimeProProductId
      );
      
      if (hasLifetime) {
        print('✅ 永年Proプラン保持者');
        return true;
      }
      
      // Entitlement 'pro' が永年プランで有効化されているかもチェック
      final proEntitlement = customerInfo.entitlements.all['pro'];
      if (proEntitlement?.isActive == true) {
        // 非サブスクリプション（永年プラン）かチェック
        final isSubscription = proEntitlement?.periodType != null;
        if (!isSubscription) {
          print('✅ 永年Proプラン保持者（Entitlement経由）');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('⚠️ 永年プランチェックエラー: $e');
      return false;
    }
  }
  
  /// 現在のプラン種類を取得（Firestore優先、キャッシュフォールバック）
  Future<SubscriptionType> getCurrentPlan() async {
    try {
      // 1. メモリキャッシュチェック（最速）- 最優先
      if (_memoryCache != null && _memoryCacheTimestamp != null) {
        // キャッシュが有効期限内か確認（60分）
        final now = DateTime.now();
        final cacheAge = now.difference(_memoryCacheTimestamp!);
        
        if (cacheAge.inMinutes < _cacheValidityMinutes) {
          print('⚡ メモリキャッシュ使用: $_memoryCache (キャッシュ年齢: ${cacheAge.inMinutes}分)');
          return _memoryCache!;
        } else {
          print('⏰ メモリキャッシュ期限切れ - 再取得');
          _memoryCache = null;
          _memoryCacheTimestamp = null;
        }
      }
      
      // 2. Firestoreから取得を試行（ログインユーザー）
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 🔧 FIX: 匿名ユーザーも含めてFirestoreから取得
        // GYM MATCHは匿名ログインが基本仕様のため、匿名チェック削除
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(
                const Duration(seconds: 3),
                onTimeout: () {
                  print('⏱️ Firestore timeout - キャッシュ使用');
                  throw TimeoutException('Firestore timeout');
                },
              );
          
          if (userDoc.exists) {
            final data = userDoc.data();
            final isPremium = data?['isPremium'] as bool? ?? false;
            final premiumType = data?['premiumType'] as String? ?? 'free';
            
            SubscriptionType plan = SubscriptionType.free;
            
            if (isPremium) {
              if (premiumType == 'pro') {
                plan = SubscriptionType.pro;
                print('✅ Firestoreからプラン取得: プロプラン (UID: ${user.uid}, 匿名: ${user.isAnonymous})');
              } else if (premiumType == 'premium') {
                plan = SubscriptionType.premium;
                print('✅ Firestoreからプラン取得: プレミアムプラン (UID: ${user.uid}, 匿名: ${user.isAnonymous})');
              }
            }
            
            // メモリキャッシュに保存（タイムスタンプ付き）
            _memoryCache = plan;
            _memoryCacheTimestamp = DateTime.now();
            
            // SharedPreferencesキャッシュに保存
            await _savePlanCache(plan);
            
            // 🔧 CRITICAL: RevenueCatチェックは非同期でバックグラウンド実行
            // UIブロックしない + クラッシュを防ぐ
            _checkLifetimePlanInBackground();
            
            return plan;
          }
        } catch (firestoreError) {
          print('⚠️ Firestore取得エラー: $firestoreError');
          // キャッシュにフォールバック
          final cachedPlan = await _loadPlanCache();
          if (cachedPlan != null) {
            print('📦 キャッシュからプラン取得: $cachedPlan');
            _memoryCache = cachedPlan;
            _memoryCacheTimestamp = DateTime.now();
            
            // バックグラウンドでRevenueCatチェック
            _checkLifetimePlanInBackground();
            
            return cachedPlan;
          }
        }
      }
      
      // 3. デフォルト: Freeプラン
      _memoryCache = SubscriptionType.free;
      _memoryCacheTimestamp = DateTime.now();
      
      // バックグラウンドでRevenueCatチェック
      _checkLifetimePlanInBackground();
      
      return SubscriptionType.free;
    } catch (e) {
      print('❌ プラン取得エラー: $e');
      // 最後の手段: キャッシュ
      final cachedPlan = await _loadPlanCache();
      if (cachedPlan != null) {
        print('📦 エラー時キャッシュ使用: $cachedPlan');
        _memoryCache = cachedPlan;
        _memoryCacheTimestamp = DateTime.now();
        return cachedPlan;
      }
      
      _memoryCache = SubscriptionType.free;
      _memoryCacheTimestamp = DateTime.now();
      return SubscriptionType.free;
    }
  }
  
  /// バックグラウンドで永年プランをチェック（非ブロッキング）
  void _checkLifetimePlanInBackground() {
    // UIをブロックしない非同期実行
    Future.delayed(Duration.zero, () async {
      try {
        final hasLifetime = await hasLifetimePlan();
        if (hasLifetime && _memoryCache != SubscriptionType.pro) {
          print('🔄 永年プラン検出 - メモリキャッシュ更新');
          _memoryCache = SubscriptionType.pro;
          _memoryCacheTimestamp = DateTime.now();
          await _savePlanCache(SubscriptionType.pro);
        }
      } catch (e) {
        print('⚠️ バックグラウンド永年プランチェックエラー: $e');
        // エラーは無視（既存のプランを維持）
      }
    });
  }
  
  /// プランをキャッシュに保存
  Future<void> _savePlanCache(SubscriptionType plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedPlanKey, plan.toString().split('.').last);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('⚠️ キャッシュ保存エラー: $e');
    }
  }
  
  /// キャッシュからプランを読み込み（有効期限チェック）
  Future<SubscriptionType?> _loadPlanCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPlanStr = prefs.getString(_cachedPlanKey);
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey);
      
      if (cachedPlanStr != null && cacheTimestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        final cacheAgeMinutes = cacheAge / (1000 * 60);
        
        if (cacheAgeMinutes < _cacheValidityMinutes) {
          // キャッシュが有効
          switch (cachedPlanStr) {
            case 'pro':
              return SubscriptionType.pro;
            case 'premium':
              return SubscriptionType.premium;
            default:
              return SubscriptionType.free;
          }
        } else {
          print('⚠️ キャッシュ期限切れ（${cacheAgeMinutes.toStringAsFixed(1)}分経過）');
        }
      }
    } catch (e) {
      print('⚠️ キャッシュ読み込みエラー: $e');
    }
    return null;
  }
  
  /// キャッシュをクリア
  Future<void> clearCache() async {
    _memoryCache = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedPlanKey);
      await prefs.remove(_cacheTimestampKey);
      print('🗑️ プランキャッシュクリア完了');
    } catch (e) {
      print('⚠️ キャッシュクリアエラー: $e');
    }
  }
  
  /// プランを変更（Firestoreに保存 - RevenueCat購入完了時のみ使用）
  /// ⚠️ この関数は直接呼び出し禁止！RevenueCatServiceからのみ呼び出すこと
  Future<void> setPlan(SubscriptionType plan) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 🔧 FIX: 匿名ユーザーも含めてFirestoreに保存
        // GYM MATCHは匿名ログインが基本仕様のため、匿名チェック削除
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'isPremium': plan != SubscriptionType.free,
          'premiumType': plan.toString().split('.').last,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (kDebugMode) {
          print('✅ Firestoreにプラン保存: $plan (UID: ${user.uid}, 匿名: ${user.isAnonymous})');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ ユーザーが未ログイン - Firestore保存スキップ');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ プラン保存エラー: $e');
      }
    }
  }
  
  /// プランを変更（ブール値を返す）
  /// ⚠️ この関数は直接呼び出し禁止！RevenueCatServiceからのみ呼び出すこと
  Future<bool> changePlan(SubscriptionType plan) async {
    try {
      await setPlan(plan);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ プラン変更エラー: $e');
      }
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
      SubscriptionType.free => AppLocalizations.of(context)!.freePlan,
      SubscriptionType.premium => AppLocalizations.of(context)!.subscription_7669b5d8,
      SubscriptionType.pro => AppLocalizations.of(context)!.subscription_bd2fedf3,
    };
  }
  
  /// プラン説明を取得
  String getPlanDescription(SubscriptionType plan) {
    return switch (plan) {
      SubscriptionType.free => 'ジム検索 + AI混雑度予測 + トレーニング記録 + AI機能月3回',
      SubscriptionType.premium => 'AI機能月20回（AIコーチ・成長予測・効果分析） + お気に入り無制限 + レビュー投稿',
      SubscriptionType.pro => 'AI機能無制限（AIコーチ・成長予測・効果分析） + パートナー検索 + メッセージング',
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
      SubscriptionType.premium => AppLocalizations.of(context)!.subscription_c71bb2e2,
      SubscriptionType.pro => AppLocalizations.of(context)!.subscription_275ce1f5,
    };
  }
  
  /// AI使用回数上限を取得
  /// 
  /// A案フル実装:
  /// - Free: 3回/月（オンボーディング体験用）
  /// - Premium: 20回/月（週5回トレーニング対応）
  /// - Pro: 999回/月（実質無制限、悪用対策で上限設定）
  int getAIUsageLimit(SubscriptionType plan) {
    return switch (plan) {
      SubscriptionType.free => 3,      // 0 → 3回
      SubscriptionType.premium => 20,  // 10 → 20回
      SubscriptionType.pro => 999,     // 30 → 999回（実質無制限）
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
  
  /// AI機能が使用可能かチェック（回数制限含む、追加購入分も含む）
  Future<bool> canUseAIFeature() async {
    final plan = await getCurrentPlan();
    final limit = getAIUsageLimit(plan);
    
    // 無料プランはAI機能なし
    if (limit == 0) {
      return false;
    }
    
    final currentUsage = await getCurrentMonthAIUsage();
    final totalLimit = await getTotalAILimit(); // 追加購入分を含む合計上限
    return currentUsage < totalLimit;
  }
  
  /// 追加購入したAI回数を取得
  Future<int> getAddonAIUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastResetDate = prefs.getString('ai_addon_reset_date');
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      // 月が変わっていたらリセット
      if (lastResetDate != currentMonth) {
        await prefs.setInt('ai_addon_count', 0);
        await prefs.setString('ai_addon_reset_date', currentMonth);
        return 0;
      }
      
      return prefs.getInt('ai_addon_count') ?? 0;
    } catch (e) {
      print('❌ 追加AI回数取得エラー: $e');
      return 0;
    }
  }
  
  /// AI追加パック（¥300で5回分）を1回消費
  Future<bool> consumeAddonAIUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentAddon = await getAddonAIUsage();
      
      if (currentAddon <= 0) {
        print('❌ AI追加パック残回数なし');
        return false;
      }
      
      // 1回消費
      await prefs.setInt('ai_addon_count', currentAddon - 1);
      print('✅ AI追加パック消費: -1 (残り: ${currentAddon - 1}回)');
      return true;
    } catch (e) {
      print('❌ AI追加パック消費エラー: $e');
      return false;
    }
  }
  
  /// AI追加購入（5回パック: ¥300）
  Future<bool> purchaseAIAddon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentAddon = await getAddonAIUsage();
      
      // 追加購入: 5回分を追加
      await prefs.setInt('ai_addon_count', currentAddon + 5);
      
      // 購入履歴を記録（オプション：将来の分析用）
      final now = DateTime.now();
      final purchaseHistory = prefs.getStringList('ai_addon_purchase_history') ?? [];
      purchaseHistory.add('${now.toIso8601String()}:5:100');
      await prefs.setStringList('ai_addon_purchase_history', purchaseHistory);
      
      print('✅ AI追加購入完了: +5回 (合計: ${currentAddon + 5}回)');
      return true;
    } catch (e) {
      print('❌ AI追加購入エラー: $e');
      return false;
    }
  }
  
  /// 合計AI使用上限を取得（プラン + 追加購入）
  Future<int> getTotalAILimit() async {
    final plan = await getCurrentPlan();
    final baseLimit = getAIUsageLimit(plan);
    final addonLimit = await getAddonAIUsage();
    return baseLimit + addonLimit;
  }
  
  /// 残りAI使用回数を取得（追加購入分含む）
  Future<int> getRemainingAIUsage() async {
    final totalLimit = await getTotalAILimit();
    final currentUsage = await getCurrentMonthAIUsage();
    return (totalLimit - currentUsage).clamp(0, totalLimit);
  }
  
  /// AI使用状況メッセージを取得（追加購入分も表示）
  Future<String> getAIUsageStatus() async {
    final plan = await getCurrentPlan();
    final baseLimit = getAIUsageLimit(plan);
    
    if (baseLimit == 0) {
      return AppLocalizations.of(context)!.subscription_34774657;
    }
    
    final currentUsage = await getCurrentMonthAIUsage();
    final addonLimit = await getAddonAIUsage();
    final totalLimit = baseLimit + addonLimit;
    final remaining = totalLimit - currentUsage;
    
    if (remaining <= 0) {
      return '今月のAI使用回数を使い切りました (${currentUsage}/${totalLimit}回)\n💰 追加購入で継続利用可能';
    }
    
    if (addonLimit > 0) {
      return '残り${remaining}回 (${currentUsage}/${totalLimit}回使用)\n※うち追加購入分: ${addonLimit}回';
    }
    
    return '残り${remaining}回 (${currentUsage}/${baseLimit}回使用)';
  }
}
