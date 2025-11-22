import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob広告管理サービス
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isInitialized = false;

  /// AdMob初期化
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Web環境ではAdMobをスキップ
    if (kIsWeb) {
      print('🌐 Web環境のためAdMob初期化をスキップ');
      _isInitialized = true;
      return;
    }
    
    await MobileAds.instance.initialize();
    _isInitialized = true;
    print('✅ AdMob initialized successfully');
  }

  /// バナー広告ID取得（iOS専用）
  static String get bannerAdUnitId {
    // iOS本番広告ID（無料プラン用）
    return 'ca-app-pub-2887531479031819/1682429555';
  }

  /// インタースティシャル広告ID取得（iOS専用）
  static String get interstitialAdUnitId {
    return 'ca-app-pub-3940256099942544/4411468910';
  }

  /// リワード広告ID取得（iOS専用）
  static String get rewardedAdUnitId {
    // iOS本番リワード広告ID（AI使用回数+1機能）
    return 'ca-app-pub-2887531479031819/6163055454';
  }
}
