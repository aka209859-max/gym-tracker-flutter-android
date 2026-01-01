import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テスト運用用パスワードゲート画面
class PasswordGateScreen extends StatefulWidget {
  final Widget child;
  
  const PasswordGateScreen({super.key, required this.child});

  @override
  State<PasswordGateScreen> createState() => _PasswordGateScreenState();
}

class _PasswordGateScreenState extends State<PasswordGateScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _errorMessage;

  // 🔒 テスト用固定パスワード (本番前に変更してください)
  static const String _correctPassword = 'nexa2024beta';
  static const String _storageKey = 'app_authenticated';

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// 認証状態をチェック (ローカルストレージ)
  Future<void> _checkAuthentication() async {
    try {
      // 🔥 β版テスト期間中は自動的に認証済みとして扱う
      setState(() {
        _isAuthenticated = true; // ← パスワード不要で即座にアクセス
        _isLoading = false;
      });
      
      // 元のコード（本番時に復元）:
      // final prefs = await SharedPreferences.getInstance();
      // final isAuthenticated = prefs.getBool(_storageKey) ?? false;
      // setState(() {
      //   _isAuthenticated = isAuthenticated;
      //   _isLoading = false;
      // });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// パスワード検証
  Future<void> _verifyPassword() async {
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.passwordRequired;
      });
      return;
    }

    if (password == _correctPassword) {
      // 認証成功 → ローカルストレージに保存
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_storageKey, true);
        
        setState(() {
          _isAuthenticated = true;
          _errorMessage = null;
        });
      } catch (e) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.save;
        });
      }
    } else {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.incorrectPassword;
      });
    }
  }

  /// 認証解除 (テスト用)
  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      
      setState(() {
        _isAuthenticated = false;
        _passwordController.clear();
        _errorMessage = null;
      });
    } catch (e) {
      // エラー時は無視
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isAuthenticated) {
      // 認証済み → メインアプリを表示
      return widget.child;
    }

    // 未認証 → パスワード入力画面
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ロゴ・アイコン
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // タイトル
                Text(
                  'GYM MATCH',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // サブタイトル
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.general_f62ab22a,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // パスワード入力欄
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.password,
                    hintText: AppLocalizations.of(context)!.password,
                    prefixIcon: const Icon(Icons.vpn_key),
                    border: const OutlineInputBorder(),
                    errorText: _errorMessage,
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _verifyPassword(),
                ),
                const SizedBox(height: 24),

                // ログインボタン
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _verifyPassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(AppLocalizations.of(context)!.gymAccess,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 注意書き
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 20, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.general_4f700ca2,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.password,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
