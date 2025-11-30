import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // SystemSound用
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:vibration/vibration.dart'; // バイブレーション用
import '../debug_log_screen.dart';

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
  bool isBodyweightMode; // 自重モード (true: 自重, false: 荷重)
  
  WorkoutSet({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    this.isCompleted = false,
    this.hasAssist = false,
    this.setType = SetType.normal,
    this.isBodyweightMode = true, // デフォルトは自重モード
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
  
  // 有酸素運動かどうかを判定
  bool _isCardioExercise(String exerciseName) {
    final cardioExercises = _muscleGroupExercises['有酸素'] ?? [];
    return cardioExercises.contains(exerciseName);
  }
  
  // 懸垂系種目かどうかを判定
  bool _isPullUpExercise(String exerciseName) {
    final pullUpVariations = ['懸垂', 'チンニング', 'プルアップ', 'チンアップ', 'ワイドグリッププルアップ'];
    return pullUpVariations.any((variation) => exerciseName.contains(variation));
  }

  @override
  void initState() {
    super.initState();
    _autoLoginIfNeeded();
    _loadCustomExercises();
    _loadLastWorkoutData();
    _applyTemplateDataIfProvided();
  }
  
  /// 未ログイン時に自動的に匿名ログイン
  Future<void> _autoLoginIfNeeded() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        await firebase_auth.FirebaseAuth.instance.signInAnonymously();
        debugPrint('✅ トレーニング記録: 匿名認証成功');
      } catch (e) {
        debugPrint('❌ トレーニング記録: 匿名認証エラー: $e');
      }
    }
  }
  
  // カスタム種目をSharedPreferencesから読み込み
  Future<void> _loadCustomExercises() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customExercisesJson = prefs.getString('custom_exercises');
      
      if (customExercisesJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(customExercisesJson);
        setState(() {
          decoded.forEach((muscleGroup, exercises) {
            if (_muscleGroupExercises.containsKey(muscleGroup)) {
              // 既存のリストにカスタム種目を追加（重複を避ける）
              final customList = List<String>.from(exercises);
              for (var exercise in customList) {
                if (!_muscleGroupExercises[muscleGroup]!.contains(exercise)) {
                  _muscleGroupExercises[muscleGroup]!.add(exercise);
                }
              }
            }
          });
        });
        print('✅ カスタム種目をロード: ${decoded.keys.length}部位');
      }
    } catch (e) {
      print('⚠️ カスタム種目のロードに失敗: $e');
    }
  }
  
  // カスタム種目をSharedPreferencesに保存
  Future<void> _saveCustomExercises() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // デフォルト種目を除外してカスタム種目のみを抽出
      final Map<String, List<String>> customOnly = {};
      
      final defaultExercises = {
        '胸': ['ベンチプレス', 'ダンベルプレス', 'インクラインプレス', 'ケーブルフライ', 'ディップス'],
        '脚': ['スクワット', 'レッグプレス', 'レッグエクステンション', 'レッグカール', 'カーフレイズ'],
        '背中': ['デッドリフト', 'ラットプルダウン', 'ベントオーバーロウ', 'シーテッドロウ', '懸垂'],
        '肩': ['ショルダープレス', 'サイドレイズ', 'フロントレイズ', 'リアデルトフライ', 'アップライトロウ'],
        '二頭': ['バーベルカール', 'ダンベルカール', 'ハンマーカール', 'プリチャーカール', 'ケーブルカール'],
        '三頭': ['トライセプスエクステンション', 'スカルクラッシャー', 'ケーブルプッシュダウン', 'ディップス', 'キックバック'],
        '有酸素': ['ランニング', 'サイクリング', 'エアロバイク', 'ステッパー', '水泳'],
      };
      
      _muscleGroupExercises.forEach((muscleGroup, exercises) {
        final defaults = defaultExercises[muscleGroup] ?? [];
        final customs = exercises.where((ex) => !defaults.contains(ex)).toList();
        if (customs.isNotEmpty) {
          customOnly[muscleGroup] = customs;
        }
      });
      
      final encoded = jsonEncode(customOnly);
      await prefs.setString('custom_exercises', encoded);
      print('✅ カスタム種目を保存: ${customOnly.keys.length}部位');
    } catch (e) {
      print('⚠️ カスタム種目の保存に失敗: $e');
    }
  }
  
  // 既存workout_idを保持
  String? _existingWorkoutId;
  
  void _applyTemplateDataIfProvided() {
    if (widget.templateData != null) {
      print('📋 テンプレートデータを適用: ${widget.templateData}');
      
      final muscleGroup = widget.templateData!['muscle_group'] as String?;
      final exercises = widget.templateData!['exercises'] as List<dynamic>?;
      final exerciseName = widget.templateData!['exercise_name'] as String?;
      final lastWeight = widget.templateData!['last_weight'] as double?;
      final lastReps = widget.templateData!['last_reps'] as int?;
      _existingWorkoutId = widget.templateData!['existing_workout_id'] as String?;
      
      setState(() {
        // 部位選択を適用
        if (muscleGroup != null) {
          _selectedMuscleGroup = muscleGroup;
        }
        
        // ケース1: テンプレートから複数種目を追加
        if (exercises != null && exercises.isNotEmpty) {
          print('📋 テンプレートから${exercises.length}種目を読み込み');
          
          for (var exercise in exercises) {
            final name = exercise['exercise_name'] as String;
            final targetSets = exercise['target_sets'] as int? ?? 3;
            final targetReps = exercise['target_reps'] as int? ?? 10;
            final targetWeight = exercise['target_weight'] as double? ?? 0.0;
            
            print('  ✅ $name: ${targetSets}セット × ${targetReps}回 @ ${targetWeight}kg');
            
            // 各種目のtargetSets数だけセットを追加
            for (int i = 0; i < targetSets; i++) {
              _sets.add(WorkoutSet(
                exerciseName: name,
                weight: targetWeight,
                reps: targetReps,
                isCompleted: false,
                isBodyweightMode: _isPullUpExercise(name),
              ));
            }
          }
          
          print('✅ テンプレートから合計${_sets.length}セットを追加');
        }
        // ケース2: 単一種目を追加（履歴から「もう一度」の場合）
        else if (exerciseName != null) {
          _sets.add(WorkoutSet(
            exerciseName: exerciseName,
            weight: lastWeight ?? 0.0,
            reps: lastReps ?? 10,
            isCompleted: false,
            isBodyweightMode: _isPullUpExercise(exerciseName),
          ));
          print('✅ $exerciseName に1セット追加（前回: ${lastWeight}kg × ${lastReps}reps）');
        }
      });
      
      if (_existingWorkoutId != null) {
        print('✅ 既存記録に追記モード: $_existingWorkoutId');
      } else {
        print('✅ 新規記録モード');
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
      if (user == null) {
        print('⚠️ ユーザー未ログイン - 前回データなし');
        // 匿名ログイン実装により、この状態には通常到達しない
        return;
      }

      print('🔍 ユーザーID: ${user.uid}');
      
      // 🔧 修正: シンプルクエリ（インデックス不要）で取得してメモリ内でソート
      final snapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .get();
      
      // メモリ内で日付順にソート（新しい順）
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final dateA = (a.data()['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final dateB = (b.data()['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return dateB.compareTo(dateA);  // 降順
      });
      
      // 最新50件に制限
      final limitedDocs = docs.take(50).toList();

      print('📊 前回記録取得: ${snapshot.docs.length}件のワークアウト履歴');
      
      if (snapshot.docs.isEmpty) {
        print('⚠️ ワークアウト履歴が1件もありません');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('まだ記録がありません。最初のワークアウトを記録しましょう！')),
          );
        }
        return;
      }

      // 種目ごとの最新記録を抽出
      final Map<String, Map<String, dynamic>> exerciseLatest = {};
      
      for (var doc in limitedDocs) {
        final data = doc.data();
        final sets = data['sets'] as List<dynamic>? ?? [];
        final docDate = (data['date'] as Timestamp).toDate();
        
        print('  📄 ドキュメント: ${doc.id}, 日付: ${DateFormat('M/d').format(docDate)}, セット数: ${sets.length}');
        
        for (var set in sets) {
          final exerciseName = set['exercise_name'] as String?;
          if (exerciseName != null) {
            // まだ記録されていない種目、または今回の記録の方が新しい場合
            if (!exerciseLatest.containsKey(exerciseName)) {
              exerciseLatest[exerciseName] = {
                'weight': set['weight'],
                'reps': set['reps'],
                'date': docDate,
              };
              print('  ✅ $exerciseName: ${set['weight']}kg × ${set['reps']}reps (${DateFormat('M/d').format(docDate)})');
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _lastWorkoutData = exerciseLatest;
        });
      }
      
      print('🎯 前回記録ロード完了: ${_lastWorkoutData.length}種目');
      print('🔑 種目キー: ${_lastWorkoutData.keys.toList()}');
    } catch (e, stackTrace) {
      print('❌ 前回データ読み込みエラー: $e');
      print('📍 スタックトレース: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データ読み込みエラー: $e'), backgroundColor: Colors.red),
        );
      }
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
      
      // 懸垂の場合は自重モードをデフォルトに
      final isPullUp = _isPullUpExercise(exerciseName);
      
      _sets.add(WorkoutSet(
        exerciseName: exerciseName,
        weight: lastSet?.weight ?? _lastWorkoutData[exerciseName]?['weight']?.toDouble() ?? 0.0,
        reps: lastSet?.reps ?? _lastWorkoutData[exerciseName]?['reps'] ?? 10,
        setType: SetType.normal,
        isBodyweightMode: lastSet?.isBodyweightMode ?? (isPullUp ? true : false),
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
          _notifyRestComplete(); // タイマー終了通知
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
  
  // タイマー終了時の通知（音声 + バイブレーション + ダイアログ）
  Future<void> _notifyRestComplete() async {
    print('🔔 タイマー終了通知開始');
    
    // 1. システムサウンドを再生（イヤホン対応）
    try {
      // iOSの通知音を再生（イヤホンに自動的にルーティングされる）
      await SystemSound.play(SystemSoundType.alert);
      print('✅ システムサウンド再生成功');
      
      // 追加で0.5秒後にもう一度鳴らす（より目立つように）
      await Future.delayed(const Duration(milliseconds: 500));
      await SystemSound.play(SystemSoundType.alert);
      print('✅ システムサウンド再生成功（2回目）');
    } catch (e) {
      print('❌ サウンド再生エラー: $e');
    }
    
    // 2. バイブレーション（デバイスがサポートしている場合）
    try {
      // デバイスがバイブレーション機能を持っているか確認
      if (await Vibration.hasVibrator() ?? false) {
        // 短く3回振動（パターン: 振動-休止-振動-休止-振動）
        await Vibration.vibrate(
          pattern: [0, 200, 100, 200, 100, 200], // [待機, 振動, 休止, 振動, 休止, 振動]
        );
        print('✅ バイブレーション成功');
      }
    } catch (e) {
      print('❌ バイブレーションエラー: $e');
    }
    
    // 3. ダイアログ表示
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.green.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.green.shade400, width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.alarm, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text(
                '休憩終了！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          content: const Text(
            '次のセットに進みましょう！💪',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      
      // 5秒後に自動的にダイアログを閉じる
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }
  }

  void _showRestTimerSettings() {
    int tempSelectedDuration = _selectedRestDuration;
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: Colors.white,
          child: Column(
            children: [
              // ヘッダー
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル', style: TextStyle(color: Colors.red)),
                    ),
                    const Text(
                      '休憩時間を設定',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedRestDuration = tempSelectedDuration);
                        Navigator.pop(context);
                        _startRestTimer(); // 設定後すぐにタイマー開始
                      },
                      child: const Text('開始', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              // ピッカービュー
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                    initialItem: _generateTimeList().indexOf(tempSelectedDuration),
                  ),
                  onSelectedItemChanged: (index) {
                    tempSelectedDuration = _generateTimeList()[index];
                  },
                  children: _generateTimeList().map((seconds) {
                    final minutes = seconds ~/ 60;
                    final remainingSeconds = seconds % 60;
                    final displayText = minutes > 0
                        ? '$minutes分${remainingSeconds > 0 ? ' $remainingSeconds秒' : ''}'
                        : '$seconds秒';
                    return Center(
                      child: Text(
                        displayText,
                        style: const TextStyle(fontSize: 20),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // ピッカー用の時間リストを生成（30秒～180秒、15秒刻み）
  List<int> _generateTimeList() {
    return List.generate(11, (index) => 30 + (index * 15));
  }

  // 🆕 過去5回分の履歴を表示して選択するダイアログ
  Future<void> _showWorkoutHistoryDialog(String exerciseName) async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        // 匿名ログイン実装により、この状態には通常到達しない
        return;
      }

      // この種目の過去5回分の記録を取得（シンプルクエリ）
      final snapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .get();
      
      // メモリ内で日付順にソート（新しい順）
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final dateA = (a.data()['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final dateB = (b.data()['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return dateB.compareTo(dateA);  // 降順
      });
      
      // 最新50件に制限
      final limitedDocs = docs.take(50).toList();

      // この種目のセットを抽出
      final List<Map<String, dynamic>> exerciseHistory = [];
      
      for (var doc in limitedDocs) {
        final data = doc.data();
        final sets = data['sets'] as List<dynamic>? ?? [];
        final docDate = (data['date'] as Timestamp).toDate();
        
        for (var set in sets) {
          if (set['exercise_name'] == exerciseName) {
            exerciseHistory.add({
              'weight': set['weight'],
              'reps': set['reps'],
              'date': docDate,
              'setType': set['set_type'] ?? 'normal',
            });
          }
        }
        
        // 過去5回分見つかったら終了
        if (exerciseHistory.length >= 5) break;
      }

      if (exerciseHistory.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$exerciseNameの履歴がありません')),
        );
        return;
      }

      // ダイアログで選択肢を表示
      if (!mounted) return;
      
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$exerciseNameの過去記録'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: exerciseHistory.length,
              itemBuilder: (context, index) {
                final record = exerciseHistory[index];
                final date = record['date'] as DateTime;
                final weight = record['weight'];
                final reps = record['reps'];
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.purple)),
                  ),
                  title: Text(
                    '$weight kg × $reps reps',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(DateFormat('yyyy/M/d (E)', 'ja').format(date)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pop(context, record),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
          ],
        ),
      );

      if (selected != null && mounted) {
        final weight = (selected['weight'] ?? 0).toDouble();
        final reps = selected['reps'] ?? 10;
        
        setState(() {
          // この種目の全セットに選択した記録をコピー
          for (var set in _sets) {
            if (set.exerciseName == exerciseName) {
              set.weight = weight;
              set.reps = reps;
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('記録を反映しました: $weight kg × $reps reps'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ 履歴表示エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('履歴の取得に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showBulkInputDialog(String exerciseName) async {
    final weightController = TextEditingController();
    final repsController = TextEditingController();

    // 最初のセットから初期値を取得
    final firstSet = _sets.firstWhere(
      (set) => set.exerciseName == exerciseName,
      orElse: () => WorkoutSet(
        exerciseName: exerciseName, 
        weight: 0.0, 
        reps: 10,
        isBodyweightMode: _isPullUpExercise(exerciseName),
      ),
    );
    
    // 懸垂で自重モードかどうかを判定
    final isPullUpBodyweight = _isPullUpExercise(exerciseName) && firstSet.isBodyweightMode;
    
    weightController.text = firstSet.weight.toString();
    repsController.text = firstSet.reps.toString();

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$exerciseNameの一括入力'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 懸垂の自重モードでは重量入力欄を非表示
            if (!isPullUpBodyweight) ...[
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                onEditingComplete: () => FocusScope.of(context).nextFocus(),
                decoration: const InputDecoration(
                  labelText: '重量 (kg)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: const InputDecoration(
                labelText: '回数 (reps)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final weight = isPullUpBodyweight ? 0.0 : (double.tryParse(weightController.text) ?? 0.0);
              final reps = double.tryParse(repsController.text) ?? 10.0;
              Navigator.pop(context, {'weight': weight, 'reps': reps});
            },
            child: const Text('適用'),
          ),
        ],
      ),
    );

    // メモリリーク防止：Controllerを破棄
    weightController.dispose();
    repsController.dispose();

    if (result != null) {
      // 懸垂で自重モードかどうかを再確認
      final firstSet = _sets.firstWhere(
        (set) => set.exerciseName == exerciseName,
        orElse: () => WorkoutSet(
          exerciseName: exerciseName, 
          weight: 0.0, 
          reps: 10,
          isBodyweightMode: _isPullUpExercise(exerciseName),
        ),
      );
      final isPullUpBodyweight = _isPullUpExercise(exerciseName) && firstSet.isBodyweightMode;
      
      setState(() {
        // この種目の全セットに一括入力
        for (var set in _sets) {
          if (set.exerciseName == exerciseName) {
            set.weight = result['weight']!;
            set.reps = result['reps']!.toInt();
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPullUpBodyweight 
              ? '一括入力完了: 自重 × ${result['reps']!.toInt()} reps'
              : '一括入力完了: ${result['weight']} kg × ${result['reps']!.toInt()} reps'
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // カスタム種目かどうかを判定
  bool _isCustomExercise(String exerciseName) {
    final defaultExercises = {
      '胸': ['ベンチプレス', 'ダンベルプレス', 'インクラインプレス', 'ケーブルフライ', 'ディップス'],
      '脚': ['スクワット', 'レッグプレス', 'レッグエクステンション', 'レッグカール', 'カーフレイズ'],
      '背中': ['デッドリフト', 'ラットプルダウン', 'ベントオーバーロウ', 'シーテッドロウ', '懸垂'],
      '肩': ['ショルダープレス', 'サイドレイズ', 'フロントレイズ', 'リアデルトフライ', 'アップライトロウ'],
      '二頭': ['バーベルカール', 'ダンベルカール', 'ハンマーカール', 'プリチャーカール', 'ケーブルカール'],
      '三頭': ['トライセプスエクステンション', 'スカルクラッシャー', 'ケーブルプッシュダウン', 'ディップス', 'キックバック'],
      '有酸素': ['ランニング', 'サイクリング', 'エアロバイク', 'ステッパー', '水泳'],
    };
    
    final defaults = defaultExercises[_selectedMuscleGroup] ?? [];
    return !defaults.contains(exerciseName);
  }
  
  // カスタム種目削除確認
  Future<void> _confirmDeleteCustomExercise(String exerciseName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('カスタム種目を削除'),
        content: Text('「$exerciseName」を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _muscleGroupExercises[_selectedMuscleGroup]!.remove(exerciseName);
      });
      
      await _saveCustomExercises();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$exerciseName」を削除しました')),
        );
      }
    }
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
    
    // メモリリーク防止：Controllerを破棄
    controller.dispose();
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        _muscleGroupExercises[_selectedMuscleGroup]!.add(result);
        _addSet(result);
      });
      
      // カスタム種目を永続化
      await _saveCustomExercises();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$result」をカスタム種目として保存しました')),
        );
      }
    }
  }

  /// 日付を日本語フォーマットで表示（Web環境対応）
  String _formatDate(DateTime date) {
    try {
      // intlパッケージを使用（ロケール初期化成功時）
      return DateFormat('yyyy年M月d日(E)', 'ja_JP').format(date);
    } catch (e) {
      // Web環境やロケール初期化失敗時のフォールバック
      const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
      final weekday = weekdays[(date.weekday - 1) % 7];
      return '${date.year}年${date.month}月${date.day}日($weekday)';
    }
  }

  /// 日付選択ダイアログを表示
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020), // 2020年から選択可能
      lastDate: DateTime.now(), // 今日まで選択可能（未来の日付は選択不可）
      // locale: Web環境では指定しない（システムロケールを使用）
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
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
          isBodyweightMode: set.isBodyweightMode,
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

      // 既存記録に追記モード
      if (_existingWorkoutId != null) {
        print('🔄 既存記録に追加セットを追記: $_existingWorkoutId');
        
        // 既存ドキュメントを取得
        final docSnapshot = await FirebaseFirestore.instance
            .collection('workout_logs')
            .doc(_existingWorkoutId)
            .get();
        
        if (docSnapshot.exists) {
          final existingData = docSnapshot.data() as Map<String, dynamic>;
          final existingSets = List<Map<String, dynamic>>.from(existingData['sets'] ?? []);
          
          // 新しいセットを既存セットの下に追加
          final newSets = _sets.map((set) => {
            'exercise_name': set.exerciseName,
            'weight': set.weight,
            'reps': set.reps,
            'is_completed': set.isCompleted,
            'has_assist': set.hasAssist,
            'set_type': set.setType.toString().split('.').last,
            'is_bodyweight_mode': set.isBodyweightMode,
          }).toList();
          
          existingSets.addAll(newSets);
          
          // 既存ドキュメントを更新
          await FirebaseFirestore.instance
              .collection('workout_logs')
              .doc(_existingWorkoutId)
              .update({
            'sets': existingSets,
            'updated_at': FieldValue.serverTimestamp(),
          });
          
          print('✅ 既存記録に${newSets.length}セット追加しました');
        }
      } else {
        // 新規記録モード
        print('➕ 新規記録を作成');
        
        // トレーニング開始時刻と終了時刻を設定
        // デフォルト: 現在時刻から2時間のトレーニング
        final now = DateTime.now();
        final startTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          now.hour >= 2 ? now.hour - 2 : 0,  // 2時間前（最小0時）
          now.minute,
        );
        
        final endTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          now.hour,
          now.minute,
        );

        DebugLogger.instance.log('💾 ワークアウト保存開始');
        DebugLogger.instance.log('   User ID: ${user.uid}');
        DebugLogger.instance.log('   筋肉グループ: $_selectedMuscleGroup');
        DebugLogger.instance.log('   日付: $_selectedDate');
        DebugLogger.instance.log('   セット数: ${_sets.length}');
        
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
            'is_bodyweight_mode': set.isBodyweightMode,
          }).toList(),
          'created_at': FieldValue.serverTimestamp(),
        });
        
        DebugLogger.instance.log('✅ ワークアウト保存成功: Document ID = ${workoutDoc.id}');

        if (_memoController.text.isNotEmpty) {
          await FirebaseFirestore.instance.collection('workout_notes').add({
            'user_id': user.uid,
            'workout_session_id': workoutDoc.id,
            'content': _memoController.text,
            'created_at': Timestamp.now(),
            'updated_at': Timestamp.now(),
          });
        }
      }

      // Firestoreの書き込み完了を確実に待機（500ms）
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('トレーニングを保存しました')),
        );
      }
    } catch (e, stackTrace) {
      DebugLogger.instance.log('❌ ワークアウト保存エラー');
      DebugLogger.instance.log('   エラー: $e');
      DebugLogger.instance.log('   スタックトレース: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存エラー: $e'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('トレーニング記録'),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          actions: [
          if (_isResting) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, size: 18, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '$_restSeconds秒',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.stop_circle),
              onPressed: _stopRestTimer,
              tooltip: 'タイマー停止',
            ),
          ] else ...[
            TextButton.icon(
              icon: const Icon(Icons.timer, color: Colors.white),
              label: const Text(
                'タイマー',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: _showRestTimerSettings,
            ),
          ],
        ],
        ),
        body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📅 日付選択セクション
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'トレーニング日',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(_selectedDate),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('変更'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            
            // 部位選択（横スクロール）
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: _muscleGroupExercises.keys.map((muscleGroup) {
                    final isSelected = _selectedMuscleGroup == muscleGroup;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(
                          muscleGroup,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedMuscleGroup = selected ? muscleGroup : null;
                          });
                        },
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                final isCustomExercise = _isCustomExercise(exercise);
                
                return ListTile(
                  leading: Icon(
                    Icons.fitness_center,
                    color: hasExercise ? theme.colorScheme.primary : Colors.grey,
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(exercise)),
                      if (isCustomExercise)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.star, size: 14, color: Colors.amber),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasExercise)
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copyExerciseSets(exercise),
                          tooltip: 'セットをコピー',
                        ),
                      if (isCustomExercise)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red,
                          onPressed: () => _confirmDeleteCustomExercise(exercise),
                          tooltip: 'カスタム種目を削除',
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
            ], // if (_sets.isNotEmpty) の閉じ
          ], // Column children の閉じ
        ), // Column
      ), // SingleChildScrollView
      ), // Scaffold
    ); // GestureDetector
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
            
            // 前回をコピー & 一括入力ボタン（画像2の配置）
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      print('🔘 前回ボタンタップ: $exerciseName');
                      print('🔍 lastData: $lastData');
                      print('🔍 _lastWorkoutData: $_lastWorkoutData');
                      _showWorkoutHistoryDialog(exerciseName);
                    },
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('前回'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showBulkInputDialog(exerciseName),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('一括入力'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
            
            // 💡初回記録 or 前回記録バナー
            const SizedBox(height: 8),
            if (lastData == null) ...[
              // 初回記録の場合
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
            ] else ...[
              // 前回データがある場合
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('📊', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          '前回の記録',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatLastWorkoutData(lastData),
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
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
              
              // 懸垂の場合は自重/荷重モード切り替えを含む特別なUI
              if (_isPullUpExercise(set.exerciseName))
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 自重/荷重切り替えボタン
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  set.isBodyweightMode = true;
                                  set.weight = 0.0; // 自重モードは重量0
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: set.isBodyweightMode 
                                    ? const Color(0xFF3F51B5) 
                                    : Colors.white,
                                foregroundColor: set.isBodyweightMode 
                                    ? Colors.white 
                                    : const Color(0xFF3F51B5),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                side: BorderSide(
                                  color: const Color(0xFF3F51B5),
                                  width: set.isBodyweightMode ? 2 : 1,
                                ),
                              ),
                              child: const Text('自重', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  set.isBodyweightMode = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: !set.isBodyweightMode 
                                    ? const Color(0xFF3F51B5) 
                                    : Colors.white,
                                foregroundColor: !set.isBodyweightMode 
                                    ? Colors.white 
                                    : const Color(0xFF3F51B5),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                side: BorderSide(
                                  color: const Color(0xFF3F51B5),
                                  width: !set.isBodyweightMode ? 2 : 1,
                                ),
                              ),
                              child: const Text('荷重', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 荷重モードの場合のみ重量入力欄を表示
                      if (!set.isBodyweightMode)
                        TextFormField(
                          key: ValueKey('weight_${globalIndex}_${set.weight}'),
                          decoration: const InputDecoration(
                            labelText: '荷重 (kg)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          initialValue: set.weight == 0.0 ? '' : set.weight.toString(),
                          onChanged: (value) {
                            if (value.isEmpty) {
                              set.weight = 0.0;
                            } else {
                              set.weight = double.tryParse(value) ?? 0.0;
                            }
                          },
                        )
                      else
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.grey[50],
                          ),
                          child: const Center(
                            child: Text(
                              '自重',
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              // 有酸素運動の場合は「時間（分）」、それ以外は「重量（kg）」
              else
                Expanded(
                  child: TextFormField(
                    key: ValueKey('weight_${globalIndex}_${set.weight}'),
                    decoration: InputDecoration(
                      labelText: _isCardioExercise(set.exerciseName) ? '時間 (分)' : '重量 (kg)',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    initialValue: set.weight == 0.0 ? '' : set.weight.toString(),
                    onChanged: (value) {
                      // 空文字列または無効な値の場合は0に
                      if (value.isEmpty) {
                        set.weight = 0.0;
                      } else {
                        set.weight = double.tryParse(value) ?? 0.0;
                      }
                    },
                  ),
                ),
              const SizedBox(width: 8),
              
              // 有酸素運動の場合は「距離（km）」、それ以外は「回数」
              Expanded(
                child: TextFormField(
                  key: ValueKey('reps_${globalIndex}_${set.reps}'),
                  decoration: InputDecoration(
                    labelText: _isCardioExercise(set.exerciseName) ? '距離 (km)' : '回数',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: set.reps == 0 ? '' : set.reps.toString(),
                  onChanged: (value) {
                    // 空文字列または無効な値の場合は0に
                    if (value.isEmpty) {
                      set.reps = 0;
                    } else {
                      set.reps = int.tryParse(value) ?? 0;
                    }
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
          
          // セット種別選択
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('通常', style: TextStyle(fontSize: 12)),
                selected: set.setType == SetType.normal,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      set.setType = SetType.normal;
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('W-UP', style: TextStyle(fontSize: 12)),
                selected: set.setType == SetType.warmup,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      set.setType = SetType.warmup;
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('SS', style: TextStyle(fontSize: 12)),
                selected: set.setType == SetType.superset,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      set.setType = SetType.superset;
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Drop', style: TextStyle(fontSize: 12)),
                selected: set.setType == SetType.dropset,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      set.setType = SetType.dropset;
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('限界', style: TextStyle(fontSize: 12)),
                selected: set.setType == SetType.failure,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      set.setType = SetType.failure;
                    });
                  }
                },
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 補助トグル ＋ セット完了チェック
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
              
              // セット完了チェック（インターバルはAppBarから開始）
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      set.isCompleted = !set.isCompleted;
                    });
                  },
                  icon: Icon(
                    set.isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(set.isCompleted ? '完了' : '未完了'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: set.isCompleted ? Colors.green : Colors.grey,
                    side: BorderSide(
                      color: set.isCompleted ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 前回ワークアウトデータをフォーマット
  String _formatLastWorkoutData(Map<String, dynamic>? lastData) {
    if (lastData == null) return '';
    
    final weight = (lastData['weight'] ?? 0).toDouble();
    final reps = (lastData['reps'] ?? 0).toInt();
    
    final date = lastData['date'] as DateTime?;
    final dateStr = date != null 
        ? '${date.month}/${date.day}'
        : '不明';
    
    // シンプルに前回の1セットのみ表示（前々回は表示しない）
    return '前回 $dateStr: ${weight}kg × ${reps}回';
  }
}
