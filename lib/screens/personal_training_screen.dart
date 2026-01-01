import 'package:gym_match/gen/app_localizations.dart';
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
        title: Text(AppLocalizations.of(context)!.personalTraining),
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
            SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.personalTraining,
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
        Text(AppLocalizations.of(context)!.generateMenu,
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
          title: AppLocalizations.of(context)!.general_2c7a47d4,
          subtitle: AppLocalizations.of(context)!.confirm,
          onTap: () {
            // TODO: 予約状況画面へ遷移
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.general_95f06a54)),
            );
          },
        ),
        const SizedBox(height: 12),
        
        // 新規予約
        _buildMenuCard(
          context,
          icon: Icons.add_circle,
          iconColor: Colors.green,
          title: AppLocalizations.of(context)!.general_bd9326cc,
          subtitle: AppLocalizations.of(context)!.general_e8725971,
          onTap: () {
            // TODO: 新規予約画面へ遷移
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.general_791be39d)),
            );
          },
        ),
        const SizedBox(height: 12),
        
        // トレーナー記録
        _buildMenuCard(
          context,
          icon: Icons.assignment,
          iconColor: Colors.orange,
          title: AppLocalizations.of(context)!.general_fae344b2,
          subtitle: AppLocalizations.of(context)!.general_6c8b9d29,
          onTap: () {
            // TODO: トレーナー記録画面へ遷移
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.general_ea97e57d)),
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
