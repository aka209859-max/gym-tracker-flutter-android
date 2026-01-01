import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/visit_history_service.dart';
import '../models/gym.dart';
import 'gym_detail_screen.dart';

/// 訪問履歴画面
class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  final VisitHistoryService _visitHistoryService = VisitHistoryService();
  List<VisitHistory> _histories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVisitHistory();
    });
  }

  Future<void> _loadVisitHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final histories = await _visitHistoryService.getVisitHistory();

      setState(() {
        _histories = histories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '訪問履歴の読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteHistory(String historyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.general_5f7f67c7),
        content: Text(AppLocalizations.of(context)!.delete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _visitHistoryService.deleteVisitHistory(historyId);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.delete)),
          );
          _loadVisitHistory();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.deleteError)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.visitHistory),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVisitHistory,
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _histories.isEmpty
                  ? _buildEmptyView()
                  : _buildHistoryList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadVisitHistory,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.general_53b262c8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_history,
              size: 80,
              color: Colors.grey[300],
            ),
            SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noVisitHistory,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ジム詳細画面で「チェックイン」すると\nここに履歴が表示されます',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _histories.length,
      itemBuilder: (context, index) {
        final history = _histories[index];
        return _buildHistoryCard(history);
      },
    );
  }

  Widget _buildHistoryCard(VisitHistory history) {
    final dateFormat = DateFormat('yyyy/MM/dd (E)', 'ja_JP');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // ジム詳細画面へ遷移（簡易Gymオブジェクト生成）
          final gym = Gym(
            id: history.gymId,
            name: history.gymName,
            address: history.gymAddress,
            latitude: 0.0, // 詳細は不要
            longitude: 0.0,
            rating: 0.0,
            reviewCount: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GymDetailScreen(gym: gym),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 日付アイコン
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd').format(history.visitedAt),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      DateFormat('MMM', 'ja_JP').format(history.visitedAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // ジム情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      history.gymName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          timeFormat.format(history.visitedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      history.gymAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 削除ボタン
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
                onPressed: () => _deleteHistory(history.id),
                tooltip: AppLocalizations.of(context)!.delete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
