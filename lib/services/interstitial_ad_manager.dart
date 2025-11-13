import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// インタースティシャル広告マネージャー
class InterstitialAdManager {
  static final InterstitialAdManager _instance = InterstitialAdManager._internal();
  factory InterstitialAdManager() => _instance;
  InterstitialAdManager._internal();

  InterstitialAd? _interstitialAd;
  bool _isLoaded = false;

  /// 広告を読み込む
  void loadAd() {
    InterstitialAd.load(
      adUnitId: AdService.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoaded = true;
          print('✅ Interstitial ad loaded');

          // 広告が閉じられたら次の広告を読み込む
          _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isLoaded = false;
              loadAd(); // 次の広告を先読み
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ Interstitial ad failed to show: $error');
              ad.dispose();
              _isLoaded = false;
              loadAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('❌ Interstitial ad failed to load: $error');
          _isLoaded = false;
        },
      ),
    );
  }

  /// 広告を表示
  void showAd() {
    if (_isLoaded && _interstitialAd != null) {
      _interstitialAd?.show();
    } else {
      print('⚠️ Interstitial ad is not loaded yet');
      loadAd(); // 読み込みを再試行
    }
  }

  /// 破棄
  void dispose() {
    _interstitialAd?.dispose();
    _isLoaded = false;
  }
}
