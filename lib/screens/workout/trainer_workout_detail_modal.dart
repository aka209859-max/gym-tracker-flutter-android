import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/trainer_workout_service.dart';

/// トレーナー記録詳細モーダル（保存ボタン付き）
class TrainerWorkoutDetailModal extends StatefulWidget {
  final TrainerWorkoutRecord record;
  final VoidCallback? onSave;

  const TrainerWorkoutDetailModal({
    super.key,
    required this.record,
    this.onSave,
  });

  @override
  State<TrainerWorkoutDetailModal> createState() => _TrainerWorkoutDetailModalState();
}

class _TrainerWorkoutDetailModalState extends State<TrainerWorkoutDetailModal> {
  bool _isSaving = false;

  /// トレーナー記録を自己記録として保存
  Future<void> _saveAsPersonalRecord() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('ログインしていません');
      }

      // workout_logsコレクションに保存
      final workoutLogData = {
        'userId': user.uid,
        'date': widget.record.date,
        'exercises': widget.record.exercises.map((exercise) => {
          'name': exercise.name,
          'weight': exercise.weight,
          'reps': exercise.reps,
          'sets': exercise.sets,
        }).toList(),
        'notes': widget.record.trainerNotes,
        'duration': 60, // デフォルト60分
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'trainer', // トレーナー記録から保存されたことを示す
        'originalSessionId': widget.record.sessionId, // 元のセッションID
      };

      // ボディメトリクスがある場合は追加
      if (widget.record.bodyMetrics != null) {
        final metrics = widget.record.bodyMetrics!;
        if (metrics.weight != null) workoutLogData['weight'] = metrics.weight!;
        if (metrics.bodyFat != null) workoutLogData['bodyFat'] = metrics.bodyFat!;
        if (metrics.muscleMass != null) workoutLogData['muscleMass'] = metrics.muscleMass!;
      }

      await FirebaseFirestore.instance
          .collection('workout_logs')
          .add(workoutLogData);

      // 成功メッセージ
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSave?.call();
      }
    } catch (e) {
      // エラーメッセージ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '(パーソナルトレーニング)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.record.formattedDate,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // コンテンツ
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 種目リスト
                    const Text(
                      'トレーニング種目',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...widget.record.exercises.map((exercise) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildMetricChip('${exercise.weight}kg', Icons.fitness_center),
                              const SizedBox(width: 8),
                              _buildMetricChip('${exercise.reps}回', Icons.repeat),
                              const SizedBox(width: 8),
                              _buildMetricChip('${exercise.sets}セット', Icons.format_list_numbered),
                            ],
                          ),
                        ],
                      ),
                    )),

                    // ボディメトリクス
                    if (widget.record.bodyMetrics != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        '体重・体組成',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          children: [
                            if (widget.record.bodyMetrics!.weight != null)
                              _buildMetricRow('体重', '${widget.record.bodyMetrics!.weight}kg'),
                            if (widget.record.bodyMetrics!.bodyFat != null)
                              _buildMetricRow('体脂肪率', '${widget.record.bodyMetrics!.bodyFat}%'),
                            if (widget.record.bodyMetrics!.muscleMass != null)
                              _buildMetricRow('筋肉量', '${widget.record.bodyMetrics!.muscleMass}kg'),
                          ],
                        ),
                      ),
                    ],

                    // トレーナーメモ
                    if (widget.record.trainerNotes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'トレーナーメモ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          widget.record.trainerNotes,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // 保存ボタン
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveAsPersonalRecord,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? '保存中...' : 'この記録を保存する'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 説明テキスト
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '保存すると、この記録があなたのワークアウト記録に追加されます。元のトレーナー記録は残ります。',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.orange),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
