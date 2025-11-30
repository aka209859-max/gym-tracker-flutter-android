import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'subscription_service.dart';
import 'notification_service.dart';
import 'dart:async';

/// 混雑度アラート通知サービス（Premium/Pro限定機能）
/// 
/// お気に入りジムの混雑度が設定値以下になったときに通知
/// - Premium/Pro会員のみ利用可能
/// - 1日1回まで通知（スパム防止）
/// - Firestoreリスナーでリアルタイム監視
class CrowdAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();
  final NotificationService _notificationService = NotificationService();
  
  // アクティブなリスナーを保持
  final Map<String, StreamSubscription> _activeListeners = {};
  
  /// ユーザーのお気に入りジムの混雑度監視を開始
  Future<void> startMonitoring(String userId) async {
    try {
      // Premium/Pro会員チェック
      final plan = await _subscriptionService.getCurrentPlan();
      if (plan == SubscriptionType.free) {
        if (kDebugMode) {
          print('⚠️ Free会員は混雑度アラート非対応');
        }
        return;
      }
      
      // お気に入りジム一覧を取得
      final favorites = await _getUserFavoriteGyms(userId);
      
      if (favorites.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ お気に入りジムなし');
        }
        return;
      }
      
      // 各ジムの監視を開始
      for (final gymId in favorites) {
        await _monitorGym(userId, gymId);
      }
      
      if (kDebugMode) {
        print('✅ 混雑度監視開始: ${favorites.length}件のジム');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 混雑度監視開始エラー: $e');
      }
    }
  }
  
  /// 特定ジムの監視を開始
  Future<void> _monitorGym(String userId, String gymId) async {
    // 既に監視中なら何もしない
    if (_activeListeners.containsKey(gymId)) {
      return;
    }
    
    // ユーザーのアラート設定を取得
    final settings = await _getAlertSettings(userId, gymId);
    if (settings == null) {
      // デフォルト設定: 混雑度3以下で通知
      await _setAlertSettings(userId, gymId, targetCrowdLevel: 3);
    }
    
    // Firestoreリスナーを設定
    final listener = _firestore
        .collection('gyms')
        .doc(gymId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      
      final data = snapshot.data();
      if (data == null) return;
      
      final currentLevel = data['currentCrowdLevel'] as int?;
      if (currentLevel == null) return;
      
      // アラート条件チェック
      final targetLevel = settings?['target_crowd_level'] as int? ?? 3;
      if (currentLevel <= targetLevel) {
        await _sendAlert(userId, gymId, currentLevel, data);
      }
    });
    
    _activeListeners[gymId] = listener;
  }
  
  /// アラート通知を送信
  Future<void> _sendAlert(
    String userId,
    String gymId,
    int crowdLevel,
    Map<String, dynamic> gymData,
  ) async {
    try {
      // 1日1回制限チェック
      final canSend = await _canSendAlert(userId, gymId);
      if (!canSend) {
        if (kDebugMode) {
          print('⚠️ 本日の通知済み: $gymId');
        }
        return;
      }
      
      // 通知を送信
      final gymName = gymData['name'] as String? ?? '不明なジム';
      await _notificationService.showCrowdAlert(
        gymName: gymName,
        crowdLevel: crowdLevel,
      );
      
      // 送信記録を保存
      await _recordAlertSent(userId, gymId);
      
      if (kDebugMode) {
        print('✅ 混雑度アラート送信: $gymName (レベル: $crowdLevel)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ アラート送信エラー: $e');
      }
    }
  }
  
  /// アラート送信可能かチェック（1日1回制限）
  Future<bool> _canSendAlert(String userId, String gymId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final snapshot = await _firestore
          .collection('crowd_alerts_sent')
          .where('user_id', isEqualTo: userId)
          .where('gym_id', isEqualTo: gymId)
          .where('sent_at', isGreaterThan: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();
      
      return snapshot.docs.isEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('❌ アラート送信可能チェックエラー: $e');
      }
      return false;
    }
  }
  
  /// アラート送信を記録
  Future<void> _recordAlertSent(String userId, String gymId) async {
    try {
      await _firestore.collection('crowd_alerts_sent').add({
        'user_id': userId,
        'gym_id': gymId,
        'sent_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ アラート送信記録エラー: $e');
      }
    }
  }
  
  /// お気に入りジム一覧を取得
  Future<List<String>> _getUserFavoriteGyms(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('favorites')
          .where('user_id', isEqualTo: userId)
          .get();
      
      return snapshot.docs
          .map((doc) => doc.data()['gym_id'] as String)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ お気に入りジム取得エラー: $e');
      }
      return [];
    }
  }
  
  /// アラート設定を取得
  Future<Map<String, dynamic>?> _getAlertSettings(String userId, String gymId) async {
    try {
      final snapshot = await _firestore
          .collection('crowd_alert_settings')
          .where('user_id', isEqualTo: userId)
          .where('gym_id', isEqualTo: gymId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data();
    } catch (e) {
      if (kDebugMode) {
        print('❌ アラート設定取得エラー: $e');
      }
      return null;
    }
  }
  
  /// アラート設定を保存
  Future<void> _setAlertSettings(
    String userId,
    String gymId, {
    required int targetCrowdLevel,
  }) async {
    try {
      await _firestore.collection('crowd_alert_settings').add({
        'user_id': userId,
        'gym_id': gymId,
        'target_crowd_level': targetCrowdLevel,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ アラート設定保存エラー: $e');
      }
    }
  }
  
  /// ユーザーがアラート設定を変更
  Future<bool> updateAlertSettings({
    required String gymId,
    required int targetCrowdLevel,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      // 既存設定を検索
      final snapshot = await _firestore
          .collection('crowd_alert_settings')
          .where('user_id', isEqualTo: user.uid)
          .where('gym_id', isEqualTo: gymId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) {
        // 新規作成
        await _setAlertSettings(user.uid, gymId, targetCrowdLevel: targetCrowdLevel);
      } else {
        // 更新
        await snapshot.docs.first.reference.update({
          'target_crowd_level': targetCrowdLevel,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      
      // 監視を再起動
      await stopMonitoring(user.uid);
      await startMonitoring(user.uid);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ アラート設定更新エラー: $e');
      }
      return false;
    }
  }
  
  /// 監視を停止
  Future<void> stopMonitoring(String userId) async {
    try {
      for (final listener in _activeListeners.values) {
        await listener.cancel();
      }
      _activeListeners.clear();
      
      if (kDebugMode) {
        print('✅ 混雑度監視停止');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 監視停止エラー: $e');
      }
    }
  }
  
  /// 特定ジムの監視を停止
  Future<void> stopMonitoringGym(String gymId) async {
    try {
      final listener = _activeListeners[gymId];
      if (listener != null) {
        await listener.cancel();
        _activeListeners.remove(gymId);
        
        if (kDebugMode) {
          print('✅ ジム監視停止: $gymId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ジム監視停止エラー: $e');
      }
    }
  }
}
