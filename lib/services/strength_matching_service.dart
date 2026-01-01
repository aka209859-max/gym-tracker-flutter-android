import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/personal_record.dart';
import 'pr_tracking_service.dart';

/// 実力ベースマッチングサービス（±15% 1RM）
/// 
/// ユーザーの主要種目（BIG3）の1RM平均値を計算し、
/// 類似する実力のパートナーをマッチングします。
class StrengthMatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PRTrackingService _prService = PRTrackingService();

  /// BIG3種目のキーワード（部分一致で検索）
  static const List<String> _big3Keywords = {
    // スクワット系
    AppLocalizations.of(context)!.exerciseSquat, 'squat',
    // ベンチプレス系
    AppLocalizations.of(context)!.exerciseBenchPress, 'bench press', AppLocalizations.of(context)!.general_c757af1f,
    // デッドリフト系
    AppLocalizations.of(context)!.exerciseDeadlift, 'deadlift',
  };

  /// ユーザーの平均1RM（BIG3）を計算
  /// 
  /// Returns: 平均1RM（kg）、BIG3の記録がない場合は null
  Future<double?> calculateAverage1RM(String userId) async {
    try {
      // 全てのPRを取得
      final allPRs = await _prService.getAllPRs(userId);
      
      if (allPRs.isEmpty) {
        print('ℹ️ ユーザー $userId: PR記録なし');
        return null;
      }

      // BIG3に該当する種目のPRを抽出
      final big3PRs = allPRs.where((pr) {
        final exerciseNameLower = pr.exerciseName.toLowerCase();
        return _big3Keywords.any((keyword) =>
            exerciseNameLower.contains(keyword.toLowerCase()));
      }).toList();

      if (big3PRs.isEmpty) {
        print('ℹ️ ユーザー $userId: BIG3記録なし');
        return null;
      }

      // 各種目（スクワット、ベンチ、デッド）の最大1RMを取得
      final squatPR = _getMaxPRByKeyword(big3PRs, [AppLocalizations.of(context)!.exerciseSquat, 'squat']);
      final benchPR = _getMaxPRByKeyword(big3PRs, [AppLocalizations.of(context)!.exerciseBenchPress, 'bench press', AppLocalizations.of(context)!.general_c757af1f]);
      final deadliftPR = _getMaxPRByKeyword(big3PRs, [AppLocalizations.of(context)!.exerciseDeadlift, 'deadlift']);

      // 記録がある種目のみで平均を計算
      final values = <double>[];
      if (squatPR != null) values.add(squatPR);
      if (benchPR != null) values.add(benchPR);
      if (deadliftPR != null) values.add(deadliftPR);

      if (values.isEmpty) return null;

      final average = values.reduce((a, b) => a + b) / values.length;
      
      print('✅ ユーザー $userId の平均1RM: ${average.toStringAsFixed(1)}kg (${values.length}種目)');
      return average;
    } catch (e) {
      print('❌ 平均1RM計算エラー: $e');
      return null;
    }
  }

  /// 特定キーワードに一致する最大1RMを取得
  double? _getMaxPRByKeyword(List<PersonalRecord> prs, List<String> keywords) {
    final matchingPRs = prs.where((pr) {
      final exerciseNameLower = pr.exerciseName.toLowerCase();
      return keywords.any((kw) => exerciseNameLower.contains(kw.toLowerCase()));
    }).toList();

    if (matchingPRs.isEmpty) return null;

    // 最大1RMを返す
    matchingPRs.sort((a, b) => b.calculated1RM.compareTo(a.calculated1RM));
    return matchingPRs.first.calculated1RM;
  }

  /// ユーザーの平均1RMをFirestoreに保存
  /// 
  /// partner_profilesコレクションの`average_1rm`フィールドを更新
  Future<void> updateAverage1RMInProfile(String userId) async {
    try {
      final average1RM = await calculateAverage1RM(userId);
      
      if (average1RM == null) {
        print('ℹ️ ユーザー $userId: 1RM更新スキップ（記録なし）');
        return;
      }

      await _firestore.collection('partner_profiles').doc(userId).update({
        'average_1rm': average1RM,
        'average_1rm_updated_at': FieldValue.serverTimestamp(),
      });

      print('✅ ユーザー $userId の平均1RM更新: ${average1RM.toStringAsFixed(1)}kg');
    } catch (e) {
      print('❌ Firestore更新エラー: $e');
    }
  }

  /// 実力が近いユーザーをフィルタリング（±15% 1RM）
  /// 
  /// Parameters:
  /// - [userAverage1RM]: 検索者の平均1RM
  /// - [targetAverage1RM]: 対象ユーザーの平均1RM
  /// 
  /// Returns: true = マッチング可能、false = 実力差が大きい
  bool isStrengthMatch(double? userAverage1RM, double? targetAverage1RM) {
    // どちらかがnullの場合はマッチング可（初心者を除外しない）
    if (userAverage1RM == null || targetAverage1RM == null) {
      return true;
    }

    // ±15%の範囲内かチェック
    final lowerBound = userAverage1RM * 0.85; // -15%
    final upperBound = userAverage1RM * 1.15; // +15%

    final isMatch = targetAverage1RM >= lowerBound && targetAverage1RM <= upperBound;
    
    if (!isMatch) {
      print('❌ 実力差大: 検索者 ${userAverage1RM.toStringAsFixed(1)}kg vs 対象 ${targetAverage1RM.toStringAsFixed(1)}kg');
    }

    return isMatch;
  }

  /// 実力差の近さでソート（0% = 完全一致、100% = 最大差）
  /// 
  /// Returns: 実力差のパーセンテージ（0-100）
  double calculateStrengthDifference(double? userAverage1RM, double? targetAverage1RM) {
    if (userAverage1RM == null || targetAverage1RM == null) {
      return 100.0; // データなしは最低優先度
    }

    final diff = (targetAverage1RM - userAverage1RM).abs();
    final percentage = (diff / userAverage1RM) * 100;

    return percentage.clamp(0.0, 100.0);
  }
}
