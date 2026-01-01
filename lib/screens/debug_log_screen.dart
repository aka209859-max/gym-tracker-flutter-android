import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// デバッグログ画面（スマホでログを確認するため）
class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  @override
  Widget build(BuildContext context) {
    final logs = DebugLogger.instance.getLogs();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.general_97909b88),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final logText = logs.join('\n');
              Clipboard.setData(ClipboardData(text: logText));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.general_34b10a74),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: AppLocalizations.of(context)!.general_d889d870,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                DebugLogger.instance.clearLogs();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.general_9248af32),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: AppLocalizations.of(context)!.general_a0854d25,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
        ],
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.general_d35250cd,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.save,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                Color bgColor;
                IconData icon;
                
                if (log.contains('❌') || log.contains('ERROR') || log.contains(AppLocalizations.of(context)!.error)) {
                  bgColor = Colors.red.shade50;
                  icon = Icons.error;
                } else if (log.contains('⚠️') || log.contains('WARNING')) {
                  bgColor = Colors.orange.shade50;
                  icon = Icons.warning;
                } else if (log.contains('✅') || log.contains('SUCCESS') || log.contains(AppLocalizations.of(context)!.success)) {
                  bgColor = Colors.green.shade50;
                  icon = Icons.check_circle;
                } else if (log.contains('💾') || log.contains('🔍') || log.contains(AppLocalizations.of(context)!.startDate)) {
                  bgColor = Colors.blue.shade50;
                  icon = Icons.play_arrow;
                } else {
                  bgColor = Colors.grey.shade50;
                  icon = Icons.info;
                }
                
                return Card(
                  color: bgColor,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(icon, size: 20),
                    title: Text(
                      log,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    dense: true,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {});
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}

/// デバッグログ管理クラス（シングルトン）
class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  static DebugLogger get instance => _instance;
  
  DebugLogger._internal();
  
  final List<String> _logs = [];
  final int _maxLogs = 200; // 最大200件まで保持
  
  /// ログを追加
  void log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    
    _logs.add(logEntry);
    
    // 最大件数を超えたら古いログを削除
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    
    // デバッグコンソールにも出力
    print(logEntry);
  }
  
  /// すべてのログを取得
  List<String> getLogs() {
    return List.unmodifiable(_logs);
  }
  
  /// ログをクリア
  void clearLogs() {
    _logs.clear();
  }
}
