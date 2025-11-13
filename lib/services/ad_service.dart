import 'dart:io';
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
    
    await MobileAds.instance.initialize();
    _isInitialized = true;
    print('✅ AdMob initialized successfully');
  }

  /// バナー広告ID取得
  static String get bannerAdUnitId {
    if (Platform.isIOS) {
      // iOS用テスト広告ID（本番環境では実際のIDに置き換える）
      return 'ca-app-pub-3940256099942544/2934735716';
    } else if (Platform.isAndroid) {
      // Android用テスト広告ID
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
      return 'ca-app-pub-3940256099942544/1712485313';
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    throw UnsupportedError('Unsupported platform');
  }
}
