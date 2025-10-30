import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/gym_provider.dart';
import '../models/gym.dart';
import '../models/google_place.dart';
import '../services/location_service.dart';
import '../services/google_places_service.dart';
import 'gym_detail_screen.dart';
import 'search_screen.dart';

/// マップ画面（Web版ではリスト表示、将来的にGoogle Maps統合）
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _crowdFilter = 5; // 混雑度フィルター（1-5）
  
  // GPS検索関連
  final LocationService _locationService = LocationService();
  final GooglePlacesService _placesService = GooglePlacesService();
  List<GooglePlace> _nearbyPlaces = [];
  bool _isLoadingGPS = false;
  Position? _userPosition;
  bool _hasSearchedGPS = false;

  @override
  void initState() {
    super.initState();
    // アプリ起動後にGPS検索ダイアログを表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowLocationDialog();
    });
  }

  /// 位置情報ダイアログの表示チェック
  Future<void> _checkAndShowLocationDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAskedBefore = prefs.getBool('location_permission_asked') ?? false;
      
      if (!hasAskedBefore && mounted) {
        _showLocationPermissionDialog();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to check location dialog status: $e');
      }
    }
  }

  /// 位置情報使用の確認ダイアログ
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 8),
            Text('位置情報を使用しますか？'),
          ],
        ),
        content: const Text(
          'あなたの近くのジムを検索するために位置情報を使用します。\n\n'
          '※位置情報は検索のみに使用され、保存されません。',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('location_permission_asked', true);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('後で'),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('location_permission_asked', true);
              if (mounted) {
                Navigator.pop(context);
                _acquireLocationAndSearch();
              }
            },
            child: const Text('はい、使用します'),
          ),
        ],
      ),
    );
  }

  /// GPS位置取得 + 近くのジム検索
  Future<void> _acquireLocationAndSearch() async {
    setState(() {
      _isLoadingGPS = true;
    });

    try {
      if (kDebugMode) {
        debugPrint('🌍 GPS位置情報を取得中...');
      }

      final position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('位置情報の取得に失敗しました。設定で位置情報を有効にしてください。'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoadingGPS = false;
        });
        return;
      }

      if (kDebugMode) {
        debugPrint('✅ GPS取得成功: ${position.latitude}, ${position.longitude}');
      }

      // 近くのジムを検索（半径5km）
      final places = await _placesService.searchNearbyGyms(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: 5000,
      );

      if (kDebugMode) {
        debugPrint('✅ 検索完了: ${places.length}件のジムが見つかりました');
      }

      setState(() {
        _userPosition = position;
        _nearbyPlaces = places;
        _isLoadingGPS = false;
        _hasSearchedGPS = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${places.length}件のジムが見つかりました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ GPS検索エラー: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('検索に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      setState(() {
        _isLoadingGPS = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ジムマップ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // GPS検索ステータスバナー
          if (!_hasSearchedGPS && !_isLoadingGPS)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '現在地周辺のジムを検索するには、下の「現在地」ボタンをタップ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // GPS検索中インジケーター
          if (_isLoadingGPS)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.green.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '現在地を取得中... 近くのジムを検索しています',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // GPS検索成功バナー
          if (_hasSearchedGPS && !_isLoadingGPS && _nearbyPlaces.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.green.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'あなたの近くのジム ${_nearbyPlaces.length}件を表示中',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // ジムリスト表示エリア
          Expanded(
            child: _hasSearchedGPS
                ? _buildGPSSearchResults()
                : _buildSampleGyms(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoadingGPS ? null : _acquireLocationAndSearch,
        icon: _isLoadingGPS
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.my_location),
        label: Text(_isLoadingGPS ? '検索中...' : '現在地'),
      ),
    );
  }

  /// GPS検索結果を表示
  Widget _buildGPSSearchResults() {
    if (_nearbyPlaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '近くにジムが見つかりませんでした',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _acquireLocationAndSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('再検索'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _nearbyPlaces.length,
      itemBuilder: (context, index) {
        return _buildGooglePlaceCard(_nearbyPlaces[index]);
      },
    );
  }

  /// サンプルジム一覧を表示（GPS検索前）
  Widget _buildSampleGyms() {
    return Consumer<GymProvider>(
      builder: (context, provider, child) {
        final filteredGyms = provider.getGymsByCrowdLevel(_crowdFilter);

        if (filteredGyms.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  '条件に一致するジムが見つかりません',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // 混雑度フィルターバー
            _buildCrowdFilterBar(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredGyms.length,
                itemBuilder: (context, index) {
                  return _buildGymCard(filteredGyms[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// GooglePlaceカード（GPS検索結果用）
  Widget _buildGooglePlaceCard(GooglePlace place) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: GooglePlace用の詳細画面に遷移
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${place.name} の詳細画面（近日公開）')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ジム画像
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: place.photoReference != null
                    ? Image.network(
                        _placesService.getPhotoUrl(place.photoReference!),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage();
                        },
                      )
                    : _buildPlaceholderImage(),
              ),
              const SizedBox(width: 12),
              // ジム情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (place.rating != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${place.rating} (${place.userRatingsTotal ?? 0}件)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      place.address,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 営業状況
                    if (place.openNow != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: place.openNow! 
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: place.openNow! ? Colors.green : Colors.red,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          place.openNow! ? '営業中' : '営業時間外',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: place.openNow! ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// プレースホルダー画像
  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[300],
      child: const Icon(Icons.fitness_center, size: 32),
    );
  }

  /// 混雑度フィルターバー
  Widget _buildCrowdFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.people, size: 20),
          const SizedBox(width: 8),
          const Text('混雑度フィルター:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: Slider(
              value: _crowdFilter.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: _getCrowdLevelText(_crowdFilter),
              onChanged: (value) {
                setState(() {
                  _crowdFilter = value.toInt();
                });
              },
            ),
          ),
          Text(
            _getCrowdLevelText(_crowdFilter),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// ジムカード
  Widget _buildGymCard(Gym gym) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GymDetailScreen(gym: gym),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ジム画像
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  gym.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.fitness_center, size: 32),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              // ジム情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gym.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${gym.rating} (${gym.reviewCount})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gym.address,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 混雑度インジケーター
                    _buildCrowdIndicator(gym),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 混雑度インジケーター
  Widget _buildCrowdIndicator(Gym gym) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(gym.crowdLevelColor).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Color(gym.crowdLevelColor),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people,
            size: 14,
            color: Color(gym.crowdLevelColor),
          ),
          const SizedBox(width: 4),
          Text(
            gym.crowdLevelText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(gym.crowdLevelColor),
            ),
          ),
        ],
      ),
    );
  }

  /// フィルターダイアログ
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('フィルター設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('混雑度の上限を選択'),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: List.generate(5, (index) {
                    final level = index + 1;
                    return RadioListTile<int>(
                      title: Text(_getCrowdLevelText(level)),
                      value: level,
                      groupValue: _crowdFilter,
                      onChanged: (value) {
                        setState(() {
                          _crowdFilter = value ?? 5;
                        });
                      },
                    );
                  }),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {}); // 外側のStateも更新
            },
            child: const Text('適用'),
          ),
        ],
      ),
    );
  }

  String _getCrowdLevelText(int level) {
    switch (level) {
      case 1:
        return '空いています';
      case 2:
        return 'やや空き';
      case 3:
        return '普通';
      case 4:
        return 'やや混雑';
      case 5:
        return '超混雑';
      default:
        return '不明';
    }
  }
}
