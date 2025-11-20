import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/gym_provider.dart';
import '../models/gym.dart';
import '../services/location_service.dart';
import '../services/google_places_service.dart';
import '../services/partner_merge_service.dart';
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
  final PartnerMergeService _partnerMergeService = PartnerMergeService();
  List<Gym> _nearbyGyms = [];
  bool _isLoadingGPS = false;
  Position? _userPosition;
  bool _hasSearchedGPS = false;

  @override
  void initState() {
    super.initState();
    // アプリ起動後に自動的にGPS検索を実行（ダイアログなし）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _acquireLocationAndSearch();
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

      Position? position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        // GPS取得失敗時はデフォルト位置（東京駅）を使用
        if (kDebugMode) {
          debugPrint('⚠️ GPS取得失敗 → デフォルト位置（東京駅）で検索');
        }
        
        // 東京駅の座標をデフォルトとして使用
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
              content: const Text('位置情報を取得できませんでした。東京駅周辺のジムを表示しています。'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: '再試行',
                textColor: Colors.white,
                onPressed: _acquireLocationAndSearch,
              ),
            ),
          );
        }
      }

      if (kDebugMode) {
        debugPrint('✅ GPS取得成功: ${position.latitude}, ${position.longitude}');
      }

      // 近くのジムを検索（半径5km）- Google Places API使用
      List<Gym> gyms = [];
      bool searchSucceeded = false;
      
      try {
        if (kDebugMode) {
          debugPrint('🌐 Google Places APIで周辺のジムを検索中...');
        }
        
        final places = await _placesService.searchNearbyGyms(
          latitude: position.latitude,
          longitude: position.longitude,
          radiusMeters: 5000,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            if (kDebugMode) {
              debugPrint('⏱️ Google Places API timeout - フォールバックします');
            }
            throw TimeoutException('Google Places API timeout');
          },
        );
        
        if (places.isEmpty) {
          if (kDebugMode) {
            debugPrint('⚠️ Google Places APIからの結果が空 - フォールバックします');
          }
          throw Exception('No gyms found from Google Places API');
        }
        
        // 🔥 パートナージム統合処理（エラー時は通常のジム情報のみ返す）
        if (kDebugMode) {
          debugPrint('🏆 パートナージム統合処理開始...');
        }
        
        try {
          gyms = await _partnerMergeService.mergePartnerData(places);
          
          if (kDebugMode) {
            final partnerCount = gyms.where((g) => g.isPartner).length;
            debugPrint('✅ パートナージム統合完了: ${partnerCount}件のPOジム検出');
          }
        } catch (mergeError) {
          // パートナー統合失敗時もGoogle Placesデータをそのまま使用
          if (kDebugMode) {
            debugPrint('⚠️ パートナー統合失敗: $mergeError');
            debugPrint('   Google Placesデータをそのまま使用します');
          }
          
          // Google PlaceをGymに変換（パートナー情報なし）
          gyms = places.map((place) => Gym(
            id: place.placeId,
            name: place.name,
            address: place.address,
            latitude: place.latitude,
            longitude: place.longitude,
            description: place.types.join(', '),
            facilities: place.types,
            phoneNumber: '',
            openingHours: place.openNow != null 
                ? (place.openNow! ? '営業中' : '営業時間外')
                : '営業時間不明',
            monthlyFee: 0,
            rating: place.rating ?? 0.0,
            reviewCount: place.userRatingsTotal ?? 0,
            imageUrl: place.photoReference != null 
                ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${place.photoReference}&key=AIzaSyA9XmQSHA1llGg7gihqjmOOIaLA856fkLc'
                : 'https://via.placeholder.com/400x300?text=No+Image',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            // 💡 Google Places APIからの推定混雑度を使用（低コスト）
            currentCrowdLevel: place.estimatedCrowdLevel ?? 3,
            lastCrowdUpdate: place.estimatedCrowdLevel != null ? DateTime.now() : null,
            isPartner: false,
          )).toList();
        }
        
        searchSucceeded = true;
        
        if (kDebugMode) {
          debugPrint('✅ ${gyms.length}件の実際のジムを取得しました');
        }
        
      } on TimeoutException catch (e) {
        if (kDebugMode) {
          debugPrint('⏱️ Google Places APIタイムアウト: $e');
          debugPrint('   フォールバック: サンプルデータを使用します');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Google Places API検索エラー: $e');
          debugPrint('   フォールバック: サンプルデータを使用します');
        }
      }
      
      // 【フォールバック】API失敗時はFirestoreから直接ジムを取得
      if (!searchSucceeded) {
        if (kDebugMode) {
          debugPrint('⚠️ Google Places API検索失敗 → Firestoreからジムを取得');
        }
        try {
          // Firestoreから全ジムを取得
          final firestoreGyms = await FirebaseFirestore.instance
              .collection('gyms')
              .get()
              .timeout(const Duration(seconds: 10));
          
          gyms = firestoreGyms.docs
              .map((doc) => Gym.fromFirestore(doc))
              .toList();
          
          if (kDebugMode) {
            debugPrint('✅ Firestoreから${gyms.length}件のジムを取得');
          }
          
          searchSucceeded = true;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Firestore取得エラー: $e');
          }
          gyms = [];
        }
      } else if (gyms.isEmpty) {
        if (kDebugMode) {
          debugPrint('ℹ️ 検索結果が0件です（この地域にジムが存在しない可能性）');
        }
      }
        
      
      // 検索結果の通知
      if (mounted) {
        if (searchSucceeded && gyms.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('周辺の${gyms.length}件のジムを検索しました'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (searchSucceeded && gyms.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('この地域にはジムが見つかりませんでした'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('ジム検索に失敗しました。もう一度お試しください'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: '再試行',
                textColor: Colors.white,
                onPressed: _acquireLocationAndSearch,
              ),
            ),
          );
        }
      }

      // 🏆 パートナージム優先表示：距離に関係なく最上位に
      gyms.sort((a, b) {
        // パートナージムを優先
        if (a.isPartner && !b.isPartner) return -1;
        if (!a.isPartner && b.isPartner) return 1;
        
        // 同じグループ内では距離順（近い順）
        final distA = _calculateDistance(
          position!.latitude,
          position!.longitude,
          a.latitude,
          a.longitude,
        );
        final distB = _calculateDistance(
          position!.latitude,
          position!.longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });

      if (kDebugMode) {
        final partnerCount = gyms.where((g) => g.isPartner).length;
        debugPrint('🏆 パートナージム優先ソート完了: ${partnerCount}件を最上位に配置');
      }

      setState(() {
        _userPosition = position;
        _nearbyGyms = gyms;
        _isLoadingGPS = false;
        _hasSearchedGPS = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${gyms.length}件のジムが見つかりました'),
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
          if (_hasSearchedGPS && !_isLoadingGPS && _nearbyGyms.isNotEmpty)
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
                      'あなたの近くのジム ${_nearbyGyms.length}件を表示中',
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

  /// GPS検索結果を表示（パートナーデータ統合済み）
  Widget _buildGPSSearchResults() {
    if (_nearbyGyms.isEmpty) {
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
      itemCount: _nearbyGyms.length,
      itemBuilder: (context, index) {
        return _buildGymCard(_nearbyGyms[index]);
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🏆',
                                  style: TextStyle(fontSize: 10),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  '広告',
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
                            maxLines: 1,
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
