import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'favorites_screen.dart';
import 'subscription_screen.dart';
import 'body_measurement_screen.dart';
import 'visit_history_screen.dart';
import 'personal_training/pt_password_screen.dart';
import 'messages/messages_screen.dart';
import 'partner/partner_screen.dart';
import 'settings/notification_settings_screen.dart';
import '../services/favorites_service.dart';
import '../services/subscription_service.dart';
import '../services/chat_service.dart';

/// プロフィール画面
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FavoritesService _favoritesService = FavoritesService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final ChatService _chatService = ChatService();
  
  int _favoriteCount = 0;
  int _unreadMessages = 0;
  SubscriptionType _currentPlan = SubscriptionType.free;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _subscribeToUnreadMessages();
  }

  Future<void> _loadUserData() async {
    final favoriteCount = await _favoritesService.getFavoriteCount();
    final currentPlan = await _subscriptionService.getCurrentPlan();
    
    setState(() {
      _favoriteCount = favoriteCount;
      _currentPlan = currentPlan;
    });
  }

  /// 未読メッセージ数を監視
  void _subscribeToUnreadMessages() {
    _chatService.getTotalUnreadCount().listen((count) {
      if (mounted) {
        setState(() {
          _unreadMessages = count;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 設定画面
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // プロフィールヘッダー
            _buildProfileHeader(context),
            const SizedBox(height: 24),
            // メニューリスト
            _buildMenuList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 50,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'トレーニングユーザー',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'GYM MATCHへようこそ',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // プランバッジ（タップ可能）
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                ).then((_) => _loadUserData());
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _currentPlan == SubscriptionType.free
                      ? Colors.grey[300]
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _subscriptionService.getPlanName(_currentPlan),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _currentPlan == SubscriptionType.free
                            ? Colors.grey[700]
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: _currentPlan == SubscriptionType.free
                          ? Colors.grey[700]
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList(BuildContext context) {
    return Column(
      children: [
        // パーソナルトレーニング
        Card(
          elevation: 2,
          color: Colors.orange[50],
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[700],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center, color: Colors.white),
            ),
            title: const Text(
              '💪 パーソナルトレーニング',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              '予約状況・トレーニング記録・予約申込',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PTPasswordScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // デザインテーマ選択は削除（Energetic系に固定）
        _buildMenuCard(
          context,
          icon: Icons.favorite,
          title: 'お気に入りジム',
          subtitle: '$_favoriteCount件',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavoritesScreen()),
            ).then((_) => _loadUserData());
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.monitor_weight,
          title: '体重・体脂肪率',
          subtitle: '身体の記録と管理',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BodyMeasurementScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.history,
          title: '訪問履歴',
          subtitle: '過去の訪問ジム',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VisitHistoryScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.people,
          title: 'トレーニングパートナー',
          subtitle: 'マッチング機能',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PartnerScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.message,
          title: 'メッセージ',
          subtitle: _unreadMessages > 0 ? '新着 $_unreadMessages 件' : '新着メッセージなし',
          badge: _unreadMessages > 0 ? '$_unreadMessages' : null,
          badgeColor: Colors.red,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MessagesScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.notifications,
          title: '通知設定',
          subtitle: 'プッシュ通知・アラート',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Row(
          children: [
            Text(title),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor?.withValues(alpha: 0.2) ?? 
                      (badge == '有料プラン' ? Colors.amber[100] : Colors.blue[100]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor ?? 
                        (badge == '有料プラン' ? Colors.amber[900] : Colors.blue[900]),
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Future<void> _checkPremiumFeature(BuildContext context, String featureName) async {
    final isPremium = await _subscriptionService.isPremiumFeatureAvailable();
    
    if (!isPremium) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.amber[700]),
              const SizedBox(width: 8),
              const Text('有料プラン限定機能'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$featureNameは有料プラン会員限定の機能です。',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                '有料プランに加入すると以下の機能が利用可能になります：',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              _buildFeatureItem('🤝 トレーニングパートナーマッチング'),
              _buildFeatureItem('💬 メッセージング機能'),
              _buildFeatureItem('⭐ 優先サポート'),
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
                // TODO: Implement SubscriptionScreen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('プラン詳細画面は近日公開予定です')),
                );
                /*
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                ).then((_) => _loadUserData());
                */
              },
              child: const Text('プラン詳細を見る'),
            ),
          ],
        ),
      );
    } else {
      _showComingSoonDialog(context, featureName);
    }
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('近日公開'),
        content: Text(
          '$featureNameは現在開発中です。\n次回のアップデートでご利用いただけます。',
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
