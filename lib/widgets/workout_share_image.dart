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
    return Container(
      width: 600,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー
          _buildHeader(),
          
          // 種目カードリスト
          Padding(
            padding: const EdgeInsets.all(16),
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF3F51B5), // GYM MATCHブランドカラー
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$formattedDate WorkOut',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            '🏋️',
            style: TextStyle(fontSize: 28),
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 種目名とRM
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exercise.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'RM: ${OneRMCalculator.formatRM(maxRM)}kg',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F51B5),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // セット詳細
          ...exercise.sets.asMap().entries.map((entry) {
            final index = entry.key;
            final set = entry.value;
            final isMaxSet = index == maxSetIndex;
            
            return _buildSetRow(
              index + 1,
              set['weight']?.toDouble() ?? 0.0,
              set['reps']?.toInt() ?? 0,
              isMaxSet,
            );
          }),
        ],
      ),
    );
  }

  /// セット行
  Widget _buildSetRow(int setNumber, double weight, int reps, bool isMax) {
    final oneRM = OneRMCalculator.calculate(weight: weight, reps: reps);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // セット番号
          SizedBox(
            width: 30,
            child: Text(
              '$setNumber',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          
          // 重量×回数
          Expanded(
            child: Text(
              '$weight kg × $reps reps',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
          
          // 1RM値
          Text(
            '(1RM:${OneRMCalculator.formatRM(oneRM)})',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(width: 8),
          
          // MAX RMバッジ
          if (isMax)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'MAX',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF3F51B5),
      ),
      child: const Center(
        child: Text(
          'Powered by GYM MATCH 💪',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
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
