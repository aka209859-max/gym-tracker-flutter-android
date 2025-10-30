import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/gym_provider.dart';
import '../services/location_service.dart';
import '../services/google_places_service.dart';
import '../models/gym.dart';
import '../models/google_place.dart';
import 'gym_detail_screen.dart';

/// 検索画面（GPS + テキスト検索）
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final LocationService _locationService = LocationService();
  final GooglePlacesService _placesService = GooglePlacesService();
  
  Position? _currentPosition;
  double _searchRadius = 5.0; // デフォルト5km
  bool _isLoadingLocation = false;
  bool _isSearching = false;
  String _searchQuery = '';
  String? _errorMessage;
  
  List<Gym> _filteredGyms = [];
  List<GooglePlace> _googlePlaces = [];
  bool _useGooglePlaces = true; // Google Places APIを使用

  // デバウンスタイマー（API呼び出し最適化）
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    // デモモード用にサンプルデータも保持
    _filteredGyms = Provider.of<GymProvider>(context, listen: false).gyms;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ジム検索'),
        elevation: 2,
      ),
      body: Column(
        children: [
          // 検索バー
          _buildSearchBar(),
          // GPS検索コントロール
          _buildGPSControls(),
          // 検索結果
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ジム名・地域で検索...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _filteredGyms = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                
                // デバウンス処理: ユーザーが入力を停止してから800ms後に検索実行
                _debounceTimer?.cancel();
                if (value.trim().isNotEmpty) {
                  if (kDebugMode) {
                    print('⏱️ Debounce timer started for: "$value"');
                  }
                  _debounceTimer = Timer(_debounceDuration, () {
                    if (kDebugMode) {
                      print('🚀 Debounce timer fired - executing search');
                    }
                    _applyFilters();
                  });
                }
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  // 手動送信時は即座に検索（デバウンスをキャンセル）
                  _debounceTimer?.cancel();
                  _applyFilters();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _searchQuery.isEmpty || _isSearching ? null : _applyFilters,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('検索'),
          ),
        ],
      ),
    );
  }

  Widget _buildGPSControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                  icon: _isLoadingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(_currentPosition == null
                      ? 'GPS位置を取得'
                      : 'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_currentPosition != null) ...[
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _currentPosition = null;
                      // GPS位置をクリアするだけで、再検索はしない
                      if (kDebugMode) {
                        print('🗑️ GPS位置をクリア');
                      }
                    });
                  },
                  tooltip: '現在地検索をクリア',
                ),
              ],
            ],
          ),
          if (_currentPosition != null) ...[
            const SizedBox(height: 12),
            const Text(
              '検索半径',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _searchRadius,
                    min: 1.0,
                    max: 10.0,
                    divisions: 9,
                    label: '${_searchRadius.toStringAsFixed(0)}km',
                    onChanged: (value) {
                      setState(() {
                        _searchRadius = value;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                Text(
                  '${_searchRadius.toStringAsFixed(0)}km',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    // ローディング中
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('全国のジムを検索中...'),
          ],
        ),
      );
    }

    // エラー表示
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _applyFilters,
              child: const Text('再検索'),
            ),
          ],
        ),
      );
    }

    // 検索結果なし
    if (_filteredGyms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _currentPosition != null || _searchQuery.isNotEmpty
                  ? '検索結果が見つかりません'
                  : 'GPS位置検索またはテキスト検索を開始してください',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 検索結果リスト
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredGyms.length,
      itemBuilder: (context, index) {
        final gym = _filteredGyms[index];
        final distance = _currentPosition != null
            ? _locationService.calculateDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                gym.latitude,
                gym.longitude,
              )
            : null;

        return _buildGymCard(gym, distance);
      },
    );
  }

  Widget _buildGymCard(Gym gym, double? distance) {
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
                      maxLines: 2,
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
                        if (distance != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            _locationService.formatDistance(distance),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
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
                    // 混雑度
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

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
        
        if (kDebugMode) {
          print('✅ GPS位置取得成功: ${position.latitude}, ${position.longitude}');
        }
        
        // テキスト検索中でない場合のみ、GPS検索を実行
        if (_searchQuery.isEmpty) {
          _applyFilters();
        } else {
          if (kDebugMode) {
            print('ℹ️ テキスト検索が優先されるため、GPS検索はスキップ');
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('位置情報の取得に失敗しました'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _applyFilters() async {
    if (!_useGooglePlaces) {
      // デモモード：サンプルデータ使用
      final provider = Provider.of<GymProvider>(context, listen: false);
      List<Gym> results = provider.gyms;

      if (_searchQuery.isNotEmpty) {
        results = provider.searchGyms(_searchQuery);
      }

      if (_currentPosition != null) {
        results = _locationService.filterByRadius(
          items: results,
          centerLat: _currentPosition!.latitude,
          centerLon: _currentPosition!.longitude,
          radiusKm: _searchRadius,
          getLatitude: (gym) => gym.latitude,
          getLongitude: (gym) => gym.longitude,
        );
      }

      setState(() {
        _filteredGyms = results;
      });
      return;
    }

    // Google Places API検索（全国対応）
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    if (kDebugMode) {
      print('🔍 検索開始: GPS=${_currentPosition != null}, Query="$_searchQuery"');
    }

    try {
      List<GooglePlace> places = [];

      // 🔥 優先順位変更: テキスト検索を最優先
      if (_searchQuery.isNotEmpty) {
        // テキスト検索（全国対応）
        if (kDebugMode) {
          print('📝 テキスト検索: "$_searchQuery"');
        }
        places = await _placesService.searchGymsByText(_searchQuery);
        if (kDebugMode) {
          print('✅ テキスト検索結果: ${places.length}件');
        }
      }
      // GPS検索（テキスト入力がない場合のみ）
      else if (_currentPosition != null) {
        if (kDebugMode) {
          print('📍 GPS検索: Lat=${_currentPosition!.latitude}, Lng=${_currentPosition!.longitude}, Radius=${_searchRadius}km');
        }
        places = await _placesService.searchNearbyGyms(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          radiusMeters: (_searchRadius * 1000).toInt(),
        );
        if (kDebugMode) {
          print('✅ GPS検索結果: ${places.length}件');
        }
      }

      // GooglePlaceをGymモデルに変換
      final gyms = places.map((place) {
        final gymData = place.toGymCompatible();
        return Gym(
          id: gymData['id'],
          name: gymData['name'],
          address: gymData['address'],
          latitude: gymData['latitude'],
          longitude: gymData['longitude'],
          rating: gymData['rating'],
          reviewCount: gymData['reviewCount'],
          currentCrowdLevel: gymData['crowdLevel'],
          monthlyFee: gymData['monthlyFee'],
          facilities: List<String>.from(gymData['facilities']),
          phoneNumber: gymData['phoneNumber'],
          openingHours: gymData['openingHours'],
          imageUrl: gymData['imageUrl'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      setState(() {
        _filteredGyms = gyms;
        _googlePlaces = places;
        _isSearching = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ 検索エラー: $e');
        print('   検索タイプ: ${_searchQuery.isNotEmpty ? "テキスト検索" : "GPS検索"}');
        if (_currentPosition != null) {
          print('   GPS座標: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
        }
        if (_searchQuery.isNotEmpty) {
          print('   検索クエリ: "$_searchQuery"');
        }
      }
      
      // ユーザーフレンドリーなエラーメッセージ
      String userMessage = 'ジムの検索に失敗しました';
      if (e.toString().contains('ClientException')) {
        userMessage = 'ネットワークエラー: API接続に失敗しました\n\nHTTPリファラー制限を確認してください';
      } else if (e.toString().contains('REQUEST_DENIED')) {
        userMessage = 'APIキーエラー: アクセスが拒否されました';
      } else if (e.toString().contains('ZERO_RESULTS')) {
        userMessage = '検索結果が見つかりませんでした';
      }
      
      setState(() {
        _errorMessage = userMessage;
        _isSearching = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('検索に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
