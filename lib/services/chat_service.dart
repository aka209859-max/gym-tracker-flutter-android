import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import 'friend_request_service.dart';

/// チャットサービス
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FriendRequestService _friendRequestService = FriendRequestService();

  /// 会話一覧を取得（リアルタイム）
  Stream<List<Conversation>> getConversations() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Conversation.fromFirestore(doc)).toList();
    });
  }

  /// メッセージ一覧を取得（リアルタイム）
  Stream<List<ChatMessage>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
    });
  }

  /// メッセージを送信
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception(AppLocalizations.of(context)!.loginRequired);

    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    final conversationDoc = await conversationRef.get();

    if (!conversationDoc.exists) {
      throw Exception(AppLocalizations.of(context)!.general_705052a5);
    }

    final conversationData = conversationDoc.data();
    if (conversationData == null) {
      throw Exception(AppLocalizations.of(context)!.error_8f013312);
    }
    
    final participants = List<String>.from(conversationData['participants'] as List? ?? []);
    final participantNames = Map<String, String>.from(conversationData['participantNames'] as Map? ?? {});

    // メッセージを追加
    final messageRef = conversationRef.collection('messages').doc();
    await messageRef.set({
      'conversationId': conversationId,
      'senderId': currentUser.uid,
      'senderName': participantNames[currentUser.uid] ?? currentUser.displayName ?? 'Unknown',
      'senderPhotoUrl': currentUser.photoURL ?? '',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // 会話情報を更新
    final unreadCount = Map<String, int>.from(
      (conversationData['unreadCount'] as Map<dynamic, dynamic>?)?.map(
        (key, value) => MapEntry(key.toString(), value as int),
      ) ?? {},
    );

    // 相手の未読数を増加
    for (final participantId in participants) {
      if (participantId != currentUser.uid) {
        unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1;
      }
    }

    await conversationRef.update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUser.uid,
      'unreadCount': unreadCount,
    });
  }

  /// チャットルーム作成（パートナー機能用）
  Future<String> createChatRoom(String partnerId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception(AppLocalizations.of(context)!.loginRequired);

    // 🔒 友達チェック
    final isFriend = await _friendRequestService.areFriends(currentUser.uid, partnerId);
    if (!isFriend) {
      throw Exception(AppLocalizations.of(context)!.general_3165d4b1);
    }

    // 既存のチャットルームを検索
    final existingRooms = await _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    for (var doc in existingRooms.docs) {
      final data = doc.data();
      final participantsData = data['participants'];
      if (participantsData == null) continue;
      
      final participants = List<String>.from(participantsData);
      if (participants.contains(partnerId)) {
        return doc.id;
      }
    }

    // 新しいチャットルームを作成
    final roomRef = await _firestore.collection('chat_rooms').add({
      'participants': [currentUser.uid, partnerId],
      'last_message': '',
      'last_message_time': FieldValue.serverTimestamp(),
      'unread_count': {currentUser.uid: 0, partnerId: 0},
      'created_at': FieldValue.serverTimestamp(),
    });

    return roomRef.id;
  }

  /// 会話を作成または取得
  Future<String> getOrCreateConversation({
    required String otherUserId,
    required String otherUserName,
    required String otherUserPhotoUrl,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception(AppLocalizations.of(context)!.loginRequired);

    // 既存の会話を検索
    final existingConversations = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    for (final doc in existingConversations.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants']);
      if (participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    // 新規会話を作成
    final conversationRef = _firestore.collection('conversations').doc();
    await conversationRef.set({
      'participants': [currentUser.uid, otherUserId],
      'participantNames': {
        currentUser.uid: currentUser.displayName ?? 'Unknown',
        otherUserId: otherUserName,
      },
      'participantPhotos': {
        currentUser.uid: currentUser.photoURL ?? '',
        otherUserId: otherUserPhotoUrl,
      },
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': '',
      'unreadCount': {
        currentUser.uid: 0,
        otherUserId: 0,
      },
    });

    return conversationRef.id;
  }

  /// 未読メッセージを既読にする
  Future<void> markAsRead(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final conversationRef = _firestore.collection('conversations').doc(conversationId);

    await conversationRef.update({
      'unreadCount.$currentUserId': 0,
    });
  }

  /// 総未読数を取得
  Stream<int> getTotalUnreadCount() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = Map<String, int>.from(
          (data['unreadCount'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(key.toString(), value as int),
          ) ?? {},
        );
        total += unreadCount[currentUserId] ?? 0;
      }
      return total;
    });
  }
}
