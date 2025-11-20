import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/weekly_report.dart';

/// 週次レポート画面
class WeeklyReportsScreen extends StatefulWidget {
  const WeeklyReportsScreen({super.key});

  @override
  State<WeeklyReportsScreen> createState() => _WeeklyReportsScreenState();
}

class _WeeklyReportsScreenState extends State<WeeklyReportsScreen> {
  @override
  void initState() {
    super.initState();
    _autoLoginIfNeeded();
  }

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
            appBar: AppBar(title: const Text('週次レポート')),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('週次レポート')),
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
        title: const Text('週次レポート'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showReportSettings(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('weeklyReports')
            .snapshots(), // orderByを削除
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text(
                      '週次レポートはまだありません',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '毎週月曜日に自動生成されます\n（デモモードではCloud Function未実装のため手動データが必要です）',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assessment, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'まだ週次レポートがありません',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '毎週月曜日に自動生成されます',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final reports = snapshot.data!.docs
              .map((doc) => WeeklyReport.fromFirestore(
                  doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          
          // メモリ内でソート（weekEndの降順）
          reports.sort((a, b) => b.weekEnd.compareTo(a.weekEnd));
          
          // 最新10件のみ表示
          final displayReports = reports.take(10).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayReports.length,
            itemBuilder: (context, index) {
              return _ReportCard(report: displayReports[index]);
            },
          );
        },
      ),
    );
  }

  void _showReportSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('週次レポート設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('週次レコメンデーション'),
              subtitle: const Text('推奨曜日とメニュー提案を表示'),
              value: true,
              onChanged: (value) {
                // TODO: Save setting to Firestore
              },
            ),
          ],
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

class _ReportCard extends StatelessWidget {
  final WeeklyReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final weekRange =
        '${DateFormat('M/d').format(report.weekStart)} - ${DateFormat('M/d').format(report.weekEnd)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.calendar_today, color: Colors.blue),
        title: Text(
          weekRange,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${report.totalWorkouts}回 • ${report.totalMinutes}分'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 実績サマリー
                _buildSection(
                  '実績',
                  [
                    _InfoRow(
                      icon: Icons.fitness_center,
                      label: 'トレーニング回数',
                      value: '${report.totalWorkouts}回',
                    ),
                    _InfoRow(
                      icon: Icons.timer,
                      label: '合計時間',
                      value: '${report.totalMinutes}分',
                    ),
                    _InfoRow(
                      icon: Icons.local_fire_department,
                      label: 'ストリーク',
                      value: '${report.streak}日',
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // 部位別実施状況
                _buildSection(
                  '部位別実施状況',
                  [
                    ...report.bodyParts.entries.map((entry) {
                      return _BodyPartRow(
                        part: entry.key,
                        count: entry.value,
                        maxCount: report.bodyParts.values
                            .reduce((a, b) => a > b ? a : b),
                      );
                    }),
                  ],
                ),

                // レコメンデーション
                if (report.recommendations != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildRecommendations(report.recommendations!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildRecommendations(WeeklyRecommendation rec) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                '今週のレコメンデーション',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '目標: 週${rec.targetFrequency}回',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '推奨曜日: ${rec.suggestedDays.join('、')}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            rec.balanceAdvice,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _BodyPartRow extends StatelessWidget {
  final String part;
  final int count;
  final int maxCount;

  const _BodyPartRow({
    required this.part,
    required this.count,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = maxCount > 0 ? (count / maxCount) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  part,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '$count回',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
