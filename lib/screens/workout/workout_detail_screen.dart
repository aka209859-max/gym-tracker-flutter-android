import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../../models/workout_log.dart';
import '../../models/workout_note.dart';
import '../../services/workout_note_service.dart';

/// トレーニング詳細画面
class WorkoutDetailScreen extends StatefulWidget {
  final WorkoutLog workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final WorkoutNoteService _noteService = WorkoutNoteService();
  WorkoutNote? _workoutNote;
  bool _isLoadingNote = true;

  @override
  void initState() {
    super.initState();
    _loadWorkoutNote();
  }

  // ワークアウトのメモを読み込み
  Future<void> _loadWorkoutNote() async {
    try {
      final note = await _noteService.getNoteByWorkoutSession(widget.workout.id);
      if (mounted) {
        setState(() {
          _workoutNote = note;
          _isLoadingNote = false;
        });
      }
    } catch (e) {
      // エラーが発生してもUIは表示する
      if (mounted) {
        setState(() {
          _isLoadingNote = false;
        });
      }
      // エラーログのみ出力（SnackBarは表示しない）
      debugPrint('⚠️ メモの読み込みエラー: $e');
    }
  }

  // ✅ v1.0.168: 腹筋系種目かどうかを判定
  bool _isAbsExercise(String exerciseName) {
    const absExercises = [
      AppLocalizations.of(context)!.crunch,
      AppLocalizations.of(context)!.legRaise,
      AppLocalizations.of(context)!.plank,
      AppLocalizations.of(context)!.abRoller,
      AppLocalizations.of(context)!.hangingLegRaise,
      AppLocalizations.of(context)!.sidePlank,
      AppLocalizations.of(context)!.bicycleCrunch,
      AppLocalizations.of(context)!.cableCrunch,
    ];
    return absExercises.contains(exerciseName);
  }

  // メモ追加・編集ダイアログを表示
  Future<void> _showNoteDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _workoutNote?.content ?? '');
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_workoutNote == null ? l10n.addNote : l10n.editNote),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: l10n.noteHint,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          if (_workoutNote != null)
            TextButton(
              onPressed: () => Navigator.pop(context, '__DELETE__'),
              child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    
    // メモリリーク防止：Controllerを破棄
    controller.dispose();

    if (result != null && mounted) {
      if (result == '__DELETE__') {
        await _deleteNote();
      } else if (result.trim().isNotEmpty) {
        await _saveNote(result.trim());
      }
    }
  }

  // メモを保存
  Future<void> _saveNote(String content) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (_workoutNote == null) {
        // 新規作成
        final newNote = await _noteService.createNote(
          userId: widget.workout.userId,
          workoutSessionId: widget.workout.id,
          content: content,
        );
        setState(() {
          _workoutNote = newNote;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.noteSaved), backgroundColor: Colors.green),
          );
        }
      } else {
        // 更新
        final updatedNote = await _noteService.updateNote(_workoutNote!.id, content);
        setState(() {
          _workoutNote = updatedNote;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.noteUpdated), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noteSaveFailed(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  // メモを削除
  Future<void> _deleteNote() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (_workoutNote != null) {
        await _noteService.deleteNote(_workoutNote!.id);
        setState(() {
          _workoutNote = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.noteDeleted)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noteDeleteFailed(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (kDebugMode) {
      debugPrint('🏗️ Building WorkoutDetailScreen');
      debugPrint('  Workout ID: ${widget.workout.id}');
      debugPrint('  Exercises count: ${widget.workout.exercises.length}');
      debugPrint('  Date: ${widget.workout.date}');
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workoutDetail),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // 編集機能（今後実装）
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // 削除機能（今後実装）
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 日付・時間
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy年MM月dd日 (E)', 'ja')
                            .format(widget.workout.date),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (widget.workout.duration != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '所要時間: ${widget.workout.duration}分',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                  if (widget.workout.gymName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          widget.workout.gymName!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 種目リスト
          ...widget.workout.exercises.map((exercise) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(
                          label: Text(exercise.bodyPart),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // セットリスト（テーブル形式ヘッダー）
                    Row(
                      children: [
                        const SizedBox(
                          width: 40,
                          child: Text(
                            AppLocalizations.of(context)!.workoutSetsLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.workout_2579352f,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            _isAbsExercise(exercise.name) ? AppLocalizations.of(context)!.workout_34d70475 : AppLocalizations.of(context)!.repsCount,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 60,
                          child: Text(
                            'RM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 40,
                          child: Text(
                            AppLocalizations.of(context)!.workout_c6b41e99,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 8),
                    // セットデータ（コンパクト表示）
                    ...exercise.sets.asMap().entries.map((entry) {
                      final index = entry.key;
                      final set = entry.value;
                      final oneRM = set.weight != null && set.actualReps != null
                          ? set.weight! * (1 + (set.actualReps! / 30))
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            // SetTypeバッジ + セット番号
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildSetTypeBadge(set.setType, set.dropsetLevel),
                                if (set.setType != SetType.normal) const SizedBox(width: 4),
                                SizedBox(
                                  width: set.setType == SetType.normal ? 40 : 24,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Text(
                                '${set.weight ?? 0} Kg',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                (set.isTimeMode ?? false)
                                    ? '${set.actualReps ?? set.targetReps}秒'
                                    : '${set.actualReps ?? set.targetReps}回',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '${oneRM.toStringAsFixed(1)}Kg',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: set.hasAssist == true
                                  ? const Icon(
                                      Icons.people,
                                      size: 16,
                                      color: Colors.orange,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),

          // トレーニングメモ（新機能）
          const SizedBox(height: 16),
          _buildNoteSection(),

          // 既存のworkout.notesメモ（互換性のため残す）
          if (widget.workout.notes != null && widget.workout.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.note, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          AppLocalizations.of(context)!.workout_e5798fef,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.workout.notes!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// トレーニングメモセクションを構築
  Widget _buildNoteSection() {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      child: InkWell(
        onTap: _showNoteDialog,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    AppLocalizations.of(context)!.trainingMemo,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoadingNote)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _workoutNote == null ? Icons.add_circle_outline : Icons.edit,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_workoutNote != null) ...[
                Text(
                  _workoutNote!.content,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '更新: ${DateFormat('yyyy/MM/dd HH:mm').format(_workoutNote!.updatedAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  AppLocalizations.of(context)!.workout_e5b3b7b2,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  /// SetTypeバッジを生成
  Widget _buildSetTypeBadge(SetType setType, int? dropsetLevel) {
    if (setType == SetType.normal) {
      return const SizedBox.shrink();
    }
    
    IconData icon;
    Color color;
    String label;
    
    switch (setType) {
      case SetType.warmup:
        icon = Icons.heat_pump;
        color = Colors.orange;
        label = 'WU';
        break;
      case SetType.superset:
        icon = Icons.compare_arrows;
        color = Colors.purple;
        label = 'SS';
        break;
      case SetType.dropset:
        icon = Icons.trending_down;
        color = Colors.blue;
        label = dropsetLevel != null ? 'DS$dropsetLevel' : 'DS';
        break;
      case SetType.failure:
        icon = Icons.local_fire_department;
        color = Colors.red;
        label = AppLocalizations.of(context)!.limit;
        break;
      default:
        return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
