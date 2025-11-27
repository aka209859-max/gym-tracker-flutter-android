import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// 体重・体脂肪率記録画面
class BodyMeasurementScreen extends StatefulWidget {
  const BodyMeasurementScreen({super.key});

  @override
  State<BodyMeasurementScreen> createState() => _BodyMeasurementScreenState();
}

class _BodyMeasurementScreenState extends State<BodyMeasurementScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _bodyFatController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _measurements = [];

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    super.dispose();
  }

  /// 記録を読み込み
  Future<void> _loadMeasurements() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('body_measurements')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .limit(30) // 最新30件
          .get();

      setState(() {
        _measurements = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'date': (data['date'] as Timestamp).toDate(),
            'weight': data['weight'] as double?,
            'body_fat_percentage': data['body_fat_percentage'] as double?,
          };
        }).toList();
      });
    } catch (e) {
      print('❌ 記録読み込みエラー: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 記録を保存
  Future<void> _saveMeasurement() async {
    final weight = double.tryParse(_weightController.text);
    final bodyFat = double.tryParse(_bodyFatController.text);

    if (weight == null && bodyFat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('体重または体脂肪率を入力してください')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ユーザーが未ログイン');

      await FirebaseFirestore.instance.collection('body_measurements').add({
        'user_id': user.uid,
        'date': Timestamp.fromDate(_selectedDate),
        'weight': weight,
        'body_fat_percentage': bodyFat,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('記録を保存しました'), backgroundColor: Colors.green),
        );
        _weightController.clear();
        _bodyFatController.clear();
        _loadMeasurements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 日付選択
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('体重・体脂肪率'),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 入力カード
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '今日の記録',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          
                          // 日付選択
                          InkWell(
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '日付',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                DateFormat('yyyy年MM月dd日').format(_selectedDate),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // 体重入力
                          TextField(
                            controller: _weightController,
                            decoration: const InputDecoration(
                              labelText: '体重 (kg)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.monitor_weight),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.next,
                            onEditingComplete: () => FocusScope.of(context).nextFocus(),
                          ),
                          const SizedBox(height: 16),
                          
                          // 体脂肪率入力
                          TextField(
                            controller: _bodyFatController,
                            decoration: const InputDecoration(
                              labelText: '体脂肪率 (%)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.analytics),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.done,
                            onEditingComplete: () => FocusScope.of(context).unfocus(),
                          ),
                          const SizedBox(height: 16),
                          
                          // 保存ボタン
                          ElevatedButton(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              _saveMeasurement();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('記録を保存', style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // グラフ
                  if (_measurements.isNotEmpty) ...[
                    _buildWeightChart(theme),
                    const SizedBox(height: 24),
                  ],
                  
                  // 履歴リスト
                  _buildHistoryList(theme),
                ],
              ),
            ),
      ),
    );
  }

  /// 体重グラフ
  Widget _buildWeightChart(ThemeData theme) {
    final weightData = _measurements
        .where((m) => m['weight'] != null)
        .map((m) => FlSpot(
              m['date'].millisecondsSinceEpoch.toDouble(),
              m['weight'] as double,
            ))
        .toList()
        .reversed
        .toList();

    if (weightData.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '体重の推移',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: weightData,
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 履歴リスト
  Widget _buildHistoryList(ThemeData theme) {
    if (_measurements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.analytics_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                '記録がありません',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '記録履歴',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _measurements.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final measurement = _measurements[index];
              final date = measurement['date'] as DateTime;
              final weight = measurement['weight'] as double?;
              final bodyFat = measurement['body_fat_percentage'] as double?;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.calendar_today,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                title: Text(DateFormat('yyyy年MM月dd日').format(date)),
                subtitle: Row(
                  children: [
                    if (weight != null) Text('体重: ${weight.toStringAsFixed(1)}kg'),
                    if (weight != null && bodyFat != null) const Text('  •  '),
                    if (bodyFat != null) Text('体脂肪率: ${bodyFat.toStringAsFixed(1)}%'),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
