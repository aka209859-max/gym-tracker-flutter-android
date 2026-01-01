import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_request.dart';

/// 友達関係ステータス
enum FriendshipStatus {
  notFriends,        // 友達ではない
  requestSent,       // 申請送信済み
  requestReceived,   // 申請受信済み
  friends,           // 友達
}

/// 友達申請サービス
class FriendRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 友達申請を送信
  Future<void> sendFriendRequest(String targetId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception(AppLocalizations.of(context)!.userNotAuthenticated);
    
    if (currentUserId == targetId) {
      throw Exception(AppLocalizations.of(context)!.general_82c35ddb);
    }

    // 既存の申請をチェック
    final existingRequest = await _firestore
        .collection('friend_requests')
        .where('requester_id', isEqualTo: currentUserId)
        .where('target_id', isEqualTo: targetId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception(AppLocalizations.of(context)!.general_036253ca);
    }

    // 逆方向の申請をチェック（相手が既に申請している場合）
    final reverseRequest = await _firestore
        .collection('friend_requests')
        .where('requester_id', isEqualTo: targetId)
        .where('target_id', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (reverseRequest.docs.isNotEmpty) {
      // 相手からの申請があれば自動承認
      await approveFriendRequest(reverseRequest.docs.first.id);
      return;
    }

    // 友達申請を作成
    await _firestore.collection('friend_requests').add({
      'requester_id': currentUserId,
      'target_id': targetId,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
      'responded_at': null,
    });
  }

  /// 友達申請を承認
  Future<void> approveFriendRequest(String requestId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception(AppLocalizations.of(context)!.userNotAuthenticated);

    // 申請情報を取得
    final requestDoc = await _firestore
        .collection('friend_requests')
        .doc(requestId)
        .get();

    if (!requestDoc.exists) {
      throw Exception(AppLocalizations.of(context)!.general_6cbc10f0);
    }

    final requestData = requestDoc.data();
    if (requestData == null) {
      throw Exception(AppLocalizations.of(context)!.gym_c7e47d32);
    }
    final requesterId = requestData['requester_id'] as String;
    final targetId = requestData['target_id'] as String;

    // 自分宛の申請かチェック
    if (targetId != currentUserId) {
      throw Exception(AppLocalizations.of(context)!.general_0f541745);
    }

    // 申請を承認済みに更新
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'approved',
      'responded_at': FieldValue.serverTimestamp(),
    });

    // 友達リストに追加（双方向）
    await _addFriend(requesterId, targetId);
  }

  /// 友達申請を拒否
  Future<void> rejectFriendRequest(String requestId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception(AppLocalizations.of(context)!.userNotAuthenticated);

    // 申請情報を取得
    final requestDoc = await _firestore
        .collection('friend_requests')
        .doc(requestId)
        .get();

    if (!requestDoc.exists) {
      throw Exception(AppLocalizations.of(context)!.general_6cbc10f0);
    }

    final requestData = requestDoc.data();
    if (requestData == null) {
      throw Exception(AppLocalizations.of(context)!.gym_c7e47d32);
    }
    final targetId = requestData['target_id'] as String;

    // 自分宛の申請かチェック
    if (targetId != currentUserId) {
      throw Exception(AppLocalizations.of(context)!.general_58b51061);
    }

    // 申請を拒否済みに更新
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'rejected',
      'responded_at': FieldValue.serverTimestamp(),
    });
  }

  /// 友達関係を作成（双方向）
  Future<void> _addFriend(String userId1, String userId2) async {
    final batch = _firestore.batch();

    // ユーザー1の友達リストに追加
    final user1FriendRef = _firestore
        .collection('users')
        .doc(userId1)
        .collection('friends')
        .doc(userId2);
    
    batch.set(user1FriendRef, {
      'friend_id': userId2,
      'created_at': FieldValue.serverTimestamp(),
    });

    // ユーザー2の友達リストに追加
    final user2FriendRef = _firestore
        .collection('users')
        .doc(userId2)
        .collection('friends')
        .doc(userId1);
    
    batch.set(user2FriendRef, {
      'friend_id': userId1,
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// 友達関係を確認
  Future<bool> areFriends(String userId1, String userId2) async {
    final friendDoc = await _firestore
        .collection('users')
        .doc(userId1)
        .collection('friends')
        .doc(userId2)
        .get();

    return friendDoc.exists;
  }

  /// 友達関係のステータスを取得
  Future<FriendshipStatus> getFriendshipStatus(String targetId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return FriendshipStatus.notFriends;

    // 友達かチェック
    final isFriend = await areFriends(currentUserId, targetId);
    if (isFriend) return FriendshipStatus.friends;

    // 送信した申請をチェック
    final sentRequest = await _firestore
        .collection('friend_requests')
        .where('requester_id', isEqualTo: currentUserId)
        .where('target_id', isEqualTo: targetId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (sentRequest.docs.isNotEmpty) {
      return FriendshipStatus.requestSent;
    }

    // 受信した申請をチェック
    final receivedRequest = await _firestore
        .collection('friend_requests')
        .where('requester_id', isEqualTo: targetId)
        .where('target_id', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (receivedRequest.docs.isNotEmpty) {
      return FriendshipStatus.requestReceived;
    }

    return FriendshipStatus.notFriends;
  }

  /// 受信した友達申請一覧を取得（リアルタイム）
  Stream<List<FriendRequest>> getReceivedRequests() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('friend_requests')
        .where('target_id', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FriendRequest.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  /// 送信した友達申請一覧を取得（リアルタイム）
  Stream<List<FriendRequest>> getSentRequests() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('friend_requests')
        .where('requester_id', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FriendRequest.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  /// 友達リストを取得（リアルタイム）
  Stream<List<String>> getFriends() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data()['friend_id'] as String)
          .toList();
    });
  }

  /// 友達を削除
  Future<void> removeFriend(String friendId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception(AppLocalizations.of(context)!.userNotAuthenticated);

    final batch = _firestore.batch();

    // 自分の友達リストから削除
    final myFriendRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(friendId);
    batch.delete(myFriendRef);

    // 相手の友達リストから削除
    final theirFriendRef = _firestore
        .collection('users')
        .doc(friendId)
        .collection('friends')
        .doc(currentUserId);
    batch.delete(theirFriendRef);

    await batch.commit();
  }
}
