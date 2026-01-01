import 'package:gym_match/gen/app_localizations.dart';
import 'dart:async';
import 'dart:math';
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
  bool _useGooglePlaces = true; // 通常モード: Google Places API使用

  // ページネーション関連
  int _currentPage = 1;
  static const int _itemsPerPage = 20;
  int get _totalPages => (_filteredGyms.length / _itemsPerPage).ceil();

  // デバウンスタイマー（API呼び出し最適化）
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    // 初期表示は空リスト（検索実行時に実データ取得）
    _filteredGyms = [];
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
        title: Text(AppLocalizations.of(context)!.gymSearch),
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
                hintText: AppLocalizations.of(context)!.searchPlaceholder,
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
          SizedBox(width: 8),
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
                : Text(AppLocalizations.of(context)!.search),
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
                      : Icon(Icons.my_location),
                  label: Text(_currentPosition == null
                      ? AppLocalizations.of(context)!.getGpsLocation
                      : 'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_currentPosition != null) ...[
                SizedBox(width: 12),
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
                  tooltip: AppLocalizations.of(context)!.searchGym,
                ),
              ],
            ],
          ),
          if (_currentPosition != null) ...[
            SizedBox(height: 12),
            Text(
                          AppLocalizations.of(context)!.searchGym,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.searchGym),
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
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _applyFilters,
              child: Text(AppLocalizations.of(context)!.searchGym),
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
            SizedBox(height: 16),
            Text(
              _currentPosition != null || _searchQuery.isNotEmpty
                  ? AppLocalizations.of(context)!.general_89ea4973
                  : AppLocalizations.of(context)!.startGpsOrTextSearch,
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

    // 検索結果リスト（パートナージム優先ソート）
    final sortedGyms = List<Gym>.from(_filteredGyms);
    sortedGyms.sort((a, b) {
      // パートナージムを優先
      if (a.isPartner && !b.isPartner) return -1;
      if (!a.isPartner && b.isPartner) return 1;
      // 同じ優先度の場合は距離でソート
      if (_currentPosition != null) {
        final distA = _locationService.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a.latitude,
          a.longitude,
        );
        final distB = _locationService.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      }
      return 0;
    });

    // ページネーション適用（20件ずつ表示）
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginatedGyms = sortedGyms.sublist(
      startIndex, 
      endIndex > sortedGyms.length ? sortedGyms.length : endIndex,
    );

    return Column(
      children: [
        // ページ情報表示
        if (sortedGyms.length > _itemsPerPage)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '全${sortedGyms.length}件中 ${startIndex + 1}-${endIndex > sortedGyms.length ? sortedGyms.length : endIndex}件を表示',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                Text(
                  'ページ $_currentPage / $_totalPages',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        
        // 検索結果リスト
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: paginatedGyms.length,
      itemBuilder: (context, index) {
        final gym = paginatedGyms[index];
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
          ),
        ),
        
        // ページネーションコントロール
        if (sortedGyms.length > _itemsPerPage)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 前へボタン
                ElevatedButton.icon(
                  onPressed: _currentPage > 1
                      ? () {
                          setState(() {
                            _currentPage--;
                          });
                        }
                      : null,
                  icon: Icon(Icons.chevron_left),
                  label: Text(AppLocalizations.of(context)!.previous),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                ),
                
                // ページ番号表示
                Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                // 次へボタン
                ElevatedButton.icon(
                  onPressed: _currentPage < _totalPages
                      ? () {
                          setState(() {
                            _currentPage++;
                          });
                        }
                      : null,
                  icon: Icon(Icons.chevron_right),
                  label: Text(AppLocalizations.of(context)!.next),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
      ],
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
                    // パートナーバッジ + ジム名
                    Row(
                      children: [
                        if (gym.isPartner) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🏆',
                                  style: TextStyle(fontSize: 10),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  AppLocalizations.of(context)!.noAds,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            gym.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                    // パートナー特典表示
                    if (gym.isPartner && gym.partnerBenefit != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green[300]!, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_offer, size: 12, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                gym.partnerBenefit!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // ビジター可バッジ
                    if (gym.acceptsVisitors) ...[
                      SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)!.visitorWelcome,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // キャンペーン表示
                    if (gym.isPartner && gym.campaignTitle != null && gym.campaignTitle!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber[600]!, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.campaign, size: 14, color: Colors.amber[900]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    gym.campaignTitle!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[900],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (gym.campaignValidUntil != null) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 10, color: Colors.red[700]),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${gym.campaignValidUntil!.month}/${gym.campaignValidUntil!.day}まで',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.red[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
      Position? position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        // GPS取得失敗時はデフォルト位置（東京駅）を使用
        if (kDebugMode) {
          print('⚠️ GPS取得失敗 → デフォルト位置（東京駅）を使用');
        }
        
        position = Position(
          latitude: 35.6812,
          longitude: 139.7671,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.searchGym),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
      // 位置情報を設定（GPS取得成功 or デフォルト位置）
      setState(() {
        _currentPosition = position;
      });
      
      if (kDebugMode) {
        print('✅ 位置情報設定完了: ${position!.latitude}, ${position.longitude}');
      }
      
      // テキスト検索中でない場合のみ、GPS検索を実行
      if (_searchQuery.isEmpty) {
        _applyFilters();
      } else {
        if (kDebugMode) {
          print('ℹ️ テキスト検索が優先されるため、GPS検索はスキップ');
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
      // 🔥 NEW: パートナー情報統合版APIを使用
      List<Gym> googleGyms = [];

      // 🔥 優先順位変更: テキスト検索を最優先
      List<Gym> localGyms = [];
      if (_searchQuery.isNotEmpty) {
        // テキスト検索（全国対応 - エリア名 or ジム名）
        if (kDebugMode) {
          print('📝 テキスト検索: "$_searchQuery"');
        }
        // 🏆 パートナー情報統合版API使用
        googleGyms = await _placesService.searchGymsByTextWithPartners(_searchQuery);
        
        // ✅ ローカルデータは使用しない（実データのみ表示）
        localGyms = []; // ダミーデータを排除
        
        if (kDebugMode) {
          print('✅ Google Places検索: ${googleGyms.length}件');
          final partnerCount = googleGyms.where((g) => g.isPartner).length;
          print('   🏆 パートナージム: ${partnerCount}件');
        }
      }
      // GPS検索（テキスト入力がない場合のみ）
      else if (_currentPosition != null) {
        if (kDebugMode) {
          print('📍 GPS検索: Lat=${_currentPosition!.latitude}, Lng=${_currentPosition!.longitude}, Radius=${_searchRadius}km');
        }
        // 🏆 パートナー情報統合版API使用
        googleGyms = await _placesService.searchNearbyGymsWithPartners(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          radiusMeters: (_searchRadius * 1000).toInt(),
        );
        if (kDebugMode) {
          print('✅ GPS検索結果: ${googleGyms.length}件');
          final partnerCount = googleGyms.where((g) => g.isPartner).length;
          print('   🏆 パートナージム: ${partnerCount}件');
        }
      }

      // 🔥 NOTE: googleGyms は既に Gym オブジェクト（変換不要）

      // ✅ Google Places検索結果のみ使用（ローカルデータは排除）
      final mergedGyms = googleGyms;
      
      if (kDebugMode) {
        print('🎯 検索結果: 合計 ${mergedGyms.length}件 (Google Places API)');
      }

      // 🏆 パートナージム優先表示：GPS検索時は距離に関係なくパートナージムを最上位に
      if (_currentPosition != null) {
        mergedGyms.sort((a, b) {
          // パートナージムを優先
          if (a.isPartner && !b.isPartner) return -1;
          if (!a.isPartner && b.isPartner) return 1;
          
          // 同じグループ内では距離順（近い順）
          final distA = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            a.latitude,
            a.longitude,
          );
          final distB = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            b.latitude,
            b.longitude,
          );
          return distA.compareTo(distB);
        });
        
        if (kDebugMode) {
          final partnerCount = mergedGyms.where((g) => g.isPartner).length;
          print('🏆 パートナージム優先ソート完了: ${partnerCount}件のパートナージムを最上位に配置');
        }
      }

      setState(() {
        _filteredGyms = mergedGyms;
        _googlePlaces = []; // GooglePlace is no longer used
        _isSearching = false;
        _currentPage = 1; // 検索実行時にページ番号をリセット
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ 検索エラー: $e');
        print('   検索タイプ: ${_searchQuery.isNotEmpty ? AppLocalizations.of(context)!.textSearch : "GPS検索"}');
        if (_currentPosition != null) {
          print('   GPS座標: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
        }
        if (_searchQuery.isNotEmpty) {
          print('   検索クエリ: "$_searchQuery"');
        }
      }
      
      // ユーザーフレンドリーなエラーメッセージ
      String userMessage = AppLocalizations.of(context)!.searchFailed;
      if (e.toString().contains('ClientException')) {
        userMessage = AppLocalizations.of(context)!.networkError;
      } else if (e.toString().contains('REQUEST_DENIED')) {
        userMessage = AppLocalizations.of(context)!.apiKeyError;
      } else if (e.toString().contains('ZERO_RESULTS')) {
        userMessage = AppLocalizations.of(context)!.searchGym;
      }
      
      setState(() {
        _errorMessage = userMessage;
        _isSearching = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.searchGym),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 2点間の距離を計算（ヒュベニの公式）単位: km
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; // 地球の半径（km）
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// 度をラジアンに変換
  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}
