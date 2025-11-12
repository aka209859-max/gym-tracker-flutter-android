import 'package:cloud_firestore/cloud_firestore.dart';

/// チャットメッセージモデル
class ChatMessage {
  final String id;
  final String conversationId; // チャットルームID
  final String senderId; // 送信者UID
  final String senderName; // 送信者名
  final String senderPhotoUrl; // 送信者プロフィール画像URL
  final String text; // メッセージ本文
  final DateTime timestamp; // 送信日時
  final bool isRead; // 既読フラグ

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });

  /// Firestoreから変換
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderPhotoUrl: data['senderPhotoUrl'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  /// Firestoreへ変換
  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }
}

/// 会話（チャットルーム）モデル
class Conversation {
  final String id;
  final List<String> participants; // 参加者UIDリスト
  final Map<String, String> participantNames; // UID -> 名前マッピング
  final Map<String, String> participantPhotos; // UID -> 写真URLマッピング
  final String lastMessage; // 最新メッセージ
  final DateTime lastMessageTime; // 最新メッセージ日時
  final String lastMessageSenderId; // 最新メッセージ送信者
  final Map<String, int> unreadCount; // UID -> 未読数マッピング

  Conversation({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.participantPhotos,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.unreadCount,
  });

  /// Firestoreから変換
  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantPhotos: Map<String, String>.from(data['participantPhotos'] ?? {}),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map<dynamic, dynamic>?)?.map(
          (key, value) => MapEntry(key.toString(), value as int),
        ) ?? {},
      ),
    );
  }

  /// Firestoreへ変換
  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
    };
  }

  /// 相手の名前を取得
  String getOtherParticipantName(String currentUserId) {
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    return participantNames[otherUserId] ?? 'Unknown';
  }

  /// 相手の写真URLを取得
  String getOtherParticipantPhoto(String currentUserId) {
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    return participantPhotos[otherUserId] ?? '';
  }

  /// 現在ユーザーの未読数を取得
  int getUnreadCount(String currentUserId) {
    return unreadCount[currentUserId] ?? 0;
  }
}
