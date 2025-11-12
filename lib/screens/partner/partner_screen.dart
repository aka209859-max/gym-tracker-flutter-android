import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/partner_service.dart';
import '../../models/training_partner.dart';
import 'partner_detail_screen.dart';
import 'partner_profile_edit_screen.dart';
import 'partner_requests_screen.dart';

/// トレーニングパートナー画面
class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  final PartnerService _partnerService = PartnerService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  String? _selectedExperienceLevel;
  Position? _currentPosition;
  int _selectedTabIndex = 0; // 0: 検索, 1: マイパートナー

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _partnerService.updateLastActive();
  }

  /// 現在位置を取得
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      // 位置情報が取得できない場合はスキップ
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'トレーニングパートナー',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        actions: [
          // プロフィール編集
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PartnerProfileEditScreen(),
                ),
              );
            },
          ),
          // リクエスト一覧
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PartnerRequestsScreen(),
                    ),
                  );
                },
              ),
              // 未読バッジ
              StreamBuilder<List<PartnerRequest>>(
                stream: _partnerService.getReceivedRequests(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  if (count == 0) return const SizedBox.shrink();

                  return Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        count > 9 ? '9+' : count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Theme.of(context).colorScheme.primary,
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'パートナーを探す',
                    icon: Icons.search,
                    isSelected: _selectedTabIndex == 0,
                    onTap: () => setState(() => _selectedTabIndex = 0),
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    label: 'マイパートナー',
                    icon: Icons.people,
                    isSelected: _selectedTabIndex == 1,
                    onTap: () => setState(() => _selectedTabIndex = 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _selectedTabIndex == 0 ? _buildSearchTab() : _buildMyPartnersTab(),
    );
  }

  /// タブボタン
  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// パートナー検索タブ
  Widget _buildSearchTab() {
    return Column(
      children: [
        // フィルター
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 20, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedExperienceLevel,
                  decoration: const InputDecoration(
                    labelText: '経験レベル',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('すべて')),
                    DropdownMenuItem(value: 'beginner', child: Text('初心者')),
                    DropdownMenuItem(value: 'intermediate', child: Text('中級者')),
                    DropdownMenuItem(value: 'advanced', child: Text('上級者')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedExperienceLevel = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // パートナー一覧
        Expanded(
          child: StreamBuilder<List<TrainingPartner>>(
            stream: _partnerService.searchPartners(
              experienceLevel: _selectedExperienceLevel,
              userLat: _currentPosition?.latitude,
              userLon: _currentPosition?.longitude,
              maxDistanceKm: 50,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('エラーが発生しました', style: TextStyle(color: Colors.grey[600])),
                );
              }

              final partners = snapshot.data ?? [];

              if (partners.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'パートナーが見つかりませんでした',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: partners.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final partner = partners[index];
                  final distance = partner.distanceFrom(
                    _currentPosition?.latitude,
                    _currentPosition?.longitude,
                  );

                  return _buildPartnerCard(partner, distance);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// マイパートナータブ
  Widget _buildMyPartnersTab() {
    return StreamBuilder<List<TrainingPartner>>(
      stream: _partnerService.getAcceptedPartners(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('エラーが発生しました', style: TextStyle(color: Colors.grey[600])),
          );
        }

        final partners = snapshot.data ?? [];

        if (partners.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'まだパートナーがいません',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'パートナーを探してリクエストを送りましょう',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: partners.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final partner = partners[index];
            final distance = partner.distanceFrom(
              _currentPosition?.latitude,
              _currentPosition?.longitude,
            );

            return _buildPartnerCard(partner, distance, isMyPartner: true);
          },
        );
      },
    );
  }

  /// パートナーカード
  Widget _buildPartnerCard(TrainingPartner partner, double? distance, {bool isMyPartner = false}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PartnerDetailScreen(
                partner: partner,
                distance: distance,
                isMyPartner: isMyPartner,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // プロフィール画像
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.grey[300],
                backgroundImage: partner.photoUrl.isNotEmpty
                    ? NetworkImage(partner.photoUrl)
                    : null,
                child: partner.photoUrl.isEmpty
                    ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                    : null,
              ),
              const SizedBox(width: 16),

              // 情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            partner.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMyPartner)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'パートナー',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      partner.experienceLevelText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (distance != null) ...[
                          Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (partner.gymName != null) ...[
                          Icon(Icons.fitness_center, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              partner.gymName!,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
