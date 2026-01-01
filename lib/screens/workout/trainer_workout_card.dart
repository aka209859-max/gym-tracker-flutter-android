import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/trainer_workout_service.dart';

/// トレーナー記録専用カード
/// GYM MATCH Managerから共有されたトレーニング記録を表示
class TrainerWorkoutCard extends StatelessWidget {
  final TrainerWorkoutRecord record;

  const TrainerWorkoutCard({
    super.key,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.orange[50], // トレーナー記録は目立つオレンジ背景
      elevation: 3,
      child: InkWell(
        onTap: () {
          _showTrainerWorkoutDetail(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー行（日付 + パーソナルトレーニングバッジ）
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy/MM/dd (E)', 'ja').format(record.date),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // パーソナルトレーニングバッジ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[700],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '(パーソナルトレーニング)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 時間表示
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${record.duration}分',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // トレーナー情報
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    'トレーナー: ${record.trainerName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 種目リスト（最大3件表示）
              ...record.exercises.take(3).map((exercise) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.fitness_center, size: 14, color: Colors.orange[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (exercise.formattedDetails.isNotEmpty)
                      Text(
                        exercise.formattedDetails,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              )),
              
              // 種目が4件以上ある場合の表示
              if (record.exercises.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '他${record.exercises.length - 3}種目',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              
              // トレーナーメモがある場合
              if (record.trainerNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.message, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          record.trainerNotes,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showTrainerWorkoutDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ヘッダー
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.fitness_center, color: Colors.orange[700]),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                          AppLocalizations.of(context)!.personalTraining,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('yyyy/MM/dd (E)', 'ja').format(record.date),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              // コンテンツ
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // トレーナー情報
                    _buildInfoRow(AppLocalizations.of(context)!.trainers, record.trainerName),
                    _buildInfoRow(AppLocalizations.of(context)!.duration, '${record.duration}分'),
                    _buildInfoRow(AppLocalizations.of(context)!.workout_c34d51a0, _getIntensityLabel(context, record.intensity)),
                    
                    const SizedBox(height: 24),
                    const Text(
                      AppLocalizations.of(context)!.workout_6635091c,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 全種目リスト
                    ...record.exercises.map((exercise) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (exercise.formattedDetails.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                exercise.formattedDetails,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )),
                    
                    // 体組成
                    if (record.bodyMetrics != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        AppLocalizations.of(context)!.workout_85a5a0ad,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (record.bodyMetrics!.weight != null)
                                _buildMetricRow(AppLocalizations.of(context)!.weight, '${record.bodyMetrics!.weight}kg'),
                              if (record.bodyMetrics!.bodyFat != null)
                                _buildMetricRow(AppLocalizations.of(context)!.bodyFat, '${record.bodyMetrics!.bodyFat}%'),
                              if (record.bodyMetrics!.muscleMass != null)
                                _buildMetricRow(AppLocalizations.of(context)!.muscleMass, '${record.bodyMetrics!.muscleMass}kg'),
                            ],
                          ),
                        ),
                      ),
                    ],
                    
                    // トレーナーメモ
                    if (record.trainerNotes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        AppLocalizations.of(context)!.workout_ffc76989,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Text(
                          record.trainerNotes,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getIntensityLabel(BuildContext context, String intensity) {
    switch (intensity) {
      case 'low':
        return AppLocalizations.of(context)!.workout_c55c9549;
      case 'high':
        return AppLocalizations.of(context)!.workout_eaaa4898;
      case 'medium':
      default:
        return AppLocalizations.of(context)!.crowdLevelNormal;
    }
  }
}
