import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pt_member.dart';

/// PO会員詳細画面
class POMemberDetailScreen extends StatelessWidget {
  final PTMember member;

  const POMemberDetailScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(member.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.edit)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 基本情報
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppLocalizations.of(context)!.gym_0179630e,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(label: AppLocalizations.of(context)!.name, value: member.name),
                  _InfoRow(label: AppLocalizations.of(context)!.email, value: member.email),
                  if (member.phoneNumber != null)
                    _InfoRow(label: AppLocalizations.of(context)!.gymPhone, value: member.phoneNumber!),
                  _InfoRow(
                    label: AppLocalizations.of(context)!.general_d583e5d0,
                    value: DateFormat('yyyy/MM/dd').format(member.joinedAt),
                  ),
                  _InfoRow(label: AppLocalizations.of(context)!.general_a82f5771, value: member.trainerName),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 契約情報
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppLocalizations.of(context)!.general_f499f3a7,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _InfoRow(label: AppLocalizations.of(context)!.upgradePlan, value: member.planName),
                  _InfoRow(
                    label: AppLocalizations.of(context)!.general_71becd2b,
                    value: '${member.totalSessions}回',
                  ),
                  _InfoRow(
                    label: AppLocalizations.of(context)!.general_520812b8,
                    value: '${member.remainingSessions}回',
                  ),
                  if (member.lastSessionAt != null)
                    _InfoRow(
                      label: AppLocalizations.of(context)!.general_49c6c5b4,
                      value: DateFormat('yyyy/MM/dd')
                          .format(member.lastSessionAt!),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ステータス
          Card(
            color: member.isActive ? Colors.green[50] : Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    member.isActive ? Icons.check_circle : Icons.warning,
                    color: member.isActive ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      member.isActive
                          ? AppLocalizations.of(context)!.general_54e32695
                          : AppLocalizations.of(context)!.general_6fff9de3,
                      style: TextStyle(
                        fontSize: 14,
                        color: member.isActive
                            ? Colors.green[800]
                            : Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // アクションボタン
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.general_0dfb3c3b)),
              );
            },
            icon: const Icon(Icons.message),
            label: Text(AppLocalizations.of(context)!.general_ed353b30),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.general_75a6ecb5)),
              );
            },
            icon: const Icon(Icons.history),
            label: Text(AppLocalizations.of(context)!.general_5573bee6),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
