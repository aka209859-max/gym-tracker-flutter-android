import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// PO管理者ダッシュボード画面
/// 
/// 機能（仮実装）:
/// 1. KPIカード表示（総会員数、アクティブ会員、休眠会員）
/// 2. サイドバーナビゲーション
/// 3. ログアウト機能
class PODashboardScreen extends StatefulWidget {
  const PODashboardScreen({super.key});

  @override
  State<PODashboardScreen> createState() => _PODashboardScreenState();
}

class _PODashboardScreenState extends State<PODashboardScreen> {
  String _gymName = AppLocalizations.of(context)!.loadingWorkouts;
  int _totalMembers = 0;
  int _activeMembers = 0;
  int _dormantMembers = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// ダッシュボードデータ読み込み
  Future<void> _loadDashboardData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception(AppLocalizations.of(context)!.userNotAuthenticated);
      }

      if (kDebugMode) {
        debugPrint('📊 ダッシュボードデータ読み込み開始...');
        debugPrint('   PO User ID: ${user.uid}');
      }

      // PO情報取得
      final poDoc = await FirebaseFirestore.instance
          .collection('poOwners')
          .doc(user.uid)
          .get();

      if (!poDoc.exists) {
        throw Exception(AppLocalizations.of(context)!.general_e22a77d8);
      }

      final poData = poDoc.data();
      if (poData == null) {
        throw Exception(AppLocalizations.of(context)!.error_46a35645);
      }
      
      // 会員数集計（仮データ）
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('poOwners')
          .doc(user.uid)
          .collection('members')
          .get();

      final totalMembers = membersSnapshot.docs.length;
      final activeMembers = membersSnapshot.docs
          .where((doc) => doc.data()['isActive'] == true)
          .length;
      final dormantMembers = totalMembers - activeMembers;

      setState(() {
        _gymName = poData['gymName'] ?? AppLocalizations.of(context)!.unknown;
        _totalMembers = totalMembers;
        _activeMembers = activeMembers;
        _dormantMembers = dormantMembers;
        _isLoading = false;
      });

      if (kDebugMode) {
        debugPrint('✅ ダッシュボードデータ読み込み完了');
        debugPrint('   ジム名: $_gymName');
        debugPrint('   総会員数: $_totalMembers');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ダッシュボードデータ読み込みエラー: $e');
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.dataLoadError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ログアウト
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      
      if (kDebugMode) {
        debugPrint('✅ ログアウト成功');
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ログアウトエラー: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.general_4a0065da),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: AppLocalizations.of(context)!.logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ジム名表示
                    Text(
                      _gymName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.general_d99061be,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // KPIカード
                    _buildKPICard(
                      title: AppLocalizations.of(context)!.general_4146c265,
                      value: _totalMembers.toString(),
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildKPICard(
                      title: AppLocalizations.of(context)!.general_58b46f8e,
                      value: _activeMembers.toString(),
                      icon: Icons.trending_up,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildKPICard(
                      title: AppLocalizations.of(context)!.general_3a99254a,
                      value: _dormantMembers.toString(),
                      icon: Icons.trending_down,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 24),

                    // 機能ボタン（仮実装）
                    _buildFeatureButton(
                      title: AppLocalizations.of(context)!.general_8043e494,
                      subtitle: AppLocalizations.of(context)!.general_2994cb17,
                      icon: Icons.people_outline,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.general_5846d4c4)),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureButton(
                      title: AppLocalizations.of(context)!.general_119d8156,
                      subtitle: AppLocalizations.of(context)!.general_f86194c5,
                      icon: Icons.calendar_today_outlined,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.general_9fef05a3)),
                        );
                      },
                    ),
                    SizedBox(height: 12),
                    _buildFeatureButton(
                      title: AppLocalizations.of(context)!.analysis,
                      subtitle: AppLocalizations.of(context)!.general_a7599bdd,
                      icon: Icons.analytics_outlined,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.general_1a8525c9)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// KPIカード
  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 機能ボタン
  Widget _buildFeatureButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue.shade700, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
