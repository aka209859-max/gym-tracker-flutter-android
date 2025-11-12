import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/training_partner.dart';
import '../../services/partner_service.dart';
import '../../services/chat_service.dart';
import '../messages/chat_detail_screen.dart';

/// パートナー詳細画面
class PartnerDetailScreen extends StatefulWidget {
  final TrainingPartner partner;
  final double? distance;
  final bool isMyPartner;

  const PartnerDetailScreen({
    super.key,
    required this.partner,
    this.distance,
    this.isMyPartner = false,
  });

  @override
  State<PartnerDetailScreen> createState() => _PartnerDetailScreenState();
}

class _PartnerDetailScreenState extends State<PartnerDetailScreen> {
  final PartnerService _partnerService = PartnerService();
  final ChatService _chatService = ChatService();
  bool _isLoading = false;

  /// パートナーリクエストを送信
  Future<void> _sendRequest() async {
    setState(() => _isLoading = true);

    try {
      await _partnerService.sendPartnerRequest(
        targetId: widget.partner.id,
        targetName: widget.partner.name,
        targetPhotoUrl: widget.partner.photoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('リクエストを送信しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// メッセージを開始
  Future<void> _startChat() async {
    setState(() => _isLoading = true);

    try {
      final conversationId = await _chatService.getOrCreateConversation(
        otherUserId: widget.partner.id,
        otherUserName: widget.partner.name,
        otherUserPhotoUrl: widget.partner.photoUrl,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              conversationId: conversationId,
              otherUserName: widget.partner.name,
              otherUserPhotoUrl: widget.partner.photoUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'プロフィール',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ヘッダー
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    backgroundImage: widget.partner.photoUrl.isNotEmpty
                        ? NetworkImage(widget.partner.photoUrl)
                        : null,
                    child: widget.partner.photoUrl.isEmpty
                        ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.partner.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.partner.experienceLevelText,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            // 情報カード
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 基本情報
                  _buildInfoCard(
                    title: '基本情報',
                    children: [
                      if (widget.distance != null)
                        _buildInfoRow(Icons.location_on, '距離',
                            '${widget.distance!.toStringAsFixed(1)} km'),
                      if (widget.partner.gymName != null)
                        _buildInfoRow(Icons.fitness_center, '所属ジム',
                            widget.partner.gymName!),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 自己紹介
                  if (widget.partner.bio.isNotEmpty)
                    _buildInfoCard(
                      title: '自己紹介',
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            widget.partner.bio,
                            style: const TextStyle(fontSize: 15, height: 1.6),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // 好きな種目
                  if (widget.partner.preferredExercises.isNotEmpty)
                    _buildInfoCard(
                      title: '好きな種目',
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.partner.preferredExercises
                              .map((exercise) => Chip(
                                    label: Text(exercise),
                                    backgroundColor: Colors.blue.shade50,
                                    labelStyle: TextStyle(color: Colors.blue.shade700),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // 目標
                  if (widget.partner.goals.isNotEmpty)
                    _buildInfoCard(
                      title: '目標',
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.partner.goals
                              .map((goal) => Chip(
                                    label: Text(goal),
                                    backgroundColor: Colors.green.shade50,
                                    labelStyle: TextStyle(color: Colors.green.shade700),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: widget.isMyPartner
              ? ElevatedButton.icon(
                  onPressed: _isLoading ? null : _startChat,
                  icon: const Icon(Icons.message),
                  label: const Text('メッセージを送る'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendRequest,
                  icon: const Icon(Icons.person_add),
                  label: const Text('パートナーリクエストを送る'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
        ),
      ),
    );
  }

  /// 情報カード
  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// 情報行
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
