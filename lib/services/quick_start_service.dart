import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_log.dart';
import '../models/exercise.dart';

/// クイックスタートサービス（v1.02新機能）
/// 
/// 初心者向けのサンプルトレーニングを提供
class QuickStartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// クイックスタートテンプレート（初心者向け）
  static final Map<String, List<Map<String, dynamic>>> templates = {
    AppLocalizations.of(context)!.general_3fb0f43a: [
      {
        'name': AppLocalizations.of(context)!.exerciseBenchPress,
        'sets': 3,
        'reps': 10,
        'weight': 40.0,
        'notes': AppLocalizations.of(context)!.general_efd91eb0,
      },
      {
        'name': AppLocalizations.of(context)!.workout_e85fb0a4,
        'sets': 3,
        'reps': 12,
        'weight': 10.0,
        'notes': AppLocalizations.of(context)!.general_d85846a8,
      },
      {
        'name': AppLocalizations.of(context)!.general_36594338,
        'sets': 3,
        'reps': 15,
        'weight': 0.0,
        'notes': AppLocalizations.of(context)!.general_fb7fa23b,
      },
    ],
    AppLocalizations.of(context)!.general_b85cad35: [
      {
        'name': AppLocalizations.of(context)!.exerciseDeadlift,
        'sets': 3,
        'reps': 8,
        'weight': 50.0,
        'notes': AppLocalizations.of(context)!.general_49fb9e50,
      },
      {
        'name': AppLocalizations.of(context)!.exerciseLatPulldown,
        'sets': 3,
        'reps': 12,
        'weight': 30.0,
        'notes': AppLocalizations.of(context)!.general_2d57da37,
      },
      {
        'name': AppLocalizations.of(context)!.general_9ba1c450,
        'sets': 3,
        'reps': 10,
        'weight': 12.0,
        'notes': AppLocalizations.of(context)!.general_fc06fc9d,
      },
    ],
    AppLocalizations.of(context)!.general_5c8057de: [
      {
        'name': AppLocalizations.of(context)!.exerciseSquat,
        'sets': 3,
        'reps': 10,
        'weight': 40.0,
        'notes': AppLocalizations.of(context)!.general_5d04b53b,
      },
      {
        'name': AppLocalizations.of(context)!.exerciseLegPress,
        'sets': 3,
        'reps': 12,
        'weight': 60.0,
        'notes': AppLocalizations.of(context)!.general_73bcde28,
      },
      {
        'name': AppLocalizations.of(context)!.exerciseLegCurl,
        'sets': 3,
        'reps': 15,
        'weight': 20.0,
        'notes': AppLocalizations.of(context)!.general_515717e8,
      },
    ],
    AppLocalizations.of(context)!.general_e999c1ce: [
      {
        'name': AppLocalizations.of(context)!.exerciseSquat,
        'sets': 3,
        'reps': 10,
        'weight': 40.0,
        'notes': AppLocalizations.of(context)!.general_b86d4dc6,
      },
      {
        'name': AppLocalizations.of(context)!.exerciseBenchPress,
        'sets': 3,
        'reps': 10,
        'weight': 40.0,
        'notes': AppLocalizations.of(context)!.general_906766df,
      },
      {
        'name': AppLocalizations.of(context)!.exerciseDeadlift,
        'sets': 3,
        'reps': 8,
        'weight': 50.0,
        'notes': AppLocalizations.of(context)!.general_ddf9f028,
      },
    ],
  };

  /// テンプレート一覧を取得
  List<String> getTemplateNames() {
    return templates.keys.toList();
  }

  /// テンプレートからサンプルトレーニングを作成
  Future<String> createSampleWorkout(String templateName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final template = templates[templateName];
    if (template == null) throw Exception('Template not found');

    try {
      // ワークアウトログを作成
      final workoutLogRef = _firestore.collection('workout_logs').doc();
      
      final exercises = template.map((exercise) {
        return Exercise(
          name: exercise['name'] as String,
          sets: List.generate(
            exercise['sets'] as int,
            (index) => ExerciseSet(
              weight: exercise['weight'] as double,
              reps: exercise['reps'] as int,
              setType: 'normal',
              rpe: 7.0, // サンプルなので中程度の強度
            ),
          ),
          notes: exercise['notes'] as String?,
        );
      }).toList();

      final workoutLog = WorkoutLog(
        id: workoutLogRef.id,
        userId: user.uid,
        date: DateTime.now(),
        exercises: exercises,
        duration: Duration(minutes: 45), // サンプル時間
        totalVolume: _calculateTotalVolume(exercises),
        notes: '🚀 クイックスタート: $templateName',
        gymId: null,
        gymName: null,
      );

      await workoutLogRef.set(workoutLog.toFirestore());

      print('✅ クイックスタート作成成功: $templateName');
      return workoutLogRef.id;
    } catch (e) {
      print('❌ クイックスタート作成エラー: $e');
      throw Exception('Failed to create sample workout: $e');
    }
  }

  /// 総挙上重量を計算
  double _calculateTotalVolume(List<Exercise> exercises) {
    double total = 0.0;
    for (var exercise in exercises) {
      for (var set in exercise.sets) {
        total += set.weight * set.reps;
      }
    }
    return total;
  }

  /// クイックスタートを使用済みにする
  Future<void> markAsUsed() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'quickStartUsed': true,
      'quickStartUsedAt': FieldValue.serverTimestamp(),
    });
  }

  /// クイックスタート使用済みかチェック
  Future<bool> hasUsedQuickStart() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    return data?['quickStartUsed'] as bool? ?? false;
  }
}
