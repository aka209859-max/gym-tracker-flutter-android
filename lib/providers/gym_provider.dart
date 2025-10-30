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
        description: '24時間営業のフィットネスジム。初心者から上級者まで幅広く対応。',
        facilities: ['筋トレマシン', 'ランニングマシン', 'フリーウェイト', 'シャワー'],
        phoneNumber: '03-1234-5678',
        openingHours: '24時間営業',
        monthlyFee: 7980,
        rating: 4.5,
        reviewCount: 128,
        imageUrl: 'https://via.placeholder.com/400x200?text=Anytime+Fitness',
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 2,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      Gym(
        id: '2',
        name: 'ゴールドジム 渋谷東京',
        address: '東京都渋谷区渋谷2-2-2',
        latitude: 35.6598,
        longitude: 139.7035,
        description: '本格的なトレーニング環境を提供する老舗ジム。',
        facilities: ['筋トレマシン', 'フリーウェイト', 'スタジオ', 'サウナ', 'プール'],
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
        description: '総合スポーツクラブ。プールやスタジオプログラムも充実。',
        facilities: ['筋トレマシン', 'プール', 'スタジオ', 'サウナ', 'スパ', 'テニスコート'],
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
        description: '女性専用フィットネスジム。30分のサーキットトレーニング。',
        facilities: ['サーキットマシン', '女性専用', 'ストレッチエリア'],
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
        description: '24時間利用可能な格安フィットネスジム。',
        facilities: ['筋トレマシン', 'ランニングマシン', 'フリーウェイト', 'シャワー'],
        phoneNumber: '03-5678-9012',
        openingHours: '24時間営業',
        monthlyFee: 6980,
        rating: 4.2,
        reviewCount: 67,
        imageUrl: 'https://via.placeholder.com/400x200?text=Joyfit24',
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
        updatedAt: DateTime.now(),
        currentCrowdLevel: 5,
        lastCrowdUpdate: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      Gym(
        id: '6',
        name: 'ティップネス 六本木店',
        address: '東京都港区六本木6-6-6',
        latitude: 35.6627,
        longitude: 139.7290,
        description: '最新設備を完備した都心型フィットネスクラブ。',
        facilities: ['筋トレマシン', 'スタジオ', 'プール', 'ヨガルーム', 'サウナ'],
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
        description: '銀座の中心地にある高級感あふれるフィットネスクラブ。',
        facilities: ['筋トレマシン', 'プール', 'スパ', 'エステ', 'ラウンジ'],
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
        description: '恵比寿駅直結の便利な総合フィットネスクラブ。',
        facilities: ['筋トレマシン', 'スタジオ', 'プール', 'ホットヨガ', 'カフェ'],
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
        description: '秋葉原駅近くの24時間営業ジム。ビジネスマンに人気。',
        facilities: ['筋トレマシン', 'ランニングマシン', 'フリーウェイト', 'シャワー'],
        phoneNumber: '03-9012-3456',
        openingHours: '24時間営業',
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
        description: '完全個室のパーソナルトレーニングジム。結果にコミット。',
        facilities: ['個室トレーニングルーム', 'フリーウェイト', 'シャワー', '専属トレーナー'],
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
        description: '目黒駅徒歩3分。充実した設備とプログラム。',
        facilities: ['筋トレマシン', 'プール', 'スタジオ', 'テニスコート', 'スカッシュ'],
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
        description: '上野エリア最大級の24時間フィットネスジム。',
        facilities: ['筋トレマシン', 'ランニングマシン', 'フリーウェイト', 'ストレッチエリア', 'シャワー'],
        phoneNumber: '03-2345-6781',
        openingHours: '24時間営業',
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
        description: 'アメリカ発の話題のグループトレーニングスタジオ。',
        facilities: ['トレッドミル', 'ローイングマシン', 'フリーウェイト', 'グループスタジオ'],
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
        description: '女性専用30分フィットネス。気軽に通える環境。',
        facilities: ['サーキットマシン', '女性専用', 'ストレッチエリア', '無料体験'],
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
        description: '家族で通える総合スポーツクラブ。キッズスクールも充実。',
        facilities: ['筋トレマシン', 'プール', 'スタジオ', 'キッズルーム', 'スパ', 'テニス'],
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
