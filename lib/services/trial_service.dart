import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_service.dart';

/// 無料トライアル管理サービス
/// 
/// パターンA: アクティブユーザー限定7日間プレミアムトライアル
/// 
/// トライアル条件:
/// 1. アカウント登録完了 ✅
/// 2. プロフィール設定完了（身長・体重・目標設定） ✅
/// 3. トレーニング記録を1回以上入力 ✅
/// 4. ジム検索を1回以上実行 ✅
/// 
/// 達成後 → プレミアムプラン7日間無料
/// 未達成 → 無料プランのまま
class TrialService {
  static final TrialService _instance = TrialService._internal();
  factory TrialService() => _instance;
  TrialService._internal();
  
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  // SharedPreferencesキー
  static const String _trialStartedKey = 'trial_started';
  static const String _trialStartDateKey = 'trial_start_date';
  static const String _trialActivatedKey = 'trial_activated';
  
  // Firestoreコレクション
  static const String _usersCollection = 'users';
  static const String _trialProgressCollection = 'trial_progress';
  
  /// トライアル条件達成状況を確認
  Future<Map<String, bool>> checkTrialConditions(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        return {
          'account_created': false,
          'profile_completed': false,
          'first_workout_logged': false,
          'gym_searched': false,
        };
      }
      
      final data = userDoc.data();
      if (data == null) {
        throw Exception(AppLocalizations.of(context)!.gym_c7e47d32);
      }
      
      // 1. アカウント登録完了（ユーザードキュメント存在）
      final accountCreated = true;
      
      // 2. プロフィール設定完了（身長・体重・目標設定）
      final profileCompleted = data['height'] != null && 
                              data['weight'] != null && 
                              data['fitness_goal'] != null;
      
      // 3. トレーニング記録を1回以上入力
      final workoutSnapshot = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(userId)
          .collection('workout_logs')
          .limit(1)
          .get();
      final firstWorkoutLogged = workoutSnapshot.docs.isNotEmpty;
      
      // 4. ジム検索を1回以上実行（trial_progressで追跡）
      final progressDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(userId)
          .collection(_trialProgressCollection)
          .doc('progress')
          .get();
      
      final gymSearched = progressDoc.exists && 
                          progressDoc.data()?['gym_searched'] == true;
      
      return {
        'account_created': accountCreated,
        'profile_completed': profileCompleted,
        'first_workout_logged': firstWorkoutLogged,
        'gym_searched': gymSearched,
      };
      
    } catch (e) {
      print('❌ トライアル条件チェックエラー: $e');
      return {
        'account_created': false,
        'profile_completed': false,
        'first_workout_logged': false,
        'gym_searched': false,
      };
    }
  }
  
  /// すべてのトライアル条件が達成されているか
  Future<bool> areAllConditionsMet(String userId) async {
    final conditions = await checkTrialConditions(userId);
    return conditions.values.every((achieved) => achieved);
  }
  
  /// トライアル達成進捗パーセンテージ
  Future<int> getTrialProgress(String userId) async {
    final conditions = await checkTrialConditions(userId);
    final achievedCount = conditions.values.where((achieved) => achieved).length;
    return ((achievedCount / conditions.length) * 100).round();
  }
  
  /// ジム検索実行を記録
  Future<void> recordGymSearch(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(userId)
          .collection(_trialProgressCollection)
          .doc('progress')
          .set({
        'gym_searched': true,
        'gym_search_date': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('✅ ジム検索記録完了');
      
      // トライアル条件チェック＆自動アクティベート
      await _checkAndActivateTrial(userId);
      
    } catch (e) {
      print('❌ ジム検索記録エラー: $e');
    }
  }
  
  /// トライアル条件を自動チェックしてアクティベート
  Future<void> _checkAndActivateTrial(String userId) async {
    try {
      // 既にトライアル開始済みの場合はスキップ
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_trialActivatedKey) == true) {
        print('ℹ️ トライアル既に開始済み');
        return;
      }
      
      // すべての条件が達成されているか確認
      final allMet = await areAllConditionsMet(userId);
      
      if (allMet) {
        // トライアル自動開始
        await activateTrial(userId);
        print('🎉 トライアル条件達成！自動的にプレミアム7日間トライアル開始');
      }
      
    } catch (e) {
      print('❌ トライアル自動アクティベートエラー: $e');
    }
  }
  
  /// トライアルを開始
  Future<bool> activateTrial(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 既にトライアル開始済みの場合は失敗
      if (prefs.getBool(_trialActivatedKey) == true) {
        print('⚠️ トライアル既に使用済み');
        return false;
      }
      
      // 現在時刻を記録
      final now = DateTime.now();
      await prefs.setBool(_trialActivatedKey, true);
      await prefs.setString(_trialStartDateKey, now.toIso8601String());
      await prefs.setBool(_trialStartedKey, true);
      
      // プレミアムプランに変更
      await _subscriptionService.setPlan(SubscriptionType.premium);
      
      // Firestoreに記録
      await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(userId)
          .update({
        'trial_started_at': FieldValue.serverTimestamp(),
        'trial_plan': 'premium',
        'trial_duration_days': 7,
      });
      
      print('✅ 7日間プレミアムトライアル開始');
      return true;
      
    } catch (e) {
      print('❌ トライアル開始エラー: $e');
      return false;
    }
  }
  
  /// トライアルが有効期限内か確認
  Future<bool> isTrialActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trialStarted = prefs.getBool(_trialStartedKey) ?? false;
      
      if (!trialStarted) {
        return false;
      }
      
      final startDateString = prefs.getString(_trialStartDateKey);
      if (startDateString == null) {
        return false;
      }
      
      final startDate = DateTime.parse(startDateString);
      final now = DateTime.now();
      final difference = now.difference(startDate).inDays;
      
      // 7日間以内であればトライアル有効
      return difference < 7;
      
    } catch (e) {
      print('❌ トライアル有効期限チェックエラー: $e');
      return false;
    }
  }
  
  /// トライアル残り日数を取得
  Future<int> getTrialRemainingDays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trialStarted = prefs.getBool(_trialStartedKey) ?? false;
      
      if (!trialStarted) {
        return 0;
      }
      
      final startDateString = prefs.getString(_trialStartDateKey);
      if (startDateString == null) {
        return 0;
      }
      
      final startDate = DateTime.parse(startDateString);
      final now = DateTime.now();
      final daysPassed = now.difference(startDate).inDays;
      final remainingDays = 7 - daysPassed;
      
      return remainingDays.clamp(0, 7);
      
    } catch (e) {
      print('❌ トライアル残り日数取得エラー: $e');
      return 0;
    }
  }
  
  /// トライアル期限切れをチェックして無料プランに戻す
  Future<void> checkTrialExpiration() async {
    try {
      final isActive = await isTrialActive();
      
      if (!isActive) {
        final prefs = await SharedPreferences.getInstance();
        final trialStarted = prefs.getBool(_trialStartedKey) ?? false;
        
        if (trialStarted) {
          // トライアル期限切れ - 無料プランに戻す
          await _subscriptionService.setPlan(SubscriptionType.free);
          print('⏰ トライアル期限切れ - 無料プランに戻しました');
        }
      }
      
    } catch (e) {
      print('❌ トライアル期限切れチェックエラー: $e');
    }
  }
  
  /// トライアル使用済みか確認
  Future<bool> isTrialUsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trialActivatedKey) ?? false;
  }
  
  /// トライアル状態メッセージを取得
  Future<String> getTrialStatusMessage(String userId) async {
    final isActive = await isTrialActive();
    
    if (isActive) {
      final remainingDays = await getTrialRemainingDays();
      return '🎁 プレミアムトライアル中（残り${remainingDays}日）';
    }
    
    final isUsed = await isTrialUsed();
    if (isUsed) {
      return AppLocalizations.of(context)!.subscription_0da2e903;
    }
    
    final conditions = await checkTrialConditions(userId);
    final progress = await getTrialProgress(userId);
    
    if (progress == 100) {
      return '🎉 トライアル条件達成！プレミアム7日間無料';
    }
    
    return 'トライアル達成進捗: $progress%';
  }
}
