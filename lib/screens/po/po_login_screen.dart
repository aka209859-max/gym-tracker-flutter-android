import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'po_dashboard_screen.dart';

/// PO管理者専用ログイン画面
/// 
/// 機能:
/// 1. メールアドレス + パスワード認証
/// 2. アクセスコード認証（例: RF-AKA-2024）
/// 3. Firestoreでrole="poAppLocalizations.of(context)!.password📧 PO Email認証開始...');
        debugPrint('   Email: ${_emailController.text}');
      }

      // Firebase Authentication
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final userId = userCredential.user?.uid;
      if (userId == null) {
        throw Exception(AppLocalizations.of(context)!.error_31d6c265);
      }

      if (kDebugMode) {
        debugPrint('✅ Firebase認証成功: $userId');
      }

      // Firestoreでrole="po"を検証
      final poDoc = await FirebaseFirestore.instance
          .collection('poOwners')
          .doc(userId)
          .get();

      if (!poDoc.exists) {
        // PO登録がない場合
        await FirebaseAuth.instance.signOut();
        throw Exception(AppLocalizations.of(context)!.emailNotRegistered);
      }

      final data = poDoc.data();
      if (data == null) {
        await FirebaseAuth.instance.signOut();
        throw Exception(AppLocalizations.of(context)!.error_5f7080fe);
      }
      
      if (data['role'] != 'po') {
        await FirebaseAuth.instance.signOut();
        throw Exception(AppLocalizations.of(context)!.general_82f22f64);
      }

      if (kDebugMode) {
        debugPrint('✅ PO権限確認完了');
        debugPrint('   ジム名: ${data['gymName']}');
      }

      // ダッシュボードへ遷移
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PODashboardScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Firebase認証エラー: ${e.code} - ${e.message}');
      }

      String errorMsg;
      switch (e.code) {
        case 'user-not-found':
          errorMsg = AppLocalizations.of(context)!.emailNotRegistered;
          break;
        case 'wrong-password':
          errorMsg = AppLocalizations.of(context)!.general_cca4bb63;
          break;
        case 'invalid-email':
          errorMsg = AppLocalizations.of(context)!.invalidEmailFormat;
          break;
        case 'user-disabled':
          errorMsg = AppLocalizations.of(context)!.general_a62dd99d;
          break;
        default:
          errorMsg = AppLocalizations.of(context)!.error;
      }

      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ログインエラー: $e');
      }

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// アクセスコード認証（例: RF-AKA-2024）
  Future<void> _loginWithAccessCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accessCode = _accessCodeController.text.trim().toUpperCase();

      if (kDebugMode) {
        debugPrint('🔑 アクセスコード認証開始...');
        debugPrint('   Code: $accessCode');
      }

      // Firestoreでアクセスコード検索
      final querySnapshot = await FirebaseFirestore.instance
          .collection('poOwners')
          .where('accessCode', isEqualTo: accessCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.general_5e23a0da);
      }

      final poDoc = querySnapshot.docs.first;
      final data = poDoc.data();

      if (kDebugMode) {
        debugPrint('✅ アクセスコード検証成功');
        debugPrint('   ジム名: ${data['gymName']}');
        debugPrint('   PO ID: ${poDoc.id}');
      }

      // メールアドレスとパスワードを取得してログイン
      final email = data['email'] as String;
      final password = data['password'] as String; // ⚠️ セキュリティ注意: 本番環境では別の方法を検討

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        debugPrint('✅ Firebase認証完了');
      }

      // ダッシュボードへ遷移
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PODashboardScreen(),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ アクセスコード認証エラー: $e');
      }

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ロゴ
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // タイトル
                const Text(
                  'GYM MATCH',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.general_5de90c88,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),

                // ログイン方法切り替えタブ
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          label: AppLocalizations.of(context)!.email,
                          icon: Icons.email_outlined,
                          isSelected: _loginMode == 0,
                          onTap: () => setState(() => _loginMode = 0),
                        ),
                      ),
                      Expanded(
                        child: _buildTabButton(
                          label: AppLocalizations.of(context)!.accessCode,
                          icon: Icons.key_outlined,
                          isSelected: _loginMode == 1,
                          onTap: () => setState(() => _loginMode = 1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // フォーム
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_loginMode == 0) ...[
                          // メールアドレスログインフォーム
                          _buildEmailForm(),
                        ] else ...[
                          // アクセスコードログインフォーム
                          _buildAccessCodeForm(),
                        ],
                      ],
                    ),
                  ),
                ),

                // エラーメッセージ
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ヘルプテキスト
                Text(
                  'PO管理者専用のログイン画面です\nアクセスコードをお持ちの方は「アクセスコード」タブから\nログインしてください',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// タブボタン
  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// メールアドレスログインフォーム
  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // メールアドレス
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.email,
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)!.emailRequired;
            }
            if (!value.contains('@')) {
              return AppLocalizations.of(context)!.enterValidEmailAddress;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // パスワード
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.password,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
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

        // ログインボタン
        ElevatedButton(
          onPressed: _isLoading ? null : _loginWithEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(AppLocalizations.of(context)!.login,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  /// アクセスコードログインフォーム
  Widget _buildAccessCodeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // アクセスコード入力
        TextFormField(
          controller: _accessCodeController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.accessCode,
            hintText: '例: RF-AKA-2024',
            prefixIcon: const Icon(Icons.key_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          textCapitalization: TextCapitalization.characters,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)!.general_5fdcaed2;
            }
            if (value.length < 8) {
              return AppLocalizations.of(context)!.general_f3d35372;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // 説明テキスト
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.general_c932d178,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ログインボタン
        ElevatedButton(
          onPressed: _isLoading ? null : _loginWithAccessCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(AppLocalizations.of(context)!.login,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
