import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../config/crowd_data_config.dart';

/// フェーズ移行管理画面
/// 
/// 管理者が現在のデータ戦略フェーズを確認し、
/// 次フェーズへの移行準備をサポートする画面
class PhaseMigrationScreen extends StatelessWidget {
  const PhaseMigrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.general_e7a900f9),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 現在のフェーズ表示
            _buildCurrentPhaseCard(),
            const SizedBox(height: 24),
            
            // フェーズ1の詳細
            _buildPhaseCard(
              phase: CrowdDataPhase.phase1,
              title: 'フェーズ1: 統計ベース',
              revenue: '0 - 100万円/月',
              cost: '\$0/月',
              accuracy: '70-90%',
              description: AppLocalizations.of(context)!.general_b6c03396,
              features: [
                '✅ 完全無料（API費用なし）',
                '✅ ユーザーエンゲージメント向上',
                '✅ コミュニティドリブンなデータ',
                '⚠️ 新規ジムはデータ不足',
              ],
              isActive: CrowdDataConfig.currentPhase == CrowdDataPhase.phase1,
            ),
            const SizedBox(height: 16),
            
            // フェーズ2の詳細
            _buildPhaseCard(
              phase: CrowdDataPhase.phase2,
              title: 'フェーズ2: ハイブリッド',
              revenue: '100 - 300万円/月',
              cost: '\$170/月',
              accuracy: '85-95%',
              description: AppLocalizations.of(context)!.general_4dd675e7,
              features: [
                '✅ 人気ジムの精度大幅向上',
                '✅ コスト効率的（費用率0.17%）',
                '✅ 段階的な品質改善',
                '📊 ROI 433%（+6.5万円/月）',
              ],
              isActive: CrowdDataConfig.currentPhase == CrowdDataPhase.phase2,
            ),
            const SizedBox(height: 16),
            
            // フェーズ3の詳細
            _buildPhaseCard(
              phase: CrowdDataPhase.phase3,
              title: 'フェーズ3: フルAPI',
              revenue: AppLocalizations.of(context)!.general_90d5357d,
              cost: '\$850/月',
              accuracy: '90-95%',
              description: AppLocalizations.of(context)!.general_a12528f0,
              features: [
                '✅ 業界最高レベルの精度',
                '✅ 全ジムでリアルタイム更新',
                '✅ 競合優位性の確立',
                '📊 ROI 567%（+34万円/月）',
              ],
              isActive: CrowdDataConfig.currentPhase == CrowdDataPhase.phase3,
            ),
            const SizedBox(height: 24),
            
            // 移行ガイドライン
            _buildMigrationGuideCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPhaseCard() {
    return Card(
      elevation: 8,
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Colors.deepPurple,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Text(
                  AppLocalizations.of(context)!.general_ecd7fa0b,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CrowdDataConfig.phaseDescription,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.attach_money, size: 20, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '月額コスト: ${CrowdDataConfig.estimatedMonthlyCost}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.api, size: 20, color: Colors.blue),
                      SizedBox(width: 4),
                      Text(
                        'Google API: ${CrowdDataConfig.enableGooglePlacesAPI ? AppLocalizations.of(context)!.valid : AppLocalizations.of(context)!.invalid}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseCard({
    required CrowdDataPhase phase,
    required String title,
    required String revenue,
    required String cost,
    required String accuracy,
    required String description,
    required List<String> features,
    required bool isActive,
  }) {
    return Card(
      elevation: isActive ? 8 : 2,
      color: isActive ? Colors.blue.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isActive) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.blue : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(AppLocalizations.of(context)!.general_713ba0e2, revenue, Icons.trending_up),
            _buildInfoRow(AppLocalizations.of(context)!.general_036e50bf, cost, Icons.attach_money),
            _buildInfoRow(AppLocalizations.of(context)!.general_ee0515ff, accuracy, Icons.speed),
            const SizedBox(height: 12),
            const Text(
              AppLocalizations.of(context)!.general_d8d1ba3a,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                feature,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationGuideCard() {
    return Card(
      elevation: 4,
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 28),
                const SizedBox(width: 8),
                const Text(
                  AppLocalizations.of(context)!.general_1aeb1c97,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGuideItem(
              '1. フェーズ1 → フェーズ2',
              AppLocalizations.of(context)!.general_2e4b390b,
            ),
            _buildGuideItem(
              '2. フェーズ2 → フェーズ3',
              AppLocalizations.of(context)!.general_f5e6812d,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 移行チェックリスト:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '✅ 収益目標の達成確認\n'
                    '✅ API費用の予算確保\n'
                    '✅ ユーザー報告率の安定性確認\n'
                    '✅ ROI計算と経営判断',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
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

  Widget _buildGuideItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_forward, size: 20, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
