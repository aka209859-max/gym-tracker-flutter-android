import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'trainer_records_screen.dart';

/// パーソナルトレーニング認証画面
class PTPasswordScreen extends StatefulWidget {
  const PTPasswordScreen({super.key});

  @override
  State<PTPasswordScreen> createState() => _PTPasswordScreenState();
}

class _PTPasswordScreenState extends State<PTPasswordScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// パスワード認証処理
  Future<void> _authenticate() async {
    if (_passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.passwordRequired;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception(AppLocalizations.of(context)!.login);
      }

      // ユーザー情報を取得
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception(AppLocalizations.of(context)!.general_9ab1948f);
      }

      final userData = userDoc.data();
      if (userData == null) {
        throw Exception(AppLocalizations.of(context)!.gym_c7e47d32);
      }
      final useGymCommonPassword = userData['useGymCommonPassword'] as bool? ?? true;
      final gymId = userData['gymId'] as String?;

      String? correctPassword;

      if (useGymCommonPassword && gymId != null) {
        // 店舗共通パスワードを取得
        final gymDoc = await FirebaseFirestore.instance
            .collection('gyms')
            .doc(gymId)
            .get();

        if (gymDoc.exists) {
          correctPassword = gymDoc.data()?['personalTrainingCommonPassword'] as String?;
        }
      } else {
        // 個別パスワードを取得
        correctPassword = userData['personalTrainingPassword'] as String?;
      }

      // パスワード検証
      if (correctPassword == null || correctPassword.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.settings);
      }

      if (_passwordController.text.trim() != correctPassword) {
        throw Exception(AppLocalizations.of(context)!.incorrectPassword);
      }

      // 認証成功 - トレーナー記録画面へ遷移
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const TrainerRecordsScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
                          AppLocalizations.of(context)!.personalTraining,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3F51B5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // アイコン
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: Colors.orange,
                ),
              ),

              const SizedBox(height: 24),

              // タイトル
              Text(
                          AppLocalizations.of(context)!.password,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // 説明文
              Text(
                          AppLocalizations.of(context)!.personalTraining,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // メールアドレス表示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // パスワード入力
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.password,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.password,
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.orange, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onSubmitted: (_) => _authenticate(),
                  ),
                ],
              ),

              // エラーメッセージ
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // 認証ボタン
              ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey[300],
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
                    : const Text(
                        AppLocalizations.of(context)!.general_7c2f0a2b,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // 注意書き
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.password,
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
