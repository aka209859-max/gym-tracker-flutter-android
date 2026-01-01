import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// オンボーディング画面（v1.02強化版）
/// 
/// 初回起動時に表示し、アプリの使い方を案内
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'GYM MATCH へようこそ！',
      description: 'トレーニングを記録して、\nAIがあなた専用のメニューを提案します',
      icon: Icons.fitness_center,
      color: Colors.blue,
      imagePath: null,
    ),
    OnboardingPage(
      title: AppLocalizations.of(context)!.general_b8985d41,
      description: '種目・重量・回数を入力するだけ！\nカレンダーで成長を可視化',
      icon: Icons.edit_note,
      color: Colors.green,
      imagePath: null,
    ),
    OnboardingPage(
      title: 'AI コーチング',
      description: 'Google Gemini 2.0 が\nあなたに最適なメニューを自動生成',
      icon: Icons.smart_toy,
      color: Colors.orange,
      imagePath: null,
    ),
    OnboardingPage(
      title: AppLocalizations.of(context)!.general_08f3d852,
      description: '最初のトレーニングを\n記録してみましょう',
      icon: Icons.rocket_launch,
      color: Colors.purple,
      imagePath: null,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // スキップボタン
            if (_currentPage < _pages.length - 1)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(AppLocalizations.of(context)!.skip,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            
            // ページビュー
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            
            // インジケーター
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildIndicator(index == _currentPage),
                ),
              ),
            ),
            
            // 次へボタン
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? AppLocalizations.of(context)!.next : AppLocalizations.of(context)!.general_81e13f3b,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // アイコン
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: page.color,
            ),
          ),
          const SizedBox(height: 40),
          
          // タイトル
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: page.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          
          // 説明
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? _pages[_currentPage].color : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  /// オンボーディング完了済みかチェック
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  /// オンボーディングを表示すべきかチェック
  static Future<bool> shouldShow() async {
    return !(await isCompleted());
  }
}

/// オンボーディングページデータ
class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? imagePath;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.imagePath,
  });
}
