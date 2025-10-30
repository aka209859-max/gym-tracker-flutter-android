import 'package:flutter/material.dart';
import '../services/subscription_service.dart';

/// サブスクリプション管理画面
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  SubscriptionType _currentPlan = SubscriptionType.free;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentPlan();
  }

  Future<void> _loadCurrentPlan() async {
    setState(() {
      _isLoading = true;
    });

    final plan = await _subscriptionService.getCurrentPlan();
    
    setState(() {
      _currentPlan = plan;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プラン管理'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 現在のプラン表示
                  _buildCurrentPlanCard(),
                  const SizedBox(height: 32),
                  
                  // プラン選択セクション
                  const Text(
                    'プランを選択',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 無料プラン
                  _buildPlanCard(
                    type: SubscriptionType.free,
                    name: '無料プラン',
                    price: '¥0',
                    priceUnit: '永久無料',
                    features: [
                      '全国のジム検索',
                      'GPS位置検索',
                      '基本情報閲覧',
                      '混雑度表示',
                      '営業時間確認',
                    ],
                    color: Colors.grey,
                    icon: Icons.account_circle,
                  ),
                  const SizedBox(height: 16),
                  
                  // プレミアムプラン
                  _buildPlanCard(
                    type: SubscriptionType.premium,
                    name: 'プレミアムプラン',
                    price: '¥980',
                    priceUnit: '月額',
                    features: [
                      '✨ 無料プランの全機能',
                      '❤️ お気に入り無制限',
                      '📊 詳細な混雑度統計',
                      '🔔 混雑度アラート通知',
                      '📝 ジムレビュー投稿',
                      '🎯 高度なフィルター検索',
                    ],
                    color: Colors.blue,
                    icon: Icons.workspace_premium,
                    isPopular: true,
                  ),
                  const SizedBox(height: 16),
                  
                  // プロプラン
                  _buildPlanCard(
                    type: SubscriptionType.pro,
                    name: 'プロプラン',
                    price: '¥1,980',
                    priceUnit: '月額',
                    features: [
                      '✨ プレミアムプランの全機能',
                      '👥 トレーニングパートナー検索',
                      '💬 メッセージング機能',
                      '📅 トレーニングスケジュール管理',
                      '📈 トレーニング記録と分析',
                      '🏆 実績バッジ取得',
                      '🎁 提携ジム特別割引',
                    ],
                    color: Colors.amber,
                    icon: Icons.emoji_events,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 機能比較テーブル
                  _buildFeatureComparisonTable(),
                  
                  const SizedBox(height: 24),
                  
                  // 注意事項
                  _buildNoticeCard(),
                ],
              ),
            ),
    );
  }

  /// 現在のプランカード
  Widget _buildCurrentPlanCard() {
    final planColor = _currentPlan == SubscriptionType.free
        ? Colors.grey
        : _currentPlan == SubscriptionType.premium
            ? Colors.blue
            : Colors.amber;

    return Card(
      color: planColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _currentPlan == SubscriptionType.free
                  ? Icons.account_circle
                  : _currentPlan == SubscriptionType.premium
                      ? Icons.workspace_premium
                      : Icons.emoji_events,
              size: 48,
              color: planColor,
            ),
            const SizedBox(height: 12),
            const Text(
              '現在のプラン',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              _subscriptionService.getPlanName(_currentPlan),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: planColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subscriptionService.getPlanPrice(_currentPlan),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// プランカード
  Widget _buildPlanCard({
    required SubscriptionType type,
    required String name,
    required String price,
    required String priceUnit,
    required List<String> features,
    required Color color,
    required IconData icon,
    bool isPopular = false,
  }) {
    final isCurrentPlan = _currentPlan == type;
    
    return Card(
      elevation: isPopular ? 8 : 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isCurrentPlan
              ? Border.all(color: color, width: 3)
              : isPopular
                  ? Border.all(color: color, width: 2)
                  : null,
        ),
        child: Column(
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  if (isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '⭐ 人気No.1',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (isPopular) const SizedBox(height: 12),
                  Icon(icon, size: 48, color: color),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          priceUnit,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 機能リスト
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: features.map((feature) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: color,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            
            // ボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: isCurrentPlan
                    ? OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: color, width: 2),
                        ),
                        child: const Text(
                          '現在のプラン',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () => _changePlan(type),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          type == SubscriptionType.free
                              ? 'このプランに変更'
                              : 'アップグレード',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 機能比較テーブル
  Widget _buildFeatureComparisonTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '機能比較',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildComparisonRow('ジム検索', true, true, true),
            _buildComparisonRow('GPS位置検索', true, true, true),
            _buildComparisonRow('混雑度表示', true, true, true),
            _buildComparisonRow('お気に入り保存', false, true, true),
            _buildComparisonRow('レビュー投稿', false, true, true),
            _buildComparisonRow('混雑度アラート', false, true, true),
            _buildComparisonRow('パートナー検索', false, false, true),
            _buildComparisonRow('メッセージング', false, false, true),
            _buildComparisonRow('トレーニング記録', false, false, true),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
    String feature,
    bool free,
    bool premium,
    bool pro,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(feature, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Center(
              child: Icon(
                free ? Icons.check : Icons.close,
                size: 20,
                color: free ? Colors.green : Colors.red,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                premium ? Icons.check : Icons.close,
                size: 20,
                color: premium ? Colors.green : Colors.red,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                pro ? Icons.check : Icons.close,
                size: 20,
                color: pro ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 注意事項カード
  Widget _buildNoticeCard() {
    return Card(
      color: Colors.blue.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'ご利用について',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '• 月額プランはいつでもキャンセル可能です\n'
              '• キャンセル後も期間満了まで利用できます\n'
              '• プラン変更は即座に反映されます\n'
              '• 決済は開発中のため、現在はデモ動作です',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// プラン変更処理
  Future<void> _changePlan(SubscriptionType newPlan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('プランを${newPlan == SubscriptionType.free ? '変更' : 'アップグレード'}しますか？'),
        content: Text(
          '${_subscriptionService.getPlanName(newPlan)}に変更します。\n\n'
          '料金: ${_subscriptionService.getPlanPrice(newPlan)}\n\n'
          '※現在は決済システム開発中のため、デモ動作です',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // プラン変更処理
      final success = await _subscriptionService.changePlan(newPlan);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_subscriptionService.getPlanName(newPlan)}に変更しました！',
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // 現在のプランを再読み込み
        _loadCurrentPlan();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プラン変更に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
