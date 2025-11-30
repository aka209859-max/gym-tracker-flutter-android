import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_log.dart';

/// 時空間コンテキストマッチングサービス
/// 
/// 同じジムで同じ時間帯（±2時間）にトレーニングする
/// パートナー候補をマッチングします。
class SpatiotemporalMatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ユーザーの頻繁に通うジムと時間帯を分析
  /// 
  /// Returns: {gymId: {曜日: [時間帯のリスト]}}
  Future<Map<String, Map<String, List<int>>>> analyzeUserGymSchedule(
    String userId, {
    int daysToAnalyze = 30,
  }) async {
    try {
      final since = DateTime.now().subtract(Duration(days: daysToAnalyze));
      
      final workoutsSnapshot = await _firestore
          .collection('workout_logs')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('date', descending: true)
          .limit(100)
          .get();

      // ジムID別、曜日別、時間帯別に集計
      final schedule = <String, Map<String, List<int>>>{};

      for (var doc in workoutsSnapshot.docs) {
        final log = WorkoutLog.fromFirestore(doc.data(), doc.id);
        final gymId = log.gymId;
        final dayOfWeek = _getDayOfWeekKey(log.date);
        final hour = log.date.hour;

        // ジムIDごとに初期化
        if (!schedule.containsKey(gymId)) {
          schedule[gymId] = {};
        }

        // 曜日ごとに初期化
        if (!schedule[gymId]!.containsKey(dayOfWeek)) {
          schedule[gymId]![dayOfWeek] = [];
        }

        // 時間帯を追加
        schedule[gymId]![dayOfWeek]!.add(hour);
      }

      print('✅ ユーザー $userId のスケジュール分析完了: ${schedule.keys.length}ジム');
      return schedule;
    } catch (e) {
      print('❌ スケジュール分析エラー: $e');
      return {};
    }
  }

  /// ユーザーの最頻出ジムとトレーニング時間帯を取得
  /// 
  /// Returns: {gymId: 最頻出ジムID, preferredHours: [よく行く時間帯]}
  Future<Map<String, dynamic>> getMostFrequentGymAndTime(String userId) async {
    final schedule = await analyzeUserGymSchedule(userId);

    if (schedule.isEmpty) {
      return {'gymId': null, 'preferredHours': <int>[]};
    }

    // 最頻出ジムを特定（トレーニング回数が最も多いジム）
    String? mostFrequentGymId;
    int maxVisits = 0;

    for (var entry in schedule.entries) {
      final totalVisits = entry.value.values
          .expand((hours) => hours)
          .length;
      
      if (totalVisits > maxVisits) {
        maxVisits = totalVisits;
        mostFrequentGymId = entry.key;
      }
    }

    // 最頻出ジムのよく行く時間帯を集計
    final preferredHours = <int>[];
    if (mostFrequentGymId != null) {
      final gymSchedule = schedule[mostFrequentGymId]!;
      final allHours = gymSchedule.values.expand((hours) => hours).toList();
      
      // 時間帯の頻度をカウント
      final hourFrequency = <int, int>{};
      for (var hour in allHours) {
        hourFrequency[hour] = (hourFrequency[hour] ?? 0) + 1;
      }

      // 頻度の高い時間帯を抽出（2回以上）
      preferredHours.addAll(
        hourFrequency.entries
            .where((e) => e.value >= 2)
            .map((e) => e.key)
            .toList()
      );
      preferredHours.sort();
    }

    print('✅ 最頻出ジム: $mostFrequentGymId, よく行く時間: $preferredHours');
    return {
      'gymId': mostFrequentGymId,
      'preferredHours': preferredHours,
    };
  }

  /// 時空間マッチング: 同じジムで±2時間以内にトレーニングするユーザーを検索
  /// 
  /// Parameters:
  /// - [targetGymId]: 検索対象のジムID
  /// - [targetHour]: 検索対象の時間帯（0-23）
  /// - [currentUserId]: 検索者のユーザーID（除外用）
  /// 
  /// Returns: マッチするユーザーIDのリスト
  Future<List<String>> findMatchingUsers({
    required String targetGymId,
    required int targetHour,
    String? currentUserId,
    int hourWindow = 2, // ±2時間
  }) async {
    try {
      final minHour = (targetHour - hourWindow).clamp(0, 23);
      final maxHour = (targetHour + hourWindow).clamp(0, 23);

      // 過去30日間のワークアウトログを検索
      final since = DateTime.now().subtract(const Duration(days: 30));
      
      final workoutsSnapshot = await _firestore
          .collection('workout_logs')
          .where('gymId', isEqualTo: targetGymId)
          .where('date', isGreaterThan: Timestamp.fromDate(since))
          .get();

      // ユーザーIDと時間帯をフィルタリング
      final matchingUserIds = <String>{};

      for (var doc in workoutsSnapshot.docs) {
        final log = WorkoutLog.fromFirestore(doc.data(), doc.id);
        final hour = log.date.hour;

        // 時間帯が±2時間以内かチェック
        if (hour >= minHour && hour <= maxHour) {
          if (log.userId != currentUserId) {
            matchingUserIds.add(log.userId);
          }
        }
      }

      print('✅ 時空間マッチング: ${matchingUserIds.length}人 (ジム: $targetGymId, 時間: $targetHour±${hourWindow}h)');
      return matchingUserIds.toList();
    } catch (e) {
      print('❌ 時空間マッチングエラー: $e');
      return [];
    }
  }

  /// 時空間コンテキストスコアを計算（0-100）
  /// 
  /// - 同じジム: +50点
  /// - 時間帯が近い: +50点（±0h: 50点、±1h: 35点、±2h: 25点）
  /// 
  /// Returns: スコア（0-100）
  int calculateSpatiotemporalScore({
    required String userGymId,
    required List<int> userPreferredHours,
    required String targetGymId,
    required List<int> targetPreferredHours,
  }) {
    int score = 0;

    // 1. 同じジムかチェック（+50点）
    if (userGymId == targetGymId) {
      score += 50;
    }

    // 2. 時間帯の近さをチェック（+0〜50点）
    if (userPreferredHours.isNotEmpty && targetPreferredHours.isNotEmpty) {
      int minTimeDiff = 24; // 初期値は最大差

      for (var userHour in userPreferredHours) {
        for (var targetHour in targetPreferredHours) {
          final diff = (userHour - targetHour).abs();
          if (diff < minTimeDiff) {
            minTimeDiff = diff;
          }
        }
      }

      // 時間差に応じてスコアを付与
      if (minTimeDiff == 0) {
        score += 50; // 完全一致
      } else if (minTimeDiff == 1) {
        score += 35; // ±1時間
      } else if (minTimeDiff == 2) {
        score += 25; // ±2時間
      } else if (minTimeDiff <= 4) {
        score += 10; // ±3-4時間
      }
    }

    return score.clamp(0, 100);
  }

  /// PartnerProfileに時空間データを保存
  /// 
  /// 最頻出ジムIDとよく行く時間帯をpartner_profilesに保存
  Future<void> updateSpatiotemporalDataInProfile(String userId) async {
    try {
      final data = await getMostFrequentGymAndTime(userId);
      
      if (data['gymId'] == null) {
        print('ℹ️ ユーザー $userId: ジムデータなし、更新スキップ');
        return;
      }

      await _firestore.collection('partner_profiles').doc(userId).update({
        'most_frequent_gym_id': data['gymId'],
        'preferred_hours': data['preferredHours'],
        'spatiotemporal_updated_at': FieldValue.serverTimestamp(),
      });

      print('✅ ユーザー $userId の時空間データ更新: ジム ${data['gymId']}, 時間 ${data['preferredHours']}');
    } catch (e) {
      print('❌ 時空間データ更新エラー: $e');
    }
  }

  /// 曜日キーを取得（月曜=monday、火曜=tuesday、...）
  String _getDayOfWeekKey(DateTime date) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[date.weekday - 1];
  }
}
