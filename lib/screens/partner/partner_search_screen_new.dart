import 'package:gym_match/gen/app_localizations.dart';
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

  String _selectedLocation = AppLocalizations.of(context)!.all;
  String _selectedExperienceLevel = AppLocalizations.of(context)!.all;
  late String _selectedGoal;
  
  bool _canAccess = false;
  bool _hasSearched = false; // 検索実行フラグ

  // 都道府県リスト
  static const List<String> _prefectures = [
    AppLocalizations.of(context)!.all,
    AppLocalizations.of(context)!.profile_afa342b7,
    AppLocalizations.of(context)!.prefectureAomori, AppLocalizations.of(context)!.prefectureIwate, AppLocalizations.of(context)!.prefectureMiyagi, AppLocalizations.of(context)!.prefectureAkita, AppLocalizations.of(context)!.prefectureYamagata, AppLocalizations.of(context)!.prefectureFukushima,
    AppLocalizations.of(context)!.prefectureIbaraki, AppLocalizations.of(context)!.prefectureTochigi, AppLocalizations.of(context)!.prefectureGunma, AppLocalizations.of(context)!.prefectureSaitama, AppLocalizations.of(context)!.prefectureChiba, AppLocalizations.of(context)!.prefectureTokyo, AppLocalizations.of(context)!.prefectureKanagawa,
    AppLocalizations.of(context)!.prefectureNiigata, AppLocalizations.of(context)!.prefectureToyama, AppLocalizations.of(context)!.prefectureIshikawa, AppLocalizations.of(context)!.prefectureFukui, AppLocalizations.of(context)!.prefectureYamanashi, AppLocalizations.of(context)!.prefectureNagano,
    AppLocalizations.of(context)!.prefectureGifu, AppLocalizations.of(context)!.prefectureShizuoka, AppLocalizations.of(context)!.prefectureAichi, AppLocalizations.of(context)!.prefectureMie,
    AppLocalizations.of(context)!.prefectureShiga, AppLocalizations.of(context)!.prefectureKyoto, AppLocalizations.of(context)!.prefectureOsaka, AppLocalizations.of(context)!.prefectureHyogo, AppLocalizations.of(context)!.prefectureNara, AppLocalizations.of(context)!.prefectureWakayama,
    AppLocalizations.of(context)!.prefectureTottori, AppLocalizations.of(context)!.prefectureShimane, AppLocalizations.of(context)!.prefectureOkayama, AppLocalizations.of(context)!.prefectureHiroshima, AppLocalizations.of(context)!.prefectureYamaguchi,
    AppLocalizations.of(context)!.prefectureTokushima, AppLocalizations.of(context)!.prefectureKagawa, AppLocalizations.of(context)!.prefectureEhime, AppLocalizations.of(context)!.prefectureKochi,
    AppLocalizations.of(context)!.prefectureFukuoka, AppLocalizations.of(context)!.prefectureSaga, AppLocalizations.of(context)!.prefectureNagasaki, AppLocalizations.of(context)!.prefectureKumamoto, AppLocalizations.of(context)!.prefectureOita, AppLocalizations.of(context)!.prefectureMiyazaki, AppLocalizations.of(context)!.prefectureKagoshima,
    AppLocalizations.of(context)!.prefectureOkinawa,
  ];

  static const List<String> _experienceLevels = [
    AppLocalizations.of(context)!.all,
    AppLocalizations.of(context)!.levelBeginner,
    AppLocalizations.of(context)!.levelIntermediate,
    AppLocalizations.of(context)!.levelAdvanced,
  ];

  static const List<String> _goals = [
    AppLocalizations.of(context)!.all,
    AppLocalizations.of(context)!.goalMuscleGain,
    AppLocalizations.of(context)!.goalWeightLoss,
    AppLocalizations.of(context)!.general_8fdcc9c5,
    AppLocalizations.of(context)!.goalMaintenance,
    AppLocalizations.of(context)!.profile_64b9cf75,
  ];

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedGoal = AppLocalizations.of(context)!.filterAll;
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
        title: Text(AppLocalizations.of(context)!.partnerSearch),
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.partnerSearch)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.diamond, size: 80, color: Colors.amber),
            SizedBox(height: 24),
            Text(
                          AppLocalizations.of(context)!.searchGym,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              AppLocalizations.of(context)!.general_9eba2cc5,
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
              child: Text(AppLocalizations.of(context)!.viewProPlan),
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
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.residence,
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
                _selectedLocation = value ?? AppLocalizations.of(context)!.filterAll;
              });
            },
          ),
          const SizedBox(height: 12),

          // 経験レベルフィルター
          DropdownButtonFormField<String>(
            value: _selectedExperienceLevel,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.experienceLevel,
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
                _selectedExperienceLevel = value ?? AppLocalizations.of(context)!.filterAll;
              });
            },
          ),
          const SizedBox(height: 12),

          // 目標フィルター
          DropdownButtonFormField<String>(
            value: _selectedGoal,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.goal,
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
                _selectedGoal = value ?? AppLocalizations.of(context)!.filterAll;
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.searchGym,
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
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.selectExercise,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.general_4f03a19c,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<List<TrainingPartner>>(
      stream: _partnerService.searchPartners(
        location: (_selectedLocation == AppLocalizations.of(context)!.filterAll || _selectedLocation.isEmpty) ? null : _selectedLocation,
        experienceLevel: (_selectedExperienceLevel == AppLocalizations.of(context)!.filterAll || _selectedExperienceLevel.isEmpty) ? null : _selectedExperienceLevel,
        goal: (_selectedGoal == AppLocalizations.of(context)!.filterAll || _selectedGoal.isEmpty) ? null : _selectedGoal,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.errorGeneric),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasSearched = false;
                    });
                  },
                  child: Text(AppLocalizations.of(context)!.back),
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
                  AppLocalizations.of(context)!.general_c814cc13,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.searchConditions,
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
