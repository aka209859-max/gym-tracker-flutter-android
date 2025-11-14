import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// トレーニング記録画像インポートサービス
/// 
/// 筋トレMEMOなどの他アプリのスクリーンショットから
/// トレーニングデータを自動抽出
class WorkoutImportService {
  // Gemini API設定
  static const String _apiKey = 'AIzaSyCanbEj1olBLzNhnlmlJH13jA93cr4LHtI';
  static const String _apiUrl = 
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';

  /// 画像からトレーニングデータを抽出
  /// 
  /// [imageBytes]: 画像のバイトデータ
  /// 戻り値: 抽出されたトレーニングデータのJSON
  static Future<Map<String, dynamic>> extractWorkoutFromImage(
    Uint8List imageBytes,
  ) async {
    try {
      if (kDebugMode) {
        print('📸 画像解析開始...');
      }

      // 画像をBase64エンコード
      final base64Image = base64Encode(imageBytes);

      // Gemini APIリクエスト
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': _buildPrompt(),
                },
                {
                  'inline_data': {
                    'mime_type': 'image/png',
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'topK': 1,
            'topP': 1,
            'maxOutputTokens': 2048,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        
        if (kDebugMode) {
          print('✅ AI応答: $text');
        }

        // JSONを抽出（```json ... ```の中身を取り出す）
        final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(text);
        if (jsonMatch != null) {
          final jsonString = jsonMatch.group(1)!;
          final result = jsonDecode(jsonString) as Map<String, dynamic>;
          
          if (kDebugMode) {
            print('✅ データ抽出成功: ${result['exercises']?.length ?? 0}種目');
          }
          
          return result;
        } else {
          // JSONブロックがない場合、テキスト全体をパース試行
          final result = jsonDecode(text) as Map<String, dynamic>;
          return result;
        }
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 画像解析エラー: $e');
      }
      rethrow;
    }
  }

  /// Gemini用プロンプト生成
  static String _buildPrompt() {
    return '''
この筋トレアプリのトレーニング記録画像から、以下の情報を抽出してJSON形式で返してください：

1. 日付（date）: YYYY-MM-DD形式
2. トレーニング種目リスト（exercises）: 各種目ごとに以下の情報
   - 種目名（name）: 文字列
   - セット情報（sets）: 各セットごとに
     - セット番号（set_number）: 数値
     - 重量（weight_kg）: 数値（自重の場合は0）
     - 回数（reps）: 数値

JSON形式例:
{
  "date": "2025-11-03",
  "exercises": [
    {
      "name": "ベンチプレス",
      "sets": [
        {"set_number": 1, "weight_kg": 80.0, "reps": 10},
        {"set_number": 2, "weight_kg": 80.0, "reps": 10},
        {"set_number": 3, "weight_kg": 75.0, "reps": 8}
      ]
    }
  ]
}

重要:
- 日付は必ず YYYY-MM-DD 形式で返してください
- 自重トレーニング（懸垂、チンニング等）の重量は0としてください
- kg表記は数値のみ抽出してください（"kg"は除く）
- 回数表記から数値のみ抽出してください（"reps"、"回"は除く）
- すべての種目とセットを正確に抽出してください
- JSON以外の説明文は不要です

画像から読み取ったトレーニング記録を上記のJSON形式で返してください。
''';
  }

  /// 種目名から部位を推定
  /// 
  /// マッピング辞書にない場合はデフォルトで「胸」を返す
  static String estimateBodyPart(String exerciseName) {
    final mapping = _exerciseToBodyPartMapping();
    return mapping[exerciseName] ?? '胸'; // デフォルト: 胸
  }

  /// 種目名 → 部位のマッピング辞書
  static Map<String, String> _exerciseToBodyPartMapping() {
    return {
      // 胸
      'ベンチプレス': '胸',
      'ダンベルプレス': '胸',
      'ダンベルベンチプレス': '胸',
      'インクラインプレス': '胸',
      'インクラインベンチプレス': '胸',
      'ケーブルフライ': '胸',
      'ディップス': '胸',
      'チェストプレス': '胸',
      'ペックフライ': '胸',
      
      // 背中
      'ラットプルダウン': '背中',
      'チンニング': '背中',
      'チンニング（懸垂）': '背中',
      '懸垂': '背中',
      'ベントオーバーローイング': '背中',
      'ベントオーバーロー': '背中',
      'デッドリフト': '背中',
      'シーテッドロウ': '背中',
      'ワンハンドロウ': '背中',
      'Tバーロウ': '背中',
      'ケーブルロウ': '背中',
      
      // 脚
      'スクワット': '脚',
      'レッグプレス': '脚',
      'レッグエクステンション': '脚',
      'レッグカール': '脚',
      'ランジ': '脚',
      'ブルガリアンスクワット': '脚',
      'カーフレイズ': '脚',
      'レッグレイズ': '脚',
      
      // 肩
      'ショルダープレス': '肩',
      'サイドレイズ': '肩',
      'フロントレイズ': '肩',
      'リアレイズ': '肩',
      'アップライトロウ': '肩',
      'ダンベルショルダープレス': '肩',
      
      // 二頭
      'バーベルカール': '二頭',
      'ダンベルカール': '二頭',
      'ハンマーカール': '二頭',
      'プリーチャーカール': '二頭',
      'コンセントレーションカール': '二頭',
      'インクラインカール': '二頭',
      
      // 三頭
      'トライセプスダウン': '三頭',
      'トライセプスプレスダウン': '三頭',
      'トライセプスエクステンション': '三頭',
      'ライイングトライセプスエクステンション': '三頭',
      'フレンチプレス': '三頭',
      'キックバック': '三頭',
      'クローズグリップベンチプレス': '三頭',
      
      // 有酸素
      'ランニング': '有酸素',
      'ウォーキング': '有酸素',
      'バイク': '有酸素',
      'エアロバイク': '有酸素',
      'トレッドミル': '有酸素',
      'エリプティカル': '有酸素',
      'ローイングマシン': '有酸素',
    };
  }
}
