import 'package:flutter/material.dart';
import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:gym_match/gen/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gym_match/gen/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../models/gym.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../models/gym_announcement.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../models/review.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../services/realtime_user_service.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../services/favorites_service.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../services/share_service.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../services/visit_history_service.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../services/crowd_level_service.dart';
import 'package:gym_match/gen/app_localizations.dart';
import 'crowd_report_screen.dart';
import 'package:gym_match/gen/app_localizations.dart';
import 'reservation_form_screen.dart';
import 'package:gym_match/gen/app_localizations.dart';
import 'gym_review_screen.dart';
import 'package:gym_match/gen/app_localizations.dart';

/// ジム詳細画面
class GymDetailScreen extends StatefulWidget {
  final Gym gym;

  const GymDetailScreen({super.key, required this.gym});

  @override
  State<GymDetailScreen> createState() => _GymDetailScreenState();
}

class _GymDetailScreenState extends State<GymDetailScreen> {
  final RealtimeUserService _userService = RealtimeUserService();
  final FavoritesService _favoritesService = FavoritesService();
  final ShareService _shareService = ShareService();
  final VisitHistoryService _visitHistoryService = VisitHistoryService();
  final CrowdLevelService _crowdLevelService = CrowdLevelService();
  bool _isCheckedIn = false;
  bool? _isFavorite; // null = ロード中、true/false = 確定
  int? _currentCrowdLevel; // Google Places API混雑度

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
    _checkFavoriteStatus();
    _loadCrowdLevel();
  }

  /// 混雑度を読み込む（ユーザー報告 → キャッシュ → Google API）
  Future<void> _loadCrowdLevel() async {
    if (kDebugMode) {
      print('🔄 _loadCrowdLevel() called for gym: ${widget.gym.name}');
      print('   Gym ID: ${widget.gym.id}');
      print('   Current crowd level in gym object: ${widget.gym.currentCrowdLevel}');
      print('   Last update: ${widget.gym.lastCrowdUpdate}');
    }
    
    final level = await _crowdLevelService.getCrowdLevel(
      gymId: widget.gym.id,
      placeId: widget.gym.id, // Google Places IDを使用
    );
    
    if (kDebugMode) {
      print('   Result from CrowdLevelService: $level');
    }
    
    if (mounted && level != null) {
      setState(() {
        _currentCrowdLevel = level;
      });
      
      if (kDebugMode) {
        print('   ✅ Updated _currentCrowdLevel to: $level');
      }
    } else if (kDebugMode) {
      print('   ⚠️ No crowd level data available');
    }
  }

  Future<void> _checkUserStatus() async {
    try {
      final isCheckedIn = await _userService.isUserCheckedIn(widget.gym.id);
      if (mounted) {
        setState(() {
          _isCheckedIn = isCheckedIn;
        });
      }
    } catch (e) {
      // Firebase未設定時はデモモード
      if (mounted) {
        setState(() {
          _isCheckedIn = false;
        });
      }
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final isFavorite = await _favoritesService.isFavorite(widget.gym.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite == true) {
      // お気に入りから削除
      final success = await _favoritesService.removeFavorite(widget.gym.id);
      if (success && mounted) {
        setState(() {
          _isFavorite = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.removedFromFavorites),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } else {
      // お気に入りに追加
      final success = await _favoritesService.addFavorite(widget.gym);
      if (success && mounted) {
        setState(() {
          _isFavorite = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.addedToFavorites),
            backgroundColor: Colors.pink,
          ),
        );
      }
    }
  }

  /// チェックイン機能
  Future<void> _checkInToGym() async {
    final success = await _visitHistoryService.checkIn(widget.gym);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${widget.gym.name}にチェックインしました'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.checkInFailed),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ヘッダー画像
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.blue[900],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.gym.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
                    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 0)),
                  ],
                ),
              ),
              centerTitle: false,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.gym.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // 画像読み込み失敗時は濃い青色の背景のみ表示（店舗名を邪魔しない）
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue[800]!,
                              Colors.blue[900]!,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(context)!.gym_b8b06afd,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // グラデーションオーバーレイ（テキスト視認性向上）
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // コンテンツ
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // パートナーバッジ + キャンペーン情報（最優先表示）
                  if (widget.gym.isPartner) ...[
                    _buildPartnerCampaignCard(),
                    const SizedBox(height: 16),
                  ],
                  // ビジター予約ボタン（パートナー店舗のみ）
                  if (widget.gym.isPartner && widget.gym.acceptsVisitors) ...[
                    _buildReservationButton(),
                    const SizedBox(height: 16),
                  ],
                  // 基本情報
                  _buildInfoSection(),
                  const SizedBox(height: 16),
                  // アクションボタン（電話・地図）
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                  // 混雑度カード（2番目に表示）
                  _buildCrowdCard(),
                  const SizedBox(height: 16),
                  // お知らせセクション（設備と混雑の間）
                  _buildAnnouncementsSection(),
                  const SizedBox(height: 16),
                  // 設備情報
                  _buildFacilitiesSection(),
                  const SizedBox(height: 24),
                  // レビューセクション（プレースホルダー）
                  _buildReviewsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isFavorite == null ? null : _toggleFavorite,
        backgroundColor: _isFavorite == true ? Colors.pink : Colors.grey[300],
        foregroundColor: _isFavorite == true ? Colors.white : Colors.grey[700],
        icon: Icon(_isFavorite == true ? Icons.favorite : Icons.favorite_border),
        label: Text(_isFavorite == true ? AppLocalizations.of(context)!.alreadyFavorite : _isFavorite == null ? AppLocalizations.of(context)!.loadingWorkouts : AppLocalizations.of(context)!.addToFavorites),
      ),
    );
  }

  Widget _buildCrowdCard() {
    final gym = widget.gym;
    
    // 混雑度の優先順位: ユーザー報告 > Google API > データなし
    int? displayLevel;
    String? dataSource;
    
    if (kDebugMode) {
      print('📊 _buildCrowdCard() called');
      print('   gym.currentCrowdLevel: ${gym.currentCrowdLevel}');
      print('   gym.lastCrowdUpdate: ${gym.lastCrowdUpdate}');
      print('   _currentCrowdLevel: $_currentCrowdLevel');
    }
    
    // ユーザー報告があり、24時間以内ならそれを使用
    if (gym.currentCrowdLevel > 0 && gym.lastCrowdUpdate != null) {
      final updateTime = gym.lastCrowdUpdate!;
      final difference = DateTime.now().difference(updateTime);
      
      if (kDebugMode) {
        print('   User report age: ${difference.inHours} hours');
      }
      
      if (difference.inHours < 24) {
        displayLevel = gym.currentCrowdLevel;
        dataSource = AppLocalizations.of(context)!.userReport;
        
        if (kDebugMode) {
          print('   ✅ Using user report: level $displayLevel');
        }
      }
    }
    
    // ユーザー報告がなければGoogle APIデータを使用
    if (displayLevel == null && _currentCrowdLevel != null) {
      displayLevel = _currentCrowdLevel;
      dataSource = AppLocalizations.of(context)!.googleStats;
      
      if (kDebugMode) {
        print('   ✅ Using Google API data: level $displayLevel');
      }
    }
    
    if (kDebugMode && displayLevel == null) {
      print('   ⚠️ No crowd data to display - showing report prompt');
    }
    
    // 混雑度データが無い場合：報告ボタンのみ表示
    if (displayLevel == null) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: const [
                  Icon(Icons.people, color: Colors.grey, size: 24),
                  SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.gym_7770984f,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Icon(Icons.help_outline, size: 48, color: Colors.grey[400]),
                    SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.noCrowdData,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.gym_923e40e1,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CrowdReportScreen(gym: widget.gym),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: Text(AppLocalizations.of(context)!.gym_29c93cdb),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 混雑度データがある場合：通常の混雑度カード
    final minutesAgo = gym.lastCrowdUpdate != null
        ? DateTime.now().difference(gym.lastCrowdUpdate!).inMinutes
        : null;
    
    // 混雑度レベルに応じた色とテキストを取得
    final crowdColor = _getCrowdLevelColor(displayLevel!);
    final crowdText = _getCrowdLevelText(displayLevel!);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  AppLocalizations.of(context)!.gym_dc16fe89,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (minutesAgo != null)
                      Text(
                        '$minutesAgo分前更新',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    if (dataSource != null)
                      Text(
                        '($dataSource)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: crowdColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: crowdColor,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people,
                        size: 32,
                        color: crowdColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        crowdText,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: crowdColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CrowdReportScreen(gym: widget.gym),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: Text(AppLocalizations.of(context)!.gym_29c93cdb),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final gym = widget.gym;
    return Card(
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.info, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.gym_0179630e,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(thickness: 2),
            _buildInfoRow(Icons.star, AppLocalizations.of(context)!.rating, '${gym.rating} (${gym.reviewCount}件)'),
            _buildInfoRow(Icons.location_on, AppLocalizations.of(context)!.gymAddress, gym.address),
            if (gym.phoneNumber.isNotEmpty)
              _buildInfoRow(Icons.phone, AppLocalizations.of(context)!.gymPhone, gym.phoneNumber),
            _buildInfoRow(Icons.access_time, AppLocalizations.of(context)!.hours, gym.openingHours),
            const SizedBox(height: 8),
            // 月額料金は公式サイトで確認
            _buildInfoNotice(
              Icons.open_in_new,
              AppLocalizations.of(context)!.gym_a44956f8,
              AppLocalizations.of(context)!.gym_e83fdce4,
            ),
            const SizedBox(height: 16),
            // チェックインボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checkInToGym,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(AppLocalizations.of(context)!.gym_5c490300),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    // 住所と電話番号を強調表示
    final isImportant = icon == Icons.location_on || icon == Icons.phone;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon, 
            size: isImportant ? 24 : 20, 
            color: isImportant ? Colors.red : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isImportant ? 16 : 14,
                    fontWeight: isImportant ? FontWeight.bold : FontWeight.normal,
                    color: isImportant ? Colors.black87 : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNotice(IconData icon, String label, String notice) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notice,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitiesSection() {
    final gym = widget.gym;
    
    // パートナージムで設備情報がある場合のみ表示（isPartnerがfalseの場合は常に非表示）
    if (!gym.isPartner) {
      return const SizedBox.shrink();
    }
    
    // パートナージムで設備情報がある場合は表示
    if (gym.equipment != null && gym.equipment!.isNotEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    AppLocalizations.of(context)!.gym_2689426f,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                          AppLocalizations.of(context)!.ownerProvided,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: gym.equipment!.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fitness_center, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Text(
                          '${entry.key} × ${entry.value}台',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }
    
    // パートナージムで設備情報がない場合は非表示
    return const SizedBox.shrink();
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // チェックイン/チェックアウトボタン
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                if (_isCheckedIn) {
                  // チェックアウト
                  await _userService.checkOutFromGym(widget.gym.id);
                  if (mounted) {
                    setState(() {
                      _isCheckedIn = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.checkedOut)),
                    );
                  }
                } else {
                  // チェックイン
                  await _userService.checkInToGym(widget.gym.id);
                  if (mounted) {
                    setState(() {
                      _isCheckedIn = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.checkedIn)),
                    );
                  }
                }
              } catch (e) {
                // Firebase未設定時のエラーハンドリング
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(AppLocalizations.of(context)!.gym_b439391c),
                      content: const Text(
                        'チェックイン機能を使用するには、Firebase Consoleで設定ファイルを取得し、firebase_options.dartを更新してください。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppLocalizations.of(context)!.gym_95877b1f),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            icon: Icon(_isCheckedIn ? Icons.logout : Icons.login),
            label: Text(_isCheckedIn ? AppLocalizations.of(context)!.checkOut : AppLocalizations.of(context)!.checkIn),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isCheckedIn
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // シェアボタン
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _shareGym,
            icon: Icon(Icons.share),
            label: Text(AppLocalizations.of(context)!.shareGym),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.blue[600]!),
              foregroundColor: Colors.blue[600],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // レビュー投稿ボタン（Premium/Pro限定）
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GymReviewScreen(gym: widget.gym),
                ),
              );
              // レビュー投稿成功時にページを更新
              if (result == true && mounted) {
                setState(() {});
              }
            },
            icon: Icon(Icons.rate_review),
            label: Text(AppLocalizations.of(context)!.postReview),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openGoogleMapsRoute,
                icon: Icon(Icons.directions),
                label: Text(AppLocalizations.of(context)!.routeGuidance),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isFavorite == null ? null : _toggleFavorite,
                icon: Icon(_isFavorite == true ? Icons.favorite : Icons.favorite_border),
                label: Text(_isFavorite == true ? AppLocalizations.of(context)!.gym_c4a78c77 : AppLocalizations.of(context)!.favorite),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isFavorite == true ? Colors.pink : null,
                  side: BorderSide(
                    color: _isFavorite == true ? Colors.pink : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ジムをシェアする
  Future<void> _shareGym() async {
    try {
      final gym = widget.gym;
      
      // トレーニング報告用のシンプルなツイート文
      final tweetText = '''📍 ${gym.name}

⭐ ${gym.rating.toStringAsFixed(1)}/5.0 (${gym.reviewCount}件のレビュー)
📍 ${gym.address}

#筋トレ''';

      // テキストのみシェア
      await _shareService.shareText(
        tweetText,
        subject: 'GYM MATCH - ${gym.name}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.shared),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('シェアに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildReviewsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                          AppLocalizations.of(context)!.review,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: レビュー一覧画面への遷移
                  },
                  child: Text(AppLocalizations.of(context)!.viewAll),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            // レビュー投稿ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GymReviewScreen(gym: widget.gym),
                    ),
                  );
                  if (result == true && mounted) {
                    setState(() {}); // レビュー投稿後に画面を更新
                  }
                },
                icon: Icon(Icons.rate_review),
                label: Text(AppLocalizations.of(context)!.postReview),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Firestoreからレビューを表示
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('gymId', isEqualTo: widget.gym.gymId ?? widget.gym.id)
                  .orderBy('createdAt', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        AppLocalizations.of(context)!.loadReviewsFailed,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'まだレビューがありません\n最初のレビューを投稿してください！',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }
                
                // レビューを表示
                final reviews = snapshot.data!.docs;
                return Column(
                  children: reviews.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final userName = data['userName'] ?? AppLocalizations.of(context)!.gym_d2109d2d;
                    final overallRating = (data['overallRating'] ?? 0).toDouble();
                    final comment = data['comment'] ?? '';
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: Text(
                                  userName[0].toUpperCase(),
                                  style: TextStyle(color: Colors.blue[700]),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        ...List.generate(5, (index) {
                                          return Icon(
                                            index < overallRating
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 16,
                                            color: Colors.amber,
                                          );
                                        }),
                                        const SizedBox(width: 8),
                                        if (createdAt != null)
                                          Text(
                                            '${createdAt.year}/${createdAt.month}/${createdAt.day}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              comment,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// パートナーキャンペーンカード
  Widget _buildPartnerCampaignCard() {
    final gym = widget.gym;
    
    return Card(
      elevation: 4,
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // パートナーバッジ
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber[700],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.gym_45a96aae,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.partnerGym,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            // 基本特典
            if (gym.partnerBenefit != null && gym.partnerBenefit!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_offer, size: 20, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        gym.partnerBenefit!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // キャンペーンバナー
            if (gym.campaignBannerUrl != null && gym.campaignBannerUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  gym.campaignBannerUrl!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image, size: 48, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            // キャンペーン情報
            if (gym.campaignTitle != null && gym.campaignTitle!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.campaign, size: 20, color: Colors.amber[900]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      gym.campaignTitle!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            if (gym.campaignDescription != null && gym.campaignDescription!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                gym.campaignDescription!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
            ],
            
            // キャンペーン期限
            if (gym.campaignValidUntil != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.red[700]),
                  const SizedBox(width: 4),
                  Text(
                    '${gym.campaignValidUntil!.year}/${gym.campaignValidUntil!.month}/${gym.campaignValidUntil!.day}まで',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            
            // クーポンコード
            if (gym.campaignCouponCode != null && gym.campaignCouponCode!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[700]!, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.confirmation_number, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Text(
                      'クーポン: ${gym.campaignCouponCode!}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.amber[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ビジター予約ボタン（パートナー店舗のみ）
  Widget _buildReservationButton() {
    return Card(
      elevation: 4,
      color: Colors.orange[50],
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReservationFormScreen(gym: widget.gym),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[700],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.visitorBooking,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[600],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                          AppLocalizations.of(context)!.visitorWelcome,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.gym_6aaedfbd,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.orange[700],
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// お知らせセクション
  Widget _buildAnnouncementsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gym_announcements')
          .snapshots(),
      builder: (context, snapshot) {
        // エラーまたはデータなしの場合は非表示
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // データ取得成功
        final announcements = snapshot.data!.docs
            .map((doc) {
              try {
                return GymAnnouncement.fromFirestore(doc);
              } catch (e) {
                // パースエラーは無視して続行
                return null;
              }
            })
            .whereType<GymAnnouncement>()
            .where((announcement) {
              // このジムのお知らせのみ
              // 優先順位: gymId > Document IDで全パターンチェック
              final gymId = widget.gym.gymId;
              final docId = widget.gym.id;
              
              // gymIdがあればそれを使用、なければDocument IDで照合
              final matchesGymId = gymId != null && announcement.gymId == gymId;
              final matchesDocId = announcement.gymId == docId;
              
              final matchesGym = matchesGymId || matchesDocId;
              
              // 表示可能（有効期限内 & アクティブ）
              final isDisplayable = announcement.isDisplayable;
              return matchesGym && isDisplayable;
            })
            .toList();

        // メモリ内でソート（新しい順）
        announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // 最新5件のみ表示
        final displayAnnouncements = announcements.take(5).toList();

        // お知らせがない場合は非表示
        if (displayAnnouncements.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.campaign, color: Colors.orange[700]),
                    SizedBox(width: 8),
                    Text(
                          AppLocalizations.of(context)!.announcement,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...displayAnnouncements.map((announcement) => 
                  _buildAnnouncementCard(announcement)
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// お知らせカード
  Widget _buildAnnouncementCard(GymAnnouncement announcement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 画像（ある場合）
          if (announcement.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: Image.network(
                announcement.imageUrl!,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 48),
                    ),
                  );
                },
              ),
            ),
          // コンテンツ
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // タイプバッジ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getAnnouncementTypeColor(announcement.type).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${announcement.type.icon} ${announcement.type.displayName}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getAnnouncementTypeColor(announcement.type),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // タイトル
                Text(
                  announcement.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // 本文
                Text(
                  announcement.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                // クーポンコード（ある場合）
                if (announcement.couponCode != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.amber, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_offer, size: 16, color: Colors.amber[900]),
                        const SizedBox(width: 4),
                        Text(
                          'クーポンコード: ${announcement.couponCode}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // 有効期限（ある場合）
                if (announcement.validUntil != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '有効期限: ${_formatDate(announcement.validUntil!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// お知らせタイプの色
  Color _getAnnouncementTypeColor(AnnouncementType type) {
    switch (type) {
      case AnnouncementType.campaign:
        return Colors.pink;
      case AnnouncementType.event:
        return Colors.purple;
      case AnnouncementType.maintenance:
        return Colors.orange;
      case AnnouncementType.newEquipment:
        return Colors.green;
      case AnnouncementType.hours:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// 日付フォーマット
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  /// Googleマップでルート案内を開く
  Future<void> _openGoogleMapsRoute() async {
    final gym = widget.gym;
    // Googleマップアプリで経路案内を開く（目的地を指定）
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${gym.latitude},${gym.longitude}&travelmode=driving'
    );
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication, // 外部アプリで開く
        );
      } else {
        throw Exception(AppLocalizations.of(context)!.couldNotOpenMap);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 混雑度レベルに応じた色を取得
  Color _getCrowdLevelColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFF4CAF50); // 緑（空いています）
      case 2:
        return const Color(0xFF8BC34A); // 黄緑（やや空き）
      case 3:
        return const Color(0xFFFFC107); // 黄色（普通）
      case 4:
        return const Color(0xFFFF9800); // オレンジ（やや混雑）
      case 5:
        return const Color(0xFFF44336); // 赤（超混雑）
      default:
        return Colors.grey;
    }
  }

  /// 混雑度レベルに応じたテキストを取得
  String _getCrowdLevelText(int level) {
    switch (level) {
      case 1:
        return AppLocalizations.of(context)!.gym_e662330d;
      case 2:
        return AppLocalizations.of(context)!.moderatelyEmpty;
      case 3:
        return AppLocalizations.of(context)!.normal;
      case 4:
        return AppLocalizations.of(context)!.moderatelyCrowded;
      case 5:
        return AppLocalizations.of(context)!.gym_181af51b;
      default:
        return AppLocalizations.of(context)!.unknown;
    }
  }
}
