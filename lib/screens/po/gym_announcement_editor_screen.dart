import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/gym_announcement.dart';

/// ジムお知らせ投稿画面（GYMMATCHManager用）
/// 
/// 機能:
/// - お知らせタイトル・本文入力
/// - 画像アップロード（Firebase Storage）
/// - お知らせタイプ選択
/// - クーポンコード設定
/// - 有効期限設定
class GymAnnouncementEditorScreen extends StatefulWidget {
  final String gymId;
  final GymAnnouncement? announcement; // 編集時は既存データ
  
  const GymAnnouncementEditorScreen({
    super.key,
    required this.gymId,
    this.announcement,
  });

  @override
  State<GymAnnouncementEditorScreen> createState() => _GymAnnouncementEditorScreenState();
}

class _GymAnnouncementEditorScreenState extends State<GymAnnouncementEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _couponCodeController = TextEditingController();
  
  AnnouncementType _selectedType = AnnouncementType.general;
  DateTime? _validUntil;
  String? _uploadedImageUrl;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    
    // 編集モードの場合、既存データを入力
    if (widget.announcement != null) {
      final ann = widget.announcement!;
      _titleController.text = ann.title;
      _contentController.text = ann.content;
      _couponCodeController.text = ann.couponCode ?? '';
      _selectedType = ann.type;
      _validUntil = ann.validUntil;
      _uploadedImageUrl = ann.imageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _couponCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploading = true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) {
        setState(() => _isUploading = false);
        return;
      }

      // Firebase Storageにアップロード
      final fileName = 'announcements/${widget.gymId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      
      await storageRef.putFile(File(image.path));
      final imageUrl = await storageRef.getDownloadURL();

      setState(() {
        _uploadedImageUrl = imageUrl;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('画像をアップロードしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像アップロードエラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveAnnouncement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final announcementData = {
        'gym_id': widget.gymId,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'image_url': _uploadedImageUrl,
        'type': _selectedType.toString().split('.').last,
        'created_at': FieldValue.serverTimestamp(),
        'valid_until': _validUntil != null
            ? Timestamp.fromDate(_validUntil!)
            : null,
        'is_active': true,
        'coupon_code': _couponCodeController.text.trim().isEmpty
            ? null
            : _couponCodeController.text.trim(),
      };

      if (widget.announcement == null) {
        // 新規投稿
        await FirebaseFirestore.instance
            .collection('gym_announcements')
            .add(announcementData);
      } else {
        // 更新
        await FirebaseFirestore.instance
            .collection('gym_announcements')
            .doc(widget.announcement!.id)
            .update(announcementData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('お知らせを保存しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.announcement == null ? 'お知らせ投稿' : 'お知らせ編集'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveAnnouncement,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('投稿'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // お知らせタイプ選択
              const Text(
                'お知らせタイプ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: AnnouncementType.values.map((type) {
                  return ChoiceChip(
                    label: Text('${type.icon} ${type.displayName}'),
                    selected: _selectedType == type,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedType = type;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              
              // タイトル入力
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  hintText: '例: 春の入会キャンペーン開催中',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'タイトルを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 本文入力
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '本文',
                  hintText: 'お知らせの詳細を入力してください',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '本文を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // クーポンコード（キャンペーンの場合）
              if (_selectedType == AnnouncementType.campaign)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _couponCodeController,
                      decoration: const InputDecoration(
                        labelText: 'クーポンコード（任意）',
                        hintText: '例: SPRING2024',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_offer),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              
              // 画像アップロード
              const Text(
                'お知らせ画像',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_uploadedImageUrl != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _uploadedImageUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _uploadedImageUrl = null;
                          });
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickAndUploadImage,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate),
                  label: Text(_isUploading ? 'アップロード中...' : '画像を選択'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              const SizedBox(height: 24),
              
              // 有効期限設定
              const Text(
                '有効期限',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _validUntil ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _validUntil = date;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _validUntil == null
                      ? '期限なし'
                      : '${_validUntil!.year}/${_validUntil!.month}/${_validUntil!.day}',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              if (_validUntil != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _validUntil = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('期限をクリア'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
