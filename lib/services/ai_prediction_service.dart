/// 📈 AI成長予測サービス
/// 
/// Gemini 2.0 Flash APIと科学的根拠データベースを活用し、
/// ユーザーの筋力成長を予測するサービス
library;

import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'scientific_database.dart';

/// AI成長予測サービスクラス
class AIPredictionService {
  // Gemini API設定（AIコーチ専用キー）
  static const String _apiKey = 'AIzaSyA9XmQSHA1llGg7gihqjmOOIaLA856fkLc';
  static const String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';

  /// ユーザーの成長を予測
  /// 
  /// [currentWeight] 現在の1RM（kg）
  /// [level] トレーニングレベル（初心者/中級者/上級者）
  /// [frequency] 週あたりのトレーニング頻度
  /// [gender] 性別（男性/女性）
  /// [age] 年齢
  /// [bodyPart] 対象部位（胸/背中/脚/腕/肩）
  /// [monthsAhead] 予測期間（月数、デフォルト4ヶ月）
  static Future<Map<String, dynamic>> predictGrowth({
    required double currentWeight,
    required String level,
    required int frequency,
    required String gender,
    required int age,
    required String bodyPart,
    int monthsAhead = 4,
  }) async {
    try {
      // 基本的な成長率を計算
      final monthlyRate = ScientificDatabase.getMonthlyGrowthRate(level);
      final weeklyRate = ScientificDatabase.getWeeklyGrowthRate(level, gender, bodyPart);

      // 年齢補正
      final ageAdjustment = ScientificDatabase.getAgeAdjustmentFactor(age);

      // 予測値の計算（複利計算）
      // 月次成長率を使った現実的な予測
      final predictedWeight =
          currentWeight * math.pow(1 + monthlyRate * ageAdjustment, monthsAhead);

      // 信頼区間の計算
      final confidenceInterval =
          ScientificDatabase.calculateConfidenceInterval(predictedWeight, level);

      // 推奨ボリュームと頻度
      final recommendedVolume = ScientificDatabase.getRecommendedVolume(level);
      final recommendedFreq = ScientificDatabase.getRecommendedFrequency(level);

      // AIによる詳細な分析を取得
      final aiAnalysis = await _getAIAnalysis(
        currentWeight: currentWeight,
        predictedWeight: predictedWeight,
        level: level,
        frequency: frequency,
        gender: gender,
        age: age,
        bodyPart: bodyPart,
        monthsAhead: monthsAhead,
        monthlyRate: monthlyRate,
        weeklyRate: weeklyRate,
        recommendedVolume: recommendedVolume,
        recommendedFreq: recommendedFreq,
      );

      return {
        'success': true,
        'currentWeight': currentWeight,
        'predictedWeight': predictedWeight.roundToDouble(),
        'growthPercentage': ((predictedWeight - currentWeight) / currentWeight * 100).round(),
        'confidenceInterval': {
          'lower': confidenceInterval['lower']!.roundToDouble(),
          'upper': confidenceInterval['upper']!.roundToDouble(),
        },
        'monthlyRate': (monthlyRate * 100).round(),
        'weeklyRate': (weeklyRate * 100 * 10).round() / 10, // 小数点1桁
        'recommendedVolume': recommendedVolume,
        'recommendedFrequency': recommendedFreq,
        'aiAnalysis': aiAnalysis,
        'scientificBasis': _getScientificBasis(level, gender, bodyPart),
      };
    } catch (e, stackTrace) {
      print('❌❌❌ predictGrowth全体エラー: $e');
      print('スタックトレース: $stackTrace');
      return {
        'success': false,
        'error': 'AI予測の生成に失敗しました: $e',
      };
    }
  }

  /// AIによる詳細な分析を取得
  static Future<String> _getAIAnalysis({
    required double currentWeight,
    required double predictedWeight,
    required String level,
    required int frequency,
    required String gender,
    required int age,
    required String bodyPart,
    required int monthsAhead,
    required double monthlyRate,
    required double weeklyRate,
    required Map<String, int> recommendedVolume,
    required Map<String, dynamic> recommendedFreq,
  }) async {
    final prompt = '''
${ScientificDatabase.getSystemPrompt()}

【ユーザー情報】
・対象部位：$bodyPart
・現在の1RM：${currentWeight}kg
・トレーニングレベル：$level
・現在の頻度：$bodyPart を週${frequency}回トレーニング
・性別：$gender
・年齢：${age}歳

【予測結果】
・予測期間：${monthsAhead}ヶ月
・予測1RM：${predictedWeight.round()}kg
・成長率：月+${(monthlyRate * 100).round()}%
・週次成長率：週+${(weeklyRate * 100 * 10).round() / 10}%

【推奨プログラム】
・$bodyPart のトレーニング：週${recommendedFreq['frequency']}回
・$bodyPart のボリューム：週${recommendedVolume['optimal']}セット
・効果量：ES=${recommendedFreq['effectSize']}

【重要】
「週${recommendedFreq['frequency']}回」= 同一部位（$bodyPart）を週に${recommendedFreq['frequency']}回トレーニングすること
これはGrgic et al. 2018のメタ分析に基づく推奨値

以下の形式で簡潔に回答してください（300文字以内）：

## 成長予測の科学的根拠
（レベル別の成長率とその根拠を説明）

## 推奨アクションプラン
（具体的なトレーニング頻度・ボリューム・負荷増加を提案）

## 成功のカギ
（最も重要な3つのポイント）
''';

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3, // 一貫性重視
            'maxOutputTokens': 1024,
            'topP': 0.8,
            'topK': 40,
          },
        }),
      ).timeout(const Duration(seconds: 5)); // 5秒タイムアウト（高速フォールバック）

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null && text.toString().isNotEmpty) {
          return text.toString();
        } else {
          return _getFallbackPrediction(currentWeight, predictedWeight, level, bodyPart, monthlyRate, weeklyRate, recommendedVolume, recommendedFreq);
        }
      } else {
        print('❌ Gemini API エラー (成長予測): ${response.statusCode} - ${response.body}');
        return _getFallbackPrediction(currentWeight, predictedWeight, level, bodyPart, monthlyRate, weeklyRate, recommendedVolume, recommendedFreq);
      }
    } catch (e) {
      print('❌ AI予測エラー: $e');
      return _getFallbackPrediction(currentWeight, predictedWeight, level, bodyPart, monthlyRate, weeklyRate, recommendedVolume, recommendedFreq);
    }
  }

  /// フォールバック予測（AI失敗時）
  static String _getFallbackPrediction(
    double currentWeight,
    double predictedWeight,
    String level,
    String bodyPart,
    double monthlyRate,
    double weeklyRate,
    Map<String, int> recommendedVolume,
    Map<String, dynamic> recommendedFreq,
  ) {
    final buffer = StringBuffer();
    
    buffer.writeln('## 成長予測の科学的根拠');
    buffer.writeln('あなたの$level レベルでは、月+${(monthlyRate * 100).round()}%の成長が期待できます。');
    buffer.writeln('現在${currentWeight.round()}kg → 4ヶ月後${predictedWeight.round()}kg（+${(predictedWeight - currentWeight).round()}kg）の成長が科学的に見込まれます。');
    
    buffer.writeln('\n## 推奨アクションプラン');
    buffer.writeln('* $bodyPart のトレーニング: 週${recommendedFreq['frequency']}回');
    buffer.writeln('* $bodyPart のボリューム: 週${recommendedVolume['optimal']}セット（${recommendedVolume['min']}-${recommendedVolume['max']}セット）');
    buffer.writeln('* 負荷増加: 週+${(weeklyRate * 100 * 10).round() / 10}%のペースで重量を上げる');
    
    buffer.writeln('\n## 成功のカギ');
    buffer.writeln('* プログレッシブオーバーロード（漸進的過負荷）の実践');
    buffer.writeln('* 十分な休息（$bodyPartは最低48時間空ける）');
    buffer.writeln('* 適切な栄養摂取（タンパク質1.6-2.2g/kg/日）');
    
    return buffer.toString();
  }

  /// 科学的根拠の取得
  static List<Map<String, String>> _getScientificBasis(
    String level,
    String gender,
    String bodyPart,
  ) {
    final basis = <Map<String, String>>[];

    // レベル別の根拠
    if (level == '初心者') {
      basis.add({
        'citation': 'ACSM 2009',
        'finding': '初心者は4ヶ月で約30%の筋力向上',
        'effectSize': 'N/A',
      });
      
      final isUpperBody = bodyPart.contains('胸') || 
                          bodyPart.contains('腕') || 
                          bodyPart.contains('肩') || 
                          bodyPart.contains('三角筋');
      
      if (gender == '女性' && isUpperBody) {
        basis.add({
          'citation': 'Roberts et al. 2020',
          'finding': '女性の上半身は男性より20%高い成長率',
          'effectSize': 'ES=-0.60',
        });
      }
    } else if (level == '中級者') {
      basis.add({
        'citation': 'ACSM 2009',
        'finding': '中級者は4ヶ月で約15%の筋力向上',
        'effectSize': 'N/A',
      });
    } else {
      basis.add({
        'citation': 'Williams et al. 2017',
        'finding': 'DUPが上級者に効果的（4ヶ月で約5%成長）',
        'effectSize': 'ES=0.68',
      });
    }

    // 頻度の根拠
    basis.add({
      'citation': 'Grgic et al. 2018',
      'finding': 'ボリュームが成長の鍵、頻度は手段',
      'effectSize': 'ES=0.88-1.08',
    });

    // ボリュームの根拠
    basis.add({
      'citation': 'Schoenfeld et al. 2017',
      'finding': 'セット追加ごとに+0.37%の成長',
      'effectSize': 'N/A',
    });

    return basis;
  }

  /// 月次の予測カーブを生成（グラフ用）
  static List<Map<String, dynamic>> generatePredictionCurve({
    required double currentWeight,
    required String level,
    required String gender,
    required int age,
    required String bodyPart,
    int monthsAhead = 4,
  }) {
    final curve = <Map<String, dynamic>>[];
    final monthlyRate = ScientificDatabase.getMonthlyGrowthRate(level);
    final ageAdjustment = ScientificDatabase.getAgeAdjustmentFactor(age);

    // 女性の上半身は特別補正
    double genderBonus = 1.0;
    final isUpperBody = bodyPart.contains('胸') || 
                        bodyPart.contains('腕') || 
                        bodyPart.contains('肩') || 
                        bodyPart.contains('三角筋');
    
    if (gender == '女性' && isUpperBody) {
      genderBonus = 1.2; // +20%ボーナス（Roberts 2020）
    }

    // 月ごとの予測値を計算
    for (int month = 0; month <= monthsAhead; month++) {
      final weight = currentWeight *
          math.pow(1 + monthlyRate * ageAdjustment * genderBonus, month);
      final ci = ScientificDatabase.calculateConfidenceInterval(weight, level);

      curve.add({
        'month': month,
        'weight': weight.roundToDouble(),
        'lower': ci['lower']!.roundToDouble(),
        'upper': ci['upper']!.roundToDouble(),
      });
    }

    return curve;
  }
}
