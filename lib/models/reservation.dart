import 'package:cloud_firestore/cloud_firestore.dart';

/// 予約データモデル
class Reservation {
  final String id;
  final String gymId;            // ジムID
  final String gymName;          // ジム名（表示用）
  final String userName;         // 予約者氏名
  final String phoneNumber;      // 電話番号
  final String email;            // メールアドレス
  final DateTime preferredDate;  // 希望日時
  final String? message;         // その他要望・メッセージ
  final DateTime createdAt;      // 予約申込日時
  final String status;           // ステータス（pending/confirmed/cancelled）

  Reservation({
    required this.id,
    required this.gymId,
    required this.gymName,
    required this.userName,
    required this.phoneNumber,
    required this.email,
    required this.preferredDate,
    this.message,
    required this.createdAt,
    this.status = 'pending',
  });

  /// Firestoreから予約データを生成
  factory Reservation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reservation(
      id: doc.id,
      gymId: data['gymId'] ?? '',
      gymName: data['gymName'] ?? '',
      userName: data['userName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'] ?? '',
      preferredDate: (data['preferredDate'] as Timestamp).toDate(),
      message: data['message'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
    );
  }

  /// Firestore用にマップ形式に変換
  Map<String, dynamic> toMap() {
    return {
      'gymId': gymId,
      'gymName': gymName,
      'userName': userName,
      'phoneNumber': phoneNumber,
      'email': email,
      'preferredDate': Timestamp.fromDate(preferredDate),
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  /// ステータスの日本語表示
  String get statusText {
    switch (status) {
      case 'pending':
        return AppLocalizations.of(context)!.general_044f232e;
      case 'confirmed':
        return AppLocalizations.of(context)!.subscription_84b9d24c;
      case 'cancelled':
        return AppLocalizations.of(context)!.buttonCancel;
      default:
        return AppLocalizations.of(context)!.unknown;
    }
  }
}
