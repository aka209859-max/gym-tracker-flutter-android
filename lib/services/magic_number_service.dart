import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// マジックナンバーサービス
/// 
/// 「5記録/30日」のマジックナンバーを達成すると、
/// 80%のユーザーが継続するというデータに基づいた
/// 習慣形成サポート機能
class MagicNumberService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// マジックナンバー定数
  static const int magicNumberRecords = 5; // 30日間で5記録
  static const int magicNumberDays = 30; // 30日間
  static const double retentionRate = 0.80; // 80%継続率

  /// SharedPreferences キー
  static const String _keyAchievedDate = 'magic_number_achieved_date';
  static const String _keyShownDialog = 'magic_number_dialog_shown';

  /// 過去30日間の記録数を取得
  /// 
  /// Returns: {count: 記録数, progress: 進捗率（0.0-1.0）}
  Future<Map<String, dynamic>> getProgress() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'count': 0, 'progress': 0.0, 'daysRemaining': magicNumberDays};

      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(Duration(days: magicNumberDays));

      // 過去30日間のワークアウトログを取得
      final snapshot = await _firestore
          .collection('workout_logs')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      // 日付のセットを作成（重複排除 = 1日1記録としてカウント）
      final trainingDates = <DateTime>{};
      for (final doc in snapshot.docs) {
        final dateTimestamp = doc['date'] as Timestamp?;
        if (dateTimestamp != null) {
          final date = dateTimestamp.toDate();
          trainingDates.add(DateTime(date.year, date.month, date.day));
        }
      }

      final count = trainingDates.length;
      final progress = (count / magicNumberRecords).clamp(0.0, 1.0);

      // 初回記録からの経過日数を計算
      int daysRemaining = magicNumberDays;
      if (trainingDates.isNotEmpty) {
        final firstRecordDate = trainingDates.reduce((a, b) => a.isBefore(b) ? a : b);
        final daysSinceFirst = now.difference(firstRecordDate).inDays;
        daysRemaining = (magicNumberDays - daysSinceFirst).clamp(0, magicNumberDays);
      }

      return {
        'count': count,
        'progress': progress,
        'daysRemaining': daysRemaining,
        'isAchieved': count >= magicNumberRecords,
      };
    } catch (e) {
      print('❌ マジックナンバー進捗取得エラー: $e');
      return {'count': 0, 'progress': 0.0, 'daysRemaining': magicNumberDays};
    }
  }

  /// マジックナンバー達成をチェック
  /// 
  /// Returns: true = 達成（かつ未表示）、false = 未達成or既表示
  Future<bool> checkAndMarkAchievement() async {
    try {
      final progressData = await getProgress();
      final isAchieved = progressData['isAchieved'] as bool? ?? false;

      if (!isAchieved) return false;

      // 既に達成ダイアログを表示済みかチェック
      final prefs = await SharedPreferences.getInstance();
      final hasShown = prefs.getBool(_keyShownDialog) ?? false;

      if (hasShown) return false;

      // 達成日時を記録
      await _recordAchievement();

      // ダイアログ表示済みフラグを立てる
      await prefs.setBool(_keyShownDialog, true);
      await prefs.setString(_keyAchievedDate, DateTime.now().toIso8601String());

      print('🎉 マジックナンバー達成！');
      return true;
    } catch (e) {
      print('❌ マジックナンバー達成チェックエラー: $e');
      return false;
    }
  }

  /// 達成をFirestoreに記録
  Future<void> _recordAchievement() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('magic_number_achievements').add({
        'userId': user.uid,
        'achievedAt': FieldValue.serverTimestamp(),
        'recordCount': magicNumberRecords,
        'days': magicNumberDays,
      });

      // ユーザープロフィールにも記録
      await _firestore.collection('users').doc(user.uid).update({
        'magicNumberAchieved': true,
        'magicNumberAchievedAt': FieldValue.serverTimestamp(),
      });

      print('✅ マジックナンバー達成をFirestoreに記録');
    } catch (e) {
      print('❌ 達成記録エラー: $e');
    }
  }

  /// 達成済みかチェック（ダイアログ表示用）
  Future<bool> hasAchieved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyShownDialog) ?? false;
    } catch (e) {
      print('❌ 達成済みチェックエラー: $e');
      return false;
    }
  }

  /// 達成日時を取得
  Future<DateTime?> getAchievedDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = prefs.getString(_keyAchievedDate);
      if (dateStr == null) return null;
      return DateTime.parse(dateStr);
    } catch (e) {
      print('❌ 達成日時取得エラー: $e');
      return null;
    }
  }

  /// 進捗メッセージを生成
  /// 
  /// Returns: ユーザーを励ますメッセージ
  String getProgressMessage(int count) {
    if (count == 0) {
      return AppLocalizations.of(context)!.general_c719e5c8;
    } else if (count == 1) {
      return 'いいスタートです！あと${magicNumberRecords - count}記録で習慣化達成！';
    } else if (count < magicNumberRecords) {
      final remaining = magicNumberRecords - count;
      return 'あと$remaining記録！この調子で続けましょう💪';
    } else {
      return '🎉 習慣化達成！あなたは継続できる人です！';
    }
  }

  /// リマインダーが必要かチェック
  /// 
  /// 15日経過して2記録未満の場合、リマインダーを推奨
  Future<bool> shouldShowReminder() async {
    try {
      final progressData = await getProgress();
      final count = progressData['count'] as int;
      final daysRemaining = progressData['daysRemaining'] as int;

      // 15日経過（残り15日以下）で2記録未満
      if (daysRemaining <= 15 && count < 2) {
        return true;
      }

      return false;
    } catch (e) {
      print('❌ リマインダーチェックエラー: $e');
      return false;
    }
  }

  /// リマインダーメッセージを生成
  String getReminderMessage(int count, int daysRemaining) {
    if (count == 0) {
      return '30日以内に5記録で習慣化！\n今日からスタートしませんか？';
    } else if (count == 1) {
      return 'あと4記録で習慣化達成！\n残り${daysRemaining}日です。';
    } else {
      return 'あと${magicNumberRecords - count}記録！\n残り${daysRemaining}日で達成できます💪';
    }
  }
}
