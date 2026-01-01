import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 通知設定画面
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // 通知設定の状態
  bool _workoutReminders = true;
  bool _goalProgress = true;
  bool _newMessages = true;
  bool _partnerRequests = true;
  bool _gymUpdates = true;
  bool _promotions = false;
  
  // リマインダー時刻
  TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 設定を読み込み
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workoutReminders = prefs.getBool('notif_workout_reminders') ?? true;
      _goalProgress = prefs.getBool('notif_goal_progress') ?? true;
      _newMessages = prefs.getBool('notif_new_messages') ?? true;
      _partnerRequests = prefs.getBool('notif_partner_requests') ?? true;
      _gymUpdates = prefs.getBool('notif_gym_updates') ?? true;
      _promotions = prefs.getBool('notif_promotions') ?? false;
      
      final hour = prefs.getInt('reminder_hour') ?? 18;
      final minute = prefs.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  /// 設定を保存
  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// リマインダー時刻を保存
  Future<void> _saveReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_hour', time.hour);
    await prefs.setInt('reminder_minute', time.minute);
  }

  /// 時刻選択
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: Theme.of(context).colorScheme.primary,
              dialHandColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
      await _saveReminderTime(picked);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('リマインダー時刻を${_formatTime(_reminderTime)}に設定しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 時刻をフォーマット
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          AppLocalizations.of(context)!.notificationSettings,
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // トレーニング通知
          _buildSectionHeader(AppLocalizations.of(context)!.workout),
          _buildNotificationCard(
            icon: Icons.fitness_center,
            iconColor: Colors.blue,
            title: AppLocalizations.of(context)!.workoutReminders,
            subtitle: AppLocalizations.of(context)!.profile_5d327b0d,
            value: _workoutReminders,
            onChanged: (value) {
              setState(() => _workoutReminders = value);
              _saveSetting('notif_workout_reminders', value);
            },
          ),
          
          // リマインダー時刻設定（ワークアウトリマインダーがONの場合）
          if (_workoutReminders) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: ListTile(
                leading: Icon(Icons.access_time, color: Colors.blue[700]),
                title: const Text(
                  AppLocalizations.of(context)!.profile_9b272b41,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_formatTime(_reminderTime)),
                trailing: const Icon(Icons.edit, size: 20),
                onTap: _selectTime,
              ),
            ),
          ],

          const SizedBox(height: 12),
          _buildNotificationCard(
            icon: Icons.flag,
            iconColor: Colors.green,
            title: AppLocalizations.of(context)!.profile_07143ba3,
            subtitle: AppLocalizations.of(context)!.profile_143190c5,
            value: _goalProgress,
            onChanged: (value) {
              setState(() => _goalProgress = value);
              _saveSetting('notif_goal_progress', value);
            },
          ),

          const SizedBox(height: 24),

          // ソーシャル通知
          _buildSectionHeader(AppLocalizations.of(context)!.profile_ac37b7eb),
          _buildNotificationCard(
            icon: Icons.message,
            iconColor: Colors.purple,
            title: AppLocalizations.of(context)!.profile_aee8f242,
            subtitle: AppLocalizations.of(context)!.profile_652e4f2a,
            value: _newMessages,
            onChanged: (value) {
              setState(() => _newMessages = value);
              _saveSetting('notif_new_messages', value);
            },
          ),

          const SizedBox(height: 12),
          _buildNotificationCard(
            icon: Icons.people,
            iconColor: Colors.orange,
            title: AppLocalizations.of(context)!.profile_01b6f7d1,
            subtitle: AppLocalizations.of(context)!.profile_786b22b4,
            value: _partnerRequests,
            onChanged: (value) {
              setState(() => _partnerRequests = value);
              _saveSetting('notif_partner_requests', value);
            },
          ),

          const SizedBox(height: 24),

          // 一般通知
          _buildSectionHeader(AppLocalizations.of(context)!.general),
          _buildNotificationCard(
            icon: Icons.store,
            iconColor: Colors.teal,
            title: AppLocalizations.of(context)!.profile_39a1a356,
            subtitle: AppLocalizations.of(context)!.profile_12c898c4,
            value: _gymUpdates,
            onChanged: (value) {
              setState(() => _gymUpdates = value);
              _saveSetting('notif_gym_updates', value);
            },
          ),

          const SizedBox(height: 12),
          _buildNotificationCard(
            icon: Icons.campaign,
            iconColor: Colors.red,
            title: AppLocalizations.of(context)!.profile_3cfc9048,
            subtitle: AppLocalizations.of(context)!.profile_04e477db,
            value: _promotions,
            onChanged: (value) {
              setState(() => _promotions = value);
              _saveSetting('notif_promotions', value);
            },
          ),

          const SizedBox(height: 32),

          // 説明テキスト
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '通知は端末の設定でも管理できます。\n設定アプリ > 通知 からご確認ください。',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// セクションヘッダー
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  /// 通知設定カード
  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 2,
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
