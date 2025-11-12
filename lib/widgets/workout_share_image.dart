import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/one_rm_calculator.dart';

/// トレーニングシェア用画像Widget
/// 
/// SNSシェア用の美しい画像を生成
class WorkoutShareImage extends StatelessWidget {
  final DateTime date;
  final List<WorkoutExerciseGroup> exercises;

  const WorkoutShareImage({
    super.key,
    required this.date,
    required this.exercises,
  });

  @override
  Widget build(BuildContext context) {
    // 動的な高さを計算（筋トレMEMO並みの密度で40行対応）
    // 基本高さ + (種目数 × 基本カード高さ) + (総セット数 × セット行高さ)
    final totalSets = exercises.fold<int>(0, (sum, ex) => sum + ex.sets.length);
    final baseHeight = 140.0; // ヘッダー + フッター（最小限）
    final exerciseCardBase = 65.0; // 種目名 + 最小マージン（大幅圧縮）
    final setRowHeight = 28.0; // 各セット行の高さ（筋トレMEMO並み）
    final dynamicHeight = baseHeight + (exercises.length * exerciseCardBase) + (totalSets * setRowHeight);
    
    return Container(
      width: 600,
      height: dynamicHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // ヘッダー
          _buildHeader(),
          
          // 種目カードリスト
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: exercises.map((exercise) => _buildExerciseCard(exercise)).toList(),
            ),
          ),
          
          // フッター
          _buildFooter(),
        ],
      ),
    );
  }

  /// ヘッダー（日付とブランディング）
  Widget _buildHeader() {
    final formattedDate = DateFormat('yyyy/MM/dd').format(date);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF3F51B5), // GYM MATCHブランドカラー
      ),
      child: Text(
        '$formattedDate WorkOut',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 種目カード
  Widget _buildExerciseCard(WorkoutExerciseGroup exercise) {
    // 最大1RMを計算
    final maxRMData = OneRMCalculator.findMaxRM(exercise.sets);
    final maxRM = maxRMData['maxRM'] as double;
    final maxSetIndex = maxRMData['setIndex'] as int;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 種目名とRM
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 種目名（1行で表示）
              Expanded(
                child: Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // RM値（右端に固定、改行なし）
              Text(
                'RM: ${OneRMCalculator.formatRM(maxRM)}kg',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F51B5),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // セット詳細
          ...exercise.sets.asMap().entries.map((entry) {
            final index = entry.key;
            final set = entry.value;
            final isMaxSet = index == maxSetIndex;
            final isBodyweightMode = set['is_bodyweight_mode'] as bool? ?? false;
            
            return _buildSetRow(
              index + 1,
              set['weight']?.toDouble() ?? 0.0,
              set['reps']?.toInt() ?? 0,
              isMaxSet,
              isBodyweightMode,
            );
          }),
        ],
      ),
    );
  }

  /// セット行（筋トレMEMO並みに圧縮）
  Widget _buildSetRow(int setNumber, double weight, int reps, bool isMax, bool isBodyweightMode) {
    final oneRM = OneRMCalculator.calculate(weight: weight, reps: reps);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // セット番号
          SizedBox(
            width: 20,
            child: Text(
              '$setNumber',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // 重量×回数（自重モードまたは重量0の場合は「自重」と表示）
          Expanded(
            child: Text(
              (isBodyweightMode || weight == 0.0)
                ? '自重 × $reps reps'
                : '$weight kg × $reps reps',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          
          // 1RM値
          Text(
            '(1RM:${OneRMCalculator.formatRM(oneRM)})',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(width: 4),
          
          // MAX RMバッジ
          if (isMax)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'MAX RM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// フッター（ブランディング）
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF3F51B5),
      ),
      child: const Center(
        child: Text(
          'Powered by GYM MATCH',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// トレーニング種目グループ
class WorkoutExerciseGroup {
  final String name;
  final List<Map<String, dynamic>> sets;

  WorkoutExerciseGroup({
    required this.name,
    required this.sets,
  });
}
