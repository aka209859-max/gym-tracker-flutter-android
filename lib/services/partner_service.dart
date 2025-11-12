import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/training_partner.dart';

/// トレーニングパートナーサービス
class PartnerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// パートナー候補を検索
  Stream<List<TrainingPartner>> searchPartners({
    String? experienceLevel,
    String? gymId,
    double? userLat,
    double? userLon,
    double? maxDistanceKm,
  }) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    Query query = _firestore
        .collection('training_partners')
        .where('isAvailable', isEqualTo: true);

    // 経験レベルでフィルタ
    if (experienceLevel != null && experienceLevel.isNotEmpty) {
      query = query.where('experienceLevel', isEqualTo: experienceLevel);
    }

    // ジムでフィルタ
    if (gymId != null && gymId.isNotEmpty) {
      query = query.where('gymId', isEqualTo: gymId);
    }

    return query
        .orderBy('lastActive', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      var partners = snapshot.docs
          .map((doc) => TrainingPartner.fromFirestore(doc))
          .where((partner) => partner.id != currentUserId) // 自分を除外
          .toList();

      // 距離でフィルタ
      if (maxDistanceKm != null && userLat != null && userLon != null) {
        partners = partners.where((partner) {
          final distance = partner.distanceFrom(userLat, userLon);
          return distance != null && distance <= maxDistanceKm;
        }).toList();
      }

      // 距離でソート
      if (userLat != null && userLon != null) {
        partners.sort((a, b) {
          final distA = a.distanceFrom(userLat, userLon) ?? double.infinity;
          final distB = b.distanceFrom(userLat, userLon) ?? double.infinity;
          return distA.compareTo(distB);
        });
      }

      return partners;
    });
  }

  /// パートナープロフィールを更新
  Future<void> updatePartnerProfile({
    required String bio,
    required String experienceLevel,
    required List<String> preferredExercises,
    required List<String> goals,
    String? gymId,
    String? gymName,
    double? latitude,
    double? longitude,
    bool isAvailable = true,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('ログインが必要です');

    await _firestore.collection('training_partners').doc(currentUser.uid).set({
      'name': currentUser.displayName ?? 'Unknown',
      'photoUrl': currentUser.photoURL ?? '',
      'bio': bio,
      'experienceLevel': experienceLevel,
      'preferredExercises': preferredExercises,
      'goals': goals,
      'gymId': gymId,
      'gymName': gymName,
      'latitude': latitude,
      'longitude': longitude,
      'isAvailable': isAvailable,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// パートナーリクエストを送信
  Future<void> sendPartnerRequest({
    required String targetId,
    required String targetName,
    required String targetPhotoUrl,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('ログインが必要です');

    // 既存のリクエストをチェック
    final existingRequests = await _firestore
        .collection('partner_requests')
        .where('requesterId', isEqualTo: currentUser.uid)
        .where('targetId', isEqualTo: targetId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequests.docs.isNotEmpty) {
      throw Exception('既にリクエストを送信済みです');
    }

    // リクエストを作成
    await _firestore.collection('partner_requests').add({
      'requesterId': currentUser.uid,
      'requesterName': currentUser.displayName ?? 'Unknown',
      'requesterPhotoUrl': currentUser.photoURL ?? '',
      'targetId': targetId,
      'targetName': targetName,
      'targetPhotoUrl': targetPhotoUrl,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
    });
  }

  /// 受信したパートナーリクエストを取得
  Stream<List<PartnerRequest>> getReceivedRequests() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('partner_requests')
        .where('targetId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PartnerRequest.fromFirestore(doc))
          .toList();
    });
  }

  /// パートナーリクエストを承認
  Future<void> acceptPartnerRequest(String requestId, String requesterId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('ログインが必要です');

    // リクエストを承認
    await _firestore.collection('partner_requests').doc(requestId).update({
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    // チャット会話を作成
    final requesterDoc = await _firestore
        .collection('training_partners')
        .doc(requesterId)
        .get();

    if (requesterDoc.exists) {
      final requesterData = requesterDoc.data()!;
      
      // 会話IDを生成（小さいUID + 大きいUID）
      final conversationId = currentUser.uid.compareTo(requesterId) < 0
          ? '${currentUser.uid}_$requesterId'
          : '${requesterId}_${currentUser.uid}';

      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': [currentUser.uid, requesterId],
        'participantNames': {
          currentUser.uid: currentUser.displayName ?? 'Unknown',
          requesterId: requesterData['name'] ?? 'Unknown',
        },
        'participantPhotos': {
          currentUser.uid: currentUser.photoURL ?? '',
          requesterId: requesterData['photoUrl'] ?? '',
        },
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
        'unreadCount': {
          currentUser.uid: 0,
          requesterId: 0,
        },
      }, SetOptions(merge: true));
    }
  }

  /// パートナーリクエストを拒否
  Future<void> rejectPartnerRequest(String requestId) async {
    await _firestore.collection('partner_requests').doc(requestId).update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// パートナー一覧を取得（承認済み）
  Stream<List<TrainingPartner>> getAcceptedPartners() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('partner_requests')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .asyncMap((snapshot) async {
      final partnerIds = <String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['requesterId'] == currentUserId) {
          partnerIds.add(data['targetId']);
        } else if (data['targetId'] == currentUserId) {
          partnerIds.add(data['requesterId']);
        }
      }

      if (partnerIds.isEmpty) return <TrainingPartner>[];

      // パートナー情報を取得
      final partners = <TrainingPartner>[];
      for (final partnerId in partnerIds) {
        final doc = await _firestore
            .collection('training_partners')
            .doc(partnerId)
            .get();
        if (doc.exists) {
          partners.add(TrainingPartner.fromFirestore(doc));
        }
      }

      return partners;
    });
  }

  /// 最終アクティブ時刻を更新
  Future<void> updateLastActive() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('training_partners').doc(currentUserId).update({
      'lastActive': FieldValue.serverTimestamp(),
    });
  }
}
