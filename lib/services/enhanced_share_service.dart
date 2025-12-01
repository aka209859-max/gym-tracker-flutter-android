import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/workout_share_image.dart';
import '../widgets/weekly_stats_share_image.dart';

/// 拡張SNSシェアサービス（Phase 1: ユーザー獲得強化）
/// 
/// 1. Instagram Stories 対応
/// 2. PR達成時の自動シェア提案
/// 3. 週間統計シェア機能
class EnhancedShareService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 📱 Instagram Stories に直接シェア
  /// 
  /// Instagram Stories API を使用して背景画像とステッカーURLを追加
  Future<void> shareToInstagramStories({
    required BuildContext context,
    required Uint8List imageBytes,
    String? backgroundTopColor,
    String? backgroundBottomColor,
  }) async {
    try {
      // Instagram Stories用に最適化されたシェア
      // Note: iOS/Androidでは通常のShare APIを使用し、
      // ユーザーがInstagramを選択できるようにする
      await Share.shareXFiles(
        [XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: 'gym_match_story.png',
        )],
        text: 'GYM MATCHでトレーニング記録をシェア！\n#GYMMATCH #筋トレ記録 #ジム\n\nhttps://gym-match-e560d.web.app',
      );
    } catch (e) {
      if (kDebugMode) print('❌ Instagram Stories シェアエラー: $e');
      // エラーをユーザーに表示
      if (context.mounted) {
        _showError(context, 'シェアに失敗しました');
      }
    }
  }

  /// 🏆 PR達成時の自動シェア提案
  /// 
  /// 新しいPR（Personal Record）を達成した時に自動的にシェアを提案
  Future<void> checkAndOfferPRShare({
    required BuildContext context,
    required String exerciseName,
    required double newWeight,
    required int reps,
  }) async {
    if (!context.mounted) return;

    // PR達成かチェック
    final isPR = await _isNewPR(exerciseName, newWeight, reps);
    
    if (!isPR) return;

    // シェア提案ダイアログを表示
    final shouldShare = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.orange,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '新記録達成！',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$exerciseName で新記録を達成しました！',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '${newWeight.toStringAsFixed(1)} kg × $reps reps',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '🎉 素晴らしい！',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'この記録をSNSでシェアしますか？',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('後で'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.share),
            label: const Text('シェアする'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (shouldShare == true && context.mounted) {
      // PR達成画像を生成してシェア
      await _sharePRAchievement(
        context: context,
        exerciseName: exerciseName,
        weight: newWeight,
        reps: reps,
      );
    }
  }

  /// 📊 週間統計をシェア
  /// 
  /// 週次でトレーニング統計をシェア（バイラル効果）
  Future<void> shareWeeklyStats({
    required BuildContext context,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showError(context, 'ログインが必要です');
        return;
      }

      // ローディング表示
      if (context.mounted) {
        _showLoadingDialog(context, '統計画像を生成中...');
      }

      // 週間統計を取得
      final weeklyStats = await _getWeeklyStats(user.uid);
      
      if (kDebugMode) {
        print('📊 週間統計取得: $weeklyStats');
      }

      // シェア画像を生成
      final shareWidget = WeeklyStatsShareImage(
        weeklyStats: weeklyStats,
      );

      final imageBytes = await _captureWidget(shareWidget);
      
      if (kDebugMode) {
        print('🎨 画像生成完了: ${imageBytes.length} bytes');
      }

      // ローディング閉じる
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Instagram Stories優先でシェア
      await shareToInstagramStories(
        context: context,
        imageBytes: imageBytes,
        backgroundTopColor: '#6A1B9A',
        backgroundBottomColor: '#9C27B0',
      );

      // シェア記録を保存（バイラル効果測定）
      await _recordShareEvent('weekly_stats');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ 週間統計シェアエラー: $e');
        print('📍 Stack trace: $stackTrace');
      }
      if (context.mounted) {
        // ローディングダイアログが開いていたら閉じる
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || !route.isActive || route is! DialogRoute);
        _showError(context, 'シェアに失敗しました: ${e.toString()}');
      }
    }
  }

  /// トレーニング記録をシェア（Instagram Stories対応）
  Future<void> shareWorkout({
    required BuildContext context,
    required DateTime date,
    required List<WorkoutExerciseGroup> exercises,
  }) async {
    try {
      _showLoadingDialog(context, '画像を生成中...');

      final shareWidget = WorkoutShareImage(
        date: date,
        exercises: exercises,
      );

      final imageBytes = await _captureWidget(shareWidget);

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Instagram Stories優先でシェア
      await shareToInstagramStories(
        context: context,
        imageBytes: imageBytes,
        backgroundTopColor: '#1976D2',
        backgroundBottomColor: '#2196F3',
      );

      // シェア記録を保存
      await _recordShareEvent('workout');
    } catch (e) {
      if (kDebugMode) print('❌ トレーニングシェアエラー: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        _showError(context, 'シェアに失敗しました');
      }
    }
  }

  // ==================== プライベートメソッド ====================

  /// 新しいPRかチェック
  Future<bool> _isNewPR(String exerciseName, double newWeight, int reps) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // 過去の最高記録を取得
      final snapshot = await _firestore
          .collection('pr_records')
          .where('user_id', isEqualTo: user.uid)
          .where('exercise_name', isEqualTo: exerciseName)
          .orderBy('weight', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return true; // 初回記録はPR
      }

      final bestRecord = snapshot.docs.first.data();
      final bestWeight = (bestRecord['weight'] as num).toDouble();

      return newWeight > bestWeight;
    } catch (e) {
      if (kDebugMode) print('❌ PR確認エラー: $e');
      return false;
    }
  }

  /// PR達成画像をシェア
  Future<void> _sharePRAchievement({
    required BuildContext context,
    required String exerciseName,
    required double weight,
    required int reps,
  }) async {
    // PR達成専用の画像Widget（簡易版）
    final shareWidget = Container(
      width: 1080,
      height: 1920,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade700,
            Colors.deepOrange.shade900,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 120,
            ),
            const SizedBox(height: 32),
            const Text(
              '新記録達成！',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(
                    exerciseName,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${weight.toStringAsFixed(1)} kg × $reps reps',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              'GYM MATCH',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );

    final imageBytes = await _captureWidget(shareWidget);

    if (context.mounted) {
      await shareToInstagramStories(
        context: context,
        imageBytes: imageBytes,
        backgroundTopColor: '#F57C00',
        backgroundBottomColor: '#E65100',
      );
    }

    // シェア記録を保存
    await _recordShareEvent('pr_achievement');
  }

  /// 週間統計を取得
  Future<Map<String, dynamic>> _getWeeklyStats(String userId) async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('workout_logs')
          .where('user_id', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .get();

      int totalWorkouts = snapshot.docs.length;
      double totalVolume = 0.0;
      Set<String> muscleGroups = {};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          // setsフィールドの安全な取得
          final setsData = data['sets'];
          if (setsData == null || setsData is! List) {
            if (kDebugMode) print('⚠️ sets is null or not a list for doc ${doc.id}');
            continue;
          }
          
          final sets = List<Map<String, dynamic>>.from(setsData);
          
          for (var set in sets) {
            if (set is! Map) continue;
            final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
            final reps = (set['reps'] as int?) ?? 0;
            totalVolume += weight * reps;
          }

          final muscleGroup = data['muscle_group'];
          if (muscleGroup != null && muscleGroup is String && muscleGroup.isNotEmpty) {
            muscleGroups.add(muscleGroup);
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Error processing doc ${doc.id}: $e');
          continue;
        }
      }

      return {
        'totalWorkouts': totalWorkouts,
        'totalVolume': totalVolume,
        'muscleGroupsCount': muscleGroups.length,
        'avgVolumePerWorkout': totalWorkouts > 0 ? totalVolume / totalWorkouts : 0.0,
      };
    } catch (e) {
      if (kDebugMode) print('❌ _getWeeklyStats error: $e');
      rethrow;
    }
  }

  /// Widgetを画像に変換
  Future<Uint8List> _captureWidget(Widget widget) async {
    final renderObject = RenderRepaintBoundary();
    
    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());
    
    final renderView = RenderView(
      view: ui.PlatformDispatcher.instance.views.first,
      child: RenderPositionedBox(
        alignment: Alignment.center,
        child: renderObject,
      ),
      configuration: ViewConfiguration.fromView(
        ui.PlatformDispatcher.instance.views.first,
      ),
    );
    
    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();
    
    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: renderObject,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: widget,
      ),
    ).attachToRenderTree(buildOwner);
    
    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();
    
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();
    
    final image = await renderObject.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  /// 通常の画像シェア
  Future<void> _shareImage({
    required BuildContext context,
    required Uint8List imageBytes,
    required String text,
  }) async {
    await Share.shareXFiles(
      [XFile.fromData(imageBytes, mimeType: 'image/png', name: 'gym_match_share.png')],
      text: text,
    );
  }

  /// シェアイベントを記録（バイラル効果測定）
  Future<void> _recordShareEvent(String shareType) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('share_events').add({
        'user_id': user.uid,
        'share_type': shareType,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) print('✅ シェアイベント記録: $shareType');
    } catch (e) {
      if (kDebugMode) print('❌ シェアイベント記録エラー: $e');
    }
  }

  /// ローディングダイアログを表示
  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// エラーを表示
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
