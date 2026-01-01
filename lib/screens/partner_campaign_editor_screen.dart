import 'package:gym_match/gen/app_localizations.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// パートナーキャンペーン編集画面
class PartnerCampaignEditorScreen extends StatefulWidget {
  final String gymId;
  final String gymName;

  const PartnerCampaignEditorScreen({
    super.key,
    required this.gymId,
    required this.gymName,
  });

  @override
  State<PartnerCampaignEditorScreen> createState() =>
      _PartnerCampaignEditorScreenState();
}

class _PartnerCampaignEditorScreenState
    extends State<PartnerCampaignEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  // 編集フィールド
  final TextEditingController _benefitController = TextEditingController();
  final TextEditingController _campaignTitleController =
      TextEditingController();
  final TextEditingController _campaignDescController =
      TextEditingController();
  final TextEditingController _couponCodeController = TextEditingController();

  DateTime? _validUntil;
  File? _bannerImage;
  String? _currentBannerUrl;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  @override
  void dispose() {
    _benefitController.dispose();
    _campaignTitleController.dispose();
    _campaignDescController.dispose();
    _couponCodeController.dispose();
    super.dispose();
  }

  /// 現在のキャンペーン情報を読み込み
  Future<void> _loadCurrentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data == null) return;
        setState(() {
          _benefitController.text = data['partnerBenefit'] ?? '';
          _campaignTitleController.text = data['campaignTitle'] ?? '';
          _campaignDescController.text = data['campaignDescription'] ?? '';
          _couponCodeController.text = data['campaignCouponCode'] ?? '';
          _currentBannerUrl = data['campaignBannerUrl'];

          if (data['campaignValidUntil'] != null) {
            _validUntil = (data['campaignValidUntil'] as Timestamp).toDate();
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ データ読み込みエラー: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// バナー画像選択
  Future<void> _pickBannerImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _bannerImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像の読み込みに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// キャンペーン保存 (Firestore + Storage)
  Future<void> _saveCampaign() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? bannerUrl = _currentBannerUrl;

      // バナー画像をアップロード
      if (_bannerImage != null) {
        if (kDebugMode) {
          print('📤 バナー画像アップロード中...');
        }

        final ref = FirebaseStorage.instance.ref().child(
            'gyms/${widget.gymId}/campaigns/banner_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putFile(_bannerImage!);
        bannerUrl = await ref.getDownloadURL();

        if (kDebugMode) {
          print('✅ アップロード完了: $bannerUrl');
        }
      }

      // Firestoreに保存 (即座にユーザーアプリに反映)
      await FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .update({
        'partnerBenefit': _benefitController.text.trim(),
        'campaignTitle': _campaignTitleController.text.trim(),
        'campaignDescription': _campaignDescController.text.trim(),
        'campaignCouponCode': _couponCodeController.text.trim().toUpperCase(),
        'campaignValidUntil':
            _validUntil != null ? Timestamp.fromDate(_validUntil!) : null,
        'campaignBannerUrl': bannerUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ キャンペーン保存完了');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ キャンペーンを保存しました！ユーザーアプリに即反映されます'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // 保存後に画面を閉じる
        Navigator.pop(context);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存エラー: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 キャンペーン編集'),
        elevation: 2,
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveCampaign,
            tooltip: AppLocalizations.of(context)!.save,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // リアルタイムプレビュー
                  _buildPreviewCard(),
                  const SizedBox(height: 24),
                  const Divider(thickness: 2),
                  const SizedBox(height: 24),

                  // 基本特典
                  Text(
                    AppLocalizations.of(context)!.general_2c8755d8,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _benefitController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.general_3dc965c3,
                      hintText: AppLocalizations.of(context)!.gym_b6f4f89a,
                      helperText: AppLocalizations.of(context)!.searchGym,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_offer),
                    ),
                    maxLength: 50,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),

                  // キャンペーン情報
                  Text(
                    AppLocalizations.of(context)!.general_809889ae,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _campaignTitleController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.general_3dc93f95,
                      hintText: '🎉 春の入会キャンペーン開催中!',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.campaign),
                    ),
                    maxLength: 100,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _campaignDescController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.general_b4b2d8e1,
                      hintText:
                          '3月31日までの入会で入会金無料 + プロテイン1kg プレゼント!',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    maxLength: 500,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // 期限選択
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(AppLocalizations.of(context)!.general_1a095336),
                    subtitle: Text(
                      _validUntil != null
                          ? '${_validUntil!.year}年${_validUntil!.month}月${_validUntil!.day}日まで'
                          : AppLocalizations.of(context)!.gym_5d1d7a5c,
                    ),
                    trailing: _validUntil != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _validUntil = null;
                              });
                            },
                          )
                        : null,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _validUntil ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _validUntil = date;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _couponCodeController,
                    decoration: InputDecoration(
                      labelText: 'クーポンコード (任意)',
                      hintText: 'SPRING2024',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),

                  // キャンペーンバナー
                  Text(
                    AppLocalizations.of(context)!.general_cb4f1541,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_bannerImage != null || _currentBannerUrl != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _bannerImage != null
                              ? Image.file(
                                  _bannerImage!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  _currentBannerUrl!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _bannerImage = null;
                                _currentBannerUrl = null;
                              });
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _pickBannerImage,
                      icon: Icon(Icons.add_photo_alternate),
                      label: Text(AppLocalizations.of(context)!.addWorkout),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  const SizedBox(height: 32),

                  // 保存ボタン
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveCampaign,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '💾 保存して即反映',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  /// リアルタイムプレビューカード
  Widget _buildPreviewCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📱 ユーザー画面プレビュー',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // 基本特典バッジ
            if (_benefitController.text.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_offer,
                        size: 16, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _benefitController.text,
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // キャンペーンバナー
            if (_bannerImage != null || _currentBannerUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _bannerImage != null
                    ? Image.file(
                        _bannerImage!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        _currentBannerUrl!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: 12),
            ],

            // キャンペーンタイトル
            if (_campaignTitleController.text.isNotEmpty) ...[
              Text(
                _campaignTitleController.text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // キャンペーン詳細
            if (_campaignDescController.text.isNotEmpty) ...[
              Text(
                _campaignDescController.text,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
            ],

            // 期限表示
            if (_validUntil != null) ...[
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    '${_validUntil!.month}/${_validUntil!.day}まで',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // クーポンコード
            if (_couponCodeController.text.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  border: Border.all(
                    color: Colors.amber[700]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.confirmation_number,
                        color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Text(
                      'クーポン: ${_couponCodeController.text.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // プレビューが空の場合
            if (_benefitController.text.isEmpty &&
                _campaignTitleController.text.isEmpty &&
                _bannerImage == null &&
                _currentBannerUrl == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    '上記のフォームに入力すると\nここにプレビューが表示されます',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
