/// 🔬 トレーニング効果分析画面
/// 
/// ユーザーのトレーニング履歴を分析し、
/// 最適なボリューム・頻度・回復時間を提案する画面
library;

import 'package:flutter/material.dart';
import '../../services/training_analysis_service.dart';
import '../../services/subscription_service.dart';
import '../../widgets/scientific_citation_card.dart';
import '../../screens/subscription_screen.dart';

/// トレーニング効果分析画面
class TrainingEffectAnalysisScreen extends StatefulWidget {
  const TrainingEffectAnalysisScreen({super.key});

  @override
  State<TrainingEffectAnalysisScreen> createState() =>
      _TrainingEffectAnalysisScreenState();
}

class _TrainingEffectAnalysisScreenState
    extends State<TrainingEffectAnalysisScreen> {
  // フォーム入力値
  final _formKey = GlobalKey<FormState>();
  String _selectedBodyPart = '大胸筋';
  String _selectedLevel = '初心者';
  int _currentSets = 12;
  int _currentFrequency = 2;
  String _selectedGender = '女性';
  int _selectedAge = 25;

  // サンプル履歴データ（実際にはFirestoreから取得）
  final List<Map<String, dynamic>> _sampleHistory = [
    {'week': 4, 'weight': 62, 'sets': 12},
    {'week': 3, 'weight': 60, 'sets': 12},
    {'week': 2, 'weight': 60, 'sets': 12},
    {'week': 1, 'weight': 60, 'sets': 12},
  ];

  // 分析結果
  Map<String, dynamic>? _analysisResult;
  bool _isLoading = false;  // ✅ 修正: 初期状態はローディングなし

  @override
  void initState() {
    super.initState();
    // ✅ 修正: 自動実行を削除（ユーザーが実行ボタンを押したときのみAI機能を使用）
    // 問題：画面起動時に入力前のデータで1回消費していた
  }

  // 選択肢
  final List<String> _bodyParts = [
    '大胸筋',
    '広背筋',
    '大腿四頭筋',
    '上腕二頭筋',
    '上腕三頭筋',
    '三角筋',
  ];
  final List<String> _levels = ['初心者', '中級者', '上級者'];

  /// 効果分析を実行
  Future<void> _executeAnalysis() async {
    if (!_formKey.currentState!.validate()) return;

    // 🔒 課金チェック: AI機能はプレミアム以上
    final subscriptionService = SubscriptionService();
    final hasAIAccess = await subscriptionService.isAIFeatureAvailable();
    
    if (!hasAIAccess) {
      // 無料プランユーザーは課金画面へ誘導
      if (mounted) {
        _showUpgradeDialog();
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // 🔢 AI使用回数チェック
    final canUseAI = await subscriptionService.canUseAIFeature();
    if (!canUseAI) {
      if (mounted) {
        final usageStatus = await subscriptionService.getAIUsageStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(usageStatus), backgroundColor: Colors.orange),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _analysisResult = null;
    });

    try {
      print('🚀 効果分析開始...');
      final result = await TrainingAnalysisService.analyzeTrainingEffect(
        bodyPart: _selectedBodyPart,
        level: _selectedLevel,
        currentSetsPerWeek: _currentSets,
        currentFrequency: _currentFrequency,
        recentHistory: _sampleHistory,
        gender: _selectedGender,
        age: _selectedAge,
      );
      print('✅ 効果分析完了: ${result['success']}');

      // ✅ AI使用回数をインクリメント
      await subscriptionService.incrementAIUsage();
      print('✅ AI使用回数: ${await subscriptionService.getCurrentMonthAIUsage()}');

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 効果分析例外: $e');
      if (mounted) {
        setState(() {
          _analysisResult = {
            'success': false,
            'error': '分析に失敗しました: $e',
          };
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング効果分析'),
        backgroundColor: Colors.purple.shade700,
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

                // 分析実行ボタン
                _buildAnalyzeButton(),
                const SizedBox(height: 32),

                // 分析結果
                if (_isLoading)
                  _buildLoadingIndicator()
                else if (_analysisResult != null)
                  _buildAnalysisResult(),
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
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.analytics, size: 40, color: Colors.purple.shade700),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'トレーニング効果分析',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '最適なボリューム・頻度・回復時間を提案',
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
              '現在のトレーニング情報',
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

            // 週あたりセット数
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderField(
                  label: 'この部位の週あたりセット数',
                  value: _currentSets.toDouble(),
                  min: 4,
                  max: 24,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() {
                      _currentSets = value.toInt();
                    });
                  },
                  displayValue: '${_currentSets}セット',
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ $_selectedBodyPart のトレーニングで週に実施する総セット数',
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

            // トレーニング頻度
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderField(
                  label: 'この部位のトレーニング頻度',
                  value: _currentFrequency.toDouble(),
                  min: 1,
                  max: 6,
                  divisions: 5,
                  onChanged: (value) {
                    setState(() {
                      _currentFrequency = value.toInt();
                    });
                  },
                  displayValue: '週${_currentFrequency}回',
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ $_selectedBodyPart を週に何回トレーニングするか',
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

  /// 分析実行ボタン
  Widget _buildAnalyzeButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _executeAnalysis,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple.shade700,
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
          Icon(Icons.analytics),
          SizedBox(width: 8),
          Text('効果分析を実行'),
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
          Text('トレーニング効果を分析中...'),
        ],
      ),
    );
  }

  /// 分析結果表示
  Widget _buildAnalysisResult() {
    // nullチェック
    if (_analysisResult == null) {
      return Card(
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('分析結果がありません'),
        ),
      );
    }

    // エラーチェック
    if (_analysisResult!['success'] != true) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    '分析エラー',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                _analysisResult!['error']?.toString() ?? '不明なエラーが発生しました',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ),
        ),
      );
    }

    // 必須フィールドの存在チェック
    if (!_analysisResult!.containsKey('volumeAnalysis') ||
        !_analysisResult!.containsKey('frequencyAnalysis')) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '分析データが不完全です。もう一度お試しください。',
            style: TextStyle(color: Colors.orange.shade900),
          ),
        ),
      );
    }

    final volumeAnalysis = _analysisResult!['volumeAnalysis'] as Map<String, dynamic>;
    final frequencyAnalysis = _analysisResult!['frequencyAnalysis'] as Map<String, dynamic>;
    final plateauDetected = _analysisResult!['plateauDetected'] as bool;
    final growthTrend = _analysisResult!['growthTrend'] as Map<String, dynamic>;
    final recommendations = _analysisResult!['recommendations'] as List;
    final basis = _analysisResult!['scientificBasis'] as List;
    final aiAnalysis = _analysisResult!['aiAnalysis'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ステータスサマリー
        _buildStatusSummary(volumeAnalysis, frequencyAnalysis, plateauDetected, growthTrend),
        const SizedBox(height: 16),

        // ボリューム分析
        _buildVolumeAnalysis(volumeAnalysis),
        const SizedBox(height: 16),

        // 頻度分析
        _buildFrequencyAnalysis(frequencyAnalysis),
        const SizedBox(height: 16),

        // プラトー警告
        if (plateauDetected) ...[
          _buildPlateauWarning(),
          const SizedBox(height: 16),
        ],

        // 推奨アクション
        _buildRecommendations(recommendations),
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

  /// ステータスサマリー
  Widget _buildStatusSummary(
    Map<String, dynamic> volume,
    Map<String, dynamic> frequency,
    bool plateau,
    Map<String, dynamic> trend,
  ) {
    Color statusColor;
    IconData statusIcon;
    String statusMessage;

    if (plateau) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusMessage = 'プラトー検出：改善が必要';
    } else if (volume['status'] == 'optimal' && frequency['status'] == 'optimal') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusMessage = '最適なトレーニング中';
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.info;
      statusMessage = '改善の余地あり';
    }

    return Card(
      color: statusColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(statusIcon, size: 48, color: statusColor),
            const SizedBox(height: 12),
            Text(
              statusMessage,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              trend['message'],
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// ボリューム分析
  Widget _buildVolumeAnalysis(Map<String, dynamic> analysis) {
    Color statusColor;
    switch (analysis['status']) {
      case 'optimal':
        statusColor = Colors.green;
        break;
      case 'insufficient':
      case 'suboptimal':
        statusColor = Colors.orange;
        break;
      case 'excessive':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: statusColor),
                const SizedBox(width: 8),
                const Text(
                  'ボリューム分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildVolumeBar(
              current: analysis['currentSets'],
              min: analysis['minSets'],
              optimal: analysis['optimalSets'],
              max: analysis['maxSets'],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                analysis['advice'],
                style: TextStyle(
                  fontSize: 13,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ボリュームバー
  Widget _buildVolumeBar({
    required int current,
    required int min,
    required int optimal,
    required int max,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('最小: ${min}'),
            Text('最適: $optimal', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('最大: ${max}'),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // 背景バー
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            // 最適範囲
            FractionallySizedBox(
              widthFactor: (max - min) / max,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 32,
                margin: EdgeInsets.only(left: (min / max * 100).toDouble()),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // 現在値
            FractionallySizedBox(
              widthFactor: current / max,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '現在: ${current}セット',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 頻度分析
  Widget _buildFrequencyAnalysis(Map<String, dynamic> analysis) {
    Color statusColor;
    switch (analysis['status']) {
      case 'optimal':
        statusColor = Colors.green;
        break;
      case 'low':
        statusColor = Colors.orange;
        break;
      case 'high':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: statusColor),
                const SizedBox(width: 8),
                const Text(
                  '頻度分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFrequencyItem(
                  '現在',
                  analysis['currentFrequency'],
                  Colors.blue,
                ),
                Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                _buildFrequencyItem(
                  '推奨',
                  analysis['recommendedFrequency'],
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                analysis['advice'],
                style: TextStyle(
                  fontSize: 13,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 頻度アイテム
  Widget _buildFrequencyItem(String label, int frequency, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Text(
            '週${frequency}回',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// プラトー警告
  Widget _buildPlateauWarning() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.warning, size: 40, color: Colors.orange.shade700),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'プラトー期を検出',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '4週間成長が停滞しています。プログラム変更を推奨します。',
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

  /// 推奨アクション
  Widget _buildRecommendations(List recommendations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  '推奨アクション',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendations.map((rec) {
              final recMap = rec as Map<String, dynamic>;
              Color priorityColor;
              switch (recMap['priority']) {
                case 'high':
                  priorityColor = Colors.red;
                  break;
                case 'medium':
                  priorityColor = Colors.orange;
                  break;
                default:
                  priorityColor = Colors.blue;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            recMap['category'],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          recMap['basis'],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recMap['action'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Markdownテキストのフォーマット
  Widget _buildFormattedText(String text) {
    final lines = text.split('\n');
    final List<Widget> widgets = [];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      if (line.trim().startsWith('##')) {
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
  
  /// 🔒 アップグレードダイアログ表示
  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('プレミアム機能'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI効果分析はプレミアムプラン以上でご利用いただけます。',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '✨ プレミアムプランの特典:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• AI成長予測（3ヶ月先の重量予測）'),
            Text('• AI効果分析（科学的根拠付き）'),
            Text('• トレーニングパートナー検索'),
            SizedBox(height: 16),
            Text(
              '月額 ¥980',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // サブスクリプション画面へ遷移
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            child: const Text('プランを見る'),
          ),
        ],
      ),
    );
  }
}
