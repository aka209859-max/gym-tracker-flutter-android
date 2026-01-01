import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// トレーニングパートナーサービス（レガシー - 新規実装は training_partner_service.dart を使用）
class PartnerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 最終アクティブ時刻を更新
  Future<void> updateLastActive() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('training_partners').doc(currentUser.uid).set({
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // エラーは無視
    }
  }

  /// パートナープロフィールを更新
  Future<void> updatePartnerProfile({
    required String bio,
    required String experienceLevel,
    required List<String> preferredExercises,
    required List<String> goals,
    String? gymId,
    String? gymName,
    double? latitude,
    double? longitude,
    bool isAvailable = true,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception(AppLocalizations.of(context)!.loginRequired);

    await _firestore.collection('training_partners').doc(currentUser.uid).set({
      'name': currentUser.displayName ?? 'Unknown',
      'photoUrl': currentUser.photoURL ?? '',
      'bio': bio,
      'experienceLevel': experienceLevel,
      'preferredExercises': preferredExercises,
      'goals': goals,
      'gymId': gymId,
      'gymName': gymName,
      'latitude': latitude,
      'longitude': longitude,
      'isAvailable': isAvailable,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
