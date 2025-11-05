import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Layer 5: AIコーチング画面
/// 
/// 機能:
/// - Gemini 2.0 Flash APIでトレーニングメニュー提案
/// - 部位選択UI（チップ式）
/// - メニュー保存・履歴表示
class AICoachingScreen extends StatefulWidget {
  const AICoachingScreen({super.key});

  @override
  State<AICoachingScreen> createState() => _AICoachingScreenState();
}

class _AICoachingScreenState extends State<AICoachingScreen> {
  // 部位選択状態（有酸素・初心者追加）
  final Map<String, bool> _selectedBodyParts = {
    '胸': false,
    '背中': false,
    '脚': false,
    '肩': false,
    '腕': false,
    '体幹': false,
    '有酸素': false,
    '初心者': false,
  };

  // UI状態
  bool _isGenerating = false;
  String? _generatedMenu;
  String? _errorMessage;
  
  // 履歴
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _autoLoginIfNeeded();
    _loadHistory();
  }

  /// 未ログイン時に自動的に匿名ログイン
  Future<void> _autoLoginIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        debugPrint('✅ 匿名認証成功');
      } catch (e) {
        debugPrint('❌ 匿名認証エラー: $e');
      }
    }
  }

  /// 履歴読み込み
  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('aiCoachingHistory')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      setState(() {
        _history = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint('❌ 履歴読み込みエラー: $e');
      setState(() => _isLoadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('AIコーチング')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('AIコーチング')),
            body: const Center(child: Text('ログインに失敗しました')),
          );
        }

        return _buildMainContent(user);
      },
    );
  }

  Widget _buildMainContent(User user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIコーチング'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
            tooltip: '使い方',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 説明文
            _buildDescription(),
            const SizedBox(height: 24),

            // 部位選択
            _buildBodyPartSelector(),
            const SizedBox(height: 24),

            // メニュー生成ボタン
            _buildGenerateButton(),
            const SizedBox(height: 24),

            // 生成結果表示
            if (_generatedMenu != null) ...[
              _buildGeneratedMenu(),
              const SizedBox(height: 24),
            ],

            // エラー表示
            if (_errorMessage != null) ...[
              _buildErrorMessage(),
              const SizedBox(height: 24),
            ],

            // 履歴表示
            _buildHistory(),
          ],
        ),
      ),
    );
  }

  /// 説明文
  Widget _buildDescription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'AI powered トレーニング提案',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'トレーニングしたい部位を選択すると、AIが最適なメニューを提案します。',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// 部位選択セクション
  Widget _buildBodyPartSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'トレーニング部位を選択',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedBodyParts.keys.map((part) {
            final isSelected = _selectedBodyParts[part]!;
            final isBeginner = part == '初心者';
            
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isBeginner) ...[
                    const Icon(Icons.school, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                  ],
                  Text(part),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedBodyParts[part] = selected;
                });
              },
              selectedColor: isBeginner 
                  ? Colors.green.shade100 
                  : Colors.blue.shade100,
              checkmarkColor: isBeginner 
                  ? Colors.green.shade700 
                  : Colors.blue.shade700,
              backgroundColor: isBeginner 
                  ? Colors.green.shade50 
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  /// メニュー生成ボタン
  Widget _buildGenerateButton() {
    final selectedParts = _selectedBodyParts.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final isEnabled = selectedParts.isNotEmpty && !_isGenerating;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? () => _generateMenu(selectedParts) : null,
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(_isGenerating ? 'AIが考え中...' : 'メニューを生成'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  /// 生成されたメニュー表示
  Widget _buildGeneratedMenu() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '提案されたメニュー',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveMenu,
                  tooltip: '保存',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildFormattedText(_generatedMenu!),
          ],
        ),
      ),
    );
  }

  /// エラーメッセージ表示
  Widget _buildErrorMessage() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 履歴表示
  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '過去の提案',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingHistory)
          const Center(child: CircularProgressIndicator())
        else if (_history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('まだ履歴がありません'),
              ),
            ),
          )
        else
          ..._history.map((item) => _buildHistoryItem(item)),
      ],
    );
  }

  /// 履歴アイテム
  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final bodyParts = (item['bodyParts'] as List<dynamic>?)?.join(', ') ?? '';
    final createdAt = (item['createdAt'] as Timestamp?)?.toDate();
    final menu = item['menu'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(bodyParts),
        subtitle: Text(
          createdAt != null
              ? '${createdAt.month}/${createdAt.day} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
              : '',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFormattedText(menu),
          ),
        ],
      ),
    );
  }

  /// Markdown形式テキストをフォーマット済みウィジェットに変換
  /// 
  /// 変換ルール:
  /// - `## 見出し` → 太字見出し（##は削除）
  /// - `**太字**` → 太字テキスト
  /// - `* 箇条書き` → `・箇条書き`
  Widget _buildFormattedText(String text) {
    final lines = text.split('\n');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      // 1. 見出し処理（## Text → 太字テキスト）
      if (line.trim().startsWith('##')) {
        final headingText = line.replaceFirst(RegExp(r'^##\s*'), '');
        spans.add(
          TextSpan(
            text: headingText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.8,
            ),
          ),
        );
        if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
        continue;
      }

      // 2. 箇条書き処理（* → ・）
      if (line.trim().startsWith('*')) {
        line = line.replaceFirst(RegExp(r'^\*\s*'), '・');
      }

      // 3. 太字処理（**text** → 太字）
      final boldPattern = RegExp(r'\*\*(.+?)\*\*');
      final matches = boldPattern.allMatches(line);

      if (matches.isEmpty) {
        // 太字なし → 通常テキスト
        spans.add(TextSpan(text: line));
      } else {
        // 太字あり → パースして分割
        int lastIndex = 0;
        for (final match in matches) {
          // 太字前のテキスト
          if (match.start > lastIndex) {
            spans.add(TextSpan(text: line.substring(lastIndex, match.start)));
          }
          // 太字テキスト
          spans.add(
            TextSpan(
              text: match.group(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
          lastIndex = match.end;
        }
        // 太字後のテキスト
        if (lastIndex < line.length) {
          spans.add(TextSpan(text: line.substring(lastIndex)));
        }
      }

      // 改行追加（最終行以外）
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.black87,
        ),
        children: spans,
      ),
    );
  }

  /// AIメニュー生成
  Future<void> _generateMenu(List<String> bodyParts) async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generatedMenu = null;
    });

    try {
      debugPrint('🤖 Gemini APIでメニュー生成開始: ${bodyParts.join(', ')}');

      // Gemini 2.0 Flash API呼び出し
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=AIzaSyA9XmQSHA1llGg7gihqjmOOIaLA856fkLc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': _buildPrompt(bodyParts),
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 2048,  // 初心者向け詳細メニューに対応（1024→2048）
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;

        setState(() {
          _generatedMenu = text;
          _isGenerating = false;
        });

        debugPrint('✅ メニュー生成成功');
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ メニュー生成エラー: $e');
      setState(() {
        _errorMessage = 'メニュー生成に失敗しました: $e';
        _isGenerating = false;
      });
    }
  }

  /// プロンプト構築
  String _buildPrompt(List<String> bodyParts) {
    // 初心者モード判定
    final isBeginner = bodyParts.contains('初心者');
    
    // 初心者以外の部位を抽出
    final targetParts = bodyParts.where((part) => part != '初心者').toList();
    
    if (isBeginner) {
      // 初心者向け専用プロンプト
      if (targetParts.isEmpty) {
        // 初心者のみ選択 → 全身トレーニング
        return '''
あなたはプロのパーソナルトレーナーです。筋トレ初心者向けの全身トレーニングメニューを提案してください。

【対象者】
- 筋トレ初心者（ジム通い始めて1〜3ヶ月程度）
- 基礎体力づくりを目指す方
- トレーニングフォームを学びたい方

【提案形式】
各種目について以下の情報を含めてください：
- 種目名
- セット数（少なめ: 2-3セット）
- 回数（軽い重量で: 10-15回）
- 休憩時間（長め: 90-120秒）
- 初心者向けフォームのポイント
- よくある間違いと注意事項

【条件】
- 全身をバランスよく鍛える（胸・背中・脚・肩・腕）
- 基本種目中心（マシンとフリーウェイト組み合わせ）
- 30-45分で完了
- 怪我のリスクが少ない種目
- フォーム習得を重視
- 日本語で丁寧に説明

初心者が安全に取り組める全身トレーニングメニューを提案してください。
''';
      } else {
        // 初心者 + 部位指定 → その部位に特化した初心者メニュー
        return '''
あなたはプロのパーソナルトレーナーです。筋トレ初心者向けの「${targetParts.join('、')}」トレーニングメニューを提案してください。

【対象者】
- 筋トレ初心者（ジム通い始めて1〜3ヶ月程度）
- ${targetParts.join('、')}を重点的に鍛えたい方
- トレーニングフォームを学びたい方

【提案形式】
各種目について以下の情報を含めてください：
- 種目名
- セット数（少なめ: 2-3セット）
- 回数（軽い重量で: 10-15回）
- 休憩時間（長め: 90-120秒）
- 初心者向けフォームのポイント
- よくある間違いと注意事項

【条件】
- ${targetParts.join('、')}を重点的にトレーニング
- 基本種目中心（マシンとフリーウェイト組み合わせ）
- 30-45分で完了
- 怪我のリスクが少ない種目
- フォーム習得を重視
- 日本語で丁寧に説明

初心者が安全に取り組める${targetParts.join('、')}トレーニングメニューを提案してください。
''';
      }
    } else {
      // 通常モード（初心者選択なし）
      return '''
あなたはプロのパーソナルトレーナーです。以下の部位をトレーニングするための最適なメニューを提案してください。

【トレーニング部位】
${bodyParts.join('、')}

【提案形式】
各種目について以下の情報を含めてください：
- 種目名
- セット数
- 回数
- 休憩時間
- ポイント・注意事項

【条件】
- 初心者〜中級者向け
- ジムで実施可能
- 45-60分で完了
- 効率的に鍛えられる
- 日本語で簡潔に

メニューを提案してください。
''';
    }
  }

  /// メニュー保存
  Future<void> _saveMenu() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _generatedMenu == null) return;

      final selectedParts = _selectedBodyParts.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('aiCoachingHistory')
          .add({
        'bodyParts': selectedParts,
        'menu': _generatedMenu,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('メニューを保存しました'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 履歴を再読み込み
      _loadHistory();

      debugPrint('✅ メニュー保存成功');
    } catch (e) {
      debugPrint('❌ メニュー保存エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 使い方ダイアログ
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AIコーチングについて'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🤖 AIがトレーニングメニューを提案',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'トレーニングしたい部位を選択すると、Gemini 2.0 Flash AIが最適なメニューを提案します。',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                '💾 メニューを保存',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '気に入ったメニューは保存して、後から見返すことができます。',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                '📜 履歴表示',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '過去の提案を確認して、トレーニングのバリエーションを増やしましょう。',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
