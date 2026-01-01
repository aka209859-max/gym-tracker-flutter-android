import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gen/app_localizations.dart';
import '../providers/locale_provider.dart';

/// 言語設定画面
/// 
/// サポート言語（6言語）から選択して、アプリの表示言語を変更できます
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currentLocale = localeProvider.locale;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.languageSettings ?? AppLocalizations.of(context)!.languageSettings),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: LocaleProvider.supportedLocales.length,
        itemBuilder: (context, index) {
          final localeInfo = LocaleProvider.supportedLocales[index];
          final isSelected = currentLocale.languageCode == localeInfo.locale.languageCode;

          return ListTile(
            leading: Text(
              localeInfo.flag,
              style: const TextStyle(fontSize: 32),
            ),
            title: Text(
              localeInfo.nativeName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              localeInfo.name,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isSelected
                ? const Icon(
                    Icons.check_circle,
                    color: Colors.blue,
                  )
                : null,
            onTap: () async {
              // 言語を変更
              await localeProvider.setLocale(localeInfo.locale);
              
              if (context.mounted) {
                // ダイアログで再起動を促す
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => AlertDialog(
                    title: Row(
                      children: [
                        Text(localeInfo.flag, style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.profile_5501a97a,
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${localeInfo.nativeName}に変更されました。',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          AppLocalizations.of(context)!.profile_510d373d,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          // ダイアログを閉じる
                          Navigator.of(dialogContext).pop();
                          // 言語設定画面を閉じる
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          AppLocalizations.of(context)!.ok,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(
            top: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 48, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              'GYM MATCH - 6言語対応',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.profile_21abb17c,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
