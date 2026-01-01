import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import '../models/partner_access.dart';
import 'partner_campaign_editor_screen.dart';
import 'partner_photos_screen.dart';
import 'partner_equipment_editor_screen.dart';
import 'partner_reservation_settings_screen.dart';

/// パートナーオーナー管理ダッシュボード
class PartnerDashboardScreen extends StatelessWidget {
  final PartnerAccess partnerAccess;

  const PartnerDashboardScreen({
    super.key,
    required this.partnerAccess,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.general_912246dc),
            Text(
              partnerAccess.gymName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        elevation: 2,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ウェルカムカード
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partnerAccess.gymName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🏆 β版パートナー',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.amber[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.general_e6a22641,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 管理メニュー
            _buildMenuSection(
              context,
              title: AppLocalizations.of(context)!.general_0490ae0f,
              icon: Icons.campaign,
              color: Colors.orange,
              items: [
                _MenuItem(
                  icon: Icons.edit_note,
                  title: AppLocalizations.of(context)!.edit,
                  subtitle: AppLocalizations.of(context)!.general_1588c96c,
                  enabled: partnerAccess.hasPermission('editCampaign'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PartnerCampaignEditorScreen(
                          gymId: partnerAccess.gymId,
                          gymName: partnerAccess.gymName,
                        ),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.photo_library,
                  title: AppLocalizations.of(context)!.general_64cab206,
                  subtitle: AppLocalizations.of(context)!.general_4ae49c21,
                  enabled: partnerAccess.hasPermission('uploadPhotos'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PartnerPhotosScreen(
                          gymId: partnerAccess.gymId,
                          gymName: partnerAccess.gymName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildMenuSection(
              context,
              title: AppLocalizations.of(context)!.general_28464ce8,
              icon: Icons.store,
              color: Colors.blue,
              items: [
                _MenuItem(
                  icon: Icons.fitness_center,
                  title: AppLocalizations.of(context)!.edit,
                  subtitle: AppLocalizations.of(context)!.general_aa7af64f,
                  enabled: partnerAccess.hasPermission('editFacilities'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PartnerEquipmentEditorScreen(
                          gymId: partnerAccess.gymId,
                        ),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.email,
                  title: AppLocalizations.of(context)!.general_ea0f11e0,
                  subtitle: AppLocalizations.of(context)!.settings,
                  enabled: partnerAccess.hasPermission('editFacilities'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PartnerReservationSettingsScreen(
                          gymId: partnerAccess.gymId,
                        ),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.access_time,
                  title: AppLocalizations.of(context)!.edit,
                  subtitle: AppLocalizations.of(context)!.general_5cf61f1e,
                  enabled: partnerAccess.hasPermission('editHours'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🚧 実装予定の機能です')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildMenuSection(
              context,
              title: AppLocalizations.of(context)!.general_96216a83,
              icon: Icons.analytics,
              color: Colors.purple,
              items: [
                _MenuItem(
                  icon: Icons.bar_chart,
                  title: AppLocalizations.of(context)!.general_e9e20dd1,
                  subtitle: AppLocalizations.of(context)!.confirm,
                  enabled: partnerAccess.hasPermission('viewAnalytics'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🚧 実装予定の機能です')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ログアウトボタン
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.logout),
              label: Text(AppLocalizations.of(context)!.logout),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: Column(
            children: items.map((item) => _buildMenuItem(context, item)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItem item) {
    return ListTile(
      leading: Icon(
        item.icon,
        color: item.enabled ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: item.enabled ? null : Colors.grey,
        ),
      ),
      subtitle: Text(
        item.subtitle,
        style: TextStyle(
          fontSize: 12,
          color: item.enabled ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
      trailing: item.enabled
          ? const Icon(Icons.chevron_right)
          : const Icon(Icons.lock, size: 20, color: Colors.grey),
      enabled: item.enabled,
      onTap: item.onTap,
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    required this.onTap,
  });
}
