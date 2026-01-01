import 'package:gym_match/gen/app_localizations.dart';
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
  int _periodDays = 30; // 集計期間（日数）

  // 部位の日本語名マッピング（contextが必要なのでgetterとして実装）
  Map<String, String> get bodyPartNames => {
    'chest': AppLocalizations.of(context)!.bodyPartChest,
    'back': AppLocalizations.of(context)!.bodyPartBack,
    'legs': AppLocalizations.of(context)!.bodyPartLegs,
    'shoulders': AppLocalizations.of(context)!.bodyPartShoulders,
    'arms': AppLocalizations.of(context)!.bodyPartArms,
    'core': AppLocalizations.of(context)!.bodyPartCore,
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
            appBar: AppBar(title: Text(AppLocalizations.of(context)!.bodyPartTracking)),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: Text(AppLocalizations.of(context)!.bodyPartTracking)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(AppLocalizations.of(context)!.loginError),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _autoLoginIfNeeded,
                    child: Text(AppLocalizations.of(context)!.tryAgain),
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
        title: Text(AppLocalizations.of(context)!.bodyPartTracking),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getWorkoutsStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(AppLocalizations.of(context)!.errorGeneric),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // 部位別統計を計算
          final stats = _calculateBodyPartStats(snapshot.data!.docs);

          return Column(
            children: [
              Expanded(child: _buildStatsView(stats)),
              _buildCompactControlPanel(),
            ],
          );
        },
      ),
    );
  }

  /// コンパクトなコントロールパネル（下部配置）
  Widget _buildCompactControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppLocalizations.of(context)!.workout_36413c90,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text(AppLocalizations.of(context)!.workout_7097f864)),
                    ButtonSegment(value: 30, label: Text(AppLocalizations.of(context)!.workout_593f53b5)),
                    ButtonSegment(value: 90, label: Text(AppLocalizations.of(context)!.workout_e80812be)),
                  ],
                  selected: {_periodDays},
                  onSelectionChanged: (Set<int> selected) {
                    setState(() => _periodDays = selected.first);
                  },
                  style: ButtonStyle(
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 12),
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



  /// 統計表示ビュー（ビジュアル重視型）
  Widget _buildStatsView(Map<String, int> stats) {
    if (stats.isEmpty) {
      return _buildEmptyState();
    }

    final maxCount = stats.values.reduce((a, b) => a > b ? a : b);
    final sortedEntries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 不足部位を検出
    final insufficientParts = _getInsufficientParts(stats, maxCount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー（期間表示）
          Row(
            children: [
              const Icon(Icons.analytics_outlined, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.bodyPartBalanceDays(_periodDays),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 部位別プログレスバー（メイン表示）
          ...sortedEntries.map((entry) => _buildVisualBodyPartRow(
                entry.key,
                entry.value,
                maxCount,
              )),

          const SizedBox(height: 20),

          // 不足部位アラート（目立つ配置）
          if (insufficientParts.isNotEmpty) _buildInsufficientAlert(insufficientParts),
        ],
      ),
    );
  }



  /// ビジュアルな部位別行（提案A: ビジュアル重視型）
  Widget _buildVisualBodyPartRow(String bodyPart, int count, int maxCount) {
    final displayName = bodyPartNames[bodyPart] ?? bodyPart;
    final percentage = maxCount > 0 ? (count / maxCount) : 0.0;
    final color = _getColorForCount(count, maxCount);
    final isInsufficient = percentage < 0.5; // 最多部位の50%未満を不足とみなす

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 部位名と回数
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isInsufficient) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.warning_amber_rounded, 
                         size: 18, 
                         color: Colors.orange.shade700),
                  ],
                ],
              ),
              Row(
                children: [
                  Text(
                    '$count回',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(percentage * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 大きなプログレスバー
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 28,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  /// 不足部位アラート（目立つデザイン）
  Widget _buildInsufficientAlert(List<String> insufficientParts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, 
                   color: Colors.orange.shade700, 
                   size: 24),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.workout_e03f69fa,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: insufficientParts.map((part) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade400),
                ),
                child: Text(
                  part,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.workout_2f9761ff,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// 不足部位を取得
  List<String> _getInsufficientParts(Map<String, int> stats, int maxCount) {
    final insufficient = <String>[];
    
    for (final entry in stats.entries) {
      final percentage = maxCount > 0 ? (entry.value / maxCount) : 0.0;
      if (percentage < 0.5) { // 最多部位の50%未満
        final displayName = bodyPartNames[entry.key] ?? entry.key;
        insufficient.add(displayName);
      }
    }
    
    return insufficient;
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
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noWorkouts,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.workout_b3e9f505,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// ワークアウトストリーム取得（インデックス不要のシンプルクエリ）
  /// 🔧 v1.0.216: workout_logs コレクションを使用（add_workout_screen.dartと一致）
  Stream<QuerySnapshot> _getWorkoutsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('workout_logs')
        .where('user_id', isEqualTo: userId)
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


  /// カウントに応じた色を取得
  Color _getColorForCount(int count, int maxCount) {
    final percentage = maxCount > 0 ? count / maxCount : 0.0;

    if (percentage >= 0.8) return Colors.green;
    if (percentage >= 0.5) return Colors.blue;
    if (percentage >= 0.3) return Colors.orange;
    return Colors.red;
  }


}
