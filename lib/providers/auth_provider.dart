import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication状態管理
class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = true;

  AuthProvider() {
    _init();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  /// 初期化：認証状態を監視
  void _init() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  /// ログアウト
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  /// 現在のユーザー表示名を取得
  String get displayName {
    if (_user?.displayName != null && _user!.displayName!.isNotEmpty) {
      return _user!.displayName!;
    }
    return _user?.email?.split('@').first ?? AppLocalizations.of(context)!.general_0cfd9ec5;
  }

  /// 現在のユーザーメールアドレスを取得
  String get email => _user?.email ?? '';
}
