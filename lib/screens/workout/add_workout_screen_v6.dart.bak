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
  // テンプレートからのデータを受け取る
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
  };

  @override
  void initState() {
    super.initState();
    _loadLastWorkoutData();
    _applyTemplateDataIfProvided();
  }
  
  // テンプレートデータを適用
  void _applyTemplateDataIfProvided() {
    if (widget.templateData != null) {
      print('📋 テンプレートデータを適用: ${widget.templateData}');
      
      // 部位を設定
      final muscleGroup = widget.templateData!['muscle_group'] as String?;
      if (muscleGroup != null) {
        setState(() {
          _selectedMuscleGroup = muscleGroup;
        });
      }
      
      // セットデータを適用
      final sets = widget.templateData!['sets'] as List<dynamic>?;
      if (sets != null) {
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
        print('✅ ${_sets.length}セットを適用しました');
      }
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _memoController.dispose();
    super.dispose();
  }

  // 前回のワークアウトデータを読み込み
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
