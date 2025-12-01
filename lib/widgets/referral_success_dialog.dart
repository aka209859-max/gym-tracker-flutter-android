import 'package:flutter/material.dart';
import 'confetti_animation.dart';

/// 紹介成功ダイアログ（v1.02強化版）
/// 
/// 紹介コード適用時・友達が参加した時に表示
class ReferralSuccessDialog {
  /// 紹介コード入力成功ダイアログ（被紹介者用）
  static void showRefereeSuccess(
    BuildContext context, {
    required int aiBonus,
    required int premiumDays,
  }) {
    // 紙吹雪アニメーション表示
    ConfettiAnimation.show(context);

    // 成功ダイアログ表示
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.celebration,
                color: Colors.orange,
                size: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                '紹介特典ゲット！',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '友達の紹介コードを使っていただき、ありがとうございます！',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎁 あなたの特典',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBonusItem(
                      icon: Icons.smart_toy,
                      title: 'AIコーチング',
                      value: '×$aiBonus回',
                      description: 'すぐに使えます！',
                    ),
                    const SizedBox(height: 8),
                    _buildBonusItem(
                      icon: Icons.workspace_premium,
                      title: 'Premium無料体験',
                      value: '$premiumDays日間',
                      description: '全機能が使い放題！',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '💪 今すぐトレーニングを記録して、AIコーチングを試してみましょう！',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'はじめる！',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// 紹介成功ダイアログ（紹介者用）
  static void showReferrerSuccess(
    BuildContext context, {
    required int aiBonus,
    required int premiumDays,
    required String friendName,
  }) {
    // 紙吹雪アニメーション表示
    ConfettiAnimation.show(context);

    // 成功ダイアログ表示
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.celebration,
                color: Colors.green,
                size: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                '紹介成功！',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$friendNameさんがGYM MATCHに参加しました！',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎁 紹介特典（豪華版）',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBonusItem(
                      icon: Icons.smart_toy,
                      title: 'AIコーチング',
                      value: '×$aiBonus回',
                      description: '¥900相当！',
                    ),
                    const SizedBox(height: 8),
                    _buildBonusItem(
                      icon: Icons.workspace_premium,
                      title: 'Premium無料体験',
                      value: '$premiumDays日間',
                      description: '全機能が使い放題！',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '🚀 友達をもっと誘って、さらに特典をゲットしよう！',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('あとで'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: 紹介画面に遷移
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'もっと招待する',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// ボーナスアイテムWidget
  static Widget _buildBonusItem({
    required IconData icon,
    required String title,
    required String value,
    required String description,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange.shade700, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
