import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// 週間トレーニング統計画面
class WeeklyStatsScreen extends StatefulWidget {
  const WeeklyStatsScreen({super.key});

  @override
  State<WeeklyStatsScreen> createState() => _WeeklyStatsScreenState();
}

class _WeeklyStatsScreenState extends State<WeeklyStatsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Map<String, dynamic>? _weeklyStats;
  List<Map<String, dynamic>> _dailyStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyStats();
  }

  Future<void> _loadWeeklyStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .get();

      int totalWorkouts = snapshot.docs.length;
      double totalVolume = 0.0;
      Set<String> muscleGroups = {};
      Map<String, Map<String, dynamic>> dailyData = {};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final date = (data['date'] as Timestamp?)?.toDate();
          if (date == null) continue;

          final dateKey = DateFormat('yyyy-MM-dd').format(date);

          // 日別データの初期化
          if (!dailyData.containsKey(dateKey)) {
            dailyData[dateKey] = {
              'date': date,
              'workouts': 0,
              'volume': 0.0,
              'muscleGroups': <String>{},
            };
          }

          dailyData[dateKey]!['workouts'] = (dailyData[dateKey]!['workouts'] as int) + 1;

          final setsData = data['sets'];
          if (setsData != null && setsData is List) {
            final sets = List<Map<String, dynamic>>.from(setsData);
            
            for (var set in sets) {
              if (set is! Map) continue;
              final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
              final reps = (set['reps'] as int?) ?? 0;
              final setVolume = weight * reps;
              totalVolume += setVolume;
              dailyData[dateKey]!['volume'] = (dailyData[dateKey]!['volume'] as double) + setVolume;
            }
          }

          final muscleGroup = data['muscle_group'];
          if (muscleGroup != null && muscleGroup is String && muscleGroup.isNotEmpty) {
            muscleGroups.add(muscleGroup);
            (dailyData[dateKey]!['muscleGroups'] as Set<String>).add(muscleGroup);
          }
        } catch (e) {
          continue;
        }
      }

      // 日別統計をリストに変換
      final dailyStatsList = dailyData.entries.map((entry) {
        return {
          'date': entry.value['date'],
          'workouts': entry.value['workouts'],
          'volume': entry.value['volume'],
          'muscleGroupsCount': (entry.value['muscleGroups'] as Set).length,
        };
      }).toList();

      // 日付順にソート
      dailyStatsList.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      setState(() {
        _weeklyStats = {
          'totalWorkouts': totalWorkouts,
          'totalVolume': totalVolume,
          'muscleGroupsCount': muscleGroups.length,
          'avgVolumePerWorkout': totalWorkouts > 0 ? totalVolume / totalWorkouts : 0.0,
        };
        _dailyStats = dailyStatsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データの読み込みに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('週間トレーニング統計'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _weeklyStats == null
              ? const Center(child: Text('データがありません'))
              : RefreshIndicator(
                  onRefresh: _loadWeeklyStats,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildDailyStatsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    final stats = _weeklyStats!;
    final totalWorkouts = stats['totalWorkouts'] as int;
    final totalVolume = stats['totalVolume'] as double;
    final muscleGroupsCount = stats['muscleGroupsCount'] as int;
    final avgVolume = stats['avgVolumePerWorkout'] as double;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade400,
              Colors.deepPurple.shade600,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Text(
                  '過去7日間のサマリー',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.fitness_center,
                  label: 'トレーニング',
                  value: '$totalWorkouts回',
                ),
                _buildStatItem(
                  icon: Icons.show_chart,
                  label: '総ボリューム',
                  value: '${totalVolume.toStringAsFixed(0)}kg',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.accessibility_new,
                  label: '鍛えた部位',
                  value: '$muscleGroupsCount部位',
                ),
                _buildStatItem(
                  icon: Icons.trending_up,
                  label: '平均ボリューム',
                  value: '${avgVolume.toStringAsFixed(0)}kg',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyStatsSection() {
    if (_dailyStats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              '過去7日間のトレーニング記録がありません',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '日別統計',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._dailyStats.map((stat) => _buildDailyStatCard(stat)).toList(),
      ],
    );
  }

  Widget _buildDailyStatCard(Map<String, dynamic> stat) {
    final date = stat['date'] as DateTime;
    final workouts = stat['workouts'] as int;
    final volume = stat['volume'] as double;
    final muscleGroupsCount = stat['muscleGroupsCount'] as int;

    final dateStr = DateFormat('M月d日(E)', 'ja').format(date);
    final isToday = DateFormat('yyyy-MM-dd').format(date) == 
                    DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isToday ? Colors.purple : Colors.grey.shade300,
          child: Text(
            date.day.toString(),
            style: TextStyle(
              color: isToday ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          dateStr,
          style: TextStyle(
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          '$workouts回 • ${volume.toStringAsFixed(0)}kg • $muscleGroupsCount部位',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}
