import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:csv/csv.dart';

/// トレーニング記録インポートサービス
/// 
/// 画像（筋トレMEMOなど）またはCSVファイルから
/// トレーニングデータを自動抽出
class WorkoutImportService {
  // Gemini API設定（写真取り込み専用：無料枠モデル使用）
  static const String _apiKey = 'AIzaSyAFVfcWzXDTtc9Rk3Zr5OGRx63FXpMAHqY';
  static const String _apiUrl = 
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';

  /// 画像からトレーニングデータを抽出（リトライロジック付き）
  /// 
  /// [imageBytes]: 画像のバイトデータ
  /// 戻り値: 抽出されたトレーニングデータのJSON
  static Future<Map<String, dynamic>> extractWorkoutFromImage(
    Uint8List imageBytes,
  ) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (kDebugMode) {
          print('📸 画像解析開始... (試行 $attempt/$maxRetries)');
        }

        // 画像サイズチェックと最適化（Gemini API制限: 20MB）
        Uint8List processedImageBytes = imageBytes;
        
        // 画像が10MBを超える場合は警告（20MB制限の半分）
        const maxSizeBytes = 10 * 1024 * 1024; // 10MB
        if (imageBytes.length > maxSizeBytes) {
          if (kDebugMode) {
            print('⚠️ 画像サイズが大きすぎます: ${(imageBytes.length / 1024 / 1024).toStringAsFixed(2)}MB');
            print('💡 ヒント: より小さい画像を使用するか、スクリーンショットの品質を下げてください');
          }
          // 大きすぎる場合はエラーとする
          throw Exception(
            '画像サイズが大きすぎます (${(imageBytes.length / 1024 / 1024).toStringAsFixed(1)}MB)。\n'
            AppLocalizations.of(context)!.workout_dd8555d2
          );
        }
        
        // 画像をBase64エンコード
        final base64Image = base64Encode(processedImageBytes);
        
        // 画像のMIME Typeを判定（バイトシグネチャから）
        String mimeType = 'image/jpeg'; // デフォルトはJPEG
        if (imageBytes.length >= 4) {
          // PNG: 89 50 4E 47
          if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50 &&
              imageBytes[2] == 0x4E && imageBytes[3] == 0x47) {
            mimeType = 'image/png';
          }
          // JPEG: FF D8 FF
          else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8 &&
                   imageBytes[2] == 0xFF) {
            mimeType = 'image/jpeg';
          }
        }
        
        if (kDebugMode) {
          print('📷 画像形式: $mimeType (サイズ: ${imageBytes.length} bytes)');
        }

        // Gemini APIリクエスト
        final response = await http.post(
          Uri.parse('$_apiUrl?key=$_apiKey'),
          headers: {
            'Content-Type': 'application/json',
            'X-Ios-Bundle-Identifier': 'com.nexa.gymmatch',
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text': _buildPrompt(),
                  },
                  {
                    'inline_data': {
                      'mime_type': mimeType,
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

      if (kDebugMode) {
        print('📡 APIレスポンス: ${response.statusCode}');
        print('📄 レスポンスボディ（最初の200文字）: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          // エラーレスポンスのチェック
          if (data.containsKey('error')) {
            throw Exception('Gemini API Error: ${data['error']['message']}');
          }
          
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
        } catch (e) {
          if (kDebugMode) {
            print('❌ JSONパースエラー: $e');
            print('📄 レスポンス全文: ${response.body}');
          }
          throw Exception('レスポンスの解析に失敗しました: $e');
        }
      } else if (response.statusCode == 503 && attempt < maxRetries) {
        // 503エラー（サーバー過負荷）の場合はリトライ
        if (kDebugMode) {
          print('⚠️ API過負荷 (503)。${retryDelay.inSeconds}秒後に再試行...');
        }
        await Future.delayed(retryDelay);
        continue; // 次の試行へ
      } else if (response.statusCode == 403) {
        // 403 Forbiddenエラー（API権限エラー）
        if (kDebugMode) {
          print('❌ API権限エラー (403): ${response.body}');
        }
        throw Exception(AppLocalizations.of(context)!.workout_7d512f87);
      } else if (response.statusCode == 400) {
        // 400 Bad Request（リクエスト形式エラー）
        if (kDebugMode) {
          print('❌ リクエストエラー (400): ${response.body}');
        }
        throw Exception(AppLocalizations.of(context)!.workout_ba59242e);
      } else {
        // その他のエラー
        if (kDebugMode) {
          print('❌ API Error: HTTP ${response.statusCode}');
          print('Response Headers: ${response.headers}');
          print('Response Body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        }
        throw Exception('画像解析に失敗しました (HTTP ${response.statusCode})。もう一度お試しください。');
      }
    } catch (e) {
      if (attempt == maxRetries) {
        // 最後の試行でも失敗した場合
        if (kDebugMode) {
          print('❌ 画像解析エラー（最大試行回数到達）: $e');
        }
        rethrow;
      } else if (e.toString().contains('503') || e.toString().contains('overloaded')) {
        // 503エラーの場合はリトライ
        if (kDebugMode) {
          print('⚠️ API過負荷検出。${retryDelay.inSeconds}秒後に再試行...');
        }
        await Future.delayed(retryDelay);
        continue;
      } else {
        // その他のエラーは即座に失敗
        if (kDebugMode) {
          print('❌ 画像解析エラー: $e');
        }
        rethrow;
      }
    }
    }
    
    // ここには到達しないはずだが、念のため
    throw Exception('画像解析に失敗しました（最大試行回数: $maxRetries）');
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
      "name": AppLocalizations.of(context)!.exerciseBenchPress,
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
- kg表記は数値のみ抽出してください（AppLocalizations.of(context)!.kgは除く）
- 回数表記から数値のみ抽出してください（"reps"、AppLocalizations.of(context)!.workoutRepsLabelは除く）
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
    return mapping[exerciseName] ?? AppLocalizations.of(context)!.bodyPartChest; // デフォルト: 胸
  }

  /// CSVファイルからトレーニングデータを抽出
  /// 
  /// [csvContent]: CSVファイルの文字列内容
  /// 戻り値: 抽出されたトレーニングデータのJSON
  /// 
  /// 対応CSVフォーマット:
  /// - 筋トレMEMO形式: 日付,種目名,セット,重量,回数
  /// - 汎用形式: date,exercise,set,weight,reps
  static Future<Map<String, dynamic>> extractWorkoutFromCSV(
    String csvContent,
  ) async {
    try {
      if (kDebugMode) {
        print('📄 CSV解析開始...');
        print('📄 CSVサイズ: ${csvContent.length} bytes');
      }

      // CSV解析
      final List<List<dynamic>> csvRows = const CsvToListConverter().convert(
        csvContent,
        eol: '\n',
        shouldParseNumbers: true,
      );

      if (csvRows.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.workout_53bd5cb4);
      }

      if (kDebugMode) {
        print('📊 CSV行数: ${csvRows.length}');
        print('📊 最初の行: ${csvRows.first}');
      }

      // ヘッダー行を検出
      final List<dynamic> headerRow = csvRows.first;
      final bool hasHeader = _isHeaderRow(headerRow);
      
      int dataStartIndex = hasHeader ? 1 : 0;
      
      if (kDebugMode) {
        print('📋 ヘッダー検出: ${hasHeader ? "あり" : "なし"}');
      }

      // データ行を解析
      final Map<String, List<Map<String, dynamic>>> exercisesByDate = {};
      
      for (int i = dataStartIndex; i < csvRows.length; i++) {
        final row = csvRows[i];
        
        // 空行をスキップ
        if (row.isEmpty || row.every((cell) => cell == null || cell.toString().trim().isEmpty)) {
          continue;
        }

        try {
          // CSV形式を判定して解析
          final parsedRow = _parseCSVRow(row);
          
          if (parsedRow != null) {
            final date = parsedRow['date'] as String;
            
            // 日付ごとにグループ化
            if (!exercisesByDate.containsKey(date)) {
              exercisesByDate[date] = [];
            }
            
            // 同じ種目を見つけてセットを追加
            final existingExercise = exercisesByDate[date]!.firstWhere(
              (ex) => ex['name'] == parsedRow['exercise'],
              orElse: () => <String, dynamic>{},
            );
            
            if (existingExercise.isEmpty) {
              // 新しい種目
              exercisesByDate[date]!.add({
                'name': parsedRow['exercise'],
                'sets': [
                  {
                    'set_number': parsedRow['set'],
                    'weight_kg': parsedRow['weight'],
                    'reps': parsedRow['reps'],
                  }
                ],
              });
            } else {
              // 既存種目にセット追加
              (existingExercise['sets'] as List).add({
                'set_number': parsedRow['set'],
                'weight_kg': parsedRow['weight'],
                'reps': parsedRow['reps'],
              });
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ 行${i + 1}のパースエラー（スキップ）: $e');
          }
          // 行単位のエラーは無視して次の行へ
          continue;
        }
      }

      if (exercisesByDate.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.workout_8682e261);
      }

      // 最初の日付のデータを返す（複数日ある場合は最新日）
      final dates = exercisesByDate.keys.toList()..sort();
      final targetDate = dates.last;
      
      final result = {
        'date': targetDate,
        'exercises': exercisesByDate[targetDate],
      };

      if (kDebugMode) {
        print('✅ CSV解析成功: ${(result['exercises'] as List?)?.length ?? 0}種目');
        print('📅 対象日: $targetDate');
      }

      return result;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ CSV解析エラー: $e');
      }
      rethrow;
    }
  }

  /// CSV行がヘッダー行かを判定
  static bool _isHeaderRow(List<dynamic> row) {
    if (row.isEmpty) return false;
    
    // 日本語ヘッダー
    final japaneseHeaders = [AppLocalizations.of(context)!.date, AppLocalizations.of(context)!.exercise, AppLocalizations.of(context)!.workoutSetsLabel, AppLocalizations.of(context)!.workoutWeightLabel, AppLocalizations.of(context)!.repsCount, AppLocalizations.of(context)!.workout_2c76b53f, AppLocalizations.of(context)!.bodyPart];
    // 英語ヘッダー
    final englishHeaders = ['date', 'exercise', 'set', 'weight', 'reps', 'menu', 'bodypart'];
    
    final firstCell = row.first.toString().toLowerCase();
    
    return japaneseHeaders.any((h) => row.first.toString().contains(h)) ||
           englishHeaders.any((h) => firstCell.contains(h));
  }

  /// CSV行を解析して標準形式に変換
  /// 
  /// 対応フォーマット:
  /// 1. 筋トレMEMO形式: 日付,種目名,セット番号,重量,回数
  /// 2. 汎用5列形式: date,exercise,set,weight,reps
  /// 3. 拡張6列形式: date,exercise,bodypart,set,weight,reps
  static Map<String, dynamic>? _parseCSVRow(List<dynamic> row) {
    if (row.length < 5) {
      return null; // 最低5列必要
    }

    try {
      // 日付を正規化 (YYYY-MM-DD形式に変換)
      String date = row[0].toString().trim();
      date = _normalizeDate(date);

      // 種目名
      String exercise = row[1].toString().trim();
      
      // セット番号（3列目または4列目）
      int setNumber;
      double weight;
      int reps;
      
      if (row.length == 5) {
        // 5列形式: 日付,種目,セット,重量,回数
        setNumber = _parseInt(row[2]);
        weight = _parseDouble(row[3]);
        reps = _parseInt(row[4]);
      } else if (row.length >= 6) {
        // 6列以上形式: 日付,種目,部位,セット,重量,回数
        setNumber = _parseInt(row[3]);
        weight = _parseDouble(row[4]);
        reps = _parseInt(row[5]);
      } else {
        return null;
      }

      return {
        'date': date,
        'exercise': exercise,
        'set': setNumber,
        'weight': weight,
        'reps': reps,
      };
      
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 行パースエラー: $e');
      }
      return null;
    }
  }

  /// 日付文字列を YYYY-MM-DD 形式に正規化
  static String _normalizeDate(String dateStr) {
    // スラッシュ区切り: 2025/01/15 → 2025-01-15
    if (dateStr.contains('/')) {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final year = parts[0].padLeft(4, '0');
        final month = parts[1].padLeft(2, '0');
        final day = parts[2].padLeft(2, '0');
        return '$year-$month-$day';
      }
    }
    
    // ドット区切り: 2025.01.15 → 2025-01-15
    if (dateStr.contains('.')) {
      final parts = dateStr.split('.');
      if (parts.length == 3) {
        final year = parts[0].padLeft(4, '0');
        final month = parts[1].padLeft(2, '0');
        final day = parts[2].padLeft(2, '0');
        return '$year-$month-$day';
      }
    }
    
    // 日本語形式: 2025年1月15日 → 2025-01-15
    final japaneseMatch = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(dateStr);
    if (japaneseMatch != null) {
      final year = japaneseMatch.group(1)!;
      final month = japaneseMatch.group(2)!.padLeft(2, '0');
      final day = japaneseMatch.group(3)!.padLeft(2, '0');
      return '$year-$month-$day';
    }
    
    // すでに YYYY-MM-DD 形式
    return dateStr;
  }

  /// 文字列を整数に変換（エラー時は0）
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      return int.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  /// 文字列を浮動小数点に変換（エラー時は0.0）
  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  /// 種目名 → 部位のマッピング辞書
  static Map<String, String> _exerciseToBodyPartMapping() {
    return {
      // 胸
      AppLocalizations.of(context)!.exerciseBenchPress: AppLocalizations.of(context)!.bodyPartChest,
      AppLocalizations.of(context)!.exerciseDumbbellPress: AppLocalizations.of(context)!.bodyPartChest,
      AppLocalizations.of(context)!.exercise_4cb61d65: AppLocalizations.of(context)!.bodyPartChest,
      AppLocalizations.of(context)!.exerciseInclinePress: AppLocalizations.of(context)!.bodyPartChest,
      AppLocalizations.of(context)!.exercise_fbfc037a: AppLocalizations.of(context)!.bodyPartChest,
      AppLocalizations.of(context)!.exerciseCableFly: AppLocalizations.of(context)!.bodyPartChest,
      AppLocalizations.of(context)!.exerciseDips: AppLocalizations.of(context)!.bodyPartChest,
      AppLocalizations.of(context)!.exercise_cfc4f367: AppLocalizations.of(context)!.bodyPartChest,
      AppLocalizations.of(context)!.workout_fb73b843: AppLocalizations.of(context)!.bodyPartChest,
      
      // 背中
      AppLocalizations.of(context)!.exerciseLatPulldown: AppLocalizations.of(context)!.bodyPartBack,
      AppLocalizations.of(context)!.exerciseChinUp: AppLocalizations.of(context)!.bodyPartBack,
      AppLocalizations.of(context)!.workout_4f6cd3a6: AppLocalizations.of(context)!.bodyPartBack,
      AppLocalizations.of(context)!.exercisePullUp: AppLocalizations.of(context)!.bodyPartBack,
      AppLocalizations.of(context)!.workout_e6ae79d7: AppLocalizations.of(context)!.bodyPartBack,
      AppLocalizations.of(context)!.workout_02d51e36: AppLocalizations.of(context)!.bodyPartBack,
      AppLocalizations.of(context)!.exerciseDeadlift: AppLocalizations.of(context)!.bodyPartBack,
      AppLocalizations.of(context)!.exerciseSeatedRow: AppLocalizations.of(context)!.bodyPartBack,
      AppLocalizations.of(context)!.workout_1db606e0: AppLocalizations.of(context)!.bodyPartBack,
      AppLocalizations.of(context)!.workout_78f50d3b: AppLocalizations.of(context)!.bodyPartBack,
      AppLocalizations.of(context)!.workout_f8d1b968: AppLocalizations.of(context)!.bodyPartBack,
      
      // 脚
      AppLocalizations.of(context)!.exerciseSquat: AppLocalizations.of(context)!.bodyPartLegs,
      AppLocalizations.of(context)!.exerciseLegPress: AppLocalizations.of(context)!.bodyPartLegs,
      AppLocalizations.of(context)!.exerciseLegExtension: AppLocalizations.of(context)!.bodyPartLegs,
      AppLocalizations.of(context)!.exerciseLegCurl: AppLocalizations.of(context)!.bodyPartLegs,
      AppLocalizations.of(context)!.workout_a19f4e60: AppLocalizations.of(context)!.bodyPartLegs,
      AppLocalizations.of(context)!.exercise_1602d233: AppLocalizations.of(context)!.bodyPartLegs,
      AppLocalizations.of(context)!.exerciseCalfRaise: AppLocalizations.of(context)!.bodyPartLegs,
      AppLocalizations.of(context)!.legRaise: AppLocalizations.of(context)!.bodyPartLegs,
      
      // 肩
      AppLocalizations.of(context)!.exerciseShoulderPress: AppLocalizations.of(context)!.bodyPartShoulders,
      AppLocalizations.of(context)!.exerciseSideRaise: AppLocalizations.of(context)!.bodyPartShoulders,
      AppLocalizations.of(context)!.exerciseFrontRaise: AppLocalizations.of(context)!.bodyPartShoulders,
      AppLocalizations.of(context)!.workout_61db805d: AppLocalizations.of(context)!.bodyPartShoulders,
      AppLocalizations.of(context)!.exerciseUprightRow: AppLocalizations.of(context)!.bodyPartShoulders,
      AppLocalizations.of(context)!.exercise_b9e82d29: AppLocalizations.of(context)!.bodyPartShoulders,
      
      // 二頭
      AppLocalizations.of(context)!.exerciseBarbellCurl: AppLocalizations.of(context)!.bodyPartBiceps,
      AppLocalizations.of(context)!.exerciseDumbbellCurl: AppLocalizations.of(context)!.bodyPartBiceps,
      AppLocalizations.of(context)!.exerciseHammerCurl: AppLocalizations.of(context)!.bodyPartBiceps,
      AppLocalizations.of(context)!.workout_d7e8733c: AppLocalizations.of(context)!.bodyPartBiceps,
      AppLocalizations.of(context)!.workout_6a8e2907: AppLocalizations.of(context)!.bodyPartBiceps,
      AppLocalizations.of(context)!.workout_2de38ba1: AppLocalizations.of(context)!.bodyPartBiceps,
      
      // 三頭
      AppLocalizations.of(context)!.workout_f2a8fd43: AppLocalizations.of(context)!.bodyPartTriceps,
      AppLocalizations.of(context)!.exercise_636fb74f: AppLocalizations.of(context)!.bodyPartTriceps,
      AppLocalizations.of(context)!.exerciseTricepsExtension: AppLocalizations.of(context)!.bodyPartTriceps,
      AppLocalizations.of(context)!.workout_41ae2e59: AppLocalizations.of(context)!.bodyPartTriceps,
      AppLocalizations.of(context)!.exercise_f6d35c01: AppLocalizations.of(context)!.bodyPartTriceps,
      AppLocalizations.of(context)!.exerciseKickback: AppLocalizations.of(context)!.bodyPartTriceps,
      AppLocalizations.of(context)!.exercise_a60f616c: AppLocalizations.of(context)!.bodyPartTriceps,
      
      // 有酸素
      AppLocalizations.of(context)!.exerciseRunning: AppLocalizations.of(context)!.exerciseCardio,
      AppLocalizations.of(context)!.workout_e23f084e: AppLocalizations.of(context)!.exerciseCardio,
      AppLocalizations.of(context)!.workout_57bd7c71: AppLocalizations.of(context)!.exerciseCardio,
      AppLocalizations.of(context)!.exerciseAerobicBike: AppLocalizations.of(context)!.exerciseCardio,
      AppLocalizations.of(context)!.workout_8308db37: AppLocalizations.of(context)!.exerciseCardio,
      AppLocalizations.of(context)!.workout_a19d7669: AppLocalizations.of(context)!.exerciseCardio,
      AppLocalizations.of(context)!.workout_4c6d7db7: AppLocalizations.of(context)!.exerciseCardio,
    };
  }
}
