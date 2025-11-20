import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/workout_log.dart';

/// Layer 4: 部位別トラッキング画面
/// 
/// 機能:
/// - 過去30日間の部位別トレーニング頻度を表示
/// - トレーニングスタイル切り替え（全身トレーニング/分割法）
/// - 不足部位のアラート表示
/// - 視覚的なプログレスバー
class BodyPartTrackingScreen extends StatefulWidget {
  const BodyPartTrackingScreen({super.key});

  @override
  State<BodyPartTrackingScreen> createState() => _BodyPartTrackingScreenState();
}

class _BodyPartTrackingScreenState extends State<BodyPartTrackingScreen> {
  String _trainingStyle = 'fullbody'; // 'fullbody' or 'split'
  int _periodDays = 30; // 集計期間（日数）

  // 部位の日本語名マッピング
  static const Map<String, String> bodyPartNames = {
    'chest': '胸',
    'back': '背中',
    'legs': '脚',
    'shoulders': '肩',
    'arms': '腕',
    'core': '体幹',
  };

  @override
  void initState() {
    super.initState();
    _autoLoginIfNeeded();
  }

  /// 未ログイン時に自動的にデモユーザーでログイン
  Future<void> _autoLoginIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint('Auto login failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('部位別トラッキング')),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('部位別トラッキング')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ログインに失敗しました'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _autoLoginIfNeeded,
                    child: const Text('再試行'),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildMainContent(user);
      },
    );
  }

  Widget _buildMainContent(User user) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('部位別トラッキング'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
            tooltip: '使い方',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getWorkoutsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('エラーが発生しました: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // 部位別統計を計算
                final stats = _calculateBodyPartStats(snapshot.data!.docs);

                return _buildStatsView(stats);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// コントロールパネル（トレーニングスタイル + 期間選択）
  Widget _buildControlPanel() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'トレーニングスタイル',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'fullbody',
                  label: Text('全身法'),
                  icon: Icon(Icons.accessibility_new),
                ),
                ButtonSegment(
                  value: 'split',
                  label: Text('分割法'),
                  icon: Icon(Icons.splitscreen),
                ),
              ],
              selected: {_trainingStyle},
              onSelectionChanged: (Set<String> selected) {
                setState(() {
                  _trainingStyle = selected.first;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text(
              '集計期間',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 7,
                  label: Text('7日'),
                ),
                ButtonSegment(
                  value: 30,
                  label: Text('30日'),
                ),
                ButtonSegment(
                  value: 90,
                  label: Text('90日'),
                ),
              ],
              selected: {_periodDays},
              onSelectionChanged: (Set<int> selected) {
                setState(() {
                  _periodDays = selected.first;
                });
              },
            ),
            const SizedBox(height: 8),
            _buildStyleExplanation(),
          ],
        ),
      ),
    );
  }

  /// トレーニングスタイルの説明
  Widget _buildStyleExplanation() {
    final explanation = _trainingStyle == 'fullbody'
        ? '毎回全身をバランスよくトレーニング（週3回想定）'
        : '部位ごとにローテーション（週5-6回想定）';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              explanation,
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  /// 統計表示ビュー
  Widget _buildStatsView(Map<String, int> stats) {
    if (stats.isEmpty) {
      return _buildEmptyState();
    }

    final maxCount = stats.values.reduce((a, b) => a > b ? a : b);
    final sortedEntries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // アラート判定
    final alerts = _generateAlerts(stats);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // アラートカード
          if (alerts.isNotEmpty) ...[
            _buildAlertsCard(alerts),
            const SizedBox(height: 16),
          ],

          // サマリーカード
          _buildSummaryCard(stats, maxCount),
          const SizedBox(height: 16),

          // 部位別詳細リスト
          const Text(
            '部位別詳細',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedEntries.map((entry) => _buildBodyPartCard(
                entry.key,
                entry.value,
                maxCount,
              )),
        ],
      ),
    );
  }

  /// アラートカード
  Widget _buildAlertsCard(List<String> alerts) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  '不足部位のお知らせ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...alerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Text(alert)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  /// サマリーカード
  Widget _buildSummaryCard(Map<String, int> stats, int maxCount) {
    final totalCount = stats.values.reduce((a, b) => a + b);
    final avgCount = (totalCount / stats.length).toStringAsFixed(1);
    final mostTrained = stats.entries.reduce((a, b) => a.value > b.value ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'サマリー',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  '合計',
                  totalCount.toString(),
                  Icons.fitness_center,
                  Colors.blue,
                ),
                _buildSummaryItem(
                  '平均',
                  avgCount,
                  Icons.trending_up,
                  Colors.green,
                ),
                _buildSummaryItem(
                  '最多',
                  bodyPartNames[mostTrained.key] ?? mostTrained.key,
                  Icons.star,
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  /// 部位別カード
  Widget _buildBodyPartCard(String bodyPart, int count, int maxCount) {
    final displayName = bodyPartNames[bodyPart] ?? bodyPart;
    final percentage = maxCount > 0 ? (count / maxCount) : 0.0;
    final color = _getColorForCount(count, maxCount);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$count回',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 20,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(percentage * 100).toStringAsFixed(0)}% (最多部位比)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 空の状態
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'トレーニング記録がありません',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ワークアウトを記録すると、部位別の統計が表示されます',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// ワークアウトストリーム取得（インデックス不要のシンプルクエリ）
  Stream<QuerySnapshot> _getWorkoutsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('workouts')
        .snapshots();
  }

  /// 部位別統計計算（メモリ内でフィルタリング）
  Map<String, int> _calculateBodyPartStats(List<QueryDocumentSnapshot> docs) {
    final stats = <String, int>{};
    final startDate = DateTime.now().subtract(Duration(days: _periodDays));

    for (final doc in docs) {
      try {
        final workout = WorkoutLog.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );

        // 期間外のデータをスキップ
        if (workout.date.isBefore(startDate)) continue;
        
        // 自動完了をスキップ
        if (workout.isAutoCompleted) continue;

        for (final exercise in workout.exercises) {
          final bodyPart = exercise.bodyPart.toLowerCase();
          stats[bodyPart] = (stats[bodyPart] ?? 0) + 1;
        }
      } catch (e) {
        debugPrint('Error parsing workout: $e');
      }
    }

    return stats;
  }

  /// アラート生成
  List<String> _generateAlerts(Map<String, int> stats) {
    final alerts = <String>[];
    
    if (stats.isEmpty) return alerts;

    final avgCount = stats.values.reduce((a, b) => a + b) / stats.length;

    if (_trainingStyle == 'fullbody') {
      // 全身トレーニング: 全部位が平均的であるべき
      for (final entry in stats.entries) {
        if (entry.value < avgCount * 0.5) {
          final displayName = bodyPartNames[entry.key] ?? entry.key;
          alerts.add('$displayNameのトレーニングが不足しています（平均の50%以下）');
        }
      }
    } else {
      // 分割法: 週に1回は各部位をトレーニング
      final minExpected = _periodDays ~/ 7; // 週1回の期待値

      for (final entry in stats.entries) {
        if (entry.value < minExpected) {
          final displayName = bodyPartNames[entry.key] ?? entry.key;
          alerts.add('$displayNameのトレーニング頻度が低いです（週1回未満）');
        }
      }
    }

    return alerts;
  }

  /// カウントに応じた色を取得
  Color _getColorForCount(int count, int maxCount) {
    final percentage = maxCount > 0 ? count / maxCount : 0.0;

    if (percentage >= 0.8) return Colors.green;
    if (percentage >= 0.5) return Colors.blue;
    if (percentage >= 0.3) return Colors.orange;
    return Colors.red;
  }

  /// 使い方ダイアログ
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('部位別トラッキングについて'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'この機能では、過去のトレーニング記録から部位別の統計を表示します。',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                '📊 トレーニングスタイル',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• 全身トレーニング: 毎回すべての部位をバランスよく鍛える方法（週3回想定）\n'
                '• 分割法: 部位ごとにローテーションで鍛える方法（週5-6回想定）',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                '⚠️ アラート機能',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'トレーニングスタイルに基づいて、不足している部位を自動的に検知します。',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                '💡 ヒント',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'バランスの取れたトレーニングで、怪我のリスクを減らし、効果的に筋力を向上させましょう！',
                style: TextStyle(fontSize: 13),
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
