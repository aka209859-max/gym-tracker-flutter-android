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
    // デバッグモード時はテスト広告を表示
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Googleテスト用バナー広告ID
    }
    
    // iOS本番広告ID（無料プラン用）
    // AdMobコンソールで作成した実際のバナー広告ユニットIDに置き換えてください
    return 'ca-app-pub-2887531479031819/1682429555';
  }

  /// インタースティシャル広告ID取得（iOS専用）
  static String get interstitialAdUnitId {
    // デバッグモード時はテスト広告を表示
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/4411468910'; // Googleテスト用インタースティシャル広告ID
    }
    
    // iOS本番インタースティシャル広告ID
    // AdMobコンソールで作成した実際のインタースティシャル広告ユニットIDに置き換えてください
    // 現在は未作成のため、テストIDを使用
    return 'ca-app-pub-3940256099942544/4411468910'; // TODO: 本番IDに要変更
  }

  /// リワード広告ID取得（iOS専用）
  static String get rewardedAdUnitId {
    // iOS本番リワード広告ID（AI使用回数+1機能）
    return 'ca-app-pub-2887531479031819/6163055454';
  }
}
