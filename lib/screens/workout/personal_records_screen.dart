import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/personal_record.dart';

/// パーソナルレコード画面
class PersonalRecordsScreen extends StatefulWidget {
  const PersonalRecordsScreen({super.key});

  @override
  State<PersonalRecordsScreen> createState() => _PersonalRecordsScreenState();
}

class _PersonalRecordsScreenState extends State<PersonalRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedExercise;
  bool _isLoadingExercises = true;

  final List<String> _periods = ['月別', '3ヶ月', '6ヶ月', '9ヶ月', '1年'];
  List<String> _exercises = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _periods.length, vsync: this);
    _tabController.index = 1; // デフォルト3ヶ月
    _autoLoginIfNeeded();
    _loadExercisesFromHistory();
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

  /// Firestoreからトレーニング履歴を読み取り、種目リストを作成
  Future<void> _loadExercisesFromHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoadingExercises = false;
        });
        return;
      }

      // workout_logs コレクションから全トレーニングを取得
      final workoutSnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .get();

      // 全種目名をSetで収集（重複除外）
      final exerciseSet = <String>{};

      for (final doc in workoutSnapshot.docs) {
        final data = doc.data();
        final sets = data['sets'] as List<dynamic>? ?? [];
        
        for (final set in sets) {
          if (set is Map<String, dynamic>) {
            final name = set['exercise_name'] as String?;
            if (name != null && name.isNotEmpty) {
              exerciseSet.add(name);
            }
          }
        }
      }

      // SetをListに変換してソート
      final exerciseList = exerciseSet.toList()..sort();

      if (mounted) {
        setState(() {
          _exercises = exerciseList;
          if (_exercises.isNotEmpty) {
            _selectedExercise = _exercises.first;
          }
          _isLoadingExercises = false;
        });
      }

      debugPrint('✅ 種目リスト読み込み完了: ${_exercises.length}種目');
    } catch (e) {
      debugPrint('⚠️ 種目リスト読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _isLoadingExercises = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('パーソナルレコード')),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('パーソナルレコード')),
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
    // 種目リスト読み込み中
    if (_isLoadingExercises) {
      return Scaffold(
        appBar: AppBar(title: const Text('パーソナルレコード')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('種目を読み込み中...'),
            ],
          ),
        ),
      );
    }

    // 種目がない場合
    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('パーソナルレコード')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'まだトレーニング記録がありません',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'トレーニングを記録すると、ここに表示されます',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('パーソナルレコード'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _periods.map((p) => Tab(text: p)).toList(),
        ),
      ),
      body: Column(
        children: [
          // 種目選択
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedExercise,
              decoration: const InputDecoration(
                labelText: '種目を選択',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fitness_center),
              ),
              items: _exercises
                  .map((ex) => DropdownMenuItem(value: ex, child: Text(ex)))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedExercise = value!);
              },
            ),
          ),

          // タブビュー
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _periods.map((period) {
                return _PeriodView(
                  userId: user.uid,
                  exercise: _selectedExercise ?? '',
                  period: period,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodView extends StatelessWidget {
  final String userId;
  final String exercise;
  final String period;

  const _PeriodView({
    required this.userId,
    required this.exercise,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PersonalRecord>>(
      future: _fetchPRData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }

        final data = snapshot.data ?? [];

        if (data.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fitness_center, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'まだ記録がありません',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              // 成長グラフ
              Container(
                height: 300,
                padding: const EdgeInsets.all(16),
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}kg',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= data.length) {
                              return const Text('');
                            }

                            final date = data[index].achievedAt;
                            return Text(
                              '${date.month}/${date.day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.calculated1RM,
                          );
                        }).toList(),
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 成長統計
              if (data.length >= 2) _buildGrowthStats(data),

              // 記録リスト
              _buildRecordsList(data),
            ],
          ),
        );
      },
    );
  }

  Future<List<PersonalRecord>> _fetchPRData() async {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case '月別':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3ヶ月':
        startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case '6ヶ月':
        startDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case '9ヶ月':
        startDate = DateTime(now.year, now.month - 9, now.day);
        break;
      case '1年':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(now.year, now.month - 3, now.day);
    }

    // インデックス不要のシンプルなクエリ（where 1つのみ）
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('personalRecords')
        .where('exerciseName', isEqualTo: exercise)
        .get();

    // メモリ内でフィルタリングとソート
    final records = snapshot.docs
        .map((doc) => PersonalRecord.fromFirestore(
            doc.data() as Map<String, dynamic>, doc.id))
        .where((record) => record.achievedAt.isAfter(startDate))
        .toList();
    
    // 日付順にソート
    records.sort((a, b) => a.achievedAt.compareTo(b.achievedAt));
    
    return records;
  }

  Widget _buildGrowthStats(List<PersonalRecord> data) {
    final start = data.first;
    final current = data.last;
    final growthKg = current.calculated1RM - start.calculated1RM;
    final growthPercent = (growthKg / start.calculated1RM) * 100;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$periodの成長',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      '開始時 (1RM)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${start.calculated1RM.toStringAsFixed(1)}kg',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward, size: 32, color: Colors.grey),
                Column(
                  children: [
                    const Text(
                      '現在 (1RM)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${current.calculated1RM.toStringAsFixed(1)}kg',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  const Text(
                    '成長',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+${growthKg.toStringAsFixed(1)}kg (+${growthPercent.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
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

  Widget _buildRecordsList(List<PersonalRecord> data) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '記録履歴',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = data[data.length - 1 - index]; // 新しい順

              return ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  '${record.weight}kg × ${record.reps}回',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '1RM推定: ${record.calculated1RM.toStringAsFixed(1)}kg',
                ),
                trailing: Text(
                  DateFormat('MM/dd').format(record.achievedAt),
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
