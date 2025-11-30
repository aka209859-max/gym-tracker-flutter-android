import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// トレーニングリマインダー通知サービス
/// 
/// 4種類のプッシュ通知でユーザーのトレーニング継続をサポート
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 通知サービス初期化
  Future<void> initialize() async {
    if (_initialized) return;

    // タイムゾーンデータベース初期化
    tz.initializeTimeZones();

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// 通知タップ時の処理
  void _onNotificationTapped(NotificationResponse response) {
    print('📱 通知タップ: ${response.payload}');
    // TODO: 通知タイプに応じて画面遷移
  }

  /// 通知権限リクエスト
  Future<bool> requestPermission() async {
    final result = await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    return result ?? false;
  }

  /// Type 1: トレーニングリマインダー（前回トレーニングから48時間後）
  Future<void> scheduleTrainingReminder({
    required String muscleGroup,
    required Duration delay,
  }) async {
    await _notifications.zonedSchedule(
      1, // notification ID
      '${muscleGroup}の回復完了！💪',
      '次のトレーニングに最適なタイミングです',
      tz.TZDateTime.now(tz.local).add(delay),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'training_reminder',
          'トレーニングリマインダー',
          channelDescription: '次のトレーニング時期をお知らせ',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Type 2: AI分析結果通知（即座）
  Future<void> showAIAnalysisNotification({
    required String title,
    required String message,
  }) async {
    await _notifications.show(
      2, // notification ID
      title,
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ai_analysis',
          'AI分析結果',
          channelDescription: 'AI分析完了をお知らせ',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Type 3: 習慣継続サポート（7日間連続達成時）
  Future<void> showStreakAchievementNotification({
    required int streakDays,
  }) async {
    await _notifications.show(
      3, // notification ID
      '${streakDays}日間連続達成！🔥',
      '次は${streakDays + 7}日間連続を目指そう',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_achievement',
          '習慣継続サポート',
          channelDescription: '連続トレーニング達成をお知らせ',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Type 4: リエンゲージメント（7日間未ログイン）
  Future<void> scheduleReengagementNotification() async {
    await _notifications.zonedSchedule(
      4, // notification ID
      'お久しぶりです！',
      'あなたの成長予測が待っています',
      tz.TZDateTime.now(tz.local).add(const Duration(days: 7)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reengagement',
          'リエンゲージメント',
          channelDescription: 'アプリへの復帰をお知らせ',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// トレーニング完了後に次回リマインダーをスケジュール
  Future<void> scheduleNextTrainingReminder(String muscleGroup) async {
    // 48時間後にリマインダー
    await scheduleTrainingReminder(
      muscleGroup: muscleGroup,
      delay: const Duration(hours: 48),
    );

    print('✅ トレーニングリマインダー設定: $muscleGroup (48時間後)');
  }

  /// 全ての通知をキャンセル
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// 特定の通知をキャンセル
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// 最終ログイン時刻を更新（リエンゲージメント判定用）
  Future<void> updateLastLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_login_time',
      DateTime.now().toIso8601String(),
    );

    // 7日後のリエンゲージメント通知をキャンセル（ログインしたので不要）
    await cancelNotification(4);
  }

  /// 7日間未ログインチェック（アプリ起動時に呼ぶ）
  Future<void> checkAndScheduleReengagement() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLoginStr = prefs.getString('last_login_time');

    if (lastLoginStr != null) {
      final lastLogin = DateTime.parse(lastLoginStr);
      final daysSinceLastLogin = DateTime.now().difference(lastLogin).inDays;

      if (daysSinceLastLogin >= 7) {
        // 7日以上未ログイン → リエンゲージメント通知スケジュール
        await scheduleReengagementNotification();
      }
    }

    // 今回のログイン時刻を記録
    await updateLastLoginTime();
  }
}
