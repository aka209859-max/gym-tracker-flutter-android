import 'package:flutter/material.dart';
import '../../models/training_partner.dart';
import '../../services/training_partner_service.dart';
import '../../services/subscription_service.dart';
import 'partner_detail_screen.dart';

/// パートナー検索画面（実装版）
class PartnerSearchScreenNew extends StatefulWidget {
  const PartnerSearchScreenNew({super.key});

  @override
  State<PartnerSearchScreenNew> createState() => _PartnerSearchScreenNewState();
}

class _PartnerSearchScreenNewState extends State<PartnerSearchScreenNew> {
  final TrainingPartnerService _partnerService = TrainingPartnerService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  String _selectedLocation = 'すべて';
  String _selectedExperienceLevel = 'すべて';
  String _selectedGoal = 'すべて';
  
  bool _canAccess = false;
  bool _hasSearched = false; // 検索実行フラグ

  // 都道府県リスト
  static const List<String> _prefectures = [
    'すべて',
    '北海道',
    '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県',
    '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県',
    '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県',
    '岐阜県', '静岡県', '愛知県', '三重県',
    '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県',
    '鳥取県', '島根県', '岡山県', '広島県', '山口県',
    '徳島県', '香川県', '愛媛県', '高知県',
    '福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県',
    '沖縄県',
  ];

  static const List<String> _experienceLevels = [
    'すべて',
    '初心者',
    '中級者',
    '上級者',
  ];

  static const List<String> _goals = [
    'すべて',
    '筋肥大',
    '減量',
    'パワー向上',
    '健康維持',
    '体力向上',
  ];

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    // 🔓 テスト用：全ユーザーにアクセス許可
    setState(() {
      _canAccess = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ペイウォールを無効化
    // if (!_canAccess) {
    //   return _buildPaywall();
    // }

    return Scaffold(
      appBar: AppBar(
        title: const Text('パートナー検索'),
      ),
      body: Column(
        children: [
          // 検索フィルター
          _buildSearchFilters(),
          const Divider(height: 1),
          // 検索結果
          Expanded(
            child: _hasSearched ? _buildSearchResults() : _buildInitialState(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaywall() {
    return Scaffold(
      appBar: AppBar(title: const Text('パートナー検索')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.diamond, size: 80, color: Colors.amber),
            const SizedBox(height: 24),
            const Text(
              'パートナー検索機能',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Proプラン限定機能です',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/subscription');
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              ),
              child: const Text('Proプランを見る'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        children: [
          // 居住地フィルター
          DropdownButtonFormField<String>(
            value: _selectedLocation,
            decoration: const InputDecoration(
              labelText: '居住地',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.location_on),
            ),
            items: _prefectures
                .map((location) => DropdownMenuItem(
                      value: location,
                      child: Text(location),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedLocation = value ?? 'すべて';
              });
            },
          ),
          const SizedBox(height: 12),

          // 経験レベルフィルター
          DropdownButtonFormField<String>(
            value: _selectedExperienceLevel,
            decoration: const InputDecoration(
              labelText: '経験レベル',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.fitness_center),
            ),
            items: _experienceLevels
                .map((level) => DropdownMenuItem(
                      value: level,
                      child: Text(level),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedExperienceLevel = value ?? 'すべて';
              });
            },
          ),
          const SizedBox(height: 12),

          // 目標フィルター
          DropdownButtonFormField<String>(
            value: _selectedGoal,
            decoration: const InputDecoration(
              labelText: '目標',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.flag),
            ),
            items: _goals
                .map((goal) => DropdownMenuItem(
                      value: goal,
                      child: Text(goal),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedGoal = value ?? 'すべて';
              });
            },
          ),
          const SizedBox(height: 16),

          // 検索開始ボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasSearched = true;
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '検索開始',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '条件を選択して検索開始ボタンを押してください',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '居住地・経験レベル・目標で絞り込めます',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<List<TrainingPartner>>(
      stream: _partnerService.searchPartners(
        location: (_selectedLocation == 'すべて' || _selectedLocation.isEmpty) ? null : _selectedLocation,
        experienceLevel: (_selectedExperienceLevel == 'すべて' || _selectedExperienceLevel.isEmpty) ? null : _selectedExperienceLevel,
        goal: (_selectedGoal == 'すべて' || _selectedGoal.isEmpty) ? null : _selectedGoal,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('エラーが発生しました'),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasSearched = false;
                    });
                  },
                  child: const Text('戻る'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final partners = snapshot.data!;

        if (partners.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '該当するパートナーが見つかりませんでした',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  '検索条件を変更してみてください',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: partners.length,
          itemBuilder: (context, index) {
            return _buildPartnerCard(partners[index]);
          },
        );
      },
    );
  }

  Widget _buildPartnerCard(TrainingPartner partner) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PartnerDetailScreen(partner: partner),
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
                radius: 30,
                backgroundColor: Colors.grey[300],
                backgroundImage: partner.profileImageUrl != null
                    ? NetworkImage(partner.profileImageUrl!)
                    : null,
                child: partner.profileImageUrl == null
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),

              // プロフィール情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名前と居住地
                    Row(
                      children: [
                        Text(
                          partner.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (partner.location != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, size: 12, color: Colors.blue[700]),
                                const SizedBox(width: 2),
                                Text(
                                  partner.location!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 経験レベル
                    if (partner.experienceLevel != null)
                      Row(
                        children: [
                          Icon(Icons.fitness_center, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            partner.experienceLevel!,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),

                    // 目標
                    if (partner.goals.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: partner.goals.take(3).map((goal) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Text(
                              goal,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[800],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),

                    // 自己紹介（省略表示）
                    if (partner.bio != null && partner.bio!.isNotEmpty)
                      Text(
                        partner.bio!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // 矢印アイコン
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
