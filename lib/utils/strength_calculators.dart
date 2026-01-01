import 'dart:math';

/// 筋力計算ユーティリティ
/// 
/// リアルタイム前回パフォーマンス比較、1RM計算、プレート計算などの
/// トレーニング関連の計算機能を提供します。
class StrengthCalculators {
  // ========== 1RM (1 Rep Max) 計算 ==========

  /// 1RM (最大挙上重量) を計算 (Epley式)
  /// 
  /// [weight]: 挙上重量 (kg)
  /// [reps]: 反復回数
  /// 
  /// 返り値: 推定1RM (kg)
  static double calculate1RM(double weight, int reps) {
    if (reps == 1) return weight;
    if (reps <= 0) return 0;
    
    // Epley式: 1RM = weight × (1 + reps / 30)
    return weight * (1 + reps / 30);
  }

  /// ターゲット回数での推奨重量を計算
  /// 
  /// [oneRM]: 1RM (最大挙上重量)
  /// [targetReps]: ターゲット回数
  /// 
  /// 返り値: 推奨重量 (kg)
  static double calculateWeight(double oneRM, int targetReps) {
    if (targetReps == 1) return oneRM;
    if (targetReps <= 0) return 0;
    
    // Epley式の逆算: weight = 1RM / (1 + targetReps / 30)
    return oneRM / (1 + targetReps / 30);
  }

  // ========== 前回パフォーマンス比較 ==========

  /// 前回比のパーセンテージ変化を計算 (1RM換算ベース)
  /// 
  /// [currentWeight]: 現在の重量
  /// [currentReps]: 現在の回数
  /// [previousWeight]: 前回の重量
  /// [previousReps]: 前回の回数
  /// 
  /// 返り値: パーセンテージ変化 (-100.0 ~ +100.0)
  static double calculatePercentageChange(
    double currentWeight,
    int currentReps,
    double previousWeight,
    int previousReps,
  ) {
    // 1RM換算で比較
    final currentEstimated1RM = calculate1RM(currentWeight, currentReps);
    final previousEstimated1RM = calculate1RM(previousWeight, previousReps);

    if (previousEstimated1RM == 0) return 0;

    final change = ((currentEstimated1RM - previousEstimated1RM) / previousEstimated1RM) * 100;
    return change;
  }

  /// ボリューム (総負荷量) を計算
  /// 
  /// [weight]: 重量 (kg)
  /// [reps]: 回数
  /// 
  /// 返り値: ボリューム (kg)
  static double calculateVolume(double weight, int reps) {
    return weight * reps;
  }

  /// セットのボリューム変化率を計算
  /// 
  /// [currentWeight]: 現在の重量
  /// [currentReps]: 現在の回数
  /// [previousWeight]: 前回の重量
  /// [previousReps]: 前回の回数
  /// 
  /// 返り値: ボリューム変化率 (%)
  static double calculateVolumeChange(
    double currentWeight,
    int currentReps,
    double previousWeight,
    int previousReps,
  ) {
    final currentVolume = calculateVolume(currentWeight, currentReps);
    final previousVolume = calculateVolume(previousWeight, previousReps);

    if (previousVolume == 0) return 0;

    return ((currentVolume - previousVolume) / previousVolume) * 100;
  }

  // ========== プレート計算 ==========

  /// バーベルのプレート組み合わせを計算
  /// 
  /// [targetWeight]: 目標重量 (kg)
  /// [barWeight]: バーの重量 (kg、デフォルト: 20kg)
  /// 
  /// 返り値: プレート重量 → 枚数のマップ (片側)
  static Map<double, int> calculatePlates(double targetWeight, {double barWeight = 20.0}) {
    // 片側のプレート重量を計算
    double weightPerSide = (targetWeight - barWeight) / 2;

    if (weightPerSide <= 0) {
      return {};
    }

    Map<double, int> plates = {};
    
    // 利用可能なプレート (kg、降順)
    List<double> availablePlates = [25, 20, 15, 10, 5, 2.5, 1.25, 1.0, 0.5, 0.25];

    for (double plate in availablePlates) {
      int count = (weightPerSide / plate).floor();
      if (count > 0) {
        plates[plate] = count;
        weightPerSide -= plate * count;
      }
    }

    return plates;
  }

  /// プレート組み合わせを人間が読みやすい文字列に変換
  /// 
  /// [plates]: calculatePlates()の返り値
  /// 
  /// 返り値: "25kg×1, 2.5kg×1" のような文字列
  static String formatPlates(Map<double, int> plates) {
    if (plates.isEmpty) return AppLocalizations.of(context)!.general_b8085933;

    List<String> parts = [];
    plates.forEach((weight, count) {
      parts.add('${weight}kg×$count');
    });

    return parts.join(', ');
  }

  /// プレート計算結果の総重量を検証
  /// 
  /// [plates]: calculatePlates()の返り値
  /// [barWeight]: バーの重量
  /// 
  /// 返り値: 実際の総重量 (kg)
  static double getTotalWeightFromPlates(Map<double, int> plates, {double barWeight = 20.0}) {
    double totalPlateWeight = 0;
    plates.forEach((weight, count) {
      totalPlateWeight += weight * count;
    });

    return barWeight + (totalPlateWeight * 2); // 両側
  }

  // ========== Wilks係数計算 (Strength Score用) ==========

  /// Wilks係数を計算 (男性)
  /// 
  /// [bodyWeight]: 体重 (kg)
  /// 
  /// 返り値: Wilks係数
  static double calculateWilksCoefficientMale(double bodyWeight) {
    const a = -216.0475144;
    const b = 16.2606339;
    const c = -0.002388645;
    const d = -0.00113732;
    const e = 7.01863E-06;
    const f = -1.291E-08;

    final denom = a +
        (b * bodyWeight) +
        (c * pow(bodyWeight, 2)) +
        (d * pow(bodyWeight, 3)) +
        (e * pow(bodyWeight, 4)) +
        (f * pow(bodyWeight, 5));

    return 500 / denom;
  }

  /// Wilks係数を計算 (女性)
  /// 
  /// [bodyWeight]: 体重 (kg)
  /// 
  /// 返り値: Wilks係数
  static double calculateWilksCoefficientFemale(double bodyWeight) {
    const a = 594.31747775582;
    const b = -27.23842536447;
    const c = 0.82112226871;
    const d = -0.00930733913;
    const e = 4.731582E-05;
    const f = -9.054E-08;

    final denom = a +
        (b * bodyWeight) +
        (c * pow(bodyWeight, 2)) +
        (d * pow(bodyWeight, 3)) +
        (e * pow(bodyWeight, 4)) +
        (f * pow(bodyWeight, 5));

    return 500 / denom;
  }

  /// 年齢係数を計算
  /// 
  /// [age]: 年齢
  /// 
  /// 返り値: 年齢係数 (1.0を基準)
  static double calculateAgeCoefficient(int age) {
    if (age < 23) {
      // 若年者の補正
      return 1.0 + (23 - age) * 0.01;
    } else if (age <= 40) {
      // 最盛期
      return 1.0;
    } else {
      // 40歳以上の補正
      return 1.0 - (age - 40) * 0.01;
    }
  }
}
