import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseAuthException;

/// 認証画面（ログイン・新規登録）
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true; // ログインモード or 新規登録モード
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// ログイン処理（匿名アカウントとのリンクをサポート）
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // 匿名ユーザーの場合、アカウントをリンク（データ引き継ぎ）
      if (currentUser != null && currentUser.isAnonymous) {
        try {
          final credential = firebase_auth.EmailAuthProvider.credential(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          
          // 匿名アカウントにメール/パスワード認証をリンク
          await currentUser.linkWithCredential(credential);
          if (kDebugMode) {
            debugPrint('✅ 匿名アカウントをメールアカウントにリンク成功');
          }
        } on FirebaseAuthException catch (linkError) {
          // リンクエラー（例: メールアドレスが既に使用されている）
          if (linkError.code == 'email-already-in-use' || 
              linkError.code == 'credential-already-in-use') {
            // 既存アカウントでログイン
            if (kDebugMode) {
              debugPrint('⚠️ メールアドレスが既に使用中、通常ログインに切り替え');
            }
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );
          } else {
            rethrow;
          }
        }
      } else {
        // 通常のログイン
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      
      if (mounted) {
        Navigator.of(context).pop(); // 認証成功 → メイン画面へ
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 新規登録処理
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 表示名を設定
      if (_nameController.text.isNotEmpty) {
        await userCredential.user?.updateDisplayName(_nameController.text.trim());
      }

      if (mounted) {
        Navigator.of(context).pop(); // 認証成功 → メイン画面へ
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// エラーメッセージを日本語化
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return AppLocalizations.of(context)!.emailNotRegistered;
      case 'wrong-password':
        return AppLocalizations.of(context)!.incorrectPassword;
      case 'email-already-in-use':
        return AppLocalizations.of(context)!.emailNotRegistered;
      case 'invalid-email':
        return AppLocalizations.of(context)!.invalidEmailFormat;
      case 'weak-password':
        return AppLocalizations.of(context)!.passwordMin6;
      case 'network-request-failed':
        return AppLocalizations.of(context)!.general_4b85b706;
      default:
        return AppLocalizations.of(context)!.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ロゴ・タイトル
                Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'FitSync',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.general_3fc0f668,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 48),

                // フォーム
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 名前入力（新規登録時のみ）
                      if (!_isLogin)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.name,
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (!_isLogin && (value == null || value.trim().isEmpty)) {
                                return AppLocalizations.of(context)!.general_98d98661;
                              }
                              return null;
                            },
                          ),
                        ),

                      // メールアドレス入力
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.email,
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocalizations.of(context)!.emailRequired;
                          }
                          if (!value.contains('@')) {
                            return AppLocalizations.of(context)!.enterValidEmailAddress;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // パスワード入力
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.password,
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!.passwordRequired;
                          }
                          if (value.length < 6) {
                            return AppLocalizations.of(context)!.passwordMin6;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // エラーメッセージ表示
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // ログイン/新規登録ボタン
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_isLogin ? _login : _signUp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  _isLogin ? AppLocalizations.of(context)!.login : AppLocalizations.of(context)!.signUp,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // モード切り替えボタン
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _errorMessage = null;
                                });
                              },
                        child: Text(
                          _isLogin
                              ? AppLocalizations.of(context)!.dontHaveAccount
                              : AppLocalizations.of(context)!.general_8fc2afad,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 利用規約・プライバシーポリシー
                Text(
                  AppLocalizations.of(context)!.general_cef07c55,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
