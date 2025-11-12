import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/trial_service.dart';
import '../../services/subscription_service.dart';

/// トライアル進捗画面
/// 
/// アクティブユーザー限定7日間トライアルの進捗を表示
class TrialProgressScreen extends StatefulWidget {
  const TrialProgressScreen({super.key});

  @override
  State<TrialProgressScreen> createState() => _TrialProgressScreenState();
}

class _TrialProgressScreenState extends State<TrialProgressScreen> {
  final TrialService _trialService = TrialService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  bool _isLoading = true;
  Map<String, bool> _conditions = {};
  int _progress = 0;
  bool _isTrialActive = false;
  bool _isTrialUsed = false;
  int _remainingDays = 0;
  SubscriptionType _currentPlan = SubscriptionType.free;

  @override
  void initState() {
    super.initState();
    _loadTrialStatus();
  }

  Future<void> _loadTrialStatus() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final conditions = await _trialService.checkTrialConditions(user.uid);
      final progress = await _trialService.getTrialProgress(user.uid);
      final isActive = await _trialService.isTrialActive();
      final isUsed = await _trialService.isTrialUsed();
      final remainingDays = await _trialService.getTrialRemainingDays();
      final currentPlan = await _subscriptionService.getCurrentPlan();

      setState(() {
        _conditions = conditions;
        _progress = progress;
        _isTrialActive = isActive;
        _isTrialUsed = isUsed;
        _remainingDays = remainingDays;
        _currentPlan = currentPlan;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トライアル進捗'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // トライアル状態カード
                  _buildTrialStatusCard(),
                  const SizedBox(height: 24),
                  
                  // 進捗表示
                  if (!_isTrialActive && !_isTrialUsed) ...[
                    _buildProgressIndicator(),
                    const SizedBox(height: 24),
                    
                    // 条件リスト
                    _buildConditionsList(),
                    const SizedBox(height: 24),
                  ],
                  
                  // トライアル内容説明
                  _buildTrialBenefitsCard(),
                ],
              ),
            ),
    );
  }

  /// トライアル状態カード
  Widget _buildTrialStatusCard() {
    String title;
    String subtitle;
    Color color;
    IconData icon;

    if (_isTrialActive) {
      title = 'プレミアムトライアル中';
      subtitle = '残り$_remainingDays日間、プレミアム機能をお楽しみください';
      color = Colors.green;
      icon = Icons.celebration;
    } else if (_isTrialUsed) {
      title = 'トライアル期間終了';
      subtitle = 'プレミアムプランにアップグレードして機能を継続利用';
      color = Colors.orange;
      icon = Icons.timer_off;
    } else if (_progress == 100) {
      title = 'トライアル条件達成！';
      subtitle = '自動的にプレミアム7日間トライアルが開始されました';
      color = Colors.blue;
      icon = Icons.star;
    } else {
      title = 'トライアル達成まであと少し';
      subtitle = '条件を達成してプレミアム7日間無料体験';
      color = Colors.grey;
      icon = Icons.flag;
    }

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 進捗インジケーター
  Widget _buildProgressIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '達成進捗',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$_progress%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _progress == 100 ? Colors.green : Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: _progress / 100,
          minHeight: 8,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            _progress == 100 ? Colors.green : Colors.blue,
          ),
        ),
      ],
    );
  }

  /// 条件リスト
  Widget _buildConditionsList() {
    final conditionLabels = {
      'account_created': 'アカウント登録完了',
      'profile_completed': 'プロフィール設定完了',
      'first_workout_logged': 'トレーニング記録1回以上',
      'gym_searched': 'ジム検索1回以上',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'トライアル条件',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...conditionLabels.entries.map((entry) {
              final isAchieved = _conditions[entry.key] ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      isAchieved ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isAchieved ? Colors.green : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 16,
                          color: isAchieved ? Colors.black : Colors.grey[600],
                          fontWeight: isAchieved ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// トライアル特典カード
  Widget _buildTrialBenefitsCard() {
    return Card(
      color: Colors.blue.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'トライアル特典',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '✨ プレミアムプラン 7日間無料',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• AI機能 月10回\n'
              '• お気に入り登録無制限\n'
              '• ジムレビュー投稿\n'
              '• 混雑度アラート通知\n'
              '• 高度なフィルター検索',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'すべての条件を達成すると自動的にトライアル開始',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber[900],
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
}
