import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import '../services/revenue_cat_service.dart';
import '../services/subscription_management_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ai_addon_purchase_screen.dart';
import 'campaign/campaign_registration_screen.dart';

/// サブスクリプション管理画面
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final RevenueCatService _revenueCatService = RevenueCatService();
  final SubscriptionManagementService _managementService = SubscriptionManagementService();
  SubscriptionType _currentPlan = SubscriptionType.free;
  bool _isLoading = true;
  List<StoreProduct> _availableProducts = [];
  bool _isYearlySelected = true; // デフォルトで年額を選択（CEO戦略）
  bool _hasLifetimePlan = false; // 永年プラン保持フラグ

  @override
  void initState() {
    super.initState();
    _loadCurrentPlan();
  }

  Future<void> _loadCurrentPlan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 永年プランチェック（最優先）
      final hasLifetime = await _subscriptionService.hasLifetimePlan();
      
      // RevenueCatから最新のサブスクリプション状態を同期
      final plan = await _revenueCatService.syncSubscriptionStatus();
      
      // 利用可能な商品を取得（アプリ内課金用）
      // 🔄 キャッシュを無効化して最新の商品情報を取得（年額プラン対応）
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final products = await _revenueCatService.getAvailableProducts(invalidateCache: true);
        setState(() {
          _availableProducts = products;
        });
      }
      
      setState(() {
        _currentPlan = plan;
        _hasLifetimePlan = hasLifetime;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ プラン読み込みエラー: $e');
      }
      // エラー時はローカルプランを使用
      final plan = await _subscriptionService.getCurrentPlan();
      final hasLifetime = await _subscriptionService.hasLifetimePlan();
      setState(() {
        _currentPlan = plan;
        _hasLifetimePlan = hasLifetime;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プラン管理'),
        centerTitle: true,
        actions: [
          // 購入復元ボタン（iOS専用 - Apple審査対応）
          // Web previewでも表示（テスト用）
          if (defaultTargetPlatform == TargetPlatform.iOS || kIsWeb)
            TextButton(
              onPressed: _restorePurchases,
              child: const Text(
                'Restore',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
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
                  const SizedBox(height: 16),
                  
                  // AI追加購入カード（有料プランのみ）
                  if (_currentPlan != SubscriptionType.free)
                    _buildAIAddonCard(),
                  if (_currentPlan != SubscriptionType.free)
                    const SizedBox(height: 16),
                  
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
                      '📝 トレーニング記録',
                      '🤖 AI機能月3回',
                      '📢 広告表示あり',
                    ],
                    color: Colors.grey,
                    icon: Icons.account_circle,
                  ),
                  const SizedBox(height: 16),
                  
                  // 月額/年額切り替えトグル
                  _buildBillingPeriodToggle(),
                  const SizedBox(height: 24),
                  
                  // Premium プラン
                  _buildPlanCard(
                    type: SubscriptionType.premium,
                    name: 'Premium',
                    price: _getPriceForPlan(SubscriptionType.premium),
                    priceUnit: _isYearlySelected ? '年額' : '月額',
                    monthlyEquivalent: _isYearlySelected ? '月換算 ¥400' : null,
                    discount: _isYearlySelected ? '20% OFF' : null,
                    savings: _isYearlySelected ? '¥1,200お得！' : null,
                    features: [
                      '✨ 無料プランの全機能',
                      '🤖 AI機能月20回（AIコーチ・成長予測・効果分析合計）',
                      '❤️ お気に入り無制限',
                      '📊 詳細な混雑度統計',
                      '⭐ ジムレビュー投稿',
                      '📈 成長予測と効果分析',
                      '🚫 広告表示なし',
                    ],
                    color: Colors.blue,
                    icon: Icons.workspace_premium,
                    isPopular: true,
                  ),
                  const SizedBox(height: 16),
                  
                  // Pro プラン
                  _buildPlanCard(
                    type: SubscriptionType.pro,
                    name: 'Pro',
                    price: _getPriceForPlan(SubscriptionType.pro),
                    priceUnit: _isYearlySelected ? '年額' : '月額',
                    monthlyEquivalent: _isYearlySelected ? '月換算 ¥667' : null,
                    discount: _isYearlySelected ? '32% OFF' : null,
                    savings: _isYearlySelected ? '¥3,760お得！' : null,
                    features: [
                      '✨ Premiumプランの全機能',
                      '🤖 AI機能無制限（AIコーチ・成長予測・効果分析）',
                      '👥 トレーニングパートナー検索', // 検索条件: 距離・目標・経験・年齢・性別・曜日・時間帯でマッチング
                      '💬 メッセージング機能',
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
                  
                  const SizedBox(height: 24),
                  
                  // AI追加パック購入カード（全ユーザー対象）
                  _buildAIAddonCard(),
                  
                  const SizedBox(height: 24),
                  
                  // 利用規約とプライバシーポリシー（Apple審査必須）
                  _buildLegalLinksCard(),
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
            // 永年プラン表示
            if (_hasLifetimePlan) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.stars, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '永年Proプラン（∞）',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'AI機能無制限 | 広告なし | すべての機能を永久利用',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ] else ...[
              Text(
                _subscriptionService.getPlanPrice(_currentPlan),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            
            // ✅ プラン管理ボタン（有料プランのみ、永年プランは除外）
            if (_currentPlan != SubscriptionType.free && !_hasLifetimePlan) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ダウングレードボタン
                  TextButton.icon(
                    onPressed: _showDowngradeDialog,
                    icon: const Icon(Icons.arrow_downward, size: 20),
                    label: const Text('プラン変更'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 月額/年額切り替えトグル
  Widget _buildBillingPeriodToggle() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleButton(
              label: '月額',
              isSelected: !_isYearlySelected,
              onTap: () {
                setState(() {
                  _isYearlySelected = false;
                });
              },
            ),
            _buildToggleButton(
              label: '年額 (💥お得)',
              isSelected: _isYearlySelected,
              onTap: () {
                setState(() {
                  _isYearlySelected = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue : Colors.grey[700],
          ),
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
    String? monthlyEquivalent,
    String? discount,
    String? savings,
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
                  if (monthlyEquivalent != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      monthlyEquivalent,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  if (discount != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        discount,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  if (savings != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      savings,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
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
              child: Column(
                children: [
                  // トライアル期間表示（有料プランのみ）
                  if (!isCurrentPlan && type != SubscriptionType.free) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.celebration, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            type == SubscriptionType.premium
                                ? '30日間無料トライアル'
                                : '14日間無料トライアル',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // 登録ボタン
                  SizedBox(
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
                        : type == SubscriptionType.free
                            ? ElevatedButton(
                                onPressed: () => _changePlan(type),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text(
                                  'このプランに変更',
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
                                child: const Text(
                                  '無料トライアルを始める',
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
            _buildComparisonRow('トレーニング記録', true, true, true),
            _buildComparisonRow('広告表示なし', false, true, true),
            _buildComparisonRow('お気に入り保存', false, true, true),
            _buildComparisonRow('レビュー投稿', false, true, true),
            _buildComparisonRow('成長予測・効果分析', false, true, true),
            _buildComparisonRow('パートナー検索', false, false, true),
            _buildComparisonRow('メッセージング', false, false, true),
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
              '• 無料トライアル期間: Premium 30日間 / Pro 14日間\n'
              '• トライアル終了後、自動的に有料プランに移行します\n'
              '• いつでもキャンセル可能（期間満了まで利用可）',
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

  /// 利用規約とプライバシーポリシーへのリンクカード（Apple審査必須）
  Widget _buildLegalLinksCard() {
    return Card(
      elevation: 0,
      color: Colors.grey.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Legal Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 利用規約リンク
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      // Web版は相対パス、iOS版は完全URL
                      final url = kIsWeb 
                          ? '/terms.html'
                          : 'https://gym-match-e560d.web.app/terms.html';
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        // Web版は同じウィンドウ、iOS版は外部Safari
                        final mode = kIsWeb 
                            ? LaunchMode.platformDefault 
                            : LaunchMode.externalApplication;
                        await launchUrl(uri, mode: mode);
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('利用規約を開けませんでした'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.description, size: 20),
                    label: const Text(
                      'Terms of Use',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // プライバシーポリシーリンク
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      // Web版は相対パス、iOS版は完全URL
                      final url = kIsWeb 
                          ? '/privacy_policy.html'
                          : 'https://gym-match-e560d.web.app/privacy_policy.html';
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        // Web版は同じウィンドウ、iOS版は外部Safari
                        final mode = kIsWeb 
                            ? LaunchMode.platformDefault 
                            : LaunchMode.externalApplication;
                        await launchUrl(uri, mode: mode);
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('プライバシーポリシーを開けませんでした'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.privacy_tip, size: 20),
                    label: const Text(
                      'Privacy Policy',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'By subscribing, you agree to our Terms of Use and Privacy Policy',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }



  /// プランの価格を取得（RevenueCatから実際の価格、またはデフォルト価格）
  String _getPriceForPlan(SubscriptionType plan) {
    // アプリ内課金の場合、RevenueCatから取得した実際の価格を使用
    if (_availableProducts.isNotEmpty) {
      String productId;
      
      if (_isYearlySelected) {
        // 年額プラン
        productId = plan == SubscriptionType.premium
            ? RevenueCatService.premiumAnnualProductId
            : RevenueCatService.proAnnualProductId;
      } else {
        // 月額プラン
        productId = plan == SubscriptionType.premium
            ? RevenueCatService.premiumMonthlyProductId
            : RevenueCatService.proMonthlyProductId;
      }
      
      try {
        final product = _availableProducts.firstWhere(
          (p) => p.identifier == productId,
        );
        // 価格が日本円（¥で始まる）の場合のみ使用、それ以外はデフォルト価格
        if (product.priceString.startsWith('¥') || product.priceString.startsWith('￥')) {
          return product.priceString;
        }
        // ドル表示の場合はデフォルト価格を使用
      } catch (e) {
        // 商品が見つからない場合はデフォルト価格
      }
    }
    
    // デフォルト価格を返す
    if (_isYearlySelected) {
      // 年額価格 (CEO戦略)
      return plan == SubscriptionType.premium ? '¥4,800' : '¥8,000';
    } else {
      // 月額価格
      return plan == SubscriptionType.premium ? '¥500' : '¥980';
    }
  }

  /// プラン変更処理（アプリ内課金版）
  Future<void> _changePlan(SubscriptionType newPlan) async {
    // 年額/月額に応じた価格を取得
    final price = _getPriceForPlan(newPlan);
    final billingPeriod = _isYearlySelected ? '年額' : '月額';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('プランを${newPlan == SubscriptionType.free ? '変更' : 'アップグレード'}しますか？'),
        content: Text(
          '${_subscriptionService.getPlanName(newPlan)}に変更します。\n\n'
          '料金: $price ($billingPeriod)',
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
      // ダウングレード（無料プランに変更）の場合
      if (newPlan == SubscriptionType.free) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('無料プランへの変更は、App Store設定でサブスクリプションをキャンセルしてください'),
              duration: Duration(seconds: 4),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // アプリ内課金の場合、RevenueCatで購入処理
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _purchaseWithRevenueCat(newPlan);
      } else {
        // Web/Desktopの場合、ローカル変更（プレビュー機能）
        await _changePlanLocal(newPlan);
      }
    }
  }
  
  /// RevenueCatでサブスクリプションを購入
  Future<void> _purchaseWithRevenueCat(SubscriptionType plan) async {
    try {
      // ローディング表示
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // Product IDを決定（月額/年額を区別）
      String productId;
      if (_isYearlySelected) {
        productId = plan == SubscriptionType.premium
            ? RevenueCatService.premiumAnnualProductId
            : RevenueCatService.proAnnualProductId;
      } else {
        productId = plan == SubscriptionType.premium
            ? RevenueCatService.premiumMonthlyProductId
            : RevenueCatService.proMonthlyProductId;
      }
      
      // RevenueCatで購入実行
      final success = await _revenueCatService.purchaseSubscription(productId);
      
      // ローディング閉じる
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_subscriptionService.getPlanName(plan)}の購入が完了しました！',
              ),
              backgroundColor: Colors.green,
            ),
          );
          
          // プラン状態を再読み込み
          _loadCurrentPlan();
        }
      } else {
        // ユーザーがキャンセルした場合など
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('購入がキャンセルされました'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      }
      
    } catch (e) {
      // ローディング閉じる
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (kDebugMode) {
        debugPrint('❌ 購入エラー: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('購入に失敗しました: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  /// 購入履歴を復元
  Future<void> _restorePurchases() async {
    try {
      // ローディング表示
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // RevenueCatで購入復元
      final hasActiveSub = await _revenueCatService.restorePurchases();
      
      // ローディング閉じる
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (hasActiveSub) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('購入履歴を復元しました！'),
              backgroundColor: Colors.green,
            ),
          );
          
          // プラン状態を再読み込み
          _loadCurrentPlan();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('復元可能な購入履歴がありませんでした'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
    } catch (e) {
      // ローディング閉じる
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (kDebugMode) {
        debugPrint('❌ 復元エラー: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('復元に失敗しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// ローカルでプラン変更（プレビュー機能・Web用）
  Future<void> _changePlanLocal(SubscriptionType newPlan) async {
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
  
  /// AI追加購入カード
  Widget _buildAIAddonCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.blue, width: 2),
      ),
      child: InkWell(
        onTap: () async {
          // AI追加購入画面に遷移
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AIAddonPurchaseScreen(),
            ),
          );
          
          // 購入成功時はプラン情報を再読み込み
          if (result == true) {
            _loadCurrentPlan();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt,
                  color: Colors.blue,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI追加パック',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI使用回数を追加購入',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '¥300 / 5回',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.blue,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ ダウングレードダイアログ
  void _showDowngradeDialog() {
    String? selectedReason;
    
    // 現在のプランに応じてダウングレード先を決定
    final String targetPlan = _currentPlan == SubscriptionType.pro ? 'premium' : 'free';
    final String targetPlanName = targetPlan == 'premium' ? 'Premium' : '無料プラン';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.arrow_downward, color: Colors.blue),
              const SizedBox(width: 8),
              Text('$targetPlanName に変更'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 代替案の提案
                if (selectedReason != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              '💡 こんな選択肢もあります',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _managementService.suggestRetentionOption(
                            _currentPlan.toString().split('.').last,
                            selectedReason!,
                          )['message']!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                Text('$targetPlanName に変更すると、以下の機能が制限されます：'),
                const SizedBox(height: 12),
                
                // 失う機能のリスト
                ..._getLostFeatures().map((feature) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(feature, style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 16),
                
                // 理由選択
                const Text('変更理由', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '選択してください',
                  ),
                  value: selectedReason,
                  items: SubscriptionManagementService.churnReasons.map((reason) {
                    return DropdownMenuItem(value: reason, child: Text(reason));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                final success = await _managementService.requestDowngrade(
                  currentPlan: _currentPlan.toString().split('.').last,
                  targetPlan: targetPlan,
                  reason: selectedReason,
                );
                
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('App Store設定から$targetPlanNameへ変更してください'),
                      backgroundColor: Colors.blue,
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'ヘルプ',
                        textColor: Colors.white,
                        onPressed: () {
                          // App Store設定へのリンクを表示
                          _showAppStoreInstructions();
                        },
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('変更する'),
            ),
          ],
        ),
      ),
    );
  }

  /// 失う機能のリストを取得
  List<String> _getLostFeatures() {
    if (_currentPlan == SubscriptionType.pro) {
      return [
        'AI機能が無制限→月20回に制限',
        'トレーニングパートナー検索',
        'メッセージング機能',
      ];
    } else if (_currentPlan == SubscriptionType.premium) {
      return [
        'AI機能が月20回→月3回に制限',
        'お気に入り無制限→制限あり',
        '詳細な混雑度統計',
        'ジムレビュー投稿',
        '広告が表示されます',
      ];
    }
    return [];
  }

  /// App Store設定手順を表示
  void _showAppStoreInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('プラン変更手順'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. iPhoneの「設定」アプリを開く'),
              SizedBox(height: 8),
              Text('2. 一番上の[Apple ID]をタップ'),
              SizedBox(height: 8),
              Text('3. 「サブスクリプション」をタップ'),
              SizedBox(height: 8),
              Text('4. 「GYM MATCH」を選択'),
              SizedBox(height: 8),
              Text('5. 希望のプランを選択'),
              SizedBox(height: 12),
              Text(
                '※ 現在のプラン期間が終了後に新プランが適用されます',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
