import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/training_partner.dart';

/// トレーニングパートナーサービス
class TrainingPartnerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 現在のユーザーのプロフィールを取得
  Future<TrainingPartner?> getCurrentUserProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    final doc = await _firestore
        .collection('training_partners')
        .doc(userId)
        .get();

    if (!doc.exists) return null;
    
    final data = doc.data();
    if (data == null) return null;

    return TrainingPartner.fromFirestore(data);
  }

  /// プロフィールを作成・更新
  Future<void> saveProfile(TrainingPartner partner) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーが認証されていません');

    await _firestore
        .collection('training_partners')
        .doc(userId)
        .set(partner.toFirestore(), SetOptions(merge: true));
  }

  /// プロフィール画像をアップロード
  Future<String> uploadProfileImage(Uint8List imageBytes) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('ユーザーが認証されていません');

    final ref = _storage.ref().child('profile_images/$userId.jpg');
    
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'userId': userId},
    );

    await ref.putData(imageBytes, metadata);
    
    return await ref.getDownloadURL();
  }

  /// パートナー検索（フィルター付き）
  Stream<List<TrainingPartner>> searchPartners({
    String? location,
    String? experienceLevel,
    String? goal,
  }) {
    Query query = _firestore.collection('training_partners');

    // 居住地フィルター
    if (location != null && location != 'すべて') {
      query = query.where('location', isEqualTo: location);
    }

    // 経験レベルフィルター
    if (experienceLevel != null && experienceLevel != 'すべて') {
      query = query.where('experience_level', isEqualTo: experienceLevel);
    }

    return query.snapshots().map((snapshot) {
      var partners = snapshot.docs
          .map((doc) => TrainingPartner.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();

      // 目標フィルター（メモリ内でフィルタリング）
      if (goal != null && goal != 'すべて') {
        partners = partners.where((p) => p.goals.contains(goal)).toList();
      }

      // 自分を除外
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null) {
        partners = partners.where((p) => p.userId != currentUserId).toList();
      }

      return partners;
    });
  }

  /// パートナー詳細取得
  Future<TrainingPartner?> getPartnerById(String userId) async {
    final doc = await _firestore
        .collection('training_partners')
        .doc(userId)
        .get();

    if (!doc.exists) return null;
    
    final data = doc.data();
    if (data == null) return null;

    return TrainingPartner.fromFirestore(data);
  }

  /// ブロック済みユーザーリストを取得
  Future<List<String>> getBlockedUserIds() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    final snapshot = await _firestore
        .collection('user_blocks')
        .where('blocker_id', isEqualTo: currentUserId)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['blocked_id'] as String)
        .toList();
  }

  /// ユーザーをブロック
  Future<void> blockUser(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('ユーザーが認証されていません');

    // ブロック情報を保存
    await _firestore.collection('user_blocks').add({
      'blocker_id': currentUserId,
      'blocked_id': targetUserId,
      'blocked_at': FieldValue.serverTimestamp(),
    });

    // チャットルームを非表示化
    final chatRoomQuery = await _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in chatRoomQuery.docs) {
      final data = doc.data();
      final participantsData = data['participants'];
      if (participantsData == null) continue;
      
      final participants = List<String>.from(participantsData);
      if (participants.contains(targetUserId)) {
        await doc.reference.update({
          'hidden_for': FieldValue.arrayUnion([currentUserId]),
        });
      }
    }
  }

  /// ユーザーを通報
  Future<void> reportUser({
    required String targetUserId,
    required String reason,
    String? details,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('ユーザーが認証されていません');

    await _firestore.collection('user_reports').add({
      'reporter_id': currentUserId,
      'reported_id': targetUserId,
      'reason': reason,
      'details': details,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
