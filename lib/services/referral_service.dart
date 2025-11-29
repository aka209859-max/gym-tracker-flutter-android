// lib/services/referral_service.dart
// 紹介プログラムサービス

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'ai_credit_service.dart';

/// 紹介プログラムサービス
class ReferralService {
  static const String _keyReferralCode = 'user_referral_code';
  static const String _keyReferralCount = 'referral_count';
  static const String _keyReferredBy = 'referred_by';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ユーザーの紹介コードを取得（なければ生成）
  Future<String> getReferralCode() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return '';

      // ローカルキャッシュをチェック
      final prefs = await SharedPreferences.getInstance();
      String? code = prefs.getString(_keyReferralCode);
      
      if (code != null && code.isNotEmpty) {
        return code;
      }

      // Firestoreから取得
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()?['referralCode'] != null) {
        code = doc.data()!['referralCode'] as String;
        await prefs.setString(_keyReferralCode, code);
        return code;
      }

      // 新規生成
      code = _generateReferralCode(user.uid);
      
      // Firestoreに保存
      await _firestore.collection('users').doc(user.uid).set({
        'referralCode': code,
        'referralCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ローカルキャッシュに保存
      await prefs.setString(_keyReferralCode, code);

      return code;
    } catch (e) {
      print('Error getting referral code: $e');
      return '';
    }
  }

  /// 紹介コードを生成
  String _generateReferralCode(String uid) {
    // UIDの最後8文字 + ランダム2文字
    final base = uid.substring(uid.length - 8).toUpperCase();
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    return '$base$random';
  }

  /// 紹介コードをシェア
  Future<void> shareReferralCode() async {
    try {
      final code = await getReferralCode();
      if (code.isEmpty) {
        print('Referral code is empty');
        return;
      }

      final shareText = '''
🏋️ GYM MATCHに招待します！

紹介コード: $code

GYM MATCHは40本以上の論文に基づく
AI科学的トレーニングコーチングアプリです。

このコードで登録すると、
あなたも私もAI追加パック（5回分）がもらえます！ 🎁

#GYM_MATCH #筋トレ #AI #トレーニング
''';

      await Share.share(shareText);
    } catch (e) {
      print('Error sharing referral code: $e');
    }
  }

  /// 紹介コードを適用（新規ユーザー登録時）
  /// 
  /// [referralCode] 紹介コード
  /// 戻り値: 適用成功 true/失敗 false
  Future<bool> applyReferralCode(String referralCode) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 既に紹介コードを適用済みかチェック
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_keyReferredBy) != null) {
        print('Referral code already applied');
        return false;
      }

      // 紹介コードが存在するかチェック
      final referrerQuery = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();

      if (referrerQuery.docs.isEmpty) {
        print('Invalid referral code');
        return false;
      }

      final referrerDoc = referrerQuery.docs.first;
      final referrerId = referrerDoc.id;

      // 自分自身のコードは使えない
      if (referrerId == user.uid) {
        print('Cannot use own referral code');
        return false;
      }

      // トランザクションで紹介カウントを増やす & 報酬を付与
      await _firestore.runTransaction((transaction) async {
        final referrerRef = _firestore.collection('users').doc(referrerId);
        final referrerSnapshot = await transaction.get(referrerRef);

        if (!referrerSnapshot.exists) {
          throw Exception('Referrer not found');
        }

        final currentCount = referrerSnapshot.data()?['referralCount'] as int? ?? 0;

        // 紹介者のカウントを増やす
        transaction.update(referrerRef, {
          'referralCount': currentCount + 1,
          'lastReferralAt': FieldValue.serverTimestamp(),
        });

        // 新規ユーザーに紹介元を記録
        final newUserRef = _firestore.collection('users').doc(user.uid);
        transaction.set(newUserRef, {
          'referredBy': referrerId,
          'referralCodeUsed': referralCode,
          'referredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      // 紹介者にAI追加パック報酬を付与
      await _grantReferralReward(referrerId);

      // 新規ユーザーにもAI追加パック報酬を付与
      await _grantReferralReward(user.uid);

      // ローカルに記録
      await prefs.setString(_keyReferredBy, referrerId);

      print('Referral code applied successfully');
      return true;
    } catch (e) {
      print('Error applying referral code: $e');
      return false;
    }
  }

  /// 紹介報酬を付与（AI追加パック5回分）
  Future<void> _grantReferralReward(String userId) async {
    try {
      // AI Credit Serviceを使って5回分のクレジットを付与
      final creditService = AICreditService();
      
      // 5回分追加
      for (int i = 0; i < 5; i++) {
        await creditService.addAICredit();
      }
      
      print('Granted 5 AI credits to user: $userId');
    } catch (e) {
      print('Error granting referral reward: $e');
    }
  }

  /// 紹介成功数を取得
  Future<int> getReferralCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return 0;

      return doc.data()?['referralCount'] as int? ?? 0;
    } catch (e) {
      print('Error getting referral count: $e');
      return 0;
    }
  }

  /// 紹介報酬の詳細を取得
  Future<Map<String, dynamic>> getReferralStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'count': 0, 'reward': 0, 'code': ''};
      }

      final code = await getReferralCode();
      final count = await getReferralCount();
      final reward = count * 5; // 1紹介につきAI 5回分

      return {
        'code': code,
        'count': count,
        'reward': reward,
      };
    } catch (e) {
      print('Error getting referral stats: $e');
      return {'count': 0, 'reward': 0, 'code': ''};
    }
  }
}
