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

  /// バナー広告ID取得
  static String get bannerAdUnitId {
    if (Platform.isIOS) {
      // iOS本番広告ID（無料プラン用）
      return 'ca-app-pub-2887531479031819/1682429555';
    } else if (Platform.isAndroid) {
      // Android用テスト広告ID（Android版は未リリース）
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// インタースティシャル広告ID取得
  static String get interstitialAdUnitId {
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// リワード広告ID取得
  static String get rewardedAdUnitId {
    if (Platform.isIOS) {
      // iOS本番リワード広告ID（AI使用回数+1機能）
      return 'ca-app-pub-2887531479031819/6163055454';
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    throw UnsupportedError('Unsupported platform');
  }
}
