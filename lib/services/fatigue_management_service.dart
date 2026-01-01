import 'package:shared_preferences/shared_preferences.dart';

/// 疲労管理システムサービス
/// 
/// Phase 2a: セッションRPEベースの科学的疲労度予測
/// 根拠: Foster et al. (2001) - sRPE method
class FatigueManagementService {
  static const String _fatigueManagementKey = 'fatigue_management_enabled';
  static const String _lastWorkoutDateKey = 'last_workout_date';
  static const String _lastSessionRPEKey = 'last_session_rpe';
  static const String _lastSessionDurationKey = 'last_session_duration_minutes';

  /// 疲労管理システムが有効かどうかを取得
  Future<bool> isFatigueManagementEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // デフォルトはOFF（ユーザーが明示的に有効化する必要がある）
    return prefs.getBool(_fatigueManagementKey) ?? false;
  }

  /// 疲労管理システムのON/OFF状態を設定
  Future<void> setFatigueManagementEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fatigueManagementKey, enabled);
  }

  /// 最後のトレーニング日を保存
  Future<void> saveLastWorkoutDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastWorkoutDateKey, date.toIso8601String());
  }

  /// 最後のトレーニング日を取得
  Future<DateTime?> getLastWorkoutDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastWorkoutDateKey);
    
    if (dateString != null) {
      return DateTime.parse(dateString);
    }
    return null;
  }

  /// 本日トレーニングを実施したかチェック
  Future<bool> hasWorkoutToday() async {
    final lastWorkout = await getLastWorkoutDate();
    
    if (lastWorkout == null) return false;
    
    final now = DateTime.now();
    return lastWorkout.year == now.year &&
           lastWorkout.month == now.month &&
           lastWorkout.day == now.day;
  }

  /// セッションRPEとトレーニング時間を保存
  Future<void> saveSessionData({
    required double sessionRPE,
    required int durationMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lastSessionRPEKey, sessionRPE);
    await prefs.setInt(_lastSessionDurationKey, durationMinutes);
  }

  /// 最後のセッションRPEを取得
  Future<double?> getLastSessionRPE() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_lastSessionRPEKey);
  }

  /// 最後のセッション時間（分）を取得
  Future<int?> getLastSessionDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSessionDurationKey);
  }

  /// Phase 2a: 科学的疲労度スコア計算
  /// 
  /// Training Load (TL) = Session RPE × Duration (min)
  /// 根拠: Foster et al. (2001), Haddad et al. (2017)
  /// 
  /// [sessionRPE]: セッション全体の自覚的運動強度（0-10）
  /// [durationMinutes]: トレーニング時間（分）
  /// [totalSets]: 総セット数（補助情報）
  /// [bodyParts]: 実施部位（補助情報）
  /// 
  /// 戻り値: 疲労度スコア（0-1000+ AU: Arbitrary Units）
  double calculateTrainingLoad({
    required double sessionRPE,
    required int durationMinutes,
    required int totalSets,
    required List<String> bodyParts,
  }) {
    // Step 1: 基礎負荷（TL = RPE × Duration）
    double baseLoad = sessionRPE * durationMinutes;
    
    // Step 2: 部位別の調整係数（大筋群は回復コストが高い）
    // 根拠: 脚・背中は中枢性疲労が大きい
    double bodyPartMultiplier = 1.0;
    if (bodyParts.contains(AppLocalizations.of(context)!.bodyPartLegs)) {
      bodyPartMultiplier += 0.15; // 脚: +15%
    }
    if (bodyParts.contains(AppLocalizations.of(context)!.bodyPartBack)) {
      bodyPartMultiplier += 0.10; // 背中: +10%
    }
    if (bodyParts.contains(AppLocalizations.of(context)!.bodyPartChest)) {
      bodyPartMultiplier += 0.05; // 胸: +5%
    }
    
    // Step 3: セット数密度補正（高セット数 = 高密度 = 高疲労）
    // RPEに既に反映されているが、極端な高セットは追加補正
    double setDensityMultiplier = 1.0;
    if (totalSets > 25) {
      setDensityMultiplier = 1.10; // 25セット超: +10%
    } else if (totalSets > 20) {
      setDensityMultiplier = 1.05; // 20セット超: +5%
    }
    
    // 最終負荷
    double adjustedLoad = baseLoad * bodyPartMultiplier * setDensityMultiplier;
    
    return adjustedLoad;
  }

  /// 疲労度レベル判定（Phase 2a簡易版）
  /// 
  /// TLスコアを5段階に分類
  /// ※ Phase 2c実装時にACWRベースに置き換え
  /// 
  /// 戻り値: {
  ///   'level': 1-5,
  ///   'label': AppLocalizations.of(context)!.general_91e882eb | AppLocalizations.of(context)!.general_ce061ec3 | AppLocalizations.of(context)!.general_da8ce224 | AppLocalizations.of(context)!.general_89a3d255,
  ///   'color': Color,
  ///   'recoveryHours': 回復時間（時間）,
  ///   'advice': アドバイステキスト
  /// }
  Map<String, dynamic> getFatigueLevel(double trainingLoad) {
    // 疲労度レベルの閾値（科学的根拠ベース）
    // RPE 7 × 60分 = 420 AU（中程度）を基準
    
    if (trainingLoad < 300) {
      // レベル1: 軽度
      return {
        'level': 1,
        'label': AppLocalizations.of(context)!.general_91e882eb,
        'color': 'green',
        'recoveryHours': 24,
        'advice': '良好なトレーニングでした！\n軽いストレッチと十分な水分補給をしましょう。',
      };
    } else if (trainingLoad < 500) {
      // レベル2: 中程度（最適）
      return {
        'level': 2,
        'label': AppLocalizations.of(context)!.general_ce061ec3,
        'color': 'blue',
        'recoveryHours': 36,
        'advice': '適度な負荷のトレーニングでした。\n7-8時間の睡眠とタンパク質補給（体重1kgあたり1.6g以上）を心がけましょう。',
      };
    } else if (trainingLoad < 700) {
      // レベル3: 高め（警戒）
      return {
        'level': 3,
        'label': AppLocalizations.of(context)!.general_da8ce224,
        'color': 'orange',
        'recoveryHours': 48,
        'advice': '高強度のトレーニングでした。\n十分な休息と栄養補給が必要です。無理せず回復を優先しましょう。',
      };
    } else {
      // レベル4: 極めて高い（危険）
      return {
        'level': 4,
        'label': AppLocalizations.of(context)!.general_89a3d255,
        'color': 'red',
        'recoveryHours': 72,
        'advice': '非常に高強度のトレーニングでした。\n今日は完全休養を推奨します。睡眠8時間以上、高タンパク質食、ストレッチを重視してください。',
      };
    }
  }
}
