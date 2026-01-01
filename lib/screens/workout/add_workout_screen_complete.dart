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

// WorkoutSet class - 有酸素運動対応版
class WorkoutSet {
  final String exerciseName;
  double weight;
  int reps;
  bool isCompleted;
  bool hasAssist;
  SetType setType;
  
  // ✅ 追加: 有酸素運動用フィールド
  bool isCardio;
  double distance; // km
  int duration;    // 分
  
  WorkoutSet({
    required this.exerciseName,
    this.weight = 0.0,
    this.reps = 0,
    this.isCompleted = false,
    this.hasAssist = false,
    this.setType = SetType.normal,
    this.isCardio = false,
    this.distance = 0.0,
    this.duration = 0,
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
  bool _dataLoadedFromArgs = false; // 引数からのデータ読み込み済みフラグ
  
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
    AppLocalizations.of(context)!.bodyPartChest: [AppLocalizations.of(context)!.exerciseBenchPress, AppLocalizations.of(context)!.exerciseDumbbellPress, AppLocalizations.of(context)!.exerciseInclinePress, AppLocalizations.of(context)!.exerciseCableFly, AppLocalizations.of(context)!.exerciseDips],
    AppLocalizations.of(context)!.bodyPartLegs: [AppLocalizations.of(context)!.exerciseSquat, AppLocalizations.of(context)!.exerciseLegPress, AppLocalizations.of(context)!.exerciseLegExtension, AppLocalizations.of(context)!.exerciseLegCurl, AppLocalizations.of(context)!.exerciseCalfRaise],
    AppLocalizations.of(context)!.bodyPartBack: [AppLocalizations.of(context)!.exerciseDeadlift, AppLocalizations.of(context)!.exerciseLatPulldown, AppLocalizations.of(context)!.exerciseBentOverRow, AppLocalizations.of(context)!.exerciseSeatedRow, AppLocalizations.of(context)!.exercisePullUp],
    AppLocalizations.of(context)!.bodyPartShoulders: [AppLocalizations.of(context)!.exerciseShoulderPress, AppLocalizations.of(context)!.exerciseSideRaise, AppLocalizations.of(context)!.exerciseFrontRaise, AppLocalizations.of(context)!.exerciseRearDeltFly, AppLocalizations.of(context)!.exerciseUprightRow],
    AppLocalizations.of(context)!.bodyPartBiceps: [AppLocalizations.of(context)!.exerciseBarbellCurl, AppLocalizations.of(context)!.exerciseDumbbellCurl, AppLocalizations.of(context)!.exerciseHammerCurl, AppLocalizations.of(context)!.exercisePreacherCurl, AppLocalizations.of(context)!.exerciseCableCurl],
    AppLocalizations.of(context)!.bodyPartTriceps: [AppLocalizations.of(context)!.exerciseTricepsExtension, AppLocalizations.of(context)!.exerciseSkullCrusher, AppLocalizations.of(context)!.workout_22752b72, AppLocalizations.of(context)!.exerciseDips, AppLocalizations.of(context)!.exerciseKickback],
    AppLocalizations.of(context)!.exerciseCardio: [AppLocalizations.of(context)!.exerciseRunning, AppLocalizations.of(context)!.workout_cf6a6f5b, AppLocalizations.of(context)!.exerciseAerobicBike, AppLocalizations.of(context)!.workout_f4ecb3c9, AppLocalizations.of(context)!.workout_a90ed9c4, AppLocalizations.of(context)!.workout_aa4c3c64, AppLocalizations.of(context)!.workout_e23f084e, AppLocalizations.of(context)!.workout_ba2fef80],
  };

  @override
  void initState() {
    super.initState();
    _autoLoginIfNeeded();
    _loadLastWorkoutData();
    _applyTemplateDataIfProvided();
  }

  // ✅ 追加: AIコーチ画面からのデータ受け取り処理
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoadedFromArgs) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['fromAICoach'] == true) {
        final exercises = args['selectedExercises'] as List<dynamic>?;
        if (exercises != null) {
          _applyAICoachExercises(exercises);
        }
        _dataLoadedFromArgs = true;
      }
    }
  }
  
  /// ✅ 追加: AIコーチからの種目データを適用
  void _applyAICoachExercises(List<dynamic> exercises) {
    if (exercises.isEmpty) return;

    setState(() {
      // 既存のセットをクリア（必要に応じて）
      // _sets.clear(); 
      
      // 部位を設定（最初の種目の部位を採用、または「AI提案」とするなど）
      // ここでは、argsに部位情報が含まれていないため、最初の種目から推測も可能ですが、
      // 既存ロジックを壊さないよう、主要部位が設定されていなければ設定
      if (_selectedMuscleGroup == null && exercises.isNotEmpty) {
        // dynamic型なので安全にアクセス
        try {
          _selectedMuscleGroup = exercises.first.bodyPart;
        } catch (e) {
          // エラーなら無視
        }
      }

      for (var ex in exercises) {
        try {
          // ParsedExerciseオブジェクトのプロパティにアクセス
          // 型がわからないためdynamic経由でアクセス
          final name = ex.name as String;
          final isCardio = (ex.isCardio as bool?) ?? false;
          final setsCount = (ex.sets as int?) ?? 1;
          
          // セット数分だけループして追加
          for (int i = 0; i < setsCount; i++) {
            if (isCardio) {
              // 有酸素運動として追加
              _sets.add(WorkoutSet(
                exerciseName: name,
                isCardio: true,
                distance: (ex.distance as num?)?.toDouble() ?? 0.0,
                duration: (ex.duration as int?) ?? 0,
                weight: 0,
                reps: 0,
              ));
            } else {
              // 筋トレとして追加
              _sets.add(WorkoutSet(
                exerciseName: name,
                isCardio: false,
                weight: (ex.weight as num?)?.toDouble() ?? 0.0,
                reps: (ex.reps as int?) ?? 10,
                distance: 0,
                duration: 0,
              ));
            }
          }
        } catch (e) {
          debugPrint('❌ 種目データの変換エラー: $e');
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AIコーチから${exercises.length}種目を読み込みました')),
      );
    });
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
            // テンプレートからの読み込みも拡張可能だが、現状は筋トレ想定で維持
            
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
      // 同じ種目の最後のセットを探す
      for (int i = _sets.length - 1; i >= 0; i--) {
        if (_sets[i].exerciseName == exerciseName) {
          lastSet = _sets[i];
          break;
        }
      }
      
      // ✅ 修正: 部位が「有酸素」または種目リストに含まれるかで判定
      bool isCardio = _selectedMuscleGroup == AppLocalizations.of(context)!.exerciseCardio || 
                      (_muscleGroupExercises[AppLocalizations.of(context)!.exerciseCardio]?.contains(exerciseName) ?? false);

      if (isCardio) {
        _sets.add(WorkoutSet(
          exerciseName: exerciseName,
          isCardio: true,
          distance: lastSet?.distance ?? 0.0,
          duration: lastSet?.duration ?? 20, // デフォルト20分
          weight: 0,
          reps: 0,
          setType: SetType.normal,
        ));
      } else {
        _sets.add(WorkoutSet(
          exerciseName: exerciseName,
          isCardio: false,
          weight: lastSet?.weight ?? _lastWorkoutData[exerciseName]?['weight']?.toDouble() ?? 0.0,
          reps: lastSet?.reps ?? _lastWorkoutData[exerciseName]?['reps'] ?? 10,
          setType: SetType.normal,
        ));
      }
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
        title: Text(AppLocalizations.of(context)!.workout_b23db97f),
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
        title: Text(AppLocalizations.of(context)!.addCustomExercise),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.workout_a3dbb30d,
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(AppLocalizations.of(context)!.add),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        if (!_muscleGroupExercises[_selectedMuscleGroup]!.contains(result)) {
          _muscleGroupExercises[_selectedMuscleGroup]!.add(result);
        }
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
          isCardio: set.isCardio,
          distance: set.distance,
          duration: set.duration,
        ));
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${exerciseSets.length}セットをコピーしました')),
    );
  }

  Future<void> _saveWorkout() async {
    if (_sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.workout_d90b7b6b)),
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
        'muscle_group': _selectedMuscleGroup ?? AppLocalizations.of(context)!.workout_ed08832f,
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
          // ✅ 追加: 有酸素データの保存
          'is_cardio': set.isCardio,
          'distance': set.distance,
          'duration': set.duration,
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
          SnackBar(content: Text(AppLocalizations.of(context)!.workout_498b0ea4)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.saveFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.trainingLog),
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
            tooltip: AppLocalizations.of(context)!.workout_4a60472d,
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
                    _selectedMuscleGroup == AppLocalizations.of(context)!.exerciseCardio ? Icons.directions_run : Icons.fitness_center,
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
                          tooltip: AppLocalizations.of(context)!.copySet,
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
                  label: Text(AppLocalizations.of(context)!.workout_268deae1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ),
            ],
            
            // セット入力セクション
            if (_sets.isNotEmpty) ...[
              Divider(height: 32, thickness: 2),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context)!.sets,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              
              // 種目ごとにグループ化
              ...() {
                // 種目の順序を保持するためのLinkedHashMap的な処理
                final exerciseGroups = <String, List<WorkoutSet>>{};
                // リストの順序通りに処理
                for (var set in _sets) {
                  if (!exerciseGroups.containsKey(set.exerciseName)) {
                    exerciseGroups[set.exerciseName] = [];
                  }
                  exerciseGroups[set.exerciseName]!.add(set);
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
                        hintText: AppLocalizations.of(context)!.workout_be150460,
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
                      AppLocalizations.of(context)!.workout_18f75a52,
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
    // グループ内の最初のセットでタイプ判定（通常、1グループ内は同じタイプ）
    final isCardio = sets.isNotEmpty && sets.first.isCardio;
    
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
                Icon(
                  isCardio ? Icons.directions_run : Icons.fitness_center, 
                  color: isCardio ? Colors.orange : Colors.blue, 
                  size: 20
                ),
                const SizedBox(width: 8),
                Text(
                  exerciseName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (isCardio) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(AppLocalizations.of(context)!.exerciseCardio,
                      style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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
                        '前回記録: ${lastData['weight']}kg x ${lastData['reps']}回\n今日の記録が次回の目標になります。',
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
              label: Text(AppLocalizations.of(context)!.workout_68d6a303),
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
              
              // ✅ 修正: 有酸素なら「距離/時間」、筋トレなら「重量/回数」
              if (set.isCardio) ...[
                // 距離入力
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: '距離 (km)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    controller: TextEditingController(text: set.distance.toString())
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: set.distance.toString().length),
                      ),
                    onChanged: (value) {
                      setState(() {
                        set.distance = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 時間入力
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: '時間 (分)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: set.duration.toString())
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: set.duration.toString().length),
                      ),
                    onChanged: (value) {
                      setState(() {
                        set.duration = int.tryParse(value) ?? 0;
                      });
                    },
                  ),
                ),
              ] else ...[
                // 重量入力
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: '重量 (kg)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                      labelText: AppLocalizations.of(context)!.repsCount,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              ],
              
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
                  label: Text(set.hasAssist ? AppLocalizations.of(context)!.workout_137b679e : AppLocalizations.of(context)!.workout_7b8e9d09),
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
                  label: Text(AppLocalizations.of(context)!.complete),
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
