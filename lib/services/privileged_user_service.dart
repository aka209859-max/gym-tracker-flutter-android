import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 特権ユーザー管理サービス
/// 
/// 開発者・インフルエンサーなどの特別な権限を管理
class PrivilegedUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 特権ユーザーのタイプ
  static const String privilegeTypeDeveloper = 'developer';
  static const String privilegeTypeInfluencer = 'influencer';
  static const String privilegeTypeLifetime = 'lifetime';

  /// 開発者のUID（あなた）
  static const List<String> developerUIDs = [
    // ここにあなたのFirebase UIDを追加
    'YOUR_UID_HERE', // ← 実際のUIDに置き換えてください
  ];

  /// 特権ユーザー情報を取得
  Future<PrivilegedUserInfo?> getPrivilegedUserInfo(String uid) async {
    try {
      final doc = await _firestore
          .collection('privileged_users')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          return PrivilegedUserInfo.fromFirestore(data, doc.id);
        }
      }

      // 開発者UIDチェック
      if (developerUIDs.contains(uid)) {
        // 開発者情報を自動作成
        await _createDeveloperAccess(uid);
        return PrivilegedUserInfo(
          uid: uid,
          privilegeType: privilegeTypeDeveloper,
          grantedPlan: 'pro',
          grantedAt: DateTime.now(),
          expiresAt: null, // 永年
          inviteCode: null,
          notes: 'Auto-granted developer access',
        );
      }

      return null;
    } catch (e) {
      debugPrint('❌ 特権ユーザー情報取得エラー: $e');
      return null;
    }
  }

  /// 現在のユーザーが特権ユーザーかチェック
  Future<bool> isPrivilegedUser() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final info = await getPrivilegedUserInfo(user.uid);
    return info != null;
  }

  /// 特権ユーザーのプランを取得
  Future<String?> getPrivilegedPlan() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final info = await getPrivilegedUserInfo(user.uid);
    if (info == null) return null;

    // 有効期限チェック
    if (info.expiresAt != null && info.expiresAt!.isBefore(DateTime.now())) {
      return null; // 期限切れ
    }

    return info.grantedPlan;
  }

  /// 開発者アクセスを自動作成
  Future<void> _createDeveloperAccess(String uid) async {
    try {
      await _firestore.collection('privileged_users').doc(uid).set({
        'privilege_type': privilegeTypeDeveloper,
        'granted_plan': 'pro',
        'granted_at': FieldValue.serverTimestamp(),
        'expires_at': null, // 永年
        'invite_code': null,
        'notes': 'Auto-granted developer access',
        'is_active': true,
      });
      debugPrint('✅ 開発者アクセス作成完了: $uid');
    } catch (e) {
      debugPrint('❌ 開発者アクセス作成エラー: $e');
    }
  }

  /// インフルエンサー招待コードを生成
  Future<String> generateInfluencerInviteCode({
    required String influencerName,
    required String grantedPlan, // 'premium' or 'pro'
    DateTime? expiresAt, // null = 永年
    String? notes,
  }) async {
    try {
      // ランダムな招待コード生成（8文字の英数字）
      final code = _generateRandomCode(8);

      await _firestore.collection('invite_codes').doc(code).set({
        'code': code,
        'influencer_name': influencerName,
        'granted_plan': grantedPlan,
        'expires_at': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'notes': notes,
        'is_used': false,
        'used_by_uid': null,
        'used_at': null,
        'created_at': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 招待コード生成完了: $code for $influencerName');
      return code;
    } catch (e) {
      debugPrint('❌ 招待コード生成エラー: $e');
      rethrow;
    }
  }

  /// 招待コードを使用
  Future<bool> redeemInviteCode(String code) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('ログインが必要です');
      }

      // 招待コード確認
      final inviteDoc = await _firestore
          .collection('invite_codes')
          .doc(code.toUpperCase())
          .get();

      if (!inviteDoc.exists) {
        throw Exception('無効な招待コードです');
      }
      
      final inviteData = inviteDoc.data();
      if (inviteData == null) {
        throw Exception('招待コードのデータが見つかりません');
      }
      
      // 既に使用済みチェック
      if (inviteData['is_used'] == true) {
        throw Exception('この招待コードは既に使用されています');
      }

      // 有効期限チェック
      if (inviteData['expires_at'] != null) {
        final expiresAt = (inviteData['expires_at'] as Timestamp).toDate();
        if (expiresAt.isBefore(DateTime.now())) {
          throw Exception('この招待コードは有効期限切れです');
        }
      }

      // トランザクションで招待コード使用 + 特権ユーザー登録
      await _firestore.runTransaction((transaction) async {
        // 招待コードを使用済みにする
        transaction.update(
          _firestore.collection('invite_codes').doc(code.toUpperCase()),
          {
            'is_used': true,
            'used_by_uid': user.uid,
            'used_at': FieldValue.serverTimestamp(),
          },
        );

        // 特権ユーザーとして登録
        transaction.set(
          _firestore.collection('privileged_users').doc(user.uid),
          {
            'privilege_type': privilegeTypeInfluencer,
            'granted_plan': inviteData['granted_plan'],
            'granted_at': FieldValue.serverTimestamp(),
            'expires_at': inviteData['expires_at'],
            'invite_code': code.toUpperCase(),
            'influencer_name': inviteData['influencer_name'],
            'notes': inviteData['notes'],
            'is_active': true,
          },
        );

        // users コレクションも更新
        transaction.set(
          _firestore.collection('users').doc(user.uid),
          {
            'isPremium': true,
            'premiumType': inviteData['granted_plan'],
            'privileged_user': true,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      debugPrint('✅ 招待コード使用完了: $code for ${user.uid}');
      return true;
    } catch (e) {
      debugPrint('❌ 招待コード使用エラー: $e');
      rethrow;
    }
  }

  /// インフルエンサー招待コード一覧を取得
  Future<List<InviteCodeInfo>> getInviteCodes() async {
    try {
      final snapshot = await _firestore
          .collection('invite_codes')
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => InviteCodeInfo.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ 招待コード一覧取得エラー: $e');
      return [];
    }
  }

  /// ランダムコード生成
  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 紛らわしい文字を除外
    final random = DateTime.now().millisecondsSinceEpoch;
    var code = '';
    
    for (int i = 0; i < length; i++) {
      code += chars[(random + i) % chars.length];
    }
    
    return code;
  }
}

/// 特権ユーザー情報
class PrivilegedUserInfo {
  final String uid;
  final String privilegeType; // developer, influencer, lifetime
  final String grantedPlan; // premium, pro
  final DateTime grantedAt;
  final DateTime? expiresAt; // null = 永年
  final String? inviteCode;
  final String? notes;

  PrivilegedUserInfo({
    required this.uid,
    required this.privilegeType,
    required this.grantedPlan,
    required this.grantedAt,
    this.expiresAt,
    this.inviteCode,
    this.notes,
  });

  factory PrivilegedUserInfo.fromFirestore(Map<String, dynamic> data, String uid) {
    return PrivilegedUserInfo(
      uid: uid,
      privilegeType: data['privilege_type'] ?? 'influencer',
      grantedPlan: data['granted_plan'] ?? 'pro',
      grantedAt: (data['granted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: data['expires_at'] != null 
          ? (data['expires_at'] as Timestamp).toDate() 
          : null,
      inviteCode: data['invite_code'],
      notes: data['notes'],
    );
  }
}

/// 招待コード情報
class InviteCodeInfo {
  final String code;
  final String influencerName;
  final String grantedPlan;
  final DateTime? expiresAt;
  final bool isUsed;
  final String? usedByUid;
  final DateTime? usedAt;
  final String? notes;

  InviteCodeInfo({
    required this.code,
    required this.influencerName,
    required this.grantedPlan,
    this.expiresAt,
    required this.isUsed,
    this.usedByUid,
    this.usedAt,
    this.notes,
  });

  factory InviteCodeInfo.fromFirestore(Map<String, dynamic> data, String docId) {
    return InviteCodeInfo(
      code: data['code'] ?? docId,
      influencerName: data['influencer_name'] ?? '',
      grantedPlan: data['granted_plan'] ?? 'pro',
      expiresAt: data['expires_at'] != null
          ? (data['expires_at'] as Timestamp).toDate()
          : null,
      isUsed: data['is_used'] ?? false,
      usedByUid: data['used_by_uid'],
      usedAt: data['used_at'] != null
          ? (data['used_at'] as Timestamp).toDate()
          : null,
      notes: data['notes'],
    );
  }
}
