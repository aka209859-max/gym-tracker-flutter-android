import 'package:flutter/material.dart';
import '../../models/partner_profile.dart';
import '../../services/partner_search_service.dart';
import '../../services/location_service.dart';
import '../../services/subscription_service.dart';
import 'partner_profile_detail_screen.dart';
import 'partner_profile_edit_screen.dart';
import '../subscription_screen.dart';

/// パートナー検索画面（MVP）
/// 
/// 機能:
/// - パートナー検索フィルター（場所、目標、経験レベル）
/// - 検索結果一覧表示
/// - プロフィール詳細表示
/// - マッチングリクエスト送信
class PartnerSearchScreen extends StatefulWidget {
  const PartnerSearchScreen({super.key});

  @override
  State<PartnerSearchScreen> createState() => _PartnerSearchScreenState();
}

class _PartnerSearchScreenState extends State<PartnerSearchScreen> {
  final PartnerSearchService _searchService = PartnerSearchService();
  final LocationService _locationService = LocationService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  List<PartnerProfile> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  SubscriptionType _currentUserPlan = SubscriptionType.free;

  // 検索フィルター
  double? _currentLatitude;
  double? _currentLongitude;
  double _maxDistanceKm = 10.0;
  List<String> _selectedGoals = [];
  String? _selectedExperienceLevel;
  List<String> _selectedGenders = [];
  bool _enableStrengthFilter = false; // ✅ 実力フィルター（±15% 1RM）
  bool _enableSpatiotemporalFilter = false; // ✅ 時空間フィルター（同じジム・時間）

  // 利用可能なオプション
  final Map<String, String> _trainingGoals = {
    'muscle_gain': '筋力増強',
    'weight_loss': '減量',
    'endurance': '持久力向上',
    'flexibility': '柔軟性向上',
  };

  final Map<String, String> _experienceLevels = {
    'beginner': '初心者',
    'intermediate': '中級者',
    'advanced': '上級者',
    'expert': 'エキスパート',
  };

  final Map<String, String> _genders = {
    'male': '男性',
    'female': '女性',
    'other': 'その他',
  };

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadCurrentPlan();
  }
  
  Future<void> _loadCurrentPlan() async {
    final plan = await _subscriptionService.getCurrentPlan();
    if (mounted) {
      setState(() {
        _currentUserPlan = plan;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (mounted && position != null) {
        setState(() {
          _currentLatitude = position.latitude;
          _currentLongitude = position.longitude;
        });
      }
    } catch (e) {
      // 位置情報取得失敗時は続行（フィルターから距離を除外）
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置情報を取得できませんでした')),
        );
      }
    }
  }

  Future<void> _searchPartners() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final results = await _searchService.searchPartners(
        latitude: _currentLatitude,
        longitude: _currentLongitude,
        maxDistanceKm: _maxDistanceKm,
        trainingGoals: _selectedGoals.isEmpty ? null : _selectedGoals,
        experienceLevel: _selectedExperienceLevel,
        genders: _selectedGenders.isEmpty ? null : _selectedGenders,
        enableStrengthFilter: _enableStrengthFilter, // ✅ 実力フィルター
        enableSpatiotemporalFilter: _enableSpatiotemporalFilter, // ✅ 時空間フィルター
      );

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('パートナー検索'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _navigateToProfileEdit,
            tooltip: 'プロフィール編集',
          ),
        ],
      ),
      body: Column(
        children: [
          // 検索フィルター
          _buildSearchFilters(),
          
          // 検索結果
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '検索条件',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 距離フィルター
            if (_currentLatitude != null && _currentLongitude != null) ...[
              Text('検索範囲: ${_maxDistanceKm.toStringAsFixed(1)} km'),
              Slider(
                value: _maxDistanceKm,
                min: 1.0,
                max: 50.0,
                divisions: 49,
                label: '${_maxDistanceKm.toStringAsFixed(1)} km',
                onChanged: (value) {
                  setState(() {
                    _maxDistanceKm = value;
                  });
                },
              ),
              const SizedBox(height: 8),
            ],

            // トレーニング目標フィルター
            const Text('トレーニング目標', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _trainingGoals.entries.map((entry) {
                final isSelected = _selectedGoals.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedGoals.add(entry.key);
                      } else {
                        _selectedGoals.remove(entry.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 経験レベルフィルター
            const Text('経験レベル', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _experienceLevels.entries.map((entry) {
                final isSelected = _selectedExperienceLevel == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedExperienceLevel = selected ? entry.key : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 性別フィルター
            const Text('性別', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _genders.entries.map((entry) {
                final isSelected = _selectedGenders.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedGenders.add(entry.key);
                      } else {
                        _selectedGenders.remove(entry.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            
            // ✅ 実力ベースマッチング（±15% 1RM）
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.fitness_center, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text(
                        '実力が近い人のみ（±15% 1RM）',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enableStrengthFilter,
                  onChanged: (value) {
                    setState(() {
                      _enableStrengthFilter = value;
                    });
                  },
                ),
              ],
            ),
            if (_enableStrengthFilter)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'あなたのBIG3平均1RMの±15%範囲内のユーザーのみ表示',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 16),
            
            // ✅ 時空間コンテキストマッチング
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '同じジム・時間帯の人のみ（±2時間）',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enableSpatiotemporalFilter,
                  onChanged: (value) {
                    setState(() {
                      _enableSpatiotemporalFilter = value;
                    });
                  },
                ),
              ],
            ),
            if (_enableSpatiotemporalFilter)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'あなたがよく行くジムで、同じ時間帯（±2時間）にトレーニングする人のみ表示',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 16),

            // 検索ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _searchPartners,
                icon: const Icon(Icons.search),
                label: const Text('検索'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // ✅ Pro非対称可視性: Free/Premiumユーザーには説明バナーを表示
    final isNonProUser = _currentUserPlan != SubscriptionType.pro;
    final showProOnlyBanner = isNonProUser && _searchResults.isNotEmpty;

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'エラーが発生しました',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchPartners,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '条件を設定して検索してください',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '条件に一致するパートナーが見つかりませんでした',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '検索条件を変更してみてください',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: showProOnlyBanner ? _searchResults.length + 1 : _searchResults.length,
      itemBuilder: (context, index) {
        // ✅ 最初に説明バナーを表示
        if (showProOnlyBanner && index == 0) {
          return _buildProOnlyBanner();
        }
        
        final profileIndex = showProOnlyBanner ? index - 1 : index;
        final profile = _searchResults[profileIndex];
        return _buildPartnerCard(profile);
      },
    );
  }

  /// ✅ Pro非対称可視性: Free/Premiumユーザー向け説明バナー
  Widget _buildProOnlyBanner() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.amber[50],
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.workspace_premium, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Proユーザーのみ表示中',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Proプランにアップグレードで全ユーザーを検索可能',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.amber),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerCard(PartnerProfile profile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToProfileDetail(profile),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // プロフィール画像
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: profile.photoUrl != null
                        ? NetworkImage(profile.photoUrl!)
                        : null,
                    child: profile.photoUrl == null
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                  // ✅ Proバッジ（Free/Premium検索者にのみ表示）
                  if (_currentUserPlan != SubscriptionType.pro)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              
              // プロフィール情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${profile.age}歳',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _experienceLevels[profile.experienceLevel] ?? profile.experienceLevel,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        // ✅ 実力表示（平均1RM）
                        if (profile.average1RM != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fitness_center, size: 12, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  '${profile.average1RM!.toStringAsFixed(0)}kg',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: profile.trainingGoals
                          .where((goal) => goal != null && goal.isNotEmpty)
                          .take(3)
                          .map((goal) {
                        return Chip(
                          label: Text(
                            _trainingGoals[goal] ?? goal,
                            style: const TextStyle(fontSize: 12),
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              
              // レーティング
              Column(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  Text(
                    profile.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

  void _navigateToProfileDetail(PartnerProfile profile) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PartnerProfileDetailScreen(profile: profile),
        ),
      );
    } catch (e) {
      print('❌ プロフィール詳細画面へのナビゲーションエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToProfileEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PartnerProfileEditScreen(),
      ),
    );

    // プロフィール編集後、検索を再実行
    if (result == true && _hasSearched) {
      _searchPartners();
    }
  }
}
