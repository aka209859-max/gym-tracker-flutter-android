import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        
        final volume = (data['weight'] as num?) ?? 0;
        final reps = (data['reps'] as num?) ?? 0;
        final sets = (data['sets'] as num?) ?? 0;
        final totalVolumeForLog = volume * reps * sets;
        
        totalVolume += totalVolumeForLog;
        
        if (data['muscle_group'] != null) {
          muscleGroups.add(data['muscle_group'] as String);
        }

        if (!dailyData.containsKey(dateKey)) {
          dailyData[dateKey] = {
            'date': date,
            'workouts': 0,
            'volume': 0.0,
            'muscleGroups': <String>{},
          };
        }
        
        dailyData[dateKey]!['workouts'] = (dailyData[dateKey]!['workouts'] as int) + 1;
        dailyData[dateKey]!['volume'] = (dailyData[dateKey]!['volume'] as double) + totalVolumeForLog;
        (dailyData[dateKey]!['muscleGroups'] as Set<String>).add(data['muscle_group'] as String? ?? 'Unknown');
      }

      final dailyStatsList = dailyData.entries.map((entry) {
        return {
          'date': entry.value['date'],
          'workouts': entry.value['workouts'],
          'volume': entry.value['volume'],
          'muscleGroupsCount': (entry.value['muscleGroups'] as Set).length,
        };
      }).toList();

      dailyStatsList.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      setState(() {
        _weeklyStats = {
          'totalWorkouts': totalWorkouts,
          'totalVolume': totalVolume,
          'muscleGroupsCount': muscleGroups.length,
          'averageVolume': totalWorkouts > 0 ? totalVolume / totalWorkouts : 0.0,
        };
        _dailyStats = dailyStatsList;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
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
        centerTitle: true,
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
                      const SizedBox(height: 20),
                      if (_dailyStats.isNotEmpty) _buildDailyStatsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    final totalWorkouts = _weeklyStats!['totalWorkouts'] as int;
    final totalVolume = _weeklyStats!['totalVolume'] as double;
    final muscleGroupsCount = _weeklyStats!['muscleGroupsCount'] as int;
    final averageVolume = _weeklyStats!['averageVolume'] as double;

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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '過去7日間のサマリー',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.fitness_center,
                  label: 'トレーニング',
                  value: '$totalWorkouts',
                ),
                _buildStatItem(
                  icon: Icons.straighten,
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
                  icon: Icons.category,
                  label: '鍛えた部位',
                  value: '$muscleGroupsCount',
                ),
                _buildStatItem(
                  icon: Icons.trending_up,
                  label: '平均ボリューム',
                  value: '${averageVolume.toStringAsFixed(0)}kg',
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
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              '過去7日間のトレーニング記録がありません',
              style: TextStyle(fontSize: 14, color: Colors.grey),
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
        ..._dailyStats.map((stat) => _buildDailyStatCard(stat)),
      ],
    );
  }

  Widget _buildDailyStatCard(Map<String, dynamic> stat) {
    final date = stat['date'] as DateTime;
    final workouts = stat['workouts'] as int;
    final volume = stat['volume'] as double;
    final muscleGroupsCount = stat['muscleGroupsCount'] as int;
    
    final dateStr = DateFormat('MMM d (E)').format(date);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade100,
          child: Text(
            DateFormat('d').format(date),
            style: TextStyle(
              color: Colors.purple.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          dateStr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$workouts回 • ${volume.toStringAsFixed(0)}kg • $muscleGroupsCount部位',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
