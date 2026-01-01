import 'package:flutter/foundation.dart';
import '../models/gym.dart';

/// ジムデータを管理するプロバイダー
class GymProvider with ChangeNotifier {
  // サンプルデータ（Firebase連携前のMockデータ）
  List<Gym> _gyms = [];
  Gym? _selectedGym;

  List<Gym> get gyms => _gyms;
  Gym? get selectedGym => _selectedGym;

  GymProvider() {
    _loadSampleData();
  }

  /// サンプルデータの読み込み（開発用）
  void _loadSampleData() {
    _gyms = [
      Gym(
        id: '1',
        name: 'エニタイムフィットネス 新宿店',
        address: '東京都新宿区西新宿1-1-1',
        latitude: 35.6895,
        longitude: 139.7006,
        description: AppLocalizations.of(context)!.gym_ec2f08b5,
        facilities: [AppLocalizations.of(context)!.gym_bbedccb4, AppLocalizations.of(context)!.gym_40e07129, AppLocalizations.of(context)!.gym_8c573aed, AppLocalizations.of(context)!.gym_f7efcddd],
        phoneNumber: '03-1234-5678',
        openingHours: AppLocalizations.of(context)!.gym_fc767436,
        monthlyFee: 7980,
        rating: 4.5,
        reviewCount: 128,
        imageUrl: 'https://via.placeholder.com/400x200?text=Anytime+Fitness',
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 2,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 15)),
        isPartner: true,  // β版パートナー
        partnerBenefit: AppLocalizations.of(context)!.gym_b6f4f89a,
        partnerSince: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Gym(
        id: '2',
        name: 'ゴールドジム 渋谷東京',
        address: '東京都渋谷区渋谷2-2-2',
        latitude: 35.6598,
        longitude: 139.7035,
        description: AppLocalizations.of(context)!.gym_092b7e38,
        facilities: [AppLocalizations.of(context)!.gym_bbedccb4, AppLocalizations.of(context)!.gym_8c573aed, AppLocalizations.of(context)!.gym_10968243, AppLocalizations.of(context)!.gym_d816d814, AppLocalizations.of(context)!.gym_62b8a10f],
        phoneNumber: '03-2345-6789',
        openingHours: '月-金 7:00-23:00, 土日 9:00-21:00',
        monthlyFee: 13200,
        rating: 4.7,
        reviewCount: 256,
        imageUrl: 'https://via.placeholder.com/400x200?text=Gold+Gym',
        createdAt: DateTime.now().subtract(const Duration(days: 730)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 4,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      Gym(
        id: '3',
        name: 'コナミスポーツクラブ 池袋',
        address: '東京都豊島区東池袋3-3-3',
        latitude: 35.7295,
        longitude: 139.7190,
        description: AppLocalizations.of(context)!.gym_763628c5,
        facilities: [AppLocalizations.of(context)!.gym_bbedccb4, AppLocalizations.of(context)!.gym_62b8a10f, AppLocalizations.of(context)!.gym_10968243, AppLocalizations.of(context)!.gym_d816d814, AppLocalizations.of(context)!.gym_a88b1eac, AppLocalizations.of(context)!.gym_dcf4ca1a],
        phoneNumber: '03-3456-7890',
        openingHours: '月-金 10:00-23:00, 土日祝 10:00-21:00',
        monthlyFee: 10890,
        rating: 4.3,
        reviewCount: 89,
        imageUrl: 'https://via.placeholder.com/400x200?text=Konami+Sports',
        createdAt: DateTime.now().subtract(const Duration(days: 500)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 3,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
      Gym(
        id: '4',
        name: 'カーブス 中野店',
        address: '東京都中野区中野4-4-4',
        latitude: 35.7072,
        longitude: 139.6656,
        description: AppLocalizations.of(context)!.gym_a8504442,
        facilities: [AppLocalizations.of(context)!.gym_dd5a565b, AppLocalizations.of(context)!.gym_07c18f38, AppLocalizations.of(context)!.gym_7d1e3afa],
        phoneNumber: '03-4567-8901',
        openingHours: '月-金 10:00-19:00, 土 10:00-13:00',
        monthlyFee: 6820,
        rating: 4.6,
        reviewCount: 142,
        imageUrl: 'https://via.placeholder.com/400x200?text=Curves',
        createdAt: DateTime.now().subtract(const Duration(days: 300)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 1,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      Gym(
        id: '5',
        name: 'ジョイフィット24 品川',
        address: '東京都港区高輪5-5-5',
        latitude: 35.6284,
        longitude: 139.7387,
        description: AppLocalizations.of(context)!.gym_38edf7d0,
        facilities: [AppLocalizations.of(context)!.gym_bbedccb4, AppLocalizations.of(context)!.gym_40e07129, AppLocalizations.of(context)!.gym_8c573aed, AppLocalizations.of(context)!.gym_f7efcddd],
        phoneNumber: '03-5678-9012',
        openingHours: AppLocalizations.of(context)!.gym_fc767436,
        monthlyFee: 6980,
        rating: 4.2,
        reviewCount: 67,
        imageUrl: 'https://via.placeholder.com/400x200?text=Joyfit24',
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 5,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 2)),
        isPartner: true,  // β版パートナー
        partnerBenefit: AppLocalizations.of(context)!.gym_3158b409,
        partnerSince: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Gym(
        id: '6',
        name: 'ティップネス 六本木店',
        address: '東京都港区六本木6-6-6',
        latitude: 35.6627,
        longitude: 139.7290,
        description: AppLocalizations.of(context)!.gym_34829df4,
        facilities: [AppLocalizations.of(context)!.gym_bbedccb4, AppLocalizations.of(context)!.gym_10968243, AppLocalizations.of(context)!.gym_62b8a10f, AppLocalizations.of(context)!.gym_20dd1bba, AppLocalizations.of(context)!.gym_d816d814],
        phoneNumber: '03-6789-0123',
        openingHours: '平日 7:00-23:00, 土日 9:00-21:00',
        monthlyFee: 12800,
        rating: 4.4,
        reviewCount: 178,
        imageUrl: 'https://via.placeholder.com/400x200?text=Tipness',
        createdAt: DateTime.now().subtract(const Duration(days: 450)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 3,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
      Gym(
        id: '7',
        name: 'セントラルスポーツ 銀座',
        address: '東京都中央区銀座7-7-7',
        latitude: 35.6719,
        longitude: 139.7646,
        description: AppLocalizations.of(context)!.gym_1276beee,
        facilities: [AppLocalizations.of(context)!.gym_bbedccb4, AppLocalizations.of(context)!.gym_62b8a10f, AppLocalizations.of(context)!.gym_a88b1eac, AppLocalizations.of(context)!.gym_80c121ca, AppLocalizations.of(context)!.gym_5c9c780e],
        phoneNumber: '03-7890-1234',
        openingHours: '平日 9:00-23:00, 土日 9:00-20:00',
        monthlyFee: 15400,
        rating: 4.8,
        reviewCount: 312,
        imageUrl: 'https://via.placeholder.com/400x200?text=Central+Sports',
        createdAt: DateTime.now().subtract(const Duration(days: 800)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 2,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
      Gym(
        id: '8',
        name: 'ルネサンス 恵比寿',
        address: '東京都渋谷区恵比寿8-8-8',
        latitude: 35.6467,
        longitude: 139.7109,
        description: AppLocalizations.of(context)!.gym_94a329e3,
        facilities: [AppLocalizations.of(context)!.gym_bbedccb4, AppLocalizations.of(context)!.gym_10968243, AppLocalizations.of(context)!.gym_62b8a10f, AppLocalizations.of(context)!.gym_058c8bd6, AppLocalizations.of(context)!.gym_71edef7e],
        phoneNumber: '03-8901-2345',
        openingHours: '平日 7:00-23:30, 土日 10:00-20:00',
        monthlyFee: 11900,
        rating: 4.5,
        reviewCount: 203,
        imageUrl: 'https://via.placeholder.com/400x200?text=Renaissance',
        createdAt: DateTime.now().subtract(const Duration(days: 600)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 4,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      Gym(
        id: '9',
        name: 'エニタイムフィットネス 秋葉原店',
        address: '東京都千代田区外神田9-9-9',
        latitude: 35.6984,
        longitude: 139.7731,
        description: AppLocalizations.of(context)!.gym_76bacc99,
        facilities: [AppLocalizations.of(context)!.gym_bbedccb4, AppLocalizations.of(context)!.gym_40e07129, AppLocalizations.of(context)!.gym_8c573aed, AppLocalizations.of(context)!.gym_f7efcddd],
        phoneNumber: '03-9012-3456',
        openingHours: AppLocalizations.of(context)!.gym_fc767436,
        monthlyFee: 7980,
        rating: 4.3,
        reviewCount: 145,
        imageUrl: 'https://via.placeholder.com/400x200?text=Anytime+Akihabara',
        createdAt: DateTime.now().subtract(const Duration(days: 280)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 3,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 18)),
      ),
      Gym(
        id: '10',
        name: 'ライザップ 表参道店',
        address: '東京都港区南青山10-10-10',
        latitude: 35.6650,
        longitude: 139.7123,
        description: AppLocalizations.of(context)!.gym_7ca88384,
        facilities: [AppLocalizations.of(context)!.gym_b12ef7f1, AppLocalizations.of(context)!.gym_8c573aed, AppLocalizations.of(context)!.gym_f7efcddd, AppLocalizations.of(context)!.gym_a28954a8],
        phoneNumber: '03-0123-4567',
        openingHours: '7:00-23:00（完全予約制）',
        monthlyFee: 149600,
        rating: 4.9,
        reviewCount: 89,
        imageUrl: 'https://via.placeholder.com/400x200?text=RIZAP',
        createdAt: DateTime.now().subtract(const Duration(days: 550)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 1,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
      Gym(
        id: '11',
        name: 'メガロス 目黒',
        address: '東京都品川区上大崎11-11-11',
        latitude: 35.6331,
        longitude: 139.7157,
        description: AppLocalizations.of(context)!.gym_8e1a98a4,
        facilities: [AppLocalizations.of(context)!.gym_bbedccb4, AppLocalizations.of(context)!.gym_62b8a10f, AppLocalizations.of(context)!.gym_10968243, AppLocalizations.of(context)!.gym_dcf4ca1a, AppLocalizations.of(context)!.gym_39863992],
        phoneNumber: '03-1234-5670',
        openingHours: '平日 9:00-23:00, 土日 9:00-21:00',
        monthlyFee: 13500,
        rating: 4.6,
        reviewCount: 187,
        imageUrl: 'https://via.placeholder.com/400x200?text=Megalos',
        createdAt: DateTime.now().subtract(const Duration(days: 650)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 2,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 7)),
      ),
      Gym(
        id: '12',
        name: 'ボディメイクジム24 上野',
        address: '東京都台東区上野12-12-12',
        latitude: 35.7074,
        longitude: 139.7748,
        description: AppLocalizations.of(context)!.gym_23779be0,
        facilities: [AppLocalizations.of(context)!.gym_bbedccb4, AppLocalizations.of(context)!.gym_40e07129, AppLocalizations.of(context)!.gym_8c573aed, AppLocalizations.of(context)!.gym_7d1e3afa, AppLocalizations.of(context)!.gym_f7efcddd],
        phoneNumber: '03-2345-6781',
        openingHours: AppLocalizations.of(context)!.gym_fc767436,
        monthlyFee: 6500,
        rating: 4.1,
        reviewCount: 112,
        imageUrl: 'https://via.placeholder.com/400x200?text=BodyMake24',
        createdAt: DateTime.now().subtract(const Duration(days: 220)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 4,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 6)),
      ),
      Gym(
        id: '13',
        name: 'オレンジセオリーフィットネス 赤坂',
        address: '東京都港区赤坂13-13-13',
        latitude: 35.6741,
        longitude: 139.7370,
        description: AppLocalizations.of(context)!.gym_2caec863,
        facilities: [AppLocalizations.of(context)!.workout_8308db37, AppLocalizations.of(context)!.workout_4c6d7db7, AppLocalizations.of(context)!.gym_8c573aed, AppLocalizations.of(context)!.gym_1c7af5f8],
        phoneNumber: '03-3456-7892',
        openingHours: '平日 6:00-22:00, 土日 7:00-19:00',
        monthlyFee: 18700,
        rating: 4.7,
        reviewCount: 156,
        imageUrl: 'https://via.placeholder.com/400x200?text=Orangetheory',
        createdAt: DateTime.now().subtract(const Duration(days: 180)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 3,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 14)),
      ),
      Gym(
        id: '14',
        name: 'カーブス 吉祥寺店',
        address: '東京都武蔵野市吉祥寺14-14-14',
        latitude: 35.7032,
        longitude: 139.5796,
        description: AppLocalizations.of(context)!.gym_79a4ea0b,
        facilities: [AppLocalizations.of(context)!.gym_dd5a565b, AppLocalizations.of(context)!.gym_07c18f38, AppLocalizations.of(context)!.gym_7d1e3afa, AppLocalizations.of(context)!.gym_2dbe0d1d],
        phoneNumber: '03-4567-8903',
        openingHours: '平日 10:00-19:00, 土 10:00-13:00',
        monthlyFee: 6820,
        rating: 4.5,
        reviewCount: 198,
        imageUrl: 'https://via.placeholder.com/400x200?text=Curves+Kichijoji',
        createdAt: DateTime.now().subtract(const Duration(days: 320)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 1,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 22)),
      ),
      Gym(
        id: '15',
        name: 'スポーツクラブNAS 世田谷',
        address: '東京都世田谷区三軒茶屋15-15-15',
        latitude: 35.6435,
        longitude: 139.6693,
        description: AppLocalizations.of(context)!.gym_58208487,
        facilities: [AppLocalizations.of(context)!.gym_bbedccb4, AppLocalizations.of(context)!.gym_62b8a10f, AppLocalizations.of(context)!.gym_10968243, AppLocalizations.of(context)!.gym_0004c949, AppLocalizations.of(context)!.gym_a88b1eac, AppLocalizations.of(context)!.gym_16e3b961],
        phoneNumber: '03-5678-9014',
        openingHours: '平日 10:00-23:00, 土日 10:00-21:00',
        monthlyFee: 10200,
        rating: 4.4,
        reviewCount: 224,
        imageUrl: 'https://via.placeholder.com/400x200?text=NAS+Setagaya',
        createdAt: DateTime.now().subtract(const Duration(days: 720)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 2,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 11)),
      ),
      // トレーニーの聖地
      Gym(
        id: '16',
        name: AppLocalizations.of(context)!.gym_15550205,
        address: '静岡県藤枝市末広4丁目1-17',
        latitude: 34.8660,
        longitude: 138.2589,
        description: AppLocalizations.of(context)!.gym_9e69a1ab,
        facilities: [AppLocalizations.of(context)!.gym_8c573aed, AppLocalizations.of(context)!.gym_831d90bb, AppLocalizations.of(context)!.gym_66c39f64, AppLocalizations.of(context)!.gym_20d0208a],
        phoneNumber: '054-635-2775',
        openingHours: AppLocalizations.of(context)!.gym_bd086df3,
        monthlyFee: 15000,
        rating: 4.7,
        reviewCount: 10,
        imageUrl: 'https://via.placeholder.com/400x200?text=Muscle+House+GYM',
        createdAt: DateTime.now().subtract(const Duration(days: 1500)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 2,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Gym(
        id: '17',
        name: AppLocalizations.of(context)!.gym_14215715,
        address: '愛知県名古屋市港区明正1丁目200 県番地',
        latitude: 35.0806,
        longitude: 136.8664,
        description: AppLocalizations.of(context)!.gym_cc63c897,
        facilities: [AppLocalizations.of(context)!.gym_5deb4820, AppLocalizations.of(context)!.gym_9dfb4ae1, AppLocalizations.of(context)!.gym_b666873b, AppLocalizations.of(context)!.gym_d66d5351],
        phoneNumber: '052-746-7210',
        openingHours: AppLocalizations.of(context)!.gym_fc4491c1,
        monthlyFee: 12000,
        rating: 4.8,
        reviewCount: 45,
        imageUrl: 'https://via.placeholder.com/400x200?text=Jurassic+Academy',
        createdAt: DateTime.now().subtract(const Duration(days: 2000)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 3,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
    ];
    notifyListeners();
  }

  /// ジムを選択
  void selectGym(Gym gym) {
    _selectedGym = gym;
    notifyListeners();
  }

  /// 選択をクリア
  void clearSelection() {
    _selectedGym = null;
    notifyListeners();
  }

  /// 混雑度でフィルタリング
  List<Gym> getGymsByCrowdLevel(int maxLevel) {
    return _gyms.where((gym) => gym.currentCrowdLevel <= maxLevel).toList();
  }

  /// 評価でソート
  List<Gym> getGymsSortedByRating() {
    final sorted = List<Gym>.from(_gyms);
    sorted.sort((a, b) => b.rating.compareTo(a.rating));
    return sorted;
  }

  /// 混雑度を更新
  void updateCrowdLevel(String gymId, int crowdLevel) {
    final index = _gyms.indexWhere((gym) => gym.id == gymId);
    if (index != -1) {
      _gyms[index].currentCrowdLevel = crowdLevel;
      _gyms[index].lastCrowdUpdate = DateTime.now();
      notifyListeners();
    }
  }

  /// テキスト検索（名前・住所）
  List<Gym> searchGyms(String query) {
    if (query.isEmpty) return _gyms;
    
    final lowerQuery = query.toLowerCase();
    return _gyms.where((gym) {
      return gym.name.toLowerCase().contains(lowerQuery) ||
          gym.address.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// 地域で検索
  List<Gym> searchByArea(String area) {
    if (area.isEmpty) return _gyms;
    
    return _gyms.where((gym) {
      return gym.address.contains(area);
    }).toList();
  }
}
