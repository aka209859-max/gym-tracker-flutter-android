import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/workout_note.dart';
import '../../services/workout_note_service.dart';

/// シンプルなトレーニング詳細画面（workout_logsデータ用）
class SimpleWorkoutDetailScreen extends StatefulWidget {
  final String workoutId;
  final Map<String, dynamic> workoutData;

  const SimpleWorkoutDetailScreen({
    super.key,
    required this.workoutId,
    required this.workoutData,
  });

  @override
  State<SimpleWorkoutDetailScreen> createState() => _SimpleWorkoutDetailScreenState();
}

class _SimpleWorkoutDetailScreenState extends State<SimpleWorkoutDetailScreen> {
  final WorkoutNoteService _noteService = WorkoutNoteService();
  WorkoutNote? _workoutNote;
  bool _isLoadingNote = true;

  /// 有酸素運動かどうかを判定
  bool get _isCardio {
    final muscleGroup = widget.workoutData['muscle_group'] as String? ?? '';
    return muscleGroup == '有酸素';
  }

  @override
  void initState() {
    super.initState();
    _loadWorkoutNote();
  }

  // ワークアウトのメモを読み込み
  Future<void> _loadWorkoutNote() async {
    try {
      final note = await _noteService.getNoteByWorkoutSession(widget.workoutId);
      if (mounted) {
        setState(() {
          _workoutNote = note;
          _isLoadingNote = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNote = false;
        });
      }
      debugPrint('⚠️ メモの読み込みエラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.workoutData;
    
    // データ解析
    final muscleGroup = data['muscle_group'] as String? ?? '不明';
    final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final startTime = (data['start_time'] as Timestamp?)?.toDate();
    final endTime = (data['end_time'] as Timestamp?)?.toDate();
    final sets = data['sets'] as List<dynamic>? ?? [];
    
    // トレーニング時間計算
    String durationText = '不明';
    if (startTime != null && endTime != null) {
      final duration = endTime.difference(startTime);
      durationText = '${duration.inMinutes}分';
    }
    
    // 種目ごとにセットをグループ化
    final exerciseMap = <String, List<Map<String, dynamic>>>{};
    for (final set in sets) {
      if (set is Map<String, dynamic>) {
        final exerciseName = set['exercise_name'] as String? ?? '不明';
        exerciseMap.putIfAbsent(exerciseName, () => []).add(set);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー情報
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('yyyy年MM月dd日 (E)', 'ja').format(date),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          muscleGroup,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        durationText,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // トレーニングメモセクション
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildNoteSection(theme),
            ),

            // 種目リスト
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '実施種目',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...exerciseMap.entries.map((entry) {
                    return _buildExerciseCard(entry.key, entry.value, theme);
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // メモセクション
  Widget _buildNoteSection(ThemeData theme) {
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: _showNoteDialog,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note, size: 24, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'トレーニングメモ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              if (_workoutNote != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  _workoutNote!.content,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'タップしてメモを追加',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 種目カード
  Widget _buildExerciseCard(String exerciseName, List<Map<String, dynamic>> sets, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fitness_center, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exerciseName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                // 🗑️ 種目削除ボタン
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDeleteExercise(exerciseName),
                  tooltip: '種目を削除',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...sets.asMap().entries.map((entry) {
              final index = entry.key;
              final set = entry.value;
              final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
              final reps = set['reps'] as int? ?? 0;
              
              // 有酸素運動の場合は「時間・距離」表示
              final String displayText;
              if (_isCardio) {
                displayText = '${weight}分 × ${reps}km';
              } else {
                displayText = '${weight}kg × ${reps}回';
              }
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      displayText,
                      style: const TextStyle(fontSize: 16),
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

  // メモダイアログ
  void _showNoteDialog() {
    final controller = TextEditingController(text: _workoutNote?.content ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('トレーニングメモ'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'メモを入力...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (_workoutNote != null)
            TextButton(
              onPressed: () async {
                await _deleteNote();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('削除', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveNote(controller.text);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // メモ保存
  Future<void> _saveNote(String content) async {
    if (content.trim().isEmpty) return;

    try {
      final userId = widget.workoutData['user_id'] as String? ?? '';
      
      if (_workoutNote == null) {
        final note = await _noteService.createNote(
          userId: userId,
          workoutSessionId: widget.workoutId,
          content: content,
        );
        setState(() {
          _workoutNote = note;
        });
      } else {
        final updatedNote = await _noteService.updateNote(_workoutNote!.id, content);
        setState(() {
          _workoutNote = updatedNote;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メモを保存しました'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メモの保存に失敗しました: $e')),
        );
      }
    }
  }

  // メモ削除
  Future<void> _deleteNote() async {
    if (_workoutNote == null) return;

    try {
      await _noteService.deleteNote(_workoutNote!.id);
      setState(() {
        _workoutNote = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メモを削除しました'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メモの削除に失敗しました: $e')),
        );
      }
    }
  }

  // 🗑️ 種目削除確認ダイアログ
  void _confirmDeleteExercise(String exerciseName) async {
    // 🔍 デバッグ: 現在のデータ構造を完全に確認
    final data = widget.workoutData;
    final sets = data['sets'] as List<dynamic>? ?? [];
    final exercises = data['exercises'];
    
    // 🔍 各セットの詳細情報を収集
    final setDetails = <String>[];
    for (int i = 0; i < sets.length; i++) {
      final set = sets[i];
      if (set is Map<String, dynamic>) {
        final name = set['exercise_name'];
        final nameType = name.runtimeType;
        final nameLength = name?.toString().length ?? 0;
        final match = name == exerciseName;
        setDetails.add('Set${i+1}: "$name" (${nameType}, len=$nameLength, match=$match)');
      } else {
        setDetails.add('Set${i+1}: NOT A MAP (${set.runtimeType})');
      }
    }
    
    // 現在の種目数を計算
    final currentExerciseNames = sets
        .where((s) => s is Map)
        .map((s) => s['exercise_name'])
        .toSet()
        .toList();
    
    // 削除ターゲットの情報
    final targetInfo = '削除対象: "$exerciseName" (${exerciseName.runtimeType}, len=${exerciseName.length})';
    
    final afterDeleteSets = sets.where((set) {
      if (set is Map<String, dynamic>) {
        final setExerciseName = set['exercise_name'] as String? ?? '';
        return setExerciseName != exerciseName;
      }
      return true;
    }).toList();
    
    final afterDeleteExerciseNames = afterDeleteSets
        .where((s) => s is Map)
        .map((s) => s['exercise_name'])
        .toSet()
        .toList();
    
    // 🔍 完全なデバッグダイアログ
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔍 削除デバッグ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('「$exerciseName」を削除しますか？'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('🎯 $targetInfo', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('📊 現在の種目: ${currentExerciseNames.join(", ")}', style: const TextStyle(fontSize: 11)),
              Text('📊 削除後の種目: ${afterDeleteExerciseNames.join(", ")}', style: const TextStyle(fontSize: 11)),
              Text('📊 現在のセット数: ${sets.length}', style: const TextStyle(fontSize: 11)),
              Text('📊 削除後のセット数: ${afterDeleteSets.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: afterDeleteSets.isEmpty ? Colors.red : Colors.green)),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text('🔍 セット詳細:', style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...setDetails.map((detail) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(detail, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              )),
              if (exercises != null) ...[
                const SizedBox(height: 8),
                const Divider(),
                Text('⚠️ exercises フィールド検出: ${exercises.runtimeType}', 
                  style: const TextStyle(fontSize: 11, color: Colors.orange)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          if (afterDeleteSets.isNotEmpty)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteExercise(exerciseName);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('削除'),
            ),
          if (afterDeleteSets.isEmpty)
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('⚠️ 全削除防止'),
            ),
        ],
      ),
    );
  }

  // 🗑️ 種目削除（その種目だけを削除）
  Future<void> _deleteExercise(String exerciseName) async {
    try {
      // 現在のワークアウトデータを取得
      final docRef = FirebaseFirestore.instance
          .collection('workout_logs')
          .doc(widget.workoutId);
      
      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('ワークアウトが見つかりません');
      }
      
      final data = doc.data();
      if (data == null) {
        throw Exception('ワークアウトデータが空です');
      }
      
      // 🔍 デバッグ: データ構造を確認
      print('🔍 Firestore data keys: ${data.keys.toList()}');
      print('🔍 Data structure check:');
      print('   - has sets: ${data.containsKey('sets')}');
      print('   - has exercises: ${data.containsKey('exercises')}');
      
      // 🔧 データ構造を判定して処理を分岐
      bool hasSetsArray = data.containsKey('sets') && data['sets'] is List;
      bool hasExercisesMap = data.containsKey('exercises') && data['exercises'] is Map;
      
      print('🔍 Data format: ${hasSetsArray ? "sets array" : ""} ${hasExercisesMap ? "exercises map" : ""}');
      
      if (hasSetsArray) {
        // ✅ 通常形式: sets配列から削除
        print('📋 Processing: sets array format');
        await _deleteFromSetsArray(docRef, data, exerciseName);
      } else if (hasExercisesMap) {
        // ✅ テンプレート形式: exercises Mapから削除  
        print('📋 Processing: exercises map format');
        await _deleteFromExercisesMap(docRef, data, exerciseName);
      } else {
        throw Exception('Unknown data structure: no sets array or exercises map found');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
      print('❌ 種目削除エラー: $e');
    }
  }
  
  // 🔧 sets配列形式からの削除
  Future<void> _deleteFromSetsArray(
    DocumentReference docRef,
    Map<String, dynamic> data,
    String exerciseName,
  ) async {
    final sets = data['sets'] as List<dynamic>? ?? [];
    
    print('🔍 Before delete - total sets: ${sets.length}');
    
    // 指定された種目のセットだけをフィルタリング（削除）
    print('🎯 Target exercise to DELETE: "$exerciseName" (len=${exerciseName.length}, bytes=${exerciseName.codeUnits})');
    
    final remainingSets = sets.where((set) {
      if (set is Map<String, dynamic>) {
        final setExerciseName = set['exercise_name'] as String? ?? '';
        final isMatch = setExerciseName == exerciseName;
        final shouldKeep = !isMatch;
        print('   Set: "$setExerciseName" (len=${setExerciseName.length}, bytes=${setExerciseName.codeUnits})');
        print('        → Match: $isMatch, Keep: $shouldKeep');
        return shouldKeep;
      }
      return true;
    }).toList();
    
    print('🔍 After filter - total sets: ${remainingSets.length}');
    
    if (remainingSets.isEmpty) {
      print('⚠️ All sets deleted - deleting entire workout');
      await docRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('最後の種目が削除されたため、トレーニング記録全体を削除しました'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      print('✅ Updating Firestore with ${remainingSets.length} sets');
      await docRef.update({'sets': remainingSets});
      
      final remainingExerciseNames = remainingSets
          .where((s) => s is Map)
          .map((s) => s['exercise_name'])
          .toSet()
          .length;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$exerciseName」を削除しました（残り${remainingExerciseNames}種目）'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 画面を再読み込み
        final updatedDoc = await docRef.get();
        if (updatedDoc.exists) {
          final updatedData = updatedDoc.data();
          if (updatedData != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SimpleWorkoutDetailScreen(
                  workoutId: widget.workoutId,
                  workoutData: updatedData as Map<String, dynamic>,
                ),
              ),
            );
          }
        }
      }
    }
  }
  
  // 🔧 exercises Map形式からの削除
  Future<void> _deleteFromExercisesMap(
    DocumentReference docRef,
    Map<String, dynamic> data,
    String exerciseName,
  ) async {
    final exercises = Map<String, dynamic>.from(data['exercises'] as Map);
    
    print('🔍 Before delete - exercises: ${exercises.keys.toList()}');
    
    // 指定された種目を削除
    exercises.remove(exerciseName);
    
    print('🔍 After delete - exercises: ${exercises.keys.toList()}');
    
    if (exercises.isEmpty) {
      print('⚠️ All exercises deleted - deleting entire workout');
      await docRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('最後の種目が削除されたため、トレーニング記録全体を削除しました'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      print('✅ Updating Firestore with ${exercises.length} exercises');
      await docRef.update({'exercises': exercises});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$exerciseName」を削除しました（残り${exercises.length}種目）'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 画面を再読み込み
        final updatedDoc = await docRef.get();
        if (updatedDoc.exists) {
          final updatedData = updatedDoc.data();
          if (updatedData != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SimpleWorkoutDetailScreen(
                  workoutId: widget.workoutId,
                  workoutData: updatedData as Map<String, dynamic>,
                ),
              ),
            );
          }
        }
      }
    }
  }
  


  // 削除確認
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('このトレーニング記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteWorkout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // ワークアウト削除
  Future<void> _deleteWorkout() async {
    try {
      await FirebaseFirestore.instance
          .collection('workout_logs')
          .doc(widget.workoutId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('トレーニング記録を削除しました'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }
}
