import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/gym.dart';

/// お気に入りジム管理サービス
class FavoritesService {
  static const String _favoritesKey = 'favorite_gyms';
  
  /// お気に入りジムのIDリストを取得
  Future<List<String>> getFavoriteIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getString(_favoritesKey);
      
      if (favoritesJson == null) {
        return [];
      }
      
      final List<dynamic> favoritesList = json.decode(favoritesJson);
      return favoritesList.map((e) => e.toString()).toList();
    } catch (e) {
      print('❌ お気に入り取得エラー: $e');
      return [];
    }
  }
  
  /// お気に入りジムの詳細情報を取得
  Future<List<Map<String, dynamic>>> getFavoriteGyms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gymsJson = prefs.getString('${_favoritesKey}_details');
      
      if (gymsJson == null) {
        return [];
      }
      
      final List<dynamic> gymsList = json.decode(gymsJson);
      return gymsList.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print('❌ お気に入り詳細取得エラー: $e');
      return [];
    }
  }
  
  /// お気に入りに追加
  Future<bool> addFavorite(Gym gym) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // IDリストを更新
      final favoriteIds = await getFavoriteIds();
      if (!favoriteIds.contains(gym.id)) {
        favoriteIds.add(gym.id);
        await prefs.setString(_favoritesKey, json.encode(favoriteIds));
      }
      
      // 詳細情報を更新
      final favoriteGyms = await getFavoriteGyms();
      
      // 既存のジムを削除（重複防止）
      favoriteGyms.removeWhere((g) => g['id'] == gym.id);
      
      // 新しいジムを追加
      favoriteGyms.add({
        'id': gym.id,
        'name': gym.name,
        'address': gym.address,
        'latitude': gym.latitude,
        'longitude': gym.longitude,
        'rating': gym.rating,
        'reviewCount': gym.reviewCount,
        'currentCrowdLevel': gym.currentCrowdLevel,
        'monthlyFee': gym.monthlyFee,
        'imageUrl': gym.imageUrl,
        'facilities': gym.facilities,
        'phoneNumber': gym.phoneNumber,
        'openingHours': gym.openingHours,
        'addedAt': DateTime.now().toIso8601String(),
      });
      
      await prefs.setString('${_favoritesKey}_details', json.encode(favoriteGyms));
      
      print('✅ お気に入り追加: ${gym.name}');
      return true;
    } catch (e) {
      print('❌ お気に入り追加エラー: $e');
      return false;
    }
  }
  
  /// お気に入りから削除
  Future<bool> removeFavorite(String gymId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // IDリストから削除
      final favoriteIds = await getFavoriteIds();
      favoriteIds.remove(gymId);
      await prefs.setString(_favoritesKey, json.encode(favoriteIds));
      
      // 詳細情報から削除
      final favoriteGyms = await getFavoriteGyms();
      favoriteGyms.removeWhere((g) => g['id'] == gymId);
      await prefs.setString('${_favoritesKey}_details', json.encode(favoriteGyms));
      
      print('✅ お気に入り削除: $gymId');
      return true;
    } catch (e) {
      print('❌ お気に入り削除エラー: $e');
      return false;
    }
  }
  
  /// 指定ジムがお気に入りかチェック
  Future<bool> isFavorite(String gymId) async {
    final favoriteIds = await getFavoriteIds();
    return favoriteIds.contains(gymId);
  }
  
  /// お気に入り件数を取得
  Future<int> getFavoriteCount() async {
    final favoriteIds = await getFavoriteIds();
    return favoriteIds.length;
  }
  
  /// すべてのお気に入りをクリア
  Future<void> clearAllFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
    await prefs.remove('${_favoritesKey}_details');
    print('✅ お気に入りをすべてクリア');
  }
}
