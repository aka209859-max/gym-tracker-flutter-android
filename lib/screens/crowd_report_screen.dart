import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/gym.dart';
import '../providers/gym_provider.dart';
import '../services/crowd_report_incentive_service.dart';

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
  
  // 🎁 インセンティブ機能追加
  final CrowdReportIncentiveService _incentiveService = CrowdReportIncentiveService();
  int _userReportCount = 0;
  NextMilestone? _nextMilestone;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserReportStatus();
  }
  
  /// ユーザーの報告状況を読み込み
  Future<void> _loadUserReportStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final count = await _incentiveService.getUserReportCount(user.uid);
        final next = await _incentiveService.getNextMilestone(user.uid);
        
        if (mounted) {
          setState(() {
            _userReportCount = count;
            _nextMilestone = next;
          });
        }
      }
    } catch (e) {
      print('❌ 報告状況読み込みエラー: $e');
    }
  }

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
            // 🎁 報酬進捗カード
            if (_nextMilestone != null) _buildRewardProgressCard(),
            if (_nextMilestone != null) const SizedBox(height: 16),
            
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

  /// 混雑度報告を送信（インセンティブ統合）
  Future<void> _submitReport() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 🎁 混雑度報告 + インセンティブ報酬を付与
      // Note: GymProviderの更新は削除（Google Places gym IDと互換性なし）
      // Firebase経由で混雑度を保存し、次回のジム読み込み時に反映される
      final result = await _incentiveService.submitCrowdReport(
        gymId: widget.gym.id,
        crowdLevel: _selectedCrowdLevel,
      );
      
      if (mounted) {
        if (result.success) {
          // 3. マイルストーン報酬ダイアログ表示
          if (result.milestone != null) {
            await _showMilestoneRewardDialog(result.milestone!);
          } else {
            // 通常報酬のみ表示
            _showRewardSnackBar(result);
          }
          
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('❌ Crowd report error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  /// 報酬スナックバー表示
  void _showRewardSnackBar(ReportRewardResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ ${result.message}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('🎁 AI 1回分をプレゼント！（報告${result.reportCount}回目）'),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// マイルストーン報酬ダイアログ表示
  Future<void> _showMilestoneRewardDialog(MilestoneReward milestone) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              milestone.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              milestone.description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('ありがとう！'),
            ),
          ],
        ),
      ),
    );
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
  
  /// 報酬進捗カード
  Widget _buildRewardProgressCard() {
    if (_nextMilestone == null) return const SizedBox.shrink();
    
    final progress = _userReportCount / _nextMilestone!.target;
    
    return Card(
      color: Colors.orange.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '次の報酬まであと${_nextMilestone!.remaining}回！',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation(Colors.orange),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '報告回数: $_userReportCount回',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '目標: ${_nextMilestone!.target}回',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '報酬: ${_nextMilestone!.reward}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
