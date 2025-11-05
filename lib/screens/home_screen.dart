import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'workout/add_workout_screen.dart';
import 'workout/rm_calculator_screen.dart';
import 'workout/ai_coaching_screen.dart';
import 'workout/template_screen.dart';
import 'workout/workout_log_screen.dart';
import 'workout/statistics_dashboard_screen.dart';
import 'achievements_screen.dart';
import 'goals_screen.dart';
import '../models/workout_log.dart' as workout_models;
import '../models/goal.dart';
import '../services/achievement_service.dart';
import '../services/goal_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  List<Map<String, dynamic>> _selectedDayWorkouts = [];
  bool _isLoading = false;
  
  // 種目ごとの展開状態を管理
  Map<String, bool> _expandedExercises = {};
  
  // Task 14: 検索・フィルター機能
  final TextEditingController _searchController = TextEditingController();
  String? _selectedMuscleGroupFilter;
  DateTimeRange? _dateRangeFilter;
  List<Map<String, dynamic>> _filteredWorkouts = [];
  
  // Task 16: バッジシステム
  final AchievementService _achievementService = AchievementService();
  Map<String, int> _badgeStats = {'total': 0, 'unlocked': 0, 'locked': 0};
  
  // Task 17: 目標システム
  final GoalService _goalService = GoalService();
  List<Goal> _activeGoals = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDay = _focusedDay;
    // 空セットをクリーンアップしてからデータ読み込み
    _cleanupEmptySets().then((_) {
      _loadWorkoutsForSelectedDay();
      _loadBadgeStats();
      _loadActiveGoals();
    });
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
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // アプリが foreground に戻った時に自動リフレッシュ
      print('🔄 アプリがアクティブになりました - データを再読み込み');
      _loadWorkoutsForSelectedDay();
    }
  }

  // 選択した日のトレーニング記録を読み込む
  Future<void> _loadWorkoutsForSelectedDay() async {
    if (_selectedDay == null) return;

    print('🔍 トレーニング記録を読み込み開始...');
    print('📅 選択日: ${_selectedDay!.year}/${_selectedDay!.month}/${_selectedDay!.day}');

    setState(() {
      _isLoading = true;
    });

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ ユーザーが未ログインです');
        // ユーザーが未ログインの場合もローディング終了
        setState(() {
          _selectedDayWorkouts = [];
          _isLoading = false;
        });
        return;
      }

      print('👤 User ID: ${user.uid}');

      // シンプルなクエリ（インデックス不要）
      print('🔍 ユーザーの全記録を取得中...');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: user.uid)
          .get();

      print('📊 全記録件数: ${querySnapshot.docs.length}');

      // 選択した日の開始時刻と終了時刻を取得
      final startOfDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      print('🕐 フィルタ範囲: $startOfDay 〜 $endOfDay');

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

      // 選択した日のデータだけをフィルタ
      final filteredWorkouts = allWorkouts.where((workout) {
        final workoutDate = workout['date'] as DateTime;
        return workoutDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
               workoutDate.isBefore(endOfDay);
      }).toList();

      // 日付で降順ソート
      filteredWorkouts.sort((a, b) {
        final dateA = a['date'] as DateTime;
        final dateB = b['date'] as DateTime;
        return dateB.compareTo(dateA);
      });

      print('✅ フィルタ後: ${filteredWorkouts.length}件');

      setState(() {
        _selectedDayWorkouts = filteredWorkouts;
        _isLoading = false;
      });

      print('✅ データ読み込み完了: ${_selectedDayWorkouts.length}件');
    } catch (e) {
      print('❌ トレーニング記録の読み込みエラー: $e');
      setState(() {
        _selectedDayWorkouts = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // 設定画面へ遷移（未実装）
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // カレンダーと統計を横並びに配置
            _buildCalendarAndStatsSection(theme),
            
            const SizedBox(height: 16),
            
            // アクションボタン
            _buildActionButtons(theme),
            
            const SizedBox(height: 16),
            
            // Task 16: バッジセクション
            _buildBadgeSection(theme),
            
            const SizedBox(height: 16),
            
            // Task 17: 目標セクション
            _buildGoalsSection(theme),
            
            const SizedBox(height: 16),
            
            // Task 14: 検索・フィルターUI
            _buildSearchAndFilterSection(theme),
            
            const SizedBox(height: 16),
            
            // 月間サマリー統計
            _buildMonthlySummary(theme),
            
            const SizedBox(height: 80), // 下部ナビゲーション用のスペース
          ],
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
          
          // 統計カード（タップで統計ダッシュボードへ）
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StatisticsDashboardScreen(),
                ),
              );
            },
            child: Row(
              children: [
                Expanded(
                  child: _buildMiniStatCard(
                    title: '7日間',
                    value: '42.78',
                    unit: 't',
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStatCard(
                    title: '合計負荷量',
                    value: '137.38',
                    unit: 't',
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStatCard(
                    title: '総負荷量',
                    value: '3116.27',
                    unit: 't',
                    theme: theme,
                  ),
                ),
              ],
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
          CalendarFormat.week: '週',
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
          // メインアクション: トレーニング記録（フル幅）
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddWorkoutScreen(),
                  ),
                );
                
                // 保存が成功した場合、データを再読み込み
                if (result == true) {
                  _loadWorkoutsForSelectedDay();
                }
              },
              icon: const Icon(Icons.add, size: 24),
              label: const Text(
                'トレーニング記録',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // サブアクション: テンプレート・RM計算・AIコーチ（3分割）
          Row(
            children: [
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
                  icon: Icon(Icons.library_books, size: 20, color: theme.colorScheme.primary),
                  label: Text(
                    'テンプレ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
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
                  icon: Icon(Icons.calculate, size: 20, color: theme.colorScheme.primary),
                  label: Text(
                    'RM計算',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
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
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AICoachingScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text(
                    'AIコーチ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 統計ダッシュボードへのボタン
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StatisticsDashboardScreen(),
                  ),
                );
              },
              icon: Icon(Icons.bar_chart, size: 20, color: theme.colorScheme.primary),
              label: Text(
                '統計ダッシュボード',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
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
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final sets = List<Map<String, dynamic>>.from(data['sets'] as List);
        
        // 有効なセットだけをフィルタ（重量または回数が0より大きい）
        final validSets = sets.where((set) {
          final weight = (set['weight'] as num).toDouble();
          final reps = set['reps'] as int;
          return weight > 0 || reps > 0;
        }).toList();
        
        if (validSets.length != sets.length) {
          // 空セットが見つかった
          if (validSets.isEmpty) {
            // 全セットが空の場合、ドキュメント削除
            await FirebaseFirestore.instance
                .collection('workout_logs')
                .doc(doc.id)
                .delete();
            print('   ドキュメント削除: ${doc.id}');
            cleanedCount++;
          } else {
            // 有効なセットだけを保存
            await FirebaseFirestore.instance
                .collection('workout_logs')
                .doc(doc.id)
                .update({'sets': validSets});
            print('   空セット削除: ${doc.id} (${sets.length} → ${validSets.length})');
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
      
      final data = docSnapshot.data()!;
      final sets = List<Map<String, dynamic>>.from(data['sets'] as List);
      
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
                  const Text(
                    '2',
                    style: TextStyle(
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
                    child: const Row(
                      children: [
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '432 days',
                          style: TextStyle(
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
      final sets = workout['sets'] as List<dynamic>;
      for (var i = 0; i < sets.length; i++) {
        final set = sets[i];
        final exerciseName = set['exercise_name'] as String;
        
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
                    Text(
                      _selectedDay != null && _isSameDay(_selectedDay!, DateTime.now())
                          ? '今日のトレーニング'
                          : '${_selectedDay!.month}月${_selectedDay!.day}日のトレーニング',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          
          // 種目ごとのセクション
          ...exerciseGroups.entries.map((entry) {
            final exerciseName = entry.key;
            final sets = entry.value;
            final isExpanded = _expandedExercises[exerciseName] ?? true;
            
            // 合計セット数、合計レップ数を計算
            final totalSets = sets.length;
            final totalReps = sets.fold<int>(0, (sum, set) => sum + (set['reps'] as int));
            
            // 記録のIDを取得（削除・編集用）
            final workoutId = _selectedDayWorkouts.isNotEmpty ? _selectedDayWorkouts[0]['id'] : null;
            
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
                return await _showDeleteConfirmDialog(exerciseName);
              },
              onDismissed: (direction) {
                _deleteWorkout(workoutId);
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
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              exerciseName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // 詳細・メモ表示ボタンを追加
                          IconButton(
                            icon: const Icon(Icons.note_alt, color: Colors.white),
                            onPressed: () async {
                              await _openWorkoutDetail(workoutId);
                            },
                            tooltip: '詳細とメモを見る',
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
                          const Expanded(
                            flex: 2,
                            child: Text(
                              '重さ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              '回数',
                              textAlign: TextAlign.center,
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
                              'RM',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
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
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            // SetTypeバッジ + セット番号
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildSetTypeBadge(setType, dropsetLevel),
                                if (setType != workout_models.SetType.normal) const SizedBox(width: 4),
                                SizedBox(
                                  width: setType == workout_models.SetType.normal ? 24 : 16,
                                  child: Text(
                                    '$setNumber',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${set['weight']} Kg',
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
                                    '${set['reps']} 回',
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
                              child: Text(
                                '${oneRM.toStringAsFixed(1)}Kg',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
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
                        print('   前回: ${lastWeight}kg × ${lastReps}reps');
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
                              final reps = set['reps'] as int?;
                              return Padding(
                                padding: const EdgeInsets.only(left: 8, bottom: 4),
                                child: Text(
                                  '• $exerciseName: ${weight}kg × ${reps}回',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 部位選択
                  const Text('部位', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['胸', '脚', '背中', '肩', '二頭', '三頭', '有酸素', 'すべて'].map((group) {
                      final isSelected = group == 'すべて' 
                          ? _selectedMuscleGroupFilter == null
                          : _selectedMuscleGroupFilter == group;
                      return FilterChip(
                        label: Text(group),
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
                Navigator.pop(context);
                final confirmed = await _showDeleteConfirmDialog(exerciseName);
                if (confirmed == true) {
                  _deleteWorkout(workoutId);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  /// 記録を削除
  Future<void> _deleteWorkout(String? workoutId) async {
    if (workoutId == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('workout_logs')
          .doc(workoutId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('記録を削除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // データを再読み込み
      _loadWorkoutsForSelectedDay();
    } catch (e) {
      print('❌ 削除エラー: $e');
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
  
  // ==================== Task 16: バッジセクション ====================
  
  /// バッジセクション
  Widget _buildBadgeSection(ThemeData theme) {
    final unlockedPercent = _badgeStats['total']! > 0
        ? (_badgeStats['unlocked']! / _badgeStats['total']! * 100).toInt()
        : 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AchievementsScreen(),
            ),
          );
          // バッジ画面から戻ったら統計を更新
          _loadBadgeStats();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
                      Icons.emoji_events,
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
                          '達成バッジ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'あなたの実績を確認',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildBadgeStat(
                      '解除済み',
                      '${_badgeStats['unlocked']}',
                      Icons.check_circle,
                    ),
                  ),
                  Expanded(
                    child: _buildBadgeStat(
                      '未解除',
                      '${_badgeStats['locked']}',
                      Icons.lock_outline,
                    ),
                  ),
                  Expanded(
                    child: _buildBadgeStat(
                      '達成率',
                      '$unlockedPercent%',
                      Icons.insights,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _badgeStats['total']! > 0
                      ? _badgeStats['unlocked']! / _badgeStats['total']!
                      : 0,
                  minHeight: 8,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBadgeStat(String label, String value, IconData icon) {
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
  
  // ==================== Task 17: 目標セクション ====================
  
  /// 目標セクション
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
    
    // アクティブな目標がある場合
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // セクションヘッダー
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '目標進捗',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
          const SizedBox(height: 8),
          
          // 目標カード
          ..._activeGoals.take(2).map((goal) {
            final progressColor = goal.isCompleted
                ? Colors.green
                : goal.progress >= 0.7
                    ? Colors.orange
                    : theme.colorScheme.primary;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                  Row(
                    children: [
                      Icon(
                        _getGoalIcon(goal.iconName),
                        color: progressColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          goal.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (goal.isCompleted)
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${goal.currentValue} / ${goal.targetValue} ${goal.unit}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                      ),
                      Text(
                        '${goal.progressPercent}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: goal.progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  if (!goal.isCompleted) ...[
                    const SizedBox(height: 8),
                    Text(
                      '残り${goal.daysRemaining}日',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  /// ワークアウト履歴画面を開く
  Future<void> _openWorkoutDetail(String? workoutId) async {
    if (mounted) {
      // WorkoutLogScreenに遷移（トレーニング履歴画面）
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WorkoutLogScreen(),
        ),
      );
      // 履歴画面から戻ってきたら、データを再読み込み
      _loadWorkoutsForSelectedDay();
    }
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
}
