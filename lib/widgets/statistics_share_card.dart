import 'package:flutter/material.dart';

/// Task 27: 統計データシェア用カード
class StatisticsShareCard extends StatelessWidget {
  final int weeklyWorkoutDays;
  final int weeklyTotalSets;
  final int weeklyTotalMinutes;
  final int monthlyWorkoutDays;
  final int monthlyTotalSets;
  final int currentStreak;
  final Map<String, int> muscleGroupCount;

  const StatisticsShareCard({
    super.key,
    required this.weeklyWorkoutDays,
    required this.weeklyTotalSets,
    required this.weeklyTotalMinutes,
    required this.monthlyWorkoutDays,
    required this.monthlyTotalSets,
    required this.currentStreak,
    required this.muscleGroupCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.shade600,
            Colors.deepPurple.shade900,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bar_chart,
                  color: Colors.deepPurple.shade700,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GYM MATCH',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.general_cbca9048,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),

          // ストリークカード（目立つように）
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  '$currentStreak日連続',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  AppLocalizations.of(context)!.workout_a826db5c,
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 週間統計
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.deepPurple.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.general_124aaff7,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.fitness_center,
                      label: AppLocalizations.of(context)!.trainingDays,
                      value: '$weeklyWorkoutDays',
                      unit: AppLocalizations.of(context)!.sun,
                      color: Colors.blue,
                    ),
                    _buildStatItem(
                      icon: Icons.list_alt,
                      label: AppLocalizations.of(context)!.workoutTotalSets,
                      value: '$weeklyTotalSets',
                      unit: 'sets',
                      color: Colors.green,
                    ),
                    _buildStatItem(
                      icon: Icons.timer,
                      label: AppLocalizations.of(context)!.workoutDuration,
                      value: '$weeklyTotalMinutes',
                      unit: AppLocalizations.of(context)!.minutes,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 月間統計
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.date_range,
                      color: Colors.deepPurple.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.general_d2429b27,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.event_available,
                      label: AppLocalizations.of(context)!.trainingDays,
                      value: '$monthlyWorkoutDays',
                      unit: AppLocalizations.of(context)!.sun,
                      color: Colors.purple,
                    ),
                    _buildStatItem(
                      icon: Icons.bar_chart,
                      label: AppLocalizations.of(context)!.workoutTotalSets,
                      value: '$monthlyTotalSets',
                      unit: 'sets',
                      color: Colors.teal,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 部位別トレーニングバランス
          if (muscleGroupCount.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.pie_chart,
                        color: Colors.deepPurple.shade700,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.general_5aa4062e,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...muscleGroupCount.entries.take(5).map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getColorForMuscleGroup(entry.key)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: entry.value /
                                    muscleGroupCount.values
                                        .reduce((a, b) => a > b ? a : b),
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _getColorForMuscleGroup(entry.key),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${entry.value}回',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          const SizedBox(height: 30),

          // フッター
          Center(
            child: Text(
              '#GYMMATCH #トレーニング統計 #筋トレ継続',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getColorForMuscleGroup(String muscleGroup) {
    final colors = {
      AppLocalizations.of(context)!.bodyPartChest: Colors.red,
      AppLocalizations.of(context)!.bodyPartBack: Colors.blue,
      AppLocalizations.of(context)!.bodyPartLegs: Colors.green,
      AppLocalizations.of(context)!.bodyPartShoulders: Colors.orange,
      AppLocalizations.of(context)!.bodyPartArms: Colors.purple,
      AppLocalizations.of(context)!.bodyPartBiceps: Colors.indigo,
      AppLocalizations.of(context)!.bodyPartTriceps: Colors.pink,
      AppLocalizations.of(context)!.bodyPartCore: Colors.teal,
      AppLocalizations.of(context)!.exerciseCardio: Colors.amber,
    };
    return colors[muscleGroup] ?? Colors.grey;
  }
}
