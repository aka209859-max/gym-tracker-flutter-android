import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/subscription_service.dart';

/// 開発者専用メニュー画面（リリースビルドでは非表示）
class DeveloperMenuScreen extends StatefulWidget {
  const DeveloperMenuScreen({super.key});

  @override
  State<DeveloperMenuScreen> createState() => _DeveloperMenuScreenState();
}

class _DeveloperMenuScreenState extends State<DeveloperMenuScreen> {
  final _subscriptionService = SubscriptionService();
  SubscriptionType? _currentPlan;
  String? _aiUsageStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
  }

  Future<void> _loadCurrentStatus() async {
    setState(() => _isLoading = true);
    
    final plan = await _subscriptionService.getCurrentPlan();
    final status = await _subscriptionService.getAIUsageStatus();
    
    setState(() {
      _currentPlan = plan;
      _aiUsageStatus = status;
      _isLoading = false;
    });
  }

  // _changePlan関数は削除（Apple審査対応）
  // プラン変更はRevenueCat経由のみ許可

  Future<void> _resetAIUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ai_usage_count', 0);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ AI使用回数をリセットしました'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadCurrentStatus();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ リセット失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('開発者メニュー'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 警告メッセージ
                Card(
                  color: Colors.orange.shade50,
                  child: const ListTile(
                    leading: Icon(Icons.warning, color: Colors.orange, size: 32),
                    title: Text(
                      '⚠️ 開発者専用',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      'リリースビルド（App Store版）では表示されません\nTestFlightビルドのみで利用可能',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 現在のプラン表示
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '現在のプラン',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _currentPlan != null
                                  ? _subscriptionService.getPlanName(_currentPlan!)
                                  : '読み込み中...',
                              style: const TextStyle(fontSize: 18),
                            ),
                            if (_currentPlan != null)
                              _getPlanBadge(_currentPlan!),
                          ],
                        ),
                        if (_currentPlan != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _subscriptionService.getPlanDescription(_currentPlan!),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _subscriptionService.getPlanPrice(_currentPlan!),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // ⚠️ プラン変更機能は削除（Apple審査対応）
                Card(
                  color: Colors.red.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.block, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              '⚠️ プラン変更機能を無効化',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Apple審査対応のため、開発者メニューからのプラン変更機能は削除されました。\n\n'
                          'プラン変更はRevenueCat経由の正規課金のみ有効です。\n\n'
                          'テストには「TestFlightサンドボックス課金」を使用してください。',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // AI使用状況
                Card(
                  color: Colors.purple.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.psychology, color: Colors.deepPurple),
                            SizedBox(width: 8),
                            Text(
                              'AI使用状況',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_aiUsageStatus != null)
                          Text(
                            _aiUsageStatus!,
                            style: const TextStyle(fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // AI使用回数リセットボタン
                ElevatedButton.icon(
                  onPressed: _resetAIUsage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('AI使用回数をリセット'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // 使い方ガイド
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              '使い方',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. 上記のボタンで任意のプランに変更できます\n'
                          '2. プロプランに変更すると全機能が使用可能になります\n'
                          '3. AI使用回数は月次で自動リセットされます\n'
                          '4. 手動リセットボタンで即座に回数をリセット可能',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // _buildPlanButton関数は削除（Apple審査対応）
  // プラン変更機能を完全に無効化しました

  Widget _getPlanBadge(SubscriptionType plan) {
    final color = switch (plan) {
      SubscriptionType.free => Colors.grey,
      SubscriptionType.premium => Colors.blue,
      SubscriptionType.pro => Colors.deepPurple,
    };
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        switch (plan) {
          SubscriptionType.free => 'FREE',
          SubscriptionType.premium => 'PREMIUM',
          SubscriptionType.pro => 'PRO',
        },
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
