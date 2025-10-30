import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// リアルタイムユーザー数管理サービス
class RealtimeUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 特定ジムの現在のユーザー数をストリームで取得
  Stream<int> getUserCountStream(String gymId) {
    return _firestore
        .collection('gym_users')
        .where('gym_id', isEqualTo: gymId)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// 現在のユーザーをジムにチェックイン
  Future<void> checkInToGym(String gymId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDocRef = _firestore
        .collection('gym_users')
        .doc('${user.uid}_$gymId');

    await userDocRef.set({
      'user_id': user.uid,
      'gym_id': gymId,
      'is_active': true,
      'checked_in_at': FieldValue.serverTimestamp(),
      'last_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 現在のユーザーをジムからチェックアウト
  Future<void> checkOutFromGym(String gymId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDocRef = _firestore
        .collection('gym_users')
        .doc('${user.uid}_$gymId');

    await userDocRef.update({
      'is_active': false,
      'checked_out_at': FieldValue.serverTimestamp(),
      'last_updated': FieldValue.serverTimestamp(),
    });
  }

  /// 現在のユーザーが特定ジムにチェックインしているか確認
  Future<bool> isUserCheckedIn(String gymId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _firestore
        .collection('gym_users')
        .doc('${user.uid}_$gymId')
        .get();

    if (!userDoc.exists) return false;

    final data = userDoc.data();
    return data?['is_active'] == true;
  }

  /// 古いチェックイン（24時間以上）を自動クリーンアップ
  Future<void> cleanupOldCheckIns() async {
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
    
    final oldCheckIns = await _firestore
        .collection('gym_users')
        .where('last_updated', isLessThan: Timestamp.fromDate(cutoffTime))
        .where('is_active', isEqualTo: true)
        .get();

    for (var doc in oldCheckIns.docs) {
      await doc.reference.update({
        'is_active': false,
        'auto_checked_out': true,
      });
    }
  }
}
