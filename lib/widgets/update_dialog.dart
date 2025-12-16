import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/version_check_service.dart';

/// アップデート促進ダイアログ
/// 
/// 🎯 機能:
/// - 推奨アップデート: 「後で」ボタンあり
/// - 必須アップデート: 「今すぐアップデート」のみ（戻るボタン無効）
class UpdateDialog extends StatelessWidget {
  final VersionCheckResult versionCheck;

  const UpdateDialog({
    super.key,
    required this.versionCheck,
  });

  /// ダイアログを表示
  static Future<void> show(
    BuildContext context,
    VersionCheckResult versionCheck,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: !versionCheck.isForceUpdate, // 強制の場合は背景タップで閉じない
      builder: (context) => UpdateDialog(versionCheck: versionCheck),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !versionCheck.isForceUpdate, // 強制の場合は戻るボタン無効
      child: AlertDialog(
        title: const Text(
          '最新バージョンに更新',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '新しいバージョンのアプリが利用可能です。最新バージョンにアップデートしてください。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actions: [
          // 強制アップデートのみ「OK」ボタン
          Center(
            child: TextButton(
              onPressed: () async {
                final url = versionCheck.appStoreUrl;
                if (url != null) {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('App Storeを開けませんでした'),
                        ),
                      );
                    }
                  }
                }
                // 強制アップデートの場合はダイアログを閉じない
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
