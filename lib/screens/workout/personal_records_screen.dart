import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/personal_record.dart';
import '../../services/exercise_master_data.dart'; // 🔧 v1.0.245: Problem 3 fix

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

  final List<String> _periods = [AppLocalizations.of(context)!.workout_133db81d, AppLocalizations.of(context)!.workout_962e3667, AppLocalizations.of(context)!.workout_a5546a18, AppLocalizations.of(context)!.workout_c6912d4d, AppLocalizations.of(context)!.workout_160f26bf, AppLocalizations.of(context)!.workout_2c6e4910];
  List<String> _exercises = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _periods.length, vsync: this);
    _tabController.index = 2; // デフォルト3ヶ月（インデックス2）
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
  /// 🔧 v1.0.251: 部位別にグルーピングして取得
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
      // 🔧 v1.0.216: user_id (snake_case) を使用（add_workout_screen.dartと一致）
      final workoutSnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .get();

      // 全種目名をSetで収集（重複除外）
      final exerciseSet = <String>{};

      for (final doc in workoutSnapshot.docs) {
        final data = doc.data();
        // 🔧 v1.0.216: sets 配列を使用（add_workout_screen.dartと一致）
        final exercises = data['sets'] as List<dynamic>? ?? [];
        
        for (final exercise in exercises) {
          if (exercise is Map<String, dynamic>) {
            // 🔧 v1.0.216: exercise_name フィールドを使用（add_workout_screen.dartと一致）
            final name = exercise['exercise_name'] as String?;
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
            appBar: AppBar(title: Text(AppLocalizations.of(context)!.personalRecord)),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: Text(AppLocalizations.of(context)!.personalRecord)),
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

  // 🔧 v1.0.251: 部位別カテゴリー表示へ変更
  Widget _buildMainContent(User user) {
    // 種目リスト読み込み中
    if (_isLoadingExercises) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.personalRecord)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.loading),
            ],
          ),
        ),
      );
    }

    // 種目がない場合
    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.personalRecord)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.noWorkoutRecords,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.workout_27312ddb,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    // 🔧 v1.0.251: 部位別カテゴリー表示（胸・背中・肩・二頭・三頭・腹筋・脚）
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.personalRecord)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBodyPartCategory(user.uid, AppLocalizations.of(context)!.bodyPartChest, Icons.fitness_center, Colors.red),
          _buildBodyPartCategory(user.uid, AppLocalizations.of(context)!.bodyPartBack, Icons.fitness_center, Colors.blue),
          _buildBodyPartCategory(user.uid, AppLocalizations.of(context)!.bodyPartShoulders, Icons.fitness_center, Colors.orange),
          _buildBodyPartCategory(user.uid, AppLocalizations.of(context)!.bodyPartBiceps, Icons.fitness_center, Colors.purple),
          _buildBodyPartCategory(user.uid, AppLocalizations.of(context)!.bodyPartTriceps, Icons.fitness_center, Colors.pink),
          _buildBodyPartCategory(user.uid, AppLocalizations.of(context)!.bodyPart_ceb49fa1, Icons.fitness_center, Colors.green),
          _buildBodyPartCategory(user.uid, AppLocalizations.of(context)!.bodyPartLegs, Icons.fitness_center, Colors.brown),
          _buildBodyPartCategory(user.uid, AppLocalizations.of(context)!.exerciseCardio, Icons.directions_run, Colors.teal),
        ],
      ),
    );
  }

  // 🔧 v1.0.253: すべての部位を常に表示（記録なしでも表示）
  Widget _buildBodyPartCategory(String userId, String bodyPart, IconData icon, Color color) {
    // この部位に属する種目をフィルタリング
    final bodyPartExercises = _exercises.where((exerciseName) {
      final detectedBodyPart = ExerciseMasterData.getBodyPartByName(exerciseName);
      return detectedBodyPart == bodyPart;
    }).toList();

    // 🔧 v1.0.253: 記録がなくても常に表示（0種目として表示）
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(
          bodyPart,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text('${bodyPartExercises.length}種目'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // 🔧 v1.0.253: 記録がない場合も遷移可能（空の一覧画面）
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExerciseListScreen(
                userId: userId,
                bodyPart: bodyPart,
                exercises: bodyPartExercises,
              ),
            ),
          );
        },
      ),
    );
  }

  // 🔧 v1.0.245: PRカードウィジェット（Problem 3 fix）
  Widget _buildPRCard(String userId, String exerciseName) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            ExerciseMasterData.isCardioExercise(exerciseName)
                ? Icons.directions_run
                : Icons.fitness_center,
            color: Colors.purple,
          ),
        ),
        title: Text(
          exerciseName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(AppLocalizations.of(context)!.confirm),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // 詳細画面（グラフ）へ遷移
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PRDetailScreen(
                userId: userId,
                exerciseName: exerciseName,
              ),
            ),
          );
        },
      ),
    );
  }
}

// 🔧 v1.0.245: Problem 3 fix - PR詳細画面（グラフ表示）
class PRDetailScreen extends StatefulWidget {
  final String userId;
  final String exerciseName;

  const PRDetailScreen({
    super.key,
    required this.userId,
    required this.exerciseName,
  });

  @override
  State<PRDetailScreen> createState() => _PRDetailScreenState();
}

class _PRDetailScreenState extends State<PRDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _periods = [AppLocalizations.of(context)!.workout_133db81d, AppLocalizations.of(context)!.workout_962e3667, AppLocalizations.of(context)!.workout_a5546a18, AppLocalizations.of(context)!.workout_c6912d4d, AppLocalizations.of(context)!.workout_160f26bf, AppLocalizations.of(context)!.workout_2c6e4910];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _periods.length, vsync: this);
    _tabController.index = 2; // デフォルト3ヶ月（インデックス2）
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _periods.map((p) => Tab(text: p)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _periods.map((period) {
          return _PeriodView(
            userId: widget.userId,
            exercise: widget.exerciseName,
            period: period,
          );
        }).toList(),
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
          return Center(child: Text(AppLocalizations.of(context)!.snapshotError(snapshot.error.toString())));
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
                  AppLocalizations.of(context)!.workout_3ca27cb2,
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
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            // 🔧 v1.0.246: 有酸素運動の場合は「分」、筋トレは「kg」
                            final isCardio = data.isNotEmpty && data.first.isCardio;
                            final unit = isCardio ? AppLocalizations.of(context)!.minutes : AppLocalizations.of(context)!.kg;
                            return Text(
                              '${value.toInt()}$unit',
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
              if (data.length >= 2) _buildGrowthStats(context, data),

              // 記録リスト
              _buildRecordsList(data),
            ],
          ),
        );
      },
    );
  }

  // 🔧 v1.0.246: workout_logsから実際のトレーニングデータを取得
  Future<List<PersonalRecord>> _fetchPRData() async {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case AppLocalizations.of(context)!.workout_133db81d:
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case AppLocalizations.of(context)!.workout_962e3667:
        startDate = DateTime(now.year, now.month - 2, now.day);
        break;
      case AppLocalizations.of(context)!.workout_a5546a18:
        startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case AppLocalizations.of(context)!.workout_c6912d4d:
        startDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case AppLocalizations.of(context)!.workout_160f26bf:
        startDate = DateTime(now.year, now.month - 9, now.day);
        break;
      case AppLocalizations.of(context)!.workout_2c6e4910:
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(now.year, now.month - 3, now.day);
    }

    try {
      // workout_logsコレクションから取得
      final snapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      debugPrint('📊 PR記録取得: ${snapshot.docs.length}件のworkout_logs (種目: $exercise)');

      // 各ワークアウトログから指定種目のPRを抽出
      final List<PersonalRecord> records = [];
      int totalSetsChecked = 0;
      int matchedSets = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final sets = data['sets'] as List<dynamic>? ?? [];
        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        for (final set in sets) {
          totalSetsChecked++;
          if (set is Map<String, dynamic>) {
            final exerciseName = set['exercise_name'] as String?;
            
            // 指定種目のみ抽出（nullチェック追加）
            if (exerciseName == exercise && exerciseName != null) {
              matchedSets++;
              debugPrint('  ✅ マッチした種目: $exerciseName (weight: ${set['weight']}, reps: ${set['reps']})');
              
              final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
              final reps = (set['reps'] as int?) ?? 0;
              final isCardio = set['is_cardio'] as bool? ?? ExerciseMasterData.isCardioExercise(exerciseName); // 🔧 v1.0.251: 後方互換性
              // 🔧 v1.0.253: 完了/未完了に関わらずホーム画面に表示される = PRに反映
              // final isCompleted = set['is_completed'] as bool? ?? true; // 不要になった
              
              // 🔧 v1.0.253: 完了フラグをチェックしない（ホーム画面に表示されていればPRに反映）
              // - 有酸素: 時間(weight)が0より大きい、または回数(reps)が0より大きい
              // - 筋トレ: 回数(reps)が0より大きい（自重の場合weight=0も許可）
              final hasValidData = isCardio 
                  ? (weight > 0 || reps > 0) // 有酸素: 時間または距離/回数
                  : (reps > 0); // 筋トレ: 回数があればOK（自重でもweight=0を許可）
              
              if (hasValidData) {
                // 有酸素運動の場合は1RM計算しない（時間×距離で表示）
                final calculated1RM = isCardio 
                    ? weight // 有酸素は時間をそのまま使用
                    : _calculate1RM(weight, reps);
                
                records.add(PersonalRecord(
                  id: '${doc.id}_${set['exercise_name']}_${date.millisecondsSinceEpoch}',
                  userId: userId,
                  exerciseName: exerciseName,
                  weight: weight,
                  reps: reps,
                  calculated1RM: calculated1RM,
                  achievedAt: date,
                  isCardio: isCardio,
                ));
              }
            }
          }
        }
      }
      
      // 日付順にソート
      records.sort((a, b) => a.achievedAt.compareTo(b.achievedAt));
      
      debugPrint('✅ ${exercise}のPR記録: ${records.length}件 (確認したセット数: $totalSetsChecked, マッチした種目: $matchedSets)');
      return records;
      
    } catch (e) {
      debugPrint('❌ PR記録取得エラー: $e');
      return [];
    }
  }
  
  // 1RM計算（Epley式）
  double _calculate1RM(double weight, int reps) {
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  Widget _buildGrowthStats(BuildContext context, List<PersonalRecord> data) {
    final start = data.first;
    final current = data.last;
    final isCardio = start.isCardio;  // 🔧 v1.0.246: 有酸素運動判定
    
    final growthValue = current.calculated1RM - start.calculated1RM;
    final growthPercent = (growthValue / start.calculated1RM) * 100;
    
    // 🔧 v1.0.246: 有酸素は「時間」、筋トレは「1RM」
    final label = isCardio ? AppLocalizations.of(context)!.time : AppLocalizations.of(context)!.oneRepMax;
    final unit = isCardio ? AppLocalizations.of(context)!.minutes : AppLocalizations.of(context)!.kg;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${period}の成長',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '開始時 ($label)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${start.calculated1RM.toStringAsFixed(1)}$unit',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward, size: 32, color: Colors.grey),
                Column(
                  children: [
                    Text(
                      '現在 ($label)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${current.calculated1RM.toStringAsFixed(1)}$unit',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Text(AppLocalizations.of(context)!.executeGrowthPrediction,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+${growthValue.toStringAsFixed(1)}$unit (+${growthPercent.toStringAsFixed(1)}%)',
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
              AppLocalizations.of(context)!.workout_16013f46,
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

              // 🔧 v1.0.246: 有酸素運動は「時間 × 距離」、筋トレは「重量 × 回数」
              final isCardio = record.isCardio;
              final title = isCardio
                  ? '${record.weight.toStringAsFixed(1)}分 × ${record.reps}km'
                  : '${record.weight}kg × ${record.reps}回';
              final subtitle = isCardio
                  ? '合計時間: ${record.calculated1RM.toStringAsFixed(1)}分'
                  : '1RM推定: ${record.calculated1RM.toStringAsFixed(1)}kg';
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCardio ? Colors.orange : Colors.blue,
                  child: Icon(
                    isCardio ? Icons.directions_run : Icons.fitness_center,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(subtitle),
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

// 🔧 v1.0.251: 部位別の種目一覧画面
class ExerciseListScreen extends StatelessWidget {
  final String userId;
  final String bodyPart;
  final List<String> exercises;

  const ExerciseListScreen({
    super.key,
    required this.userId,
    required this.bodyPart,
    required this.exercises,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$bodyPart - PR記録'),
      ),
      body: exercises.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'まだ$bodyPartの記録がありません',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.workout_27312ddb,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exerciseName = exercises[index];
                final isCardio = ExerciseMasterData.isCardioExercise(exerciseName);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isCardio ? Colors.teal : Colors.purple).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCardio ? Icons.directions_run : Icons.fitness_center,
                        color: isCardio ? Colors.teal : Colors.purple,
                      ),
                    ),
                    title: Text(
                      exerciseName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(AppLocalizations.of(context)!.confirm),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // 詳細画面（グラフ）へ遷移
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PRDetailScreen(
                            userId: userId,
                            exerciseName: exerciseName,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
