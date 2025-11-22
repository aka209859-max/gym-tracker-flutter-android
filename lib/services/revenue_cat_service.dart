import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'subscription_service.dart';

/// RevenueCat統合サービス - iOS App Store課金管理
/// 
/// 機能:
/// - App Store In-App Purchase管理
/// - サブスクリプション状態同期
/// - Firebase認証との連携
/// - ローカルSubscriptionServiceとの同期
class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();
  
  // RevenueCat API Key (iOS専用)
  static const String _appleApiKey = 'appl_QCxDcuCpNzWsfVJBzIQmBtszjmm';
  
  // Product IDs (App Store Connectで登録する商品ID)
  // 月額プラン
  static const String premiumMonthlyProductId = 'com.nexa.gymmatch.premium.monthly';
  static const String proMonthlyProductId = 'com.nexa.gymmatch.pro.monthly';
  
  // 年額プラン (CEO戦略: 大幅割引で年額選択率向上)
  static const String premiumAnnualProductId = 'com.nexa.gymmatch.premium.annual';  // ¥4,800 (20% OFF)
  static const String proAnnualProductId = 'com.nexa.gymmatch.pro.annual';          // ¥8,000 (32% OFF)
  
  // 追加課金（消耗型 - Consumable）
  static const String aiAdditionalPackProductId = 'com.nexa.gymmatch.ai_pack_5_v2';
  
  // Entitlement IDs (RevenueCatで設定する権限ID)
  static const String premiumEntitlementId = 'premium';
  static const String proEntitlementId = 'pro';
  
  bool _isInitialized = false;
  final SubscriptionService _localSubscriptionService = SubscriptionService();
  
  /// RevenueCat SDKを初期化
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        debugPrint('✅ RevenueCat already initialized');
      }
      return;
    }
    
    try {
      if (kDebugMode) {
        debugPrint('🚀 RevenueCat初期化開始...');
      }
      
      // iOS専用のAPIキー設定
      if (defaultTargetPlatform != TargetPlatform.iOS) {
        if (kDebugMode) {
          debugPrint('⚠️ iOS platform only - RevenueCat not available');
        }
        return;
      }
      
      // Firebase AuthのユーザーIDを設定
      final firebaseUser = FirebaseAuth.instance.currentUser;
      PurchasesConfiguration configuration = PurchasesConfiguration(_appleApiKey);
      
      if (firebaseUser != null) {
        configuration = PurchasesConfiguration(_appleApiKey)..appUserID = firebaseUser.uid;
        if (kDebugMode) {
          debugPrint('👤 Firebase User ID: ${firebaseUser.uid}');
        }
      }
      
      // RevenueCat初期化
      await Purchases.configure(configuration);
      
      // デバッグログ有効化 (リリース時はfalse)
      await Purchases.setLogLevel(LogLevel.debug);
      
      _isInitialized = true;
      
      if (kDebugMode) {
        debugPrint('✅ RevenueCat初期化成功');
      }
      
      // 初回同期
      await syncSubscriptionStatus();
      
      // リスナー設定（購入状態変化を検知）
      _setupPurchaseListener();
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ RevenueCat初期化エラー: $e');
      }
      // 初期化失敗時はローカルモードで動作
    }
  }
  
  /// 購入状態変化リスナーを設定
  void _setupPurchaseListener() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      if (kDebugMode) {
        debugPrint('📱 購入状態が更新されました');
      }
      syncSubscriptionStatus();
    });
  }
  
  /// 現在のサブスクリプション状態を同期
  Future<SubscriptionType> syncSubscriptionStatus() async {
    try {
      if (!_isInitialized) {
        if (kDebugMode) {
          debugPrint('⚠️ RevenueCat not initialized, using local status');
        }
        return await _localSubscriptionService.getCurrentPlan();
      }
      
      // RevenueCatから顧客情報を取得
      final customerInfo = await Purchases.getCustomerInfo();
      
      // Entitlementを確認してプランを判定
      SubscriptionType currentPlan = SubscriptionType.free;
      
      if (customerInfo.entitlements.all[proEntitlementId]?.isActive == true) {
        currentPlan = SubscriptionType.pro;
        if (kDebugMode) {
          debugPrint('✅ Pro Entitlement active');
        }
      } else if (customerInfo.entitlements.all[premiumEntitlementId]?.isActive == true) {
        currentPlan = SubscriptionType.premium;
        if (kDebugMode) {
          debugPrint('✅ Premium Entitlement active');
        }
      } else {
        if (kDebugMode) {
          debugPrint('ℹ️ No active subscription - Free plan');
        }
      }
      
      // ローカルSubscriptionServiceと同期
      await _localSubscriptionService.setPlan(currentPlan);
      
      if (kDebugMode) {
        debugPrint('🔄 Subscription synced: $currentPlan');
      }
      
      return currentPlan;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Subscription sync error: $e');
      }
      // エラー時はローカル状態を返す
      return await _localSubscriptionService.getCurrentPlan();
    }
  }
  
  /// RevenueCatキャッシュを無効化（新商品読み込み用）
  Future<void> invalidateCache() async {
    try {
      if (!_isInitialized) {
        if (kDebugMode) {
          debugPrint('⚠️ RevenueCat not initialized - cannot invalidate cache');
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('🔄 RevenueCatキャッシュを無効化中...');
      }
      
      // CustomerInfoキャッシュを無効化
      await Purchases.invalidateCustomerInfoCache();
      
      if (kDebugMode) {
        debugPrint('✅ RevenueCatキャッシュ無効化完了');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ キャッシュ無効化エラー: $e');
      }
    }
  }
  
  /// 利用可能な商品を取得（キャッシュ無効化オプション付き）
  Future<List<StoreProduct>> getAvailableProducts({bool invalidateCache = false}) async {
    try {
      if (!_isInitialized) {
        throw Exception('RevenueCat not initialized');
      }
      
      // キャッシュ無効化が要求された場合
      if (invalidateCache) {
        await this.invalidateCache();
      }
      
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current == null) {
        if (kDebugMode) {
          debugPrint('⚠️ No offerings available');
        }
        return [];
      }
      
      // 現在のOfferingから商品リストを取得
      final packages = offerings.current!.availablePackages;
      final products = packages.map((package) => package.storeProduct).toList();
      
      if (kDebugMode) {
        debugPrint('📦 Available products: ${products.length}');
        for (var product in products) {
          debugPrint('  - ${product.identifier}: ${product.priceString}');
        }
      }
      
      return products;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to get products: $e');
      }
      return [];
    }
  }
  
  /// サブスクリプションを購入
  Future<bool> purchaseSubscription(String productId) async {
    try {
      if (!_isInitialized) {
        throw Exception('RevenueCat not initialized');
      }
      
      if (kDebugMode) {
        debugPrint('🛒 購入開始: $productId');
      }
      
      // 商品を取得
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        throw Exception('No offerings available');
      }
      
      // Product IDに対応するPackageを検索
      final package = offerings.current!.availablePackages.firstWhere(
        (pkg) => pkg.storeProduct.identifier == productId,
        orElse: () => throw Exception('Product not found: $productId'),
      );
      
      // 購入実行
      final customerInfo = await Purchases.purchasePackage(package);
      
      if (kDebugMode) {
        debugPrint('✅ 購入完了');
      }
      
      // サブスクリプション状態を同期
      await syncSubscriptionStatus();
      
      // 購入成功判定
      final isPro = customerInfo.entitlements.all[proEntitlementId]?.isActive == true;
      final isPremium = customerInfo.entitlements.all[premiumEntitlementId]?.isActive == true;
      
      return isPro || isPremium;
      
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 購入エラー: ${e.code} - ${e.message}');
      }
      
      // ユーザーキャンセルは正常系として扱う
      if (e.code == '1' || e.code == 'purchase_cancelled') {
        if (kDebugMode) {
          debugPrint('ℹ️ ユーザーが購入をキャンセルしました');
        }
        return false;
      }
      
      rethrow;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 予期しない購入エラー: $e');
      }
      rethrow;
    }
  }
  
  /// サブスクリプションを復元
  Future<bool> restorePurchases() async {
    try {
      if (!_isInitialized) {
        throw Exception('RevenueCat not initialized');
      }
      
      if (kDebugMode) {
        debugPrint('🔄 購入履歴を復元中...');
      }
      
      final customerInfo = await Purchases.restorePurchases();
      
      // サブスクリプション状態を同期
      await syncSubscriptionStatus();
      
      // 有効なサブスクリプションがあるか確認
      final hasActiveSub = customerInfo.entitlements.active.isNotEmpty;
      
      if (kDebugMode) {
        if (hasActiveSub) {
          debugPrint('✅ 購入履歴を復元しました');
        } else {
          debugPrint('ℹ️ 復元可能な購入履歴がありません');
        }
      }
      
      return hasActiveSub;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 復元エラー: $e');
      }
      return false;
    }
  }
  
  /// 現在のプランを取得（ローカルサービスから）
  Future<SubscriptionType> getCurrentPlan() async {
    return await _localSubscriptionService.getCurrentPlan();
  }
  
  /// AI機能が使用可能かチェック（ローカルサービス経由）
  Future<bool> canUseAIFeature() async {
    final plan = await _localSubscriptionService.getCurrentPlan();
    return plan != SubscriptionType.free;
  }
  
  /// AI使用回数をインクリメント（ローカルサービス経由）
  Future<bool> incrementAIUsage() async {
    return await _localSubscriptionService.incrementAIUsage();
  }
  
  /// 残りAI使用回数を取得（ローカルサービス経由）
  Future<int> getRemainingAIUsage() async {
    return await _localSubscriptionService.getRemainingAIUsage();
  }
  
  /// AI使用状況メッセージを取得（ローカルサービス経由）
  Future<String> getAIUsageStatus() async {
    return await _localSubscriptionService.getAIUsageStatus();
  }
  
  /// AI追加パックを購入（消耗型アイテム）
  Future<bool> purchaseAIAddon() async {
    try {
      if (!_isInitialized) {
        throw Exception('RevenueCat not initialized');
      }
      
      if (kDebugMode) {
        debugPrint('🛒 AI追加パック購入開始: $aiAdditionalPackProductId');
      }
      
      // 商品を取得
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        throw Exception('No offerings available');
      }
      
      // デバッグ: 利用可能な商品をログ出力
      if (kDebugMode) {
        debugPrint('📦 利用可能な商品一覧:');
        for (var pkg in offerings.current!.availablePackages) {
          debugPrint('  - ${pkg.storeProduct.identifier}: ${pkg.storeProduct.title} (${pkg.storeProduct.priceString})');
        }
      }
      
      // Product IDに対応するPackageを検索
      Package? package;
      try {
        package = offerings.current!.availablePackages.firstWhere(
          (pkg) => pkg.storeProduct.identifier == aiAdditionalPackProductId,
        );
      } catch (e) {
        // 商品が見つからない場合、詳細なエラーメッセージ
        final availableIds = offerings.current!.availablePackages
            .map((pkg) => pkg.storeProduct.identifier)
            .join(', ');
        throw Exception(
          'AI追加パック商品が見つかりません。\n'
          '探している商品ID: $aiAdditionalPackProductId\n'
          '利用可能な商品ID: $availableIds\n\n'
          '対処方法:\n'
          '1. App Store Connectで商品を作成してください\n'
          '2. RevenueCat ConsoleのOfferingsに商品を追加してください'
        );
      }
      
      // 購入実行
      final customerInfo = await Purchases.purchasePackage(package);
      
      if (kDebugMode) {
        debugPrint('✅ AI追加パック購入完了');
      }
      
      // ローカルサービスでAI回数を追加
      await _localSubscriptionService.purchaseAIAddon();
      
      return true;
      
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ AI追加パック購入エラー: ${e.code} - ${e.message}');
      }
      
      // ユーザーキャンセルは正常系として扱う
      if (e.code == '1' || e.code == 'purchase_cancelled') {
        if (kDebugMode) {
          debugPrint('ℹ️ ユーザーが購入をキャンセルしました');
        }
        return false;
      }
      
      rethrow;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 予期しないAI追加パック購入エラー: $e');
      }
      rethrow;
    }
  }
}
