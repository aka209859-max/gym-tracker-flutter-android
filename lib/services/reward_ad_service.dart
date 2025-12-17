import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ai_credit_service.dart';

/// リワード動画広告サービス（CEO戦略: 動画1回視聴 → AI機能1回追加）
class RewardAdService {
  static final RewardAdService _instance = RewardAdService._internal();
  factory RewardAdService() => _instance;
  RewardAdService._internal();
  
  final AICreditService _creditService = AICreditService();
  
  // AdMob Unit IDs（iOS/Android対応）
  // iOS本番広告ID使用中（収益化有効）
  static const String _iosRewardAdUnitId = 'ca-app-pub-2887531479031819/6163055454'; // 本番用（iOS - AI使用回数+1）
  
  // Android AdMob広告ユニットID（テスト用）
  // TODO: 実際のAndroid AdMob IDに置き換える
  static const String _androidRewardAdUnitId = 'ca-app-pub-3940256099942544/5224354917'; // テスト用（Android - AI使用回数+1）
  
  // テスト用広告ID（開発時のみ使用）
  // static const String _rewardAdUnitId = 'ca-app-pub-3940256099942544/5224354917'; // テスト用（iOS）
  
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  bool _isAdReady = false;
  int _retryAttempt = 0;
  static const int _maxRetryAttempt = 3;
  
  /// AdMob SDKを初期化
  Future<void> initialize() async {
    // Web環境ではAdMobをスキップ
    if (kIsWeb) {
      debugPrint('🌐 Web環境のためAdMob初期化をスキップ');
      return;
    }
    
    try {
      debugPrint('🎬 リワード広告初期化開始...');
      debugPrint('🎬 リワード広告ID: $_rewardAdUnitId');
      debugPrint('🎬 ビルドモード: ${kReleaseMode ? "Release" : "Debug"}');
      
      await MobileAds.instance.initialize();
      debugPrint('✅ リワード広告SDK初期化成功');
    } catch (e) {
      debugPrint('❌ リワード広告初期化エラー: $e');
    }
  }
  
  /// リワード動画広告ユニットIDを取得（iOS/Android対応）
  String get _rewardAdUnitId {
    if (Platform.isIOS) {
      return _iosRewardAdUnitId;
    } else if (Platform.isAndroid) {
      return _androidRewardAdUnitId;
    }
    return _iosRewardAdUnitId; // デフォルト
  }
  
  /// リワード動画広告を読み込み
  Future<void> loadRewardedAd() async {
    if (_isAdLoading || _isAdReady) {
      return;
    }
    
    _isAdLoading = true;
    
    try {
      await RewardedAd.load(
        adUnitId: _rewardAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('✅ リワード広告読み込み成功');
            debugPrint('   広告ID: $_rewardAdUnitId');
            _rewardedAd = ad;
            _isAdReady = true;
            _isAdLoading = false;
            _retryAttempt = 0;  // リトライカウンターをリセット
            
            // 広告イベントリスナー設定
            _setupAdCallbacks(ad);
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ [AdMob] リワード広告読み込み失敗');
            debugPrint('   広告ID: $_rewardAdUnitId');
            debugPrint('   エラーコード: ${error.code}');
            debugPrint('   エラー内容: ${error.message}');
            debugPrint('   ドメイン: ${error.domain}');
            debugPrint('   レスポンス情報: ${error.responseInfo}');
            _isAdLoading = false;
            _isAdReady = false;
            
            // リトライロジック追加（収益最大化のため）
            _retryAttempt++;
            if (_retryAttempt < _maxRetryAttempt) {
              debugPrint('🔄 リワード広告リトライ: $_retryAttempt/$_maxRetryAttempt');
              // 指数バックオフでリトライ（1秒、2秒、4秒...）
              Future.delayed(Duration(seconds: 1 << (_retryAttempt - 1)), () {
                loadRewardedAd();
              });
            } else {
              debugPrint('⚠️ リワード広告リトライ上限到達（$_maxRetryAttempt回）');
              // リトライカウンターをリセット（次回のためトライに備える）
              Future.delayed(const Duration(minutes: 5), () {
                _retryAttempt = 0;
                debugPrint('🔄 リワード広告リトライカウンターリセット');
              });
            }
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ loadRewardedAd error: $e');
      }
      _isAdLoading = false;
    }
  }
  
  /// 広告イベントリスナーを設定
  void _setupAdCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) {
          debugPrint('📺 Rewarded ad showed full screen');
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) {
          debugPrint('📺 Rewarded ad dismissed');
        }
        ad.dispose();
        _rewardedAd = null;
        _isAdReady = false;
        
        // 次の広告を事前ロード
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          debugPrint('❌ Rewarded ad failed to show: $error');
        }
        ad.dispose();
        _rewardedAd = null;
        _isAdReady = false;
        
        // エラー後も次の広告を試行
        loadRewardedAd();
      },
    );
  }
  
  /// リワード動画広告を表示（成功時にAIクレジット付与）
  Future<bool> showRewardedAd() async {
    if (!_isAdReady || _rewardedAd == null) {
      if (kDebugMode) {
        debugPrint('⚠️ Rewarded ad not ready');
      }
      return false;
    }
    
    bool rewardGranted = false;
    
    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) async {
          if (kDebugMode) {
            debugPrint('🎁 User earned reward: ${reward.amount} ${reward.type}');
          }
          
          // AI機能1回分のクレジットを付与
          await _creditService.addAICredit(1);
          await _creditService.recordAdEarned();
          rewardGranted = true;
        },
      );
      
      return rewardGranted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ showRewardedAd error: $e');
      }
      return false;
    }
  }
  
  /// 広告が準備完了か
  bool isAdReady() {
    return _isAdReady && _rewardedAd != null;
  }
  
  /// サービスを破棄
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdReady = false;
  }
}
