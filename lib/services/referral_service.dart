import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Task 10: バイラルループ実装
/// 紹介コードシステムでCAC削減（¥2,500→¥1,675、-33%）
class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 紹介コード長（例: "GYM12ABC"）
  static const int _codeLength = 8;
  static const String _codePrefix = 'GYM';

  // 紹介特典
  static const int _refereeAiBonus = 3; // 紹介された側のAI無料利用×3回
  static const double _referrerDiscountPercent = 50.0; // 紹介した側のPremium割引50%

  /// ユーザーの紹介コードを取得（なければ生成）
  Future<String> getReferralCode() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    // 既存コードがあればそれを返す
    if (data != null && data.containsKey('referralCode')) {
      return data['referralCode'] as String;
    }

    // なければ新規生成
    final newCode = await _generateUniqueCode();
    await _firestore.collection('users').doc(user.uid).update({
      'referralCode': newCode,
      'referralStats': {
        'totalReferrals': 0,
        'successfulReferrals': 0,
        'discountCredits': 0,
      },
      'referralCodeCreatedAt': FieldValue.serverTimestamp(),
    });

    return newCode;
  }

  /// ユニークな紹介コードを生成
  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    int attempts = 0;
    const maxAttempts = 10;

    while (attempts < maxAttempts) {
      // コード生成（例: GYM + 5文字ランダム）
      final randomPart = List.generate(
        _codeLength - _codePrefix.length,
        (index) => chars[random.nextInt(chars.length)],
      ).join();
      final code = '$_codePrefix$randomPart';

      // 重複チェック
      final existingCode = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();

      if (existingCode.docs.isEmpty) {
        return code;
      }

      attempts++;
    }

    throw Exception('Failed to generate unique referral code after $maxAttempts attempts');
  }

  /// 紹介コードを使用（新規ユーザー登録時）
  Future<bool> applyReferralCode(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // コードの検証
    code = code.trim().toUpperCase();
    if (code.isEmpty || !code.startsWith(_codePrefix)) {
      throw Exception('Invalid referral code format');
    }

    // 紹介者を検索
    final referrerQuery = await _firestore
        .collection('users')
        .where('referralCode', isEqualTo: code)
        .limit(1)
        .get();

    if (referrerQuery.docs.isEmpty) {
      throw Exception('Referral code not found');
    }

    final referrerDoc = referrerQuery.docs.first;
    final referrerId = referrerDoc.id;

    // 自分自身の紹介は不可
    if (referrerId == user.uid) {
      throw Exception('Cannot use your own referral code');
    }

    // 既に紹介コードを使用済みかチェック
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData != null && userData.containsKey('usedReferralCode')) {
      throw Exception('You have already used a referral code');
    }

    // トランザクションで処理
    await _firestore.runTransaction((transaction) async {
      // 1. 紹介された側（referee）にAI無料利用×3回付与
      final userRef = _firestore.collection('users').doc(user.uid);
      transaction.update(userRef, {
        'usedReferralCode': code,
        'referredBy': referrerId,
        'referralBonusAiCredits': _refereeAiBonus,
        'referredAt': FieldValue.serverTimestamp(),
      });

      // 2. 紹介した側（referrer）に割引クレジット付与
      final referrerRef = _firestore.collection('users').doc(referrerId);
      transaction.update(referrerRef, {
        'referralStats.totalReferrals': FieldValue.increment(1),
        'referralStats.successfulReferrals': FieldValue.increment(1),
        'referralStats.discountCredits': FieldValue.increment(1), // 50%割引×1回
      });

      // 3. 紹介履歴を記録
      final referralRef = _firestore.collection('referrals').doc();
      transaction.set(referralRef, {
        'referrerId': referrerId,
        'refereeId': user.uid,
        'referralCode': code,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'bonuses': {
          'refereeAiCredits': _refereeAiBonus,
          'referrerDiscountCredit': 1,
        },
      });
    });

    return true;
  }

  /// 紹介統計を取得
  Future<Map<String, dynamic>> getReferralStats() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    if (data == null || !data.containsKey('referralStats')) {
      return {
        'totalReferrals': 0,
        'successfulReferrals': 0,
        'discountCredits': 0,
        'referralCode': await getReferralCode(),
      };
    }

    final stats = data['referralStats'] as Map<String, dynamic>;
    return {
      'totalReferrals': stats['totalReferrals'] ?? 0,
      'successfulReferrals': stats['successfulReferrals'] ?? 0,
      'discountCredits': stats['discountCredits'] ?? 0,
      'referralCode': data['referralCode'] ?? await getReferralCode(),
    };
  }

  /// 紹介ボーナスのAIクレジットを取得
  Future<int> getReferralBonusAiCredits() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    if (data == null) return 0;
    return (data['referralBonusAiCredits'] as int?) ?? 0;
  }

  /// 紹介ボーナスのAIクレジットを消費
  Future<void> consumeReferralBonusAiCredit() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore.collection('users').doc(user.uid).update({
      'referralBonusAiCredits': FieldValue.increment(-1),
    });
  }

  /// 紹介した側の割引クレジットを使用
  Future<bool> useReferrerDiscountCredit() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    if (data == null) return false;

    final stats = data['referralStats'] as Map<String, dynamic>?;
    final discountCredits = (stats?['discountCredits'] as int?) ?? 0;

    if (discountCredits <= 0) return false;

    await _firestore.collection('users').doc(user.uid).update({
      'referralStats.discountCredits': FieldValue.increment(-1),
      'referralStats.usedDiscountCredits': FieldValue.increment(1),
    });

    return true;
  }

  /// 紹介リストを取得（紹介した側用）
  Future<List<Map<String, dynamic>>> getReferralsList() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final referralsQuery = await _firestore
        .collection('referrals')
        .where('referrerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return referralsQuery.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'refereeId': data['refereeId'],
        'referralCode': data['referralCode'],
        'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        'status': data['status'],
      };
    }).toList();
  }

  /// SharedPreferencesに紹介コードをキャッシュ
  Future<void> cacheReferralCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('referral_code', code);
  }

  /// SharedPreferencesから紹介コードを取得
  Future<String?> getCachedReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('referral_code');
  }

  /// 紹介コード適用済みかチェック
  Future<bool> hasUsedReferralCode() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    return data != null && data.containsKey('usedReferralCode');
  }
}
