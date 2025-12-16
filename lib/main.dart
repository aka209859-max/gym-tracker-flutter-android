import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_analytics/firebase_analytics.dart';  // ✅ v1.0.164: Analytics追加
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'firebase_options.dart';
import 'services/offline_service.dart';
import 'services/search_cache_service.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/workout/workout_log_screen.dart';
import 'screens/workout/workout_history_screen.dart'; // ✅ v1.0.241: トレーニング履歴タブ
import 'screens/workout/ai_coaching_screen_tabbed.dart';

import 'screens/password_gate_screen.dart';
import 'screens/developer_menu_screen.dart';
import 'screens/workout/workout_memo_list_screen.dart';
import 'screens/workout/add_workout_screen.dart'; // 🔧 v1.0.224: AIコーチ連携
import 'screens/personal_factors_screen.dart';
import 'screens/subscription_screen.dart';
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
import 'services/reward_ad_service.dart';
import 'utils/console_logger.dart';

// 🎬 グローバルリワード広告サービス（全画面で共有）
late RewardAdService globalRewardAdService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // グローバルエラーハンドラー設定（クラッシュ防止）
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      print('❌ Flutter Error: ${details.exception}');
      print('📍 Stack trace: ${details.stack}');
    }
  };
  
  // 非同期エラーのグローバルハンドラー
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      print('❌ Uncaught async error: $error');
      print('📍 Stack trace: $stack');
    }
    return true; // エラーを処理済みとマーク
  };
  
  // ログシステム初期化（最優先 - JS Interop版）
  ConsoleLogger.init();
  
  // 日本語ロケール初期化（日付フォーマット用）
  try {
    await initializeDateFormatting('ja_JP', null);
    ConsoleLogger.info('日本語ロケール初期化成功', tag: 'INIT');
  } catch (e) {
    ConsoleLogger.warn('日本語ロケール初期化失敗（継続可能）', tag: 'INIT');
    // Web環境では失敗する可能性があるが、アプリ起動は継続
  }
  
  // Firebase初期化（エラー時はスキップしてデモモード）
  bool firebaseInitialized = false;
  try {
    ConsoleLogger.info('Firebase初期化開始', tag: 'FIREBASE');
    
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
    
    // ✅ v1.0.164: Firebase Analytics初期化
    try {
      final analytics = FirebaseAnalytics.instance;
      print('📊 Firebase Analytics初期化成功');
      print('   Analytics ID: ${analytics.app.options.projectId}');
      
      // 初回起動イベントを送信
      await analytics.logEvent(
        name: 'app_open',
        parameters: {
          'platform': defaultTargetPlatform.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('✅ Analytics初回イベント送信完了');
    } catch (analyticsError) {
      print('❌ Analytics初期化エラー: $analyticsError');
    }
    
  } catch (e, stackTrace) {
    // Firebase設定エラー時はオフラインモードで起動
    print('❌ Firebase初期化エラー（オフラインモードで起動）: $e');
    print('   StackTrace: $stackTrace');
  }
  
  // 🔥 マスターユーザー権限設定（CEO専用）
  // ✅ 本番環境：マスターユーザー機能を無効化（RevenueCat課金のみ有効）
  // await _setMasterUserPrivileges();
  
  // ✅ 本番環境：無料プランリセットを無効化
  // await _resetToFreePlanForTesting();

  // ATTリクエストは起動後にバックグラウンドで実行（スプラッシュ表示中）
  if (!kIsWeb) {
    Future.delayed(const Duration(milliseconds: 500)).then((_) async {
      try {
        final status = await AppTrackingTransparency.requestTrackingAuthorization();
        print('📱 ATTステータス: $status');
      } catch (e) {
        print('❌ ATTリクエストエラー: $e');
      }
    });
  }
  
  // 📱 AdMob初期化（バックグラウンドで実行、アプリ起動をブロックしない）
  Future.delayed(Duration.zero).then((_) async {
    try {
      await AdService().initialize();
      // インタースティシャル広告を先読み
      InterstitialAdManager().loadAd();
      print('✅ AdMob初期化成功');
    } catch (e) {
      print('❌ AdMob初期化エラー: $e');
    }
  });
  
  // 💾 オフラインサービス初期化（Hive）
  try {
    await OfflineService.initialize();
    print('✅ オフラインサービス初期化成功');
    
    // ✅ v1.0.161: 起動時に同期待ちデータを自動同期
    if (firebaseInitialized) {
      final pendingCount = await OfflineService.getPendingSyncCount();
      if (pendingCount > 0) {
        print('📤 同期待ちデータ: $pendingCount件');
        try {
          await OfflineService.syncPendingData();
          print('✅ オフラインデータ同期完了');
        } catch (e) {
          print('⚠️ 同期エラー（次回リトライ）: $e');
        }
      } else {
        print('📭 同期待ちデータなし');
      }
    }
  } catch (e) {
    print('❌ オフラインサービス初期化エラー: $e');
  }
  
  // 💰 検索キャッシュサービス初期化（Hive - コスト最適化）
  try {
    await SearchCacheService().init();
    print('✅ 検索キャッシュサービス初期化成功（Google Maps API コスト削減）');
  } catch (e) {
    print('❌ 検索キャッシュサービス初期化エラー: $e');
  }
  
  // 💰 RevenueCat・広告・トライアル初期化（バックグラウンドで並列実行）
  if (firebaseInitialized) {
    // 重い初期化処理をバックグラウンドで非同期実行（起動時間を短縮）
    Future.wait([
      // RevenueCat初期化
      Future(() async {
        try {
          print('💰 RevenueCat初期化開始...');
          final revenueCatService = RevenueCatService();
          await revenueCatService.initialize();
          print('✅ RevenueCat初期化成功');
        } catch (e) {
          print('❌ RevenueCat初期化エラー: $e');
        }
      }),
      
      // トライアル期限チェック
      Future(() async {
        try {
          print('🎁 トライアル期限チェック...');
          final trialService = TrialService();
          await trialService.checkTrialExpiration();
          print('✅ トライアル状態確認完了');
        } catch (e) {
          print('❌ トライアルチェックエラー: $e');
        }
      }),
      
      // AdMob初期化
      Future(() async {
        try {
          print('📱 AdMob初期化...');
          final adMobService = AdMobService();
          await adMobService.initialize();
          print('✅ AdMob初期化完了');
        } catch (e) {
          print('❌ AdMob初期化エラー: $e');
        }
      }),
      
      // リワード広告初期化
      Future(() async {
        try {
          print('🎬 リワード広告初期化...');
          globalRewardAdService = RewardAdService();
          await globalRewardAdService.initialize();
          await globalRewardAdService.loadRewardedAd();
          print('✅ リワード広告初期化完了');
        } catch (e) {
          print('❌ リワード広告初期化エラー: $e');
        }
      }),
    ]).then((_) {
      print('✅ バックグラウンド初期化完了');
    });
  }
  
  print('🚀 アプリ起動開始 (Firebase: ${firebaseInitialized ? "有効" : "無効"})');
  
  runApp(const GymMatchApp());
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
              // 開発者メニュー: リリースビルドでは無効化
              if (!kReleaseMode)
                '/developer_menu': (context) => const DeveloperMenuScreen(),
              '/workout-memo': (context) => const WorkoutMemoListScreen(),
              '/personal-factors': (context) => const PersonalFactorsScreen(),
              '/subscription': (context) => const SubscriptionScreen(),
              // 🔧 v1.0.224: AIコーチからのトレーニング記録画面遷移
              '/add-workout': (context) => const AddWorkoutScreen(),
            },
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const SplashScreen(),
              );
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
    const HomeScreen(),  // ホーム（カレンダー・統計・AI提案）
    const WorkoutHistoryScreen(),  // トレーニング履歴（部位別・PR・メモ・週次）
    const AICoachingScreenTabbed(),  // AI機能（メニュー生成・成長予測・効果分析）
    const MapScreen(),  // ジム検索（リアルタイム混雑度）
    const ProfileScreen(),  // プロフィール・設定
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: '履歴',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('AI', style: TextStyle(fontSize: 8)),
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.psychology_outlined),
            ),
            selectedIcon: Badge(
              label: Text('AI', style: TextStyle(fontSize: 8)),
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.psychology),
            ),
            label: 'AI機能',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'ジム検索',
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
