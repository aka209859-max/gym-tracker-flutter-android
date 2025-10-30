import 'package:geolocator/geolocator.dart';

/// 位置情報検索サービス
class LocationService {
  /// 現在地を取得
  Future<Position?> getCurrentLocation() async {
    try {
      // 位置情報サービスが有効かチェック
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // 位置情報の権限をチェック
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // 現在地を取得
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
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
