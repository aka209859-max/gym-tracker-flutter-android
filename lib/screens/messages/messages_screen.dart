import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// メッセージ一覧画面（マッチング相手のみ）
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.messaging,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: _currentUserId == null
          ? _buildNotLoggedIn()
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .where('participants', arrayContains: _currentUserId)
                  .orderBy('last_message_time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildEmptyState();
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildChatRoomCard(doc.id, data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.signInRequired,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.general_00af6a9c,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.searchGym,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRoomCard(String roomId, Map<String, dynamic> data) {
    final participants = List<String>.from(data['participants'] ?? []);
    final partnerId = participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
    
    final lastMessage = data['last_message'] as String? ?? '';
    final lastMessageTime = data['last_message_time'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          AppLocalizations.of(context)!.findPartner,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          lastMessage.isEmpty ? AppLocalizations.of(context)!.general_c69c0c2d : lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: lastMessageTime != null
            ? Text(
                _formatTime(lastMessageTime.toDate()),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              )
            : null,
        onTap: () {
          Navigator.pushNamed(
            context,
            '/partner/chat',
            arguments: {'roomId': roomId, 'partnerId': partnerId},
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${time.month}/${time.day}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分前';
    } else {
      return AppLocalizations.of(context)!.general_e31b5d77;
    }
  }
}
