import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_workout_screen.dart';
import 'simple_workout_detail_screen.dart';
import 'weekly_reports_screen.dart';
import 'personal_records_screen.dart';
import 'body_part_tracking_screen.dart';
import 'workout_memo_list_screen.dart';

/// トレーニング記録一覧画面
class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({super.key});

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    // 画面表示時に自動ログインを完了させる
    _initializeAuth();
  }

  /// 認証の初期化とデモユーザーでの自動ログイン
  Future<void> _initializeAuth() async {
    // リリースビルドでもログ出力（デバッグ用）
    print('📱 [WorkoutLogScreen] 認証初期化開始');
    
    try {
      // Firebase初期化を十分に待機（3秒に延長）
      await Future.delayed(const Duration(seconds: 3));
      
      print('📱 [WorkoutLogScreen] Firebase確認中...');
      
      final user = FirebaseAuth.instance.currentUser;
      
      print('📱 [WorkoutLogScreen] 現在のユーザー: ${user?.uid ?? "null"}');
      
      if (user == null) {
        print('🔐 [WorkoutLogScreen] 自動ログイン開始...');
        
        // リトライ機能付きログイン（最大3回試行）
        UserCredential? userCredential;
        int retryCount = 0;
        const maxRetries = 3;
        
        while (userCredential == null && retryCount < maxRetries) {
          try {
            retryCount++;
            print('   試行 $retryCount/$maxRetries...');
            
            userCredential = await FirebaseAuth.instance.signInAnonymously().timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw Exception('ログインタイムアウト（15秒）');
              },
            );
            
            print('✅ [WorkoutLogScreen] 自動ログイン成功: ${userCredential.user?.uid}');
            
          } catch (e) {
            print('   試行 $retryCount 失敗: $e');
            if (retryCount < maxRetries) {
              print('   2秒後に再試行...');
              await Future.delayed(const Duration(seconds: 2));
            } else {
              print('❌ 最大試行回数に達しました');
              rethrow;
            }
          }
        }
        
        // ログイン後、少し待ってからUI更新
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        print('✅ [WorkoutLogScreen] 既にログイン済み: ${user.uid}');
      }
    } catch (e, stackTrace) {
      print('❌ [WorkoutLogScreen] 自動ログイン失敗: $e');
      print('   StackTrace: $stackTrace');
      try {
        print('   Firebase App: ${FirebaseAuth.instance.app.name}');
        print('   Firebase Project: ${FirebaseAuth.instance.app.options.projectId}');
      } catch (e2) {
        print('   Firebase確認エラー: $e2');
      }
      
      // エラー時も続行（エラー画面を表示）
    } finally {
      if (mounted) {
        print('📱 [WorkoutLogScreen] 初期化完了、UI更新');
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 初期化中はローディング表示
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('トレーニング記録'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('デモモードで起動中...'),
            ],
          ),
        ),
      );
    }

    // StreamBuilderでFirebase認証状態を監視
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ログイン済み
        final user = snapshot.data;
        if (user != null) {
          return _buildMainContent(user);
        }

        // ログイン失敗時 - 詳細なデバッグ情報を表示
        print('⚠️ StreamBuilder: ユーザーがnull');
        print('   ConnectionState: ${snapshot.connectionState}');
        print('   HasError: ${snapshot.hasError}');
        if (snapshot.hasError) {
          print('   Error: ${snapshot.error}');
        }
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('トレーニング記録'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orange),
                  const SizedBox(height: 24),
                  const Text(
                    '認証エラー',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Firebaseの初期化またはログインに失敗しました',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  if (kDebugMode && snapshot.hasError) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'エラー詳細:\n${snapshot.error}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isInitializing = true;
                      });
                      _initializeAuth();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('再試行'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // ホーム画面に戻る
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text('ホームに戻る'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// メインコンテンツ表示
  Widget _buildMainContent(User user) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニング記録'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              // カレンダー表示機能（今後実装）
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Layer 2-5 クイックアクセスバー
          _buildQuickAccessBar(context),
          
          // メインコンテンツ
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workout_logs')
            .where('user_id', isEqualTo: user.uid)
            .snapshots(), // リアルタイム更新（自動反映）
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // より詳細なエラー表示
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'データの読み込みに失敗しました',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'デモモードでは初回アクセス時にデータがありません',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddWorkoutScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('最初の記録を追加'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'まだトレーニング記録がありません',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddWorkoutScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('最初の記録を追加'),
                  ),
                ],
              ),
            );
          }

          // workout_logsデータを直接使用
          final workoutDocs = snapshot.data!.docs;
          
          // メモリ内で日付ソート（Firestoreインデックス不要）
          workoutDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final dateA = (dataA['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final dateB = (dataB['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return dateB.compareTo(dateA);
          });
          
          // 最新30件のみ表示
          final displayDocs = workoutDocs.take(30).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayDocs.length,
            itemBuilder: (context, index) {
              final doc = displayDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _SimpleWorkoutCard(
                workoutId: doc.id,
                workoutData: data,
              );
            },
          );
        },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddWorkoutScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Layer 2-5 クイックアクセスバー
  Widget _buildQuickAccessBar(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _QuickAccessCard(
            title: '週次レポート',
            subtitle: '統計分析',
            icon: Icons.bar_chart,
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WeeklyReportsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          _QuickAccessCard(
            title: 'PR記録',
            subtitle: '最高記録',
            icon: Icons.trending_up,
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PersonalRecordsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          _QuickAccessCard(
            title: '部位別',
            subtitle: '部位分析',
            icon: Icons.accessibility_new,
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BodyPartTrackingScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          _QuickAccessCard(
            title: 'メモ',
            subtitle: 'トレーニングメモ',
            icon: Icons.note_add,
            color: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WorkoutMemoListScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// クイックアクセスカード
class _QuickAccessCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// シンプルなトレーニングカード（workout_logsデータ用）
class _SimpleWorkoutCard extends StatelessWidget {
  final String workoutId;
  final Map<String, dynamic> workoutData;

  const _SimpleWorkoutCard({
    required this.workoutId,
    required this.workoutData,
  });

  @override
  Widget build(BuildContext context) {
    // データ解析
    final muscleGroup = workoutData['muscle_group'] as String? ?? '不明';
    final date = (workoutData['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final startTime = (workoutData['start_time'] as Timestamp?)?.toDate();
    final endTime = (workoutData['end_time'] as Timestamp?)?.toDate();
    final sets = workoutData['sets'] as List<dynamic>? ?? [];
    
    // トレーニング時間計算
    int? duration;
    if (startTime != null && endTime != null) {
      duration = endTime.difference(startTime).inMinutes;
    }
    
    // 種目数とセット数を計算
    final exerciseNames = <String>{};
    for (final set in sets) {
      if (set is Map<String, dynamic>) {
        final exerciseName = set['exercise_name'] as String?;
        if (exerciseName != null) {
          exerciseNames.add(exerciseName);
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SimpleWorkoutDetailScreen(
                workoutId: workoutId,
                workoutData: workoutData,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy/MM/dd (E)', 'ja').format(date),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  if (duration != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$duration分',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Chip(
                label: Text(muscleGroup),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.fitness_center,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${exerciseNames.length}種目 • ${sets.length} セット',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
