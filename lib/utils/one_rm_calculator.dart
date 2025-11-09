/// 1RM（1 Rep Maximum）計算ユーティリティ
/// 
/// Epley式を使用: 1RM = 重量 × (1 + 回数 / 30)
class OneRMCalculator {
  /// 1RMを計算（Epley式）
  /// 
  /// [weight] 使用重量（kg）
  /// [reps] 回数
  /// 
  /// Returns: 1RM（kg）
  static double calculate({
    required double weight,
    required int reps,
  }) {
    if (reps == 0) return 0.0;
    if (reps == 1) return weight;
    
    // Epley式: 1RM = 重量 × (1 + 回数 / 30)
    return weight * (1 + reps / 30);
  }
  
  /// セットごとの1RMを計算し、最大値を返す
  /// 
  /// [sets] セットリスト（各セットは weight と reps を持つ）
  /// 
  /// Returns: 最大1RM（kg）とそのセット番号
  static Map<String, dynamic> findMaxRM(List<Map<String, dynamic>> sets) {
    if (sets.isEmpty) {
      return {'maxRM': 0.0, 'setIndex': -1};
    }
    
    double maxRM = 0.0;
    int maxSetIndex = 0;
    
    for (int i = 0; i < sets.length; i++) {
      final set = sets[i];
      final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
      final reps = (set['reps'] as num?)?.toInt() ?? 0;
      
      final oneRM = calculate(weight: weight, reps: reps);
      
      if (oneRM > maxRM) {
        maxRM = oneRM;
        maxSetIndex = i;
      }
    }
    
    return {
      'maxRM': maxRM,
      'setIndex': maxSetIndex,
    };
  }
  
  /// 1RMを小数点1桁で文字列化
  static String formatRM(double rm) {
    return rm.toStringAsFixed(1);
  }
}
