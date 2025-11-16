import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'services/offline_service.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';

import 'screens/password_gate_screen.dart';
import 'screens/developer_menu_screen.dart';
import 'providers/gym_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/navigation_provider.dart';
import 'widgets/trial_welcome_dialog.dart';
import 'widgets/admob_banner.dart';
import 'services/subscription_service.dart';
import 'services/admob_service.dart';
import 'services/revenue_cat_service.dart';
import 'services/trial_service.dart';
import 'services/ad_service.dart';
import 'services/interstitial_ad_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 日本語ロケール初期化（日付フォーマット用）
  try {
    await initializeDateFormatting('ja_JP', null);
    print('✅ 日本語ロケール初期化成功');
  } catch (e) {
    print('⚠️ 日本語ロケール初期化失敗（継続可能）: $e');
    // Web環境では失敗する可能性があるが、アプリ起動は継続
  }
  
  // Firebase初期化（エラー時はスキップしてデモモード）
  bool firebaseInitialized = false;
  try {
    // リリースビルドでもログを出力（デバッグ用）
    print('🔥 Firebase初期化開始...');
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    firebaseInitialized = true;
    print('✅ Firebase初期化成功');
    print('   App name: ${Firebase.app().name}');
    
    // 匿名認証を自動実行
    try {
      print('👤 匿名認証を開始...');
      final auth = firebase_auth.FirebaseAuth.instance;
      
      // 既存ユーザーがいるか確認
      if (auth.currentUser == null) {
        print('   新規ユーザーとして匿名ログイン中...');
        final userCredential = await auth.signInAnonymously();
        print('✅ 匿名認証成功: ${userCredential.user?.uid}');
      } else {
        print('✅ 既存ユーザー: ${auth.currentUser?.uid}');
      }
    } catch (authError) {
      print('❌ 匿名認証エラー: $authError');
    }
    
  } catch (e, stackTrace) {
    // Firebase設定エラー時はデモモードで起動
    print('❌ Firebase初期化エラー（デモモードで起動）: $e');
    print('   StackTrace: $stackTrace');
  }
  
  // 🔥 マスターユーザー権限設定（CEO専用）
  await _setMasterUserPrivileges();
  
  // 📱 AdMob初期化（広告表示）
  try {
    await AdService().initialize();
    // インタースティシャル広告を先読み
    InterstitialAdManager().loadAd();
    print('✅ AdMob初期化成功');
  } catch (e) {
    print('❌ AdMob初期化エラー: $e');
  }
  
  // 💾 オフラインサービス初期化（Hive）
  try {
    await OfflineService.initialize();
    print('✅ オフラインサービス初期化成功');
  } catch (e) {
    print('❌ オフラインサービス初期化エラー: $e');
  }
  
  // 💰 RevenueCat初期化（iOS課金統合）
  if (firebaseInitialized) {
    try {
      print('💰 RevenueCat初期化開始...');
      final revenueCatService = RevenueCatService();
      await revenueCatService.initialize();
      print('✅ RevenueCat初期化成功');
    } catch (revenueCatError) {
      print('❌ RevenueCat初期化エラー（ローカルモードで動作）: $revenueCatError');
    }
    
    // 🎁 トライアル期限チェック
    try {
      print('🎁 トライアル期限チェック...');
      final trialService = TrialService();
      await trialService.checkTrialExpiration();
      print('✅ トライアル状態確認完了');
    } catch (trialError) {
      print('❌ トライアルチェックエラー: $trialError');
    }
    
    // 📱 AdMob初期化（無料プラン広告用）
    try {
      print('📱 AdMob初期化...');
      final adMobService = AdMobService();
      await adMobService.initialize();
      print('✅ AdMob初期化完了');
    } catch (adMobError) {
      print('❌ AdMob初期化エラー（広告なしで動作）: $adMobError');
    }
  }
  
  print('🚀 アプリ起動開始 (Firebase: ${firebaseInitialized ? "有効" : "無効"})');
  
  runApp(const GymMatchApp());
}

/// マスターユーザー権限設定（CEO専用）
/// 起動時に自動的にProプランを設定し、全機能をフルアクセス可能にする
Future<void> _setMasterUserPrivileges() async {
  print('👑 マスターユーザー権限設定開始...');
  
  try {
    final subscriptionService = SubscriptionService();
    
    // Proプランに設定（全機能アクセス可能）
    await subscriptionService.setPlan(SubscriptionType.pro);
    
    // マスターユーザーフラグ設定
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_master_user', true);
    
    print('✅ マスターユーザー権限設定完了');
    print('   プラン: Proプラン（全機能フルアクセス）');
    print('   🎯 AI成長予測: ✅');
    print('   🎯 AI効果分析: ✅');
    print('   🎯 AI週次レポート: ✅');
    print('   🎯 トレーニングパートナー: ✅');
    print('   🎯 メッセージング: ✅');
    print('   🎯 優先サポート: ✅');
    
  } catch (e) {
    print('❌ マスターユーザー権限設定失敗: $e');
  }
}

class GymMatchApp extends StatelessWidget {
  const GymMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GymProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'GYM MATCH - ジム検索アプリ',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentTheme,
            
            // スプラッシュスクリーンを初期画面に設定
            home: const SplashScreen(),
            
            // ルート設定
            routes: {
              '/main': (context) => const PasswordGateScreen(
                child: MainScreen(),
              ),
              '/developer_menu': (context) => const DeveloperMenuScreen(),
            },
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _screens = [
    const HomeScreen(),  // トレーニング記録画面（筋トレMEMO風）
    const MapScreen(),  // ジム検索（GPS + リスト表示）
    const ProfileScreen(),  // プロフィール
  ];

  @override
  void initState() {
    super.initState();
    
    // 7日間トライアルは廃止
    // 新システム: 乗り換え割キャンペーン（プロフィール画面からアクセス）
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, child) {
        return Scaffold(
          body: SafeArea(
            child: _screens[navigationProvider.selectedIndex],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AdMobバナー広告（無料プランのみ）
              const AdMobBanner(),
              // ナビゲーションバー
              NavigationBar(
                selectedIndex: navigationProvider.selectedIndex,
                onDestinationSelected: (index) {
                  navigationProvider.selectTab(index);
                },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: '記録',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'ジムマップ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'プロフィール',
          ),
        ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ローディング画面
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('FitSync 起動中...'),
          ],
        ),
      ),
    );
  }
}
