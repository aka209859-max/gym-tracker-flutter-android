import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

/// PWA インストールプロンプトウィジェット
/// 
/// ユーザーに「ホーム画面に追加」を促すバナーを表示
class InstallPrompt extends StatefulWidget {
  const InstallPrompt({super.key});

  @override
  State<InstallPrompt> createState() => _InstallPromptState();
}

class _InstallPromptState extends State<InstallPrompt> {
  bool _showPrompt = false;
  bool _isInstalled = false;
  
  static const String _dismissedKey = 'install_prompt_dismissed';
  static const String _installCheckKey = 'app_installed';

  @override
  void initState() {
    super.initState();
    _checkInstallStatus();
  }

  Future<void> _checkInstallStatus() async {
    if (!kIsWeb) {
      // ネイティブアプリの場合はプロンプト不要
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // ユーザーが以前に閉じたかチェック
      final dismissed = prefs.getBool(_dismissedKey) ?? false;
      
      // すでにインストール済みかチェック
      final installed = prefs.getBool(_installCheckKey) ?? false;

      if (!dismissed && !installed) {
        setState(() {
          _showPrompt = true;
          _isInstalled = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Install status check error: $e');
      }
    }
  }

  Future<void> _dismissPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dismissedKey, true);
      
      setState(() {
        _showPrompt = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Dismiss prompt error: $e');
      }
    }
  }

  Future<void> _markAsInstalled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_installCheckKey, true);
      
      setState(() {
        _isInstalled = true;
        _showPrompt = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Mark installed error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showPrompt || !kIsWeb) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 8,
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.download_for_offline,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.general_b57ab79a,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.general_06bcf409,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _dismissPrompt,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _dismissPrompt,
                      icon: const Icon(Icons.cancel_outlined),
                      label: Text(AppLocalizations.of(context)!.later),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showInstallInstructions(context);
                      },
                      icon: const Icon(Icons.add_to_home_screen),
                      label: Text(AppLocalizations.of(context)!.general_0d8d60bb),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E88E5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInstallInstructions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.download_for_offline,
                    color: Color(0xFF1E88E5),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.general_c8137971,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInstructionStep(
              1,
              AppLocalizations.of(context)!.general_46f1d23e,
              AppLocalizations.of(context)!.general_0c5f6229,
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              2,
              AppLocalizations.of(context)!.general_7458083c,
              AppLocalizations.of(context)!.general_a07846c5,
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              3,
              AppLocalizations.of(context)!.general_a42b1cc6,
              AppLocalizations.of(context)!.general_c17d5af8,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _markAsInstalled();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  AppLocalizations.of(context)!.general_d2fff453,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int step, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              '$step',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
