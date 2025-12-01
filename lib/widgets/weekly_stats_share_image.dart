import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 週間統計シェア用画像Widget
/// 
/// Instagram Stories用の縦長画像（1080x1920）を生成
class WeeklyStatsShareImage extends StatelessWidget {
  final Map<String, dynamic> weeklyStats;

  const WeeklyStatsShareImage({
    super.key,
    required this.weeklyStats,
  });

  @override
  Widget build(BuildContext context) {
    final totalWorkouts = weeklyStats['totalWorkouts'] as int;
    final totalVolume = (weeklyStats['totalVolume'] as num).toDouble();
    final muscleGroupsCount = weeklyStats['muscleGroupsCount'] as int;
    final avgVolumePerWorkout = (weeklyStats['avgVolumePerWorkout'] as num).toDouble();

    return Container(
      width: 1080,
      height: 1920,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade700,
            Colors.deepPurple.shade900,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 120),
            
            // タイトル
            const Text(
              '週間トレーニング統計',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 日付範囲
            Text(
              _getDateRangeText(),
              style: TextStyle(
                fontSize: 28,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            
            const SizedBox(height: 80),
            
            // 統計カード
            _buildStatCard(
              icon: Icons.fitness_center,
              label: 'トレーニング回数',
              value: '$totalWorkouts',
              unit: '回',
              color: Colors.blue,
            ),
            
            const SizedBox(height: 32),
            
            _buildStatCard(
              icon: Icons.show_chart,
              label: '総ボリューム',
              value: _formatVolume(totalVolume),
              unit: 'kg',
              color: Colors.orange,
            ),
            
            const SizedBox(height: 32),
            
            _buildStatCard(
              icon: Icons.grid_on,
              label: 'トレーニング部位',
              value: '$muscleGroupsCount',
              unit: '部位',
              color: Colors.green,
            ),
            
            const SizedBox(height: 32),
            
            _buildStatCard(
              icon: Icons.trending_up,
              label: '平均ボリューム/回',
              value: _formatVolume(avgVolumePerWorkout),
              unit: 'kg',
              color: Colors.pink,
            ),
            
            const Spacer(),
            
            // フッター
            Center(
              child: Column(
                children: [
                  const Text(
                    'Keep Going! 💪',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'GYM MATCH',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'gym-match-e560d.web.app',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// 統計カードWidget
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // アイコン
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 48,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(width: 24),
          
          // ラベルと値
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 日付範囲のテキストを生成
  String _getDateRangeText() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    
    final formatter = DateFormat('M/d');
    return '${formatter.format(weekAgo)} - ${formatter.format(now)}';
  }

  /// ボリュームを整形（1000kg以上は「1.0k」形式）
  String _formatVolume(double volume) {
    if (volume >= 1000) {
      return (volume / 1000).toStringAsFixed(1) + 'k';
    } else {
      return volume.toStringAsFixed(0);
    }
  }
}
