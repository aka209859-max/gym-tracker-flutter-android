import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/goal.dart';
import '../services/goal_service.dart';

/// 目標設定・管理画面
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with SingleTickerProviderStateMixin {
  final GoalService _goalService = GoalService();
  late TabController _tabController;

  List<Goal> _activeGoals = [];
  List<Goal> _completedGoals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGoals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 進捗を更新
      await _goalService.updateGoalProgress(user.uid);

      // 目標を取得
      final allGoals = await _goalService.getAllGoals(user.uid);

      setState(() {
        _activeGoals = allGoals.where((g) => g.isActive && !g.isExpired).toList();
        _completedGoals = allGoals.where((g) => g.isCompleted).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('目標の読み込みに失敗しました: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.active),
            Tab(text: AppLocalizations.of(context)!.general_45f91da4),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveGoalsTab(theme),
                _buildCompletedGoalsTab(theme),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGoalDialog,
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.general_6b0cabf8),
      ),
    );
  }

  /// アクティブな目標タブ
  Widget _buildActiveGoalsTab(ThemeData theme) {
    if (_activeGoals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.general_01b23520,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateGoalDialog,
              icon: Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.settings),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGoals,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeGoals.length,
        itemBuilder: (context, index) {
          final goal = _activeGoals[index];
          return _buildGoalCard(goal, theme, isActive: true);
        },
      ),
    );
  }

  /// 達成済み目標タブ
  Widget _buildCompletedGoalsTab(ThemeData theme) {
    if (_completedGoals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.general_46a04781,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedGoals.length,
      itemBuilder: (context, index) {
        final goal = _completedGoals[index];
        return _buildGoalCard(goal, theme, isActive: false);
      },
    );
  }

  /// 目標カード
  Widget _buildGoalCard(Goal goal, ThemeData theme, {required bool isActive}) {
    final progressColor = goal.isCompleted
        ? Colors.green
        : goal.progress >= 0.7
            ? Colors.orange
            : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isActive ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: goal.isCompleted
              ? Colors.green.withValues(alpha: 0.5)
              : isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: goal.isCompleted
              ? LinearGradient(
                  colors: [
                    Colors.green.withValues(alpha: 0.1),
                    Colors.green.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getGoalIcon(goal.iconName),
                      color: progressColor,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${goal.period == GoalPeriod.weekly ? AppLocalizations.of(context)!.thisWeek : AppLocalizations.of(context)!.thisMonth}の目標',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (goal.isCompleted)
                    const Icon(Icons.check_circle, color: Colors.green, size: 32)
                  else if (isActive)
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showGoalOptions(goal),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 進捗表示
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${goal.currentValue} / ${goal.targetValue} ${goal.unit}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                  Text(
                    '${goal.progressPercent}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // プログレスバー
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              
              if (isActive && !goal.isCompleted) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '残り${goal.daysRemaining}日',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
              
              if (goal.isCompleted && goal.completedAt != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.celebration, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      '達成日: ${goal.completedAt!.month}/${goal.completedAt!.day}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 目標アイコンを取得
  IconData _getGoalIcon(String iconName) {
    switch (iconName) {
      case 'event_repeat':
        return Icons.event_repeat;
      case 'fitness_center':
        return Icons.fitness_center;
      default:
        return Icons.flag;
    }
  }

  /// 目標オプションメニューを表示
  void _showGoalOptions(Goal goal) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              goal.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // 目標値変更
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: Text(AppLocalizations.of(context)!.general_fbfd31d9),
              onTap: () {
                Navigator.pop(context);
                _showEditGoalDialog(goal);
              },
            ),
            const Divider(),
            // 削除
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text(AppLocalizations.of(context)!.remove, style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _showDeleteConfirmDialog(goal.name);
                if (confirmed == true) {
                  await _goalService.deleteGoal(goal.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.delete)),
                    );
                  }
                  _loadGoals();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 削除確認ダイアログ
  Future<bool?> _showDeleteConfirmDialog(String goalName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.delete),
        content: Text('「$goalName」を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.remove),
          ),
        ],
      ),
    );
  }

  /// 目標作成ダイアログ
  void _showCreateGoalDialog() {
    GoalType selectedType = GoalType.weeklyWorkoutCount;
    GoalPeriod selectedPeriod = GoalPeriod.weekly;
    int targetValue = 3;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.settings),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 目標タイプ選択
                  Text(AppLocalizations.of(context)!.general_654c46cb, style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<GoalType>(
                    value: selectedType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: GoalType.weeklyWorkoutCount,
                        child: Text(AppLocalizations.of(context)!.general_e9b451c8),
                      ),
                      DropdownMenuItem(
                        value: GoalType.monthlyTotalWeight,
                        child: Text(AppLocalizations.of(context)!.general_12bffb53),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedType = value;
                          selectedPeriod = value == GoalType.weeklyWorkoutCount
                              ? GoalPeriod.weekly
                              : GoalPeriod.monthly;
                          targetValue = value == GoalType.weeklyWorkoutCount ? 3 : 10000;
                        });
                      }
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 目標値入力
                  Text(AppLocalizations.of(context)!.targetValue, style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextFormField(
                    initialValue: targetValue.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      suffixText: selectedType == GoalType.weeklyWorkoutCount ? AppLocalizations.of(context)!.reps : AppLocalizations.of(context)!.kg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        targetValue = int.tryParse(value) ?? targetValue;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ヒント表示
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue[700], size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedType == GoalType.weeklyWorkoutCount
                                ? AppLocalizations.of(context)!.general_1350619b
                                : AppLocalizations.of(context)!.settings,
                            style: TextStyle(fontSize: 12, color: Colors.blue[900]),
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
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  
                  try {
                    await _goalService.createGoal(
                      userId: user.uid,
                      type: selectedType,
                      period: selectedPeriod,
                      targetValue: targetValue,
                    );
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.settings)),
                      );
                    }
                    
                    _loadGoals();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.settings)),
                      );
                    }
                  }
                },
                child: Text(AppLocalizations.of(context)!.settings),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 目標編集ダイアログ
  void _showEditGoalDialog(Goal goal) {
    int newTargetValue = goal.targetValue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${goal.name}を編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: goal.targetValue.toString(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.targetValue,
                border: const OutlineInputBorder(),
                suffixText: goal.unit,
              ),
              onChanged: (value) {
                newTargetValue = int.tryParse(value) ?? goal.targetValue;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                await _goalService.updateGoal(goal.id, targetValue: newTargetValue);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.general_583ed93e)),
                  );
                }
                
                _loadGoals();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('更新に失敗しました: $e')),
                  );
                }
              }
            },
            child: Text(AppLocalizations.of(context)!.update),
          ),
        ],
      ),
    );
  }
}
