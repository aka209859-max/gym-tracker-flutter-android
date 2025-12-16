import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/offline_service.dart'; // ✅ v1.0.161: オフライン対応

/// 体重・体脂肪率記録画面
class BodyMeasurementScreen extends StatefulWidget {
  const BodyMeasurementScreen({super.key});

  @override
  State<BodyMeasurementScreen> createState() => _BodyMeasurementScreenState();
}

// ✅ v1.0.158: グラフ表示オプション追加
enum ChartType { weight, bodyFat }
enum ChartPeriod { recent, all }

class _BodyMeasurementScreenState extends State<BodyMeasurementScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _bodyFatController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _measurements = [];
  
  // ✅ v1.0.158: グラフ設定
  ChartType _selectedChartType = ChartType.weight;
  ChartPeriod _selectedPeriod = ChartPeriod.recent;

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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ ユーザー未ログイン');
        return;
      }

      print('🔍 体重記録を取得中... user_id: ${user.uid}');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('body_measurements')
          .where('user_id', isEqualTo: user.uid)
          .get();

      print('📊 取得件数: ${querySnapshot.docs.length}');

      if (!mounted) return;
      
      // データを取得してソート
      final measurements = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date': (data['date'] as Timestamp).toDate(),
          'weight': data['weight'] as double?,
          'body_fat_percentage': data['body_fat_percentage'] as double?,
        };
      }).toList();
      
      // 日付でソート（降順）
      measurements.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      // 最新30件に絞る
      final limited = measurements.take(30).toList();
      
      setState(() {
        _measurements = limited;
      });
      
      print('✅ 体重記録読み込み完了: ${_measurements.length}件');
    } catch (e, stackTrace) {
      print('❌ 記録読み込みエラー: $e');
      print('スタックトレース: $stackTrace');
    } finally {
      if (!mounted) return;
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

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ユーザーが未ログイン');

      // ✅ v1.0.158: 日付 + 現在時刻を保存
      final now = DateTime.now();
      final dateTimeWithTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour,
        now.minute,
        now.second,
      );

      // ✅ v1.0.161: ネットワーク状態を確認
      final isOnline = await OfflineService.isOnline();
      
      if (isOnline) {
        // 🌐 オンラインモード: Firestore に保存
        await FirebaseFirestore.instance.collection('body_measurements').add({
          'user_id': user.uid,
          'date': Timestamp.fromDate(dateTimeWithTime),  // ✅ 時刻を含める
          'weight': weight,
          'body_fat_percentage': bodyFat,
          'created_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('記録を保存しました'), backgroundColor: Colors.green),
          );
        }
      } else {
        // 📴 オフラインモード: ローカルに保存
        await OfflineService.saveBodyMeasurementOffline({
          'user_id': user.uid,
          'date': dateTimeWithTime,
          'weight': weight,
          'body_fat_percentage': bodyFat,
          'created_at': now,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('📴 オフライン保存しました\nオンライン復帰時に自動同期されます'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      if (mounted) {
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
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// 削除確認ダイアログ
  Future<void> _confirmDelete(Map<String, dynamic> measurement) async {
    final date = measurement['date'] as DateTime;
    final weight = measurement['weight'] as double?;
    final bodyFat = measurement['body_fat_percentage'] as double?;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('記録を削除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('以下の記録を削除しますか？'),
            const SizedBox(height: 16),
            Text(
              DateFormat('yyyy年MM月dd日 HH:mm').format(date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (weight != null) Text('体重: ${weight.toStringAsFixed(1)}kg'),
            if (bodyFat != null) Text('体脂肪率: ${bodyFat.toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteMeasurement(measurement['id']);
    }
  }

  /// 記録を削除
  Future<void> _deleteMeasurement(String documentId) async {
    setState(() => _isLoading = true);

    try {
      print('🗑️ 記録を削除中... ID: $documentId');
      
      await FirebaseFirestore.instance
          .collection('body_measurements')
          .doc(documentId)
          .delete();

      print('✅ 記録を削除しました');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('記録を削除しました'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadMeasurements();  // グラフと履歴を更新
      }
    } catch (e) {
      print('❌ 削除エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('削除に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (!mounted) return;
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

  /// ✅ v1.0.159: 体重グラフ（タブ切り替え + 最新値表示改善）
  Widget _buildWeightChart(ThemeData theme) {
    if (_measurements.isEmpty) return const SizedBox.shrink();

    // 最新値を取得
    final sorted = List<Map<String, dynamic>>.from(_measurements)
      ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    final latest = sorted.first;
    final latestWeight = latest['weight'] as double?;
    final latestBodyFat = latest['body_fat_percentage'] as double?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ タブ切り替え（体重 / 体脂肪率）
            Row(
              children: [
                _buildTabButton(
                  label: '体重',
                  isSelected: _selectedChartType == ChartType.weight,
                  onTap: () => setState(() => _selectedChartType = ChartType.weight),
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  label: '体脂肪率',
                  isSelected: _selectedChartType == ChartType.bodyFat,
                  onTap: () => setState(() => _selectedChartType = ChartType.bodyFat),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // ✅ 最新値を横に表示（文字の重なりを解消）
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _selectedChartType == ChartType.weight ? '体重' : '体脂肪率',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                if (_selectedChartType == ChartType.weight && latestWeight != null)
                  Text(
                    latestWeight.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                if (_selectedChartType == ChartType.bodyFat && latestBodyFat != null)
                  Text(
                    latestBodyFat.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // グラフ本体
            SizedBox(
              height: 250,  // ✅ 数値ラベル表示のため高さを確保
              child: _buildLineChart(theme),
            ),
            
            const SizedBox(height: 16),
            
            // 期間切り替えスイッチ
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('最近', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                Switch(
                  value: _selectedPeriod == ChartPeriod.all,
                  onChanged: (value) {
                    setState(() {
                      _selectedPeriod = value ? ChartPeriod.all : ChartPeriod.recent;
                    });
                  },
                  activeColor: Colors.grey.shade400,
                ),
                Text('全て', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ 折れ線グラフ（画像①完全再現）
  Widget _buildLineChart(ThemeData theme) {
    // データを古い順にソート
    final sorted = List<Map<String, dynamic>>.from(_measurements)
      ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    
    // 期間フィルタリング
    final filtered = _selectedPeriod == ChartPeriod.recent
        ? sorted.take(10).toList()  // 最新10件
        : sorted;
    
    // スポットデータを生成
    final spots = <FlSpot>[];
    final values = <double>[];
    
    for (int i = 0; i < filtered.length; i++) {
      final value = _selectedChartType == ChartType.weight
          ? filtered[i]['weight'] as double?
          : filtered[i]['body_fat_percentage'] as double?;
      
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
        values.add(value);
      }
    }
    
    if (values.isEmpty) {
      return Center(child: Text('データがありません'));
    }
    
    // Y軸の範囲と間隔を計算（0.1刻み対応）
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    
    double interval;
    if (range <= 1.0) {
      interval = 0.1;
    } else if (range <= 2.0) {
      interval = 0.2;
    } else if (range <= 5.0) {
      interval = 0.5;
    } else if (range <= 10.0) {
      interval = 1.0;
    } else if (range <= 20.0) {
      interval = 2.0;
    } else {
      interval = 5.0;
    }
    
    final minY = ((minValue / interval).floor() * interval) - interval;
    final maxY = ((maxValue / interval).ceil() * interval) + interval;
    
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.grey.shade500,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isLatest = index == spots.length - 1;
                return FlDotCirclePainter(
                  radius: isLatest ? 7 : 5,
                  color: isLatest ? Colors.red : Colors.grey.shade700,
                  strokeWidth: 0,
                );
              },
            ),
            // ✅ データポイント上に数値を表示
            showingIndicators: List.generate(spots.length, (index) => index),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= filtered.length) return Text('');
                
                final date = filtered[index]['date'] as DateTime;
                final dateStr = DateFormat('MM.dd').format(date);
                final timeStr = DateFormat('HH:mm').format(date);
                
                return Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(dateStr, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      Text(timeStr, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                    ],
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: false,  // ✅ 画像①では左側の目盛りが非表示
            ),
          ),
        ),
        gridData: FlGridData(show: false),  // ✅ グリッド線を非表示
        borderData: FlBorderData(show: false),  // ✅ 枠線を非表示
        // ✅ 各ポイント上に数値を常時表示
        extraLinesData: ExtraLinesData(
          horizontalLines: spots.asMap().entries.map((entry) {
            final index = entry.key;
            final spot = entry.value;
            final isLatest = index == spots.length - 1;
            
            return HorizontalLine(
              y: spot.y,
              color: Colors.transparent,
              strokeWidth: 0,
              label: HorizontalLineLabel(
                show: !isLatest,  // ✅ 最新値はタイトル横に表示するため、グラフ上では非表示
                alignment: Alignment.topCenter,
                padding: EdgeInsets.only(bottom: 25),
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
                labelResolver: (line) => spot.y.toStringAsFixed(1),
              ),
            );
          }).toList(),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final date = filtered[index]['date'] as DateTime;
                final value = spot.y;
                
                final unit = _selectedChartType == ChartType.weight ? 'kg' : '%';
                
                return LineTooltipItem(
                  '${DateFormat('M/d').format(date)}\n${value.toStringAsFixed(1)}$unit',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    backgroundColor: Colors.black87,
                  ),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(color: Colors.grey, strokeWidth: 1, dashArray: [3, 3]),
                FlDotData(
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: Colors.red,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
              );
            }).toList();
          },
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
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(measurement),
                  tooltip: '削除',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// ✅ v1.0.159: タブボタンウィジェット
  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
