/// 📊 科学的根拠データベース
/// 
/// 40本以上の査読付き論文に基づく科学的根拠を構造化し、
/// AI予測・分析機能に活用するためのデータベース
library;

/// 科学的根拠データベースクラス
class ScientificDatabase {
  /// システムプロンプト用の完全な科学的根拠データベース
  static String getSystemPrompt() {
    return '''
あなたは40本以上の査読付き論文に基づく科学的トレーニングアドバイザーです。
すべての回答は以下の科学的根拠データベースに基づいて提供してください。

【科学的根拠データベース】

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
テーマ1：筋力向上率の基準値
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

■ 初心者（0-6ヶ月）
・4ヶ月で約30%の筋力向上（月次約7.5%の複利成長）
・根拠：ACSM 2009 Position Stand on Progression Models
・女性の上半身：男性より20%高い成長率（Roberts et al. 2020, ES=-0.60）
・負荷増加：週2%推奨（ACSM 2-10%ルール）

■ 中級者（6-24ヶ月）
・4ヶ月で約15%の筋力向上（月次約3.5%の複利成長）
・ピリオダイゼーション導入が効果的
・ボリューム増加が成長の鍵

■ 上級者（24ヶ月以上）
・4ヶ月で約5%の筋力向上（月次約1.2%の複利成長）
・DUP（Daily Undulating Periodization）が効果的（Williams 2017, ES=0.68）
・高度なテクニック（クラスターセット、ドロップセット）必須

■ 重要な発見
・「ノンレスポンダー」は存在しない（Pickering & Kiely 2019）
・停滞 = プログラムのミスマッチ（プログラム変更で全員が反応）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
テーマ2：最適トレーニング頻度
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

■ 決定的研究：Grgic et al. 2018（メタ分析、n=25研究）

【重要】「頻度」の定義
・トレーニング頻度 = **同一部位に対する週あたりのトレーニング回数**
・例：「週3回」= 大胸筋を月曜・水曜・金曜にトレーニング
・注意：ジムに通う総回数ではなく、**特定の部位をトレーニングする回数**

結論：**ボリュームが王様、頻度は手段**

■ ボリューム統制条件（週トータルセット数同じ）
・有意差なし（p=0.421）
・週2回（1回6セット）でも週6回（1回2セット）でも結果は同じ

■ ボリューム非統制条件（高頻度 = 高ボリューム）
・同一部位を週1回：ES=0.74
・同一部位を週2回：ES=0.88
・同一部位を週3回：ES=1.03
・同一部位を週4回以上：ES=1.08

■ 部位別効果
・上半身：高頻度が有利（p=0.004）
・下半身：頻度差小（p=0.16）

■ 実用的推奨（同一部位のトレーニング回数）
・初心者：週2回（回復時間確保）
・中級者：週3回（ボリューム増加）
・上級者：週4-6回（高ボリューム達成手段）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
テーマ3：プラトー期の定義と対策
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

■ プラトー期の定義
・3-4週間の成長停滞
・同一重量・回数が連続
・根拠：Kraemer & Ratamess 2004

■ 対策A：高度なテクニック（Krzysztofik et al. 2019）
・ドロップセット：ES=0.69
・クラスターセット：力発揮維持
・レストポーズ：ボリューム増加
・適用時期：4週間停滞後

■ 対策B：ディロード（Bell et al. 2023）
・ボリューム30-50%削減
・強度は維持（重量減らさない）
・期間：1-2週間
・効果：スーパーコンペンセーション

■ 対策C：ピリオダイゼーション変更
・リニア型 → DUP型
・ボリューム重視 → 強度重視
・種目変更（角度・器具）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
テーマ4：推奨トレーニングボリューム
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

■ 決定的研究：Schoenfeld et al. 2017（メタ分析）

基本法則：**セット追加ごとに+0.37%の成長**

■ レベル別推奨ボリューム（週あたり/部位）

初心者：10-12セット/週
・根拠：Baz-Valle et al. 2022
・フォーム習得優先

中級者：12-16セット/週
・上半身：14-18セット推奨
・ボリューム増加で成長加速

上級者：16-20セット/週
・上腕三頭筋：最大24セットまで効果あり（例外的）
・20セット超：収穫逓減（diminishing returns）

■ 重要な発見
・最低4セット/週は必要（維持レベル）
・最大効率点：15-18セット/週
・20セット超：疲労 > 成長

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
テーマ5：最適休息日数
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

■ 筋タンパク質合成（MPS）の科学
・MPS上昇期間：48時間（Davies et al. 2024）
・トレーニング刺激後24時間でピーク
・48時間で正常値に戻る

■ 部位別推奨休息

大筋群（胸・背中・脚）：48-72時間
・筋損傷が大きい、回復に時間

小筋群（肩・腕・腹筋）：24-48時間
・筋損傷が小さい、回復が早い

■ レベル別考慮
・初心者：+12-24時間（神経系適応中）
・上級者：標準値（効率的回復能力）

■ 実用的推奨
・同一部位：最低48時間空ける
・高頻度トレーニング：部位分割必須
・全身トレーニング：48-72時間空ける

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
テーマ6：推奨トレーニング強度
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

■ 筋力向上の閾値
・**>60% 1RM 必須**（Schoenfeld et al. 2017）
・60%未満：筋力向上効果小

■ 筋肥大の柔軟性
・**あらゆる強度で筋肥大可能**
・条件：限界近くまで追い込む（near-failure）
・30% 1RM でも効果あり（疲労まで）

■ 限界トレーニングの効果（Grgic et al. 2022, n=15研究）
・全体効果：ES=0.15（小さいが有意）
・**上級者ほど効果大**
・初心者：必ずしも必要なし

■ RIR（Reps In Reserve）の活用
・初心者：RIR 3-4（余裕残す）
・中級者：RIR 1-2（限界近く）
・上級者：RIR 0-1（限界まで）

■ 実用的推奨
・筋力目標：70-85% 1RM、3-6回
・筋肥大目標：60-80% 1RM、8-12回
・筋持久力目標：50-60% 1RM、15-20回

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
テーマ7：年齢・性別・遺伝要因
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

■ 年齢の影響（Peterson et al. 2010, メタ分析）
・**50歳以上でも+29%のレッグプレス向上**
・高齢者：強度より頻度・ボリューム重視
・回復時間：+24時間考慮

■ 性別の影響（Roberts et al. 2020, 決定的メタ分析）
・**女性は男性より上半身の相対的筋力向上率が高い**
・効果量：ES=-0.60（女性有利、p=0.002）
・下半身：性差なし（p=0.85）
・重要：絶対値でなく**相対的向上率**

■ 遺伝的要因（Pickering & Kiely 2019）
・「ノンレスポンダー」は存在しない
・プログラムとのミスマッチが原因
・個人差：3-10倍（Hubal et al. 2005）
・対策：プログラム変更で全員が反応

■ 実用的推奨
・年齢・性別問わず**全員が成長可能**
・女性：上半身トレーニングを重視
・高齢者：回復時間を長めに設定
・停滞時：プログラム変更（遺伝のせいにしない）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【回答時の必須ルール】
1. すべての推奨に科学的根拠を明記（著者名・年・効果量）
2. 数値は具体的に（例：「週2-3回」ではなく「週3回（Grgic 2018, ES=1.03）」）
3. ユーザーのレベル（初心者/中級者/上級者）に応じた推奨
4. 性別・年齢を考慮した個別化
5. プラトー期は4週間停滞で検出、対策を提案
6. **頻度は必ず「同一部位を週X回」と明記すること**（誤解を防ぐため）
''';
  }

  /// 筋力向上率の計算（月ごと）
  /// 
  /// 🔧 v1.0.226+244: Conservative growth rates based on academic report
  /// レポート分析: 週次成長率をベースに、より保守的な月次レートを算出
  /// - Beginner: Weekly 1.5%-2.5% → Monthly ~5% (conservative)
  /// - Intermediate: Weekly 0.4%-0.8% → Monthly ~2%
  /// - Advanced: Weekly 0.15%-0.25% → Monthly ~0.8%
  static double getMonthlyGrowthRate(String level) {
    switch (level) {
      case AppLocalizations.of(context)!.levelBeginner:
        // 🔧 Conservative: 週1.5-2.5% → 月約5%（保守的推定）
        // (1.05)^4 = 1.215 ≈ +21.5% over 4 months
        // 根拠: レポートの週次下限値 + 安全マージン
        return 0.05; // 月+5%（旧: 7.5%）
      case AppLocalizations.of(context)!.levelIntermediate:
        // 🔧 Conservative: 週0.4-0.8% → 月約2%
        // (1.02)^4 = 1.082 ≈ +8.2% over 4 months
        return 0.02; // 月+2%（旧: 3.5%）
      case AppLocalizations.of(context)!.levelAdvanced:
        // 🔧 Conservative: 週0.15-0.25% → 月約0.8%
        // (1.008)^4 = 1.032 ≈ +3.2% over 4 months
        return 0.008; // 月+0.8%（旧: 1.2%）
      default:
        return 0.05; // デフォルトは初心者
    }
  }

  /// 週ごとの筋力向上率（女性の上半身特化）
  /// 
  /// 🔧 v1.0.226+244: More conservative weekly rates based on report
  static double getWeeklyGrowthRate(String level, String gender, String bodyPart) {
    // レポートベースの週次成長率（Table 3より）
    double baseWeeklyRate;
    switch (level) {
      case AppLocalizations.of(context)!.levelBeginner:
        baseWeeklyRate = gender == AppLocalizations.of(context)!.genderFemale ? 0.020 : 0.015; // 2.0% vs 1.5%
        break;
      case AppLocalizations.of(context)!.levelIntermediate:
        baseWeeklyRate = gender == AppLocalizations.of(context)!.genderFemale ? 0.005 : 0.004; // 0.5% vs 0.4%
        break;
      case AppLocalizations.of(context)!.levelAdvanced:
        baseWeeklyRate = 0.0015; // 0.15%（性差なし）
        break;
      default:
        baseWeeklyRate = 0.015;
    }
    
    final monthlyRate = getMonthlyGrowthRate(level);
    
    // 上半身部位の判定（胸、腕、肩、三角筋）
    final isUpperBody = bodyPart.contains(AppLocalizations.of(context)!.bodyPartChest) || 
                        bodyPart.contains(AppLocalizations.of(context)!.bodyPartArms) || 
                        bodyPart.contains(AppLocalizations.of(context)!.bodyPartShoulders) || 
                        bodyPart.contains(AppLocalizations.of(context)!.workout_da6d5d22);
    
    if (gender == AppLocalizations.of(context)!.genderFemale && isUpperBody && level == AppLocalizations.of(context)!.levelBeginner) {
      // 🔧 v1.0.226+244: 女性の上半身初心者のみ1.2倍ボーナス（Roberts 2020）
      // レポート Section 3.2: 女性・初心者・上半身の特異的補正
      return baseWeeklyRate * 1.2;
    }

    // 通常はベース週次レートをそのまま使用
    return baseWeeklyRate;
  }

  /// 推奨トレーニングボリューム（週あたりセット数）
  static Map<String, int> getRecommendedVolume(String level) {
    switch (level) {
      case AppLocalizations.of(context)!.levelBeginner:
        return {'min': 10, 'max': 12, 'optimal': 11};
      case AppLocalizations.of(context)!.levelIntermediate:
        return {'min': 12, 'max': 16, 'optimal': 14};
      case AppLocalizations.of(context)!.levelAdvanced:
        return {'min': 16, 'max': 20, 'optimal': 18};
      default:
        return {'min': 10, 'max': 12, 'optimal': 11};
    }
  }

  /// 推奨トレーニング頻度（週あたり回数）
  static Map<String, dynamic> getRecommendedFrequency(String level) {
    switch (level) {
      case AppLocalizations.of(context)!.levelBeginner:
        return {
          'frequency': 2,
          'effectSize': 0.88,
          'reason': '回復時間確保（Grgic 2018）'
        };
      case AppLocalizations.of(context)!.levelIntermediate:
        return {
          'frequency': 3,
          'effectSize': 1.03,
          'reason': 'ボリューム増加（Grgic 2018）'
        };
      case AppLocalizations.of(context)!.levelAdvanced:
        return {
          'frequency': 5,
          'effectSize': 1.08,
          'reason': '高ボリューム達成（Grgic 2018）'
        };
      default:
        return {
          'frequency': 2,
          'effectSize': 0.88,
          'reason': '回復時間確保（Grgic 2018）'
        };
    }
  }

  /// 推奨休息日数
  static int getRecommendedRestDays(String level, String bodyPart) {
    // 大筋群か小筋群かを判定
    final isLargeMuscle = bodyPart.contains(AppLocalizations.of(context)!.bodyPartChest) ||
        bodyPart.contains(AppLocalizations.of(context)!.bodyPartBack) ||
        bodyPart.contains(AppLocalizations.of(context)!.bodyPartLegs) ||
        bodyPart.contains(AppLocalizations.of(context)!.workout_10073d2e);

    if (isLargeMuscle) {
      // 大筋群：48-72時間
      return level == AppLocalizations.of(context)!.levelBeginner ? 3 : 2;
    } else {
      // 小筋群：24-48時間
      return level == AppLocalizations.of(context)!.levelBeginner ? 2 : 1;
    }
  }

  /// プラトー検出（4週間停滞）
  static bool detectPlateauFromHistory(List<Map<String, dynamic>> history) {
    if (history.length < 4) return false;

    // 直近4週間のデータを取得
    final recentFour = history.take(4).toList();

    // すべての重量が同じかチェック
    final firstWeight = recentFour[0]['weight'];
    return recentFour.every((record) => record['weight'] == firstWeight);
  }

  /// プラトー対策の提案
  static List<String> getPlateauSolutions(String level) {
    if (level == AppLocalizations.of(context)!.levelBeginner || level == AppLocalizations.of(context)!.levelIntermediate) {
      return [
        'ディロード週を実施（ボリューム30-50%削減、強度維持）',
        AppLocalizations.of(context)!.general_ffd1690a,
        'トレーニング頻度を週+1回増やす',
      ];
    } else {
      // 上級者向け
      return [
        'ドロップセットを導入（Krzysztofik 2019, ES=0.69）',
        AppLocalizations.of(context)!.general_e49688cb,
        'DUP（Daily Undulating Periodization）に変更（Williams 2017, ES=0.68）',
        'ディロード週を実施（ボリューム30-50%削減）',
      ];
    }
  }

  /// 信頼区間の計算（個人差を考慮）
  static Map<String, double> calculateConfidenceInterval(
    double predictedValue,
    String level,
  ) {
    // Hubal 2005: 個人差は3-10倍
    // 保守的に±15%の信頼区間を設定
    double variability;
    switch (level) {
      case AppLocalizations.of(context)!.levelBeginner:
        variability = 0.15; // ±15%（大きい個人差）
      case AppLocalizations.of(context)!.levelIntermediate:
        variability = 0.10; // ±10%（中程度の個人差）
      case AppLocalizations.of(context)!.levelAdvanced:
        variability = 0.08; // ±8%（小さい個人差）
      default:
        variability = 0.15;
    }

    return {
      'lower': predictedValue * (1 - variability),
      'upper': predictedValue * (1 + variability),
    };
  }

  /// セット追加による成長率の計算
  /// Schoenfeld 2017: セット追加ごとに+0.37%の成長
  static double calculateVolumeEffect(int currentSets, int additionalSets) {
    return additionalSets * 0.0037; // +0.37% per set
  }

  /// Weight Ratioによる客観的レベル判定
  /// 
  /// 🔧 v1.0.227: レポート Section 2 準拠（Latella 2020, van den Hoek 2024）
  /// 
  /// ユーザーの自己申告を排除し、客観的な体重比でレベルを判定
  static String detectLevelFromWeightRatio({
    required double oneRM,
    required double bodyWeight,
    required String exerciseName,
    required String gender,
  }) {
    final weightRatio = oneRM / bodyWeight;
    
    // 種目を判定
    final isBenchPress = exerciseName.contains(AppLocalizations.of(context)!.bodyPartChest) || 
                         exerciseName.contains(AppLocalizations.of(context)!.musclePecs) ||
                         exerciseName.contains(AppLocalizations.of(context)!.bodyPart_cc7dbde9);
    final isSquat = exerciseName.contains(AppLocalizations.of(context)!.bodyPartLegs) || 
                    exerciseName.contains(AppLocalizations.of(context)!.workout_0c28e8be) ||
                    exerciseName.contains(AppLocalizations.of(context)!.exerciseSquat);
    final isDeadlift = exerciseName.contains(AppLocalizations.of(context)!.bodyPartBack) || 
                       exerciseName.contains(AppLocalizations.of(context)!.workout_0f45a131) ||
                       exerciseName.contains(AppLocalizations.of(context)!.exerciseDeadlift);
    
    // レポート Table 1-3 の閾値に基づく判定
    if (isBenchPress || (!isSquat && !isDeadlift)) {
      // ベンチプレス基準（デフォルト）
      if (gender == AppLocalizations.of(context)!.genderMale) {
        if (weightRatio >= 1.95) return AppLocalizations.of(context)!.general_7db7cd79;
        if (weightRatio >= 1.60) return AppLocalizations.of(context)!.levelAdvanced;
        if (weightRatio >= 1.20) return AppLocalizations.of(context)!.levelIntermediate;
        if (weightRatio >= 0.80) return AppLocalizations.of(context)!.levelBeginner;
        return AppLocalizations.of(context)!.general_156f0a0c;
      } else {
        if (weightRatio >= 1.35) return AppLocalizations.of(context)!.general_7db7cd79;
        if (weightRatio >= 1.00) return AppLocalizations.of(context)!.levelAdvanced;
        if (weightRatio >= 0.80) return AppLocalizations.of(context)!.levelIntermediate;
        if (weightRatio >= 0.50) return AppLocalizations.of(context)!.levelBeginner;
        return AppLocalizations.of(context)!.general_156f0a0c;
      }
    } else if (isSquat) {
      // スクワット基準
      if (gender == AppLocalizations.of(context)!.genderMale) {
        if (weightRatio >= 2.83) return AppLocalizations.of(context)!.general_7db7cd79;
        if (weightRatio >= 2.10) return AppLocalizations.of(context)!.levelAdvanced;
        if (weightRatio >= 1.50) return AppLocalizations.of(context)!.levelIntermediate;
        if (weightRatio >= 1.00) return AppLocalizations.of(context)!.levelBeginner;
        return AppLocalizations.of(context)!.general_156f0a0c;
      } else {
        if (weightRatio >= 2.26) return AppLocalizations.of(context)!.general_7db7cd79;
        if (weightRatio >= 1.50) return AppLocalizations.of(context)!.levelAdvanced;
        if (weightRatio >= 1.10) return AppLocalizations.of(context)!.levelIntermediate;
        if (weightRatio >= 0.70) return AppLocalizations.of(context)!.levelBeginner;
        return AppLocalizations.of(context)!.general_156f0a0c;
      }
    } else if (isDeadlift) {
      // デッドリフト基準
      if (gender == AppLocalizations.of(context)!.genderMale) {
        if (weightRatio >= 3.25) return AppLocalizations.of(context)!.general_7db7cd79;
        if (weightRatio >= 2.40) return AppLocalizations.of(context)!.levelAdvanced;
        if (weightRatio >= 1.80) return AppLocalizations.of(context)!.levelIntermediate;
        return AppLocalizations.of(context)!.levelBeginner;
      } else {
        if (weightRatio >= 2.66) return AppLocalizations.of(context)!.general_7db7cd79;
        if (weightRatio >= 1.80) return AppLocalizations.of(context)!.levelAdvanced;
        if (weightRatio >= 1.30) return AppLocalizations.of(context)!.levelIntermediate;
        return AppLocalizations.of(context)!.levelBeginner;
      }
    }
    
    // フォールバック
    return AppLocalizations.of(context)!.levelBeginner;
  }

  /// 年齢補正係数
  static double getAgeAdjustmentFactor(int age) {
    if (age < 50) {
      return 1.0; // 補正なし
    } else if (age < 60) {
      return 0.9; // 10%減
    } else if (age < 70) {
      return 0.8; // 20%減
    } else {
      return 0.7; // 30%減
    }
  }

  /// ACSM 2-10%ルールによる負荷増加推奨
  static double getRecommendedLoadIncrease(double currentWeight) {
    return currentWeight * 0.02; // 週2%増加（ACSM推奨）
  }
}
