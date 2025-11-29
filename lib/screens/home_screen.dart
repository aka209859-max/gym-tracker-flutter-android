import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import 'workout/add_workout_screen.dart';
import 'workout/rm_calculator_screen.dart';
import 'workout/ai_coaching_screen_tabbed.dart';
import 'workout/template_screen.dart';
import 'workout/workout_log_screen.dart';
import 'workout/statistics_dashboard_screen.dart';
import 'achievements_screen.dart';
import 'goals_screen.dart';
import '../models/workout_log.dart' as workout_models;
import '../models/goal.dart';
import '../services/achievement_service.dart';
import '../services/goal_service.dart';
import '../services/share_service.dart';
import '../services/workout_share_service.dart';
import '../services/fatigue_management_service.dart';
import '../services/advanced_fatigue_service.dart';
import '../models/user_profile.dart';
import '../widgets/workout_share_card.dart';
import '../widgets/workout_share_image.dart';
import '../providers/navigation_provider.dart';
import '../services/admob_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/paywall_trigger_service.dart';
import '../widgets/paywall_dialog.dart';
import '../services/ai_credit_service.dart';
import '../services/subscription_service.dart';

import '../services/reminder_service.dart';
import '../services/habit_formation_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  List<Map<String, dynamic>> _selectedDayWorkouts = [];
  bool _isLoading = false;
  
  // トレーニング記録がある日付のセット
  Set<DateTime> _workoutDates = {};
  
  // 種目ごとの展開状態を管理
  Map<String, bool> _expandedExercises = {};
  
  // 統計データ
  double _last7DaysVolume = 0.0;
  double _currentMonthVolume = 0.0;
  double _totalVolume = 0.0;
  
  // 日数カウンター（MONTHLY ARCHIVE & TOTAL）
  int _monthlyActiveDays = 0;  // 今月のワークアウト日数
  int _totalDaysFromStart = 0;  // 初回記録からの経過日数
  
  // Task 14: 検索・フィルター機能
  final TextEditingController _searchController = TextEditingController();
  String? _selectedMuscleGroupFilter;
  DateTimeRange? _dateRangeFilter;
  List<Map<String, dynamic>> _filteredWorkouts = [];
  
  // 📱 AdMob広告関連
  final AdMobService _adMobService = AdMobService();
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  
  // Task 16: バッジシステム
  final AchievementService _achievementService = AchievementService();
  Map<String, int> _badgeStats = {'total': 0, 'unlocked': 0, 'locked': 0};
  
  // Task 17: 目標システム
  final GoalService _goalService = GoalService();
  List<Goal> _activeGoals = [];
  
  // Task 27: SNSシェア
  final ShareService _shareService = ShareService();
  
  // 疲労管理システム
  final FatigueManagementService _fatigueService = FatigueManagementService();
  final AdvancedFatigueService _advancedFatigueService = AdvancedFatigueService();
  
  // 🔔 リマインダーシステム
  final ReminderService _reminderService = ReminderService();
  bool _show48HourReminder = false;
  bool _show7DayInactiveReminder = false;
  
  // 🔥 習慣形成システム
  final HabitFormationService _habitService = HabitFormationService();
  int _currentStreak = 0;
  Map<String, int> _weeklyProgress = {'current': 0, 'goal': 3};
  List<Map<String, dynamic>> _topTrainingDays = [];
  
  // 詳細セクションの表示/非表示状態
  bool _isAdvancedSectionsExpanded = false;
  
  // SetType説明一覧の表示/非表示状態
  bool _showSetTypeExplanation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDay = _focusedDay;
    // 空セットをクリーンアップしてからデータ読み込み
    _cleanupEmptySets().then((_) {
      _loadWorkoutDates(); // トレーニング記録がある日付を読み込む
      _loadWorkoutsForSelectedDay();
      _loadBadgeStats();
      _loadActiveGoals();
      _loadStatistics(); // 統計データを読み込む
      
      // 🎯 Day 7ペイウォールトリガーチェック
      _checkDay7Paywall();
      
      // 🔔 リマインダーチェック
      _checkReminders();
      
      // 🔥 習慣形成データ読み込み
      _loadHabitData();
    });
    
    // 📱 バナー広告をロード
    _loadBannerAd();
  }
  
  /// Day 7ペイウォールをチェックして表示
  Future<void> _checkDay7Paywall() async {
    // initState完了後に遅延実行（UIが安定してから表示）
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final paywallService = PaywallTriggerService();
    final shouldShow = await paywallService.shouldShowDay7Paywall();
    
    if (shouldShow && mounted) {
      await PaywallDialog.show(context, PaywallType.day7Achievement);
      await paywallService.markDay7PaywallShown();
    }
  }
  
  /// 🔔 リマインダーをチェック
  Future<void> _checkReminders() async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    
    // 7日連続達成リマインダーをチェック（ダイアログ）
    final shouldShow7DayStreak = await _reminderService.shouldShow7DayStreakReminder();
    if (shouldShow7DayStreak && mounted) {
      await _show7DayStreakDialog();
      await _reminderService.markStreak7DayReminderShown();
      return; // ダイアログ表示したら他のリマインダーは表示しない
    }
    
    // 48時間経過リマインダーをチェック（カード表示）
    final shouldShow48Hour = await _reminderService.shouldShow48HourReminder();
    
    // 7日間未記録リマインダーをチェック（カード表示）
    final shouldShow7DayInactive = await _reminderService.shouldShow7DayInactiveReminder();
    
    if (mounted) {
      setState(() {
        _show48HourReminder = shouldShow48Hour;
        _show7DayInactiveReminder = shouldShow7DayInactive;
      });
      
      // 7日間未記録リマインダーを表示済みとしてマーク
      if (shouldShow7DayInactive) {
        await _reminderService.markInactive7DayReminderShown();
      }
    }
  }
  
  /// 7日連続達成ダイアログを表示
  Future<void> _show7DayStreakDialog() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.shade50,
                Colors.deepOrange.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🎉 アイコン
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration,
                  size: 48,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              
              // タイトル
              const Text(
                '7日連続達成！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 12),
              
              // メッセージ
              const Text(
                'おめでとうございます！\n7日間連続でトレーニングを記録しました。\nこの調子で続けましょう！💪',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              
              // 閉じるボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ありがとう！',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 🔥 習慣形成データを読み込む
  Future<void> _loadHabitData() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (!mounted) return;
    
    // 連続トレーニング日数を取得
    final streak = await _habitService.getCurrentStreak();
    
    // 今週の進捗を取得
    final weeklyProgress = await _habitService.getWeeklyProgress();
    
    // 最もトレーニングしている曜日TOP3を取得
    final topDays = await _habitService.getTopTrainingDays();
    
    if (mounted) {
      setState(() {
        _currentStreak = streak;
        _weeklyProgress = weeklyProgress;
        _topTrainingDays = topDays;
      });
      
      // マイルストーン達成チェック
      await _checkMilestone();
    }
  }
  
  /// マイルストーン達成をチェックして表示
  Future<void> _checkMilestone() async {
    if (!mounted) return;
    
    final milestone = await _habitService.checkMilestone();
    if (milestone != null && mounted) {
      await _showMilestoneDialog(milestone);
      await _habitService.markMilestoneShown(milestone);
    }
  }
  
  /// マイルストーン達成ダイアログを表示
  Future<void> _showMilestoneDialog(HabitMilestone milestone) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade50,
                Colors.deepPurple.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🏆 トロフィーアイコン
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 48,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 16),
              
              // タイトル
              Text(
                milestone.message,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 12),
              
              // メッセージ
              const Text(
                'すごい！マイルストーン達成です！\nこの調子で続けていきましょう！💪',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              
              // 閉じるボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ありがとう！',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// バナー広告を読み込む
  Future<void> _loadBannerAd() async {
    await _adMobService.loadBannerAd(
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() {
            _bannerAd = ad;
            _isAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint('バナー広告読み込み失敗: $error');
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // NavigationProviderのtargetDateを監視
    final navigationProvider = Provider.of<NavigationProvider>(
      context, 
      listen: true,
    );
    
    // 対象日付が設定されている場合、その日を選択
    if (navigationProvider.targetDate != null) {
      final targetDate = navigationProvider.targetDate!;
      print('📅 [HomeScreen] 対象日付を受信: ${targetDate.year}/${targetDate.month}/${targetDate.day}');
      
      setState(() {
        _selectedDay = targetDate;
        _focusedDay = targetDate;
      });
      
      // データを再読み込み
      _loadWorkoutsForSelectedDay();
      
      // targetDateをクリア（次回の遷移のため）
      Future.delayed(const Duration(milliseconds: 500), () {
        navigationProvider.clearTargetDate();
      });
    }
  }
  
  // Task 16: バッジ統計を読み込む
  Future<void> _loadBadgeStats() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // バッジを初期化（初回のみ）
      await _achievementService.initializeUserBadges(user.uid);
      
      // バッジをチェックして更新
      await _achievementService.checkAndUpdateBadges(user.uid);
      
      // 統計を取得
      final stats = await _achievementService.getBadgeStats(user.uid);
      setState(() {
        _badgeStats = stats;
      });
    } catch (e) {
      print('❌ バッジ統計の読み込みエラー: $e');
    }
  }
  
  // Task 17: アクティブな目標を読み込む
  Future<void> _loadActiveGoals() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // 進捗を更新
      await _goalService.updateGoalProgress(user.uid);
      
      // アクティブな目標を取得
      final goals = await _goalService.getActiveGoals(user.uid);
      setState(() {
        _activeGoals = goals.where((g) => !g.isExpired).toList();
      });
    } catch (e) {
      print('❌ 目標の読み込みエラー: $e');
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _bannerAd?.dispose();  // 📱 バナー広告を破棄
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // アプリが foreground に戻った時に自動リフレッシュ
      print('🔄 アプリがアクティブになりました - データを再読み込み');
      _loadWorkoutDates(); // トレーニング記録日付も再読み込み
      _loadWorkoutsForSelectedDay();
      _loadStatistics(); // 統計データも再読み込み
    }
  }
  
  /// 統計データと日数カウンターを計算して読み込む
  Future<void> _loadStatistics() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      print('📊 統計データを計算中...');
      
      // 全トレーニング記録を取得（シンプルクエリ - インデックス不要）
      final querySnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .get();
      
      print('📊 全記録件数: ${querySnapshot.docs.length}');
      
      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _last7DaysVolume = 0.0;
          _currentMonthVolume = 0.0;
          _totalVolume = 0.0;
          _monthlyActiveDays = 0;
          _totalDaysFromStart = 0;
        });
        return;
      }
      
      // 基準日
      final now = DateTime.now();
      final last7DaysStart = now.subtract(const Duration(days: 7));
      final currentMonthStart = DateTime(now.year, now.month, 1);
      
      double last7DaysVolume = 0.0;
      double currentMonthVolume = 0.0;
      double totalVolume = 0.0;
      
      // 🆕 日数カウンター用の変数
      DateTime? firstWorkoutDate;
      Set<String> monthlyWorkoutDates = {};  // 今月のワークアウト日（重複除去）
      
      // 各トレーニング記録を処理
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        final sets = data['sets'] as List<dynamic>? ?? [];
        
        if (date == null) continue;
        
        // 🆕 最初のワークアウト日を記録
        if (firstWorkoutDate == null || date.isBefore(firstWorkoutDate)) {
          firstWorkoutDate = date;
        }
        
        // 🆕 今月のワークアウト日をカウント
        if (date.year == now.year && date.month == now.month) {
          final dateKey = '${date.year}-${date.month}-${date.day}';
          monthlyWorkoutDates.add(dateKey);
        }
        
        // この記録の総負荷量を計算
        double workoutVolume = 0.0;
        for (final set in sets) {
          if (set is Map<String, dynamic>) {
            final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
            final reps = (set['reps'] as num?)?.toInt() ?? 0;
            workoutVolume += (weight * reps);
          }
        }
        
        // トンに変換
        workoutVolume = workoutVolume / 1000.0;
        
        // 期間別に集計
        totalVolume += workoutVolume;
        
        if (date.isAfter(last7DaysStart)) {
          last7DaysVolume += workoutVolume;
        }
        
        if (date.isAfter(currentMonthStart)) {
          currentMonthVolume += workoutVolume;
        }
      }
      
      // 🆕 日数計算（バグ修正: 最低値を1に設定）
      int totalDaysFromStart = 0;
      if (firstWorkoutDate != null) {
        // 初回記録から今日までの日数（+1で最低値1を保証）
        totalDaysFromStart = now.difference(firstWorkoutDate).inDays + 1;
        print('📅 初回ワークアウト: ${firstWorkoutDate.year}/${firstWorkoutDate.month}/${firstWorkoutDate.day}');
        print('📅 経過日数: $totalDaysFromStart日');
      }
      
      final monthlyActiveDays = monthlyWorkoutDates.length;
      print('📅 今月のアクティブ日数: $monthlyActiveDays日');
      
      print('✅ 統計計算完了:');
      print('   7日間: ${last7DaysVolume.toStringAsFixed(2)}t');
      print('   今月: ${currentMonthVolume.toStringAsFixed(2)}t');
      print('   全期間: ${totalVolume.toStringAsFixed(2)}t');
      
      setState(() {
        _last7DaysVolume = last7DaysVolume;
        _currentMonthVolume = currentMonthVolume;
        _totalVolume = totalVolume;
        _monthlyActiveDays = monthlyActiveDays;
        _totalDaysFromStart = totalDaysFromStart;
      });
      
    } catch (e) {
      print('❌ 統計データの計算エラー: $e');
      setState(() {
        _last7DaysVolume = 0.0;
        _currentMonthVolume = 0.0;
        _totalVolume = 0.0;
        _monthlyActiveDays = 0;
        _totalDaysFromStart = 0;
      });
    }
  }

  /// トレーニング記録がある日付を読み込む（カレンダーマーカー用）
  Future<void> _loadWorkoutDates() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      print('📅 トレーニング記録日付を取得中...');
      
      // 全トレーニング記録の日付を取得
      final querySnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .get();
      
      final workoutDates = <DateTime>{};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        
        if (date != null) {
          // 時刻を正規化（日付のみを使用）
          final normalizedDate = DateTime(date.year, date.month, date.day);
          workoutDates.add(normalizedDate);
        }
      }
      
      print('✅ トレーニング記録日付: ${workoutDates.length}日');
      
      setState(() {
        _workoutDates = workoutDates;
      });
      
    } catch (e) {
      print('❌ トレーニング記録日付の取得エラー: $e');
    }
  }

  // トレーニング記録をシェア
  Future<void> _handleShare() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      // ログイン不要でシェア機能を利用可能にする

      if (_selectedDay == null || _selectedDayWorkouts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('シェアできるトレーニング記録がありません'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 種目ごとにグループ化（home_screen表示ロジックと同じ構造）
      final exerciseMap = <String, List<Map<String, dynamic>>>{};
      
      for (final workout in _selectedDayWorkouts) {
        final sets = workout['sets'] as List<dynamic>?;
        
        if (sets != null) {
          for (final set in sets) {
            final setData = set as Map<String, dynamic>;
            final name = setData['exercise_name'] as String? ?? '不明な種目';
            
            if (!exerciseMap.containsKey(name)) {
              exerciseMap[name] = [];
            }
            
            exerciseMap[name]!.add({
              'weight': setData['weight'] ?? 0,
              'reps': setData['reps'] ?? 0,
            });
          }
        }
      }

      // WorkoutExerciseGroupリストに変換
      final exerciseGroups = exerciseMap.entries.map((entry) {
        return WorkoutExerciseGroup(
          name: entry.key,
          sets: entry.value,
        );
      }).toList();

      if (exerciseGroups.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('シェアできる種目がありません'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // シェア実行
      final shareService = WorkoutShareService();
      await shareService.shareWorkout(
        context: context,
        date: _selectedDay!,
        exercises: exerciseGroups,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('シェアに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 選択した日のトレーニング記録を読み込む
  Future<void> _loadWorkoutsForSelectedDay() async {
    if (_selectedDay == null) return;

    print('🔍 トレーニング記録を読み込み開始...');
    print('📅 選択日: ${_selectedDay!.year}/${_selectedDay!.month}/${_selectedDay!.day}');

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ ユーザーが未ログインです');
        // ユーザーが未ログインの場合もローディング終了
        if (mounted) {
          setState(() {
            _selectedDayWorkouts = [];
            _isLoading = false;
          });
        }
        return;
      }

      print('👤 User ID: ${user.uid}');

      // シンプルなクエリ（インデックス不要）
      print('🔍 ユーザーの全記録を取得中...');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .get(const GetOptions(source: Source.server));

      print('📊 全記録件数: ${querySnapshot.docs.length}');

      // 選択した日（年・月・日のみ）
      final selectedDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);

      print('🕐 選択日: $selectedDate (${selectedDate.year}/${selectedDate.month}/${selectedDate.day})');

      // メモリ内でフィルタリング
      final allWorkouts = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'muscle_group': data['muscle_group'],
          'start_time': data['start_time'],
          'end_time': data['end_time'],
          'sets': data['sets'] as List<dynamic>,
          'date': (data['date'] as Timestamp).toDate(),
        };
      }).toList();

      print('📊 全ワークアウト詳細:');
      for (var i = 0; i < allWorkouts.length; i++) {
        final workout = allWorkouts[i];
        final workoutDate = workout['date'] as DateTime;
        final normalizedDate = DateTime(workoutDate.year, workoutDate.month, workoutDate.day);
        print('   [$i] date=${workoutDate.toIso8601String()}, normalized=${normalizedDate.year}/${normalizedDate.month}/${normalizedDate.day}, muscle=${workout['muscle_group']}');
      }

      // 選択した日のデータだけをフィルタ（時刻を無視して年月日のみで比較）
      final filteredWorkouts = allWorkouts.where((workout) {
        final workoutDate = workout['date'] as DateTime;
        // 時刻を無視して日付のみで比較
        final normalizedWorkoutDate = DateTime(workoutDate.year, workoutDate.month, workoutDate.day);
        final isMatch = normalizedWorkoutDate.isAtSameMomentAs(selectedDate);
        
        if (!isMatch) {
          print('   ⚠️ 除外: ${workoutDate.toIso8601String()} (normalized: ${normalizedWorkoutDate.year}/${normalizedWorkoutDate.month}/${normalizedWorkoutDate.day})');
        }
        
        return isMatch;
      }).toList();

      // 日付で降順ソート
      filteredWorkouts.sort((a, b) {
        final dateA = a['date'] as DateTime;
        final dateB = b['date'] as DateTime;
        return dateB.compareTo(dateA);
      });

      print('✅ フィルタ後: ${filteredWorkouts.length}件');
      
      // 詳細ログ: 各ワークアウトの情報を表示
      for (var i = 0; i < filteredWorkouts.length; i++) {
        final workout = filteredWorkouts[i];
        print('   [$i] ID=${workout['id']}, muscle_group=${workout['muscle_group']}, sets=${(workout['sets'] as List).length}');
      }

      if (mounted) {
        setState(() {
          _selectedDayWorkouts = filteredWorkouts;
          _isLoading = false;
        });
      }

      print('✅ データ読み込み完了: ${_selectedDayWorkouts.length}件');
    } catch (e) {
      print('❌ トレーニング記録の読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _selectedDayWorkouts = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'トレーニング記録',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        actions: [
          // 開発者メニュー（デバッグモードのみ表示）
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.developer_mode),
              tooltip: '開発者メニュー',
              onPressed: () {
                Navigator.pushNamed(context, '/developer_menu');
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsMenu(context),
            tooltip: '設定',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // カレンダーと統計を横並びに配置
            _buildCalendarAndStatsSection(theme),
            
            const SizedBox(height: 16),
            
            // 🔔 リマインダーカード
            if (_show48HourReminder)
              _build48HourReminderCard(theme),
            if (_show7DayInactiveReminder)
              _build7DayInactiveReminderCard(theme),
            
            // 🔥 習慣形成サポートカード
            if (_currentStreak > 0 || _weeklyProgress['current']! > 0)
              _buildHabitFormationCard(theme),
            
            // トグルボタン（疲労管理・目標・アクションの表示/非表示切替）
            _buildAdvancedSectionsToggle(theme),
            
            // 展開可能な詳細セクション
            if (_isAdvancedSectionsExpanded) ...[
              const SizedBox(height: 16),
              
              // Phase 2: 疲労管理を上位表示（意思決定支援強化）
              _buildFatigueManagementSection(theme),
              
              const SizedBox(height: 16),
              
              // Phase 2: 目標を上位表示（目標勾配効果最大化）
              _buildGoalsSection(theme),
              
              const SizedBox(height: 16),
              
              // Phase 2: サブアクションボタン（テンプレートのみ）
              _buildActionButtons(theme),
            ],
            
            const SizedBox(height: 16),
            
            // 月間サマリー統計
            _buildMonthlySummary(theme),
            
            // 📱 バナー広告表示（無料プランのみ）
            if (_isAdLoaded && _bannerAd != null)
              Container(
                margin: const EdgeInsets.only(top: 16, bottom: 16),
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            
            const SizedBox(height: 80), // FAB用のスペース確保
          ],
        ),
      ),
      // FloatingActionButton（画面右下固定）
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddWorkoutScreen(),
            ),
          );
          
          // 保存が成功した場合、データを再読み込み
          if (result == true) {
            await _loadWorkoutsForSelectedDay();
            await _loadWorkoutDates(); // カレンダーのマーカーも更新
            await _loadStatistics(); // 統計データも即座に更新
            await _loadHabitData(); // 🔥 習慣形成データも更新
          }
        },
        icon: const Icon(Icons.add, size: 24),
        label: const Text(
          'トレーニング記録',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 6.0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // 詳細セクションのトグルボタン
  Widget _buildAdvancedSectionsToggle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          setState(() {
            _isAdvancedSectionsExpanded = !_isAdvancedSectionsExpanded;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isAdvancedSectionsExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _isAdvancedSectionsExpanded
                    ? '詳細セクションを閉じる'
                    : '詳細セクションを表示（疲労管理・目標）',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarAndStatsSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // カレンダー（コンパクトな週表示）
          _buildCalendarCard(theme),
          
          const SizedBox(height: 12),
          
          // 💡 今日のAI提案カード
          _buildAISuggestionCard(theme),
          
          const SizedBox(height: 12),
          
          // 統計カード（タブ切替式・タップで統計ダッシュボードへ）
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StatisticsDashboardScreen(),
                ),
              );
            },
            child: DefaultTabController(
              length: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TabBar(
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: theme.colorScheme.primary,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      tabs: const [
                        Tab(text: '7日間'),
                        Tab(text: '月間'),
                        Tab(text: '総負荷量'),
                      ],
                    ),
                    SizedBox(
                      height: 80,
                      child: TabBarView(
                        children: [
                          _buildStatTabContent(
                            value: _last7DaysVolume.toStringAsFixed(2),
                            unit: 't',
                            theme: theme,
                          ),
                          _buildStatTabContent(
                            value: _currentMonthVolume.toStringAsFixed(2),
                            unit: 't',
                            theme: theme,
                          ),
                          _buildStatTabContent(
                            value: _totalVolume.toStringAsFixed(2),
                            unit: 't',
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 統計ダッシュボードへのヒントテキスト
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'タップして詳細統計を表示',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // タブコンテンツ（統計値表示）
  Widget _buildStatTabContent({
    required String value,
    required String unit,
    required ThemeData theme,
  }) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  // 💡 今日のAI提案カード
  Widget _buildAISuggestionCard(ThemeData theme) {
    return FutureBuilder<int>(
      future: AICreditService().getAICredits().then((credits) async {
        final plan = await SubscriptionService().getCurrentPlan();
        if (plan != SubscriptionType.free) {
          return await SubscriptionService().getRemainingAIUsage();
        }
        return credits;
      }),
      builder: (context, snapshot) {
        final remainingCredits = snapshot.data ?? 0;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade700, Colors.purple.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '💡 今日のAI提案',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'AI残回数: $remainingCredits回',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'あなた専用のトレーニングメニューを\nAIが科学的に分析します',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: remainingCredits > 0
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AICoachingScreenTabbed(initialTabIndex: 0),
                                ),
                              );
                            }
                          : () async {
                              await PaywallDialog.show(
                                context,
                                PaywallType.aiLimitReached,
                              );
                            },
                      icon: Icon(
                        remainingCredits > 0
                            ? Icons.psychology
                            : Icons.lock,
                        size: 18,
                      ),
                      label: Text(
                        remainingCredits > 0
                            ? 'AIメニューを作成'
                            : 'AI回数を追加',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.purple.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// 🔔 48時間経過リマインダーカード
  Widget _build48HourReminderCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.lightBlue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fitness_center,
              color: Colors.blue,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'トレーニングのお知らせ 💪',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '前回のトレーニングから2日経過しました。\n今日もトレーニングしませんか？',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _show48HourReminder = false;
              });
            },
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
  
  /// 🔔 7日間未記録リマインダーカード
  Widget _build7DayInactiveReminderCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restart_alt,
              color: Colors.orange,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'お久しぶりです 🏋️',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'しばらくトレーニングを記録していませんね。\nまた始めませんか？',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _show7DayInactiveReminder = false;
              });
            },
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
  
  /// 🔥 習慣形成サポートカード
  Widget _buildHabitFormationCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.teal.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '🔥 あなたの習慣',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 連続記録ストリーク
          if (_currentStreak > 0) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: Colors.deepOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '連続 $_currentStreak 日',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_currentStreak}日連続記録中！',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // 週間進捗
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '今週のトレーニング',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${_weeklyProgress['current']}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Text(
                          ' / ${_weeklyProgress['goal']}回',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 進捗バー
              Expanded(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_weeklyProgress['current']! /
                                _weeklyProgress['goal']!)
                            .clamp(0.0, 1.0),
                        backgroundColor: Colors.green.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.green.shade600,
                        ),
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${((_weeklyProgress['current']! / _weeklyProgress['goal']!) * 100).clamp(0, 100).toInt()}% 達成',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // よくトレーニングする曜日
          if (_topTrainingDays.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.green),
            const SizedBox(height: 12),
            const Text(
              '💡 あなたのトレーニングパターン',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _topTrainingDays.take(3).map((day) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${day['weekday']} (${day['count']}回)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  // ミニ統計カード（チャートなし・数値のみ）
  Widget _buildMiniStatCard({
    required String title,
    required String value,
    required String unit,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard({
    required String title,
    required String value,
    required String unit,
    required ThemeData theme,
    List<double>? chartData,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (chartData != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(chartData.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FractionallySizedBox(
                        heightFactor: chartData[index],
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          // 選択した日のトレーニング記録を読み込む
          _loadWorkoutsForSelectedDay();
        },
        availableCalendarFormats: const {
          CalendarFormat.month: '月',
        },
        eventLoader: (day) {
          // この日にトレーニング記録があるかチェック
          final normalizedDay = DateTime(day.year, day.month, day.day);
          return _workoutDates.contains(normalizedDay) ? ['workout'] : [];
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: theme.colorScheme.secondary,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 1,
          todayTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // サブアクションボタン（トグル展開時のみ表示）
          Row(
            children: [
              // テンプレート管理
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TemplateScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.library_books, size: 18, color: theme.colorScheme.primary),
                  label: const Text(
                    'テンプレート',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: theme.colorScheme.primary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // RM計算機
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RMCalculatorScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.calculate, size: 18, color: theme.colorScheme.primary),
                  label: const Text(
                    'RM計算',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: theme.colorScheme.primary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // AI科学的コーチング（統合版）
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade50, Colors.purple.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.shade200, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.deepPurple.shade700, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '🔬 AI科学的コーチング（統合版）',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '40本以上の論文に基づく科学的トレーニング支援',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                // AI残回数表示
                FutureBuilder<int>(
                  future: AICreditService().getAICredits().then((credits) async {
                    final plan = await SubscriptionService().getCurrentPlan();
                    if (plan != SubscriptionType.free) {
                      return await SubscriptionService().getRemainingAIUsage();
                    }
                    return credits;
                  }),
                  builder: (context, snapshot) {
                    final remainingCredits = snapshot.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: remainingCredits > 0
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: remainingCredits > 0
                              ? Colors.green.shade200
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            remainingCredits > 0
                                ? Icons.check_circle
                                : Icons.warning,
                            size: 14,
                            color: remainingCredits > 0
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI残回数: $remainingCredits回/月',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: remainingCredits > 0
                                  ? Colors.green.shade900
                                  : Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AICoachingScreenTabbed(initialTabIndex: 1),
                            ),
                          );
                        },
                        icon: Icon(Icons.timeline, size: 18, color: Colors.deepPurple.shade700),
                        label: Text(
                          '成長予測',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: Colors.deepPurple.shade300, width: 1.5),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AICoachingScreenTabbed(initialTabIndex: 2),
                            ),
                          );
                        },
                        icon: Icon(Icons.analytics, size: 18, color: Colors.orange.shade700),
                        label: Text(
                          '効果分析',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: Colors.orange.shade300, width: 1.5),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 日付比較ヘルパー
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  // 空のセット（0kg x 0回）をクリーンアップ
  Future<void> _cleanupEmptySets() async {
    try {
      print('🧹 空セットのクリーンアップ開始...');
      
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .get();
      
      int cleanedCount = 0;
      final now = DateTime.now();
      final cleanupThreshold = now.subtract(const Duration(hours: 24)); // 24時間前
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final sets = List<Map<String, dynamic>>.from(data['sets'] as List? ?? []);
        
        // 作成日時を確認（24時間以内のデータはスキップ）
        final createdAt = (data['created_at'] as Timestamp?)?.toDate();
        if (createdAt != null && createdAt.isAfter(cleanupThreshold)) {
          // 24時間以内のデータはクリーンアップしない（入力途中の可能性）
          continue;
        }
        
        // 有効なセットだけをフィルタ（重量または回数が0より大きい）
        final validSets = sets.where((set) {
          final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
          final reps = set['reps'] as int? ?? 0;
          // 重量0かつ回数0のセットは無効
          return weight > 0 || reps > 0;
        }).toList();
        
        if (validSets.length != sets.length) {
          // 空セットが見つかった
          if (validSets.isEmpty) {
            // 全セットが空の場合、ドキュメント削除
            print('   🗑️ 空データ削除: ${doc.id} (作成: ${createdAt?.toString() ?? "不明"})');
            await FirebaseFirestore.instance
                .collection('workout_logs')
                .doc(doc.id)
                .delete();
            cleanedCount++;
          } else {
            // 有効なセットだけを保存
            print('   🧹 空セット削除: ${doc.id} (${sets.length} → ${validSets.length})');
            await FirebaseFirestore.instance
                .collection('workout_logs')
                .doc(doc.id)
                .update({'sets': validSets});
            cleanedCount++;
          }
        }
      }
      
      if (cleanedCount > 0) {
        print('✅ クリーンアップ完了: ${cleanedCount}件');
        _loadWorkoutsForSelectedDay();
      } else {
        print('✅ クリーンアップ不要');
      }
    } catch (e) {
      print('❌ クリーンアップエラー: $e');
    }
  }
  
  // 1RM計算式（Epley formula - より正確で高回数にも対応）
  double _calculate1RM(double weight, int reps) {
    if (reps == 1) return weight;
    // Epley式: 1RM = 重量 × (1 + 回数 / 30)
    // 高回数でも正確に計算できる
    return weight * (1 + reps / 30.0);
  }
  
  // ワークアウトセット削除（ワンタップ削除）
  Future<void> _deleteWorkoutSet(String workoutId, int setIndex) async {
    try {
      print('🗑️ セット削除開始: Workout ID=$workoutId, Set Index=$setIndex');
      
      // ドキュメントを取得
      final docSnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .doc(workoutId)
          .get();
      
      if (!docSnapshot.exists) {
        print('❌ ドキュメントが見つかりません');
        return;
      }
      
      final data = docSnapshot.data();
      if (data == null) {
        print('❌ ドキュメントデータが存在しません');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('データの取得に失敗しました')),
          );
        }
        return;
      }
      
      final sets = List<Map<String, dynamic>>.from(data['sets'] as List? ?? []);
      
      // 指定されたセットを削除
      sets.removeAt(setIndex);
      
      if (sets.isEmpty) {
        // セットがすべて削除された場合、ドキュメント全体を削除
        await FirebaseFirestore.instance
            .collection('workout_logs')
            .doc(workoutId)
            .delete();
        
        print('✅ 全セット削除 - ドキュメント削除完了');
      } else {
        // セットリストを更新
        await FirebaseFirestore.instance
            .collection('workout_logs')
            .doc(workoutId)
            .update({'sets': sets});
        
        print('✅ セット削除完了 - 残りセット数: ${sets.length}');
      }
      
      // データを再読み込み
      _loadWorkoutsForSelectedDay();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('セットを削除しました')),
        );
      }
    } catch (e) {
      print('❌ セット削除エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除エラー: $e')),
        );
      }
    }
  }

  Widget _buildMonthlySummary(ThemeData theme) {
    // エンプティステート判定（データなし時）
    if (_totalDaysFromStart == 0 && _monthlyActiveDays == 0) {
      return Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 64,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'さあ、最初の記録を始めましょう！',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'トレーニングを記録して、\n進捗を可視化しましょう',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildWorkoutHistory(theme),
        ],
      );
    }
    
    // 通常表示（データあり時）
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.calendar_month,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'MONTHLY ARCHIVE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '$_monthlyActiveDays',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'days',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_totalDaysFromStart days',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // トレーニング履歴
        _buildWorkoutHistory(theme),
      ],
    );
  }

  Widget _buildWorkoutHistory(ThemeData theme) {
    // Firestoreから読み込んだ実際のデータを使用
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    if (_selectedDayWorkouts.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '${_selectedDay!.month}月${_selectedDay!.day}日のトレーニング記録はありません',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 種目ごとにデータをグループ化
    final Map<String, List<Map<String, dynamic>>> exerciseGroups = {};
    
    for (var workout in _selectedDayWorkouts) {
      final sets = workout['sets'] as List<dynamic>? ?? [];
      for (var i = 0; i < sets.length; i++) {
        final set = sets[i];
        final exerciseName = set['exercise_name'] as String? ?? '不明な種目';
        
        if (!exerciseGroups.containsKey(exerciseName)) {
          exerciseGroups[exerciseName] = [];
          // デフォルトで展開状態にする
          _expandedExercises[exerciseName] ??= true;
        }
        
        exerciseGroups[exerciseName]!.add({
          'workout_id': workout['id'],
          'set_index': i,
          'exercise': exerciseName,
          'weight': set['weight'],
          'reps': set['reps'],
          'has_assist': set['has_assist'] ?? false, // 補助有無を追加
          'setType': set['set_type'] ?? 'normal', // スーパーセット等のタイプ（DBはsnake_case）
          'dropsetLevel': set['dropset_level'] as int?, // ドロップセットレベル（DBはsnake_case、null許容）
          'muscle_group': workout['muscle_group'],
          'start_time': workout['start_time'],
          'end_time': workout['end_time'],
        });
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.fitness_center,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedDay != null && _isSameDay(_selectedDay!, DateTime.now())
                            ? '今日のトレーニング'
                            : '${_selectedDay!.month}月${_selectedDay!.day}日のトレーニング',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // シェアボタン
                    if (_selectedDayWorkouts.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.share, size: 20),
                        onPressed: () => _handleShare(),
                        tooltip: 'トレーニングをシェア',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          
          // SetType説明一覧（トグル表示）
          if (_selectedDayWorkouts.isNotEmpty)
            Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _showSetTypeExplanation = !_showSetTypeExplanation;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'セットタイプの見方',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _showSetTypeExplanation 
                            ? Icons.keyboard_arrow_up 
                            : Icons.keyboard_arrow_down,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showSetTypeExplanation)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSetTypeExplanationRow(
                          Icons.heat_pump,
                          Colors.orange,
                          'WU',
                          'ウォームアップセット',
                          '本番前の準備セット',
                        ),
                        const SizedBox(height: 8),
                        _buildSetTypeExplanationRow(
                          Icons.compare_arrows,
                          Colors.purple,
                          'SS',
                          'スーパーセット',
                          '連続で行う2種目',
                        ),
                        const SizedBox(height: 8),
                        _buildSetTypeExplanationRow(
                          Icons.trending_down,
                          Colors.blue,
                          'DS',
                          'ドロップセット',
                          '重量を落として限界まで',
                        ),
                        const SizedBox(height: 8),
                        _buildSetTypeExplanationRow(
                          Icons.local_fire_department,
                          Colors.red,
                          '限界',
                          '限界セット',
                          '完全に力尽きるまで',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          
          // 種目ごとのセクション
          ...exerciseGroups.entries.map((entry) {
            final exerciseName = entry.key;
            final sets = entry.value;
            final isExpanded = _expandedExercises[exerciseName] ?? true;
            
            // muscle_groupを取得（有酸素判定用）
            // ワークアウト全体のmuscle_groupを取得（セットではなくワークアウトレベル）
            final muscleGroup = _selectedDayWorkouts.isNotEmpty 
                ? (_selectedDayWorkouts.first['muscle_group'] as String? ?? '') 
                : '';
            final isCardio = muscleGroup == '有酸素';
            
            if (kDebugMode) {
              print('種目: $exerciseName, muscle_group: $muscleGroup, isCardio: $isCardio');
            }
            
            // 合計セット数、合計レップ数を計算
            final totalSets = sets.length;
            final totalReps = sets.fold<int>(0, (sum, set) => sum + (set['reps'] as int));
            
            // 記録のIDを取得（削除・編集用）
            // ✅ 修正: 各種目の最初のセットからworkout_idを取得（正しいワークアウトIDを使用）
            final workoutId = sets.isNotEmpty ? sets[0]['workout_id'] as String? : null;
            
            return Dismissible(
              key: Key('${workoutId}_$exerciseName'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete, color: Colors.white, size: 32),
                    SizedBox(height: 4),
                    Text('削除', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              confirmDismiss: (direction) async {
                print('🔔 削除確認ダイアログ表示: $exerciseName (ID: $workoutId)');
                return await _showDeleteConfirmDialog(exerciseName);
              },
              onDismissed: (direction) async {
                print('👆 スワイプ削除実行: $exerciseName (ID: $workoutId)');
                // ❌ _deleteWorkout(workoutId); // これはワークアウト全体を削除してしまう
                // ✅ 特定の種目だけを削除する
                await _deleteExerciseFromWorkout(workoutId, exerciseName);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 種目ヘッダー（赤い背景）
                    InkWell(
                      onTap: () {
                        setState(() {
                          _expandedExercises[exerciseName] = !isExpanded;
                        });
                      },
                      onLongPress: () {
                        _showEditDeleteMenu(workoutId, exerciseName);
                      },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF2E3192), // 深い青紫
                            Color(0xFFE85D75), // オレンジがかった赤
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              exerciseName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // 編集ボタン（トレーニング記録画面に遷移）
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              if (mounted) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const WorkoutLogScreen(),
                                  ),
                                );
                                _loadWorkoutsForSelectedDay();
                              }
                            },
                            tooltip: 'トレーニング記録を編集',
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // セットリスト（展開時のみ表示）
                  if (isExpanded) ...[
                    // テーブルヘッダー
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      color: Colors.grey[100],
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 24,
                            child: Text(
                              'セット',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              isCardio ? '時間' : '重さ',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              isCardio ? '距離' : '回数',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          if (!isCardio)
                            Expanded(
                              flex: 2,
                              child: Text(
                                'RM',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          if (isCardio) const Spacer(flex: 2),
                          const SizedBox(
                            width: 24,
                            child: Text(
                              '補助',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                        ],
                      ),
                    ),
                    
                    // セット行
                    ...sets.asMap().entries.map((setEntry) {
                      final setNumber = setEntry.key + 1;
                      final set = setEntry.value;
                      final oneRM = _calculate1RM(set['weight'] as double, set['reps'] as int);
                      
                      // SetTypeを取得
                      final setTypeStr = set['setType'] as String? ?? 'normal';
                      final setType = workout_models.SetType.values.firstWhere(
                        (e) => e.name == setTypeStr,
                        orElse: () => workout_models.SetType.normal,
                      );
                      final dropsetLevel = set['dropsetLevel'] as int?;
                      
                      // 🆕 SetTypeによる背景色の色分け
                      Color backgroundColor;
                      switch (setType) {
                        case workout_models.SetType.warmup:
                          backgroundColor = Colors.orange.withValues(alpha: 0.05);
                          break;
                        case workout_models.SetType.superset:
                          backgroundColor = Colors.purple.withValues(alpha: 0.05);
                          break;
                        case workout_models.SetType.dropset:
                          backgroundColor = Colors.blue.withValues(alpha: 0.05);
                          break;
                        case workout_models.SetType.failure:
                          backgroundColor = Colors.red.withValues(alpha: 0.05);
                          break;
                        default:
                          backgroundColor = Colors.white;
                      }
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            // セット番号（左端）
                            SizedBox(
                              width: 24,
                              child: Text(
                                '$setNumber',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // SetTypeバッジ（通常セットは表示しない）
                            if (setType != workout_models.SetType.normal) ...[
                              _buildSetTypeBadge(setType, dropsetLevel),
                              const SizedBox(width: 4),
                            ],
                            // 重量
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isCardio 
                                      ? '${set['weight']} 分' 
                                      : (set['is_bodyweight_mode'] == true && set['weight'] == 0.0)
                                        ? '自重'
                                        : '${set['weight']} Kg',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isCardio ? '${set['reps']} km' : '${set['reps']} 回',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isCardio)
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${oneRM.toStringAsFixed(1)}Kg',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (isCardio) const Spacer(flex: 2),
                            SizedBox(
                              width: 24,
                              child: set['has_assist'] == true
                                  ? const Icon(
                                      Icons.people,
                                      size: 14,
                                      color: Colors.orange,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            SizedBox(
                              width: 28,
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 14),
                                color: Colors.red[400],
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _deleteWorkoutSet(
                                  set['workout_id'],
                                  set['set_index'],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    
                    // 追加ボタン（該当種目に直接移動、既存記録に追記）
                    GestureDetector(
                      onTap: () {
                        // 該当種目のデータをテンプレート形式に変換
                        final muscleGroup = sets.isNotEmpty ? sets.first['muscle_group'] as String? ?? '不明' : '不明';
                        final workoutId = sets.isNotEmpty ? sets.first['workout_id'] as String? : null;
                        
                        // 最後のセットの重量・回数を取得（前回の記録として使用）
                        final lastWeight = sets.isNotEmpty ? (sets.last['weight'] as num?)?.toDouble() ?? 0.0 : 0.0;
                        final lastReps = sets.isNotEmpty ? sets.last['reps'] as int? ?? 10 : 10;
                        
                        final templateData = {
                          'muscle_group': muscleGroup,
                          'exercise_name': exerciseName,
                          'last_weight': lastWeight,
                          'last_reps': lastReps,
                          'existing_workout_id': workoutId,  // 既存記録ID
                        };
                        
                        print('📋 追加セット準備（＋ボタンから）: $exerciseName');
                        if (isCardio) {
                          print('   前回: ${lastWeight}分 × ${lastReps}km');
                        } else {
                          print('   前回: ${lastWeight}kg × ${lastReps}回');
                        }
                        print('   既存workout_id: $workoutId');
                        
                        // AddWorkoutScreenにテンプレートデータを渡して遷移
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddWorkoutScreen(templateData: templateData),
                          ),
                        ).then((result) {
                          if (result == true) {
                            _loadWorkoutsForSelectedDay();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.white,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            );
          }),
        ],
      ),
    );
  }
  
  // ==================== Task 14: 検索・フィルター機能 ====================
  
  /// 検索・フィルターUIセクション
  Widget _buildSearchAndFilterSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 検索バーとフィルターボタン
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '種目名で検索...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _filteredWorkouts = [];
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    if (value.isNotEmpty) {
                      _performSearch();
                    } else {
                      setState(() {
                        _filteredWorkouts = [];
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // フィルターボタン
              Container(
                decoration: BoxDecoration(
                  color: (_selectedMuscleGroupFilter != null || _dateRangeFilter != null)
                      ? theme.colorScheme.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: (_selectedMuscleGroupFilter != null || _dateRangeFilter != null)
                        ? Colors.white
                        : theme.colorScheme.primary,
                  ),
                  onPressed: _showFilterDialog,
                ),
              ),
            ],
          ),
          
          // フィルター適用中の表示
          if (_selectedMuscleGroupFilter != null || _dateRangeFilter != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (_selectedMuscleGroupFilter != null)
                  Chip(
                    label: Text(_selectedMuscleGroupFilter!),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _selectedMuscleGroupFilter = null;
                      });
                      _performSearch();
                    },
                  ),
                if (_dateRangeFilter != null)
                  Chip(
                    label: Text(
                      '${_dateRangeFilter!.start.month}/${_dateRangeFilter!.start.day} - ${_dateRangeFilter!.end.month}/${_dateRangeFilter!.end.day}',
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _dateRangeFilter = null;
                      });
                      _performSearch();
                    },
                  ),
              ],
            ),
          ],
          
          // 検索結果表示
          if (_filteredWorkouts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.search, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '検索結果: ${_filteredWorkouts.length}件',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredWorkouts.length,
                    separatorBuilder: (context, index) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final workout = _filteredWorkouts[index];
                      final date = (workout['date'] as Timestamp?)?.toDate();
                      final muscleGroup = workout['muscle_group'] as String?;
                      final sets = workout['sets'] as List<dynamic>?;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  muscleGroup ?? '不明',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                date != null ? '${date.year}/${date.month}/${date.day}' : '日付不明',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (sets != null)
                            ...sets.take(3).map((set) {
                              final exerciseName = set['exercise_name'] as String?;
                              final weight = set['weight'] as num?;
                              final reps = set['reps'] as num?;
                              
                              // 有酸素運動の場合は「時間(分) × 距離(km)」表示
                              final isCardio = muscleGroup == '有酸素';
                              final displayText = isCardio
                                  ? '• $exerciseName: ${weight?.toInt() ?? 0}分 × ${reps?.toInt() ?? 0}km'
                                  : '• $exerciseName: ${weight?.toInt() ?? 0}kg × ${reps?.toInt() ?? 0}回';
                              
                              return Padding(
                                padding: const EdgeInsets.only(left: 8, bottom: 4),
                                child: Text(
                                  displayText,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                          if (sets != null && sets.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 4),
                              child: Text(
                                '他 ${sets.length - 3}セット',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// 検索・フィルター実行
  Future<void> _performSearch() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _filteredWorkouts = [];
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Firestoreから全履歴を取得
      final querySnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .get();
      
      // メモリ内でフィルタリング
      List<Map<String, dynamic>> results = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      // 検索キーワードでフィルター（種目名）
      final searchQuery = _searchController.text.toLowerCase();
      if (searchQuery.isNotEmpty) {
        results = results.where((workout) {
          final sets = workout['sets'] as List<dynamic>?;
          if (sets == null) return false;
          return sets.any((set) {
            final exerciseName = (set['exercise_name'] as String? ?? '').toLowerCase();
            return exerciseName.contains(searchQuery);
          });
        }).toList();
      }
      
      // 部位でフィルター
      if (_selectedMuscleGroupFilter != null) {
        results = results.where((workout) {
          return workout['muscle_group'] == _selectedMuscleGroupFilter;
        }).toList();
      }
      
      // 日付範囲でフィルター
      if (_dateRangeFilter != null) {
        results = results.where((workout) {
          final date = (workout['date'] as Timestamp?)?.toDate();
          if (date == null) return false;
          return date.isAfter(_dateRangeFilter!.start.subtract(const Duration(days: 1))) &&
                 date.isBefore(_dateRangeFilter!.end.add(const Duration(days: 1)));
        }).toList();
      }
      
      // 日付順でソート（新しい順）
      results.sort((a, b) {
        final dateA = (a['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final dateB = (b['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });
      
      setState(() {
        _filteredWorkouts = results;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 検索エラー: $e');
      setState(() {
        _filteredWorkouts = [];
        _isLoading = false;
      });
    }
  }
  
  /// フィルターダイアログを表示
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('フィルター'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 部位選択
                  const Text('部位', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['胸', '脚', '背中', '肩', '二頭', '三頭', '有酸素', 'すべて'].map((group) {
                      final isSelected = group == 'すべて' 
                          ? _selectedMuscleGroupFilter == null
                          : _selectedMuscleGroupFilter == group;
                      return FilterChip(
                        label: Text(
                          group,
                          style: const TextStyle(fontSize: 13),
                        ),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            setState(() {
                              _selectedMuscleGroupFilter = group == 'すべて' ? null : group;
                            });
                          });
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 日付範囲
                  const Text('日付範囲', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _dateRangeFilter,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          setState(() {
                            _dateRangeFilter = picked;
                          });
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _dateRangeFilter == null
                          ? '日付範囲を選択'
                          : '${_dateRangeFilter!.start.month}/${_dateRangeFilter!.start.day} - ${_dateRangeFilter!.end.month}/${_dateRangeFilter!.end.day}',
                    ),
                  ),
                  if (_dateRangeFilter != null)
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          setState(() {
                            _dateRangeFilter = null;
                          });
                        });
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('クリア', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedMuscleGroupFilter = null;
                    _dateRangeFilter = null;
                  });
                  Navigator.pop(context);
                  _performSearch();
                },
                child: const Text('リセット'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performSearch();
                },
                child: const Text('適用'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  /// SetType説明一覧の各行を生成
  Widget _buildSetTypeExplanationRow(
    IconData icon,
    Color color,
    String badge,
    String title,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// SetTypeバッジを生成
  Widget _buildSetTypeBadge(workout_models.SetType setType, int? dropsetLevel) {
    if (setType == workout_models.SetType.normal) {
      return const SizedBox.shrink();
    }
    
    IconData icon;
    Color color;
    String label;
    
    switch (setType) {
      case workout_models.SetType.warmup:
        icon = Icons.heat_pump;
        color = Colors.orange;
        label = 'WU';
        break;
      case workout_models.SetType.superset:
        icon = Icons.compare_arrows;
        color = Colors.purple;
        label = 'SS';
        break;
      case workout_models.SetType.dropset:
        icon = Icons.trending_down;
        color = Colors.blue;
        label = dropsetLevel != null ? 'DS$dropsetLevel' : 'DS';
        break;
      case workout_models.SetType.failure:
        icon = Icons.local_fire_department;
        color = Colors.red;
        label = '限界';
        break;
      default:
        return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  
  }
  
  // ==================== Task 15: 編集・削除機能 ====================
  
  /// 削除確認ダイアログ
  Future<bool?> _showDeleteConfirmDialog(String exerciseName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('記録を削除'),
        content: Text('「$exerciseName」の記録を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
  
  /// 編集・削除メニューを表示
  void _showEditDeleteMenu(String? workoutId, String exerciseName) {
    if (workoutId == null) return;
    
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
              exerciseName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // 編集ボタン
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('編集'),
              onTap: () {
                Navigator.pop(context);
                _editWorkout(workoutId);
              },
            ),
            const Divider(),
            // 削除ボタン
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('削除', style: TextStyle(color: Colors.red)),
              onTap: () async {
                print('👆 メニューから削除選択: $exerciseName (ID: $workoutId)');
                Navigator.pop(context);
                final confirmed = await _showDeleteConfirmDialog(exerciseName);
                if (confirmed == true) {
                  print('✅ 削除確認OK: $exerciseName (ID: $workoutId)');
                  _deleteWorkout(workoutId);
                } else {
                  print('❌ 削除キャンセル: $exerciseName');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  /// 特定の種目だけを削除（スワイプ削除用）
  Future<void> _deleteExerciseFromWorkout(String? workoutId, String exerciseName) async {
    if (workoutId == null) {
      print('❌ 削除失敗: workoutId is null');
      return;
    }
    
    try {
      print('🗑️ 種目削除開始: Workout ID = $workoutId, Exercise = $exerciseName');
      
      final docRef = FirebaseFirestore.instance.collection('workout_logs').doc(workoutId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        print('❌ ドキュメントが見つかりません: $workoutId');
        return;
      }
      
      final data = docSnapshot.data();
      if (data == null) {
        print('❌ ドキュメントデータが存在しません');
        return;
      }
      
      // データ構造によって処理を分岐
      if (data['sets'] != null) {
        // sets配列形式の場合
        final sets = data['sets'] as List<dynamic>? ?? [];
        print('🔍 Before delete - total sets: ${sets.length}');
        
        // 指定された種目のセットだけをフィルタリング（削除）
        print('🎯 削除対象: "$exerciseName" (length=${exerciseName.length})');
        final remainingSets = sets.where((set) {
          if (set is Map<String, dynamic>) {
            final setExerciseName = set['exercise_name'] as String? ?? '';
            final isMatch = setExerciseName == exerciseName;
            print('   セット比較: "$setExerciseName" vs "$exerciseName" → Match=$isMatch');
            return setExerciseName != exerciseName;
          }
          return true;
        }).toList();
        
        print('🔍 After filter - total sets: ${remainingSets.length}');
        
        if (remainingSets.isEmpty) {
          // 全てのセットが削除された場合はワークアウト全体を削除
          print('⚠️ All sets deleted - deleting entire workout');
          await docRef.delete();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('最後の種目が削除されたため、トレーニング記録全体を削除しました'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          // 残りのセットで更新
          print('✅ Updating Firestore with ${remainingSets.length} sets');
          print('📤 Firestore更新開始: workout_logs/$workoutId');
          
          try {
            // Firestoreを更新
            await docRef.update({'sets': remainingSets});
            print('✅ Firestore更新完了');
            
            // 更新を確認（ベリフィケーション）
            final verifyDoc = await docRef.get();
            if (verifyDoc.exists) {
              final verifyData = verifyDoc.data();
              if (verifyData == null) {
                print('⚠️ 検証データが取得できません');
              } else {
                final verifySets = verifyData['sets'] as List<dynamic>? ?? [];
                print('✅ 更新確認: ${verifySets.length}セット（期待値: ${remainingSets.length}）');
                
                if (verifySets.length != remainingSets.length) {
                  print('⚠️ 警告: セット数が一致しません！');
                  throw Exception('Firestore更新の検証に失敗しました');
                }
              }
            }
            
            // その日の残り種目数を計算（全ワークアウトから）
            await _loadWorkoutsForSelectedDay();
            final totalRemainingExercises = _selectedDayWorkouts.fold<Set<String>>(
              {},
              (names, workout) {
                if (workout['sets'] != null) {
                  final sets = workout['sets'] as List<dynamic>? ?? [];
                  for (var set in sets) {
                    if (set is Map<String, dynamic>) {
                      final exerciseName = set['exercise_name'] as String?;
                      if (exerciseName != null) names.add(exerciseName);
                    }
                  }
                } else if (workout['exercises'] != null) {
                  final exercises = workout['exercises'] as Map<String, dynamic>;
                  names.addAll(exercises.keys);
                }
                return names;
              },
            ).length;
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('「$exerciseName」を削除しました（残り${totalRemainingExercises}種目）'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (updateError) {
            print('❌ Firestore更新エラー: $updateError');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('削除に失敗しました: $updateError'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            rethrow;
          }
        }
      } else if (data['exercises'] != null) {
        // exercises Map形式の場合
        final exercises = Map<String, dynamic>.from(data['exercises'] as Map);
        print('🔍 Before delete - exercises: ${exercises.keys.toList()}');
        
        exercises.remove(exerciseName);
        print('🔍 After delete - exercises: ${exercises.keys.toList()}');
        
        if (exercises.isEmpty) {
          print('⚠️ All exercises deleted - deleting entire workout');
          await docRef.delete();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('最後の種目が削除されたため、トレーニング記録全体を削除しました'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          print('✅ Updating Firestore with ${exercises.length} exercises');
          await docRef.update({'exercises': exercises});
          
          // その日の残り種目数を計算（全ワークアウトから）
          await _loadWorkoutsForSelectedDay();
          final totalRemainingExercises = _selectedDayWorkouts.fold<Set<String>>(
            {},
            (names, workout) {
              if (workout['sets'] != null) {
                final sets = workout['sets'] as List<dynamic>? ?? [];
                for (var set in sets) {
                  if (set is Map<String, dynamic>) {
                    final exerciseName = set['exercise_name'] as String?;
                    if (exerciseName != null) names.add(exerciseName);
                  }
                }
              } else if (workout['exercises'] != null) {
                final exercises = workout['exercises'] as Map<String, dynamic>;
                names.addAll(exercises.keys);
              }
              return names;
            },
          ).length;
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('「$exerciseName」を削除しました（残り${totalRemainingExercises}種目）'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
      
      // データを再読み込み（強制リフレッシュ）
      print('🔄 データ再読み込み開始...');
      
      // setState を使って強制的にUIを更新
      if (mounted) {
        setState(() {
          _selectedDayWorkouts.clear();
        });
      }
      
      // Firestoreから最新データを再取得
      await _loadWorkoutsForSelectedDay();
      print('✅ データ再読み込み完了');
      
      // 追加で画面を強制更新
      if (mounted) {
        setState(() {});
      }
      
    } catch (e, stackTrace) {
      print('❌ 種目削除エラー: $e');
      print('Stack Trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }
  
  /// 記録を削除
  Future<void> _deleteWorkout(String? workoutId) async {
    if (workoutId == null) {
      print('❌ 削除失敗: workoutId is null');
      return;
    }
    
    try {
      print('🗑️ 削除開始: Workout ID = $workoutId');
      
      // 削除前にドキュメントが存在するか確認
      final docSnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .doc(workoutId)
          .get();
      
      if (!docSnapshot.exists) {
        print('❌ ドキュメントが見つかりません: $workoutId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('削除対象の記録が見つかりませんでした'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // ドキュメント情報をログ出力
      final data = docSnapshot.data();
      print('📄 削除対象ドキュメント:');
      print('   - muscle_group: ${data?['muscle_group']}');
      print('   - sets: ${(data?['sets'] as List?)?.length ?? 0}セット');
      print('   - date: ${data?['date']}');
      
      // 削除実行
      await FirebaseFirestore.instance
          .collection('workout_logs')
          .doc(workoutId)
          .delete();
      
      print('✅ Firestore削除完了: $workoutId');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('記録を削除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // データを再読み込み
      print('🔄 データ再読み込み開始...');
      await _loadWorkoutsForSelectedDay();
      print('✅ データ再読み込み完了');
      
    } catch (e, stackTrace) {
      print('❌ 削除エラー: $e');
      print('Stack Trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }
  
  /// 記録を編集
  void _editWorkout(String workoutId) {
    // 編集画面に遷移（AddWorkoutScreenを編集モードで開く）
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('編集機能は次のアップデートで実装予定です'),
        duration: Duration(seconds: 2),
      ),
    );
    // TODO: AddWorkoutScreenに既存データを渡して編集モードで開く
  }
  
  // ==================== Task 16: 疲労管理システムセクション ====================
  
  /// 疲労管理システムセクション
  Widget _buildFatigueManagementSection(ThemeData theme) {
    return FutureBuilder<bool>(
      future: _fatigueService.isFatigueManagementEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? false;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[700]!,
                  Colors.blue[500]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.psychology,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔬 疲労管理システム',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '科学的根拠に基づく疲労度分析',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // ON/OFFスイッチ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'システム状態',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    Switch(
                      value: isEnabled,
                      onChanged: (value) async {
                        await _fatigueService.setFatigueManagementEnabled(value);
                        setState(() {});
                        
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
                      },
                      activeColor: Colors.white,
                      activeTrackColor: Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 全トレーニング終了ボタン
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isEnabled ? _endTodayWorkout : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue[700],
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 24,
                          color: isEnabled ? Colors.blue[700] : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '本日の全トレーニング終了',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isEnabled ? Colors.blue[700] : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                if (!isEnabled) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'システムをONにしてください',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFatigueStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
  
  /// 全トレーニング終了処理
  Future<void> _endTodayWorkout() async {
    try {
      // 本日のトレーニング記録を取得
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('ユーザーが認証されていません');
      }

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // シンプルクエリ（インデックス不要）+ メモリ内フィルタ
      final querySnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .get();

      // メモリ内で本日のデータをフィルタ
      final todayDocs = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null) return false;
        return date.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
               date.isBefore(todayEnd);
      }).toList();

      if (todayDocs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('本日のトレーニング記録が見つかりません'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // トレーニング記録を分析（セット数、部位などを集計）
      int totalSets = 0;
      Set<String> bodyParts = {};
      DateTime? firstWorkoutTime;
      DateTime? lastWorkoutTime;

      for (final doc in todayDocs) {
        final data = doc.data();
        final sets = data['sets'] as List<dynamic>? ?? [];
        totalSets += sets.length;
        
        // 部位情報を収集
        final muscleGroup = data['muscle_group'] as String?;
        if (muscleGroup != null && muscleGroup != '有酸素') {
          bodyParts.add(muscleGroup);
        }
        
        // 最初と最後のワークアウト時刻を記録
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date != null) {
          if (firstWorkoutTime == null || date.isBefore(firstWorkoutTime)) {
            firstWorkoutTime = date;
          }
          if (lastWorkoutTime == null || date.isAfter(lastWorkoutTime)) {
            lastWorkoutTime = date;
          }
        }
      }

      // セッション時間を計算（分）
      int sessionDuration = 60; // デフォルト60分
      if (firstWorkoutTime != null && lastWorkoutTime != null) {
        final duration = lastWorkoutTime.difference(firstWorkoutTime).inMinutes;
        sessionDuration = duration > 0 ? duration : 60;
      }

      // Phase 2a: セッションRPE入力ダイアログ表示
      if (mounted) {
        final sessionRPE = await _showRPEInputDialog();
        if (sessionRPE == null) {
          // ユーザーがキャンセルした場合
          return;
        }

        // Phase 2a: 基礎Training Load計算
        final baseTrainingLoad = _fatigueService.calculateTrainingLoad(
          sessionRPE: sessionRPE,
          durationMinutes: sessionDuration,
          totalSets: totalSets,
          bodyParts: bodyParts.toList(),
        );

        // Phase 2b+2c: ユーザープロファイル取得 + 統合分析
        final userProfile = await _advancedFatigueService.getUserProfile();
        final comprehensiveAnalysis = await _advancedFatigueService.getComprehensiveFatigueAnalysis(
          baseTrainingLoad: baseTrainingLoad,
          profile: userProfile,
        );

        // セッションデータを保存
        await _fatigueService.saveSessionData(
          sessionRPE: sessionRPE,
          durationMinutes: sessionDuration,
        );
        
        // 最後のトレーニング日を保存
        await _fatigueService.saveLastWorkoutDate(DateTime.now());

        // Phase 2a+2b+2c統合: 疲労度アドバイスダイアログを表示
        if (mounted) {
          _showComprehensiveFatigueDialog(comprehensiveAnalysis);
        }
      }
    } catch (e) {
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

  /// Phase 2a: セッションRPE入力ダイアログ
  /// 根拠: Foster et al. (2001) - sRPE method
  Future<double?> _showRPEInputDialog() async {
    double selectedRPE = 5.0; // デフォルト: 中間値
    
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.psychology, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text('🔬 セッションRPE入力'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今日のトレーニング全体の主観的強度は？',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'セッション全体を振り返り、最も適切な値を選択してください',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // RPE値と説明
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getRPEColor(selectedRPE).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getRPEColor(selectedRPE),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          selectedRPE.toInt().toString(),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: _getRPEColor(selectedRPE),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getRPELabel(selectedRPE.toInt()),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getRPEColor(selectedRPE),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // スライダー
                  Slider(
                    value: selectedRPE,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    activeColor: _getRPEColor(selectedRPE),
                    label: selectedRPE.toInt().toString(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRPE = value;
                      });
                    },
                  ),
                  
                  // RPEスケール説明
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 6),
                            const Text(
                              'RPEスケール参考',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '0-1: 休息\n2-3: 軽い運動\n4-6: 中程度の運動\n7-8: きつい運動\n9-10: 最大努力',
                          style: TextStyle(fontSize: 11, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, selectedRPE),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getRPEColor(selectedRPE),
                ),
                child: const Text('確定'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  /// RPE値に対応する色を取得
  Color _getRPEColor(double rpe) {
    if (rpe <= 3) return Colors.green;
    if (rpe <= 6) return Colors.blue;
    if (rpe <= 8) return Colors.orange;
    return Colors.red;
  }
  
  /// RPE値に対応するラベルを取得
  String _getRPELabel(int rpe) {
    switch (rpe) {
      case 0:
      case 1:
        return '休息レベル';
      case 2:
      case 3:
        return '軽い運動';
      case 4:
      case 5:
      case 6:
        return '中程度の運動';
      case 7:
      case 8:
        return 'きつい運動';
      case 9:
      case 10:
        return '最大努力';
      default:
        return '中程度の運動';
    }
  }

  /// Phase 2a: TLベースの疲労度アドバイスダイアログ
  void _showFatigueAdviceDialog(double trainingLoad) {
    // FatigueManagementServiceから疲労度レベルを取得
    final fatigueData = _fatigueService.getFatigueLevel(trainingLoad);
    
    final fatigueLevel = fatigueData['label'] as String;
    final colorName = fatigueData['color'] as String;
    final recoveryHours = fatigueData['recoveryHours'] as int;
    final advice = fatigueData['advice'] as String;
    
    // 色名を実際のColorに変換
    Color levelColor;
    IconData levelIcon;
    switch (colorName) {
      case 'green':
        levelColor = Colors.green;
        levelIcon = Icons.sentiment_satisfied;
        break;
      case 'blue':
        levelColor = Colors.blue;
        levelIcon = Icons.sentiment_neutral;
        break;
      case 'orange':
        levelColor = Colors.orange;
        levelIcon = Icons.sentiment_dissatisfied;
        break;
      case 'red':
        levelColor = Colors.red;
        levelIcon = Icons.warning;
        break;
      default:
        levelColor = Colors.grey;
        levelIcon = Icons.help;
    }
    
    final recoveryTime = recoveryHours >= 72 
        ? '${recoveryHours}時間以上' 
        : '$recoveryHours時間';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(levelIcon, color: levelColor, size: 32),
            const SizedBox(width: 12),
            const Text('🔬 疲労度分析結果'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      'Training Load: ${trainingLoad.toInt()} AU',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              _buildInfoRow('推奨回復時間', recoveryTime),
              
              const Divider(height: 32),
              
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
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.science, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Phase 2a実装完了\nFoster et al. (2001)のSession RPE理論を採用',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue[900],
                          height: 1.4,
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
  
  /// Phase 2a+2b+2c統合: 包括的疲労度分析ダイアログ
  void _showComprehensiveFatigueDialog(Map<String, dynamic> analysis) {
    final baseTrainingLoad = analysis['base_training_load'] as double;
    final pfm = analysis['personal_factor_multiplier'] as double;
    final adjustedTrainingLoad = analysis['adjusted_training_load'] as double;
    final acwrData = analysis['acwr_data'] as Map<String, dynamic>;
    
    // Phase 2a: 基礎疲労度レベル
    final baseFatigueData = _fatigueService.getFatigueLevel(adjustedTrainingLoad);
    final baseFatigueLevel = baseFatigueData['label'] as String;
    final recoveryHours = baseFatigueData['recoveryHours'] as int;
    final baseAdvice = baseFatigueData['advice'] as String;
    
    // Phase 2c: ACWR分析
    final acwr = acwrData['acwr'] as double?;
    final acuteLoad = acwrData['acute_load'] as double;
    final chronicLoad = acwrData['chronic_load'] as double;
    final riskLevel = acwrData['risk_level'] as String;
    final riskColorName = acwrData['risk_color'] as String;
    final acwrAdvice = acwrData['advice'] as String;
    
    // Traffic Light Color
    Color trafficLightColor;
    IconData trafficLightIcon;
    String trafficLightLabel;
    
    switch (riskColorName) {
      case 'green':
        trafficLightColor = Colors.green;
        trafficLightIcon = Icons.check_circle;
        trafficLightLabel = '安全';
        break;
      case 'yellow':
        trafficLightColor = Colors.amber;
        trafficLightIcon = Icons.warning;
        trafficLightLabel = '警戒';
        break;
      case 'red':
        trafficLightColor = Colors.red;
        trafficLightIcon = Icons.error;
        trafficLightLabel = '危険';
        break;
      case 'blue':
        trafficLightColor = Colors.blue;
        trafficLightIcon = Icons.trending_down;
        trafficLightLabel = 'アンダートレーニング';
        break;
      default:
        trafficLightColor = Colors.grey;
        trafficLightIcon = Icons.help;
        trafficLightLabel = 'データ不足';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue[700], size: 32),
            const SizedBox(width: 12),
            const Text('🔬 総合疲労度分析'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phase 2c: Traffic Light Model
              if (acwr != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: trafficLightColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: trafficLightColor, width: 3),
                  ),
                  child: Column(
                    children: [
                      Icon(trafficLightIcon, color: trafficLightColor, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        trafficLightLabel,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: trafficLightColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ACWR: ${acwr.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Phase 2b: Personal Factor Multiplier
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple[200]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.purple[700], size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Phase 2b: 個人補正係数 (PFM)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PFM: ${pfm.toStringAsFixed(2)}x',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '基礎TL: ${baseTrainingLoad.toInt()} AU → 補正後: ${adjustedTrainingLoad.toInt()} AU',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Phase 2c: ACWR詳細データ
              if (acwr != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Phase 2c: ACWR分析',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('急性負荷 (7日)', '${acuteLoad.toInt()} AU'),
                      const SizedBox(height: 4),
                      _buildInfoRow('慢性負荷 (28日)', '${chronicLoad.toInt()} AU'),
                      const SizedBox(height: 4),
                      _buildInfoRow('ACWR比', acwr.toStringAsFixed(2)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // 疲労度レベル
              _buildInfoRow('疲労度レベル', baseFatigueLevel),
              const SizedBox(height: 8),
              _buildInfoRow('推奨回復時間', '${recoveryHours}時間'),
              
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
              
              // Phase 2a アドバイス
              Text(
                '【基礎分析】\n$baseAdvice',
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              
              if (acwr != null) ...[
                const SizedBox(height: 12),
                Text(
                  '【ACWR分析】\n$acwrAdvice',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // 科学的根拠表示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.science, color: Colors.green[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Phase 2a+2b+2c統合実装\nFoster (2001), Murray (2016), Windt & Gabbett (2017)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green[900],
                          height: 1.4,
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
  
  // ==================== Task 17: 目標セクション ====================
  
  /// 目標セクション
  // Smart Goal Card（カルーセル用の大きなビジュアルカード）
  Widget _buildSmartGoalCard(Goal goal, ThemeData theme) {
    final progress = goal.progress;
    final remaining = goal.targetValue - goal.currentValue;
    final progressColor = goal.isCompleted
        ? Colors.green
        : progress >= 0.85
            ? Colors.orange
            : theme.colorScheme.primary;
    
    // 動的メッセージ生成
    String motivationMessage;
    String motivationEmoji;
    if (goal.isCompleted) {
      motivationMessage = '達成おめでとう！';
      motivationEmoji = '🎉';
    } else if (progress >= 0.95) {
      motivationMessage = 'あと少しで達成！今週中にいこう！';
      motivationEmoji = '🎉';
    } else if (progress >= 0.85) {
      motivationMessage = 'あと${remaining.toStringAsFixed(0)}${goal.unit}で達成！';
      motivationEmoji = '🔥';
    } else if (progress >= 0.70) {
      motivationMessage = 'もうすぐ達成！';
      motivationEmoji = '💪';
    } else if (progress >= 0.50) {
      motivationMessage = '折り返し地点！その調子！';
      motivationEmoji = '📈';
    } else {
      motivationMessage = 'スタートダッシュ成功！';
      motivationEmoji = '🎯';
    }
    
    // グラデーション色設定
    List<Color> gradientColors;
    if (goal.isCompleted) {
      gradientColors = [Colors.green.shade400, Colors.green.shade600];
    } else if (progress >= 0.85) {
      gradientColors = [Colors.orange.shade400, Colors.deepOrange.shade600];
    } else if (progress >= 0.70) {
      gradientColors = [Colors.purple.shade400, Colors.purple.shade600];
    } else {
      gradientColors = [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)];
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: progressColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 動的メッセージ
            Row(
              children: [
                Text(
                  motivationEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    motivationMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 目標名
            Row(
              children: [
                Icon(
                  _getGoalIcon(goal.iconName),
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 進捗表示
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${goal.currentValue} → ${goal.targetValue} ${goal.unit}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${goal.progressPercent}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // プログレスバー（太め）
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 予測メッセージ
            if (!goal.isCompleted)
              Text(
                '残り${goal.daysRemaining}日 | 現在のペースを維持しよう',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              )
            else
              const Text(
                '目標達成済み！次の目標を設定しましょう',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsSection(ThemeData theme) {
    if (_activeGoals.isEmpty) {
      // 目標が設定されていない場合
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GoalsScreen(),
              ),
            );
            _loadActiveGoals();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flag,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '目標を設定',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'トレーニング目標を設定しましょう',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 28),
              ],
            ),
          ),
        ),
      );
    }
    
    // アクティブな目標がある場合 - Smart Carousel実装
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // セクションヘッダー
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    '🎯 目標進捗',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'スワイプで切替',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GoalsScreen(),
                    ),
                  );
                  _loadActiveGoals();
                },
                child: const Text('すべて表示'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Smart Carousel
          SizedBox(
            height: 180,
            child: PageView.builder(
              itemCount: _activeGoals.length,
              controller: PageController(viewportFraction: 0.92),
              itemBuilder: (context, index) {
                return _buildSmartGoalCard(_activeGoals[index], theme);
              },
            ),
          ),
          
          // ページインジケーター
          if (_activeGoals.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _activeGoals.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == 0
                        ? theme.colorScheme.primary
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// ワークアウト履歴画面を開く
  
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

  /// 設定メニューを表示
  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // タイトル
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.deepPurple.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    '設定メニュー',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            // メニュー項目1: トレーニングメモ
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.note_alt,
                  color: Colors.blue.shade700,
                ),
              ),
              title: const Text(
                'トレーニングメモ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text('過去のトレーニング記録を確認'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/workout-memo');
              },
            ),
            // メニュー項目2: 個人要因設定
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_outline,
                  color: Colors.purple.shade700,
                ),
              ),
              title: const Text(
                '個人要因設定',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text('年齢・経験・睡眠・栄養などを編集'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/personal-factors');
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
