import 'package:flutter/material.dart';
import '../models/gym.dart';
import '../services/realtime_user_service.dart';
import '../services/favorites_service.dart';
import 'crowd_report_screen.dart';

/// ジム詳細画面
class GymDetailScreen extends StatefulWidget {
  final Gym gym;

  const GymDetailScreen({super.key, required this.gym});

  @override
  State<GymDetailScreen> createState() => _GymDetailScreenState();
}

class _GymDetailScreenState extends State<GymDetailScreen> {
  final RealtimeUserService _userService = RealtimeUserService();
  final FavoritesService _favoritesService = FavoritesService();
  bool _isCheckedIn = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
    _checkFavoriteStatus();
  }

  Future<void> _checkUserStatus() async {
    try {
      final isCheckedIn = await _userService.isUserCheckedIn(widget.gym.id);
      if (mounted) {
        setState(() {
          _isCheckedIn = isCheckedIn;
        });
      }
    } catch (e) {
      // Firebase未設定時はデモモード
      if (mounted) {
        setState(() {
          _isCheckedIn = false;
        });
      }
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final isFavorite = await _favoritesService.isFavorite(widget.gym.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      // お気に入りから削除
      final success = await _favoritesService.removeFavorite(widget.gym.id);
      if (success && mounted) {
        setState(() {
          _isFavorite = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('お気に入りから削除しました'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } else {
      // お気に入りに追加
      final success = await _favoritesService.addFavorite(widget.gym);
      if (success && mounted) {
        setState(() {
          _isFavorite = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('お気に入りに追加しました'),
            backgroundColor: Colors.pink,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ヘッダー画像
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.gym.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 4),
                  ],
                ),
              ),
              background: Image.network(
                widget.gym.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.fitness_center, size: 64),
                  );
                },
              ),
            ),
          ),
          // コンテンツ
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 混雑度カード
                  _buildCrowdCard(),
                  const SizedBox(height: 16),
                  // 基本情報
                  _buildInfoSection(),
                  const SizedBox(height: 16),
                  // 設備情報
                  _buildFacilitiesSection(),
                  const SizedBox(height: 16),
                  // アクションボタン
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  // レビューセクション（プレースホルダー）
                  _buildReviewsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleFavorite,
        backgroundColor: _isFavorite ? Colors.pink : Colors.grey[300],
        foregroundColor: _isFavorite ? Colors.white : Colors.grey[700],
        icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
        label: Text(_isFavorite ? 'お気に入り登録済み' : 'お気に入りに追加'),
      ),
    );
  }

  Widget _buildCrowdCard() {
    final gym = widget.gym;
    
    // 混雑度データが未実装の場合は「データ収集中」を表示
    if (gym.currentCrowdLevel == 0 || gym.lastCrowdUpdate == null) {
      return Card(
        color: Colors.blue.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.hourglass_empty, size: 32, color: Colors.blue),
                  SizedBox(width: 12),
                  Text(
                    '混雑度データ収集中',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'リアルタイム混雑度機能は近日公開予定です',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    
    final minutesAgo = gym.lastCrowdUpdate != null
        ? DateTime.now().difference(gym.lastCrowdUpdate!).inMinutes
        : null;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '現在の混雑度',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (minutesAgo != null)
                  Text(
                    '$minutesAgo分前更新',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(gym.crowdLevelColor).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(gym.crowdLevelColor),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people,
                        size: 32,
                        color: Color(gym.crowdLevelColor),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        gym.crowdLevelText,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(gym.crowdLevelColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // リアルタイムユーザー数表示（デモモード対応）
                  StreamBuilder<int>(
                    stream: _userService.getUserCountStream(gym.id),
                    builder: (context, snapshot) {
                      // エラー時はデモデータ表示
                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person,
                                size: 18,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'デモモード（Firebase未設定）',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      final userCount = snapshot.data ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person,
                              size: 18,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$userCountがトレーニング中',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CrowdReportScreen(gym: widget.gym),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('混雑度を報告する'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final gym = widget.gym;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '基本情報',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow(Icons.star, '評価', '${gym.rating} (${gym.reviewCount}件)'),
            _buildInfoRow(Icons.location_on, '住所', gym.address),
            if (gym.phoneNumber.isNotEmpty)
              _buildInfoRow(Icons.phone, '電話番号', gym.phoneNumber),
            _buildInfoRow(Icons.access_time, '営業時間', gym.openingHours),
            // 月額料金は公式サイトで確認
            _buildInfoNotice(
              Icons.info_outline,
              '料金・詳細情報',
              '最新の料金プランや設備情報は、ジムの公式サイトでご確認ください',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNotice(IconData icon, String label, String notice) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notice,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitiesSection() {
    // 設備情報がない場合は「公式サイトで確認」を表示
    if (widget.gym.facilities.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '設備・施設',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '設備情報は公式サイトでご確認ください',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 設備情報がある場合は表示（サンプルデータのみ）
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '設備・施設',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.gym.facilities.map((facility) {
                return Chip(
                  label: Text(facility),
                  avatar: const Icon(Icons.check_circle, size: 16),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // チェックイン/チェックアウトボタン
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                if (_isCheckedIn) {
                  // チェックアウト
                  await _userService.checkOutFromGym(widget.gym.id);
                  if (mounted) {
                    setState(() {
                      _isCheckedIn = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('チェックアウトしました')),
                    );
                  }
                } else {
                  // チェックイン
                  await _userService.checkInToGym(widget.gym.id);
                  if (mounted) {
                    setState(() {
                      _isCheckedIn = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('チェックインしました！')),
                    );
                  }
                }
              } catch (e) {
                // Firebase未設定時のエラーハンドリング
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Firebase設定が必要です'),
                      content: const Text(
                        'チェックイン機能を使用するには、Firebase Consoleで設定ファイルを取得し、firebase_options.dartを更新してください。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('了解'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            icon: Icon(_isCheckedIn ? Icons.logout : Icons.login),
            label: Text(_isCheckedIn ? 'チェックアウト' : 'チェックイン'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isCheckedIn
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: ルート案内機能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ルート案内機能は開発中です')),
                  );
                },
                icon: const Icon(Icons.directions),
                label: const Text('ルート案内'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: お気に入り機能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('お気に入りに追加しました')),
                  );
                },
                icon: const Icon(Icons.favorite_border),
                label: const Text('お気に入り'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'レビュー',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: レビュー一覧画面
                  },
                  child: const Text('すべて見る'),
                ),
              ],
            ),
            const Divider(),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'レビュー機能は準備中です',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
