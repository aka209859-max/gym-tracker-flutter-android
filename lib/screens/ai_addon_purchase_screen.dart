import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../services/revenue_cat_service.dart';

/// 💰 AI追加購入画面
/// 
/// AI使用回数を追加購入できる画面
class AIAddonPurchaseScreen extends StatefulWidget {
  const AIAddonPurchaseScreen({super.key});

  @override
  State<AIAddonPurchaseScreen> createState() => _AIAddonPurchaseScreenState();
}

class _AIAddonPurchaseScreenState extends State<AIAddonPurchaseScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final RevenueCatService _revenueCatService = RevenueCatService();
  bool _isPurchasing = false;
  
  int _currentUsage = 0;
  int _totalLimit = 0;
  int _baseLimit = 0;
  int _addonLimit = 0;

  @override
  void initState() {
    super.initState();
    _loadUsageStatus();
  }

  Future<void> _loadUsageStatus() async {
    final plan = await _subscriptionService.getCurrentPlan();
    final currentUsage = await _subscriptionService.getCurrentMonthAIUsage();
    final baseLimit = _subscriptionService.getAIUsageLimit(plan);
    final addonLimit = await _subscriptionService.getAddonAIUsage();
    final totalLimit = baseLimit + addonLimit;
    
    setState(() {
      _currentUsage = currentUsage;
      _baseLimit = baseLimit;
      _addonLimit = addonLimit;
      _totalLimit = totalLimit;
    });
  }

  Future<void> _purchaseAddon() async {
    // 購入確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.general_a03febb3),
        content: Text(
          'AI追加パック（5回分）\n'
          '料金: ¥300\n\n'
          '${AppLocalizations.of(context)!.addWorkout}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.general_c71038e7),
          ),
        ],
      ),
    );

    // キャンセルされた場合は処理を中断
    if (confirmed != true) return;

    setState(() {
      _isPurchasing = true;
    });

    try {
      // RevenueCatを使ってApp Store課金処理を実行
      final success = await _revenueCatService.purchaseAIAddon();
      
      if (success && mounted) {
        // 使用状況を再読み込み
        await _loadUsageStatus();
        
        // 成功ダイアログ
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.purchaseCompleted(AppLocalizations.of(context)!.aiAddonPack)),
              ],
            ),
            content: const Text(
              'AI追加パック（5回分）を購入しました！\n'
              AppLocalizations.of(context)!.general_6dc47887,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // ダイアログを閉じる
                  Navigator.pop(context, true); // 購入画面を閉じて成功を返す
                },
                child: Text(AppLocalizations.of(context)!.close),
              ),
            ],
          ),
        );
      } else if (mounted) {
        // エラーダイアログ
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 32),
                SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.error),
              ],
            ),
            content: const Text('購入処理に失敗しました。\nもう一度お試しください。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.close),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ 購入処理エラー: $e');
      if (mounted) {
        // エラー内容を判定してユーザーフレンドリーなメッセージを表示
        String errorMessage = AppLocalizations.of(context)!.error_84228e89;
        
        if (e.toString().contains('product not found') || 
            e.toString().contains(AppLocalizations.of(context)!.general_e322250e)) {
          errorMessage = 'この商品は現在利用できません。\n'
                        AppLocalizations.of(context)!.general_b316392b;
        } else if (e.toString().contains('cancelled') || 
                   e.toString().contains(AppLocalizations.of(context)!.buttonCancel)) {
          errorMessage = AppLocalizations.of(context)!.purchaseCancelled;
        }
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 32),
                SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.error),
              ],
            ),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.close),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _totalLimit - _currentUsage;
    final isProPlan = _baseLimit >= 999; // Pro Plan判定
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.purchaseAICredits),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 現在の使用状況カード
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.blue, size: 28),
                        SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.general_7a3b29c4,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // プログレスバー
                    LinearProgressIndicator(
                      value: _totalLimit > 0 ? _currentUsage / _totalLimit : 0,
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        remaining <= 3 ? Colors.red : Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 使用状況テキスト
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '使用済み: $_currentUsage回',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          isProPlan ? '残り: ∞' : '残り: $remaining回',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: remaining <= 3 && !isProPlan ? Colors.red : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      isProPlan 
                          ? 'プラン基本: 無制限 / 追加購入: $_addonLimit回'
                          : AppLocalizations.of(context)!.addWorkout,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 追加購入パッケージ
            const Text(
              AppLocalizations.of(context)!.aiAddonPack,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // 5回パック
            _buildAddonPackageCard(
              icon: Icons.bolt,
              title: AppLocalizations.of(context)!.aiAddonPack,
              subtitle: AppLocalizations.of(context)!.general_5beac536,
              price: '¥300',
              aiCount: 5,
              color: Colors.blue,
              isRecommended: true,
            ),
            
            const SizedBox(height: 24),
            
            // 説明セクション
            Card(
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
                          AppLocalizations.of(context)!.subscription_76b79b54,
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
                      '• 追加購入分は今月末まで有効です\n'
                      '• 月が変わると追加購入分もリセットされます\n'
                      '• 追加購入はいつでも可能です\n'
                      '• プラン変更後も追加購入分は引き継がれます',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
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

  Widget _buildAddonPackageCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String price,
    required int aiCount,
    required Color color,
    bool isRecommended = false,
  }) {
    return Card(
      elevation: isRecommended ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRecommended
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: _isPurchasing ? null : _purchaseAddon,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (isRecommended)
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
                    '💰 お得',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (isRecommended) const SizedBox(height: 12),
              
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              
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
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '/ $aiCount回',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              Text(
                '1回あたり: ¥${(300 / aiCount).round()}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPurchasing ? null : _purchaseAddon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isPurchasing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          AppLocalizations.of(context)!.general_c71038e7,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
