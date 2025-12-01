import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// レビュー依頼サービス（ASO最適化）
/// 
/// 5回目のトレーニング記録後に自動的にレビューを依頼
class ReviewRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final InAppReview _inAppReview = InAppReview.instance;

  // レビュー依頼のトリガー条件
  static const int _workoutCountTrigger = 5; // 5回目のトレーニング記録後
  static const int _cooldownDays = 90; // 一度拒否したら90日間は表示しない

  /// レビュー依頼を表示すべきかチェック
  Future<bool> shouldShowReviewRequest() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // レビュー済みかチェック
      if (await _hasReviewed()) {
        return false;
      }

      // クールダウン期間中かチェック
      if (await _isInCooldownPeriod()) {
        return false;
      }

      // トレーニング記録回数をチェック
      final workoutCount = await _getWorkoutCount();
      if (workoutCount < _workoutCountTrigger) {
        return false;
      }

      // 既に表示済みかチェック
      if (await _hasShownReviewRequest()) {
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ レビュー依頼チェックエラー: $e');
      return false;
    }
  }

  /// レビュー依頼ダイアログを表示
  Future<void> showReviewRequestDialog(BuildContext context) async {
    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text(
              'GYM MATCH を気に入っていますか？',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '5回もトレーニングを記録していただき、ありがとうございます！',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'よろしければ、App Store でレビューをお願いします。\nあなたのフィードバックがアプリの改善に役立ちます！',
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
            icon: const Icon(Icons.star),
            label: const Text('レビューする'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _requestReview();
    } else {
      await _markAsDeclined();
    }
  }

  /// App Store レビューをリクエスト
  Future<void> _requestReview() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        await _markAsReviewed();
        if (kDebugMode) debugPrint('✅ レビューリクエスト送信成功');
      } else {
        // In-App Review が利用できない場合、App Store を直接開く
        await _inAppReview.openStoreListing(appStoreId: '6755346813');
        await _markAsReviewed();
        if (kDebugMode) debugPrint('✅ App Store を開きました');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ レビューリクエストエラー: $e');
    }
  }

  /// トレーニング記録回数を取得
  Future<int> _getWorkoutCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final workoutsSnapshot = await _firestore
        .collection('workout_logs')
        .where('userId', isEqualTo: user.uid)
        .get();

    return workoutsSnapshot.docs.length;
  }

  /// レビュー済みフラグをセット
  Future<void> _markAsReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_reviewed', true);
    await prefs.setString('reviewed_at', DateTime.now().toIso8601String());

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'hasReviewed': true,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    }

    if (kDebugMode) debugPrint('✅ レビュー済みフラグをセット');
  }

  /// レビュー依頼を表示済みにする
  Future<void> _markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('review_request_shown', true);
    await prefs.setString('review_request_shown_at', DateTime.now().toIso8601String());
  }

  /// レビューを拒否した時刻を記録（クールダウン期間開始）
  Future<void> _markAsDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('review_declined_at', DateTime.now().toIso8601String());
    if (kDebugMode) debugPrint('ℹ️ レビュー拒否: ${_cooldownDays}日間はリクエストしません');
  }

  /// レビュー済みかチェック
  Future<bool> _hasReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_reviewed') ?? false;
  }

  /// レビュー依頼を表示済みかチェック
  Future<bool> _hasShownReviewRequest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('review_request_shown') ?? false;
  }

  /// クールダウン期間中かチェック
  Future<bool> _isInCooldownPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    final declinedAtStr = prefs.getString('review_declined_at');
    
    if (declinedAtStr == null) return false;

    final declinedAt = DateTime.parse(declinedAtStr);
    final cooldownEnd = declinedAt.add(Duration(days: _cooldownDays));

    return DateTime.now().isBefore(cooldownEnd);
  }

  /// レビュー依頼を手動でトリガー（デバッグ用）
  Future<void> triggerReviewRequest(BuildContext context) async {
    await showReviewRequestDialog(context);
  }
}
