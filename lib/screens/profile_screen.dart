import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'favorites_screen.dart';
import 'subscription_screen.dart';
import 'body_measurement_screen.dart';
import 'visit_history_screen.dart';
import 'personal_training/pt_password_screen.dart';
import 'messages/messages_screen.dart';
import 'partner/partner_screen.dart';
import 'settings/notification_settings_screen.dart';
import 'settings/terms_of_service_screen.dart';
import 'settings/tokutei_shoutorihikihou_screen.dart';
import 'workout_import_preview_screen.dart';
import 'achievements_screen.dart';
import 'personal_factors_screen.dart';
import 'campaign/campaign_registration_screen.dart';
import 'ai_addon_purchase_screen.dart';
import 'profile_edit_screen.dart';
import 'redeem_invite_code_screen.dart';
import '../services/favorites_service.dart';
import '../services/subscription_service.dart';
import '../services/chat_service.dart';
import '../services/workout_import_service.dart';
import '../services/training_partner_service.dart';
import '../services/referral_service.dart';
import '../services/enhanced_share_service.dart';
import '../models/training_partner.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

/// プロフィール画面
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FavoritesService _favoritesService = FavoritesService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final ChatService _chatService = ChatService();
  final TrainingPartnerService _trainingPartnerService = TrainingPartnerService();
  final ReferralService _referralService = ReferralService();
  
  int _favoriteCount = 0;
  int _unreadMessages = 0;
  SubscriptionType _currentPlan = SubscriptionType.free;
  TrainingPartner? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _subscribeToUnreadMessages();
  }

  Future<void> _loadUserData() async {
    final favoriteCount = await _favoritesService.getFavoriteCount();
    final currentPlan = await _subscriptionService.getCurrentPlan();
    final userProfile = await _trainingPartnerService.getCurrentUserProfile();
    
    setState(() {
      _favoriteCount = favoriteCount;
      _currentPlan = currentPlan;
      _userProfile = userProfile;
    });
  }

  /// 未読メッセージ数を監視
  void _subscribeToUnreadMessages() {
    _chatService.getTotalUnreadCount().listen((count) {
      if (mounted) {
        setState(() {
          _unreadMessages = count;
        });
      }
    });
  }

  /// プロフィール編集画面へ遷移
  Future<void> _navigateToProfileEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(currentProfile: _userProfile),
      ),
    );
    
    if (result == true) {
      // プロフィール更新後、データを再読み込み
      _loadUserData();
    }
  }

  /// 写真・CSVから取り込み機能（ファイル種類選択）
  Future<void> _importWorkoutData() async {
    // ファイル種類選択ダイアログ
    final importType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upload_file, color: Colors.purple),
            SizedBox(width: 8),
            Text('データ取り込み'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'トレーニング記録をどの形式で取り込みますか？',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            // 写真から取り込み
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.photo_camera, color: Colors.white),
              ),
              title: const Text('📸 写真から取り込み'),
              subtitle: const Text(
                '他アプリのスクリーンショット',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            const Divider(),
            // CSVから取り込み
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.description, color: Colors.white),
              ),
              title: const Text('📄 CSVから取り込み'),
              subtitle: const Text(
                'CSV形式のファイル',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => Navigator.pop(context, 'csv'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );

    if (importType == null) return;

    // 選択された形式で取り込み実行
    if (importType == 'photo') {
      await _importFromPhoto();
    } else if (importType == 'csv') {
      await _importFromCSV();
    }
  }

  /// 写真から取り込み機能
  Future<void> _importFromPhoto() async {
    try {
      // 画像選択
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      // ローディング表示
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('画像を解析しています...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // 画像を読み込み
      final imageBytes = await image.readAsBytes();

      // Gemini APIで解析
      final extractedData = await WorkoutImportService.extractWorkoutFromImage(
        imageBytes,
      );

      // ローディングを閉じる
      if (mounted) {
        Navigator.of(context).pop();

        // プレビュー画面へ遷移
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutImportPreviewScreen(
              extractedData: extractedData,
            ),
          ),
        );
      }
    } catch (e) {
      // ローディングを閉じる
      if (mounted) {
        Navigator.of(context).pop();

        // エラーメッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 画像解析エラー: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// CSVから取り込み機能
  Future<void> _importFromCSV() async {
    try {
      // CSVファイル選択
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      
      // ファイルサイズチェック（5MB制限）
      if (file.size > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ ファイルサイズが大きすぎます（5MB以下）'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // ローディング表示
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('CSVファイルを解析しています...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // CSVファイルを読み込み
      String csvContent;
      if (file.bytes != null) {
        // Web: バイトデータから読み込み
        csvContent = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        // Mobile: ファイルパスから読み込み
        // Note: file_pickerはモバイルでもbytesを提供するため、通常このパスは使用されない
        throw Exception('ファイルの読み込みに失敗しました');
      } else {
        throw Exception('ファイルデータが取得できませんでした');
      }

      // CSV解析
      final extractedData = await WorkoutImportService.extractWorkoutFromCSV(
        csvContent,
      );

      // ローディングを閉じる
      if (mounted) {
        Navigator.of(context).pop();

        // プレビュー画面へ遷移
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutImportPreviewScreen(
              extractedData: extractedData,
            ),
          ),
        );
      }
    } catch (e) {
      // ローディングを閉じる
      if (mounted) {
        Navigator.of(context).pop();

        // エラーメッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ CSV解析エラー: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// 紹介コードダイアログを表示
  Future<void> _showReferralDialog() async {
    try {
      final referralCode = await _referralService.getReferralCode();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '友達を招待',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'あなたの紹介コード',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        referralCode,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.orange),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: referralCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ コードをコピーしました！'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'コピー',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '🎁 紹介特典',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildRewardItem('あなた', 'AI使用回数 +5回'),
              _buildRewardItem('友達', 'AI使用回数 +3回'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💡 友達がこのコードを入力すると、両方に特典が届きます！',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Clipboard.setData(ClipboardData(
                  text: 'GYM MATCHで一緒にトレーニングしませんか？\n\n'
                      '紹介コード: $referralCode\n'
                      'AI使用回数3回がもらえます！\n\n'
                      'https://gym-match-e560d.web.app',
                ));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ シェア用メッセージをコピーしました！'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('シェア'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ エラー: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRewardItem(String title, String reward) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.orange,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title: $reward',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsMenu(context),
            tooltip: '設定',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // プロフィールヘッダー
            _buildProfileHeader(context),
            const SizedBox(height: 24),
            // メニューリスト
            _buildMenuList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    // Production: Only Pro users can edit profile
    final bool isProUser = _currentPlan == SubscriptionType.pro;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // プロフィール画像 + 編集ボタン
            GestureDetector(
              onTap: isProUser ? _navigateToProfileEdit : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: _userProfile?.profileImageUrl != null
                        ? NetworkImage(_userProfile!.profileImageUrl!)
                        : null,
                    child: _userProfile?.profileImageUrl == null
                        ? Icon(
                            Icons.person,
                            size: 50,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                  if (isProUser)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: isProUser ? _navigateToProfileEdit : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _userProfile?.displayName ?? 'トレーニングユーザー',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (isProUser) const SizedBox(width: 8),
                  if (isProUser)
                    Icon(Icons.edit, size: 18, color: Colors.grey[600]),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _userProfile?.bio ?? 'GYM MATCHへようこそ',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            // プランバッジ（タップ可能）
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                ).then((_) => _loadUserData());
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _currentPlan == SubscriptionType.free
                      ? Colors.grey[300]
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _subscriptionService.getPlanName(_currentPlan),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _currentPlan == SubscriptionType.free
                            ? Colors.grey[700]
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: _currentPlan == SubscriptionType.free
                          ? Colors.grey[700]
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList(BuildContext context) {
    return Column(
      children: [
        // 📸 写真から取り込み（NEW!）
        Card(
          elevation: 2,
          color: Colors.purple[50],
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple[700],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_camera, color: Colors.white),
            ),
            title: const Text(
              '📸 写真・CSVから取り込み',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              '他アプリの記録画像・CSVファイルを自動データ化',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _importWorkoutData,
          ),
        ),
        const SizedBox(height: 12),
        // 🔬 個人要因設定（Phase 2b）
        Card(
          elevation: 2,
          color: Colors.blue[50],
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology, color: Colors.white),
            ),
            title: const Text(
              '🔬 個人要因設定',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              '年齢・経験・睡眠・栄養・アルコール（PFM補正）',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PersonalFactorsScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // パーソナルトレーニング
        Card(
          elevation: 2,
          color: Colors.orange[50],
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[700],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center, color: Colors.white),
            ),
            title: const Text(
              '💪 パーソナルトレーニング',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              '予約状況・トレーニング記録・予約申込',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PTPasswordScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // 💰 AI追加購入（有料プラン会員のみ表示）
        if (_currentPlan != SubscriptionType.free) ...[
          Card(
            elevation: 2,
            color: Colors.blue[50],
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              title: const Text(
                '💰 AI追加購入',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'AI機能をさらに5回追加（¥300）',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AIAddonPurchaseScreen()),
                ).then((_) => _loadUserData());
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        // デザインテーマ選択は削除（Energetic系に固定）
        _buildMenuCard(
          context,
          icon: Icons.favorite,
          title: 'お気に入りジム',
          subtitle: '$_favoriteCount件',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavoritesScreen()),
            ).then((_) => _loadUserData());
          },
        ),
        const SizedBox(height: 12),
        // 🏆 達成バッジ
        _buildMenuCard(
          context,
          icon: Icons.emoji_events,
          title: '達成バッジ',
          subtitle: 'あなたの実績を確認',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AchievementsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.monitor_weight,
          title: '体重・体脂肪率',
          subtitle: '身体の記録と管理',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BodyMeasurementScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.history,
          title: '訪問履歴',
          subtitle: '過去の訪問ジム',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VisitHistoryScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.people,
          title: 'トレーニングパートナー',
          subtitle: 'マッチング機能',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PartnerScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.message,
          title: 'メッセージ',
          subtitle: _unreadMessages > 0 ? '新着 $_unreadMessages 件' : '新着メッセージなし',
          badge: _unreadMessages > 0 ? '$_unreadMessages' : null,
          badgeColor: Colors.red,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MessagesScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.card_giftcard,
          title: '友達を招待',
          subtitle: 'AI x5回 + 紹介された人もAI x3回',
          badge: 'NEW',
          badgeColor: Colors.orange,
          onTap: () {
            _showReferralDialog();
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.notifications,
          title: '通知設定',
          subtitle: 'プッシュ通知・アラート',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          context,
          icon: Icons.card_giftcard,
          title: '招待コードを入力',
          subtitle: '招待コードで特典をGET',
          badge: '特典',
          badgeColor: Colors.amber,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RedeemInviteCodeScreen()),
            );
            
            if (result == true) {
              _loadUserData();
            }
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Row(
          children: [
            Text(title),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor?.withValues(alpha: 0.2) ?? 
                      (badge == '有料プラン' ? Colors.amber[100] : Colors.blue[100]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor ?? 
                        (badge == '有料プラン' ? Colors.amber[900] : Colors.blue[900]),
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Future<void> _checkPremiumFeature(BuildContext context, String featureName) async {
    final isPremium = await _subscriptionService.isPremiumFeatureAvailable();
    
    if (!isPremium) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.amber[700]),
              const SizedBox(width: 8),
              const Text('有料プラン限定機能'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$featureNameは有料プラン会員限定の機能です。',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                '有料プランに加入すると以下の機能が利用可能になります：',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              _buildFeatureItem('🤝 トレーニングパートナーマッチング'),
              _buildFeatureItem('💬 メッセージング機能'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Implement SubscriptionScreen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('プラン詳細画面は近日公開予定です')),
                );
                /*
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                ).then((_) => _loadUserData());
                */
              },
              child: const Text('プラン詳細を見る'),
            ),
          ],
        ),
      );
    } else {
      _showComingSoonDialog(context, featureName);
    }
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('近日公開'),
        content: Text(
          '$featureNameは現在開発中です。\n次回のアップデートでご利用いただけます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }

  /// 設定メニューを表示
  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.only(top: 20, bottom: 40),
          child: ListView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            children: [
            // ハンドル
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // タイトル
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.deepPurple.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    '設定メニュー',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            // メニュー項目1: トレーニングメモ
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.note_alt,
                  color: Colors.blue.shade700,
                ),
              ),
              title: const Text(
                'トレーニングメモ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text('過去のトレーニング記録を確認'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/workout-memo');
              },
            ),
            // メニュー項目2: 個人要因設定
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_outline,
                  color: Colors.purple.shade700,
                ),
              ),
              title: const Text(
                '個人要因設定',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text('年齢・経験・睡眠・栄養などを編集'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/personal-factors');
              },
            ),
            const Divider(height: 20),
            // 法的情報セクション
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                '法的情報',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            // メニュー項目3: 利用規約
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: Colors.blue.shade700,
                ),
              ),
              title: const Text(
                '利用規約',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text('サービス利用条件・サブスクリプション'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsOfServiceScreen(),
                  ),
                );
              },
            ),
            // メニュー項目4: 特定商取引法表記
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.gavel,
                  color: Colors.deepPurple.shade700,
                ),
              ),
              title: const Text(
                '特定商取引法に基づく表記',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text('販売事業者・返金ポリシー'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TokuteiShoutorihikihouScreen(),
                  ),
                );
              },
            ),
            // メニュー項目5: プライバシーポリシー
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  color: Colors.green.shade700,
                ),
              ),
              title: const Text(
                'プライバシーポリシー',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text('個人情報の取扱い'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                Navigator.of(context).pop();
                final url = Uri.parse('https://gym-match-e560d.web.app/privacy_policy.html');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('プライバシーポリシーを開けませんでした')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      ),
    );
  }
}
