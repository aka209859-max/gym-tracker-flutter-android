import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// Task 11: トレーニング統計ダッシュボード
class StatisticsDashboardScreen extends StatefulWidget {
  const StatisticsDashboardScreen({super.key});

  @override
  State<StatisticsDashboardScreen> createState() => _StatisticsDashboardScreenState();
}

class _StatisticsDashboardScreenState extends State<StatisticsDashboardScreen> {
  bool _isLoading = true;
  
  // 統計データ
  int _weeklyWorkoutDays = 0;
  int _weeklyTotalSets = 0;
  int _weeklyTotalMinutes = 0;
  int _monthlyWorkoutDays = 0;
  int _monthlyTotalSets = 0;
  int _currentStreak = 0;
  Map<String, int> _muscleGroupCount = {};
  List<Map<String, dynamic>> _weeklyData = [];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // 週間統計
      await _loadWeeklyStats(user.uid, weekStart);
      
      // 月間統計
      await _loadMonthlyStats(user.uid, monthStart);
      
      // ストリーク計算
      await _calculateStreak(user.uid);

    } catch (e) {
      debugPrint('統計読み込みエラー: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadWeeklyStats(String userId, DateTime weekStart) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('workout_logs')
        .where('user_id', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get();

    final workoutDates = <String>{};
    int totalSets = 0;
    int totalMinutes = 0;
    final muscleGroups = <String, int>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      workoutDates.add(DateFormat('yyyy-MM-dd').format(date));
      
      final sets = data['sets'] as List<dynamic>? ?? [];
      totalSets += sets.length;
      
      final startTime = (data['start_time'] as Timestamp?)?.toDate();
      final endTime = (data['end_time'] as Timestamp?)?.toDate();
      if (startTime != null && endTime != null) {
        totalMinutes += endTime.difference(startTime).inMinutes;
      }
      
      final muscleGroup = data['muscle_group'] as String? ?? '不明';
      muscleGroups[muscleGroup] = (muscleGroups[muscleGroup] ?? 0) + 1;
    }

    if (mounted) {
      setState(() {
        _weeklyWorkoutDays = workoutDates.length;
        _weeklyTotalSets = totalSets;
        _weeklyTotalMinutes = totalMinutes;
        _muscleGroupCount = muscleGroups;
      });
    }
  }

  Future<void> _loadMonthlyStats(String userId, DateTime monthStart) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('workout_logs')
        .where('user_id', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .get();

    final workoutDates = <String>{};
    int totalSets = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      workoutDates.add(DateFormat('yyyy-MM-dd').format(date));
      
      final sets = data['sets'] as List<dynamic>? ?? [];
      totalSets += sets.length;
    }

    if (mounted) {
      setState(() {
        _monthlyWorkoutDays = workoutDates.length;
        _monthlyTotalSets = totalSets;
      });
    }
  }

  Future<void> _calculateStreak(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('workout_logs')
        .where('user_id', isEqualTo: userId)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() => _currentStreak = 0);
      return;
    }

    // 日付でソート
    final dates = snapshot.docs
        .map((doc) => (doc.data()['date'] as Timestamp).toDate())
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime? lastDate;

    for (final date in dates) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      if (lastDate == null) {
        // 最初の日付
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        
        if (dateOnly == todayOnly || dateOnly == todayOnly.subtract(const Duration(days: 1))) {
          streak = 1;
          lastDate = dateOnly;
        } else {
          break;
        }
      } else {
        // 連続チェック
        if (lastDate.difference(dateOnly).inDays == 1) {
          streak++;
          lastDate = dateOnly;
        } else {
          break;
        }
      }
    }

    if (mounted) {
      setState(() => _currentStreak = streak);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('統計ダッシュボード'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('統計ダッシュボード'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: '更新',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 週間概要カード
              _buildWeeklySummaryCard(theme),
              const SizedBox(height: 16),
              
              // ストリークカード
              _buildStreakCard(theme),
              const SizedBox(height: 16),
              
              // 月間統計カード
              _buildMonthlySummaryCard(theme),
              const SizedBox(height: 16),
              
              // 部位別トレーニンググラフ
              _buildMuscleGroupChart(theme),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklySummaryCard(ThemeData theme) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                const Text(
                  '今週の概要',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.fitness_center,
                    label: 'トレーニング日数',
                    value: '$_weeklyWorkoutDays日',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.list_alt,
                    label: '総セット数',
                    value: '$_weeklyTotalSetsセット',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.timer,
                    label: 'トレーニング時間',
                    value: '$_weeklyTotalMinutes分',
                    color: Colors.orange,
                  ),
                ),
                Expanded(
                  child: Container(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(ThemeData theme) {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              '$_currentStreak日連続',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '連続トレーニング記録',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummaryCard(ThemeData theme) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.date_range, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                const Text(
                  '今月の統計',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.event_available,
                    label: 'トレーニング日数',
                    value: '$_monthlyWorkoutDays日',
                    color: Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.bar_chart,
                    label: '総セット数',
                    value: '$_monthlyTotalSetsセット',
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleGroupChart(ThemeData theme) {
    if (_muscleGroupCount.isEmpty) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                '部位別データがありません',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final total = _muscleGroupCount.values.fold<int>(0, (sum, count) => sum + count);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                const Text(
                  '部位別トレーニング（今週）',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._muscleGroupCount.entries.map((entry) {
              final percentage = (entry.value / total * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${entry.value}回 ($percentage%)',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: entry.value / total,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getColorForMuscleGroup(entry.key),
                      ),
                      minHeight: 8,
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getColorForMuscleGroup(String muscleGroup) {
    final colors = {
      '胸': Colors.red,
      '背中': Colors.blue,
      '脚': Colors.green,
      '肩': Colors.orange,
      '腕': Colors.purple,
      '二頭': Colors.indigo,
      '三頭': Colors.pink,
      '体幹': Colors.teal,
      '有酸素': Colors.amber,
    };
    return colors[muscleGroup] ?? Colors.grey;
  }
}
