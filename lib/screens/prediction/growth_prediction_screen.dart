/// 📈 AI成長予測画面
/// 
/// ユーザーの筋力成長を科学的根拠に基づいて予測し、
/// グラフと信頼区間で視覚化する画面
library;

import 'package:flutter/material.dart';
import '../../services/ai_prediction_service.dart';
import '../../widgets/scientific_citation_card.dart';

/// AI成長予測画面
class GrowthPredictionScreen extends StatefulWidget {
  const GrowthPredictionScreen({super.key});

  @override
  State<GrowthPredictionScreen> createState() => _GrowthPredictionScreenState();
}

class _GrowthPredictionScreenState extends State<GrowthPredictionScreen> {
  // フォーム入力値
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController(text: '60');
  String _selectedLevel = '初心者';
  int _selectedFrequency = 3;
  String _selectedGender = '女性';
  int _selectedAge = 25;
  String _selectedBodyPart = '大胸筋';

  // 予測結果
  Map<String, dynamic>? _predictionResult;
  bool _isLoading = false;

  // レベル選択肢
  final List<String> _levels = ['初心者', '中級者', '上級者'];

  // 部位選択肢
  final List<String> _bodyParts = [
    '大胸筋',
    '広背筋',
    '大腿四頭筋',
    '上腕二頭筋',
    '上腕三頭筋',
    '三角筋',
  ];

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  /// 成長予測を実行
  Future<void> _executePrediction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _predictionResult = null;
    });

    try {
      final result = await AIPredictionService.predictGrowth(
        currentWeight: double.parse(_weightController.text),
        level: _selectedLevel,
        frequency: _selectedFrequency,
        gender: _selectedGender,
        age: _selectedAge,
        bodyPart: _selectedBodyPart,
        monthsAhead: 4,
      );

      setState(() {
        _predictionResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('予測の生成に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI成長予測'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ヘッダー
                _buildHeader(),
                const SizedBox(height: 24),

                // 入力フォーム
                _buildInputForm(),
                const SizedBox(height: 24),

                // 予測実行ボタン
                _buildPredictButton(),
                const SizedBox(height: 32),

                // 予測結果
                if (_isLoading)
                  _buildLoadingIndicator()
                else if (_predictionResult != null)
                  _buildPredictionResult(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ヘッダー
  Widget _buildHeader() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.timeline, size: 40, color: Colors.blue.shade700),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI成長予測',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '40本以上の論文に基づく科学的予測',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 入力フォーム
  Widget _buildInputForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'あなたの情報を入力',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 対象部位
            _buildDropdownField(
              label: '対象部位',
              value: _selectedBodyPart,
              items: _bodyParts,
              onChanged: (value) {
                setState(() {
                  _selectedBodyPart = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 現在の1RM
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: '現在の1RM（kg）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fitness_center),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '1RMを入力してください';
                }
                final weight = double.tryParse(value);
                if (weight == null) {
                  return '数値を入力してください';
                }
                if (weight <= 0) {
                  return '1kg以上を入力してください';
                }
                if (weight > 500) {
                  return '500kg以下を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // トレーニングレベル
            _buildDropdownField(
              label: 'トレーニングレベル',
              value: _selectedLevel,
              items: _levels,
              onChanged: (value) {
                setState(() {
                  _selectedLevel = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // トレーニング頻度
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderField(
                  label: 'この部位のトレーニング頻度',
                  value: _selectedFrequency.toDouble(),
                  min: 1,
                  max: 6,
                  divisions: 5,
                  onChanged: (value) {
                    setState(() {
                      _selectedFrequency = value.toInt();
                    });
                  },
                  displayValue: '週${_selectedFrequency}回',
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ 選択した部位（$_selectedBodyPart）を週に何回トレーニングするか',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 性別
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('男性'),
                    value: '男性',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('女性'),
                    value: '女性',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 年齢
            _buildSliderField(
              label: '年齢',
              value: _selectedAge.toDouble(),
              min: 18,
              max: 70,
              divisions: 52,
              onChanged: (value) {
                setState(() {
                  _selectedAge = value.toInt();
                });
              },
              displayValue: '${_selectedAge}歳',
            ),
          ],
        ),
      ),
    );
  }

  /// ドロップダウンフィールド
  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  /// スライダーフィールド
  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
    required String displayValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              displayValue,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 予測実行ボタン
  Widget _buildPredictButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _executePrediction,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph),
          SizedBox(width: 8),
          Text('AI予測を実行'),
        ],
      ),
    );
  }

  /// ローディングインジケーター
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('AI予測を生成中...'),
        ],
      ),
    );
  }

  /// 予測結果表示
  Widget _buildPredictionResult() {
    if (_predictionResult == null || !_predictionResult!['success']) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _predictionResult?['error'] ?? '予測の生成に失敗しました',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final current = _predictionResult!['currentWeight'];
    final predicted = _predictionResult!['predictedWeight'];
    final growth = _predictionResult!['growthPercentage'];
    final ci = _predictionResult!['confidenceInterval'];
    final basis = _predictionResult!['scientificBasis'] as List;
    final aiAnalysis = _predictionResult!['aiAnalysis'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 予測結果サマリー
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 48,
                  color: Colors.green.shade700,
                ),
                const SizedBox(height: 16),
                const Text(
                  '4ヶ月後の予測',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${predicted.round()}kg',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '現在: ${current.round()}kg → +${growth}%の成長',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '信頼区間: ${ci['lower'].round()}-${ci['upper'].round()}kg',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 簡易グラフ表示
        _buildSimpleChart(current, predicted, ci),
        const SizedBox(height: 16),

        // AI分析
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'AI詳細分析',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFormattedText(aiAnalysis),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 科学的根拠
        ScientificBasisSection(
          basis: basis.cast<Map<String, String>>(),
        ),
        const SizedBox(height: 8),

        // 信頼度インジケーター
        Center(
          child: ConfidenceIndicator(paperCount: basis.length),
        ),
      ],
    );
  }

  /// 簡易グラフ表示
  Widget _buildSimpleChart(double current, double predicted, Map ci) {
    final maxValue = ci['upper'] * 1.1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '成長予測グラフ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 現在値
            _buildChartBar('現在', current, maxValue, Colors.blue),
            const SizedBox(height: 12),
            // 予測値
            _buildChartBar('4ヶ月後', predicted, maxValue, Colors.green),
            const SizedBox(height: 12),
            // 信頼区間上限
            _buildChartBar('最大予測', ci['upper'], maxValue, Colors.green.shade200),
          ],
        ),
      ),
    );
  }

  /// グラフバー
  Widget _buildChartBar(String label, double value, double maxValue, Color color) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${value.round()}kg',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 24,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  /// Markdownテキストのフォーマット
  Widget _buildFormattedText(String text) {
    final lines = text.split('\n');
    final List<Widget> widgets = [];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      if (line.trim().startsWith('##')) {
        // 見出し
        final heading = line.replaceFirst(RegExp(r'^##\s*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              heading,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        );
      } else {
        // 通常テキスト
        String processedLine = line;
        if (processedLine.trim().startsWith('*')) {
          processedLine = processedLine.replaceFirst(RegExp(r'^\*\s*'), '・');
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              processedLine,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
