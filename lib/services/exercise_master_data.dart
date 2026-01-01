/// 種目マスターデータ
/// 種目名から部位を逆引きするための共通データ
/// 
/// NOTE: このファイルは英語キーを使用しています（ローカライゼーション削除のため）
/// 実際の表示テキストはAppLocalizationsを通じてローカライズされます
class ExerciseMasterData {
  // 🔧 v1.0.317: ハードコードされた英語キーを使用（ARBキー削除のため）
  // これらのキーは内部でのマッピングにのみ使用され、UIには表示されません
  static const Map<String, List<String>> muscleGroupExercises = {
    'Chest': ['Bench Press', 'Dumbbell Press', 'Incline Press', 'Decline Press', 'Cable Fly', 'Dips', 'Chest Fly'],
    'Legs': ['Squat', 'Leg Press', 'Leg Extension', 'Leg Curl', 'Lunge', 'Calf Raise', 'Romanian Deadlift'],
    'Back': ['Deadlift', 'Lat Pulldown', 'Pull Up', 'Chin Up', 'Bent Over Row', 'Seated Row', 'T-Bar Row'],
    'Shoulders': ['Shoulder Press', 'Side Raise', 'Front Raise', 'Rear Delt Fly', 'Upright Row', 'Arnold Press'],
    'Biceps': ['Barbell Curl', 'Dumbbell Curl', 'Hammer Curl', 'Preacher Curl', 'Cable Curl', 'Concentration Curl'],
    'Triceps': ['Tricep Extension', 'Skull Crusher', 'Dips', 'Kickback', 'Close Grip Bench', 'Overhead Extension'],
    'Abs': ['Crunch', 'Leg Raise', 'Hanging Leg Raise', 'Plank', 'Side Plank', 'Ab Roller', 'Cable Crunch', 'Bicycle Crunch'],
    'Cardio': ['Running', 'Cycling', 'Swimming', 'Rowing', 'Elliptical', 'Aerobic Bike', 'Jump Rope', 'Burpees'],
  };

  /// 種目名から部位を推定
  /// 
  /// [exerciseName] 種目名
  /// Returns: 部位名、見つからない場合は 'Other'
  static String getBodyPartByName(String exerciseName) {
    // スペースを除去して正規化
    final normalizedName = exerciseName.trim().toLowerCase().replaceAll(' ', '');
    
    for (final entry in muscleGroupExercises.entries) {
      // マップ内の種目も正規化して比較
      if (entry.value.any((e) => 
        e.toLowerCase().replaceAll(' ', '') == normalizedName || 
        exerciseName.toLowerCase().contains(e.toLowerCase()))) {
        return entry.key;
      }
    }
    return 'Other';
  }

  /// 有酸素運動かどうかを判定
  static bool isCardioExercise(String exerciseName) {
    final normalizedName = exerciseName.trim().toLowerCase().replaceAll(' ', '');
    final cardioList = muscleGroupExercises['Cardio'] ?? [];
    
    return cardioList.any((e) => 
      e.toLowerCase().replaceAll(' ', '') == normalizedName || 
      exerciseName.toLowerCase().contains(e.toLowerCase()));
  }

  /// 腹筋種目かどうかを判定
  static bool isAbsExercise(String exerciseName) {
    final normalizedName = exerciseName.trim().toLowerCase().replaceAll(' ', '');
    final absList = muscleGroupExercises['Abs'] ?? [];
    
    return absList.any((e) => 
      e.toLowerCase().replaceAll(' ', '') == normalizedName || 
      exerciseName.toLowerCase().contains(e.toLowerCase()));
  }

  /// 懸垂系種目かどうかを判定
  static bool isPullUpExercise(String exerciseName) {
    final pullUpVariations = ['Pull Up', 'Chin Up', 'Neutral Grip Pull Up', 'Wide Grip Pull Up'];
    return pullUpVariations.any((variation) => 
      exerciseName.toLowerCase().contains(variation.toLowerCase()));
  }

  /// 有酸素運動が距離を使うかどうかを判定
  /// 
  /// 距離を使う有酸素: ランニング、ジョギング、サイクリング、ウォーキング、水泳など
  /// 回数を使う有酸素: バーピー、マウンテンクライマー、バトルロープなど
  /// 
  /// [exerciseName] 種目名
  /// Returns: 距離を使う場合true、回数を使う場合false
  static bool cardioUsesDistance(String exerciseName) {
    final normalizedName = exerciseName.trim().toLowerCase().replaceAll(' ', '');
    
    // 距離を使う有酸素運動
    final distanceExercises = [
      'running',
      'jogging',
      'cycling',
      'walking',
      'swimming',
      'rowing',
      'elliptical',
      'aerobic bike',
      'bike',
      'treadmill',
    ];
    
    return distanceExercises.any((e) => 
      e.replaceAll(' ', '') == normalizedName || 
      exerciseName.toLowerCase().contains(e));
  }
}
