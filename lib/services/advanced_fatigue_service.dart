import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Phase 2b + 2c: 高度な疲労管理システム
/// 
/// Phase 2b: Personal Factor Multipliers (PFM)
/// Phase 2c: ACWR (Acute:Chronic Workload Ratio) + EWMA
/// 
/// 学術的根拠:
/// - Foster et al. (2001): Session RPE
/// - Murray et al. (2016): EWMA for ACWR
/// - Windt & Gabbett (2017): ACWR and injury risk
/// - Hulin et al. (2016): Training load monitoring
class AdvancedFatigueService {
  static const String _userProfileKey = 'user_profile';
  static const String _trainingHistoryKey = 'training_load_history';
  static const String _acwrHistoryKey = 'acwr_history';
  
  // Phase 2c: EWMA計算用の減衰定数
  // 根拠: Murray et al. (2016)
  static const double _acuteDecayConstant = 0.2857; // 7日間 (λ = 2/(n+1), n=7)
  static const double _chronicDecayConstant = 0.0690; // 28日間 (λ = 2/(n+1), n=28)
  
  /// Phase 2b: ユーザープロファイルを保存
  Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userProfileKey, jsonEncode(profile.toJson()));
  }
  
  /// Phase 2b: ユーザープロファイルを取得
  Future<UserProfile> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(_userProfileKey);
    
    if (profileJson == null) {
      // デフォルトプロファイルを返す
      return UserProfile.defaultProfile();
    }
    
    try {
      return UserProfile.fromJson(jsonDecode(profileJson) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) print('❌ Error parsing user profile: $e');
      return UserProfile.defaultProfile();
    }
  }
  
  /// Phase 2b: Personal Factor Multiplier (PFM) 計算
  /// 
  /// 静的要因と動的要因を組み合わせて、個人の回復能力を補正
  /// 
  /// 戻り値: 0.5-1.5の範囲（1.0がベースライン）
  /// - 1.0より大きい = 疲労が高い（回復が遅い）
  /// - 1.0より小さい = 疲労が低い（回復が早い）
  double calculatePersonalFactorMultiplier(UserProfile profile) {
    double pfm = 1.0;
    
    // 静的要因1: 年齢係数
    // 根拠: 加齢による回復能力の低下
    if (profile.age < 25) {
      pfm *= 0.95; // 若年: -5%
    } else if (profile.age >= 40 && profile.age < 50) {
      pfm *= 1.05; // 中年: +5%
    } else if (profile.age >= 50) {
      pfm *= 1.10; // 高齢: +10%
    }
    
    // 静的要因2: トレーニング経験年数
    // 根拠: 経験者は神経系適応が進み、相対的疲労が低い
    if (profile.trainingExperienceYears < 1) {
      pfm *= 1.10; // 初心者: +10%
    } else if (profile.trainingExperienceYears >= 3 && profile.trainingExperienceYears < 5) {
      pfm *= 0.95; // 中級者: -5%
    } else if (profile.trainingExperienceYears >= 5) {
      pfm *= 0.90; // 上級者: -10%
    }
    
    // 動的要因1: 睡眠時間
    // 根拠: 睡眠不足は回復を阻害
    if (profile.sleepHoursLastNight < 6.0) {
      pfm *= 1.15; // 睡眠不足: +15%
    } else if (profile.sleepHoursLastNight >= 8.0) {
      pfm *= 0.95; // 十分な睡眠: -5%
    }
    
    // 動的要因2: タンパク質摂取量
    // 根拠: タンパク質は筋肉回復に必須
    // 目安: 体重1kgあたり1.6g以上が推奨
    final bodyWeightKg = 70.0; // 仮の体重（後で実体重を使用可能）
    final proteinPerKg = profile.dailyProteinIntakeGrams / bodyWeightKg;
    
    if (proteinPerKg < 1.2) {
      pfm *= 1.10; // 不足: +10%
    } else if (proteinPerKg >= 1.6) {
      pfm *= 0.95; // 十分: -5%
    }
    
    // 動的要因3: アルコール摂取
    // 根拠: アルコールは筋肉合成を阻害
    if (profile.alcoholUnitsLastDay > 0) {
      pfm *= (1.0 + (profile.alcoholUnitsLastDay * 0.05)); // 1単位あたり+5%
    }
    
    // PFMの範囲制限（0.7-1.3）
    return pfm.clamp(0.7, 1.3);
  }
  
  /// Phase 2c: トレーニング履歴を保存
  /// 
  /// 直近28日間のTraining Loadを保存
  Future<void> saveTrainingLoad(double trainingLoad, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 既存履歴を取得
    final historyJson = prefs.getString(_trainingHistoryKey);
    List<Map<String, dynamic>> history = [];
    
    if (historyJson != null) {
      history = List<Map<String, dynamic>>.from(jsonDecode(historyJson) as List);
    }
    
    // 新しいエントリを追加
    history.add({
      'training_load': trainingLoad,
      'date': date.toIso8601String(),
    });
    
    // 古いデータを削除（29日以上前のデータ）
    final cutoffDate = DateTime.now().subtract(const Duration(days: 29));
    history = history.where((entry) {
      final entryDate = DateTime.parse(entry['date'] as String);
      return entryDate.isAfter(cutoffDate);
    }).toList();
    
    // 保存
    await prefs.setString(_trainingHistoryKey, jsonEncode(history));
  }
  
  /// Phase 2c: トレーニング履歴を取得
  Future<List<Map<String, dynamic>>> getTrainingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_trainingHistoryKey);
    
    if (historyJson == null) {
      return [];
    }
    
    return List<Map<String, dynamic>>.from(jsonDecode(historyJson) as List);
  }
  
  /// Phase 2c: EWMA (Exponentially Weighted Moving Average) 計算
  /// 
  /// 根拠: Murray et al. (2016) - より最近のデータに高い重みを与える
  /// 
  /// [history]: トレーニング履歴
  /// [days]: 計算期間（7日間 or 28日間）
  /// 
  /// 戻り値: EWMA値（AU）
  double calculateEWMA(List<Map<String, dynamic>> history, int days) {
    if (history.isEmpty) return 0.0;
    
    // 減衰定数を選択
    final lambda = days == 7 ? _acuteDecayConstant : _chronicDecayConstant;
    
    // 日付でソート（古い順）
    final sortedHistory = List<Map<String, dynamic>>.from(history);
    sortedHistory.sort((a, b) {
      final dateA = DateTime.parse(a['date'] as String);
      final dateB = DateTime.parse(b['date'] as String);
      return dateA.compareTo(dateB);
    });
    
    // 指定期間のデータのみを使用
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final recentHistory = sortedHistory.where((entry) {
      final entryDate = DateTime.parse(entry['date'] as String);
      return entryDate.isAfter(cutoffDate);
    }).toList();
    
    if (recentHistory.isEmpty) return 0.0;
    
    // EWMAを計算
    double ewma = (recentHistory.first['training_load'] as num).toDouble();
    
    for (int i = 1; i < recentHistory.length; i++) {
      final currentLoad = (recentHistory[i]['training_load'] as num).toDouble();
      ewma = (lambda * currentLoad) + ((1 - lambda) * ewma);
    }
    
    return ewma;
  }
  
  /// Phase 2c: ACWR (Acute:Chronic Workload Ratio) 計算
  /// 
  /// ACWR = 急性負荷（7日間EWMA） / 慢性負荷（28日間EWMA）
  /// 
  /// 根拠: Windt & Gabbett (2017), Hulin et al. (2016)
  /// 
  /// 最適範囲: 0.8-1.3
  /// - 0.8未満: アンダートレーニング（パフォーマンス低下）
  /// - 0.8-1.3: スイートスポット（最適）
  /// - 1.3-1.5: 警戒ゾーン（怪我リスク増加）
  /// - 1.5超: 危険ゾーン（怪我リスク高）
  Future<Map<String, dynamic>> calculateACWR() async {
    final history = await getTrainingHistory();
    
    if (history.length < 7) {
      // データ不足
      return {
        'acwr': null,
        'acute_load': 0.0,
        'chronic_load': 0.0,
        'risk_level': 'insufficient_data',
        'risk_color': 'grey',
        'advice': AppLocalizations.of(context)!.general_f7f81187,
      };
    }
    
    // 急性負荷（7日間EWMA）
    final acuteLoad = calculateEWMA(history, 7);
    
    // 慢性負荷（28日間EWMA）
    final chronicLoad = calculateEWMA(history, 28);
    
    if (chronicLoad == 0.0) {
      return {
        'acwr': null,
        'acute_load': acuteLoad,
        'chronic_load': 0.0,
        'risk_level': 'insufficient_data',
        'risk_color': 'grey',
        'advice': AppLocalizations.of(context)!.general_7bbb802c,
      };
    }
    
    // ACWR計算
    final acwr = acuteLoad / chronicLoad;
    
    // リスクレベル判定
    String riskLevel;
    String riskColor;
    String advice;
    
    if (acwr < 0.8) {
      riskLevel = 'undertraining';
      riskColor = 'blue';
      advice = 'トレーニング負荷が低すぎます。\n徐々に負荷を上げることでパフォーマンス向上が期待できます。';
    } else if (acwr >= 0.8 && acwr <= 1.3) {
      riskLevel = 'optimal';
      riskColor = 'green';
      advice = '理想的なトレーニング負荷です！\n現在のペースを維持しましょう。怪我リスクは最小です。';
    } else if (acwr > 1.3 && acwr <= 1.5) {
      riskLevel = 'caution';
      riskColor = 'yellow';
      advice = '警戒ゾーンです。\n怪我のリスクがやや高まっています。回復を優先し、次回は負荷を少し下げましょう。';
    } else {
      riskLevel = 'danger';
      riskColor = 'red';
      advice = '危険ゾーンです！\n怪我のリスクが高い状態です。今日は完全休養を推奨します。';
    }
    
    return {
      'acwr': acwr,
      'acute_load': acuteLoad,
      'chronic_load': chronicLoad,
      'risk_level': riskLevel,
      'risk_color': riskColor,
      'advice': advice,
    };
  }
  
  /// Phase 2b+2c統合: PFM適用済みTL + ACWR分析
  /// 
  /// 最終的な疲労度評価を返す
  Future<Map<String, dynamic>> getComprehensiveFatigueAnalysis({
    required double baseTrainingLoad,
    required UserProfile profile,
  }) async {
    // Phase 2b: PFM適用
    final pfm = calculatePersonalFactorMultiplier(profile);
    final adjustedTrainingLoad = baseTrainingLoad * pfm;
    
    // トレーニング履歴に保存
    await saveTrainingLoad(adjustedTrainingLoad, DateTime.now());
    
    // Phase 2c: ACWR計算
    final acwrData = await calculateACWR();
    
    return {
      'base_training_load': baseTrainingLoad,
      'personal_factor_multiplier': pfm,
      'adjusted_training_load': adjustedTrainingLoad,
      'acwr_data': acwrData,
    };
  }
}
