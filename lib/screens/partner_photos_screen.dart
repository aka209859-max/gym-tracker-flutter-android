import 'package:gym_match/gen/app_localizations.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// パートナー店舗画像管理画面
class PartnerPhotosScreen extends StatefulWidget {
  final String gymId;
  final String gymName;

  const PartnerPhotosScreen({
    super.key,
    required this.gymId,
    required this.gymName,
  });

  @override
  State<PartnerPhotosScreen> createState() => _PartnerPhotosScreenState();
}

class _PartnerPhotosScreenState extends State<PartnerPhotosScreen> {
  List<String> _photoUrls = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  /// 現在の店舗画像を読み込み
  Future<void> _loadPhotos() async {
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
          _photoUrls = data['photos'] != null
              ? List<String>.from(data['photos'])
              : [];
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 画像読み込みエラー: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 画像を選択してアップロード
  Future<void> _pickAndUploadPhotos() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      for (var image in images) {
        if (kDebugMode) {
          print('📤 画像アップロード中: ${image.name}');
        }

        // Firebase Storageにアップロード
        final ref = FirebaseStorage.instance.ref().child(
            'gyms/${widget.gymId}/photos/photo_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putFile(File(image.path));
        final url = await ref.getDownloadURL();

        // Firestoreに画像URLを追加
        await FirebaseFirestore.instance
            .collection('gyms')
            .doc(widget.gymId)
            .update({
          'photos': FieldValue.arrayUnion([url]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _photoUrls.add(url);
        });

        if (kDebugMode) {
          print('✅ アップロード完了: $url');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${images.length}枚の画像をアップロードしました！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ アップロードエラー: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ アップロード失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  /// 画像を削除
  Future<void> _deletePhoto(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.general_d069db16),
        content: Text(AppLocalizations.of(context)!.delete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Firestoreから画像URLを削除
      await FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .update({
        'photos': FieldValue.arrayRemove([url]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _photoUrls.remove(url);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.delete),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 削除エラー: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.delete),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.general_64cab206),
        elevation: 2,
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              onPressed: _pickAndUploadPhotos,
              tooltip: AppLocalizations.of(context)!.addWorkout,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photoUrls.isEmpty
              ? _buildEmptyState()
              : _buildPhotoGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.general_150daaa6,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '店舗の雰囲気やマシン・設備の写真を\nアップロードしましょう',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickAndUploadPhotos,
              icon: Icon(Icons.add_photo_alternate),
              label: Text(AppLocalizations.of(context)!.addWorkout),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Column(
      children: [
        // 画像枚数表示
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.emailNotRegistered,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadPhotos,
                icon: Icon(Icons.add),
                label: Text(AppLocalizations.of(context)!.add),
              ),
            ],
          ),
        ),

        // 画像グリッド
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _photoUrls.length,
            itemBuilder: (context, index) {
              return _buildPhotoCard(_photoUrls[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard(String url) {
    return GestureDetector(
      onTap: () => _showPhotoDetail(url),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                );
              },
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                onPressed: () => _deletePhoto(url),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoDetail(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
