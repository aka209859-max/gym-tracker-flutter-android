import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/training_partner.dart';
import '../../services/training_partner_service.dart';

/// パートナーチャット画面（ブロック・通報機能付き）
class ChatScreenPartner extends StatefulWidget {
  final String roomId;
  final TrainingPartner partner;

  const ChatScreenPartner({
    super.key,
    required this.roomId,
    required this.partner,
  });

  @override
  State<ChatScreenPartner> createState() => _ChatScreenPartnerState();
}

class _ChatScreenPartnerState extends State<ChatScreenPartner> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TrainingPartnerService _partnerService = TrainingPartnerService();
  
  String? _currentUserId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// メッセージ送信
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentUserId == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final messageText = _messageController.text.trim();
      _messageController.clear();

      final messageRef = FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'message_id': messageRef.id,
        'sender_id': _currentUserId,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // チャットルーム更新
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.roomId)
          .update({
        'last_message': messageText,
        'last_message_time': FieldValue.serverTimestamp(),
      });

      // スクロールを最下部へ
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  /// ブロック確認ダイアログ
  Future<void> _showBlockDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.partner.displayName}さんをブロックしますか？'),
            const SizedBox(height: 16),
            Text(
              'ブロックすると:\n'
              '• メッセージの送受信ができなくなります\n'
              '• 検索結果に表示されなくなります\n'
              '• 相手からあなたのプロフィールが見られなくなります',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.general_9bba20c8),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _blockUser();
    }
  }

  /// ブロック実行
  Future<void> _blockUser() async {
    try {
      await _partnerService.blockUser(widget.partner.userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.general_1a0017eb)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 通報ダイアログ
  Future<void> _showReportDialog() async {
    String selectedReason = AppLocalizations.of(context)!.inappropriateContent;
    final TextEditingController detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.report),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.selectExercise),
                const SizedBox(height: 12),
                ...[
                  AppLocalizations.of(context)!.inappropriateContent,
                  AppLocalizations.of(context)!.general_43115ef3,
                  AppLocalizations.of(context)!.general_6687d4b9,
                  AppLocalizations.of(context)!.general_503e4fae,
                  AppLocalizations.of(context)!.other,
                ].map((reason) {
                  return RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.general_c2c1126e,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.sendMessage),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _reportUser(selectedReason, detailsController.text);
    }
  }

  /// 通報実行
  Future<void> _reportUser(String reason, String? details) async {
    try {
      await _partnerService.reportUser(
        targetUserId: widget.partner.userId,
        reason: reason,
        details: details,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.general_f53f0049)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.partner.displayName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') {
                _showBlockDialog();
              } else if (value == 'report') {
                _showReportDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20),
                    SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.general_0cdd8f95),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.flag, size: 20),
                    SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.report),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // メッセージリスト
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.roomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(AppLocalizations.of(context)!.snapshotError(snapshot.error.toString())));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.general_948098d7,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data() as Map<String, dynamic>;
                    final senderId = messageData['sender_id'] as String;
                    final text = messageData['text'] as String;
                    final timestamp = messageData['timestamp'] as Timestamp?;
                    final isMe = senderId == _currentUserId;

                    return _buildMessageBubble(
                      text: text,
                      isMe: isMe,
                      timestamp: timestamp?.toDate(),
                    );
                  },
                );
              },
            ),
          ),

          // メッセージ入力欄
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isMe,
    DateTime? timestamp,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Colors.grey[300],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'メッセージを入力...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
