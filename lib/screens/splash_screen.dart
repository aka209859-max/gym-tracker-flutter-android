import 'package:flutter/material.dart';
import 'dart:async';
import '../services/onboarding_service.dart';
import '../services/version_check_service.dart';
import '../widgets/update_dialog.dart';
import 'onboarding/onboarding_screen.dart';

/// スプラッシュスクリーン
/// 
/// アプリ起動時にロゴをアニメーション表示し、
/// 初回起動判定後、オンボーディングまたはホーム画面に遷移します
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  final OnboardingService _onboardingService = OnboardingService();

  @override
  void initState() {
    super.initState();
    
    // アニメーションコントローラーの初期化
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // スケールアニメーション（パンッと拡大）
    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    // 透明度アニメーション（フェードイン）
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    // アニメーション開始
    _animationController.forward();

    // 2秒後に初回起動判定 → バージョンチェック → オンボーディングorホーム画面に遷移
    Timer(const Duration(seconds: 2), () async {
      if (mounted) {
        // 🔍 バージョンチェック
        final versionCheck = await VersionCheckService().checkVersion();
        
        if (!mounted) return;
        
        // アップデートが必要な場合、ダイアログを表示
        if (versionCheck.shouldUpdate) {
          await UpdateDialog.show(context, versionCheck);
          
          // 強制アップデートの場合はここで終了（ホーム画面に進まない）
          if (versionCheck.isForceUpdate) {
            return;
          }
        }
        
        if (!mounted) return;
        
        // 初回起動判定
        final isCompleted = await _onboardingService.isOnboardingCompleted();
        
        if (!mounted) return;
        
        if (isCompleted) {
          // 既存ユーザー → ホーム画面へ
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          // 初回ユーザー → オンボーディング画面へ
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const OnboardingScreen(),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27), // 濃いネイビー背景
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ロゴ画像
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Image.asset(
                          'assets/images/splash_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // アプリ名（オプション）
                    const Text(
                      'GYM MATCH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // タグライン
                    Text(
                      'あなたに最適なトレーニングを',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
