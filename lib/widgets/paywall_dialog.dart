import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../services/reward_ad_service.dart';
import '../services/ai_credit_service.dart';
import '../screens/subscription_screen.dart';
import '../screens/ai_addon_purchase_screen.dart';

/// ペイウォールダイアログ種別
enum PaywallType {
  aiLimitReached,  // AI利用回数上限到達
  day7Achievement, // 7日間継続達成
  partnerFeature,  // パートナー機能（Pro限定）
}

/// 汎用ペイウォールダイアログ
class PaywallDialog extends StatelessWidget {
  final PaywallType type;

  const PaywallDialog({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case PaywallType.aiLimitReached:
        return _buildAILimitDialog(context);
      case PaywallType.day7Achievement:
        return _buildDay7Dialog(context);
      case PaywallType.partnerFeature:
        return _buildPartnerFeatureDialog(context);
    }
  }

  /// AI利用回数上限到達時のペイウォール
  Widget _buildAILimitDialog(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0E27),
              const Color(0xFF1A1E3F),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アイコン
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology,
                size: 48,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 20),
            
            // タイトル
            const Text(
              AppLocalizations.of(context)!.general_7a4837ed,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // 説明
            Text(
              AppLocalizations.of(context)!.general_453f0a92,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // オプション0: 動画視聴で1回分ゲット（NEW!）
            _buildRewardAdOption(context),
            const SizedBox(height: 12),
            
            // オプション1: AI追加パック（お得！）
            _buildOptionCard(
              context,
              title: AppLocalizations.of(context)!.aiAddonPack,
              subtitle: AppLocalizations.of(context)!.general_a974dc84,
              badge: AppLocalizations.of(context)!.general_b08e3e55,
              badgeColor: Colors.green,
              icon: Icons.add_shopping_cart,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AIAddonPurchaseScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            
            // オプション2: Premium Plan
            _buildOptionCard(
              context,
              title: 'Premium Plan',
              subtitle: AppLocalizations.of(context)!.general_ddc75fbc,
              badge: AppLocalizations.of(context)!.general_6fd93ccd,
              badgeColor: Colors.purple,
              icon: Icons.star,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            
            // オプション3: Pro Plan
            _buildOptionCard(
              context,
              title: 'Pro Plan',
              subtitle: AppLocalizations.of(context)!.general_a5612ca8,
              badge: AppLocalizations.of(context)!.general_85dbd0fe,
              badgeColor: Colors.amber,
              icon: Icons.emoji_events,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            
            // 閉じるボタン
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppLocalizations.of(context)!.later,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Day 7達成時のペイウォール
  Widget _buildDay7Dialog(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade900,
              Colors.purple.shade700,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 祝福アイコン
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration,
                size: 48,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 20),
            
            // タイトル
            const Text(
              AppLocalizations.of(context)!.general_0b2c2440,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // 説明
            const Text(
              '素晴らしい継続力です！\nさらに快適なトレーニング体験をお楽しみください',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Premium Plan訴求
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Premium Plan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    AppLocalizations.of(context)!.subscription_c71bb2e2,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(Icons.psychology, 'AI分析 10回/月'),
                  _buildFeatureRow(Icons.block, AppLocalizations.of(context)!.noAds),
                  _buildFeatureRow(Icons.show_chart, AppLocalizations.of(context)!.general_c75214b2),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      AppLocalizations.of(context)!.general_05848a73,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // CTAボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SubscriptionScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  AppLocalizations.of(context)!.general_9811cf34,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // 閉じるボタン
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                AppLocalizations.of(context)!.later,
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// パートナー機能（Pro限定）のペイウォール
  Widget _buildPartnerFeatureDialog(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amber.shade900,
              Colors.amber.shade700,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アイコン
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            
            // タイトル
            const Text(
              'トレーニングパートナーを\n見つけよう',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // 説明
            const Text(
              '孤独なトレーニングから卒業\n同じジム・同じ目標の仲間と一緒に成長',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Pro Plan訴求
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Pro Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    AppLocalizations.of(context)!.subscription_275ce1f5,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(Icons.people, 'パートナー検索 🆕'),
                  _buildFeatureRow(Icons.chat, 'メッセージング機能 🆕'),
                  _buildFeatureRow(Icons.psychology, 'AI分析 30回/月'),
                  _buildFeatureRow(Icons.block, AppLocalizations.of(context)!.noAds),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      AppLocalizations.of(context)!.general_d89e38c4,
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // CTAボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SubscriptionScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.amber.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Pro Planを試す',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // 閉じるボタン
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                AppLocalizations.of(context)!.later,
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 機能行ウィジェット
  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// リワード広告オプション（動画視聴で1回分ゲット）
  Widget _buildRewardAdOption(BuildContext context) {
    final rewardAdService = RewardAdService();
    final aiCreditService = AICreditService();
    
    return _buildOptionCard(
      context,
      title: AppLocalizations.of(context)!.general_77908ac6,
      subtitle: AppLocalizations.of(context)!.general_f4c2543c,
      badge: AppLocalizations.of(context)!.general_72978833,
      badgeColor: Colors.blue,
      icon: Icons.play_circle_fill,
      onTap: () async {
        // 広告がまだ準備できていない場合はロード試行
        if (!rewardAdService.isAdReady()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('広告を準備中です...しばらくお待ちください'),
              duration: Duration(seconds: 2),
            ),
          );
          await rewardAdService.loadRewardedAd();
          return;
        }
        
        // リワード広告を表示
        final success = await rewardAdService.showRewardedAd();
        
        if (success) {
          // 成功時の処理
          if (!context.mounted) return;
          Navigator.of(context).pop();
          
          // AI残回数を取得
          final remaining = await aiCreditService.getAICredits();
          
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎁 AI機能1回分を獲得しました！(残り${remaining}回)',
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // 失敗時の処理
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppLocalizations.of(context)!.error_97a53f5f),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  // オプションカード（AI上限到達時用）
  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ペイウォールを表示（静的メソッド）
  static Future<void> show(BuildContext context, PaywallType type) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PaywallDialog(type: type),
    );
  }
}
