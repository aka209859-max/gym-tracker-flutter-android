import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../models/training_partner.dart';
import '../../services/training_partner_service.dart';
import '../../services/chat_service.dart';
import '../../services/friend_request_service.dart';
import 'chat_screen_partner.dart';

/// パートナー詳細画面
class PartnerDetailScreen extends StatefulWidget {
  final TrainingPartner partner;

  const PartnerDetailScreen({super.key, required this.partner});

  @override
  State<PartnerDetailScreen> createState() => _PartnerDetailScreenState();
}

class _PartnerDetailScreenState extends State<PartnerDetailScreen> {
  final TrainingPartnerService _partnerService = TrainingPartnerService();
  final ChatService _chatService = ChatService();
  final FriendRequestService _friendRequestService = FriendRequestService();
  bool _isLoading = false;
  FriendshipStatus _friendshipStatus = FriendshipStatus.notFriends;

  @override
  void initState() {
    super.initState();
    _loadFriendshipStatus();
  }

  /// 友達関係ステータスを読み込み
  Future<void> _loadFriendshipStatus() async {
    try {
      final status = await _friendRequestService.getFriendshipStatus(widget.partner.userId);
      if (mounted) {
        setState(() {
          _friendshipStatus = status;
        });
      }
    } catch (e) {
      // エラー時はnotFriendsのまま
    }
  }

  /// 友達申請を送信
  Future<void> _sendFriendRequest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _friendRequestService.sendFriendRequest(widget.partner.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.general_456a48f9)),
        );
        await _loadFriendshipStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// メッセージ画面へ移動
  Future<void> _openChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 友達チェック
      final isFriend = await _friendRequestService.areFriends(
        widget.partner.userId,
        widget.partner.userId,
      );

      if (!isFriend) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.general_3165d4b1),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // チャットルーム作成または取得
      final roomId = await _chatService.createChatRoom(widget.partner.userId);

      if (mounted) {
        // チャット画面へ移動
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreenPartner(
              roomId: roomId,
              partner: widget.partner,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.general_dab5809e),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ヘッダー
            _buildHeader(),
            const Divider(height: 1),

            // プロフィール詳細
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 基本情報
                  _buildInfoSection(AppLocalizations.of(context)!.gym_0179630e, [
                    if (widget.partner.location != null)
                      _buildInfoRow(Icons.location_on, AppLocalizations.of(context)!.residence, widget.partner.location!),
                    if (widget.partner.experienceLevel != null)
                      _buildInfoRow(Icons.fitness_center, AppLocalizations.of(context)!.experienceLevel, widget.partner.experienceLevel!),
                  ]),

                  const SizedBox(height: 24),

                  // 目標
                  if (widget.partner.goals.isNotEmpty)
                    _buildInfoSection(AppLocalizations.of(context)!.goal, [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.partner.goals.map((goal) {
                          return Chip(
                            label: Text(goal),
                            backgroundColor: Colors.orange[50],
                            side: BorderSide(color: Colors.orange[200]!),
                          );
                        }).toList(),
                      ),
                    ]),

                  const SizedBox(height: 24),

                  // トレーニング種目
                  if (widget.partner.preferredExercises.isNotEmpty)
                    _buildInfoSection(AppLocalizations.of(context)!.profile_539d673a, [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.partner.preferredExercises.map((exercise) {
                          return Chip(
                            label: Text(exercise),
                            backgroundColor: Colors.blue[50],
                            side: BorderSide(color: Colors.blue[200]!),
                          );
                        }).toList(),
                      ),
                    ]),

                  const SizedBox(height: 24),

                  // 自己紹介
                  if (widget.partner.bio != null && widget.partner.bio!.isNotEmpty)
                    _buildInfoSection(AppLocalizations.of(context)!.bio, [
                      Text(
                        widget.partner.bio!,
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  /// 画面下部のボタンを構築
  Widget _buildBottomButtons() {
    if (_isLoading) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 友達ステータスに応じたボタン表示
            if (_friendshipStatus == FriendshipStatus.notFriends)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendFriendRequest,
                  icon: const Icon(Icons.person_add),
                  label: Text(AppLocalizations.of(context)!.general_8596907f, style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                ),
              ),

            if (_friendshipStatus == FriendshipStatus.requestSent)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.schedule),
                  label: Text(AppLocalizations.of(context)!.general_34fb6e79, style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.grey,
                  ),
                ),
              ),

            if (_friendshipStatus == FriendshipStatus.requestReceived)
              Column(
                children: [
                  const Text(
                    AppLocalizations.of(context)!.general_caeec09a,
                    style: TextStyle(fontSize: 14, color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // TODO: 拒否処理
                          },
                          child: Text(AppLocalizations.of(context)!.general_a0d47aa4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: 承認処理
                          },
                          child: Text(AppLocalizations.of(context)!.general_35db47a8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            if (_friendshipStatus == FriendshipStatus.friends)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.message),
                  label: Text(AppLocalizations.of(context)!.general_5010ff33, style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // プロフィール画像
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[300],
            backgroundImage: widget.partner.profileImageUrl != null
                ? NetworkImage(widget.partner.profileImageUrl!)
                : null,
            child: widget.partner.profileImageUrl == null
                ? const Icon(Icons.person, size: 60)
                : null,
          ),
          const SizedBox(height: 16),

          // 名前
          Text(
            widget.partner.displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          // 居住地
          if (widget.partner.location != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  widget.partner.location!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
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
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
