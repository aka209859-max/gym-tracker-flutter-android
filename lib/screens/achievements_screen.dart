import 'package:flutter/material.dart';
import 'package:gym_match/gen/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../models/achievement.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../services/achievement_service.dart';
import 'package:gym_match/gen/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:gym_match/gen/app_localizations.dart';

/// 達成バッジ画面
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  final AchievementService _achievementService = AchievementService();
  late TabController _tabController;

  List<Achievement> _allBadges = [];
  List<Achievement> _streakBadges = [];
  List<Achievement> _totalWeightBadges = [];
  List<Achievement> _prCountBadges = [];
  Map<String, int> _stats = {'total': 0, 'unlocked': 0, 'locked': 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBadges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // バッジを初期化（初回のみ）
      await _achievementService.initializeUserBadges(user.uid);

      // バッジをチェックして更新
      await _achievementService.checkAndUpdateBadges(user.uid);

      // 全バッジを取得
      final badges = await _achievementService.getUserBadges(user.uid);
      final stats = await _achievementService.getBadgeStats(user.uid);

      setState(() {
        _allBadges = badges;
        _streakBadges = badges
            .where((b) => b.category == BadgeCategory.streak)
            .toList()
          ..sort((a, b) => a.threshold.compareTo(b.threshold));
        _totalWeightBadges = badges
            .where((b) => b.category == BadgeCategory.totalWeight)
            .toList()
          ..sort((a, b) => a.threshold.compareTo(b.threshold));
        _prCountBadges = badges
            .where((b) => b.category == BadgeCategory.prCount)
            .toList()
          ..sort((a, b) => a.threshold.compareTo(b.threshold));
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('バッジの読み込みに失敗しました: $e')),
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
        title: Text(AppLocalizations.of(context)!.general_472edfec),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.all),
            Tab(text: AppLocalizations.of(context)!.general_3fa16d02),
            Tab(text: AppLocalizations.of(context)!.totalWeight),
            Tab(text: 'PR'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsSection(theme),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBadgeList(_allBadges, theme),
                      _buildBadgeList(_streakBadges, theme),
                      _buildBadgeList(_totalWeightBadges, theme),
                      _buildBadgeList(_prCountBadges, theme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// 統計セクション
  Widget _buildStatsSection(ThemeData theme) {
    final unlockedPercent = _stats['total']! > 0
        ? (_stats['unlocked']! / _stats['total']! * 100).toInt()
        : 0;

    return Container(
      margin: const EdgeInsets.all(16),
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
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                AppLocalizations.of(context)!.general_68f06584,
                '${_stats['unlocked']}',
                Icons.emoji_events,
                Colors.white,
              ),
              _buildStatItem(
                AppLocalizations.of(context)!.general_e05cb021,
                '${_stats['locked']}',
                Icons.lock_outline,
                Colors.white70,
              ),
              _buildStatItem(
                AppLocalizations.of(context)!.general_7810caaf,
                '$unlockedPercent%',
                Icons.insights,
                Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _stats['total']! > 0
                  ? _stats['unlocked']! / _stats['total']!
                  : 0,
              minHeight: 12,
              backgroundColor: Colors.white30,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  /// バッジリスト
  Widget _buildBadgeList(List<Achievement> badges, ThemeData theme) {
    if (badges.isEmpty) {
      return const Center(
        child: Text(AppLocalizations.of(context)!.general_398db801),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBadges,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: badges.length,
        itemBuilder: (context, index) {
          final badge = badges[index];
          return _buildBadgeCard(badge, theme);
        },
      ),
    );
  }

  /// バッジカード
  Widget _buildBadgeCard(Achievement badge, ThemeData theme) {
    final isUnlocked = badge.isUnlocked;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isUnlocked ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUnlocked
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.2),
          width: isUnlocked ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isUnlocked
              ? LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                    theme.colorScheme.secondary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // バッジアイコン
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getBadgeIcon(badge.iconName),
                  size: 32,
                  color: isUnlocked
                      ? theme.colorScheme.primary
                      : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              // バッジ情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            badge.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? null : Colors.grey,
                            ),
                          ),
                        ),
                        if (isUnlocked)
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      badge.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isUnlocked
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                            : Colors.grey,
                      ),
                    ),
                    if (isUnlocked && badge.unlockedAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: theme.colorScheme.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '解除: ${DateFormat('yyyy/MM/dd').format(badge.unlockedAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!isUnlocked) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '条件: ${_getCategoryLabel(badge.category)} ${badge.threshold}${_getCategoryUnit(badge.category)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// バッジアイコンを取得
  IconData _getBadgeIcon(String iconName) {
    switch (iconName) {
      case 'directions_run':
        return Icons.directions_run;
      case 'military_tech':
        return Icons.military_tech;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'sports_gymnastics':
        return Icons.sports_gymnastics;
      case 'sports_martial_arts':
        return Icons.sports_martial_arts;
      case 'star':
        return Icons.star;
      case 'celebration':
        return Icons.celebration;
      case 'trending_up':
        return Icons.trending_up;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'diamond':
        return Icons.diamond;
      default:
        return Icons.emoji_events;
    }
  }

  /// カテゴリーラベルを取得
  String _getCategoryLabel(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.streak:
        return AppLocalizations.of(context)!.general_3fa16d02;
      case BadgeCategory.totalWeight:
        return AppLocalizations.of(context)!.general_dc78fd37;
      case BadgeCategory.prCount:
        return 'PR';
    }
  }

  /// カテゴリー単位を取得
  String _getCategoryUnit(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.streak:
        return AppLocalizations.of(context)!.sun;
      case BadgeCategory.totalWeight:
        return AppLocalizations.of(context)!.kg;
      case BadgeCategory.prCount:
        return AppLocalizations.of(context)!.reps;
    }
  }
}
