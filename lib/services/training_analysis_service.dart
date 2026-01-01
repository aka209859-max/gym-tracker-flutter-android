/// 🔬 トレーニング効果分析サービス
/// 
/// ユーザーのトレーニング履歴を分析し、
/// 最適なボリューム・頻度・回復時間を提案するサービス
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'scientific_database.dart';
import 'ai_response_optimizer.dart';

/// トレーニング効果分析サービスクラス
class TrainingAnalysisService {
  // Gemini API設定（AIコーチ専用キー）
  static const String _apiKey = 'AIzaSyAFVfcWzXDTtc9Rk3Zr5OGRx63FXpMAHqY';
  static const String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';

  /// トレーニング履歴から効果を分析
  /// 
  /// [bodyPart] 対象部位
  /// [level] トレーニングレベル
  /// [currentSetsPerWeek] 現在の週あたりセット数
  /// [currentFrequency] 現在の週あたり頻度
  /// [recentHistory] 直近4週間のトレーニング履歴
  /// [gender] 性別
  /// [age] 年齢
  static Future<Map<String, dynamic>> analyzeTrainingEffect({
    required String bodyPart,
    required String level,
    required int currentSetsPerWeek,
    required int currentFrequency,
    required List<Map<String, dynamic>> recentHistory,
    required String gender,
    required int age,
  }) async {
    try {
      // 推奨値の取得
      final recommendedVolume = ScientificDatabase.getRecommendedVolume(level);
      final recommendedFreq = ScientificDatabase.getRecommendedFrequency(level);
      final recommendedRest = ScientificDatabase.getRecommendedRestDays(level, bodyPart);

      // ボリューム評価
      final volumeAnalysis = _analyzeVolume(
        currentSetsPerWeek,
        recommendedVolume,
      );

      // 頻度評価
      final frequencyAnalysis = _analyzeFrequency(
        currentFrequency,
        recommendedFreq['frequency'],
      );

      // プラトー検出
      final plateauDetected = ScientificDatabase.detectPlateauFromHistory(recentHistory);
      final plateauSolutions = plateauDetected
          ? ScientificDatabase.getPlateauSolutions(level)
          : <String>[];

      // 成長トレンド分析
      final growthTrend = _analyzeGrowthTrend(recentHistory);

      // AIによる詳細な分析
      final aiAnalysis = await _getAIAnalysis(
        bodyPart: bodyPart,
        level: level,
        currentSetsPerWeek: currentSetsPerWeek,
        currentFrequency: currentFrequency,
        volumeAnalysis: volumeAnalysis,
        frequencyAnalysis: frequencyAnalysis,
        plateauDetected: plateauDetected,
        growthTrend: growthTrend,
        recommendedVolume: recommendedVolume,
        recommendedFreq: recommendedFreq,
        gender: gender,
        age: age,
      );

      return {
        'success': true,
        'bodyPart': bodyPart,
        'level': level,
        'currentStatus': {
          'setsPerWeek': currentSetsPerWeek,
          'frequency': currentFrequency,
          'restDays': recommendedRest,
        },
        'volumeAnalysis': volumeAnalysis,
        'frequencyAnalysis': frequencyAnalysis,
        'plateauDetected': plateauDetected,
        'plateauSolutions': plateauSolutions,
        'growthTrend': growthTrend,
        'recommendations': _generateRecommendations(
          volumeAnalysis: volumeAnalysis,
          frequencyAnalysis: frequencyAnalysis,
          plateauDetected: plateauDetected,
          level: level,
          bodyPart: bodyPart,
        ),
        'aiAnalysis': aiAnalysis,
        'scientificBasis': _getScientificBasis(level),
      };
    } catch (e, stackTrace) {
      print('❌❌❌ analyzeTrainingEffect全体エラー: $e');
      print('スタックトレース: $stackTrace');
      return {
        'success': false,
        'error': 'トレーニング効果分析に失敗しました: $e',
      };
    }
  }

  /// ボリューム分析
  static Map<String, dynamic> _analyzeVolume(
    int currentSets,
    Map<String, int> recommended,
  ) {
    final optimalSets = recommended['optimal']!;
    final minSets = recommended['min']!;
    final maxSets = recommended['max']!;

    String status;
    String advice;
    int suggestedChange = 0;

    if (currentSets < minSets) {
      status = 'insufficient'; // 不足
      suggestedChange = minSets - currentSets;
      advice = '週${suggestedChange}セット追加で、+${(suggestedChange * 0.37).toStringAsFixed(1)}%の成長期待（Schoenfeld 2017）';
    } else if (currentSets < optimalSets) {
      status = 'suboptimal'; // 最適以下
      suggestedChange = optimalSets - currentSets;
      advice = '週${suggestedChange}セット追加で最適ボリューム到達';
    } else if (currentSets <= maxSets) {
      status = 'optimal'; // 最適
      suggestedChange = 0;
      advice = AppLocalizations.of(context)!.general_e2dab825;
    } else {
      status = 'excessive'; // 過剰
      suggestedChange = maxSets - currentSets;
      advice = '疲労リスク：週${-suggestedChange}セット削減推奨';
    }

    return {
      'status': status,
      'currentSets': currentSets,
      'optimalSets': optimalSets,
      'minSets': minSets,
      'maxSets': maxSets,
      'suggestedChange': suggestedChange,
      'advice': advice,
    };
  }

  /// 頻度分析
  static Map<String, dynamic> _analyzeFrequency(
    int currentFrequency,
    int recommendedFrequency,
  ) {
    String status;
    String advice;

    if (currentFrequency < recommendedFrequency) {
      status = 'low';
      advice = '週+${recommendedFrequency - currentFrequency}回でボリューム増加可能（Grgic 2018）';
    } else if (currentFrequency == recommendedFrequency) {
      status = 'optimal';
      advice = AppLocalizations.of(context)!.general_1cb6010c;
    } else {
      status = 'high';
      advice = AppLocalizations.of(context)!.general_dd3d4747;
    }

    return {
      'status': status,
      'currentFrequency': currentFrequency,
      'recommendedFrequency': recommendedFrequency,
      'advice': advice,
    };
  }

  /// 成長トレンド分析
  static Map<String, dynamic> _analyzeGrowthTrend(
    List<Map<String, dynamic>> history,
  ) {
    if (history.length < 2) {
      return {
        'trend': 'insufficient_data',
        'message': AppLocalizations.of(context)!.general_d1c587d7,
      };
    }

    // 最新と最古のデータを比較
    final latest = history.first;
    final oldest = history.last;
    final weightChange = latest['weight'] - oldest['weight'];
    final weeksPassed = history.length;
    final weeklyGrowth = (weightChange / oldest['weight'] * 100) / weeksPassed;

    String trend;
    String message;

    if (weeklyGrowth > 2.0) {
      trend = 'excellent'; // 優秀
      message = '週+${weeklyGrowth.toStringAsFixed(1)}%：素晴らしい成長ペース！';
    } else if (weeklyGrowth > 1.0) {
      trend = 'good'; // 良好
      message = '週+${weeklyGrowth.toStringAsFixed(1)}%：順調に成長中';
    } else if (weeklyGrowth > 0) {
      trend = 'slow'; // 遅い
      message = '週+${weeklyGrowth.toStringAsFixed(1)}%：成長ペースが遅め';
    } else {
      trend = 'plateau'; // 停滞
      message = AppLocalizations.of(context)!.general_c13355bf;
    }

    return {
      'trend': trend,
      'weeklyGrowth': weeklyGrowth,
      'totalGrowth': weightChange,
      'weeksPassed': weeksPassed,
      'message': message,
    };
  }

  /// 推奨アクションの生成
  static List<Map<String, String>> _generateRecommendations({
    required Map<String, dynamic> volumeAnalysis,
    required Map<String, dynamic> frequencyAnalysis,
    required bool plateauDetected,
    required String level,
    required String bodyPart,
  }) {
    final recommendations = <Map<String, String>>[];

    // ボリューム推奨
    if (volumeAnalysis['status'] != 'optimal') {
      recommendations.add({
        'priority': 'high',
        'category': AppLocalizations.of(context)!.general_9ee757d0,
        'action': volumeAnalysis['advice'],
        'basis': 'Schoenfeld et al. 2017',
      });
    }

    // 頻度推奨
    if (frequencyAnalysis['status'] != 'optimal') {
      recommendations.add({
        'priority': 'medium',
        'category': AppLocalizations.of(context)!.general_c46defd1,
        'action': frequencyAnalysis['advice'],
        'basis': 'Grgic et al. 2018',
      });
    }

    // プラトー対策
    if (plateauDetected) {
      final solutions = ScientificDatabase.getPlateauSolutions(level);
      for (final solution in solutions) {
        recommendations.add({
          'priority': 'high',
          'category': AppLocalizations.of(context)!.general_028acae4,
          'action': solution,
          'basis': 'Kraemer & Ratamess 2004',
        });
      }
    }

    // 回復時間
    final restDays = ScientificDatabase.getRecommendedRestDays(level, bodyPart);
    recommendations.add({
      'priority': 'medium',
      'category': AppLocalizations.of(context)!.recovery,
      'action': '同一部位は${restDays}日空ける（MPS上昇期間：48時間）',
      'basis': 'Davies et al. 2024',
    });

    return recommendations;
  }

  /// AIによる詳細分析
  static Future<String> _getAIAnalysis({
    required String bodyPart,
    required String level,
    required int currentSetsPerWeek,
    required int currentFrequency,
    required Map<String, dynamic> volumeAnalysis,
    required Map<String, dynamic> frequencyAnalysis,
    required bool plateauDetected,
    required Map<String, dynamic> growthTrend,
    required Map<String, int> recommendedVolume,
    required Map<String, dynamic> recommendedFreq,
    required String gender,
    required int age,
  }) async {
    // キャッシュキーを生成
    final cacheKey = AIResponseOptimizer.generateCacheKey({
      'type': 'training_analysis',
      'bodyPart': bodyPart,
      'level': level,
      'currentSets': currentSetsPerWeek,
      'currentFreq': currentFrequency,
      'volumeStatus': volumeAnalysis['status'],
      'freqStatus': frequencyAnalysis['status'],
      'plateau': plateauDetected,
      'trend': growthTrend['trend'],
      'gender': gender,
      'age': age,
    });
    
    // キャッシュをチェック
    final cachedResponse = await AIResponseOptimizer.getCachedResponse(cacheKey);
    if (cachedResponse != null) {
      print('✅ トレーニング分析: キャッシュヒット（即座に応答）');
      return cachedResponse;
    }
    
    print('⏳ トレーニング分析: API呼び出し中...');
    
    final prompt = '''
${ScientificDatabase.getSystemPrompt()}

【分析対象】
・部位：$bodyPart
・レベル：$level
・性別：$gender
・年齢：${age}歳

【現在の状況】
・$bodyPart のトレーニング：週${currentSetsPerWeek}セット実施中
・$bodyPart のトレーニング頻度：週${currentFrequency}回
・ボリューム評価：${volumeAnalysis['status']}
・頻度評価：${frequencyAnalysis['status']}
・成長トレンド：${growthTrend['trend']}
・プラトー検出：${plateauDetected ? 'あり' : 'なし'}

【推奨プログラム】
・$bodyPart のボリューム：週${recommendedVolume['optimal']}セット（${recommendedVolume['min']}-${recommendedVolume['max']}セット）
・$bodyPart のトレーニング頻度：週${recommendedFreq['frequency']}回
・効果量：ES=${recommendedFreq['effectSize']}

【重要】
「週${recommendedFreq['frequency']}回」= 同一部位（$bodyPart）を週に${recommendedFreq['frequency']}回トレーニングすること
例：月曜・水曜・金曜に$bodyPart のトレーニングを実施（週3回）

以下の形式で簡潔に回答してください（300文字以内）：

## トレーニング効果の評価
（現在のプログラムの科学的評価）

## 最優先改善ポイント
（最も効果的な改善策を1つ）

## 具体的アクションプラン
（今週から実行できる3つのアクション）
''';

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
          // Note: Gemini API does NOT support X-Ios-Bundle-Identifier header
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
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
          final responseText = text.toString();
          // レスポンスをキャッシュに保存
          await AIResponseOptimizer.cacheResponse(cacheKey, responseText);
          print('✅ トレーニング分析: 成功（キャッシュ保存完了）');
          return responseText;
        } else {
          return _getFallbackAnalysis(bodyPart, level, volumeAnalysis, frequencyAnalysis, plateauDetected);
        }
      } else {
        print('❌ Gemini API エラー: ${response.statusCode} - ${response.body}');
        return _getFallbackAnalysis(bodyPart, level, volumeAnalysis, frequencyAnalysis, plateauDetected);
      }
    } catch (e) {
      print('❌ AI分析エラー: $e');
      return _getFallbackAnalysis(bodyPart, level, volumeAnalysis, frequencyAnalysis, plateauDetected);
    }
  }

  /// フォールバック分析（AI失敗時）
  static String _getFallbackAnalysis(
    String bodyPart,
    String level,
    Map<String, dynamic> volumeAnalysis,
    Map<String, dynamic> frequencyAnalysis,
    bool plateauDetected,
  ) {
    final buffer = StringBuffer();
    
    buffer.writeln('## トレーニング効果の評価');
    if (volumeAnalysis['status'] == 'optimal' && frequencyAnalysis['status'] == 'optimal') {
      buffer.writeln(AppLocalizations.of(context)!.general_b2d3af2b);
    } else {
      buffer.writeln(AppLocalizations.of(context)!.general_5be1d3e2);
    }
    
    buffer.writeln('\n## 最優先改善ポイント');
    if (volumeAnalysis['status'] == 'insufficient') {
      buffer.writeln('週${volumeAnalysis['suggestedChange']}セット追加で、筋肥大効果が向上します（Schoenfeld 2017）。');
    } else if (volumeAnalysis['status'] == 'excessive') {
      buffer.writeln('現在のボリュームは過剰です。週${-volumeAnalysis['suggestedChange']}セット削減で回復時間を確保しましょう。');
    } else if (plateauDetected) {
      buffer.writeln(AppLocalizations.of(context)!.general_e72d4ca1);
    } else {
      buffer.writeln('${volumeAnalysis['advice']}');
    }
    
    buffer.writeln('\n## 具体的アクションプラン');
    buffer.writeln('* 今週から: ${volumeAnalysis['advice']}');
    buffer.writeln('* トレーニング頻度: ${frequencyAnalysis['advice']}');
    buffer.writeln('* 回復時間: $bodyPartは${ScientificDatabase.getRecommendedRestDays(level, bodyPart)}日空ける');
    
    return buffer.toString();
  }

  /// 科学的根拠の取得
  static List<Map<String, String>> _getScientificBasis(String level) {
    return [
      {
        'citation': 'Schoenfeld et al. 2017',
        'finding': 'セット追加ごとに+0.37%の成長',
        'effectSize': 'N/A',
      },
      {
        'citation': 'Grgic et al. 2018',
        'finding': AppLocalizations.of(context)!.general_52c6bae7,
        'effectSize': 'ES=0.88-1.08',
      },
      {
        'citation': 'Davies et al. 2024',
        'finding': AppLocalizations.of(context)!.general_351acace,
        'effectSize': 'N/A',
      },
      {
        'citation': 'Baz-Valle et al. 2022',
        'finding': AppLocalizations.of(context)!.general_6677a2f7,
        'effectSize': 'N/A',
      },
    ];
  }

  /// 週次ボリュームトレンドの生成（グラフ用）
  static List<Map<String, dynamic>> generateVolumeTrend(
    List<Map<String, dynamic>> history,
  ) {
    return history.map((record) {
      return {
        'week': record['week'] ?? 0,
        'sets': record['sets'] ?? 0,
        'weight': record['weight'] ?? 0,
      };
    }).toList();
  }
}
