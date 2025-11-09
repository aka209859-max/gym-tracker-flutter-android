import 'package:flutter/material.dart';

/// パーソナルトレーニング画面
/// 予約状況確認、新規予約、トレーナー記録閲覧
class PersonalTrainingScreen extends StatefulWidget {
  const PersonalTrainingScreen({super.key});

  @override
  State<PersonalTrainingScreen> createState() => _PersonalTrainingScreenState();
}

class _PersonalTrainingScreenState extends State<PersonalTrainingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('パーソナルトレーニング'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダーカード
            _buildHeaderCard(context),
            const SizedBox(height: 24),
            
            // メニューセクション
            _buildMenuSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.fitness_center,
              size: 64,
              color: Colors.orange[700],
            ),
            const SizedBox(height: 16),
            const Text(
              'パーソナルトレーニング',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'プロのトレーナーによる\nマンツーマン指導',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'メニュー',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // 予約状況
        _buildMenuCard(
          context,
          icon: Icons.calendar_today,
          iconColor: Colors.blue,
          title: '予約状況',
          subtitle: '現在の予約を確認',
          onTap: () {
            // TODO: 予約状況画面へ遷移
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('予約状況機能は開発中です')),
            );
          },
        ),
        const SizedBox(height: 12),
        
        // 新規予約
        _buildMenuCard(
          context,
          icon: Icons.add_circle,
          iconColor: Colors.green,
          title: '新規予約',
          subtitle: 'トレーニングを予約する',
          onTap: () {
            // TODO: 新規予約画面へ遷移
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('新規予約機能は開発中です')),
            );
          },
        ),
        const SizedBox(height: 12),
        
        // トレーナー記録
        _buildMenuCard(
          context,
          icon: Icons.assignment,
          iconColor: Colors.orange,
          title: 'トレーナー記録',
          subtitle: 'トレーナーが記録したトレーニング履歴',
          onTap: () {
            // TODO: トレーナー記録画面へ遷移
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('トレーナー記録機能は開発中です')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
