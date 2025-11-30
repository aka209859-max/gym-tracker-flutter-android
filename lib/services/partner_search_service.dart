import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' show cos, sqrt, asin;
import '../models/partner_profile.dart';
import 'subscription_service.dart';
import 'strength_matching_service.dart';
import 'spatiotemporal_matching_service.dart';

/// パートナー検索サービス
/// 
/// トレーニングパートナーの検索・マッチング機能を提供
class PartnerSearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();
  final StrengthMatchingService _strengthService = StrengthMatchingService();
  final SpatiotemporalMatchingService _spatiotemporalService = SpatiotemporalMatchingService();

  /// 自分のパートナープロフィールを取得
  Future<PartnerProfile?> getMyProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    try {
      final doc = await _firestore.collection('partner_profiles').doc(userId).get();
      if (!doc.exists) return null;
      
      final data = doc.data();
      if (data == null) return null;

      return PartnerProfile.fromFirestore(data, userId);
    } catch (e) {
      throw Exception('プロフィール取得エラー: $e');
    }
  }

  /// パートナープロフィールを作成・更新
  Future<void> saveProfile(PartnerProfile profile) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ログインが必要です');

    try {
      await _firestore.collection('partner_profiles').doc(userId).set(
        profile.toFirestore(),
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('プロフィール保存エラー: $e');
    }
  }

  /// パートナープロフィールを削除（プロフィール非公開）
  Future<void> deleteProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ログインが必要です');

    try {
      await _firestore.collection('partner_profiles').doc(userId).update({
        'is_visible': false,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('プロフィール削除エラー: $e');
    }
  }

  /// パートナー検索（フィルター付き + Pro非対称可視性 + 実力 + 時空間マッチング）
  /// 
  /// Pro Plan非対称可視性:
  /// - Proユーザー: すべてのユーザー（Free/Premium/Pro）を検索可能
  /// - Free/Premiumユーザー: Proユーザーのみ検索可能
  /// 
  /// 実力ベースマッチング（±15% 1RM）:
  /// - enableStrengthFilter = true: ±15%範囲内のみ表示
  /// - enableStrengthFilter = false: 全ユーザー表示（実力差でソート）
  /// 
  /// 時空間コンテキストマッチング:
  /// - enableSpatiotemporalFilter = true: 同じジム・同じ時間帯（±2h）のみ表示
  /// - enableSpatiotemporalFilter = false: 全ユーザー表示（時空間スコアでソート）
  /// 
  /// 検索条件:
  /// - 場所（緯度経度からの距離）
  /// - トレーニング目標
  /// - 経験レベル
  /// - 年齢範囲
  /// - 性別
  /// - 曜日・時間帯の可用性
  /// - 実力（±15% 1RM）
  /// - 時空間（同じジム・時間帯）
  Future<List<PartnerProfile>> searchPartners({
    double? latitude,
    double? longitude,
    double? maxDistanceKm,
    List<String>? trainingGoals,
    String? experienceLevel,
    int? minAge,
    int? maxAge,
    List<String>? genders,
    List<String>? availableDays,
    List<String>? availableTimeSlots,
    bool enableStrengthFilter = false, // ✅ 実力フィルター有効化フラグ
    bool enableSpatiotemporalFilter = false, // ✅ 時空間フィルター有効化フラグ
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ログインが必要です');

    try {
      // ✅ Pro Plan非対称可視性: 検索者のプランを取得
      final currentUserPlan = await _subscriptionService.getCurrentPlan();
      final isProUser = currentUserPlan == SubscriptionType.pro;
      
      // ✅ 実力ベースマッチング: 検索者の平均1RMを取得
      double? userAverage1RM;
      if (enableStrengthFilter) {
        userAverage1RM = await _strengthService.calculateAverage1RM(userId);
        print('💪 実力フィルター有効 - 検索者の平均1RM: ${userAverage1RM?.toStringAsFixed(1) ?? "記録なし"}kg');
      }
      
      // ✅ 時空間コンテキストマッチング: 検索者のジム・時間帯データを取得
      String? userGymId;
      List<int> userPreferredHours = [];
      if (enableSpatiotemporalFilter) {
        final spatioData = await _spatiotemporalService.getMostFrequentGymAndTime(userId);
        userGymId = spatioData['gymId'];
        userPreferredHours = spatioData['preferredHours'] ?? [];
        print('🕐 時空間フィルター有効 - 検索者のジム: $userGymId, 時間: $userPreferredHours');
      }
      
      print('🔍 パートナー検索: ${currentUserPlan.toString().split(".").last}ユーザー (Pro非対称: ${isProUser ? "全員検索可能" : "Pro限定"})');
      
      // 基本クエリ: 公開プロフィールのみ、自分以外
      Query query = _firestore.collection('partner_profiles')
          .where('is_visible', isEqualTo: true);

      // Firestore クエリでフィルタリング可能な条件のみ適用
      // 複雑な条件（距離、配列の一致など）はメモリ内でフィルタリング
      
      List<PartnerProfile> profiles = [];
      final querySnapshot = await query.get();

      for (var doc in querySnapshot.docs) {
        // 自分自身は除外
        if (doc.id == userId) continue;

        final profile = PartnerProfile.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        
        // ✅ Pro Plan非対称可視性フィルター
        // Proユーザー以外は、Proユーザーのプロフィールのみ表示
        if (!isProUser) {
          final targetUserPlan = await _getTargetUserPlan(doc.id);
          if (targetUserPlan != SubscriptionType.pro) {
            print('⏭️ Skip: ${doc.id} (Free/Premium) - 検索者がNon-Pro');
            continue; // Free/Premiumユーザーを除外
          }
        }
        
        // ✅ 実力ベースマッチングフィルター（±15% 1RM）
        if (enableStrengthFilter && userAverage1RM != null) {
          if (!_strengthService.isStrengthMatch(userAverage1RM, profile.average1RM)) {
            print('⏭️ Skip: ${doc.id} - 実力差が大きい');
            continue; // ±15%範囲外を除外
          }
        }
        
        // ✅ 時空間コンテキストマッチングフィルター（同じジム・±2時間）
        if (enableSpatiotemporalFilter && userGymId != null) {
          final score = _spatiotemporalService.calculateSpatiotemporalScore(
            userGymId: userGymId,
            userPreferredHours: userPreferredHours,
            targetGymId: profile.mostFrequentGymId ?? '',
            targetPreferredHours: profile.preferredHours ?? [],
          );
          
          // スコアが25点未満（時間差±2時間超 or 別ジム）は除外
          if (score < 25) {
            print('⏭️ Skip: ${doc.id} - 時空間スコア低 ($score点)');
            continue;
          }
        }
        
        // メモリ内フィルタリング
        bool matches = true;

        // 距離フィルター
        if (latitude != null && longitude != null && maxDistanceKm != null) {
          if (profile.latitude != null && profile.longitude != null) {
            final distance = _calculateDistance(
              latitude,
              longitude,
              profile.latitude!,
              profile.longitude!,
            );
            if (distance > maxDistanceKm) matches = false;
          } else {
            matches = false; // 位置情報がない場合は除外
          }
        }

        // トレーニング目標フィルター（1つでも一致すればOK）
        if (matches && trainingGoals != null && trainingGoals.isNotEmpty) {
          final hasCommonGoal = profile.trainingGoals.any(
            (goal) => trainingGoals.contains(goal)
          );
          if (!hasCommonGoal) matches = false;
        }

        // 経験レベルフィルター
        if (matches && experienceLevel != null) {
          if (profile.experienceLevel != experienceLevel) matches = false;
        }

        // 年齢フィルター
        if (matches && minAge != null && profile.age < minAge) matches = false;
        if (matches && maxAge != null && profile.age > maxAge) matches = false;

        // 性別フィルター
        if (matches && genders != null && genders.isNotEmpty) {
          if (!genders.contains(profile.gender)) matches = false;
        }

        // 曜日フィルター（1つでも一致すればOK）
        if (matches && availableDays != null && availableDays.isNotEmpty) {
          final hasCommonDay = profile.availableDays.any(
            (day) => availableDays.contains(day)
          );
          if (!hasCommonDay) matches = false;
        }

        // 時間帯フィルター（1つでも一致すればOK）
        if (matches && availableTimeSlots != null && availableTimeSlots.isNotEmpty) {
          final hasCommonSlot = profile.availableTimeSlots.any(
            (slot) => availableTimeSlots.contains(slot)
          );
          if (!hasCommonSlot) matches = false;
        }

        if (matches) {
          profiles.add(profile);
        }
      }

      // ✅ ソート優先順位:
      // 1. 時空間フィルター有効時: 時空間スコア（高い順）
      // 2. 実力フィルター有効時: 実力差（近い順）
      // 3. 距離情報あり: 距離（近い順）
      // 4. それ以外: レーティング（高い順）
      if (enableSpatiotemporalFilter && userGymId != null) {
        // 時空間スコアでソート（100点 = 完全一致、0点 = 全く合わない）
        profiles.sort((a, b) {
          final scoreA = _spatiotemporalService.calculateSpatiotemporalScore(
            userGymId: userGymId,
            userPreferredHours: userPreferredHours,
            targetGymId: a.mostFrequentGymId ?? '',
            targetPreferredHours: a.preferredHours ?? [],
          );
          final scoreB = _spatiotemporalService.calculateSpatiotemporalScore(
            userGymId: userGymId,
            userPreferredHours: userPreferredHours,
            targetGymId: b.mostFrequentGymId ?? '',
            targetPreferredHours: b.preferredHours ?? [],
          );
          return scoreB.compareTo(scoreA); // 降順（高スコアが上）
        });
        print('✅ 時空間スコアでソート完了: ${profiles.length}件');
      } else if (enableStrengthFilter && userAverage1RM != null) {
        // 実力差でソート（0% = 完全一致、100% = 最大差）
        profiles.sort((a, b) {
          final diffA = _strengthService.calculateStrengthDifference(userAverage1RM, a.average1RM);
          final diffB = _strengthService.calculateStrengthDifference(userAverage1RM, b.average1RM);
          return diffA.compareTo(diffB);
        });
        print('✅ 実力差でソート完了: ${profiles.length}件');
      } else if (latitude != null && longitude != null) {
        // 距離でソート（近い順）
        profiles.sort((a, b) {
          if (a.latitude == null || a.longitude == null) return 1;
          if (b.latitude == null || b.longitude == null) return -1;
          
          final distA = _calculateDistance(latitude, longitude, a.latitude!, a.longitude!);
          final distB = _calculateDistance(latitude, longitude, b.latitude!, b.longitude!);
          return distA.compareTo(distB);
        });
      } else {
        // 距離情報がない場合はレーティング順
        profiles.sort((a, b) => b.rating.compareTo(a.rating));
      }

      return profiles;
    } catch (e) {
      throw Exception('パートナー検索エラー: $e');
    }
  }

  /// 2点間の距離を計算（Haversine formula）
  /// 
  /// Returns: 距離（キロメートル）
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * asin(sqrt(a));
    
    return earthRadiusKm * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  double sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  double pi = 3.14159265359;
  
  /// 対象ユーザーのプラン種類を取得（キャッシュ付き）
  /// 
  /// Firestore users コレクションから isPremium + premiumType を読み取り
  Future<SubscriptionType> _getTargetUserPlan(String targetUserId) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(targetUserId)
          .get(const GetOptions(source: Source.cache)); // キャッシュ優先で高速化
      
      if (!userDoc.exists) return SubscriptionType.free;
      
      final data = userDoc.data();
      final isPremium = data?['isPremium'] as bool? ?? false;
      final premiumType = data?['premiumType'] as String? ?? 'free';
      
      if (isPremium) {
        if (premiumType == 'pro') return SubscriptionType.pro;
        if (premiumType == 'premium') return SubscriptionType.premium;
      }
      
      return SubscriptionType.free;
    } catch (e) {
      print('⚠️ 対象ユーザープラン取得エラー: $e');
      return SubscriptionType.free; // エラー時はFreeとして扱う
    }
  }
  
  /// マッチングリクエスト送信権限チェック（Pro限定機能）
  /// 
  /// Returns:
  /// - canSend: true = 送信可能（Proユーザー）, false = 送信不可（Free/Premium）
  /// - reason: 不可の場合の理由メッセージ
  Future<Map<String, dynamic>> canSendMatchRequest() async {
    final currentUserPlan = await _subscriptionService.getCurrentPlan();
    
    if (currentUserPlan == SubscriptionType.pro) {
      return {'canSend': true, 'reason': ''};
    } else {
      return {
        'canSend': false, 
        'reason': 'マッチングリクエスト送信はProプラン限定機能です。\nProプランにアップグレードしてパートナーとつながりましょう！',
        'currentPlan': currentUserPlan.toString().split('.').last,
      };
    }
  }

  /// マッチングリクエストを送信（✅ Pro限定機能）
  Future<void> sendMatchRequest({
    required String targetUserId,
    String? message,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ログインが必要です');

    // ✅ Pro Plan権限チェック（非対称可視性の一環）
    final permissionCheck = await canSendMatchRequest();
    if (permissionCheck['canSend'] != true) {
      throw Exception(permissionCheck['reason']);
    }

    try {
      final matchRef = _firestore.collection('partner_matches').doc();
      
      final match = PartnerMatch(
        matchId: matchRef.id,
        requesterId: userId,
        targetId: targetUserId,
        status: 'pending',
        createdAt: DateTime.now(),
        message: message,
      );

      await matchRef.set(match.toFirestore());
      print('✅ マッチングリクエスト送信成功: $userId -> $targetUserId');
    } catch (e) {
      throw Exception('マッチングリクエスト送信エラー: $e');
    }
  }

  /// 受信したマッチングリクエストを取得
  Stream<List<PartnerMatch>> getReceivedMatchRequests() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('partner_matches')
        .where('target_id', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PartnerMatch.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  /// 送信したマッチングリクエストを取得
  Stream<List<PartnerMatch>> getSentMatchRequests() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('partner_matches')
        .where('requester_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PartnerMatch.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  /// マッチングリクエストを承認
  Future<void> acceptMatchRequest(String matchId) async {
    try {
      await _firestore.collection('partner_matches').doc(matchId).update({
        'status': 'accepted',
        'responded_at': DateTime.now().toIso8601String(),
      });

      // TODO: メッセージング機能が実装されたら、チャットルームを自動作成
    } catch (e) {
      throw Exception('マッチング承認エラー: $e');
    }
  }

  /// マッチングリクエストを拒否
  Future<void> declineMatchRequest(String matchId) async {
    try {
      await _firestore.collection('partner_matches').doc(matchId).update({
        'status': 'declined',
        'responded_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('マッチング拒否エラー: $e');
    }
  }

  /// マッチング済みのパートナーリストを取得
  Future<List<String>> getMatchedPartners() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      // 自分が送信して承認されたリクエスト
      final sentMatches = await _firestore
          .collection('partner_matches')
          .where('requester_id', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      // 自分が受信して承認したリクエスト
      final receivedMatches = await _firestore
          .collection('partner_matches')
          .where('target_id', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final Set<String> partnerIds = {};

      for (var doc in sentMatches.docs) {
        partnerIds.add(doc.data()['target_id'] as String);
      }

      for (var doc in receivedMatches.docs) {
        partnerIds.add(doc.data()['requester_id'] as String);
      }

      return partnerIds.toList();
    } catch (e) {
      throw Exception('マッチングパートナー取得エラー: $e');
    }
  }

  /// 特定ユーザーのプロフィールを取得
  Future<PartnerProfile?> getProfileById(String userId) async {
    try {
      final doc = await _firestore.collection('partner_profiles').doc(userId).get();
      if (!doc.exists) return null;
      
      final data = doc.data();
      if (data == null) return null;

      return PartnerProfile.fromFirestore(data, userId);
    } catch (e) {
      throw Exception('プロフィール取得エラー: $e');
    }
  }
}
