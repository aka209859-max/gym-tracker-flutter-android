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

  // 紹介特典（v1.02強化版: 3倍に増量！）
  static const int _refereeAiBonus = 5; // 紹介された側のAI無料利用×5回（旧3回→5回）
  static const int _refereePremiumDays = 3; // 紹介された側のPremium無料体験×3日間（新規）
  static const int _referrerAiBonus = 15; // 紹介した側のAI追加パック×3個（15回分、¥900相当、旧5回→15回）
  static const int _referrerPremiumDays = 7; // 紹介した側のPremium無料体験×7日間（新規）

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
        'aiPackCredits': 0, // AI追加パックの獲得数
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
      // 1. 紹介された側（referee）に豪華特典付与
      //    - AI無料利用×5回（旧3回→5回に増量）
      //    - Premium無料体験×3日間（新規追加）
      final userRef = _firestore.collection('users').doc(user.uid);
      final premiumUntil = DateTime.now().add(Duration(days: _refereePremiumDays));
      transaction.update(userRef, {
        'usedReferralCode': code,
        'referredBy': referrerId,
        'referralBonusAiCredits': _refereeAiBonus, // 5回分
        'referralBonusPremiumUntil': Timestamp.fromDate(premiumUntil), // 3日間Premium
        'referredAt': FieldValue.serverTimestamp(),
      });

      // 2. 紹介した側（referrer）に超豪華特典付与
      //    - AI追加パック×3個（15回分、¥900相当、旧5回→15回に増量）
      //    - Premium無料体験×7日間（新規追加）
      final referrerRef = _firestore.collection('users').doc(referrerId);
      final referrerPremiumUntil = DateTime.now().add(Duration(days: _referrerPremiumDays));
      transaction.update(referrerRef, {
        'referralStats.totalReferrals': FieldValue.increment(1),
        'referralStats.successfulReferrals': FieldValue.increment(1),
        'referralStats.aiPackCredits': FieldValue.increment(3), // AI追加パック×3個（旧1個→3個）
        'ai_credits': FieldValue.increment(_referrerAiBonus), // AI 15回分を直接付与（旧5回→15回）
        'referralBonusPremiumUntil': Timestamp.fromDate(referrerPremiumUntil), // 7日間Premium
      });

      // 3. 紹介履歴を記録（v1.02強化版）
      final referralRef = _firestore.collection('referrals').doc();
      transaction.set(referralRef, {
        'referrerId': referrerId,
        'refereeId': user.uid,
        'referralCode': code,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'bonuses': {
          'refereeAiCredits': _refereeAiBonus, // 5回分
          'refereePremiumDays': _refereePremiumDays, // 3日間
          'referrerAiPackCredits': 3, // AI追加パック×3個（15回分、¥900相当）
          'referrerPremiumDays': _referrerPremiumDays, // 7日間
        },
      });
    });

    print('🎉 紹介コード適用成功！');
    print('   紹介された側: AI×${_refereeAiBonus}回 + Premium×${_refereePremiumDays}日間');
    print('   紹介した側: AI×${_referrerAiBonus}回 + Premium×${_referrerPremiumDays}日間');

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
        'aiPackCredits': 0,
        'referralCode': await getReferralCode(),
      };
    }

    final stats = data['referralStats'] as Map<String, dynamic>;
    return {
      'totalReferrals': stats['totalReferrals'] ?? 0,
      'successfulReferrals': stats['successfulReferrals'] ?? 0,
      'aiPackCredits': stats['aiPackCredits'] ?? 0,
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

  /// 紹介した側のAI追加パック獲得数を取得
  Future<int> getReferrerAiPackCredits() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    if (data == null) return 0;

    final stats = data['referralStats'] as Map<String, dynamic>?;
    return (stats?['aiPackCredits'] as int?) ?? 0;
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

  /// 紹介ボーナスのPremium無料期間が有効かチェック
  Future<bool> hasActivePremiumBonus() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    if (data == null || !data.containsKey('referralBonusPremiumUntil')) {
      return false;
    }

    final premiumUntil = (data['referralBonusPremiumUntil'] as Timestamp).toDate();
    return DateTime.now().isBefore(premiumUntil);
  }

  /// 紹介ボーナスのPremium有効期限を取得
  Future<DateTime?> getPremiumBonusExpiry() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    if (data == null || !data.containsKey('referralBonusPremiumUntil')) {
      return null;
    }

    return (data['referralBonusPremiumUntil'] as Timestamp).toDate();
  }
}
