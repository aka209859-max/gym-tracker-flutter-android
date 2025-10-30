import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gym.dart';
import '../providers/gym_provider.dart';

/// 混雑度報告画面
class CrowdReportScreen extends StatefulWidget {
  final Gym gym;

  const CrowdReportScreen({super.key, required this.gym});

  @override
  State<CrowdReportScreen> createState() => _CrowdReportScreenState();
}

class _CrowdReportScreenState extends State<CrowdReportScreen> {
  int _selectedCrowdLevel = 3;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('混雑度を報告'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ジム情報カード
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.gym.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[300],
                            child: const Icon(Icons.fitness_center),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.gym.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.gym.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 混雑度選択
            const Text(
              '現在の混雑度を選択してください',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildCrowdLevelSelector(),
            const SizedBox(height: 24),
            // コメント入力
            const Text(
              'コメント（任意）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '例: 平日の夕方は結構混んでます',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            // 送信ボタン
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitReport,
                child: const Text(
                  '報告を送信',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrowdLevelSelector() {
    return Column(
      children: List.generate(5, (index) {
        final level = index + 1;
        final isSelected = _selectedCrowdLevel == level;
        final color = _getCrowdLevelColor(level);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedCrowdLevel = level;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    color: isSelected ? color : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getCrowdLevelText(level),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? color : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCrowdLevelDescription(level),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: color, size: 28),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  void _submitReport() {
    // プロバイダー経由で混雑度を更新
    Provider.of<GymProvider>(context, listen: false)
        .updateCrowdLevel(widget.gym.id, _selectedCrowdLevel);

    // 成功メッセージ
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('混雑度を報告しました！'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );

    // 画面を閉じる
    Navigator.pop(context);
  }

  String _getCrowdLevelText(int level) {
    switch (level) {
      case 1:
        return '空いています';
      case 2:
        return 'やや空き';
      case 3:
        return '普通';
      case 4:
        return 'やや混雑';
      case 5:
        return '超混雑';
      default:
        return '不明';
    }
  }

  String _getCrowdLevelDescription(int level) {
    switch (level) {
      case 1:
        return 'ほとんど人がいません';
      case 2:
        return '少し人がいますが、余裕があります';
      case 3:
        return '適度に人がいます';
      case 4:
        return 'かなり混んでいます';
      case 5:
        return '非常に混雑しています';
      default:
        return '';
    }
  }

  Color _getCrowdLevelColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFF4CAF50); // Green
      case 2:
        return const Color(0xFF8BC34A); // Light Green
      case 3:
        return const Color(0xFFFFC107); // Amber
      case 4:
        return const Color(0xFFFF9800); // Orange
      case 5:
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }
}
