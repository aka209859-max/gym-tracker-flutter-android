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

  /// バナー広告ID取得（iOS/Android対応）
  static String get bannerAdUnitId {
    // ✅ 修正: kReleaseMode を使用してリリースビルドでは必ず本番広告を表示
    if (kReleaseMode) {
      if (Platform.isIOS) {
        // iOS本番広告ID（TestFlight、App Store）
        return 'ca-app-pub-2887531479031819/1682429555';
      } else if (Platform.isAndroid) {
        // Android本番広告ID（Google Play Store）
        // TODO: 実際のAndroid AdMob IDに置き換える
        return 'ca-app-pub-3940256099942544/6300978111'; // Androidテスト用バナー広告ID
      }
    }
    
    // デバッグビルドのみテスト広告を表示
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOSテスト用バナー広告ID
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Androidテスト用バナー広告ID
    }
    
    return 'ca-app-pub-3940256099942544/2934735716'; // デフォルト
  }

  /// インタースティシャル広告ID取得（iOS/Android対応）
  static String get interstitialAdUnitId {
    // ✅ 修正: kReleaseMode を使用
    if (kReleaseMode) {
      if (Platform.isIOS) {
        // iOS本番インタースティシャル広告ID
        // 現在は未使用のため、テストIDを使用
        return 'ca-app-pub-3940256099942544/4411468910'; // TODO: 本番IDに要変更
      } else if (Platform.isAndroid) {
        // Android本番インタースティシャル広告ID
        // TODO: 実際のAndroid AdMob IDに置き換える
        return 'ca-app-pub-3940256099942544/1033173712'; // Androidテスト用インタースティシャル広告ID
      }
    }
    
    // デバッグビルドのみテスト広告を表示
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOSテスト用インタースティシャル広告ID
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Androidテスト用インタースティシャル広告ID
    }
    
    return 'ca-app-pub-3940256099942544/4411468910'; // デフォルト
  }

  /// リワード広告ID取得（iOS/Android対応）
  static String get rewardedAdUnitId {
    if (kReleaseMode) {
      if (Platform.isIOS) {
        // iOS本番リワード広告ID（AI使用回数+1機能）
        return 'ca-app-pub-2887531479031819/6163055454';
      } else if (Platform.isAndroid) {
        // Android本番リワード広告ID（AI使用回数+1機能）
        // TODO: 実際のAndroid AdMob IDに置き換える
        return 'ca-app-pub-3940256099942544/5224354917'; // Androidテスト用リワード広告ID
      }
    }
    
    // デバッグビルドのみテスト広告を表示
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOSテスト用リワード広告ID
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Androidテスト用リワード広告ID
    }
    
    return 'ca-app-pub-3940256099942544/5224354917'; // デフォルト
  }
}
