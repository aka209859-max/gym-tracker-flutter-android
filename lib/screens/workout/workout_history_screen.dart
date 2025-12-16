import 'package:flutter/material.dart';
import 'body_part_tracking_screen.dart';
import 'personal_records_screen.dart';
import 'workout_memo_list_screen.dart';
import 'weekly_reports_screen.dart';

/// トレーニング履歴画面
/// 
/// 4つのタブで構成:
/// - 部位別: BodyPartTrackingScreen
/// - PR記録: PersonalRecordsScreen
/// - メモ: WorkoutMemoListScreen
/// - 週次レポート: WeeklyReportsScreen
class WorkoutHistoryScreen extends StatelessWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'トレーニング履歴',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: theme.colorScheme.primary,
          elevation: 0,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: const [
              Tab(
                icon: Icon(Icons.accessibility_new),
                text: '部位別',
              ),
              Tab(
                icon: Icon(Icons.trending_up),
                text: 'PR記録',
              ),
              Tab(
                icon: Icon(Icons.note_add),
                text: 'メモ',
              ),
              Tab(
                icon: Icon(Icons.bar_chart),
                text: '週次',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Tab 1: 部位別トレーニング履歴
            BodyPartTrackingScreen(),
            
            // Tab 2: PR記録（個人記録）
            PersonalRecordsScreen(),
            
            // Tab 3: メモ一覧
            WorkoutMemoListScreen(),
            
            // Tab 4: 週次レポート
            WeeklyReportsScreen(),
          ],
        ),
      ),
    );
  }
}
