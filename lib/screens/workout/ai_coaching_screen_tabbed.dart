import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // 🎯 Phase 1追加
import '../../services/ai_prediction_service.dart';
import '../../services/training_analysis_service.dart';
import '../../services/subscription_service.dart';
import '../../services/reward_ad_service.dart';
import '../../services/ai_credit_service.dart';
import '../../services/advanced_fatigue_service.dart'; // 🆕 Phase 7: 年齢取得用
import '../../services/scientific_database.dart'; // 🆕 Phase 7: レベル判定用
import '../../widgets/scientific_citation_card.dart';
import '../../widgets/paywall_dialog.dart';
import '../../main.dart'; // globalRewardAdService用
import '../../models/workout_log.dart'; // 🔧 v1.0.220: トレーニング履歴保存用
import '../personal_factors_screen.dart'; // 🔧 Phase 7 Fix: 個人要因設定画面
import '../body_measurement_screen.dart'; // 🔧 Phase 7 Fix: 体重記録画面

/// 🔧 v1.0.220: パース済み種目データ（AIコーチ提案メニュー用）
class ParsedExercise {
  final String name;
  final String bodyPart;
  final double? weight; // kg（筋トレ用）
  final int? reps; // 回数（筋トレ用）
  final int? sets; // セット数
  final String? description; // 初心者向け説明
  
  // 🔧 v1.0.237: 有酸素運動対応
  final bool isCardio; // 有酸素運動かどうか
  final double? distance; // 距離（km）（有酸素用）
  final int? duration; // 時間（分）（有酸素用）

  ParsedExercise({
    required this.name,
    required this.bodyPart,
    this.weight,
    this.reps,
    this.sets,
    this.description,
    this.isCardio = false, // デフォルトは筋トレ
    this.distance,
    this.duration,
  });
}

/// Layer 5: AIコーチング画面（統合版）
/// 
/// 機能:
/// - Tab 1: AIトレーニングメニュー提案（既存機能）
/// - Tab 2: AI成長予測（科学的根拠ベース）
/// - Tab 3: トレーニング効果分析
class AICoachingScreenTabbed extends StatefulWidget {
  final int initialTabIndex;

  const AICoachingScreenTabbed({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<AICoachingScreenTabbed> createState() => _AICoachingScreenTabbedState();
}

class _AICoachingScreenTabbedState extends State<AICoachingScreenTabbed>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _autoLoginIfNeeded();
    
    // 🎯 Phase 1: AI初回利用時のガイド表示
    _showFirstTimeAIGuide();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 未ログイン時に自動的に匿名ログイン
  Future<void> _autoLoginIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        debugPrint('✅ 匿名認証成功');
      } catch (e) {
        debugPrint('❌ 匿名認証エラー: $e');
      }
    }
  }
  
  /// 🎯 Phase 1: AI初回利用時のガイド
  Future<void> _showFirstTimeAIGuide() async {
    // UIが安定してから表示
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGuide = prefs.getBool('has_seen_ai_first_guide') ?? false;
    
    // 初回のみ表示
    if (hasSeenGuide) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アニメーションアイコン
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.5 + (value * 0.5),
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.psychology,
                        size: 64,
                        color: Colors.purple.shade600,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            
            // タイトル
            const Text(
              'AI疲労度分析へようこそ！',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // 説明
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGuideItem(
                  icon: Icons.analytics,
                  title: '科学的な分析',
                  description: 'あなたのトレーニングデータを基に、疲労度を科学的に分析します。',
                ),
                const SizedBox(height: 12),
                _buildGuideItem(
                  icon: Icons.auto_awesome,
                  title: '最適な提案',
                  description: '回復時間とトレーニングメニューを自動で提案します。',
                ),
                const SizedBox(height: 12),
                _buildGuideItem(
                  icon: Icons.trending_up,
                  title: '成長を加速',
                  description: 'パフォーマンスを最大化し、怪我のリスクを最小化します。',
                ),
              ],
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await prefs.setBool('has_seen_ai_first_guide', true);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'はじめる',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// ガイド項目Widget
  Widget _buildGuideItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.purple.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 設定メニューを表示
  void _showSettingsMenu() {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('AIコーチング')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('AIコーチング')),
            body: const Center(child: Text('ログインに失敗しました')),
          );
        }

        return _buildMainContent(user);
      },
    );
  }

  Widget _buildMainContent(User user) {
    return Scaffold(
        appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 24),
            SizedBox(width: 8),
            Text('AI科学的コーチング'),
          ],
        ),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsMenu,
            tooltip: '設定',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.fitness_center),
              text: 'メニュー提案',
            ),
            Tab(
              icon: Icon(Icons.timeline),
              text: '成長予測',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: '効果分析',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: AIメニュー提案（既存機能）
          _AIMenuTab(user: user),
          // Tab 2: 成長予測
          _GrowthPredictionTab(),
          // Tab 3: 効果分析
          _EffectAnalysisTab(),
        ],
      ),
    );
  }
}

// ========================================
// Tab 1: AIメニュー提案タブ
// ========================================

class _AIMenuTab extends StatefulWidget {
  final User user;

  const _AIMenuTab({required this.user});

  @override
  State<_AIMenuTab> createState() => _AIMenuTabState();
}

class _AIMenuTabState extends State<_AIMenuTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // 部位選択状態（有酸素追加）
  final Map<String, bool> _selectedBodyParts = {
    '胸': false,
    '背中': false,
    '脚': false,
    '肩': false,
    '腕': false,
    '腹筋': false,
    '有酸素': false,
  };
  
  // 🔧 v1.0.217: レベル選択（初心者・中級者・上級者）
  String _selectedLevel = '初心者'; // デフォルトは初心者

  // UI状態
  bool _isGenerating = false;
  String? _generatedMenu;
  String? _errorMessage;
  
  // 🔧 v1.0.217: トレーニング履歴データ
  Map<String, Map<String, dynamic>> _exerciseHistory = {}; // 種目名 → {maxWeight, max1RM, totalSets}
  bool _isLoadingWorkoutHistory = false;
  
  // 🔧 v1.0.220: パース済み種目データ（チェックボックス対応）
  List<ParsedExercise> _parsedExercises = [];
  Set<int> _selectedExerciseIndices = {}; // 選択された種目のインデックス

  // 履歴
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadWorkoutHistory(); // 🔧 v1.0.217: トレーニング履歴を読み込む
  }

  /// 履歴読み込み
  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('aiCoachingHistory')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      setState(() {
        _history = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint('❌ 履歴読み込みエラー: $e');
      setState(() => _isLoadingHistory = false);
    }
  }
  
  /// 🔧 v1.0.217: 直近1ヶ月のトレーニング履歴を読み込み、1RMを自動計算
  Future<void> _loadWorkoutHistory() async {
    setState(() => _isLoadingWorkoutHistory = true);
    
    try {
      // 1ヶ月前の日付
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
      
      // workout_logsから直近1ヶ月のデータを取得
      final snapshot = await FirebaseFirestore.instance
          .collection('workout_logs')
          .where('user_id', isEqualTo: widget.user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(oneMonthAgo))
          .get();
      
      // 種目ごとに集計
      final Map<String, Map<String, dynamic>> exerciseData = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final sets = data['sets'] as List<dynamic>? ?? [];
        
        for (final set in sets) {
          if (set is! Map<String, dynamic>) continue;
          
          final exerciseName = set['exercise_name'] as String?;
          final weight = (set['weight'] as num?)?.toDouble();
          final reps = set['reps'] as int?;
          final isCompleted = set['is_completed'] as bool? ?? false;
          
          // 完了していないセットはスキップ
          if (!isCompleted || exerciseName == null || weight == null || reps == null) {
            continue;
          }
          
          // 1RM計算（Epley formula: 1RM = weight × (1 + reps / 30)）
          final calculated1RM = weight * (1 + reps / 30);
          
          // 種目データを更新
          if (!exerciseData.containsKey(exerciseName)) {
            exerciseData[exerciseName] = {
              'maxWeight': weight,
              'max1RM': calculated1RM,
              'totalSets': 1,
              'bestReps': reps,
            };
          } else {
            final current = exerciseData[exerciseName]!;
            exerciseData[exerciseName] = {
              'maxWeight': weight > (current['maxWeight'] as double) ? weight : current['maxWeight'],
              'max1RM': calculated1RM > (current['max1RM'] as double) ? calculated1RM : current['max1RM'],
              'totalSets': (current['totalSets'] as int) + 1,
              'bestReps': reps > (current['bestReps'] as int) ? reps : current['bestReps'],
            };
          }
        }
      }
      
      setState(() {
        _exerciseHistory = exerciseData;
        _isLoadingWorkoutHistory = false;
      });
      
      debugPrint('✅ トレーニング履歴読み込み完了: ${exerciseData.length}種目');
      for (final entry in exerciseData.entries) {
        debugPrint('   ${entry.key}: 最大重量=${entry.value['maxWeight']}kg, 1RM=${entry.value['max1RM']?.toStringAsFixed(1)}kg');
      }
    } catch (e) {
      debugPrint('❌ トレーニング履歴読み込みエラー: $e');
      setState(() => _isLoadingWorkoutHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 説明文
          _buildDescription(),
          const SizedBox(height: 24),

          // 🔧 v1.0.217: レベル選択
          _buildLevelSelector(),
          const SizedBox(height: 24),

          // 部位選択
          _buildBodyPartSelector(),
          const SizedBox(height: 24),

          // メニュー生成ボタン
          _buildGenerateButton(),
          const SizedBox(height: 24),

          // 生成結果表示
          if (_generatedMenu != null) ...[
            _buildGeneratedMenu(),
            const SizedBox(height: 24),
          ],

          // エラー表示
          if (_errorMessage != null) ...[
            _buildErrorMessage(),
            const SizedBox(height: 24),
          ],

          // 履歴表示
          _buildHistory(),
        ],
      ),
    );
  }

  /// 説明文
  Widget _buildDescription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'AI powered トレーニング提案',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'トレーニングしたい部位を選択すると、AIが最適なメニューを提案します。',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 🔧 v1.0.217: レベル選択セクション
  Widget _buildLevelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'トレーニングレベル',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildLevelButton('初心者', Icons.fitness_center, Colors.green),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildLevelButton('中級者', Icons.trending_up, Colors.orange),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildLevelButton('上級者', Icons.emoji_events, Colors.red),
            ),
          ],
        ),
      ],
    );
  }
  
  /// レベルボタン
  Widget _buildLevelButton(String level, IconData icon, Color color) {
    final isSelected = _selectedLevel == level;
    
    return Material(
      color: isSelected ? color : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedLevel = level;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                level,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 部位選択セクション
  Widget _buildBodyPartSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'トレーニング部位を選択',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedBodyParts.keys.map((part) {
            final isSelected = _selectedBodyParts[part]!;
            final isBeginner = part == '初心者';

            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isBeginner) ...[
                    const Icon(Icons.school, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                  ],
                  Text(part),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedBodyParts[part] = selected;
                });
              },
              selectedColor: isBeginner
                  ? Colors.green.shade100
                  : Colors.blue.shade100,
              checkmarkColor: isBeginner
                  ? Colors.green.shade700
                  : Colors.blue.shade700,
              backgroundColor: isBeginner ? Colors.green.shade50 : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  /// メニュー生成ボタン
  Widget _buildGenerateButton() {
    final selectedParts = _selectedBodyParts.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final isEnabled = selectedParts.isNotEmpty && !_isGenerating;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? () {
          FocusScope.of(context).unfocus();
          _generateMenu(selectedParts);
        } : null,
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(_isGenerating ? 'AIが考え中...' : 'メニューを生成'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  /// 🔧 v1.0.220: 生成されたメニュー表示（チェックボックス付き）
  Widget _buildGeneratedMenu() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '提案されたメニュー',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    // 全選択/全解除ボタン
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_selectedExerciseIndices.length == _parsedExercises.length) {
                            _selectedExerciseIndices.clear();
                          } else {
                            _selectedExerciseIndices = Set.from(
                              List.generate(_parsedExercises.length, (i) => i)
                            );
                          }
                        });
                      },
                      icon: Icon(
                        _selectedExerciseIndices.length == _parsedExercises.length
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                      ),
                      label: Text(
                        _selectedExerciseIndices.length == _parsedExercises.length
                            ? '全解除'
                            : '全選択',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: _saveMenu,
                      tooltip: '保存',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            // 🔧 v1.0.220: パース済み種目リスト（チェックボックス付き）
            if (_parsedExercises.isNotEmpty) ...[
              ..._parsedExercises.asMap().entries.map((entry) {
                final index = entry.key;
                final exercise = entry.value;
                final isSelected = _selectedExerciseIndices.contains(index);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? Colors.blue.shade50 : null,
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedExerciseIndices.add(index);
                        } else {
                          _selectedExerciseIndices.remove(index);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getBodyPartColor(exercise.bodyPart),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            exercise.bodyPart,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        // 🔧 v1.0.237: 有酸素運動と筋トレで表示を分ける
                        if (exercise.isCardio) 
                          // 有酸素運動の表示: 距離/時間
                          Wrap(
                            spacing: 12,
                            children: [
                              if (exercise.distance != null && exercise.distance! > 0)
                                _buildInfoChip(Icons.straighten, '${exercise.distance}km'),
                              if (exercise.duration != null)
                                _buildInfoChip(Icons.timer, '${exercise.duration}分'),
                              if (exercise.sets != null)
                                _buildInfoChip(Icons.layers, '${exercise.sets}セット'),
                            ],
                          )
                        else
                          // 筋トレの表示: 重さ/回数
                          Wrap(
                            spacing: 12,
                            children: [
                              if (exercise.weight != null)
                                _buildInfoChip(Icons.fitness_center, '${exercise.weight}kg'),
                              if (exercise.reps != null)
                                _buildInfoChip(Icons.repeat, '${exercise.reps}回'),
                              if (exercise.sets != null)
                                _buildInfoChip(Icons.layers, '${exercise.sets}セット'),
                            ],
                          ),
                        if (exercise.description != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            exercise.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
              
              // 🔧 v1.0.222: トレーニングを開始ボタン（記録画面に遷移）
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedExerciseIndices.isEmpty
                      ? null
                      : _saveSelectedExercisesToWorkoutLog,
                  icon: const Icon(Icons.fitness_center),
                  label: Text(
                    'トレーニングを開始 (${_selectedExerciseIndices.length}種目)',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                ),
              ),
            ] else ...[
              // 🔧 v1.0.223-debug: パースに失敗した場合はエラーメッセージと生テキストを表示（デバッグ用）
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'メニューの解析に失敗しました',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'もう一度メニューを生成してください。\n問題が続く場合は、サポートにお問い合わせください。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _generatedMenu = null;
                            _parsedExercises.clear();
                            _errorMessage = null;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('再生成する'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      // 🐛 デバッグ用: 生成されたテキストを表示
                      ExpansionTile(
                        title: Text(
                          '🐛 デバッグ: 生成されたテキストを見る',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.grey.shade100,
                            child: SelectableText(
                              _generatedMenu ?? '',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// 🔧 v1.0.221: 部位別カラー取得（二頭・三頭対応）
  Color _getBodyPartColor(String bodyPart) {
    switch (bodyPart) {
      case '胸':
        return Colors.red.shade400;
      case '背中':
        return Colors.blue.shade400;
      case '脚':
        return Colors.green.shade400;
      case '肩':
        return Colors.orange.shade400;
      case '二頭':
        return Colors.purple.shade400;
      case '三頭':
        return Colors.deepPurple.shade400;
      case '腕': // 後方互換性
        return Colors.purple.shade300;
      case '腹筋':
        return Colors.teal.shade400;
      default:
        return Colors.grey.shade400;
    }
  }
  
  /// 🔧 v1.0.220: 情報チップウィジェット
  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// エラーメッセージ表示
  Widget _buildErrorMessage() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 履歴表示
  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '過去の提案',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingHistory)
          const Center(child: CircularProgressIndicator())
        else if (_history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('まだ履歴がありません'),
              ),
            ),
          )
        else
          ..._history.map((item) => _buildHistoryItem(item)),
      ],
    );
  }

  /// 履歴アイテム
  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final bodyParts = (item['bodyParts'] as List<dynamic>?)?.join(', ') ?? '';
    final createdAt = (item['createdAt'] as Timestamp?)?.toDate();
    final menu = item['menu'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(bodyParts),
        subtitle: Text(
          createdAt != null
              ? '${createdAt.month}/${createdAt.day} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
              : '',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFormattedText(menu),
          ),
        ],
      ),
    );
  }

  /// Markdown形式テキストをフォーマット済みウィジェットに変換
  Widget _buildFormattedText(String text) {
    final lines = text.split('\n');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      // 1. 見出し処理（## Text → 太字テキスト）
      if (line.trim().startsWith('##')) {
        final headingText = line.replaceFirst(RegExp(r'^##\s*'), '');
        spans.add(
          TextSpan(
            text: headingText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.8,
            ),
          ),
        );
        if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
        continue;
      }

      // 2. 箇条書き処理（* → ・）
      if (line.trim().startsWith('*')) {
        line = line.replaceFirst(RegExp(r'^\*\s*'), '・');
      }

      // 3. 太字処理（**text** → 太字）
      final boldPattern = RegExp(r'\*\*(.+?)\*\*');
      final matches = boldPattern.allMatches(line);

      if (matches.isEmpty) {
        // 太字なし → 通常テキスト
        spans.add(TextSpan(text: line));
      } else {
        // 太字あり → パースして分割
        int lastIndex = 0;
        for (final match in matches) {
          // 太字前のテキスト
          if (match.start > lastIndex) {
            spans.add(TextSpan(text: line.substring(lastIndex, match.start)));
          }
          // 太字テキスト
          spans.add(
            TextSpan(
              text: match.group(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
          lastIndex = match.end;
        }
        // 太字後のテキスト
        if (lastIndex < line.length) {
          spans.add(TextSpan(text: line.substring(lastIndex)));
        }
      }

      // 改行追加（最終行以外）
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.black87,
        ),
        children: spans,
      ),
    );
  }

  /// AIメニュー生成（サブスクリプションチェック統合）
  Future<void> _generateMenu(List<String> bodyParts) async {
    // ========================================
    // 🔐 Step 1: サブスクリプション状態チェック
    // ========================================
    final subscriptionService = SubscriptionService();
    final creditService = AICreditService();
    final rewardAdService = globalRewardAdService;
    
    final currentPlan = await subscriptionService.getCurrentPlan();
    debugPrint('🔍 [AI生成] 現在のプラン: $currentPlan');
    
    // ========================================
    // 🎯 Step 2: AI利用可能性チェック
    // ========================================
    final canUseAIResult = await creditService.canUseAI();
    debugPrint('🔍 [AI生成] AI使用可能: ${canUseAIResult.allowed}');
    
    if (!canUseAIResult.allowed) {
      // 無料プランでAIクレジットがない場合
      if (currentPlan == SubscriptionType.free) {
        // リワード広告で獲得可能かチェック
        final canEarnFromAd = await creditService.canEarnCreditFromAd();
        debugPrint('🔍 [AI生成] 広告視聴可能: $canEarnFromAd');
        
        if (canEarnFromAd) {
          // ========================================
          // 📺 Step 3: リワード広告ダイアログ表示
          // ========================================
          final shouldShowAd = await _showRewardAdDialog();
          
          if (shouldShowAd == true) {
            // 広告を表示してクレジット獲得
            final adSuccess = await _showRewardAdAndEarn();
            
            if (!adSuccess) {
              // 広告表示失敗
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('広告の読み込みに失敗しました。しばらくしてからお試しください。'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
            // 広告視聴成功 → 下記のAI生成処理に進む
          } else {
            // ユーザーがキャンセル
            return;
          }
        } else {
          // 今月の広告視聴上限に達している
          if (mounted) {
            await _showUpgradeDialog('今月の無料AI利用回数を使い切りました');
          }
          return;
        }
      } else {
        // 有料プランで月次上限に達している
        if (mounted) {
          await _showUpgradeDialog('今月のAI利用回数を使い切りました');
        }
        return;
      }
    }
    
    // ========================================
    // 🤖 Step 4: AI生成処理（クレジット消費含む）
    // ========================================
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generatedMenu = null;
    });

    try {
      debugPrint('🤖 Gemini APIでメニュー生成開始: ${bodyParts.join(', ')}');

      // Gemini 2.0 Flash API呼び出し
      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=AIzaSyAFVfcWzXDTtc9Rk3Zr5OGRx63FXpMAHqY'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': _buildPrompt(bodyParts),
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3, // 🔧 v1.0.226: 一貫性のある出力のため低く設定
            'topK': 20,
            'topP': 0.85,
            'maxOutputTokens': 2048,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;

        // ========================================
        // ✅ Step 5: AI生成成功 → クレジット消費
        // ========================================
        final consumeSuccess = await creditService.consumeAICredit();
        debugPrint('✅ AIクレジット消費: $consumeSuccess');
        
        // 🔧 v1.0.223: メニューをパースして種目抽出
        debugPrint('📄 生成されたメニュー（最初の500文字）:\n${text.substring(0, text.length > 500 ? 500 : text.length)}');
        
        final parsedExercises = _parseGeneratedMenu(text, bodyParts);
        
        debugPrint('✅ メニュー生成成功: ${parsedExercises.length}種目抽出');
        if (parsedExercises.isEmpty) {
          debugPrint('⚠️ 警告: パースされた種目が0件です。メニューの形式を確認してください。');
        }
        
        setState(() {
          _generatedMenu = text;
          _parsedExercises = parsedExercises;
          _selectedExerciseIndices.clear(); // 選択をリセット
          _isGenerating = false;
        });
        
        // 残りクレジット表示
        if (mounted) {
          final statusMessage = await creditService.getAIUsageStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI生成完了! ($statusMessage)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ メニュー生成エラー: $e');
      setState(() {
        _errorMessage = 'メニュー生成に失敗しました: $e';
        _isGenerating = false;
      });
    }
  }
  
  /// 🔧 v1.0.223: AI生成メニューをパースして種目データを抽出（完全内部処理）
  List<ParsedExercise> _parseGeneratedMenu(String menu, List<String> bodyParts) {
    debugPrint('🔍 パース開始: 全${menu.length}文字, ${menu.split('\n').length}行');
    
    final exercises = <ParsedExercise>[];
    final lines = menu.split('\n');
    
    String currentBodyPart = '';
    String currentExerciseName = '';
    String currentDescription = '';
    double? currentWeight;
    int? currentReps;
    int? currentSets;
    
    // 🔧 v1.0.221: 部位マッピング（二頭・三頭を分離）
    // 🔧 v1.0.226: 有酸素を追加
    final bodyPartMap = {
      '胸': '胸',
      '大胸筋': '胸',
      '背中': '背中',
      '広背筋': '背中',
      '僧帽筋': '背中',
      '脚': '脚',
      '大腿': '脚',
      '下半身': '脚',
      '肩': '肩',
      '三角筋': '肩',
      '二頭': '二頭',
      '上腕二頭筋': '二頭',
      '三頭': '三頭',
      '上腕三頭筋': '三頭',
      '腕': '腕', // 後方互換性のため残す
      '上腕': '腕',
      '腹筋': '腹筋',
      '腹': '腹筋',
      'コア': '腹筋',
      '有酸素': '有酸素', // 🔧 v1.0.226: 有酸素運動対応
      'カーディオ': '有酸素',
      '心肺': '有酸素',
    };
    
    debugPrint('🔍 パーサー開始: 全${lines.length}行を処理');
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      debugPrint('  📄 処理中: $line');
      
      // 🔧 v1.0.226: 部位の検出（■、【】、## または単一#で囲まれた部位名）
      // ### はサブセクションなので無視
      if (line.startsWith('■') || line.startsWith('【') || 
          (line.startsWith('##') && !line.startsWith('###')) ||
          (line.startsWith('#') && !line.startsWith('##'))) {
        for (final key in bodyPartMap.keys) {
          if (line.contains(key)) {
            currentBodyPart = bodyPartMap[key]!;
            debugPrint('  📍 部位検出: $currentBodyPart (行: $line)');
            break;
          }
        }
        continue;
      }
      
      // ### はサブセクション（スキップ）
      if (line.startsWith('###')) {
        debugPrint('  ⏭️  サブセクションをスキップ: $line');
        continue;
      }
      
      // 🔧 v1.0.226: 種目名の検出（複数パターンに対応）
      // パターン1: "1. 種目名" or "1) 種目名"
      final exercisePattern = RegExp(r'^(\d+[\.\)]\s*)(.+?)(?:[:：]|$)');
      final match = exercisePattern.firstMatch(line);
      
      // パターン2: "・ 種目名：" のような形式（ウォームアップなど）
      final altExercisePattern = RegExp(r'^[・\*]\s*(.+?)(?:[:：]\s*\*\*|$)');
      final altMatch = altExercisePattern.firstMatch(line);
      
      // パターン3: "**種目1：種目名**" のようなマークダウン形式
      final markdownPattern = RegExp(r'^\*\*種目\d+[:：](.+?)\*\*');
      final markdownMatch = markdownPattern.firstMatch(line);
      
      // パターン4: "**A1. EZバーカール**" のような英数字番号付き形式
      final alphaNumPattern = RegExp(r'^\*\*[A-Z]\d+[\.\)]\s*(.+?)\*\*');
      final alphaNumMatch = alphaNumPattern.firstMatch(line);
      
      // 詳細情報行の判定（先頭がスペースまたはタブ、または「•」「*」で始まる）
      final isDetailLine = line.startsWith('  ') || line.startsWith('\t') || 
                           line.startsWith('•') || 
                           (line.startsWith('*') && markdownMatch == null);
      
      if ((match != null || altMatch != null || markdownMatch != null || alphaNumMatch != null) && !isDetailLine) {
        // 前の種目を保存
        if (currentExerciseName.isNotEmpty && currentBodyPart.isNotEmpty) {
          // 🔧 v1.0.237: 有酸素運動かどうかを判定
          final isCardio = currentBodyPart == '有酸素';
          
          if (isCardio) {
            // 有酸素運動の場合: duration（時間）とdistance（距離）を使用
            final finalDuration = currentReps; // repsに時間が入っている
            final finalDistance = currentWeight; // weightに距離が入っている可能性
            final finalSets = currentSets ?? 1; // 有酸素は通常1セット
            
            debugPrint('  💾 有酸素種目保存: $currentExerciseName - duration=$finalDuration分, distance=$finalDistance, sets=$finalSets');
            
            exercises.add(ParsedExercise(
              name: currentExerciseName,
              bodyPart: currentBodyPart,
              isCardio: true,
              duration: finalDuration,
              distance: finalDistance,
              sets: finalSets,
              description: currentDescription.isNotEmpty ? currentDescription : null,
            ));
          } else {
            // 筋トレの場合: weight, reps, setsを使用
            final finalWeight = currentWeight ?? 0.0;
            final finalReps = currentReps ?? 10;
            final finalSets = currentSets ?? 3;
            
            debugPrint('  💾 筋トレ種目保存: $currentExerciseName - weight=$finalWeight, reps=$finalReps, sets=$finalSets');
            
            exercises.add(ParsedExercise(
              name: currentExerciseName,
              bodyPart: currentBodyPart,
              isCardio: false,
              weight: finalWeight,
              reps: finalReps,
              sets: finalSets,
              description: currentDescription.isNotEmpty ? currentDescription : null,
            ));
          }
        }
        
        // 🔧 v1.0.226: 種目名の抽出（4パターンに対応）
        var name = '';
        if (match != null) {
          name = match.group(2)!.trim();
        } else if (altMatch != null) {
          name = altMatch.group(1)!.trim();
        } else if (markdownMatch != null) {
          name = markdownMatch.group(1)!.trim();
        } else if (alphaNumMatch != null) {
          name = alphaNumMatch.group(1)!.trim();
        }
        
        // **で囲まれた部分があれば除去
        name = name.replaceAll('**', '').trim();
        
        // 🔧 v1.0.226-fix: コロンがあれば後ろの部分（実際の種目名）を取得
        if (name.contains('：')) {
          // 「種目1：ショルダープレス」→「ショルダープレス」
          final parts = name.split('：');
          name = parts.length > 1 ? parts[1].trim() : parts[0].trim();
        }
        if (name.contains(':')) {
          final parts = name.split(':');
          name = parts.length > 1 ? parts[1].trim() : parts[0].trim();
        }
        
        // 括弧内の補足情報を除去（例: ベンチプレス（バーベル）→ ベンチプレス）
        name = name.replaceAll(RegExp(r'[（\(][^）\)]*[）\)]'), '').trim();
        
        currentExerciseName = name;
        currentDescription = '';
        currentWeight = null;
        currentReps = null;
        currentSets = null;
        
        debugPrint('  ✅ 種目検出: $currentExerciseName (部位: $currentBodyPart)');
        
        // 同じ行に重量・回数・セット情報があるか確認
        final weightPattern = RegExp(r'(\d+(?:\.\d+)?)\s*kg');
        final repsPattern = RegExp(r'(\d+)\s*(?:回|reps?)');
        final setsPattern = RegExp(r'(\d+)\s*(?:セット|sets?)');
        final timePattern = RegExp(r'(\d+)\s*分(?:\s*（|\s*\()?');
        
        final weightMatch = weightPattern.firstMatch(line);
        final repsMatch = repsPattern.firstMatch(line);
        final setsMatch = setsPattern.firstMatch(line);
        final timeMatch = timePattern.firstMatch(line);
        
        if (weightMatch != null) currentWeight = double.tryParse(weightMatch.group(1)!);
        if (repsMatch != null) currentReps = int.tryParse(repsMatch.group(1)!);
        // 🔧 v1.0.226: 有酸素運動の場合のみ、時間をrepsとして扱う
        if (timeMatch != null && currentReps == null && currentBodyPart == '有酸素') {
          currentReps = int.tryParse(timeMatch.group(1)!);
        }
        if (setsMatch != null) currentSets = int.tryParse(setsMatch.group(1)!);
      } else if (currentExerciseName.isNotEmpty) {
        // 種目の説明や詳細情報
        if (line.startsWith('説明:') || line.startsWith('説明：')) {
          currentDescription = line.replaceFirst(RegExp(r'説明[:：]\s*'), '');
        } else if (!line.startsWith('■') && !line.startsWith('【') && !line.startsWith('##') && !line.startsWith('#')) {
          // 🔧 v1.0.224: *や・、•で始まる行、または通常の行から重量・回数・セット情報を抽出
          String cleanLine = line;
          // マークダウンの **説明:** のような形式に対応
          if (line.startsWith('* **') || line.startsWith('• **')) {
            cleanLine = line.substring(2).trim();
            // **を除去
            cleanLine = cleanLine.replaceAll('**', '').trim();
          } else if (line.startsWith('*') || line.startsWith('・') || line.startsWith('-') || line.startsWith('•')) {
            cleanLine = line.substring(1).trim();
          }
          // インデントされた行の処理
          cleanLine = cleanLine.trim();
          
          // 🔧 v1.0.224: 重量・回数・セット数の抽出（複数パターン対応）
          // パターン1: "重量: XXkg" または "重量: 男性: XX-XXkg"
          final weightPattern = RegExp(r'重量[:：]?\s*(?:男性[:：]?\s*)?(\d+(?:\.\d+)?)(?:-\d+(?:\.\d+)?)?(?:kg)?');
          final repsPattern = RegExp(r'回数[:：]?\s*(\d+)\s*(?:回|reps?)?');
          final setsPattern = RegExp(r'セット数[:：]?\s*(\d+)\s*(?:セット|sets?)?');
          
          // パターン2: 単純な "XXkg", "XX回", "XXセット"
          final weightPattern2 = RegExp(r'(\d+(?:\.\d+)?)\s*(?:-\d+(?:\.\d+)?)?\s*kg');
          final repsPattern2 = RegExp(r'(\d+)\s*回');
          final setsPattern2 = RegExp(r'(\d+)\s*セット');
          
          // 🔧 v1.0.226: 有酸素運動用のパターン（時間）- 括弧付き説明にも対応
          final timePattern = RegExp(r'(?:時間|HIIT形式)[:：]?\s*(\d+)\s*分');
          final timePattern2 = RegExp(r'(\d+)\s*分(?:\s*（|\s*\()?');
          
          var weightMatch = weightPattern.firstMatch(cleanLine);
          var repsMatch = repsPattern.firstMatch(cleanLine);
          var setsMatch = setsPattern.firstMatch(cleanLine);
          var timeMatch = timePattern.firstMatch(cleanLine);
          
          // 代替パターンでも試す
          if (weightMatch == null) weightMatch = weightPattern2.firstMatch(cleanLine);
          if (repsMatch == null) repsMatch = repsPattern2.firstMatch(cleanLine);
          if (setsMatch == null) setsMatch = setsPattern2.firstMatch(cleanLine);
          if (timeMatch == null) timeMatch = timePattern2.firstMatch(cleanLine);
          
          if (weightMatch != null && currentWeight == null) {
            currentWeight = double.tryParse(weightMatch.group(1)!);
          }
          if (repsMatch != null && currentReps == null) {
            currentReps = int.tryParse(repsMatch.group(1)!);
          }
          // 🔧 v1.0.226: 有酸素運動の場合のみ、時間をrepsとして扱う
          if (timeMatch != null && currentReps == null && currentBodyPart == '有酸素') {
            currentReps = int.tryParse(timeMatch.group(1)!);
            debugPrint('  ⏱️ 有酸素時間検出: ${timeMatch.group(1)}分 → reps=$currentReps (line: $cleanLine)');
          }
          if (setsMatch != null && currentSets == null) {
            currentSets = int.tryParse(setsMatch.group(1)!);
            debugPrint('  📊 セット数検出: ${setsMatch.group(1)}セット');
          }
          
          // デバッグ: パース状態を確認
          if (currentExerciseName.isNotEmpty && (weightMatch != null || repsMatch != null || timeMatch != null || setsMatch != null)) {
            debugPrint('  📝 現在の状態 ($currentExerciseName): weight=$currentWeight, reps=$currentReps, sets=$currentSets');
          }
          
          // 🔧 v1.0.226: 休憩時間、ポイントなどの無関係な行をスキップ
          final isIgnoredLine = cleanLine.contains('休憩時間') || 
                               cleanLine.contains('ポイント') ||
                               cleanLine.contains('フォームのポイント') ||
                               cleanLine.contains('説明') ||
                               cleanLine.contains('高度なテクニック') ||
                               cleanLine.contains('テクニックのポイント');
          
          // 説明の続き（重量・回数・セット情報がない場合、かつ無視すべき行ではない場合）
          if (!isIgnoredLine && currentDescription.isNotEmpty && weightMatch == null && repsMatch == null && timeMatch == null && setsMatch == null) {
            currentDescription += ' ' + cleanLine;
          }
        }
      }
    }
    
    // 最後の種目を保存
    if (currentExerciseName.isNotEmpty && currentBodyPart.isNotEmpty) {
      // 🔧 v1.0.237: 有酸素運動かどうかを判定
      final isCardio = currentBodyPart == '有酸素';
      
      if (isCardio) {
        // 有酸素運動の場合: duration（時間）とdistance（距離）を使用
        final finalDuration = currentReps; // repsに時間が入っている
        final finalDistance = currentWeight; // weightに距離が入っている可能性
        final finalSets = currentSets ?? 1; // 有酸素は通常1セット
        
        debugPrint('  💾 有酸素種目保存: $currentExerciseName - duration=$finalDuration分, distance=$finalDistance, sets=$finalSets');
        
        exercises.add(ParsedExercise(
          name: currentExerciseName,
          bodyPart: currentBodyPart,
          isCardio: true,
          duration: finalDuration,
          distance: finalDistance,
          sets: finalSets,
          description: currentDescription.isNotEmpty ? currentDescription : null,
        ));
      } else {
        // 筋トレの場合: weight, reps, setsを使用
        final finalWeight = currentWeight ?? 0.0;
        final finalReps = currentReps ?? 10;
        final finalSets = currentSets ?? 3;
        
        debugPrint('  💾 筋トレ種目保存: $currentExerciseName - weight=$finalWeight, reps=$finalReps, sets=$finalSets');
        
        exercises.add(ParsedExercise(
          name: currentExerciseName,
          bodyPart: currentBodyPart,
          isCardio: false,
          weight: finalWeight,
          reps: finalReps,
          sets: finalSets,
          description: currentDescription.isNotEmpty ? currentDescription : null,
        ));
      }
    }
    
    debugPrint('📝 パース結果: ${exercises.length}種目抽出');
    if (exercises.isEmpty) {
      debugPrint('❌ エラー: 1つも種目が抽出できませんでした！');
      debugPrint('📋 最後の状態:');
      debugPrint('  - currentExerciseName: $currentExerciseName');
      debugPrint('  - currentBodyPart: $currentBodyPart');
      debugPrint('  - currentWeight: $currentWeight');
      debugPrint('  - currentReps: $currentReps');
      debugPrint('  - currentSets: $currentSets');
    } else {
      for (final ex in exercises) {
        if (ex.isCardio) {
          debugPrint('  ✅ ${ex.name} (${ex.bodyPart}): ${ex.duration}分, ${ex.distance ?? 0}km, ${ex.sets}セット [有酸素]');
        } else {
          debugPrint('  ✅ ${ex.name} (${ex.bodyPart}): ${ex.weight}kg, ${ex.reps}回, ${ex.sets}セット [筋トレ]');
        }
      }
    }
    
    return exercises;
  }

  /// 🔧 v1.0.219: 初心者向けトレーニング種目データベース（説明付き）
  static const String _beginnerExerciseDatabase = '''
【初心者向けトレーニング種目一覧】以下から選択し、必ず説明を含めてください。

■胸（大胸筋）:
1. チェストプレスマシン
   説明: 軌道が固定されており最も安全。座ったまま胸の前でバーを押し出す。大胸筋全体を鍛える基本種目。

2. ダンベルベンチプレス
   説明: ベンチに仰向けになりダンベルを胸の上で押し上げる。バーベルより可動域が広く、バランス感覚も養える。

3. ペックフライマシン
   説明: 座った状態で両腕を胸の前で閉じる動作。大胸筋のストレッチと収縮を意識しやすい。

■背中（広背筋・僧帽筋）:
1. ラットプルダウン
   説明: 座った状態でバーを上から引き下ろす。懸垂ができない初心者に最適な背中の基本種目。

2. シーテッドロー
   説明: 座った状態でケーブルやバーを胸に向かって引く。広背筋と僧帽筋を効率的に鍛える。

3. バックエクステンション
   説明: うつ伏せで上体を起こす。脊柱起立筋を鍛え、姿勢改善に効果的。

■脚（大腿四頭筋・ハムストリングス）:
1. レッグプレスマシン
   説明: 座った状態で足でプレートを押し出す。スクワットより安全で、大腿四頭筋・ハムストリングス・大臀筋を鍛える。

2. レッグエクステンション
   説明: 座った状態で膝を伸ばす動作。大腿四頭筋（太もも前側）を集中的に鍛える。

3. レッグカール
   説明: うつ伏せで膝を曲げる動作。ハムストリングス（太もも裏側）を集中的に鍛える。

■肩（三角筋）:
1. ショルダープレスマシン
   説明: 座った状態でバーを頭上に押し上げる。三角筋全体を安全に鍛えられる。

2. サイドレイズ（ダンベル）
   説明: 両手にダンベルを持ち、腕を横に上げる。三角筋中部を重点的に鍛える。

■二頭（上腕二頭筋）:
1. ダンベルカール
   説明: ダンベルを持ち肘を曲げて持ち上げる。上腕二頭筋（力こぶ）を鍛える基本種目。

2. ハンマーカール
   説明: 親指を上にしてダンベルを持ち上げる。二頭筋と前腕を同時に鍛えられる。

3. マシンアームカール
   説明: 軌道が固定されており初心者に安全。座った状態で肘を曲げる。

■三頭（上腕三頭筋）:
1. トライセプスプレスダウン
   説明: ケーブルマシンでバーを下に押し下げる。上腕三頭筋（二の腕）を鍛える基本種目。

2. トライセプスキックバック
   説明: ダンベルを持ち、後ろに押し出す動作。三頭筋の収縮を意識しやすい。

3. マシンディップス
   説明: 補助付きで安全に三頭筋を鍛える。体を上下させる動作。

■腹筋（腹直筋・腹斜筋）:
1. アブドミナルクランチマシン
   説明: マシンで上体を丸める動作。腹直筋を効率的に鍛えられる。

2. プランク
   説明: うつ伏せで肘と つま先で体を支える。体幹全体を鍛える基礎種目。

■有酸素運動:
1. ランニング（トレッドミル）
   説明: 有酸素運動の王道。心肺機能向上と脂肪燃焼に効果的。時速6-8km/hから開始推奨。

2. エアロバイク
   説明: 膝への負担が少なく、有酸素運動初心者に最適。心拍数を管理しやすい。

3. ウォーキング（トレッドミル）
   説明: 最も負担が少ない有酸素運動。運動習慣がない方の第一歩に最適。

4. クロストレーナー
   説明: 全身を使う有酸素運動。関節への負担が少なく、消費カロリーが高い。

5. ステッパー
   説明: 階段を登る動作を再現。下半身と心肺機能を同時に鍛えられる。

6. 水泳
   説明: 全身運動で関節への負担が最小。心肺機能と筋持久力を同時に向上。

**重要**: 必ず上記の説明を含めて提案すること。
''';

  /// 🔧 v1.0.219: 中・上級者向けトレーニング種目データベース（種目名のみ）
  static const String _advancedExerciseDatabase = '''
【中・上級者向けトレーニング種目一覧】以下から選択してください。

■胸（大胸筋）:
ベンチプレス（バーベル）、インクラインベンチプレス、デクラインベンチプレス、ダンベルベンチプレス、インクラインダンベルプレス、ダンベルフライ、インクラインフライ、ケーブルクロスオーバー、ディップス（胸重視）、チェストプレスマシン、ペックフライマシン

■背中（広背筋・僧帽筋・脊柱起立筋）:
デッドリフト（バーベル）、ラットプルダウン（ワイド）、ラットプルダウン（ナロー）、チンニング（懸垂）、ベントオーバーロー、ワンハンドダンベルロー、Tバーロー、シーテッドロー、ケーブルロー、バックエクステンション、シュラッグ

■脚（大腿四頭筋・ハムストリングス・大臀筋）:
バーベルスクワット、フロントスクワット、ブルガリアンスクワット、レッグプレスマシン、レッグエクステンション、レッグカール、ルーマニアンデッドリフト、ランジ（フロント）、ランジ（バック）、レッグアブダクション、レッグアダクション、カーフレイズ、ヒップスラスト

■肩（三角筋）:
ショルダープレス（バーベル）、ダンベルショルダープレス、マシンショルダープレス、サイドレイズ（ダンベル）、ケーブルサイドレイズ、フロントレイズ、リアレイズ（ダンベル）、ケーブルリアレイズ、アップライトロー、フェイスプル

■二頭（上腕二頭筋）:
バーベルカール（ストレート）、EZバーカール、ダンベルカール（オルタネイト）、ハンマーカール、プリチャーカール、インクラインダンベルカール、コンセントレーションカール、ケーブルカール、チンアップ（逆手懸垂）、21カール、ドラッグカール、ゾットマンカール、マシンアームカール

■三頭（上腕三頭筋）:
トライセプスプレスダウン、ケーブルプレスダウン、ライイングトライセプスエクステンション、スカルクラッシャー、オーバーヘッドトライセプスエクステンション、ディップス（三頭筋重視）、トライセプスキックバック、キックバック、クローズグリップベンチプレス、ケーブルオーバーヘッドエクステンション、リバースグリッププレスダウン、ダンベルトライセプスエクステンション、JMプレス、ダイヤモンドプッシュアップ、ベンチディップス、マシンディップス

■腹筋（腹直筋・腹斜筋・腹横筋）:
クランチ、レッグレイズ、ハンギングレッグレイズ、ケーブルクランチ、アブローラー、プランク、サイドプランク、ロシアンツイスト、マウンテンクライマー、バイシクルクランチ、ドラゴンフラッグ

■有酸素運動:
ランニング（トレッドミル）、ジョギング（屋外）、エアロバイク、ウォーキング（トレッドミル）、インターバルラン、クロストレーナー、ステッパー、水泳、ローイングマシン、バトルロープ、バーピージャンプ、マウンテンクライマー（高強度）

**重要**: 種目名・重量・回数のみ簡潔に記載。説明は不要。
''';

  /// 🔧 v1.0.217: プロンプト構築（レベル別 + トレーニング履歴考慮 + v1.0.219: レベル別種目DB）
  String _buildPrompt(List<String> bodyParts) {
    // トレーニング履歴情報を構築
    String historyInfo = '';
    if (_exerciseHistory.isNotEmpty) {
      historyInfo = '\n【直近1ヶ月のトレーニング履歴】\n';
      for (final entry in _exerciseHistory.entries) {
        final exerciseName = entry.key;
        final maxWeight = entry.value['maxWeight'];
        final max1RM = entry.value['max1RM'];
        final totalSets = entry.value['totalSets'];
        historyInfo += '- $exerciseName: 最大重量=${maxWeight}kg, 推定1RM=${max1RM?.toStringAsFixed(1)}kg, 総セット数=$totalSets\n';
      }
      historyInfo += '\n上記の履歴を参考に、適切な重量と回数を提案してください。\n';
    }
    
    final targetParts = bodyParts;

    // レベル別プロンプト構築
    if (_selectedLevel == '初心者') {
      // 初心者向け
      if (targetParts.isEmpty) {
        return '''
あなたはプロのパーソナルトレーナーです。筋トレ初心者向けの全身トレーニングメニューを提案してください。

$_beginnerExerciseDatabase
$historyInfo
【対象者】
- 筋トレ初心者（ジム通い始めて1〜3ヶ月程度）
- 基礎体力づくりを目指す方
- トレーニングフォームを学びたい方

【提案形式】
**必ずこの形式で出力してください：**

```
## 部位トレーニングメニュー

**種目1：種目名**
* 重量：XXkg
* 回数：XX回
* セット数：Xセット
* 休憩時間：XX秒
* フォームのポイント：説明文

**種目2：種目名**
* 重量：XXkg
* 回数：XX回
* セット数：Xセット
```

各種目について以下の情報を含めてください：
- 種目名（種目データベースから選択）
- **具体的な重量（kg）** ← 履歴があればそれを参考に、なければ初心者向けの推奨重量
  ※有酸素運動の場合は「重量：0kg」とし、回数の代わりに「時間：XX分」を記載
- **回数（10-15回）** ← 有酸素の場合は「時間：20-30分」
- セット数（2-3セット）← 有酸素の場合は「1セット」
- 休憩時間（90-120秒）
- 初心者向けフォームのポイント

【条件】
- 全身をバランスよく鍛える
- 基本種目中心
- 30-45分で完了
- 日本語で丁寧に説明

**重要: 各種目に具体的な重量と回数を必ず記載してください。有酸素運動の場合は重量0kg、時間をXX分形式で記載してください。**
''';
      } else {
        return '''
あなたはプロのパーソナルトレーナーです。筋トレ初心者向けの「${targetParts.join('、')}」トレーニングメニューを提案してください。

$_beginnerExerciseDatabase
$historyInfo
【対象者】
- 筋トレ初心者（ジム通い始めて1〜3ヶ月程度）
- ${targetParts.join('、')}を重点的に鍛えたい方

【提案形式】
**必ずこの形式で出力してください：**

```
## 部位トレーニングメニュー

**種目1：種目名**
* 重量：XXkg
* 回数：XX回
* セット数：Xセット
* 休憩時間：XX秒
* フォームのポイント：説明文

**種目2：種目名**
* 重量：XXkg
* 回数：XX回
* セット数：Xセット
```

各種目について以下の情報を含めてください：
- 種目名（種目データベースから選択）
- **具体的な重量（kg）** ← 履歴があればそれを参考に、なければ初心者向けの推奨重量
  ※有酸素運動の場合は「重量：0kg」とし、回数の代わりに「時間：XX分」を記載
- **回数（10-15回）** ← 有酸素の場合は「時間：20-30分」
- セット数（2-3セット）← 有酸素の場合は「1セット」
- 休憩時間（90-120秒）
- フォームのポイント

【条件】
- ${targetParts.join('、')}を重点的にトレーニング
${targetParts.contains('有酸素') ? "- **有酸素運動のみ**を提案（筋トレ種目は含めない）" : "- 基本種目中心"}
- 30-45分で完了
- 日本語で丁寧に説明

**重要: 各種目に具体的な重量と回数を必ず記載してください。有酸素運動の場合は重量0kg、時間をXX分形式で記載してください。**
${targetParts.contains('有酸素') ? "**絶対厳守: 有酸素運動データベースの種目のみ使用すること。ベンチプレス、スクワットなどの筋トレ種目は絶対に含めないこと。**" : ""}
''';
      }
    } else if (_selectedLevel == '中級者') {
      // 中級者向け
      return '''
あなたはプロのパーソナルトレーナーです。筋トレ中級者向けの「${targetParts.isEmpty ? "全身" : targetParts.join('、')}」トレーニングメニューを提案してください。

$_advancedExerciseDatabase
$historyInfo
【対象者】
- 筋トレ経験6ヶ月〜2年程度
- 筋力・筋肥大を目指す方
- より高度なテクニックを習得したい方

【提案形式】
**必ずこの形式で出力してください：**

```
## 部位トレーニングメニュー

**種目1：種目名**
* 重量：XXkg
* 回数：XX回
* セット数：Xセット
* 休憩時間：XX秒
* ポイント：説明文

**種目2：種目名**
* 重量：XXkg
* 回数：XX回
* セット数：Xセット
```

各種目について以下の情報を含めてください：
- 種目名（種目データベースから選択）
- **具体的な重量（kg）** ← 履歴の1RMの70-85%を目安に提案
  ※有酸素運動の場合は「重量：0kg」とし、回数の代わりに「時間：XX分」を記載
- **回数（8-12回）** ← 有酸素の場合は「時間：30-45分」または「インターバル形式」
- セット数（3-4セット）← 有酸素の場合は「1セット」
- 休憩時間（60-90秒）
- テクニックのポイント（ドロップセット、スーパーセット等）

【条件】
- ${targetParts.isEmpty ? "全身バランスよく" : targetParts.join('、')+"を重点的に"}
${targetParts.contains('有酸素') ? "- **有酸素運動のみ**を提案（筋トレ種目は含めない）\n- HIIT、持久走、インターバルなど多様な有酸素トレーニング" : "- フリーウェイト中心\n- 筋肥大を重視"}
- 45-60分で完了
- 日本語で説明

**重要: 各種目に具体的な重量と回数を必ず記載してください。有酸素運動の場合は重量0kg、時間をXX分形式で記載してください。**
${targetParts.contains('有酸素') ? "**絶対厳守: 有酸素運動データベースの種目のみ使用すること。ベンチプレス、スクワット、デッドリフトなどの筋トレ種目は絶対に含めないこと。**" : ""}
''';
    } else {
      // 上級者向け
      return '''
あなたはプロのパーソナルトレーナーです。筋トレ上級者向けの「${targetParts.isEmpty ? "全身" : targetParts.join('、')}」トレーニングメニューを提案してください。

$_advancedExerciseDatabase
$historyInfo
【対象者】
- 筋トレ経験2年以上
- 最大限の筋力・筋肥大を目指す方
- 高強度トレーニングに慣れている方

【提案形式】
**必ずこの形式で出力してください：**

```
## 部位トレーニングメニュー

**種目1：種目名**
* 重量：XXkg
* 回数：XX回
* セット数：Xセット
* 休憩時間：XX秒
* 高度なテクニック：説明文

**種目2：種目名**
* 重量：XXkg
* 回数：XX回
* セット数：Xセット
```

各種目について以下の情報を含めてください：
- 種目名（種目データベースから選択）
- **具体的な重量（kg）** ← 履歴の1RMの85-95%を目安に提案
  ※有酸素運動の場合は「重量：0kg」とし、回数の代わりに「時間：XX分」を記載
- **回数（5-8回）** ← 有酸素の場合は「HIIT形式：XX分」または「持久走：XX分」
- セット数（4-5セット）← 有酸素の場合は「1セット」
- 休憩時間（120-180秒）
- 高度なテクニック（ピラミッド法、5x5法等）

【条件】
- ${targetParts.isEmpty ? "全身最大限に" : targetParts.join('、')+"を極限まで"}
${targetParts.contains('有酸素') ? "- **有酸素運動のみ**を提案（筋トレ種目は含めない）\n- HIIT、タバタ式、持久走など高強度有酸素トレーニング" : "- 高重量フリーウェイト中心\n- 最大筋力向上を重視"}
- 60-90分で完了
- 日本語で説明

**重要: 各種目に具体的な重量と回数を必ず記載してください。有酸素運動の場合は重量0kg、時間をXX分形式で記載してください。**
${targetParts.contains('有酸素') ? "**絶対厳守: 有酸素運動データベースの種目のみ使用すること。ベンチプレス、スクワット、デッドリフト、ショルダープレスなどの筋トレ種目は絶対に含めないこと。**" : ""}
''';
    }
  }

  /// リワード広告ダイアログ表示
  Future<bool?> _showRewardAdDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.play_circle_outline, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('動画でAI機能解放'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '無料プランでは、動画広告を視聴することでAI機能を1回利用できます。',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '月3回まで動画視聴でAI利用可能',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('動画を視聴'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  /// リワード広告を表示してクレジット獲得
  Future<bool> _showRewardAdAndEarn() async {
    // グローバルインスタンスを使用（main.dartで初期化済み）
    final rewardAdService = globalRewardAdService;
    
    // 広告読み込み待機ダイアログ表示
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('広告を読み込んでいます...'),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // 広告を読み込む
    await rewardAdService.loadRewardedAd();
    
    // 読み込み完了まで最大5秒待機
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (rewardAdService.isAdReady()) {
        break;
      }
    }
    
    // ローディングダイアログを閉じる
    if (mounted) {
      Navigator.of(context).pop();
    }
    
    // 広告表示
    if (rewardAdService.isAdReady()) {
      final success = await rewardAdService.showRewardedAd();
      
      if (success) {
        // 広告視聴成功メッセージ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎁 AI機能1回分を獲得しました!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return true;
      }
    }
    
    return false;
  }
  
  /// アップグレード促進ダイアログ表示
  Future<void> _showUpgradeDialog(String message) async {
    // 🎯 新しいペイウォールダイアログを使用（AI追加パック訴求含む）
    return PaywallDialog.show(context, PaywallType.aiLimitReached);
  }
  
  /// メニュー保存
  /// 🔧 v1.0.222: 選択された種目をトレーニング記録画面に渡して遷移
  Future<void> _saveSelectedExercisesToWorkoutLog() async {
    try {
      if (_selectedExerciseIndices.isEmpty) return;
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('ユーザーが認証されていません');
      }
      
      // 選択された種目を抽出
      final selectedExercises = _selectedExerciseIndices
          .map((index) => _parsedExercises[index])
          .toList();
      
      debugPrint('✅ AIコーチ: ${selectedExercises.length}種目をトレーニング記録画面に渡します');
      
      // トレーニング記録画面に遷移（データを引き継ぐ）
      if (mounted) {
        await Navigator.of(context).pushNamed(
          '/add-workout',
          arguments: {
            'fromAICoach': true,
            'selectedExercises': selectedExercises,
            'userLevel': _selectedLevel, // 初心者・中級者・上級者
            'exerciseHistory': _exerciseHistory, // 1RM計算用の履歴
          },
        );
        
        // 戻ってきたら選択をリセット
        setState(() {
          _selectedExerciseIndices.clear();
        });
      }
    } catch (e) {
      debugPrint('❌ トレーニング記録画面への遷移エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画面遷移に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _saveMenu() async {
    try {
      if (_generatedMenu == null) return;

      final selectedParts = _selectedBodyParts.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('aiCoachingHistory')
          .add({
        'bodyParts': selectedParts,
        'menu': _generatedMenu,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('メニューを保存しました'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 履歴を再読み込み
      _loadHistory();

      debugPrint('✅ メニュー保存成功');
    } catch (e) {
      debugPrint('❌ メニュー保存エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ========================================
// Tab 2: 成長予測タブ
// ========================================

class _GrowthPredictionTab extends StatefulWidget {
  @override
  State<_GrowthPredictionTab> createState() => _GrowthPredictionTabState();
}

class _GrowthPredictionTabState extends State<_GrowthPredictionTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // フォーム入力値
  final _formKey = GlobalKey<FormState>();
  final _oneRMController = TextEditingController(); // 🔧 Phase 7 Fix: 1RM入力用コントローラー
  String _selectedLevel = '初心者';
  int _selectedFrequency = 3;
  String _selectedGender = '女性';
  String _selectedBodyPart = '大胸筋';
  int _selectedRPE = 8; // 🆕 v1.0.230: RPE（自覚的強度、デフォルト8）

  // 🆕 Phase 7: 自動取得データ
  int? _userAge; // 個人要因設定から取得
  double? _latestBodyWeight; // 体重記録から取得
  DateTime? _weightRecordedAt; // 体重記録日時
  double? _currentOneRM; // 予測の基準となる1RM
  String? _objectiveLevel; // Weight Ratioから判定された客観的レベル
  double? _weightRatio; // 1RM ÷ 体重

  // 予測結果
  Map<String, dynamic>? _predictionResult;
  bool _isLoading = false;  // ✅ 修正: 初期状態はローディングなし

  @override
  void initState() {
    super.initState();
    _loadUserData(); // 🆕 Phase 7: 年齢・体重を自動取得
  }

  // レベル選択肢
  final List<String> _levels = ['初心者', '中級者', '上級者'];

  // 部位選択肢
  final List<String> _bodyParts = [
    '大胸筋',
    '広背筋',
    '大腿四頭筋',
    '上腕二頭筋',
    '上腕三頭筋',
    '三角筋',
  ];

  @override
  void dispose() {
    _oneRMController.dispose(); // 🔧 Phase 7 Fix: コントローラーを破棄
    super.dispose();
  }

  // ========================================
  // 🆕 Phase 7: データ自動取得ロジック
  // ========================================

  /// ユーザーデータ（年齢・体重）を自動取得
  Future<void> _loadUserData() async {
    await _loadUserAge();
    await _loadLatestBodyWeight();
  }

  /// 個人要因設定から年齢を取得
  Future<void> _loadUserAge() async {
    try {
      final advancedFatigueService = AdvancedFatigueService();
      final userProfile = await advancedFatigueService.getUserProfile();
      
      if (mounted) {
        setState(() {
          _userAge = userProfile.age;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [Phase 7] 年齢取得エラー: $e');
      // エラー時は null のまま（未設定状態）
    }
  }

  /// 📝 体重記録から最新の体重を取得（インデックス不要・全データ対応版）
  /// 🔧 v1.0.236: Gemini提案を反映 - orderBy削除+クライアント側ソート+フィールド名ゆらぎ対応
  Future<void> _loadLatestBodyWeight() async {
    if (!mounted) return;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('⚠️ [Phase 7] ユーザーIDが取得できません（未ログイン）');
        if (mounted) {
          setState(() {
            _latestBodyWeight = null;
            _weightRecordedAt = null;
          });
        }
        return;
      }

      debugPrint('🔍 [Phase 7] 体重取得クエリ開始: userId=$userId');

      // 🎯 Gemini提案: orderByを削除し、単純なwhereのみで取得（インデックス不要で高速・確実）
      final snapshot = await FirebaseFirestore.instance
          .collection('body_measurements')
          .where('user_id', isEqualTo: userId)
          .get(); // ⚡ orderBy削除でFirestoreインデックス不要

      debugPrint('📊 [Phase 7] 取得ドキュメント数: ${snapshot.docs.length}件');

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ [Phase 7] データが0件です。体重記録画面で保存してください。');
        if (mounted) {
          setState(() {
            _latestBodyWeight = null;
            _weightRecordedAt = null;
          });
        }
        return;
      }

      // 🔍 デバッグ用: 最初の3件のデータ構造を出力
      for (int i = 0; i < snapshot.docs.length && i < 3; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();
        debugPrint('  [${i+1}] id: ${doc.id}');
        debugPrint('      weight: ${data['weight']} (${data['weight'].runtimeType})');
        debugPrint('      date: ${data['date']}');
        debugPrint('      timestamp: ${data['timestamp']}');
        debugPrint('      created_at: ${data['created_at']}');
      }

      // 🎯 Gemini提案: クライアント側でソート（日付フィールドのゆらぎを吸収）
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final dataA = a.data();
        final dataB = b.data();
        
        // 📌 date, timestamp, created_at の順で優先して日付を探す
        final timeA = (dataA['date'] ?? dataA['timestamp'] ?? dataA['created_at']) as Timestamp?;
        final timeB = (dataB['date'] ?? dataB['timestamp'] ?? dataB['created_at']) as Timestamp?;
        
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1; // 日付なしは後ろへ
        if (timeB == null) return -1;
        
        return timeB.compareTo(timeA); // 降順（新しい順）
      });

      // ✅ 最新のデータを取得
      final latestDoc = docs.first;
      final latestData = latestDoc.data();
      final weight = latestData['weight'] as num?; // int/double両対応
      
      // 日付の確認（デバッグ用）
      final recordDate = (latestData['date'] ?? latestData['timestamp'] ?? latestData['created_at']) as Timestamp?;

      debugPrint('✅ [Phase 7] 最新データ特定: ID=${latestDoc.id}, 体重=${weight}kg, 日付=${recordDate?.toDate()}');

      if (weight != null && weight > 0) {
        if (mounted) {
          setState(() {
            _latestBodyWeight = weight.toDouble();
            _weightRecordedAt = recordDate?.toDate();
          });
          
          // 🎯 Weight Ratio計算準備完了の通知
          debugPrint('🎯 [Phase 7] Weight Ratio計算準備完了: 体重=${weight}kg');
        }
      } else {
        debugPrint('⚠️ [Phase 7] 体重データが無効またはゼロ: weight=$weight');
        if (mounted) {
          setState(() {
            _latestBodyWeight = null;
            _weightRecordedAt = null;
          });
        }
      }
    } catch (e, stack) {
      debugPrint('❌ [Phase 7] 体重取得で例外発生: $e');
      debugPrint('   StackTrace: $stack');
      if (mounted) {
        setState(() {
          _latestBodyWeight = null;
          _weightRecordedAt = null;
        });
      }
    }
  }

  /// Weight Ratioを計算し、客観的レベルを判定
  void _calculateWeightRatioAndLevel(double oneRM) {
    if (_latestBodyWeight == null || _latestBodyWeight! <= 0) {
      setState(() {
        _weightRatio = null;
        _objectiveLevel = null;
      });
      return;
    }

    final ratio = oneRM / _latestBodyWeight!;
    final detectedLevel = ScientificDatabase.detectLevelFromWeightRatio(
      oneRM: oneRM,
      bodyWeight: _latestBodyWeight!,
      exerciseName: _selectedBodyPart,
      gender: _selectedGender,
    );

    setState(() {
      _currentOneRM = oneRM;
      _weightRatio = ratio;
      _objectiveLevel = detectedLevel;
    });
  }

  /// 成長予測を実行(サブスクリプションチェック統合)
  Future<void> _executePrediction() async {
    if (!_formKey.currentState!.validate()) return;

    // ========================================
    // 🔐 Step 1: サブスクリプション状態チェック
    // ========================================
    final subscriptionService = SubscriptionService();
    final creditService = AICreditService();
    final rewardAdService = globalRewardAdService;
    
    final currentPlan = await subscriptionService.getCurrentPlan();
    debugPrint('🔍 [成長予測] 現在のプラン: $currentPlan');
    
    // ========================================
    // 🎯 Step 2: AI利用可能性チェック
    // ========================================
    final canUseAIResult = await creditService.canUseAI();
    debugPrint('🔍 [成長予測] AI使用可能: ${canUseAIResult.allowed}');
    
    if (!canUseAIResult.allowed) {
      // 無料プランでAIクレジットがない場合
      if (currentPlan == SubscriptionType.free) {
        // リワード広告で獲得可能かチェック
        final canEarnFromAd = await creditService.canEarnCreditFromAd();
        debugPrint('🔍 [成長予測] 広告視聴可能: $canEarnFromAd');
        
        if (canEarnFromAd) {
          // ========================================
          // 📺 Step 3: リワード広告ダイアログ表示
          // ========================================
          final shouldShowAd = await _showRewardAdDialog();
          
          if (shouldShowAd == true) {
            // 広告を表示してクレジット獲得
            final adSuccess = await _showRewardAdAndEarn();
            
            if (!adSuccess) {
              // 広告表示失敗
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('広告の読み込みに失敗しました。しばらくしてからお試しください。'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
            // 広告視聴成功 → 下記のAI生成処理に進む
          } else {
            // ユーザーがキャンセル
            return;
          }
        } else {
          // 今月の広告視聴上限に達している
          if (mounted) {
            await _showUpgradeDialog('今月の無料AI利用回数を使い切りました');
          }
          return;
        }
      } else {
        // 有料プランで月次上限に達している
        if (mounted) {
          await _showUpgradeDialog('今月のAI利用回数を使い切りました');
        }
        return;
      }
    }

    // ========================================
    // 🤖 Step 4: AI予測処理(クレジット消費含む)
    // ========================================
    setState(() {
      _isLoading = true;
      _predictionResult = null;
    });

    // 🆕 Phase 7: 必須データのバリデーション
    // 🔧 Phase 7 Fix: _oneRMControllerから1RMを取得
    final oneRMText = _oneRMController.text.trim();
    if (oneRMText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('1RMを入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final oneRM = double.tryParse(oneRMText);
    if (oneRM == null || oneRM <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('有効な1RMを入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_userAge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('年齢が未設定です。個人要因設定で年齢を登録してください。'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_latestBodyWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('体重が記録されていません。体重を記録してください。'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      print('🚀 成長予測開始...');
      final result = await AIPredictionService.predictGrowth(
        currentWeight: oneRM, // 🔧 Phase 7 Fix: controllerから取得した1RM
        level: _objectiveLevel ?? _selectedLevel, // 🆕 Phase 7: 客観的レベル優先
        frequency: _selectedFrequency,
        gender: _selectedGender,
        age: _userAge!, // 🆕 Phase 7: 自動取得した年齢
        bodyPart: _selectedBodyPart,
        monthsAhead: 4,
        rpe: _selectedRPE, // 🆕 v1.0.230: RPE（自覚的強度）
      );
      print('✅ 成長予測完了: ${result['success']}');

      if (result['success'] == true) {
        // ========================================
        // ✅ Step 5: AI生成成功 → クレジット消費
        // ========================================
        final consumeSuccess = await creditService.consumeAICredit();
        debugPrint('✅ AIクレジット消費: $consumeSuccess');
        
        // 残りクレジット表示
        if (mounted) {
          final statusMessage = await creditService.getAIUsageStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI予測完了! ($statusMessage)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _predictionResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 成長予測例外: $e');
      if (mounted) {
        setState(() {
          _predictionResult = {
            'success': false,
            'error': '予測の生成に失敗しました: $e',
          };
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー
            _buildHeader(),
            const SizedBox(height: 24),

            // 入力フォーム
            _buildInputForm(),
            const SizedBox(height: 24),

            // 予測実行ボタン
            _buildPredictButton(),
            const SizedBox(height: 32),

            // 予測結果
            if (_isLoading)
              _buildLoadingIndicator()
            else if (_predictionResult != null)
              _buildPredictionResult(),
          ],
        ),
      ),
    );
  }

  /// ヘッダー
  Widget _buildHeader() {
    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.timeline, size: 40, color: Colors.purple.shade700),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI成長予測',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '40本以上の論文に基づく科学的予測',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 入力フォーム
  Widget _buildInputForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'あなたの情報を入力',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 🆕 Phase 7: 年齢表示（自動取得）
            _buildAutoLoadedDataDisplay(),
            const SizedBox(height: 16),

            // 対象部位
            _buildDropdownField(
              label: '対象部位',
              value: _selectedBodyPart,
              items: _bodyParts,
              onChanged: (value) {
                setState(() {
                  _selectedBodyPart = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 現在の1RM
            _build1RMInputField(),
            const SizedBox(height: 16),

            // 🆕 Phase 7: Weight Ratio & 客観的レベル表示
            if (_weightRatio != null) ...[
              _buildWeightRatioDisplay(),
              const SizedBox(height: 16),
            ],

            // 🆕 Phase 7: 客観的レベル判定結果
            if (_objectiveLevel != null && _objectiveLevel != _selectedLevel) ...[
              _buildLevelWarning(),
              const SizedBox(height: 16),
            ],

            // トレーニングレベル
            _buildDropdownField(
              label: 'トレーニングレベル',
              value: _selectedLevel,
              items: _levels,
              onChanged: (value) {
                setState(() {
                  _selectedLevel = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // トレーニング頻度
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderField(
                  label: 'この部位のトレーニング頻度',
                  value: _selectedFrequency.toDouble(),
                  min: 1,
                  max: 6,
                  divisions: 5,
                  onChanged: (value) {
                    setState(() {
                      _selectedFrequency = value.toInt();
                    });
                  },
                  displayValue: '週${_selectedFrequency}回',
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ 選択した部位（$_selectedBodyPart）を週に何回トレーニングするか',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 🆕 v1.0.230: RPE（自覚的強度）スライダー
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderField(
                  label: '前回のトレーニングの強度（RPE）',
                  value: _selectedRPE.toDouble(),
                  min: 6,
                  max: 10,
                  divisions: 4,
                  onChanged: (value) {
                    setState(() {
                      _selectedRPE = value.toInt();
                    });
                  },
                  displayValue: _getRPELabel(_selectedRPE),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    _getRPEDescription(_selectedRPE),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 性別
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdownField(
                  label: '性別',
                  value: _selectedGender,
                  items: ['男性', '女性'],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value!;
                    });
                  },
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ 女性は上半身の相対的筋力向上率が男性より高い（Roberts 2020）',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ドロップダウンフィールド
  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      value: value,
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  /// スライダーフィールド
  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String displayValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: Colors.purple.shade700,
        ),
      ],
    );
  }

  /// 予測実行ボタン
  Widget _buildPredictButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : () {
        FocusScope.of(context).unfocus();
        _executePrediction();
      },
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.auto_graph),
      label: Text(_isLoading ? 'AI分析中...' : '成長予測を実行'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// ローディングインジケーター
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('AIが科学的根拠に基づいて分析中...'),
        ],
      ),
    );
  }

  /// 予測結果表示
  Widget _buildPredictionResult() {
    // nullチェック
    if (_predictionResult == null) {
      return Card(
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('予測結果がありません'),
        ),
      );
    }

    // エラーチェック
    if (_predictionResult!['success'] != true) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    '予測エラー',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                _predictionResult!['error']?.toString() ?? '不明なエラーが発生しました',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ),
        ),
      );
    }

    final result = _predictionResult!;
    
    // 必須フィールドチェック
    if (!result.containsKey('currentWeight') || 
        !result.containsKey('predictedWeight') ||
        !result.containsKey('aiAnalysis')) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '予測データが不完全です。もう一度お試しください。',
            style: TextStyle(color: Colors.orange.shade900),
          ),
        ),
      );
    }
    
    final currentWeight = result['currentWeight'] as double;
    final predictedWeight = result['predictedWeight'] as double;
    final growthPercentage = result['growthPercentage'] as int;
    final confidenceInterval = result['confidenceInterval'] as Map<String, dynamic>;
    final monthlyRate = result['monthlyRate'] as int;
    final weeklyRate = result['weeklyRate'] as double;
    final aiAnalysis = result['aiAnalysis'] as String;
    final scientificBasis = result['scientificBasis'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 予測結果サマリー
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 48,
                  color: Colors.green.shade700,
                ),
                const SizedBox(height: 16),
                const Text(
                  '4ヶ月後の予測',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${predictedWeight.round()}kg',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '現在: ${currentWeight.round()}kg → +$growthPercentage%の成長',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '信頼区間: ${confidenceInterval['lower'].round()}-${confidenceInterval['upper'].round()}kg',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 成長率カード
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      '成長率',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('月次成長', '+$monthlyRate%', Colors.blue),
                    _buildStatItem('週次成長', '+${weeklyRate.toStringAsFixed(1)}%', Colors.green),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // AI分析
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'AI詳細分析',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFormattedText(aiAnalysis),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 科学的根拠
        ScientificBasisSection(
          basis: scientificBasis.cast<Map<String, String>>(),
        ),
        const SizedBox(height: 8),

        // 信頼度インジケーター
        Center(
          child: ConfidenceIndicator(paperCount: scientificBasis.length),
        ),
      ],
    );
  }

  /// 統計アイテム
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// リワード広告ダイアログ表示
  Future<bool?> _showRewardAdDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.play_circle_outline, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('動画でAI機能解放'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '無料プランでは、動画広告を視聴することでAI機能を1回利用できます。',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '月3回まで動画視聴でAI利用可能',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('動画を視聴'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  /// リワード広告を表示してクレジット獲得
  Future<bool> _showRewardAdAndEarn() async {
    // グローバルインスタンスを使用（main.dartで初期化済み）
    final rewardAdService = globalRewardAdService;
    
    // 広告読み込み待機ダイアログ表示
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('広告を読み込んでいます...'),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // 広告を読み込む
    await rewardAdService.loadRewardedAd();
    
    // 読み込み完了まで最大5秒待機
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (rewardAdService.isAdReady()) {
        break;
      }
    }
    
    // ローディングダイアログを閉じる
    if (mounted) {
      Navigator.of(context).pop();
    }
    
    // 広告表示
    if (rewardAdService.isAdReady()) {
      final success = await rewardAdService.showRewardedAd();
      
      if (success) {
        // 広告視聴成功メッセージ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎁 AI機能1回分を獲得しました!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return true;
      }
    }
    
    return false;
  }
  
  /// アップグレード促進ダイアログ表示
  Future<void> _showUpgradeDialog(String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text('プレミアムプランにアップグレード'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'プレミアムプランなら:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 月10回までAI機能が使い放題\n'
              '• 広告なしで快適に利用\n'
              '• お気に入りジム無制限\n'
              '• レビュー投稿可能',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '月額 ¥500',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('後で'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('アップグレード'),
          ),
        ],
      ),
    );
  }

  /// Markdown形式テキストをフォーマット済みウィジェットに変換
  Widget _buildFormattedText(String text) {
    final lines = text.split('\n');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      // 1. 見出し処理（## Text → 太字テキスト）
      if (line.trim().startsWith('##')) {
        final headingText = line.replaceFirst(RegExp(r'^##\s*'), '');
        spans.add(
          TextSpan(
            text: headingText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.8,
            ),
          ),
        );
        if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
        continue;
      }

      // 2. 箇条書き処理（* → ・）
      if (line.trim().startsWith('*')) {
        line = line.replaceFirst(RegExp(r'^\*\s*'), '・');
      }

      // 3. 太字処理（**text** → 太字）
      final boldPattern = RegExp(r'\*\*(.+?)\*\*');
      final matches = boldPattern.allMatches(line);

      if (matches.isEmpty) {
        spans.add(TextSpan(text: line));
      } else {
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            spans.add(TextSpan(text: line.substring(lastIndex, match.start)));
          }
          spans.add(
            TextSpan(
              text: match.group(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
          lastIndex = match.end;
        }
        if (lastIndex < line.length) {
          spans.add(TextSpan(text: line.substring(lastIndex)));
        }
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.black87,
        ),
        children: spans,
      ),
    );
  }

  /// 🆕 v1.0.230: RPEラベルを取得
  String _getRPELabel(int rpe) {
    switch (rpe) {
      case 6:
      case 7:
        return 'RPE $rpe（余裕あり）';
      case 8:
      case 9:
        return 'RPE $rpe（適正）';
      case 10:
        return 'RPE $rpe（限界）';
      default:
        return 'RPE $rpe';
    }
  }

  /// 🆕 v1.0.230: RPE説明文を取得
  String _getRPEDescription(int rpe) {
    if (rpe <= 7) {
      return '※ まだ余裕があった場合、予測成長率を10%アップします';
    } else if (rpe >= 10) {
      return '※ 限界まで追い込んだ場合、過労を考慮して予測成長率を20%ダウンします';
    } else {
      return '※ 適正な強度でトレーニングできた場合、標準の成長率で予測します';
    }
  }

  // ========================================
  // 🆕 Phase 7: 自動取得データ表示UI
  // ========================================

  /// 年齢・体重の自動取得データ表示
  Widget _buildAutoLoadedDataDisplay() {
    return Column(
      children: [
        // 年齢表示
        if (_userAge != null)
          _buildDataRow(
            icon: Icons.calendar_today,
            label: '年齢',
            value: '$_userAge歳',
            actionLabel: '変更',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PersonalFactorsScreen()),
            ).then((_) => _loadUserAge()),
          )
        else
          _buildWarningCard(
            message: '年齢が未設定です。予測精度を高めるため、個人要因設定で年齢を登録してください。',
            actionLabel: '設定する',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PersonalFactorsScreen()),
            ).then((_) => _loadUserAge()),
          ),
        const SizedBox(height: 12),

        // 体重表示
        if (_latestBodyWeight != null)
          _buildDataRow(
            icon: Icons.monitor_weight,
            label: '体重',
            value: '${_latestBodyWeight!.toStringAsFixed(1)}kg'
                '${_weightRecordedAt != null ? " (${_formatDate(_weightRecordedAt!)})" : ""}',
            actionLabel: '更新',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BodyMeasurementScreen()),
            ).then((_) => _loadLatestBodyWeight()),
          )
        else
          _buildWarningCard(
            message: '体重が記録されていません。予測精度を高めるため、体重を記録してください。',
            actionLabel: '記録する',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BodyMeasurementScreen()),
            ).then((_) => _loadLatestBodyWeight()),
          ),
      ],
    );
  }

  /// データ表示行（年齢・体重）
  Widget _buildDataRow({
    required IconData icon,
    required String label,
    required String value,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  /// 警告カード（未設定時）
  Widget _buildWarningCard({
    required String message,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  /// 1RM入力フィールド（Weight Ratio計算付き）
  Widget _build1RMInputField() {
    return TextFormField(
      controller: _oneRMController, // 🔧 Phase 7 Fix: controllerを使用
      decoration: const InputDecoration(
        labelText: '現在の1RM (kg)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.fitness_center),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onEditingComplete: () => FocusScope.of(context).unfocus(),
      onChanged: (value) {
        final oneRM = double.tryParse(value);
        if (oneRM != null && oneRM > 0) {
          _calculateWeightRatioAndLevel(oneRM);
        } else {
          // 🔧 Phase 7 Fix: 無効な入力時はWeight Ratioをクリア
          setState(() {
            _currentOneRM = null;
            _weightRatio = null;
            _objectiveLevel = null;
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '1RMを入力してください';
        }
        final weight = double.tryParse(value);
        if (weight == null) {
          return '数値を入力してください';
        }
        if (weight <= 0) {
          return '1kg以上を入力してください';
        }
        if (weight > 500) {
          return '500kg以下を入力してください';
        }
        return null;
      },
    );
  }

  /// Weight Ratio表示
  Widget _buildWeightRatioDisplay() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: Colors.indigo.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weight Ratio（体重比）',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_weightRatio!.toStringAsFixed(2)} (1RM ${_currentOneRM!.toStringAsFixed(1)}kg ÷ 体重 ${_latestBodyWeight!.toStringAsFixed(1)}kg)',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 客観的レベル判定の警告表示
  Widget _buildLevelWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              const Text(
                'レベル判定の通知',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'あなたのWeight Ratio (${_weightRatio!.toStringAsFixed(2)}) から、'
            '客観的なレベルは「$_objectiveLevel」と判定されました。',
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            '選択中のレベル：「$_selectedLevel」',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedLevel = _objectiveLevel!;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
            ),
            child: const Text('客観的レベルを使用する'),
          ),
        ],
      ),
    );
  }

  /// 日付フォーマット
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}

// ========================================
// Tab 3: 効果分析タブ
// ========================================

class _EffectAnalysisTab extends StatefulWidget {
  @override
  State<_EffectAnalysisTab> createState() => _EffectAnalysisTabState();
}

class _EffectAnalysisTabState extends State<_EffectAnalysisTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // フォーム入力値
  final _formKey = GlobalKey<FormState>();
  String _selectedBodyPart = '大胸筋';
  String _selectedExercise = 'ベンチプレス';  // 種目選択
  int _currentSets = 12;
  int _currentFrequency = 2;
  String _selectedLevel = '中級者';
  String _selectedGender = '女性';
  bool _enablePlateauDetection = true;  // プラトー検出ON/OFF

  // 🆕 Phase 7.5: 自動取得データ
  int? _userAge; // 個人要因設定から取得

  // 分析結果
  Map<String, dynamic>? _analysisResult;
  bool _isLoading = false;  // ✅ 修正: 初期状態はローディングなし

  @override
  void initState() {
    super.initState();
    _loadUserAge(); // 🆕 Phase 7.5: 年齢を自動取得
  }

  // 部位選択肢
  final List<String> _bodyParts = [
    '大胸筋',
    '広背筋',
    '大腿四頭筋',
    '上腕二頭筋',
    '上腕三頭筋',
    '三角筋',
  ];

  // 種目選択肢（部位ごと）
  final Map<String, List<String>> _exercisesByBodyPart = {
    '大胸筋': ['ベンチプレス', 'インクラインベンチプレス', 'ダンベルフライ', 'ディップス'],
    '広背筋': ['デッドリフト', 'ラットプルダウン', 'ベントオーバーロウ', 'チンニング'],
    '大腿四頭筋': ['スクワット', 'レッグプレス', 'レッグエクステンション', 'ランジ'],
    '上腕二頭筋': ['バーベルカール', 'ダンベルカール', 'ハンマーカール', 'プリーチャーカール'],
    '上腕三頭筋': ['トライセプスプレスダウン', 'ライイングトライセプスエクステンション', 'ディップス', 'クローズグリップベンチプレス'],
    '三角筋': ['ショルダープレス', 'サイドレイズ', 'フロントレイズ', 'リアレイズ'],
  };

  // レベル選択肢
  final List<String> _levels = ['初心者', '中級者', '上級者'];

  // 現在選択中の部位の種目リスト
  List<String> get _availableExercises => _exercisesByBodyPart[_selectedBodyPart] ?? [];

  // ========================================
  // 🆕 Phase 7.5: データ自動取得ロジック
  // ========================================

  /// 個人要因設定から年齢を取得
  Future<void> _loadUserAge() async {
    try {
      final advancedFatigueService = AdvancedFatigueService();
      final userProfile = await advancedFatigueService.getUserProfile();
      
      if (mounted) {
        setState(() {
          _userAge = userProfile.age;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [Phase 7.5] 年齢取得エラー: $e');
      // エラー時は null のまま（未設定状態）
    }
  }

  /// 効果分析を実行(サブスクリプションチェック統合)
  Future<void> _executeAnalysis() async {
    if (!_formKey.currentState!.validate()) return;

    // ========================================
    // 🔐 Step 1: サブスクリプション状態チェック
    // ========================================
    final subscriptionService = SubscriptionService();
    final creditService = AICreditService();
    final rewardAdService = globalRewardAdService;
    
    final currentPlan = await subscriptionService.getCurrentPlan();
    debugPrint('🔍 [効果分析] 現在のプラン: $currentPlan');
    
    // ========================================
    // 🎯 Step 2: AI利用可能性チェック
    // ========================================
    final canUseAIResult = await creditService.canUseAI();
    debugPrint('🔍 [効果分析] AI使用可能: ${canUseAIResult.allowed}');
    
    if (!canUseAIResult.allowed) {
      // 無料プランでAIクレジットがない場合
      if (currentPlan == SubscriptionType.free) {
        // リワード広告で獲得可能かチェック
        final canEarnFromAd = await creditService.canEarnCreditFromAd();
        debugPrint('🔍 [効果分析] 広告視聴可能: $canEarnFromAd');
        
        if (canEarnFromAd) {
          // ========================================
          // 📺 Step 3: リワード広告ダイアログ表示
          // ========================================
          final shouldShowAd = await _showRewardAdDialog();
          
          if (shouldShowAd == true) {
            // 広告を表示してクレジット獲得
            final adSuccess = await _showRewardAdAndEarn();
            
            if (!adSuccess) {
              // 広告表示失敗
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('広告の読み込みに失敗しました。しばらくしてからお試しください。'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
            // 広告視聴成功 → 下記のAI生成処理に進む
          } else {
            // ユーザーがキャンセル
            return;
          }
        } else {
          // 今月の広告視聴上限に達している
          if (mounted) {
            await _showUpgradeDialog('今月の無料AI利用回数を使い切りました');
          }
          return;
        }
      } else {
        // 有料プランで月次上限に達している
        if (mounted) {
          await _showUpgradeDialog('今月のAI利用回数を使い切りました');
        }
        return;
      }
    }

    // ========================================
    // 🤖 Step 4: AI分析処理(クレジット消費含む)
    // ========================================
    setState(() {
      _isLoading = true;
      _analysisResult = null;
    });

    try {
      print('🚀 効果分析開始...');
      
      // プラトー検出が有効な場合、Firestoreから履歴を取得
      // 🆕 Phase 7.5: 必須データのバリデーション
      if (_userAge == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('年齢が未設定です。個人要因設定で年齢を登録してください。'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      List<Map<String, dynamic>> recentHistory = [];
      if (_enablePlateauDetection) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          recentHistory = await _fetchRecentExerciseHistory(user.uid, _selectedExercise);
          print('📊 履歴取得: ${recentHistory.length}件');
        }
      }
      
      final result = await TrainingAnalysisService.analyzeTrainingEffect(
        bodyPart: _selectedBodyPart,
        currentSetsPerWeek: _currentSets,
        currentFrequency: _currentFrequency,
        level: _selectedLevel,
        gender: _selectedGender,
        age: _userAge!, // 🆕 Phase 7.5: 自動取得した年齢
        recentHistory: recentHistory,
      );
      print('✅ 効果分析完了: ${result['success']}');

      if (result['success'] == true) {
        // ========================================
        // ✅ Step 5: AI生成成功 → クレジット消費
        // ========================================
        final consumeSuccess = await creditService.consumeAICredit();
        debugPrint('✅ AIクレジット消費: $consumeSuccess');
        
        // 残りクレジット表示
        if (mounted) {
          final statusMessage = await creditService.getAIUsageStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI分析完了! ($statusMessage)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 効果分析例外: $e');
      if (mounted) {
        setState(() {
          _analysisResult = {
            'success': false,
            'error': '分析の生成に失敗しました: $e',
          };
          _isLoading = false;
        });
      }
    }
  }

  /// Firestoreから特定種目の直近4回のトレーニング記録を取得
  Future<List<Map<String, dynamic>>> _fetchRecentExerciseHistory(
    String userId,
    String exerciseName,
  ) async {
    try {
      // 直近30日間のworkoutログを取得
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final snapshot = await FirebaseFirestore.instance
          .collection('workouts')
          .where('user_id', isEqualTo: userId)
          .where('date', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('date', descending: true)
          .limit(20)  // 最大20件のワークアウトログを取得
          .get();

      final List<Map<String, dynamic>> exerciseRecords = [];
      
      // 各ワークアウトログから指定種目のデータを抽出
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final exercises = data['exercises'] as List<dynamic>?;
        
        if (exercises != null) {
          // 指定種目を探す
          for (final exercise in exercises) {
            final exerciseMap = exercise as Map<String, dynamic>;
            if (exerciseMap['name'] == exerciseName) {
              // 最大重量を計算
              final sets = exerciseMap['sets'] as List<dynamic>?;
              double maxWeight = 0;
              
              if (sets != null) {
                for (final set in sets) {
                  final setMap = set as Map<String, dynamic>;
                  final weight = setMap['weight']?.toDouble() ?? 0;
                  if (weight > maxWeight) {
                    maxWeight = weight;
                  }
                }
              }
              
              // 記録を追加（4件に達したら終了）
              exerciseRecords.add({
                'date': (data['date'] as Timestamp).toDate(),
                'weight': maxWeight,
                'sets': sets?.length ?? 0,
              });
              
              if (exerciseRecords.length >= 4) break;
            }
          }
        }
        
        if (exerciseRecords.length >= 4) break;
      }
      
      // 日付順にソート（新しい順）
      exerciseRecords.sort((a, b) => 
        (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      // 週番号を付与（直近が week 1）
      final result = <Map<String, dynamic>>[];
      for (int i = 0; i < exerciseRecords.length; i++) {
        result.add({
          'week': exerciseRecords.length - i,
          'weight': exerciseRecords[i]['weight'],
          'sets': exerciseRecords[i]['sets'],
        });
      }
      
      return result;
    } catch (e) {
      print('❌ 履歴取得エラー: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー
            _buildHeader(),
            const SizedBox(height: 24),

            // 入力フォーム
            _buildInputForm(),
            const SizedBox(height: 24),

            // 分析実行ボタン
            _buildAnalyzeButton(),
            const SizedBox(height: 32),

            // 分析結果
            if (_isLoading)
              _buildLoadingIndicator()
            else if (_analysisResult != null)
              _buildAnalysisResult(),
          ],
        ),
      ),
    );
  }

  /// ヘッダー
  Widget _buildHeader() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.analytics, size: 40, color: Colors.orange.shade700),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'トレーニング効果分析',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '最適なボリュームと頻度を科学的に分析',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 入力フォーム
  Widget _buildInputForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '現在のトレーニング状況',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 🆕 Phase 7.5: 年齢表示（自動取得）
            _buildAgeDisplay(),
            const SizedBox(height: 16),

            // 対象部位
            _buildDropdownField(
              label: '対象部位',
              value: _selectedBodyPart,
              items: _bodyParts,
              onChanged: (value) {
                setState(() {
                  _selectedBodyPart = value!;
                  // 部位変更時に種目を自動選択
                  _selectedExercise = _availableExercises.isNotEmpty 
                      ? _availableExercises.first 
                      : 'ベンチプレス';
                });
              },
            ),
            const SizedBox(height: 16),

            // 種目選択
            _buildDropdownField(
              label: '種目（プラトー検出用）',
              value: _selectedExercise,
              items: _availableExercises,
              onChanged: (value) {
                setState(() {
                  _selectedExercise = value!;
                });
              },
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '※ 同じ種目で4回連続同じ重量の場合、停滞を検出',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // プラトー検出トグル
            SwitchListTile(
              title: const Text(
                'プラトー（停滞期）検出',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _enablePlateauDetection 
                    ? '実際のトレーニング記録から自動検出します' 
                    : '検出機能をOFFにしています',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              value: _enablePlateauDetection,
              onChanged: (value) {
                setState(() {
                  _enablePlateauDetection = value;
                });
              },
              activeColor: Colors.orange.shade700,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // 週あたりセット数
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderField(
                  label: 'この部位の週あたりセット数',
                  value: _currentSets.toDouble(),
                  min: 4,
                  max: 24,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() {
                      _currentSets = value.toInt();
                    });
                  },
                  displayValue: '${_currentSets}セット',
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ $_selectedBodyPart のトレーニングで週に実施する総セット数',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // トレーニング頻度
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderField(
                  label: 'この部位のトレーニング頻度',
                  value: _currentFrequency.toDouble(),
                  min: 1,
                  max: 6,
                  divisions: 5,
                  onChanged: (value) {
                    setState(() {
                      _currentFrequency = value.toInt();
                    });
                  },
                  displayValue: '週${_currentFrequency}回',
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ $_selectedBodyPart を週に何回トレーニングするか',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // トレーニングレベル
            _buildDropdownField(
              label: 'トレーニングレベル',
              value: _selectedLevel,
              items: _levels,
              onChanged: (value) {
                setState(() {
                  _selectedLevel = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 性別
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdownField(
                  label: '性別',
                  value: _selectedGender,
                  items: ['男性', '女性'],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value!;
                    });
                  },
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ 女性は上半身の相対的筋力向上率が男性より高い（Roberts 2020）',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // 🆕 Phase 7.5: 年齢表示UI
  // ========================================

  /// 年齢の自動取得データ表示
  Widget _buildAgeDisplay() {
    if (_userAge != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '年齢',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '$_userAge歳',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PersonalFactorsScreen()),
              ).then((_) => _loadUserAge()),
              child: const Text('変更'),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: const Text(
                '年齢が未設定です。予測精度を高めるため、個人要因設定で年齢を登録してください。',
                style: TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PersonalFactorsScreen()),
              ).then((_) => _loadUserAge()),
              child: const Text('設定する'),
            ),
          ],
        ),
      );
    }
  }

  /// ドロップダウンフィールド
  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      value: value,
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  /// スライダーフィールド
  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String displayValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: Colors.orange.shade700,
        ),
      ],
    );
  }

  /// 分析実行ボタン
  Widget _buildAnalyzeButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : () {
        FocusScope.of(context).unfocus();
        _executeAnalysis();
      },
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.auto_graph),
      label: Text(_isLoading ? 'AI分析中...' : '効果を分析'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// ローディングインジケーター
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('AIが最適なプログラムを分析中...'),
        ],
      ),
    );
  }

  /// 分析結果表示
  Widget _buildAnalysisResult() {
    // nullチェック
    if (_analysisResult == null) {
      return Card(
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('分析結果がありません'),
        ),
      );
    }

    // エラーチェック
    if (_analysisResult!['success'] != true) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    '分析エラー',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                _analysisResult!['error']?.toString() ?? '不明なエラーが発生しました',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ),
        ),
      );
    }

    final result = _analysisResult!;
    
    // 必須フィールドチェック
    if (!result.containsKey('volumeAnalysis') || 
        !result.containsKey('frequencyAnalysis') ||
        !result.containsKey('aiAnalysis')) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '分析データが不完全です。もう一度お試しください。',
            style: TextStyle(color: Colors.orange.shade900),
          ),
        ),
      );
    }
    
    final volumeAnalysis = result['volumeAnalysis'] as Map<String, dynamic>;
    final frequencyAnalysis = result['frequencyAnalysis'] as Map<String, dynamic>;
    final plateauDetected = result['plateauDetected'] as bool;
    final growthTrend = result['growthTrend'] as Map<String, dynamic>;
    final recommendations = result['recommendations'] as List;
    final scientificBasis = result['scientificBasis'] as List;
    final aiAnalysis = result['aiAnalysis'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ステータスサマリー（トグルOFFの場合はプラトー無視）
        _buildStatusSummary(volumeAnalysis, frequencyAnalysis, 
          _enablePlateauDetection && plateauDetected, growthTrend),
        const SizedBox(height: 16),

        // ボリューム分析
        _buildVolumeAnalysis(volumeAnalysis),
        const SizedBox(height: 16),

        // 頻度分析
        _buildFrequencyAnalysis(frequencyAnalysis),
        const SizedBox(height: 16),

        // プラトー警告（トグルON かつ 検出された場合のみ表示）
        if (_enablePlateauDetection && plateauDetected) ...[
          _buildPlateauWarning(),
          const SizedBox(height: 16),
        ],

        // 推奨アクション
        _buildRecommendations(recommendations),
        const SizedBox(height: 16),

        // AI分析
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'AI詳細分析',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFormattedText(aiAnalysis),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 科学的根拠
        ScientificBasisSection(
          basis: scientificBasis.cast<Map<String, String>>(),
        ),
        const SizedBox(height: 8),

        // 信頼度インジケーター
        Center(
          child: ConfidenceIndicator(paperCount: scientificBasis.length),
        ),
      ],
    );
  }

  /// ステータスサマリー
  Widget _buildStatusSummary(
    Map<String, dynamic> volume,
    Map<String, dynamic> frequency,
    bool plateau,
    Map<String, dynamic> trend,
  ) {
    Color statusColor;
    IconData statusIcon;
    String statusMessage;

    if (plateau) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusMessage = 'プラトー検出：改善が必要';
    } else if (volume['status'] == 'optimal' && frequency['status'] == 'optimal') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusMessage = '最適なトレーニング中';
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.info;
      statusMessage = '改善の余地あり';
    }

    return Card(
      color: statusColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(statusIcon, size: 48, color: statusColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusMessage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '成長トレンド: ${trend['trend']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ボリューム分析
  Widget _buildVolumeAnalysis(Map<String, dynamic> analysis) {
    final status = analysis['status'] as String;
    final advice = analysis['advice'] as String;
    
    Color statusColor;
    String statusLabel;
    
    switch (status) {
      case 'optimal':
        statusColor = Colors.green;
        statusLabel = '最適';
        break;
      case 'suboptimal':
        statusColor = Colors.blue;
        statusLabel = '最適以下';
        break;
      case 'insufficient':
        statusColor = Colors.orange;
        statusLabel = '不足';
        break;
      case 'excessive':
        statusColor = Colors.red;
        statusLabel = '過剰';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = '不明';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'ボリューム分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              advice,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  /// 頻度分析
  Widget _buildFrequencyAnalysis(Map<String, dynamic> analysis) {
    final status = analysis['status'] as String;
    final advice = analysis['advice'] as String;
    
    Color statusColor;
    String statusLabel;
    
    switch (status) {
      case 'optimal':
        statusColor = Colors.green;
        statusLabel = '最適';
        break;
      case 'suboptimal':
        statusColor = Colors.blue;
        statusLabel = '最適以下';
        break;
      case 'insufficient':
        statusColor = Colors.orange;
        statusLabel = '不足';
        break;
      case 'excessive':
        statusColor = Colors.red;
        statusLabel = '過剰';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = '不明';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  '頻度分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              advice,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  /// プラトー警告
  Widget _buildPlateauWarning() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.warning_amber, size: 40, color: Colors.orange.shade700),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'プラトー検出',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '成長が停滞しています。トレーニングを変更しましょう。',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 推奨アクション
  Widget _buildRecommendations(List recommendations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.recommend, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Text(
                  '推奨アクション',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendations.map((rec) {
              final action = rec['action'] as String;
              final category = rec['category'] as String;
              final priority = rec['priority'] as String;
              
              Color priorityColor;
              switch (priority) {
                case 'high':
                  priorityColor = Colors.red;
                  break;
                case 'medium':
                  priorityColor = Colors.orange;
                  break;
                default:
                  priorityColor = Colors.blue;
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: priorityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            action,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// リワード広告ダイアログ表示
  Future<bool?> _showRewardAdDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.play_circle_outline, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('動画でAI機能解放'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '無料プランでは、動画広告を視聴することでAI機能を1回利用できます。',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '月3回まで動画視聴でAI利用可能',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('動画を視聴'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  /// リワード広告を表示してクレジット獲得
  Future<bool> _showRewardAdAndEarn() async {
    // グローバルインスタンスを使用（main.dartで初期化済み）
    final rewardAdService = globalRewardAdService;
    
    // 広告読み込み待機ダイアログ表示
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('広告を読み込んでいます...'),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // 広告を読み込む
    await rewardAdService.loadRewardedAd();
    
    // 読み込み完了まで最大5秒待機
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (rewardAdService.isAdReady()) {
        break;
      }
    }
    
    // ローディングダイアログを閉じる
    if (mounted) {
      Navigator.of(context).pop();
    }
    
    // 広告表示
    if (rewardAdService.isAdReady()) {
      final success = await rewardAdService.showRewardedAd();
      
      if (success) {
        // 広告視聴成功メッセージ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎁 AI機能1回分を獲得しました!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return true;
      }
    }
    
    return false;
  }
  
  /// アップグレード促進ダイアログ表示
  Future<void> _showUpgradeDialog(String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text('プレミアムプランにアップグレード'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'プレミアムプランなら:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 月10回までAI機能が使い放題\n'
              '• 広告なしで快適に利用\n'
              '• お気に入りジム無制限\n'
              '• レビュー投稿可能',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '月額 ¥500',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('後で'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('アップグレード'),
          ),
        ],
      ),
    );
  }

  /// Markdown形式テキストをフォーマット済みウィジェットに変換
  Widget _buildFormattedText(String text) {
    final lines = text.split('\n');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      // 1. 見出し処理（## Text → 太字テキスト）
      if (line.trim().startsWith('##')) {
        final headingText = line.replaceFirst(RegExp(r'^##\s*'), '');
        spans.add(
          TextSpan(
            text: headingText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.8,
            ),
          ),
        );
        if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
        continue;
      }

      // 2. 箇条書き処理（* → ・）
      if (line.trim().startsWith('*')) {
        line = line.replaceFirst(RegExp(r'^\*\s*'), '・');
      }

      // 3. 太字処理（**text** → 太字）
      final boldPattern = RegExp(r'\*\*(.+?)\*\*');
      final matches = boldPattern.allMatches(line);

      if (matches.isEmpty) {
        spans.add(TextSpan(text: line));
      } else {
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            spans.add(TextSpan(text: line.substring(lastIndex, match.start)));
          }
          spans.add(
            TextSpan(
              text: match.group(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
          lastIndex = match.end;
        }
        if (lastIndex < line.length) {
          spans.add(TextSpan(text: line.substring(lastIndex)));
        }
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.black87,
        ),
        children: spans,
      ),
    );
  }
}
