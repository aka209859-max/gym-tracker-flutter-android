import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// 位置情報検索サービス
class LocationService {
  /// 現在地を取得（Web & モバイル対応版）
  Future<Position?> getCurrentLocation() async {
    try {
      debugPrint('📍 位置情報取得開始...');
      debugPrint('   プラットフォーム: ${kIsWeb ? "Web" : "Mobile"}');
      
      // Web環境の特別処理
      if (kIsWeb) {
        debugPrint('🌐 Web環境: ブラウザ位置情報APIを使用');
        
        // Webの場合、権限チェックをスキップして直接取得を試みる
        try {
          debugPrint('🔄 Geolocator.getCurrentPosition() 呼び出し中...');
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('⏱️ Web位置情報取得タイムアウト（10秒）');
              throw TimeoutException('Location timeout');
            },
          );
          debugPrint('✅ Web位置情報取得成功: ${position.latitude}, ${position.longitude}');
          return position;
        } catch (webError) {
          debugPrint('❌ Web位置情報エラー: $webError');
          debugPrint('💡 ヒント: ブラウザで位置情報権限を許可してください');
          return null;
        }
      }
      
      // モバイル環境の処理
      debugPrint('📱 モバイル環境: ネイティブGPS使用');
      
      // 位置情報サービスが有効かチェック
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ 位置情報サービスが無効です');
        debugPrint('💡 ヒント: 端末の設定で位置情報サービスを有効にしてください');
        return null;
      }
      debugPrint('✅ 位置情報サービス: 有効');

      // 位置情報の権限をチェック
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📋 現在の権限ステータス: $permission');
      
      if (permission == LocationPermission.denied) {
        debugPrint('🔔 位置情報権限をリクエスト中...');
        permission = await Geolocator.requestPermission();
        debugPrint('📋 権限リクエスト結果: $permission');
        
        if (permission == LocationPermission.denied) {
          debugPrint('❌ 位置情報権限が拒否されました');
          debugPrint('💡 ヒント: アプリの権限設定で位置情報を許可してください');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ 位置情報権限が永久に拒否されています');
        debugPrint('💡 ヒント: 端末の設定 → アプリ → GYM MATCH → 位置情報を「常に許可」に変更してください');
        return null;
      }

      // 現在地を取得
      debugPrint('🔄 GPS位置情報取得中...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⏱️ GPS位置情報取得タイムアウト（15秒）');
          throw TimeoutException('Location timeout');
        },
      );
      
      debugPrint('✅ GPS位置情報取得成功: ${position.latitude}, ${position.longitude}');
      debugPrint('   精度: ${position.accuracy}m');
      return position;
    } catch (e, stackTrace) {
      debugPrint('❌ 位置情報取得エラー: $e');
      debugPrint('📋 スタックトレース: $stackTrace');
      return null;
    }
  }

  /// 2点間の距離を計算（km）
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// 半径内の判定
  bool isWithinRadius(
    double centerLat,
    double centerLon,
    double targetLat,
    double targetLon,
    double radiusKm,
  ) {
    final distance = calculateDistance(
      centerLat,
      centerLon,
      targetLat,
      targetLon,
    );
    return distance <= radiusKm;
  }

  /// 距離でソート（近い順）
  List<T> sortByDistance<T>({
    required List<T> items,
    required double centerLat,
    required double centerLon,
    required double Function(T) getLatitude,
    required double Function(T) getLongitude,
  }) {
    final sortedItems = List<T>.from(items);
    sortedItems.sort((a, b) {
      final distanceA = calculateDistance(
        centerLat,
        centerLon,
        getLatitude(a),
        getLongitude(a),
      );
      final distanceB = calculateDistance(
        centerLat,
        centerLon,
        getLatitude(b),
        getLongitude(b),
      );
      return distanceA.compareTo(distanceB);
    });
    return sortedItems;
  }

  /// 半径内のアイテムをフィルタリング
  List<T> filterByRadius<T>({
    required List<T> items,
    required double centerLat,
    required double centerLon,
    required double radiusKm,
    required double Function(T) getLatitude,
    required double Function(T) getLongitude,
  }) {
    return items.where((item) {
      return isWithinRadius(
        centerLat,
        centerLon,
        getLatitude(item),
        getLongitude(item),
        radiusKm,
      );
    }).toList();
  }

  /// 距離を人間が読みやすい形式に変換
  String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).toStringAsFixed(0)}m';
    } else {
      return '${distanceKm.toStringAsFixed(1)}km';
    }
  }
}
