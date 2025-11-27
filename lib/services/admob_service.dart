import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'subscription_service.dart';

/// AdMob広告管理サービス
/// 
/// 無料プランのみ広告表示
/// プレミアム/プロプランは広告なし
class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  final SubscriptionService _subscriptionService = SubscriptionService();
  
  // iOS AdMob広告ユニットID
  // ✅ 修正: kReleaseMode を使用してリリースビルドでは必ず本番広告を表示
  static const String _iosBannerAdUnitId = kReleaseMode
      ? 'ca-app-pub-2887531479031819/1682429555' // 本番用（TestFlight、App Store）
      : 'ca-app-pub-3940256099942544/2934735716'; // テスト用（開発中）
  
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isInitialized = false;

  /// AdMob初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Web環境ではAdMobをスキップ（MissingPluginException防止）
    if (kIsWeb) {
      if (kDebugMode) {
        debugPrint('🌐 Web環境のためAdMob初期化をスキップ');
      }
      _isInitialized = true;
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('📱 AdMob初期化開始...');
      }

      await MobileAds.instance.initialize();
      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ AdMob初期化成功');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ AdMob初期化エラー: $e');
      }
    }
  }

  /// バナー広告ユニットIDを取得（iOS専用）
  String get bannerAdUnitId {
    return _iosBannerAdUnitId;
  }

  /// バナー広告を読み込む（無料プランのみ）
  Future<void> loadBannerAd({
    required Function(BannerAd) onAdLoaded,
    Function(Ad, LoadAdError)? onAdFailedToLoad,
  }) async {
    // プラン確認
    final plan = await _subscriptionService.getCurrentPlan();
    
    // 無料プラン以外は広告を表示しない
    if (plan != SubscriptionType.free) {
      if (kDebugMode) {
        debugPrint('ℹ️ 有料プランのため広告なし');
      }
      return;
    }

    // Web環境では広告なし
    if (kIsWeb) {
      if (kDebugMode) {
        debugPrint('ℹ️ Web環境のため広告なし');
      }
      return;
    }

    // 既存の広告を破棄
    _bannerAd?.dispose();
    _isAdLoaded = false;

    try {
      _bannerAd = BannerAd(
        adUnitId: bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            if (kDebugMode) {
              debugPrint('✅ バナー広告読み込み成功');
            }
            _isAdLoaded = true;
            onAdLoaded(ad as BannerAd);
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            if (kDebugMode) {
              debugPrint('❌ バナー広告読み込み失敗: $error');
            }
            _isAdLoaded = false;
            ad.dispose();
            if (onAdFailedToLoad != null) {
              onAdFailedToLoad(ad, error);
            }
          },
          onAdOpened: (Ad ad) {
            if (kDebugMode) {
              debugPrint('📱 バナー広告が開かれました');
            }
          },
          onAdClosed: (Ad ad) {
            if (kDebugMode) {
              debugPrint('📱 バナー広告が閉じられました');
            }
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ バナー広告エラー: $e');
      }
    }
  }

  /// 広告が読み込まれているか
  bool get isAdLoaded => _isAdLoaded;

  /// 現在のバナー広告を取得
  BannerAd? get bannerAd => _bannerAd;

  /// 広告を破棄
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
  }

  /// 無料プランかどうか確認
  Future<bool> shouldShowAds() async {
    final plan = await _subscriptionService.getCurrentPlan();
    return plan == SubscriptionType.free && !kIsWeb;
  }
}
