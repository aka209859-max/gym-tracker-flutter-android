import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/training_partner.dart';
import '../services/training_partner_service.dart';
import '../services/subscription_service.dart';

/// プロフィール編集画面（Pro以上限定）
class ProfileEditScreen extends StatefulWidget {
  final TrainingPartner? currentProfile;

  const ProfileEditScreen({super.key, this.currentProfile});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _trainingPartnerService = TrainingPartnerService();
  final _subscriptionService = SubscriptionService();

  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  String? _selectedLocation;
  Uint8List? _selectedImageBytes;
  String? _currentImageUrl;
  bool _isLoading = false;
  bool _isPickingImage = false; // 画像選択中フラグ

  // 都道府県リスト
  static const List<String> _prefectures = [
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

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  void _initializeProfile() {
    if (widget.currentProfile != null) {
      _displayNameController.text = widget.currentProfile!.displayName;
      _bioController.text = widget.currentProfile!.bio ?? '';
      _selectedLocation = widget.currentProfile!.location;
      _currentImageUrl = widget.currentProfile!.profileImageUrl;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// 画像選択（安定化版）
  Future<void> _pickImage() async {
    // 既に画像選択中の場合は処理をスキップ（連続タップ防止）
    if (_isPickingImage) {
      debugPrint('⚠️ 既に画像選択処理中です');
      return;
    }

    // 画像選択開始フラグを立てる
    if (mounted) {
      setState(() {
        _isPickingImage = true;
      });
    }

    if (kIsWeb) {
      debugPrint('🖼️ [Web] 画像選択を開始');
    }
    
    try {
      final picker = ImagePicker();
      
      // ギャラリーから選択
      debugPrint('📱 ImagePicker.pickImage() 呼び出し中...');
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      // ユーザーがキャンセルした場合
      if (pickedFile == null) {
        debugPrint('ℹ️ 画像選択がキャンセルされました');
        if (mounted) {
          setState(() {
            _isPickingImage = false;
          });
        }
        return;
      }

      // 画像選択成功
      debugPrint('📸 画像選択成功: ${pickedFile.name}');
      debugPrint('📏 ファイルパス: ${pickedFile.path}');
      
      // バイト配列読み込み（この部分で時間がかかる可能性あり）
      debugPrint('💾 バイト配列読み込み中...');
      final bytes = await pickedFile.readAsBytes();
      debugPrint('✅ 画像読み込み完了: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(2)} KB)');
      
      // UI更新
      if (mounted) {
        setState(() {
          _selectedImageBytes = bytes;
          _isPickingImage = false;
        });
        debugPrint('✅ UI更新完了');
        
        // 成功フィードバック
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('画像を選択しました'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        debugPrint('⚠️ 警告: 画面が既に破棄されています');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 画像選択エラー: $e');
      debugPrint('📋 スタックトレース: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
        
        // エラーの詳細をユーザーに表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像の読み込みに失敗しました\n$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '再試行',
              textColor: Colors.white,
              onPressed: _pickImage,
            ),
          ),
        );
      }
    } finally {
      // 確実にフラグをリセット
      if (mounted && _isPickingImage) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  /// 保存処理
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ 本番実装：Proプラン権限チェック
    final currentPlan = await _subscriptionService.getCurrentPlan();
    if (currentPlan != SubscriptionType.pro) {
      _showUpgradeDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl = _currentImageUrl;

      // 画像がアップロードされている場合
      if (_selectedImageBytes != null) {
        imageUrl = await _trainingPartnerService.uploadProfileImage(_selectedImageBytes!);
      }

      // プロフィール作成
      final profile = TrainingPartner(
        userId: '', // サービス側で設定
        displayName: _displayNameController.text.trim(),
        profileImageUrl: imageUrl,
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        location: _selectedLocation,
        experienceLevel: null,
        goals: [],
        preferredExercises: [],
        createdAt: widget.currentProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _trainingPartnerService.saveProfile(profile);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プロフィールを保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Pro アップグレードダイアログ
  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.diamond, color: Colors.amber),
            SizedBox(width: 8),
            Text('Proプラン限定機能'),
          ],
        ),
        content: const Text(
          'プロフィール編集機能はProプラン限定です。\n'
          'Proプランにアップグレードしてご利用ください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // サブスクリプション画面へ遷移（実装済みと仮定）
            },
            child: const Text('Proプランを見る'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール編集'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveProfile,
              child: const Text('完了', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // プロフィール画像
                    GestureDetector(
                      onTap: _isPickingImage ? null : _pickImage, // 画像選択中は無効化
                      child: Stack(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: _selectedImageBytes != null
                                    ? MemoryImage(_selectedImageBytes!)
                                    : (_currentImageUrl != null
                                        ? NetworkImage(_currentImageUrl!)
                                        : null) as ImageProvider?,
                                child: _selectedImageBytes == null && _currentImageUrl == null
                                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                                    : null,
                              ),
                              // 画像選択中のローディング表示
                              if (_isPickingImage)
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'タップして画像を変更',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),

                    // アカウント名
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'アカウント名 *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'アカウント名を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 居住地
                    DropdownButtonFormField<String>(
                      value: _selectedLocation,
                      decoration: const InputDecoration(
                        labelText: '居住地',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      items: _prefectures
                          .map((prefecture) => DropdownMenuItem(
                                value: prefecture,
                                child: Text(prefecture),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLocation = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // 自己紹介
                    TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        labelText: '自己紹介（150文字以内）',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.edit),
                        helperText: '残り${150 - _bioController.text.length}文字',
                      ),
                      maxLines: 5,
                      maxLength: 150,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 24),

                    // 注意事項
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'プロフィール情報は他のユーザーに公開されます',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
