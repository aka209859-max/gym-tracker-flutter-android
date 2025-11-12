import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

/// AdMobバナー広告ウィジェット
/// 
/// 無料プランのみ表示
/// 画面下部に固定表示
class AdMobBanner extends StatefulWidget {
  const AdMobBanner({super.key});

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  final AdMobService _adMobService = AdMobService();
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _shouldShowAds = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadAd();
  }

  Future<void> _checkAndLoadAd() async {
    // 広告表示すべきか確認
    _shouldShowAds = await _adMobService.shouldShowAds();
    
    if (!_shouldShowAds) {
      return;
    }

    // 広告読み込み
    await _adMobService.loadBannerAd(
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() {
            _bannerAd = ad;
            _isLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        if (mounted) {
          setState(() {
            _isLoaded = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 広告なし or 読み込み失敗
    if (!_shouldShowAds || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    // バナー広告表示
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: 60,
      child: Center(
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
