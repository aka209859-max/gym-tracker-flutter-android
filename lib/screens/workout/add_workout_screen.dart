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
import '../../services/review_request_service.dart';
import '../../services/enhanced_share_service.dart';
import '../../services/offline_service.dart'; // ✅ v1.0.161: オフライン対応
import '../../services/exercise_master_data.dart'; // FIX: Problem 2 - Add ExerciseMasterData import
import 'package:gym_match/gen/app_localizations.dart'; // 🔧 v1.0.299: ABSOLUTE PATH (Gemini推奨)

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
  bool isTimeMode; // 時間モード (true: 秒数, false: 回数) - v1.0.169: 腹筋用
  bool isCardio; // 🔧 v1.0.226+242: 有酸素運動フラグ（セット作成時に固定）
  
  WorkoutSet({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    this.isCompleted = false,
    this.hasAssist = false,
    this.setType = SetType.normal,
    this.isBodyweightMode = true, // デフォルトは自重モード
    this.isTimeMode = false, // デフォルトは回数モード
    this.isCardio = false, // 🔧 v1.0.226+242: デフォルトは筋トレ
  });
}

class AddWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic>? templateData;
  
  const AddWorkoutScreen({super.key, this.templateData});

  @override
  State<AddWorkoutScreen> createState() => _AddWorkoutScreenState();
}

// 🔧 v1.0.248: ワークアウトタイプフィルター（筋トレ/有酸素の2部屋制）
enum WorkoutTypeFilter {
  strength, // 筋トレ（デフォルト）
  cardio,   // 有酸素
}

class _AddWorkoutScreenState extends State<AddWorkoutScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedMuscleGroup;
  int _startHour = 9;
  int _startMinute = 0;
  int _endHour = 11;
  int _endMinute = 0;
  final List<WorkoutSet> _sets = [];
  
  // 🔧 v1.0.248: ワークアウトタイプフィルター（デフォルト: 筋トレ）
  WorkoutTypeFilter _workoutTypeFilter = WorkoutTypeFilter.strength;
  
  // タイマー関連
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _isResting = false;
  int _selectedRestDuration = 90;
  final List<int> _restDurations = [30, 60, 90, 120];
  bool _isRestDialogShowing = false; // ✅ v1.0.162: ダイアログ表示状態フラグ
  
  // 前回記録データ
  Map<String, Map<String, dynamic>> _lastWorkoutData = {};
  
  // メモ機能
  final TextEditingController _memoController = TextEditingController();
  
  // ✅ v1.0.158: ユーザーの最新体重（懸垂の自重計算用）
  double? _userBodyweight;
  
  // 🔧 v1.0.222: AIコーチからのデータ
  Map<String, dynamic>? _aiCoachData;
  bool _isFromAICoach = false;
  
  // 🔧 v1.0.221: 二頭筋・三頭筋の種目を詳細化（Deep Search結果反映）
  // 🔧 v1.0.296: late変更（AppLocalizations.of(context)をdidChangeDependenciesで初期化）
  late Map<String, List<String>> _muscleGroupExercises;
  bool _isInitialized = false; // 🔧 初期化フラグ
  
  // 有酸素運動かどうかを判定
  bool _isCardioExercise(String exerciseName) {
    final cardioExercises = _muscleGroupExercises[AppLocalizations.of(context)!.exerciseCardio] ?? [];
    return cardioExercises.contains(exerciseName);
  }
  
  // 懸垂系種目かどうかを判定
  bool _isPullUpExercise(String exerciseName) {
    final pullUpVariations = [AppLocalizations.of(context)!.exercisePullUp, AppLocalizations.of(context)!.exerciseChinUp, AppLocalizations.of(context)!.workout_e3dc6687, AppLocalizations.of(context)!.workout_13a24951, AppLocalizations.of(context)!.workout_269bc3f6];
    return pullUpVariations.any((variation) => exerciseName.contains(variation));
  }
  
  // ✅ v1.0.167: 腹筋系種目かどうかを判定（懸垂と同じUI: 自重/重さ/秒数）
  bool _isAbsExercise(String exerciseName) {
    final absExercises = _muscleGroupExercises[AppLocalizations.of(context)!.bodyPart_ceb49fa1] ?? [];
    return absExercises.contains(exerciseName);
  }

  /// v1.0.169: 腹筋種目のデフォルト時間モード判定（プランク系は秒数、その他は回数）
  /// v1.0.185: 腹筋種目のデフォルト時間モード判定
  /// ユーザーが秒数入力した場合は「秒」表記にするため、デフォルトで全ての腹筋を秒数モードとして扱う
  /// （過去のis_time_mode=nullデータとの互換性のため）
  bool _getDefaultTimeMode(String exerciseName) {
    // 腹筋種目は全て秒数モードをデフォルトとする
    return _isAbsExercise(exerciseName);
  }

  @override
  void initState() {
    super.initState();
    _autoLoginIfNeeded();
    _loadCustomExercises();
    _loadLastWorkoutData();
    _loadUserBodyweight(); // ✅ v1.0.158: 体重を取得
    _applyTemplateDataIfProvided();
    
    // 🔧 v1.0.222: AI Coach データの初期化は didChangeDependencies で行う
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 🔧 v1.0.297: 1回だけ初期化（context利用可能）
    if (!_isInitialized) {
      _muscleGroupExercises = {
        AppLocalizations.of(context)!.bodyPartChest: [AppLocalizations.of(context)!.exerciseBenchPress, AppLocalizations.of(context)!.exerciseDumbbellPress, AppLocalizations.of(context)!.exerciseInclinePress, AppLocalizations.of(context)!.exercise_11c97451, AppLocalizations.of(context)!.workout_e85fb0a4, AppLocalizations.of(context)!.workout_b18d1691, AppLocalizations.of(context)!.workout_c196525e, AppLocalizations.of(context)!.exerciseCableFly, AppLocalizations.of(context)!.exerciseDips, AppLocalizations.of(context)!.exercise_fbe3be86, AppLocalizations.of(context)!.workout_aaa776e7],
        AppLocalizations.of(context)!.bodyPartLegs: [AppLocalizations.of(context)!.exercise_8c982e86, AppLocalizations.of(context)!.exercise_4e99d714, AppLocalizations.of(context)!.exercise_1602d233, AppLocalizations.of(context)!.exerciseSquat, AppLocalizations.of(context)!.exerciseLegPress, AppLocalizations.of(context)!.exerciseLegExtension, AppLocalizations.of(context)!.exerciseLegCurl, AppLocalizations.of(context)!.exercise_0afc8ed2, AppLocalizations.of(context)!.workout_a19f4e60, AppLocalizations.of(context)!.workout_4027c245, AppLocalizations.of(context)!.workout_dc27b01c, AppLocalizations.of(context)!.exerciseCalfRaise, AppLocalizations.of(context)!.workout_7cb5b362],
        AppLocalizations.of(context)!.bodyPartBack: [AppLocalizations.of(context)!.exerciseDeadlift, AppLocalizations.of(context)!.exerciseLatPulldown, AppLocalizations.of(context)!.workout_be7c87e2, AppLocalizations.of(context)!.workout_8d5f0039, AppLocalizations.of(context)!.exerciseChinUp, AppLocalizations.of(context)!.exercisePullUp, AppLocalizations.of(context)!.exerciseBentOverRow, AppLocalizations.of(context)!.workout_f67592f1, AppLocalizations.of(context)!.workout_78f50d3b, AppLocalizations.of(context)!.exerciseSeatedRow, AppLocalizations.of(context)!.workout_f8d1b968, AppLocalizations.of(context)!.workout_56b5390a, AppLocalizations.of(context)!.workout_600bfaf4],
        AppLocalizations.of(context)!.bodyPartShoulders: [AppLocalizations.of(context)!.exerciseShoulderPress, AppLocalizations.of(context)!.exercise_b9e82d29, AppLocalizations.of(context)!.exercise_158c0c0a, AppLocalizations.of(context)!.exerciseSideRaise, AppLocalizations.of(context)!.workout_0d3898b0, AppLocalizations.of(context)!.exerciseFrontRaise, AppLocalizations.of(context)!.workout_61db805d, AppLocalizations.of(context)!.exerciseRearDeltFly, AppLocalizations.of(context)!.workout_a2742c19, AppLocalizations.of(context)!.exerciseUprightRow, AppLocalizations.of(context)!.workout_6a40751e],
        AppLocalizations.of(context)!.bodyPartBiceps: [AppLocalizations.of(context)!.exerciseBarbellCurl, AppLocalizations.of(context)!.workout_6bc85042, AppLocalizations.of(context)!.exerciseDumbbellCurl, AppLocalizations.of(context)!.workout_143ec9bf, AppLocalizations.of(context)!.exerciseHammerCurl, AppLocalizations.of(context)!.exercisePreacherCurl, AppLocalizations.of(context)!.workout_9556156f, AppLocalizations.of(context)!.workout_6a8e2907, AppLocalizations.of(context)!.exerciseCableCurl, AppLocalizations.of(context)!.workout_6c337a90, AppLocalizations.of(context)!.workout_f7c7e985, AppLocalizations.of(context)!.workout_f3949316, AppLocalizations.of(context)!.workout_404e46d1, AppLocalizations.of(context)!.workout_6b330584],
        AppLocalizations.of(context)!.bodyPartTriceps: [AppLocalizations.of(context)!.exercise_636fb74f, AppLocalizations.of(context)!.exercise_cba215fa, AppLocalizations.of(context)!.workout_41ae2e59, AppLocalizations.of(context)!.exerciseSkullCrusher, AppLocalizations.of(context)!.workout_f00eef45, AppLocalizations.of(context)!.exerciseDips, AppLocalizations.of(context)!.workout_4a6fa58a, AppLocalizations.of(context)!.exerciseKickback, AppLocalizations.of(context)!.exercise_a60f616c, AppLocalizations.of(context)!.workout_06bbf6c9, AppLocalizations.of(context)!.exercise_f48ee2b4, AppLocalizations.of(context)!.workout_7e5aac14, AppLocalizations.of(context)!.exercise_235597fb, AppLocalizations.of(context)!.workout_8a9a2d2b, AppLocalizations.of(context)!.workout_facbc0fc, AppLocalizations.of(context)!.workout_db390755],
        AppLocalizations.of(context)!.bodyPart_ceb49fa1: [AppLocalizations.of(context)!.exerciseCrunch, AppLocalizations.of(context)!.exerciseLegRaise, AppLocalizations.of(context)!.exerciseHangingLegRaise, AppLocalizations.of(context)!.exercisePlank, AppLocalizations.of(context)!.exerciseSidePlank, AppLocalizations.of(context)!.exerciseAbRoller, AppLocalizations.of(context)!.exerciseCableCrunch, AppLocalizations.of(context)!.exerciseBicycleCrunch, AppLocalizations.of(context)!.workout_b2d699ea, AppLocalizations.of(context)!.workout_9bee258f, AppLocalizations.of(context)!.workout_eebef32f, AppLocalizations.of(context)!.workout_5be61342],
        AppLocalizations.of(context)!.exerciseCardio: [AppLocalizations.of(context)!.exerciseRunning, AppLocalizations.of(context)!.workout_f7a7208d, AppLocalizations.of(context)!.workout_285aeb0d, AppLocalizations.of(context)!.workout_f62c28a0, AppLocalizations.of(context)!.workout_cf6a6f5b, AppLocalizations.of(context)!.exerciseAerobicBike, AppLocalizations.of(context)!.workout_f4ecb3c9, AppLocalizations.of(context)!.workout_a90ed9c4, AppLocalizations.of(context)!.workout_4c6d7db7, AppLocalizations.of(context)!.workout_e23f084e, AppLocalizations.of(context)!.workout_9114559c, AppLocalizations.of(context)!.workout_aa4c3c64, AppLocalizations.of(context)!.workout_ba2fef80, AppLocalizations.of(context)!.workout_bc2d4a29, AppLocalizations.of(context)!.workout_fcdc095e, AppLocalizations.of(context)!.workout_9bee258f, AppLocalizations.of(context)!.workout_6180358f],
      };
      _isInitialized = true;
    }
    
    // 🔧 v1.0.222: AI Coach からのデータを取得
    if (!_isFromAICoach) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['fromAICoach'] == true) {
        _aiCoachData = args;
        _isFromAICoach = true;
        _initializeFromAICoach(args);
      }
    }
  }
  
  /// 🔧 v1.0.222: AIコーチからのデータで初期化
  /// ParsedExerciseリストを受け取り、1RM計算と推奨重量/回数でセットを自動生成
  Future<void> _initializeFromAICoach(Map<String, dynamic> args) async {
    try {
      debugPrint('🤖 AIコーチデータから初期化開始');
      
      final selectedExercises = args['selectedExercises'] as List?;
      final userLevel = args['userLevel'] as String?;
      // v1.0.225-hotfix: Map形式の履歴データに対応
      final exerciseHistory = args['exerciseHistory'] as Map<String, dynamic>?;
      
      if (selectedExercises == null || selectedExercises.isEmpty) {
        debugPrint('⚠️ 選択された種目がありません');
        return;
      }
      
      debugPrint('📋 選択種目: ${selectedExercises.length}件');
      debugPrint('🎯 ユーザーレベル: $userLevel');
      // v1.0.225-hotfix2: Map形式の履歴データに対応（Null安全性）
      if (exerciseHistory != null && exerciseHistory is Map) {
        debugPrint('📊 履歴データ: ${exerciseHistory.keys.length}種目');
      } else {
        debugPrint('📊 履歴データ: なし');
      }
      
      // 各種目ごとに1RMを計算してセットを生成
      for (var exercise in selectedExercises) {
        // ParsedExerciseオブジェクトからデータを取得
        final exerciseName = _getPropertyValue(exercise, 'name') as String;
        final bodyPart = _getPropertyValue(exercise, 'bodyPart') as String;
        final aiWeight = _getPropertyValue(exercise, 'weight') as double?;
        final aiReps = _getPropertyValue(exercise, 'reps') as int?;
        final aiSets = _getPropertyValue(exercise, 'sets') as int?;
        final isCardio = _getPropertyValue(exercise, 'isCardio') as bool? ?? false; // 🔧 v1.0.242+266: AI Coachから直接取得
        
        debugPrint('  🏋️ 種目: $exerciseName (部位: $bodyPart, 有酸素: $isCardio)');
        
        // 1. 履歴から1RMを計算
        final oneRM = _calculate1RMFromHistory(exerciseName, exerciseHistory);
        debugPrint('    💪 推定1RM: ${oneRM?.toStringAsFixed(1) ?? "なし"}kg');
        
        // 2. レベルと1RMに基づいて推奨重量・回数を決定
        final recommendation = _getRecommendedWeightAndReps(
          userLevel ?? AppLocalizations.of(context)!.levelBeginner,
          oneRM,
          aiWeight,
          aiReps,
        );
        
        final weight = recommendation['weight'] as double;
        final reps = recommendation['reps'] as int;
        final sets = aiSets ?? 3; // デフォルト3セット
        
        debugPrint('    ✅ 推奨: ${weight}kg × ${reps}回 × ${sets}セット');
        
        // 3. セットを自動生成
        setState(() {
          // 最初のセットの部位を選択
          if (_selectedMuscleGroup == null) {
            _selectedMuscleGroup = bodyPart;
          }
          
          for (int i = 0; i < sets; i++) {
            _sets.add(WorkoutSet(
              exerciseName: exerciseName,
              weight: weight,
              reps: reps,
              isBodyweightMode: false,
              isTimeMode: false,
              isCardio: isCardio, // 🔧 v1.0.242+266: ParsedExercise.isCardioを直接使用
            ));
          }
        });
      }
      
      debugPrint('✅ AIコーチデータ初期化完了: ${_sets.length}セット生成');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AIコーチの推奨メニューを読み込みました (${selectedExercises.length}種目)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ AIコーチデータ初期化エラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AIコーチデータの読み込みに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// オブジェクトから動的にプロパティを取得（ParsedExerciseクラス対応）
  dynamic _getPropertyValue(dynamic obj, String propertyName) {
    if (obj is Map) {
      return obj[propertyName];
    }
    // ParsedExerciseオブジェクトの場合
    switch (propertyName) {
      case 'name':
        return (obj as dynamic).name;
      case 'bodyPart':
        return (obj as dynamic).bodyPart;
      case 'weight':
        return (obj as dynamic).weight;
      case 'reps':
        return (obj as dynamic).reps;
      case 'sets':
        return (obj as dynamic).sets;
      default:
        return null;
    }
  }
  
  /// 🔧 v1.0.222: 過去30日の履歴から種目別の1RMを取得
  /// AIコーチが既に計算した1RMを使用（Epley formula: 1RM = weight × (1 + reps / 30)）
  double? _calculate1RMFromHistory(String exerciseName, dynamic history) {
    if (history == null) {
      debugPrint('    ⚠️ 履歴データなし');
      return null;
    }
    
    // AIコーチから渡される形式: Map<String, Map<String, dynamic>>
    if (history is Map<String, dynamic>) {
      final exerciseData = history[exerciseName] as Map<String, dynamic>?;
      if (exerciseData != null) {
        final oneRM = exerciseData['max1RM'] as double?;
        if (oneRM != null && oneRM > 0) {
          debugPrint('    ✅ 1RM取得成功: ${oneRM.toStringAsFixed(1)}kg');
          return oneRM;
        }
      }
    }
    
    // 履歴がList形式の場合（後方互換性のため）
    if (history is List) {
      double maxOneRM = 0.0;
      
      for (var log in history) {
        final exercises = log['exercises'] as List<dynamic>?;
        if (exercises == null) continue;
        
        for (var exercise in exercises) {
          final name = exercise['name'] as String?;
          if (name != exerciseName) continue;
          
          final sets = exercise['sets'] as List<dynamic>?;
          if (sets == null) continue;
          
          for (var set in sets) {
            final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
            final reps = (set['reps'] as num?)?.toInt() ?? 0;
            
            if (weight > 0 && reps > 0 && reps <= 15) {
              // Brzycki式で1RMを計算
              final oneRM = reps == 1 ? weight : weight * (36 / (37 - reps));
              if (oneRM > maxOneRM) {
                maxOneRM = oneRM;
              }
            }
          }
        }
      }
      
      return maxOneRM > 0 ? maxOneRM : null;
    }
    
    debugPrint('    ⚠️ 履歴形式が不正');
    return null;
  }
  
  /// 🔧 v1.0.222: レベルと1RMに基づいて推奨重量と回数を決定
  Map<String, dynamic> _getRecommendedWeightAndReps(
    String userLevel,
    double? oneRM,
    double? aiWeight,
    int? aiReps,
  ) {
    // 1RMがない場合はAIの提案値を使う、それもなければデフォルト値
    if (oneRM == null || oneRM == 0) {
      return {
        'weight': aiWeight ?? 10.0,
        'reps': aiReps ?? 10,
      };
    }
    
    // レベル別の推奨強度（%1RM）と回数
    double percentage;
    int reps;
    
    final l10n = AppLocalizations.of(context)!;
    if (userLevel == l10n.levelBeginner) {
      percentage = 0.65; // 65%
      reps = 12;
    } else if (userLevel == l10n.levelIntermediate) {
      percentage = 0.75; // 75%
      reps = 10;
    } else if (userLevel == l10n.levelAdvanced) {
      percentage = 0.80; // 80%
      reps = 8;
    } else {
      percentage = 0.70;
      reps = 10;
    }
    
    final recommendedWeight = (oneRM * percentage / 2.5).round() * 2.5; // 2.5kg単位で丸める
    
    return {
      'weight': recommendedWeight,
      'reps': reps,
    };
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
  
  /// ✅ v1.0.158: body_measurementsから最新の体重を取得
  Future<void> _loadUserBodyweight() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ 体重取得: ユーザー未ログイン');
        return;
      }
      
      debugPrint('🔍 体重記録を取得中... user_id: ${user.uid}');
      
      // Firestore から体重記録を取得（orderBy なしでインデックス不要）
      final snapshot = await FirebaseFirestore.instance
          .collection('body_measurements')
          .where('user_id', isEqualTo: user.uid)
          .get();
      
      debugPrint('📊 取得件数: ${snapshot.docs.length}');
      
      if (snapshot.docs.isNotEmpty) {
        // 日付でソートして最新を取得
        final sorted = snapshot.docs.toList()
          ..sort((a, b) {
            final aDate = (a.data()['date'] as Timestamp).toDate();
            final bDate = (b.data()['date'] as Timestamp).toDate();
            return bDate.compareTo(aDate);  // 降順
          });
        
        final data = sorted.first.data();
        final weight = data['weight'] as double?;
        
        if (weight != null) {
          setState(() {
            _userBodyweight = weight;
          });
          debugPrint('✅ ユーザー体重を取得: ${weight}kg');
        } else {
          debugPrint('⚠️ 体重データがnull');
        }
      } else {
        debugPrint('⚠️ 体重記録が見つかりません（データ件数: 0）');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 体重取得エラー: $e');
      debugPrint('   スタックトレース: $stackTrace');
    }
  }

  /// ✅ v1.0.161: ネットワーク状態チェック
  Future<bool> _checkNetworkStatus() async {
    try {
      debugPrint('🔍 ネットワーク状態確認中...');
      final isOnline = await OfflineService.isOnline();
      debugPrint(isOnline ? '🌐 オンライン' : '📴 オフライン');
      return isOnline;
    } catch (e) {
      debugPrint('⚠️ ネットワークチェックエラー: $e');
      return false; // エラー時はオフラインとみなす
    }
  }

  /// ✅ v1.0.161: オフラインでのトレーニング保存
  Future<void> _saveWorkoutOffline(String userId) async {
    debugPrint('📴 オフラインモード: ローカルに保存開始');
    debugPrint('   User ID: $userId');
    debugPrint('   筋肉グループ: $_selectedMuscleGroup');
    debugPrint('   セット数: ${_sets.length}');
    
    try {
      // トレーニング開始時刻と終了時刻を設定
      final now = DateTime.now();
      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour >= 2 ? now.hour - 2 : 0,
        now.minute,
      );
      
      final endTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour,
        now.minute,
      );

      // セットデータを準備
      final sets = _sets.map((set) {
        double effectiveWeight = set.weight;
        if (set.isBodyweightMode && _userBodyweight != null && _isPullUpExercise(set.exerciseName)) {
          effectiveWeight = _userBodyweight! + set.weight;
        }
        
        // 🔧 v1.0.243: 種目名から部位を逆引き
        String bodyPart = AppLocalizations.of(context)!.bodyPartOther;
        for (final entry in _muscleGroupExercises.entries) {
          if (entry.value.contains(set.exerciseName)) {
            bodyPart = entry.key;
            break;
          }
        }
        
        return {
          'exercise_name': set.exerciseName,
          'bodyPart': bodyPart,  // 🔧 v1.0.243: 部位情報を追加
          'weight': effectiveWeight,
          'reps': set.reps,
          'is_completed': set.isCompleted,
          'has_assist': set.hasAssist,
          'set_type': set.setType.toString().split('.').last,
          'is_bodyweight_mode': set.isBodyweightMode,
          'is_time_mode': set.isTimeMode,  // v1.0.169: 秒数/回数モード
          'is_cardio': set.isCardio,  // 🔧 v1.0.226+242: 有酸素フラグ保存
          'user_bodyweight': set.isBodyweightMode ? _userBodyweight : null,
          'additional_weight': set.isBodyweightMode ? set.weight : null,
        };
      }).toList();

      // Hive にローカル保存
      final localId = await OfflineService.saveWorkoutOffline({
        'user_id': userId,
        'muscle_group': _selectedMuscleGroup,
        'date': _selectedDate,
        'start_time': startTime,
        'end_time': endTime,
        'sets': sets,
        'created_at': now,
      });

      debugPrint('✅ オフライン保存成功: $localId');

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('📴 オフライン保存しました\nオンライン復帰時に自動同期されます'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ オフライン保存エラー: $e');
      debugPrint('   スタックトレース: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('オフライン保存エラー: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
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
        AppLocalizations.of(context)!.bodyPartChest: [AppLocalizations.of(context)!.exerciseBenchPress, AppLocalizations.of(context)!.exerciseDumbbellPress, AppLocalizations.of(context)!.exerciseInclinePress, AppLocalizations.of(context)!.exerciseCableFly, AppLocalizations.of(context)!.exerciseDips],
        AppLocalizations.of(context)!.bodyPartLegs: [AppLocalizations.of(context)!.exerciseSquat, AppLocalizations.of(context)!.exerciseLegPress, AppLocalizations.of(context)!.exerciseLegExtension, AppLocalizations.of(context)!.exerciseLegCurl, AppLocalizations.of(context)!.exerciseCalfRaise],
        AppLocalizations.of(context)!.bodyPartBack: [AppLocalizations.of(context)!.exerciseDeadlift, AppLocalizations.of(context)!.exerciseLatPulldown, AppLocalizations.of(context)!.exerciseBentOverRow, AppLocalizations.of(context)!.exerciseSeatedRow, AppLocalizations.of(context)!.exercisePullUp],
        AppLocalizations.of(context)!.bodyPartShoulders: [AppLocalizations.of(context)!.exerciseShoulderPress, AppLocalizations.of(context)!.exerciseSideRaise, AppLocalizations.of(context)!.exerciseFrontRaise, AppLocalizations.of(context)!.exerciseRearDeltFly, AppLocalizations.of(context)!.exerciseUprightRow],
        AppLocalizations.of(context)!.bodyPartBiceps: [AppLocalizations.of(context)!.exerciseBarbellCurl, AppLocalizations.of(context)!.exerciseDumbbellCurl, AppLocalizations.of(context)!.exerciseHammerCurl, AppLocalizations.of(context)!.exercisePreacherCurl, AppLocalizations.of(context)!.exerciseCableCurl],
        AppLocalizations.of(context)!.bodyPartTriceps: [AppLocalizations.of(context)!.exerciseTricepsExtension, AppLocalizations.of(context)!.exerciseSkullCrusher, AppLocalizations.of(context)!.workout_22752b72, AppLocalizations.of(context)!.exerciseDips, AppLocalizations.of(context)!.exerciseKickback],
        AppLocalizations.of(context)!.exerciseCardio: [AppLocalizations.of(context)!.exerciseRunning, AppLocalizations.of(context)!.workout_cf6a6f5b, AppLocalizations.of(context)!.exerciseAerobicBike, AppLocalizations.of(context)!.workout_f4ecb3c9, AppLocalizations.of(context)!.workout_a90ed9c4],
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
      final lastIsTimeMode = widget.templateData!['is_time_mode'] as bool?;  // ✅ v1.0.176: is_time_mode を取得
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
            // 🔧 v1.0.226+242: 既存データとの互換性のため、is_cardioがnullの場合は種目名から自動判定
            final isCardio = exercise['is_cardio'] as bool? ?? _isCardioExercise(name);
            
            print('  ✅ $name: ${targetSets}セット × ${targetReps}回 @ ${targetWeight}kg (有酸素: $isCardio)');
            
            // 各種目のtargetSets数だけセットを追加
            for (int i = 0; i < targetSets; i++) {
              _sets.add(WorkoutSet(
                exerciseName: name,
                weight: targetWeight,
                reps: targetReps,
                isCompleted: false,
                isBodyweightMode: _isPullUpExercise(name) || _isAbsExercise(name),
                isTimeMode: _getDefaultTimeMode(name),
                isCardio: isCardio, // 🔧 v1.0.226+242: テンプレートから読み込み or 自動判定
              ));
            }
          }
          
          print('✅ テンプレートから合計${_sets.length}セットを追加');
        }
        // ケース2: 単一種目を追加（履歴から「もう一度」の場合）
        else if (exerciseName != null) {
          // 🔧 v1.0.226+242: 既存データとの互換性のため、is_cardioがnullの場合は種目名から自動判定
          final lastIsCardio = widget.templateData!['is_cardio'] as bool?;
          _sets.add(WorkoutSet(
            exerciseName: exerciseName,
            weight: lastWeight ?? 0.0,
            reps: lastReps ?? 10,
            isCompleted: false,
            isBodyweightMode: _isPullUpExercise(exerciseName) || _isAbsExercise(exerciseName),
            isTimeMode: lastIsTimeMode ?? _getDefaultTimeMode(exerciseName),  // ✅ v1.0.176: templateData から is_time_mode を優先
            isCardio: lastIsCardio ?? _isCardioExercise(exerciseName), // 🔧 v1.0.226+242: templateDataから読み込み or 自動判定
          ));
          print('✅ $exerciseName に1セット追加（前回: ${lastWeight}kg × ${lastReps}reps, isTimeMode: ${lastIsTimeMode ?? _getDefaultTimeMode(exerciseName)}, isCardio: ${lastIsCardio ?? _isCardioExercise(exerciseName)}）');
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
            SnackBar(content: Text(AppLocalizations.of(context)!.workout_404c0672)),
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
          SnackBar(content: Text(AppLocalizations.of(context)!.dataLoadError(e.toString())), backgroundColor: Colors.red),
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
      
      // FIX: Problem 2 - Use centralized ExerciseMasterData logic
      final isPullUp = ExerciseMasterData.isPullUpExercise(exerciseName);
      final isAbs = ExerciseMasterData.isAbsExercise(exerciseName);
      final isCardio = ExerciseMasterData.isCardioExercise(exerciseName);
      
      debugPrint('➕ セット追加: $exerciseName (有酸素: $isCardio, 腹筋: $isAbs)');
      
      _sets.add(WorkoutSet(
        exerciseName: exerciseName,
        weight: lastSet?.weight ?? _lastWorkoutData[exerciseName]?['weight']?.toDouble() ?? 0.0,
        reps: lastSet?.reps ?? _lastWorkoutData[exerciseName]?['reps'] ?? 10,
        setType: SetType.normal,
        isBodyweightMode: lastSet?.isBodyweightMode ?? (isPullUp || isAbs ? true : false),
        isTimeMode: lastSet?.isTimeMode ?? (isAbs ? true : false), // 腹筋はデフォルト秒数
        isCardio: lastSet?.isCardio ?? isCardio, // 自動判定または前回の値を継承
      ));
    });
  }

  void _startRestTimer() {
    // ✅ v1.0.162: 既存のタイマーを確実に停止
    _restTimer?.cancel();
    
    setState(() {
      _isResting = true;
      _restSeconds = _selectedRestDuration;
    });
    
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // ✅ v1.0.162: mountedチェック追加
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_restSeconds > 0) {
          _restSeconds--;
        } else {
          _stopRestTimer();
          // ✅ v1.0.162: 非同期処理を分離してsetStateとの競合を防止
          Future.microtask(() => _notifyRestComplete());
        }
      });
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _restTimer = null; // ✅ v1.0.162: nullにして完全に破棄
    
    // ✅ v1.0.162: mountedチェック追加
    if (mounted) {
      setState(() {
        _isResting = false;
        _restSeconds = 0;
      });
    }
  }
  
  // タイマー終了時の通知（音声 + バイブレーション + ダイアログ）
  Future<void> _notifyRestComplete() async {
    print('🔔 タイマー終了通知開始');
    
    // ✅ v1.0.162: 既にダイアログが表示されている場合はスキップ
    if (_isRestDialogShowing) {
      print('⚠️ ダイアログ既に表示中 - スキップ');
      return;
    }
    
    // ✅ v1.0.162: 非同期処理前にmountedチェック
    if (!mounted) return;
    
    // 1. システムサウンドを再生（イヤホン対応）
    try {
      // iOSの通知音を再生（イヤホンに自動的にルーティングされる）
      await SystemSound.play(SystemSoundType.alert);
      print('✅ システムサウンド再生成功');
      
      // ✅ v1.0.162: 待機中にmountedチェック
      if (!mounted) return;
      
      // 追加で0.5秒後にもう一度鳴らす（より目立つように）
      await Future.delayed(const Duration(milliseconds: 500));
      
      // ✅ v1.0.162: 再度mountedチェック
      if (!mounted) return;
      
      await SystemSound.play(SystemSoundType.alert);
      print('✅ システムサウンド再生成功（2回目）');
    } catch (e) {
      print('❌ サウンド再生エラー: $e');
    }
    
    // ✅ v1.0.162: バイブレーション前にmountedチェック
    if (!mounted) return;
    
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
    
    // ✅ v1.0.162: ダイアログ表示前に最終mountedチェック
    if (!mounted) return;
    
    // 3. ダイアログ表示
    _isRestDialogShowing = true; // ✅ v1.0.162: フラグを立てる
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.green.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.green.shade400, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.alarm, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)!.workout_ec97904d,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        content: const Text(
          AppLocalizations.of(context)!.workout_4378d5d9,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // ✅ v1.0.162: フラグをクリアしてからダイアログを閉じる
              _isRestDialogShowing = false;
              Navigator.pop(dialogContext); // ✅ v1.0.162: dialogContextを使用
              print('✅ ユーザーがOKボタンを押下 - ダイアログ閉じる');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(AppLocalizations.of(context)!.ok,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).then((_) {
      // ✅ v1.0.162: ダイアログが閉じられた時に必ずフラグをクリア
      _isRestDialogShowing = false;
      print('✅ ダイアログ閉じる - フラグクリア');
    });
    
    // ✅ v1.0.162: 5秒後に自動的にダイアログを閉じる（ダブルpop防止）
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isRestDialogShowing && Navigator.canPop(context)) {
        _isRestDialogShowing = false;
        Navigator.pop(context);
        print('✅ 自動閉じ実行（5秒経過）');
      } else {
        print('⚠️ 自動閉じスキップ（既に閉じられています）');
      }
    });
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
                      child: Text(AppLocalizations.of(context)!.cancel, style: TextStyle(color: Colors.red)),
                    ),
                    const Text(
                      AppLocalizations.of(context)!.workout_b23db97f,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedRestDuration = tempSelectedDuration);
                        Navigator.pop(context);
                        _startRestTimer(); // 設定後すぐにタイマー開始
                      },
                      child: Text(AppLocalizations.of(context)!.workout_eb87a812, style: TextStyle(fontWeight: FontWeight.bold)),
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
              child: Text(AppLocalizations.of(context)!.cancel),
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
        isBodyweightMode: _isPullUpExercise(exerciseName) || _isAbsExercise(exerciseName),
        isTimeMode: _getDefaultTimeMode(exerciseName),
        isCardio: _isCardioExercise(exerciseName), // 🔧 v1.0.226+242: Fix cardio detection
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
                decoration: InputDecoration(
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
              decoration: InputDecoration(
                labelText: '回数 (reps)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              final weight = isPullUpBodyweight ? 0.0 : (double.tryParse(weightController.text) ?? 0.0);
              final reps = double.tryParse(repsController.text) ?? 10.0;
              Navigator.pop(context, {'weight': weight, 'reps': reps});
            },
            child: Text(AppLocalizations.of(context)!.apply),
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
          isBodyweightMode: _isPullUpExercise(exerciseName) || _isAbsExercise(exerciseName),
          isTimeMode: _getDefaultTimeMode(exerciseName),
          isCardio: _isCardioExercise(exerciseName), // 🔧 v1.0.226+242: Fix cardio detection
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
      AppLocalizations.of(context)!.bodyPartChest: [AppLocalizations.of(context)!.exerciseBenchPress, AppLocalizations.of(context)!.exerciseDumbbellPress, AppLocalizations.of(context)!.exerciseInclinePress, AppLocalizations.of(context)!.exerciseCableFly, AppLocalizations.of(context)!.exerciseDips],
      AppLocalizations.of(context)!.bodyPartLegs: [AppLocalizations.of(context)!.exerciseSquat, AppLocalizations.of(context)!.exerciseLegPress, AppLocalizations.of(context)!.exerciseLegExtension, AppLocalizations.of(context)!.exerciseLegCurl, AppLocalizations.of(context)!.exerciseCalfRaise],
      AppLocalizations.of(context)!.bodyPartBack: [AppLocalizations.of(context)!.exerciseDeadlift, AppLocalizations.of(context)!.exerciseLatPulldown, AppLocalizations.of(context)!.exerciseBentOverRow, AppLocalizations.of(context)!.exerciseSeatedRow, AppLocalizations.of(context)!.exercisePullUp],
      AppLocalizations.of(context)!.bodyPartShoulders: [AppLocalizations.of(context)!.exerciseShoulderPress, AppLocalizations.of(context)!.exerciseSideRaise, AppLocalizations.of(context)!.exerciseFrontRaise, AppLocalizations.of(context)!.exerciseRearDeltFly, AppLocalizations.of(context)!.exerciseUprightRow],
      AppLocalizations.of(context)!.bodyPartBiceps: [AppLocalizations.of(context)!.exerciseBarbellCurl, AppLocalizations.of(context)!.exerciseDumbbellCurl, AppLocalizations.of(context)!.exerciseHammerCurl, AppLocalizations.of(context)!.exercisePreacherCurl, AppLocalizations.of(context)!.exerciseCableCurl],
      AppLocalizations.of(context)!.bodyPartTriceps: [AppLocalizations.of(context)!.exerciseTricepsExtension, AppLocalizations.of(context)!.exerciseSkullCrusher, AppLocalizations.of(context)!.workout_22752b72, AppLocalizations.of(context)!.exerciseDips, AppLocalizations.of(context)!.exerciseKickback],
      AppLocalizations.of(context)!.exerciseCardio: [AppLocalizations.of(context)!.exerciseRunning, AppLocalizations.of(context)!.workout_cf6a6f5b, AppLocalizations.of(context)!.exerciseAerobicBike, AppLocalizations.of(context)!.workout_f4ecb3c9, AppLocalizations.of(context)!.workout_a90ed9c4],
    };
    
    final defaults = defaultExercises[_selectedMuscleGroup] ?? [];
    return !defaults.contains(exerciseName);
  }
  
  // カスタム種目削除確認
  Future<void> _confirmDeleteCustomExercise(String exerciseName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.workout_54d4f6f6),
        content: Text('「$exerciseName」を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.remove),
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
      final weekdays = [AppLocalizations.of(context)!.mon, AppLocalizations.of(context)!.tue, AppLocalizations.of(context)!.wed, AppLocalizations.of(context)!.thu, AppLocalizations.of(context)!.fri, AppLocalizations.of(context)!.sat, AppLocalizations.of(context)!.sun];
      final weekday = weekdays[(date.weekday - 1) % 7];
      return '${date.year}年${date.month}月${date.day}日($weekday)';
    }
  }

  /// ✅ v1.0.178: オフ日として保存
  Future<void> _saveRestDay(BuildContext context) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.loginRequired)),
      );
      return;
    }
    
    try {
      debugPrint('📴 オフ日を保存: $_selectedDate');
      
      // 日付を正規化
      final normalizedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      
      // 既存のオフ日レコードを確認
      final existingQuery = await FirebaseFirestore.instance
          .collection('rest_days')
          .where('user_id', isEqualTo: user.uid)
          .where('date', isEqualTo: Timestamp.fromDate(normalizedDate))
          .get();
      
      if (existingQuery.docs.isNotEmpty) {
        // 既にオフ日として登録済み
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.workout_85f9fe6e),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Firestoreにオフ日を保存
      await FirebaseFirestore.instance.collection('rest_days').add({
        'user_id': user.uid,
        'date': Timestamp.fromDate(normalizedDate),
        'created_at': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ オフ日保存成功');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.bed, color: Colors.white),
                SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.workout_da75109e),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // ホーム画面に戻る
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ オフ日保存エラー: $e');
      debugPrint('   スタックトレース: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('オフ日の保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          isTimeMode: set.isTimeMode,
          isCardio: set.isCardio, // 🔧 v1.0.226+242: Preserve cardio flag
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
        SnackBar(content: Text(AppLocalizations.of(context)!.workout_4c734626)),
      );
      return;
    }

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ✅ v1.0.161: ネットワーク状態を確認
      final isOnline = await _checkNetworkStatus();

      if (!isOnline) {
        // 📴 オフラインモード: ローカルに保存
        await _saveWorkoutOffline(user.uid);
        return;
      }

      // 🌐 オンラインモード: Firestore に保存
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
          final newSets = _sets.map((set) {
            // ✅ v1.0.158+v1.0.170: 自重モード（懸垂のみ）の場合、体重を自動反映
            double effectiveWeight = set.weight;
            if (set.isBodyweightMode && _userBodyweight != null && _isPullUpExercise(set.exerciseName)) {
              effectiveWeight = _userBodyweight! + set.weight;
              debugPrint('✅ 既存記録追加 - 自重モード反映: ${set.exerciseName} = ${_userBodyweight}kg + ${set.weight}kg = ${effectiveWeight}kg');
            }
            
            debugPrint('💾 保存データ: ${set.exerciseName} - isTimeMode: ${set.isTimeMode}, isCardio: ${set.isCardio}, reps: ${set.reps}');
            return {
              'exercise_name': set.exerciseName,
              'weight': effectiveWeight,  // ✅ 自重 + 追加重量
              'reps': set.reps,
              'is_completed': set.isCompleted,
              'has_assist': set.hasAssist,
              'set_type': set.setType.toString().split('.').last,
              'is_bodyweight_mode': set.isBodyweightMode,
              'is_time_mode': set.isTimeMode,  // v1.0.169: 秒数/回数モード
              'is_cardio': set.isCardio,  // 🔧 v1.0.226+242: 有酸素フラグ保存
              'user_bodyweight': set.isBodyweightMode ? _userBodyweight : null,
              'additional_weight': set.isBodyweightMode ? set.weight : null,
            };
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
          'sets': _sets.map((set) {
            // ✅ v1.0.158+v1.0.170: 自重モード（懸垂のみ）の場合、体重を自動反映
            double effectiveWeight = set.weight;
            if (set.isBodyweightMode && _userBodyweight != null && _isPullUpExercise(set.exerciseName)) {
              // 自重モード: ユーザー体重 + 追加重量（例: 体重70kg + プレート10kg = 80kg）
              effectiveWeight = _userBodyweight! + set.weight;
              debugPrint('✅ 自重モード反映: ${set.exerciseName} = ${_userBodyweight}kg (体重) + ${set.weight}kg (追加) = ${effectiveWeight}kg');
            }
            
            // 🔧 v1.0.245: ExerciseMasterData を使用して部位を取得 (Problem 1 fix)
            final bodyPart = ExerciseMasterData.getBodyPartByName(set.exerciseName);
            
            return {
              'exercise_name': set.exerciseName,
              'bodyPart': bodyPart,  // 🔧 v1.0.243: 部位情報を追加
              'weight': effectiveWeight,  // ✅ 自重 + 追加重量
              'reps': set.reps,
              'is_completed': set.isCompleted,
              'has_assist': set.hasAssist,
              'set_type': set.setType.toString().split('.').last,
              'is_bodyweight_mode': set.isBodyweightMode,
              'is_time_mode': set.isTimeMode,  // v1.0.169: 秒数/回数モード
              'is_cardio': set.isCardio,  // 🔧 v1.0.226+242: 有酸素フラグ保存
              'user_bodyweight': set.isBodyweightMode ? _userBodyweight : null,  // ✅ 体重を記録
              'additional_weight': set.isBodyweightMode ? set.weight : null,  // ✅ 追加重量を記録
            };
          }).toList(),
          'created_at': FieldValue.serverTimestamp(),
        });
        
        DebugLogger.instance.log('✅ ワークアウト保存成功: Document ID = ${workoutDoc.id}');

        // FIX: Problem 4 - メモ保存の強化
        if (_memoController.text.trim().isNotEmpty) {
          try {
            final noteId = DateTime.now().millisecondsSinceEpoch.toString();
            await FirebaseFirestore.instance
                .collection('workout_notes')
                .doc(noteId)
                .set({
              'user_id': user.uid,
              'workout_session_id': workoutDoc.id, // 正しいIDを使用
              'content': _memoController.text.trim(),
              'created_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
            });
            debugPrint('✅ メモ保存完了: $noteId -> workout_session: ${workoutDoc.id}');
          } catch (e) {
            debugPrint('❌ メモ保存エラー: $e');
          }
        }
      }

      // Firestoreの書き込み完了を確実に待機（500ms）
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.workout_498b0ea4)),
        );
        
        // 🎯 Phase 1: トレーニング記録後のAI導線ポップアップ
        await _showPostWorkoutAIPrompt();
        
        // ⭐ ASO: レビュー依頼（5回目のトレーニング後）
        _checkAndShowReviewRequest();
        
        // 🏆 PR達成チェック & シェア提案
        _checkPRAndOfferShare();
      }
    } catch (e, stackTrace) {
      DebugLogger.instance.log('❌ ワークアウト保存エラー');
      DebugLogger.instance.log('   エラー: $e');
      DebugLogger.instance.log('   スタックトレース: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.saveFailed(e.toString())),
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
          title: Text(AppLocalizations.of(context)!.trainingLog),
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
              tooltip: AppLocalizations.of(context)!.workout_6218789d,
            ),
          ] else ...[
            TextButton.icon(
              icon: const Icon(Icons.timer, color: Colors.white),
              label: const Text(
                AppLocalizations.of(context)!.workout_e6f170ef,
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
                          AppLocalizations.of(context)!.workout_8a92c566,
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
                  // ✅ v1.0.178: オフボタン
                  OutlinedButton.icon(
                    onPressed: () => _saveRestDay(context),
                    icon: const Icon(Icons.bed, size: 18),
                    label: Text(AppLocalizations.of(context)!.workout_a0c22faa),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: Text(AppLocalizations.of(context)!.workout_5c7bbafb),
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
                          tooltip: AppLocalizations.of(context)!.copySet,
                        ),
                      if (isCustomExercise)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red,
                          onPressed: () => _confirmDeleteCustomExercise(exercise),
                          tooltip: AppLocalizations.of(context)!.workout_54d4f6f6,
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
                  label: Text(AppLocalizations.of(context)!.addCustomExercise),
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
                child: Row(
                  children: [
                    Text(AppLocalizations.of(context)!.sets,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    // 🔧 v1.0.248: ワークアウトタイプフィルタータブ（筋トレ/有酸素の2部屋制）
                    SegmentedButton<WorkoutTypeFilter>(
                      segments: [
                        ButtonSegment(
                          value: WorkoutTypeFilter.strength,
                          label: Text(AppLocalizations.of(context)!.strengthTrainingFilter, style: TextStyle(fontSize: 13)),
                          icon: Icon(Icons.fitness_center, size: 18),
                        ),
                        ButtonSegment(
                          value: WorkoutTypeFilter.cardio,
                          label: Text(AppLocalizations.of(context)!.exerciseCardio, style: TextStyle(fontSize: 13)),
                          icon: Icon(Icons.directions_run, size: 18),
                        ),
                      ],
                      selected: {_workoutTypeFilter},
                      onSelectionChanged: (Set<WorkoutTypeFilter> newSelection) {
                        setState(() {
                          _workoutTypeFilter = newSelection.first;
                        });
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 種目ごとにグループ化 + フィルタリング
              ...() {
                // 🔧 v1.0.248: フィルターに基づいてセットを絞り込み（筋トレ/有酸素の2部屋制）
                final filteredSets = _sets.where((set) {
                  switch (_workoutTypeFilter) {
                    case WorkoutTypeFilter.strength:
                      return !set.isCardio;
                    case WorkoutTypeFilter.cardio:
                      return set.isCardio;
                  }
                }).toList();
                
                final exerciseGroups = <String, List<WorkoutSet>>{};
                for (var set in filteredSets) {
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
                    label: Text(AppLocalizations.of(context)!.workout_57b74023),
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
                    label: Text(AppLocalizations.of(context)!.workout_779c0c7b),
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
            
            // 🔧 v1.0.222: AIコーチからの場合は1RM情報も表示
            if (_isFromAICoach) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🤖', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.workout_400911f5,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        // v1.0.225-hotfix: Map形式の履歴データに対応
                        final exerciseHistory = _aiCoachData?['exerciseHistory'];
                        final oneRM = _calculate1RMFromHistory(exerciseName, exerciseHistory);
                        final userLevel = _aiCoachData?['userLevel'] as String? ?? AppLocalizations.of(context)!.levelBeginner;
                        
                        if (oneRM != null && oneRM > 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '推定1RM: ${oneRM.toStringAsFixed(1)}kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'あなたのレベル ($userLevel) に合わせた重量・回数を設定しています',
                                style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                              ),
                            ],
                          );
                        } else {
                          return Text(
                            AppLocalizations.of(context)!.workout_207a9a37,
                            style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            
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
                          AppLocalizations.of(context)!.workout_565c4718,
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
              
              // 懸垂または腹筋の場合は自重/荷重モード切り替えを含む特別なUI
              if (_isPullUpExercise(set.exerciseName) || _isAbsExercise(set.exerciseName))
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
                              child: Text(AppLocalizations.of(context)!.bodyweight, style: TextStyle(fontSize: 12)),
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
                              child: Text(
                                _isAbsExercise(set.exerciseName) ? AppLocalizations.of(context)!.workout_2579352f : AppLocalizations.of(context)!.workout_63dbc040, 
                                style: const TextStyle(fontSize: 12)
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 荷重モードの場合のみ重量入力欄を表示
                      if (!set.isBodyweightMode)
                        TextFormField(
                          key: ValueKey('weight_${globalIndex}_${set.weight}'),
                          decoration: InputDecoration(
                            labelText: _isAbsExercise(set.exerciseName) ? '重さ (kg)' : '荷重 (kg)',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              AppLocalizations.of(context)!.bodyweight,
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      // v1.0.169: 腹筋種目の場合、回数/秒数切り替えボタンを追加
                      if (_isAbsExercise(set.exerciseName)) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    set.isTimeMode = false;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: !set.isTimeMode 
                                      ? const Color(0xFF4CAF50) 
                                      : Colors.white,
                                  foregroundColor: !set.isTimeMode 
                                      ? Colors.white 
                                      : const Color(0xFF4CAF50),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  side: BorderSide(
                                    color: const Color(0xFF4CAF50),
                                    width: !set.isTimeMode ? 2 : 1,
                                  ),
                                ),
                                child: Text(AppLocalizations.of(context)!.repsCount, style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    set.isTimeMode = true;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: set.isTimeMode 
                                      ? const Color(0xFF4CAF50) 
                                      : Colors.white,
                                  foregroundColor: set.isTimeMode 
                                      ? Colors.white 
                                      : const Color(0xFF4CAF50),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  side: BorderSide(
                                    color: const Color(0xFF4CAF50),
                                    width: set.isTimeMode ? 2 : 1,
                                  ),
                                ),
                                child: Text(AppLocalizations.of(context)!.seconds, style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                )
              // 有酸素運動の場合は「時間（分）」、それ以外は「重量（kg）」
              else
                Expanded(
                  child: TextFormField(
                    key: ValueKey('weight_${globalIndex}_${set.weight}'),
                    decoration: InputDecoration(
                      labelText: set.isCardio ? '時間 (分)' : '重量 (kg)', // 🔧 v1.0.226+242: Use stored flag
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
              
              // 有酸素運動の場合は距離ベースかレップスベースかで分ける、腹筋の場合は「秒数/回数」、それ以外は「回数」
              Expanded(
                child: TextFormField(
                  key: ValueKey('reps_${globalIndex}_${set.reps}'),
                  decoration: InputDecoration(
                    labelText: set.isCardio // 🔧 v1.0.226+242: Use stored flag
                        ? (ExerciseMasterData.cardioUsesDistance(set.exerciseName) ? '距離 (km)' : AppLocalizations.of(context)!.repsCount) // 🔧 v1.0.251: Distance vs Reps for cardio
                        : _isAbsExercise(set.exerciseName)
                            ? (set.isTimeMode ? AppLocalizations.of(context)!.seconds : AppLocalizations.of(context)!.repsCount)
                            : AppLocalizations.of(context)!.repsCount,
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
                label: Text(AppLocalizations.of(context)!.workout_9f784efd, style: TextStyle(fontSize: 12)),
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
                label: Text(AppLocalizations.of(context)!.limit, style: TextStyle(fontSize: 12)),
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
                  label: Text(set.isCompleted ? AppLocalizations.of(context)!.complete : AppLocalizations.of(context)!.workout_2bf8f78c),
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
    final isTimeMode = lastData['is_time_mode'] == true;  // ✅ v1.0.181: 秒数モード対応
    
    final date = lastData['date'] as DateTime?;
    final dateStr = date != null 
        ? '${date.month}/${date.day}'
        : AppLocalizations.of(context)!.unknown;
    
    // シンプルに前回の1セットのみ表示（前々回は表示しない）
    // ✅ v1.0.181: 秒数モードの場合は「秒」と表示
    return isTimeMode
        ? '前回 $dateStr: ${weight}kg × ${reps}秒'
        : '前回 $dateStr: ${weight}kg × ${reps}回';
  }
  
  // 🎯 Phase 1: トレーニング記録後のAI導線ポップアップ
  Future<void> _showPostWorkoutAIPrompt() async {
    if (!mounted) return;
    
    final prefs = await SharedPreferences.getInstance();
    final hasSeenPrompt = prefs.getBool('has_seen_post_workout_ai_prompt') ?? false;
    
    // 初回のみ表示（2回目以降は表示しない）
    if (hasSeenPrompt) return;
    
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アイコン
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology,
                size: 48,
                color: Colors.purple.shade600,
              ),
            ),
            const SizedBox(height: 16),
            
            // タイトル
            const Text(
              AppLocalizations.of(context)!.workout_0179c7df,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // 説明
            Text(
              AppLocalizations.of(context)!.workout_e8d8ddef,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool('has_seen_post_workout_ai_prompt', true);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context)!.later),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setBool('has_seen_post_workout_ai_prompt', true);
              if (mounted) {
                Navigator.pop(context); // ダイアログを閉じる
                Navigator.pushNamed(context, '/ai_coaching'); // AI画面へ遷移
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.workout_000aac76),
          ),
        ],
      ),
    );
  }
  
  // ⭐ ASO: レビュー依頼を確認して表示
  Future<void> _checkAndShowReviewRequest() async {
    if (!mounted) return;
    
    try {
      final reviewService = ReviewRequestService();
      
      // レビュー依頼を表示すべきかチェック
      if (await reviewService.shouldShowReviewRequest()) {
        // 少し遅延してから表示（UX改善）
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          await reviewService.showReviewRequestDialog(context);
        }
      }
    } catch (e) {
      print('❌ レビュー依頼チェックエラー: $e');
      // エラーが発生してもアプリは継続
    }
  }
  
  // 🏆 PR達成チェック & シェア提案
  Future<void> _checkPRAndOfferShare() async {
    if (!mounted) return;
    
    try {
      final shareService = EnhancedShareService();
      
      // 各セットの最高重量をチェック
      for (var set in _sets) {
        if (set.isCompleted && !set.hasAssist && !set.isBodyweightMode) {
          // 少し遅延してから表示（レビュー依頼の後）
          await Future.delayed(const Duration(milliseconds: 1000));
          
          if (mounted) {
            await shareService.checkAndOfferPRShare(
              context: context,
              exerciseName: set.exerciseName,
              newWeight: set.weight,
              reps: set.reps,
            );
            break; // 1つのPRだけ表示
          }
        }
      }
    } catch (e) {
      print('❌ PR達成チェックエラー: $e');
      // エラーが発生してもアプリは継続
    }
  }
}
