import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/gym.dart';
import '../models/review.dart';
import '../services/subscription_service.dart';

/// ジムレビュー投稿画面（Premium/Pro限定）
class GymReviewScreen extends StatefulWidget {
  final Gym gym;

  const GymReviewScreen({super.key, required this.gym});

  @override
  State<GymReviewScreen> createState() => _GymReviewScreenState();
}

class _GymReviewScreenState extends State<GymReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  double _overallRating = 3.0;
  double _crowdAccuracy = 3.0;
  double _cleanliness = 3.0;
  double _staffFriendliness = 3.0;
  double _beginnerFriendly = 3.0;
  
  bool _isSubmitting = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final plan = await _subscriptionService.getCurrentPlan();
    setState(() {
      _hasPermission = plan != SubscriptionType.free;
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_hasPermission) {
      _showUpgradeDialog();
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('ログインが必要です');
      }

      // ユーザー名を取得
      String userName = 'ユーザー';
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        userName = user.displayName!;
      } else if (user.email != null) {
        userName = user.email!.split('@')[0];
      }

      final review = Review(
        id: '',
        gymId: widget.gym.gymId ?? widget.gym.id,
        userId: user.uid,
        userName: userName,
        userPhotoUrl: user.photoURL ?? '',
        overallRating: _overallRating,
        crowdAccuracy: _crowdAccuracy,
        cleanliness: _cleanliness,
        staffFriendliness: _staffFriendliness,
        beginnerFriendly: _beginnerFriendly,
        comment: _commentController.text.trim(),
        imageUrls: [],
        createdAt: DateTime.now(),
        likeCount: 0,
      );

      // Firestoreに保存
      await FirebaseFirestore.instance
          .collection('reviews')
          .add(review.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('レビューを投稿しました！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // 成功を返す
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('レビュー投稿に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.blue),
            SizedBox(width: 12),
            Text('Premium機能'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'レビュー投稿はPremium/Proプラン限定機能です。',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '💎 Premiumプランにアップグレードすると:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('• ジムレビューの投稿', style: TextStyle(fontSize: 14)),
            Text('• AI機能を月10回使用', style: TextStyle(fontSize: 14)),
            Text('• お気に入り無制限', style: TextStyle(fontSize: 14)),
            Text('• 詳細な混雑度統計', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('プランを見る'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('レビューを投稿'),
        centerTitle: true,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ジム情報カード
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.fitness_center, size: 40),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.gym.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (widget.gym.address.isNotEmpty)
                                    Text(
                                      widget.gym.address,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 総合評価
                    _buildRatingSection(
                      title: '総合評価',
                      rating: _overallRating,
                      icon: Icons.star,
                      color: Colors.amber,
                      onChanged: (value) {
                        setState(() {
                          _overallRating = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // 詳細評価
                    const Text(
                      '詳細評価',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildRatingSection(
                      title: '混雑度の正確さ',
                      rating: _crowdAccuracy,
                      icon: Icons.people,
                      color: Colors.blue,
                      onChanged: (value) {
                        setState(() {
                          _crowdAccuracy = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildRatingSection(
                      title: '清潔さ',
                      rating: _cleanliness,
                      icon: Icons.cleaning_services,
                      color: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          _cleanliness = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildRatingSection(
                      title: 'スタッフの対応',
                      rating: _staffFriendliness,
                      icon: Icons.person,
                      color: Colors.orange,
                      onChanged: (value) {
                        setState(() {
                          _staffFriendliness = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildRatingSection(
                      title: '初心者への優しさ',
                      rating: _beginnerFriendly,
                      icon: Icons.school,
                      color: Colors.purple,
                      onChanged: (value) {
                        setState(() {
                          _beginnerFriendly = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // コメント入力
                    const Text(
                      'コメント',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _commentController,
                      maxLines: 5,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'このジムの良かった点や改善点を教えてください',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'コメントを入力してください';
                        }
                        if (value.trim().length < 10) {
                          return '10文字以上入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // 投稿ボタン
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReview,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'レビューを投稿',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRatingSection({
    required String title,
    required double rating,
    required IconData icon,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: rating,
          min: 1.0,
          max: 5.0,
          divisions: 8,
          label: rating.toStringAsFixed(1),
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
