import 'package:flutter/material.dart';
import 'package:gym_match/gen/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            l10n.workoutHistory,
            style: const TextStyle(
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
            tabs: [
              Tab(
                icon: const Icon(Icons.accessibility_new),
                text: l10n.byBodyPart,
              ),
              Tab(
                icon: const Icon(Icons.trending_up),
                text: l10n.personalRecords,
              ),
              Tab(
                icon: const Icon(Icons.note_add),
                text: l10n.memo,
              ),
              Tab(
                icon: const Icon(Icons.bar_chart),
                text: l10n.weeklyReport,
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
