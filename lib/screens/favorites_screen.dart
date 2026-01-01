import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/favorites_service.dart';
import '../models/gym.dart';
import 'gym_detail_screen.dart';

/// お気に入りジム一覧画面
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesService _favoritesService = FavoritesService();
  List<Gym> _favoriteGyms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  /// お気に入りジムを読み込み
  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final favoritesData = await _favoritesService.getFavoriteGyms();
      
      // Map<String, dynamic> から Gym オブジェクトに変換
      final gyms = favoritesData.map((gymData) {
        return Gym(
          id: gymData['id'] as String,
          name: gymData['name'] as String,
          address: gymData['address'] as String,
          latitude: (gymData['latitude'] as num).toDouble(),
          longitude: (gymData['longitude'] as num).toDouble(),
          rating: (gymData['rating'] as num?)?.toDouble() ?? 0.0,
          reviewCount: gymData['reviewCount'] as int? ?? 0,
          currentCrowdLevel: gymData['currentCrowdLevel'] as int? ?? 3,
          monthlyFee: (gymData['monthlyFee'] as num?)?.toDouble() ?? 0.0,
          imageUrl: gymData['imageUrl'] as String? ?? '',
          facilities: List<String>.from(gymData['facilities'] ?? []),
          phoneNumber: gymData['phoneNumber'] as String? ?? '',
          openingHours: gymData['openingHours'] as String? ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      // 追加日時でソート（新しい順）
      gyms.sort((a, b) {
        final aAdded = favoritesData.firstWhere(
          (data) => data['id'] == a.id,
          orElse: () => {'addedAt': DateTime.now().toIso8601String()},
        )['addedAt'] as String;
        final bAdded = favoritesData.firstWhere(
          (data) => data['id'] == b.id,
          orElse: () => {'addedAt': DateTime.now().toIso8601String()},
        )['addedAt'] as String;
        return DateTime.parse(bAdded).compareTo(DateTime.parse(aAdded));
      });

      setState(() {
        _favoriteGyms = gyms;
        _isLoading = false;
      });

      if (kDebugMode) {
        debugPrint('✅ お気に入り読み込み完了: ${gyms.length}件');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ お気に入り読み込みエラー: $e');
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  /// お気に入りから削除
  Future<void> _removeFavorite(Gym gym) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.removeFromFavorites),
        content: Text('「${gym.name}」をお気に入りから削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _favoritesService.removeFavorite(gym.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${gym.name} をお気に入りから削除しました'),
            backgroundColor: Colors.green,
          ),
        );
        
        // リストを再読み込み
        _loadFavorites();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.favorite),
        actions: [
          if (_favoriteGyms.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              tooltip: AppLocalizations.of(context)!.deleteAll,
              onPressed: _clearAllFavorites,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteGyms.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
    );
  }

  /// 空状態の表示
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.general_a15b95ca,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.addWorkout,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// お気に入りリスト表示
  Widget _buildFavoritesList() {
    return Column(
      children: [
        // ヘッダー
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'お気に入りのジム (${_favoriteGyms.length}件)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // リスト
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFavorites,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _favoriteGyms.length,
              itemBuilder: (context, index) {
                return _buildFavoriteCard(_favoriteGyms[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// お気に入りカード
  Widget _buildFavoriteCard(Gym gym) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GymDetailScreen(gym: gym),
            ),
          ).then((_) {
            // 詳細画面から戻ってきたらリロード（削除された可能性があるため）
            _loadFavorites();
          });
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
                    
                    // 確実な情報のみ表示
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.open_in_new, size: 12, color: Colors.blue),
                              SizedBox(width: 4),
                              Text(
                                AppLocalizations.of(context)!.confirm,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 削除ボタン
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red),
                tooltip: AppLocalizations.of(context)!.delete,
                onPressed: () => _removeFavorite(gym),
              ),
            ],
          ),
        ),
      ),
    );
  }



  /// すべてのお気に入りをクリア
  Future<void> _clearAllFavorites() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteAll),
        content: Text(AppLocalizations.of(context)!.delete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.deleteAll),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _favoritesService.clearAllFavorites();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.delete),
            backgroundColor: Colors.green,
          ),
        );
        
        _loadFavorites();
      }
    }
  }
}
