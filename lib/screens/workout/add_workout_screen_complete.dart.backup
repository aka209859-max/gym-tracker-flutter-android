import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:async';

// SetType enum
enum SetType {
  normal,     // 通常
  warmup,     // ウォームアップ
  superset,   // スーパーセット
  dropset,    // ドロップセット
  failure,    // フェイラー（限界まで）
}

// WorkoutSet class
class WorkoutSet {
  final String exerciseName;
  double weight;
  int reps;
  bool isCompleted;
  bool hasAssist;
  SetType setType;
  
  WorkoutSet({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    this.isCompleted = false,
    this.hasAssist = false,
    this.setType = SetType.normal,
  });
}

class AddWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic>? templateData;
  
  const AddWorkoutScreen({super.key, this.templateData});

  @override
  State<AddWorkoutScreen> createState() => _AddWorkoutScreenState();
}

class _AddWorkoutScreenState extends State<AddWorkoutScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedMuscleGroup;
  int _startHour = 9;
  int _startMinute = 0;
  int _endHour = 11;
  int _endMinute = 0;
  final List<WorkoutSet> _sets = [];
  
  // タイマー関連
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _isResting = false;
  int _selectedRestDuration = 90;
  final List<int> _restDurations = [30, 60, 90, 120];
  
  // 前回記録データ
  Map<String, Map<String, dynamic>> _lastWorkoutData = {};
  
  // メモ機能
  final TextEditingController _memoController = TextEditingController();
  
  final Map<String, List<String>> _muscleGroupExercises = {
    '胸': ['ベンチプレス', 'ダンベルプレス', 'インクラインプレス', 'ケーブルフライ', 'ディップス'],
    '脚': ['スクワット', 'レッグプレス', 'レッグエクステンション', 'レッグカール', 'カーフレイズ'],
    '背中': ['デッドリフト', 'ラットプルダウン', 'ベントオーバーロウ', 'シーテッドロウ', '懸垂'],
    '肩': ['ショルダープレス', 'サイドレイズ', 'フロントレイズ', 'リアデルトフライ', 'アップライトロウ'],
    '二頭': ['バーベルカール', 'ダンベルカール', 'ハンマーカール', 'プリチャーカール', 'ケーブルカール'],
    '三頭': ['トライセプスエクステンション', 'スカルクラッシャー', 'ケーブルプッシュダウン', 'ディップス', 'キックバック'],
    '有酸素': ['ランニング', 'サイクリング', 'エアロバイク', 'ステッパー', '水泳'],
  };

  @override
  void initState() {
    super.initState();
    _autoLoginIfNeeded();
    _loadLastWorkoutData();
    _applyTemplateDataIfProvided();
  }
  
  /// 未ログイン時に自動的に匿名ログイン
  Future<void> _autoLoginIfNeeded() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        await firebase_auth.FirebaseAuth.instance.signInAnonymously();
        debugPrint('✅ トレーニング記録完了: 匿名認証成功');
      } catch (e) {
        debugPrint('❌ トレーニング記録完了: 匿名認証エラー: $e');
      }
    }
  }
  
  void _applyTemplateDataIfProvided() {
    if (widget.templateData != null) {
      print('📋 テンプレートデータを適用: ${widget.templateData}');
      
      final muscleGroup = widget.templateData!['muscle_group'] as String?;
      if (muscleGroup != null) {
        setState(() {
          _selectedMuscleGroup = muscleGroup;
        });
      }
      
      final sets = widget.templateData!['sets'] as List<dynamic>?;
      if (sets != null) {
        setState(() {
          for (var setData in sets) {
            final exerciseName = setData['exercise_name'] as String;
            final weight = (setData['weight'] as num?)?.toDouble() ?? 0.0;
            final reps = setData['reps'] as int? ?? 10;
            
            _sets.add(WorkoutSet(
              exerciseName: exerciseName,
              weight: weight,
              reps: reps,
            ));
          }
          print('✅ ${_sets.length}セットをテンプレートから適用しました');
        });
      }
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadLastWorkoutData() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final sets = data['sets'] as List<dynamic>? ?? [];
        
        for (var set in sets) {
          final exerciseName = set['exercise_name'] as String?;
          if (exerciseName != null) {
            _lastWorkoutData[exerciseName] = {
              'weight': set['weight'],
              'reps': set['reps'],
            };
          }
        }
      }
    } catch (e) {
      print('前回データ読み込みエラー: $e');
    }
  }

  void _addSet(String exerciseName) {
    setState(() {
      WorkoutSet? lastSet;
      for (int i = _sets.length - 1; i >= 0; i--) {
        if (_sets[i].exerciseName == exerciseName) {
          lastSet = _sets[i];
          break;
        }
      }
      
      _sets.add(WorkoutSet(
        exerciseName: exerciseName,
        weight: lastSet?.weight ?? _lastWorkoutData[exerciseName]?['weight']?.toDouble() ?? 0.0,
        reps: lastSet?.reps ?? _lastWorkoutData[exerciseName]?['reps'] ?? 10,
        setType: SetType.normal,
      ));
    });
  }

  void _startRestTimer() {
    setState(() {
      _isResting = true;
      _restSeconds = _selectedRestDuration;
    });
    
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_restSeconds > 0) {
          _restSeconds--;
        } else {
          _stopRestTimer();
        }
      });
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restSeconds = 0;
    });
  }

  void _showRestTimerSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('休憩時間を設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _restDurations.map((duration) {
            return RadioListTile<int>(
              title: Text('${duration}秒'),
              value: duration,
              groupValue: _selectedRestDuration,
              onChanged: (value) {
                setState(() => _selectedRestDuration = value!);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showAddCustomExerciseDialog() async {
    if (_selectedMuscleGroup == null) return;
    
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('カスタム種目を追加'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '種目名を入力',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        _muscleGroupExercises[_selectedMuscleGroup]!.add(result);
        _addSet(result);
      });
    }
  }

  void _copyExerciseSets(String exerciseName) {
    final exerciseSets = _sets.where((s) => s.exerciseName == exerciseName).toList();
    if (exerciseSets.isEmpty) return;
    
    setState(() {
      for (var set in exerciseSets) {
        _sets.add(WorkoutSet(
          exerciseName: set.exerciseName,
          weight: set.weight,
          reps: set.reps,
        ));
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${exerciseSets.length}セットをコピーしました')),
    );
  }

  Future<void> _saveWorkout() async {
    if (_selectedMuscleGroup == null || _sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('部位と種目を選択してください')),
      );
      return;
    }

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startHour,
        _startMinute,
      );
      
      final endTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endHour,
        _endMinute,
      );

      final workoutDoc = await FirebaseFirestore.instance.collection('workout_logs').add({
        'user_id': user.uid,
        'muscle_group': _selectedMuscleGroup,
        'date': Timestamp.fromDate(_selectedDate),
        'start_time': Timestamp.fromDate(startTime),
        'end_time': Timestamp.fromDate(endTime),
        'sets': _sets.map((set) => {
          'exercise_name': set.exerciseName,
          'weight': set.weight,
          'reps': set.reps,
          'is_completed': set.isCompleted,
          'has_assist': set.hasAssist,
          'set_type': set.setType.toString().split('.').last,
        }).toList(),
        'created_at': FieldValue.serverTimestamp(),
      });

      if (_memoController.text.isNotEmpty) {
        await FirebaseFirestore.instance.collection('workout_notes').add({
          'user_id': user.uid,
          'workout_session_id': workoutDoc.id,
          'content': _memoController.text,
          'created_at': Timestamp.now(),
          'updated_at': Timestamp.now(),
        });
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('トレーニングを保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング記録'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isResting)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '休憩 $_restSeconds秒',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: _showRestTimerSettings,
            tooltip: '休憩時間設定',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 部位選択（横スクロール）
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _muscleGroupExercises.keys.map((muscleGroup) {
                    final isSelected = _selectedMuscleGroup == muscleGroup;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(muscleGroup),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedMuscleGroup = selected ? muscleGroup : null;
                          });
                        },
                        selectedColor: theme.colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            // 種目リスト
            if (_selectedMuscleGroup != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '$_selectedMuscleGroupの種目',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              
              ..._muscleGroupExercises[_selectedMuscleGroup]!.map((exercise) {
                final hasExercise = _sets.any((s) => s.exerciseName == exercise);
                return ListTile(
                  leading: Icon(
                    Icons.fitness_center,
                    color: hasExercise ? theme.colorScheme.primary : Colors.grey,
                  ),
                  title: Text(exercise),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasExercise)
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copyExerciseSets(exercise),
                          tooltip: 'セットをコピー',
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _addSet(exercise),
                );
              }).toList(),
              
              // カスタム種目追加ボタン
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: _showAddCustomExerciseDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('種目を追加（カスタム）'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ),
            ],
            
            // セット入力セクション
            if (_sets.isNotEmpty) ...[
              const Divider(height: 32, thickness: 2),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'セット',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              
              // 種目ごとにグループ化
              ...() {
                final exerciseGroups = <String, List<WorkoutSet>>{};
                for (var set in _sets) {
                  exerciseGroups.putIfAbsent(set.exerciseName, () => []).add(set);
                }
                
                return exerciseGroups.entries.map((entry) {
                  return _buildExerciseGroup(entry.key, entry.value);
                }).toList();
              }(),
              
              // メモ入力欄
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📝 トレーニングメモ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _memoController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: '今日のトレーニングについてメモを残しましょう',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 保存ボタン
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveWorkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '記録を保存',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseGroup(String exerciseName, List<WorkoutSet> sets) {
    final lastData = _lastWorkoutData[exerciseName];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  exerciseName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            // 💡前回記録バナー
            if (lastData != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '初回記録\n今日の記録が次回の目標になります。全力で挑戦しましょう！',
                        style: TextStyle(fontSize: 12, color: Colors.purple.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // セット一覧
            ...sets.asMap().entries.map((entry) {
              final index = entry.key;
              final globalIndex = _sets.indexOf(entry.value);
              return _buildSetRow(globalIndex, entry.value, index + 1);
            }).toList(),
            
            // セット追加ボタン
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _addSet(exerciseName),
              icon: const Icon(Icons.add),
              label: const Text('セットを追加'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(int globalIndex, WorkoutSet set, int setNumber) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // セット番号
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: set.isCompleted ? Colors.green : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$setNumber',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: set.isCompleted ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // 重量入力
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: '重量 (kg)',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  controller: TextEditingController(text: set.weight.toString())
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: set.weight.toString().length),
                    ),
                  onChanged: (value) {
                    setState(() {
                      set.weight = double.tryParse(value) ?? 0.0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              
              // 回数入力
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: '回数',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: set.reps.toString())
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: set.reps.toString().length),
                    ),
                  onChanged: (value) {
                    setState(() {
                      set.reps = int.tryParse(value) ?? 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              
              // 削除ボタン
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _sets.removeAt(globalIndex);
                  });
                },
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 補助トグル ＋ 完了ボタン
          Row(
            children: [
              // 補助トグル
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      set.hasAssist = !set.hasAssist;
                    });
                  },
                  icon: Icon(
                    set.hasAssist ? Icons.people : Icons.person,
                    size: 18,
                  ),
                  label: Text(set.hasAssist ? '補助あり' : '補助なし'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: set.hasAssist ? Colors.orange : Colors.grey,
                    side: BorderSide(
                      color: set.hasAssist ? Colors.orange : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // 完了ボタン
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      set.isCompleted = !set.isCompleted;
                      if (set.isCompleted && !_isResting) {
                        _startRestTimer();
                      }
                    });
                  },
                  icon: Icon(
                    set.isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: const Text('完了'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: set.isCompleted ? Colors.green : Colors.grey.shade300,
                    foregroundColor: set.isCompleted ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
