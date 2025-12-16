import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// アプリバージョンチェックサービス
/// 
/// 🎯 機能:
/// - アプリ起動時に最新バージョンをチェック
/// - 古いバージョンの場合、アップデート促進ダイアログを表示
/// - 必須アップデート（強制）と推奨アップデート（任意）をサポート
/// 
/// 💡 使用例:
/// ```dart
/// final versionCheck = await VersionCheckService().checkVersion();
/// if (versionCheck.shouldUpdate) {
///   showUpdateDialog(context, versionCheck);
/// }
/// ```
class VersionCheckService {
  // Firestore コレクション
  static const String _collectionName = 'app_config';
  static const String _documentId = 'version_control';

  /// アプリバージョンをチェック
  /// 
  /// Firestoreから最新バージョン情報を取得し、現在のバージョンと比較
  Future<VersionCheckResult> checkVersion() async {
    try {
      // 現在のアプリバージョンを取得
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // 例: "1.0.112"
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0; // 例: 112

      if (kDebugMode) {
        print('📱 現在のバージョン: $currentVersion (Build: $currentBuildNumber)');
      }

      // Firestoreから最新バージョン情報を取得
      final doc = await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(_documentId)
          .get();

      if (!doc.exists) {
        if (kDebugMode) {
          print('⚠️ バージョン管理ドキュメントが存在しません');
        }
        return VersionCheckResult(
          shouldUpdate: false,
          isForceUpdate: false,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
        );
      }

      final data = doc.data()!;
      
      // 最小必須バージョン（これより古い場合は強制アップデート）
      final minVersion = data['min_version'] as String?; // 例: "1.0.100"
      final minBuildNumber = data['min_build_number'] as int?; // 例: 100
      
      // 推奨バージョン（これより古い場合はアップデート推奨）
      final recommendedVersion = data['recommended_version'] as String?; // 例: "1.0.112"
      final recommendedBuildNumber = data['recommended_build_number'] as int?; // 例: 112
      
      // アップデートメッセージ
      final updateMessage = data['update_message'] as String? ?? 
          '新しいバージョンが利用可能です。\nアップデートをお願いします。';
      final forceUpdateMessage = data['force_update_message'] as String? ?? 
          '必須アップデートがあります。\nアプリを最新版に更新してください。';
      
      // App Store URL（iOS用）
      final appStoreUrl = data['app_store_url'] as String? ?? 
          'https://apps.apple.com/jp/app/gym-match/id6736888311'; // TODO: 実際のURLに置き換え

      if (kDebugMode) {
        print('🔍 最小バージョン: $minVersion (Build: $minBuildNumber)');
        print('🔍 推奨バージョン: $recommendedVersion (Build: $recommendedBuildNumber)');
      }

      // 強制アップデートチェック（最小バージョンより古い）
      if (minBuildNumber != null && currentBuildNumber < minBuildNumber) {
        if (kDebugMode) {
          print('🚨 強制アップデートが必要: $currentBuildNumber < $minBuildNumber');
        }
        return VersionCheckResult(
          shouldUpdate: true,
          isForceUpdate: true,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          latestVersion: minVersion ?? recommendedVersion,
          latestBuildNumber: minBuildNumber ?? recommendedBuildNumber,
          updateMessage: forceUpdateMessage,
          appStoreUrl: appStoreUrl,
        );
      }

      // 推奨アップデートチェック（推奨バージョンより古い）
      if (recommendedBuildNumber != null && currentBuildNumber < recommendedBuildNumber) {
        if (kDebugMode) {
          print('💡 アップデート推奨: $currentBuildNumber < $recommendedBuildNumber');
        }
        return VersionCheckResult(
          shouldUpdate: true,
          isForceUpdate: false,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          latestVersion: recommendedVersion,
          latestBuildNumber: recommendedBuildNumber,
          updateMessage: updateMessage,
          appStoreUrl: appStoreUrl,
        );
      }

      // アップデート不要
      if (kDebugMode) {
        print('✅ アプリは最新版です');
      }
      return VersionCheckResult(
        shouldUpdate: false,
        isForceUpdate: false,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        latestVersion: recommendedVersion,
        latestBuildNumber: recommendedBuildNumber,
      );

    } catch (e) {
      if (kDebugMode) {
        print('❌ バージョンチェックエラー: $e');
      }
      // エラー時はアップデート不要として扱う（アプリを使えなくしない）
      final packageInfo = await PackageInfo.fromPlatform();
      return VersionCheckResult(
        shouldUpdate: false,
        isForceUpdate: false,
        currentVersion: packageInfo.version,
        currentBuildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
        error: e.toString(),
      );
    }
  }

  /// Firestoreのバージョン管理ドキュメントを作成/更新（管理者用）
  /// 
  /// 💡 使用例（開発者メニューから実行）:
  /// ```dart
  /// await VersionCheckService().updateVersionControl(
  ///   minVersion: '1.0.100',
  ///   minBuildNumber: 100,
  ///   recommendedVersion: '1.0.112',
  ///   recommendedBuildNumber: 112,
  /// );
  /// ```
  Future<void> updateVersionControl({
    String? minVersion,
    int? minBuildNumber,
    String? recommendedVersion,
    int? recommendedBuildNumber,
    String? updateMessage,
    String? forceUpdateMessage,
    String? appStoreUrl,
  }) async {
    try {
      final data = <String, dynamic>{};
      
      if (minVersion != null) data['min_version'] = minVersion;
      if (minBuildNumber != null) data['min_build_number'] = minBuildNumber;
      if (recommendedVersion != null) data['recommended_version'] = recommendedVersion;
      if (recommendedBuildNumber != null) data['recommended_build_number'] = recommendedBuildNumber;
      if (updateMessage != null) data['update_message'] = updateMessage;
      if (forceUpdateMessage != null) data['force_update_message'] = forceUpdateMessage;
      if (appStoreUrl != null) data['app_store_url'] = appStoreUrl;
      
      data['updated_at'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(_documentId)
          .set(data, SetOptions(merge: true));

      if (kDebugMode) {
        print('✅ バージョン管理情報を更新しました: $data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ バージョン管理情報の更新エラー: $e');
      }
      rethrow;
    }
  }
}

/// バージョンチェック結果
class VersionCheckResult {
  /// アップデートが必要か
  final bool shouldUpdate;
  
  /// 強制アップデートか（trueの場合、アプリ使用を制限）
  final bool isForceUpdate;
  
  /// 現在のバージョン
  final String currentVersion;
  
  /// 現在のビルド番号
  final int currentBuildNumber;
  
  /// 最新バージョン
  final String? latestVersion;
  
  /// 最新ビルド番号
  final int? latestBuildNumber;
  
  /// アップデートメッセージ
  final String? updateMessage;
  
  /// App Store URL
  final String? appStoreUrl;
  
  /// エラーメッセージ
  final String? error;

  VersionCheckResult({
    required this.shouldUpdate,
    required this.isForceUpdate,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.latestVersion,
    this.latestBuildNumber,
    this.updateMessage,
    this.appStoreUrl,
    this.error,
  });

  /// デバッグ用文字列
  @override
  String toString() {
    return 'VersionCheckResult('
        'shouldUpdate: $shouldUpdate, '
        'isForceUpdate: $isForceUpdate, '
        'current: $currentVersion ($currentBuildNumber), '
        'latest: $latestVersion ($latestBuildNumber), '
        'error: $error'
        ')';
  }
}
