import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/fatigue_management_service.dart';

/// 疲労管理システム画面
class FatigueManagementScreen extends StatefulWidget {
  const FatigueManagementScreen({super.key});

  @override
  State<FatigueManagementScreen> createState() => _FatigueManagementScreenState();
}

class _FatigueManagementScreenState extends State<FatigueManagementScreen> {
  final FatigueManagementService _fatigueService = FatigueManagementService();
  
  bool _isEnabled = false;
  bool _isLoading = true;
  bool _hasWorkoutToday = false;
  bool _isEndingWorkout = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final enabled = await _fatigueService.isFatigueManagementEnabled();
    final hasWorkout = await _fatigueService.hasWorkoutToday();
    
    setState(() {
      _isEnabled = enabled;
      _hasWorkoutToday = hasWorkout;
      _isLoading = false;
    });
  }

  Future<void> _toggleFatigueManagement(bool value) async {
    await _fatigueService.setFatigueManagementEnabled(value);
    setState(() => _isEnabled = value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? '✅ 疲労管理システムを有効にしました' : '❌ 疲労管理システムを無効にしました',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _endTodayWorkout() async {
    if (!_isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('疲労管理システムをONにしてください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isEndingWorkout = true);

    try {
      // 本日のトレーニング記録を取得
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('ユーザーが認証されていません');
      }

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final querySnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThan: Timestamp.fromDate(todayEnd))
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('本日のトレーニング記録が見つかりません'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isEndingWorkout = false);
        return;
      }

      // トレーニング記録を分析
      int totalSets = 0;
      double totalVolumeLoad = 0.0;
      Set<String> bodyParts = {};
      int totalDuration = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final exercises = data['exercises'] as List<dynamic>? ?? [];
        
        for (final exercise in exercises) {
          final sets = exercise['sets'] as List<dynamic>? ?? [];
          totalSets += sets.length;
          
          for (final set in sets) {
            final weight = (set['weight_kg'] as num?)?.toDouble() ?? 0.0;
            final reps = (set['reps'] as num?)?.toInt() ?? 0;
            totalVolumeLoad += weight * reps;
          }
          
          final bodyPart = exercise['body_part'] as String? ?? '不明';
          bodyParts.add(bodyPart);
        }
      }

      // 最後のトレーニング日を保存
      await _fatigueService.saveLastWorkoutDate(DateTime.now());

      setState(() {
        _isEndingWorkout = false;
        _hasWorkoutToday = true;
      });

      // 疲労度アドバイスダイアログを表示
      if (mounted) {
        _showFatigueAdviceDialog(
          totalSets: totalSets,
          totalVolumeLoad: totalVolumeLoad,
          bodyParts: bodyParts.toList(),
          totalDuration: totalDuration,
        );
      }
    } catch (e) {
      setState(() => _isEndingWorkout = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ エラー: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showFatigueAdviceDialog({
    required int totalSets,
    required double totalVolumeLoad,
    required List<String> bodyParts,
    required int totalDuration,
  }) {
    // 簡易的な疲労度計算（今後Gemini調査結果で精緻化）
    double fatigueScore = 0.0;
    
    // セット数による疲労度（1セット = 2点）
    fatigueScore += totalSets * 2.0;
    
    // 部位数による疲労度（大筋群は追加）
    if (bodyParts.contains('脚')) fatigueScore += 15.0;
    if (bodyParts.contains('背中')) fatigueScore += 10.0;
    if (bodyParts.contains('胸')) fatigueScore += 8.0;
    
    // 疲労度レベルを判定
    String fatigueLevel;
    Color levelColor;
    String advice;
    String recoveryTime;
    IconData levelIcon;
    
    if (fatigueScore < 30) {
      fatigueLevel = '軽度';
      levelColor = Colors.green;
      levelIcon = Icons.sentiment_satisfied;
      advice = '良好なトレーニングでした！\n軽いストレッチと十分な水分補給をしましょう。';
      recoveryTime = '24時間';
    } else if (fatigueScore < 50) {
      fatigueLevel = '中程度';
      levelColor = Colors.blue;
      levelIcon = Icons.sentiment_neutral;
      advice = '適度な負荷のトレーニングでした。\n7-8時間の睡眠とタンパク質補給を心がけましょう。';
      recoveryTime = '36-48時間';
    } else if (fatigueScore < 70) {
      fatigueLevel = '高め';
      levelColor = Colors.orange;
      levelIcon = Icons.sentiment_dissatisfied;
      advice = '高強度のトレーニングでした。\n十分な休息と栄養補給が必要です。無理せず回復を優先しましょう。';
      recoveryTime = '48-72時間';
    } else {
      fatigueLevel = '極めて高い';
      levelColor = Colors.red;
      levelIcon = Icons.warning;
      advice = '非常に高強度のトレーニングでした。\n今日は完全休養を推奨します。睡眠・栄養・ストレッチを重視してください。';
      recoveryTime = '72時間以上';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(levelIcon, color: levelColor, size: 32),
            const SizedBox(width: 12),
            const Text('疲労度分析結果'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 疲労度スコア
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: levelColor, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      '疲労度レベル',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fatigueLevel,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: levelColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'スコア: ${fatigueScore.toInt()} / 100',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // トレーニング内容サマリー
              _buildInfoRow('総セット数', '$totalSets セット'),
              const SizedBox(height: 8),
              _buildInfoRow('総負荷量', '${totalVolumeLoad.toStringAsFixed(0)} kg'),
              const SizedBox(height: 8),
              _buildInfoRow('実施部位', bodyParts.join('、')),
              const SizedBox(height: 8),
              _buildInfoRow('推奨回復時間', recoveryTime),
              
              const Divider(height: 32),
              
              // アドバイス
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'アドバイス',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                advice,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              
              const SizedBox(height: 20),
              
              // 科学的根拠（プレースホルダー）
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.science, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '※ 科学的根拠に基づく詳細分析機能は近日実装予定',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('疲労管理システム'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('疲労管理システム'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // システム説明カード
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.blue[700], size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          '疲労管理システムとは？',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'トレーニング後の疲労度を科学的に分析し、'
                      '最適な回復期間とアドバイスを提供します。\n\n'
                      'オーバートレーニングを防ぎ、常にベストコンディションで'
                      'トレーニングできるようサポートします。',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // ON/OFFスイッチ
            Card(
              child: ListTile(
                leading: Icon(
                  _isEnabled ? Icons.toggle_on : Icons.toggle_off,
                  size: 40,
                  color: _isEnabled ? Colors.green : Colors.grey,
                ),
                title: const Text(
                  '疲労管理システム',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _isEnabled ? '有効' : '無効',
                  style: TextStyle(
                    color: _isEnabled ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Switch(
                  value: _isEnabled,
                  onChanged: _toggleFatigueManagement,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 全トレーニング終了ボタン
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isEndingWorkout ? null : _endTodayWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEnabled ? Colors.orange[700] : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isEndingWorkout
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            '本日の全トレーニング終了',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            
            // 注意事項
            if (_isEnabled) ...[
              Text(
                '💡 全トレーニング終了ボタンを押すと、本日のトレーニング記録を分析し、'
                '疲労度とアドバイスを表示します。',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.grey[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '疲労管理システムをONにしてください',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // 本日のトレーニング状況
            Card(
              child: ListTile(
                leading: Icon(
                  _hasWorkoutToday ? Icons.fitness_center : Icons.event_available,
                  color: _hasWorkoutToday ? Colors.green : Colors.grey,
                  size: 32,
                ),
                title: const Text('本日のトレーニング'),
                subtitle: Text(
                  _hasWorkoutToday ? '記録済み（分析完了）' : 'まだ記録がありません',
                  style: TextStyle(
                    color: _hasWorkoutToday ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
