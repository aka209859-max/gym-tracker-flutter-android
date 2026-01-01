import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pt_member.dart';
import 'po_member_detail_screen.dart';

/// PO会員管理画面
class POMembersScreen extends StatefulWidget {
  final String partnerId;

  const POMembersScreen({super.key, required this.partnerId});

  @override
  State<POMembersScreen> createState() => _POMembersScreenState();
}

class _POMembersScreenState extends State<POMembersScreen> {
  String _filterStatus = 'all'; // 'all', 'active', 'dormant'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // フィルタ
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'all', label: Text(AppLocalizations.of(context)!.general_f3a02437)),
                ButtonSegment(value: 'active', label: Text(AppLocalizations.of(context)!.active)),
                ButtonSegment(value: 'dormant', label: Text(AppLocalizations.of(context)!.general_a9de8b69)),
              ],
              selected: {_filterStatus},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _filterStatus = newSelection.first;
                });
              },
            ),
          ),

          // 会員リスト
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('personalTrainingMembers')
                  .where('partnerId', isEqualTo: widget.partnerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text(AppLocalizations.of(context)!.snapshotError));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.general_ab9c4e26,
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                }

                var members = snapshot.data!.docs
                    .map((doc) => PTMember.fromFirestore(
                        doc.data() as Map<String, dynamic>, doc.id))
                    .toList();

                // フィルタ適用
                if (_filterStatus == 'active') {
                  members = members.where((m) => m.isActive).toList();
                } else if (_filterStatus == 'dormant') {
                  members = members.where((m) => !m.isActive).toList();
                }

                // サマリーカード
                final activeCount =
                    members.where((m) => m.isActive).length;
                final dormantCount =
                    members.where((m) => !m.isActive).length;

                return Column(
                  children: [
                    // サマリー
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              label: AppLocalizations.of(context)!.general_f3a02437,
                              value: '${members.length}名',
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              label: AppLocalizations.of(context)!.active,
                              value: '$activeCount名',
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              label: AppLocalizations.of(context)!.general_a9de8b69,
                              value: '$dormantCount名',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 会員リスト
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          return _MemberCard(
                            member: member,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => POMemberDetailScreen(
                                    member: member,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 会員追加機能（今後実装）
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.addWorkout)),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }


}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final PTMember member;
  final VoidCallback onTap;

  const _MemberCard({
    required this.member,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysSince = member.lastSessionAt != null
        ? DateTime.now().difference(member.lastSessionAt!).inDays
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(member.name[0]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '担当: ${member.trainerName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: member.isActive
                          ? Colors.green[100]
                          : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      member.isActive ? AppLocalizations.of(context)!.active : AppLocalizations.of(context)!.general_a9de8b69,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: member.isActive
                            ? Colors.green[800]
                            : Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${member.planName} (残り${member.remainingSessions}回)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                  if (daysSince != null)
                    Text(
                      '最終: $daysSince日前',
                      style: TextStyle(
                        fontSize: 12,
                        color: daysSince > 14 ? Colors.red : Colors.grey[700],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
