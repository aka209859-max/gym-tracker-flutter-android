import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/ai_prediction_service.dart';
import '../../services/training_analysis_service.dart';
import '../../widgets/scientific_citation_card.dart';

/// Layer 5: AIコーチング画面（統合版）
/// 
/// 機能:
/// - Tab 1: AIトレーニングメニュー提案（既存機能）
/// - Tab 2: AI成長予測（科学的根拠ベース）
/// - Tab 3: トレーニング効果分析
class AICoachingScreenTabbed extends StatefulWidget {
  final int initialTabIndex;

  const AICoachingScreenTabbed({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<AICoachingScreenTabbed> createState() => _AICoachingScreenTabbedState();
}

class _AICoachingScreenTabbedState extends State<AICoachingScreenTabbed>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _autoLoginIfNeeded();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 24),
            SizedBox(width: 8),
            Text('AI科学的コーチング'),
          ],
        ),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.fitness_center),
              text: 'メニュー提案',
            ),
            Tab(
              icon: Icon(Icons.timeline),
              text: '成長予測',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: '効果分析',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: AIメニュー提案（既存機能）
          _AIMenuTab(user: user),
          // Tab 2: 成長予測
          _GrowthPredictionTab(),
          // Tab 3: 効果分析
          _EffectAnalysisTab(),
        ],
      ),
    );
  }
}

// ========================================
// Tab 1: AIメニュー提案タブ
// ========================================

class _AIMenuTab extends StatefulWidget {
  final User user;

  const _AIMenuTab({required this.user});

  @override
  State<_AIMenuTab> createState() => _AIMenuTabState();
}

class _AIMenuTabState extends State<_AIMenuTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
    _loadHistory();
  }

  /// 履歴読み込み
  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
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
    super.build(context);
    return SingleChildScrollView(
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
              backgroundColor: isBeginner ? Colors.green.shade50 : null,
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
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=AIzaSyA9XmQSHA1llGg7gihqjmOOIaLA856fkLc'),
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
            'maxOutputTokens': 2048,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;

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
      if (_generatedMenu == null) return;

      final selectedParts = _selectedBodyParts.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
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
}

// ========================================
// Tab 2: 成長予測タブ
// ========================================

class _GrowthPredictionTab extends StatefulWidget {
  @override
  State<_GrowthPredictionTab> createState() => _GrowthPredictionTabState();
}

class _GrowthPredictionTabState extends State<_GrowthPredictionTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // フォーム入力値
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController(text: '60');
  String _selectedLevel = '初心者';
  int _selectedFrequency = 3;
  String _selectedGender = '女性';
  int _selectedAge = 25;
  String _selectedBodyPart = '大胸筋';

  // 予測結果
  Map<String, dynamic>? _predictionResult;
  bool _isLoading = false;

  // レベル選択肢
  final List<String> _levels = ['初心者', '中級者', '上級者'];

  // 部位選択肢
  final List<String> _bodyParts = [
    '大胸筋',
    '広背筋',
    '大腿四頭筋',
    '上腕二頭筋',
    '上腕三頭筋',
    '三角筋',
  ];

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  /// 成長予測を実行
  Future<void> _executePrediction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _predictionResult = null;
    });

    try {
      final result = await AIPredictionService.predictGrowth(
        currentWeight: double.parse(_weightController.text),
        level: _selectedLevel,
        frequency: _selectedFrequency,
        gender: _selectedGender,
        age: _selectedAge,
        bodyPart: _selectedBodyPart,
        monthsAhead: 4,
      );

      setState(() {
        _predictionResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('予測の生成に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー
            _buildHeader(),
            const SizedBox(height: 24),

            // 入力フォーム
            _buildInputForm(),
            const SizedBox(height: 24),

            // 予測実行ボタン
            _buildPredictButton(),
            const SizedBox(height: 32),

            // 予測結果
            if (_isLoading)
              _buildLoadingIndicator()
            else if (_predictionResult != null)
              _buildPredictionResult(),
          ],
        ),
      ),
    );
  }

  /// ヘッダー
  Widget _buildHeader() {
    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.timeline, size: 40, color: Colors.purple.shade700),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI成長予測',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '40本以上の論文に基づく科学的予測',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 入力フォーム
  Widget _buildInputForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'あなたの情報を入力',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 対象部位
            _buildDropdownField(
              label: '対象部位',
              value: _selectedBodyPart,
              items: _bodyParts,
              onChanged: (value) {
                setState(() {
                  _selectedBodyPart = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 現在の1RM
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: '現在の1RM (kg)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fitness_center),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '1RMを入力してください';
                }
                final weight = double.tryParse(value);
                if (weight == null) {
                  return '数値を入力してください';
                }
                if (weight <= 0) {
                  return '1kg以上を入力してください';
                }
                if (weight > 500) {
                  return '500kg以下を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // トレーニングレベル
            _buildDropdownField(
              label: 'トレーニングレベル',
              value: _selectedLevel,
              items: _levels,
              onChanged: (value) {
                setState(() {
                  _selectedLevel = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // トレーニング頻度
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderField(
                  label: 'この部位のトレーニング頻度',
                  value: _selectedFrequency.toDouble(),
                  min: 1,
                  max: 6,
                  divisions: 5,
                  onChanged: (value) {
                    setState(() {
                      _selectedFrequency = value.toInt();
                    });
                  },
                  displayValue: '週${_selectedFrequency}回',
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ 選択した部位（$_selectedBodyPart）を週に何回トレーニングするか',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 性別
            _buildDropdownField(
              label: '性別',
              value: _selectedGender,
              items: ['男性', '女性'],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 年齢
            _buildSliderField(
              label: '年齢',
              value: _selectedAge.toDouble(),
              min: 18,
              max: 70,
              divisions: 52,
              onChanged: (value) {
                setState(() {
                  _selectedAge = value.toInt();
                });
              },
              displayValue: '${_selectedAge}歳',
            ),
          ],
        ),
      ),
    );
  }

  /// ドロップダウンフィールド
  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      value: value,
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  /// スライダーフィールド
  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String displayValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: Colors.purple.shade700,
        ),
      ],
    );
  }

  /// 予測実行ボタン
  Widget _buildPredictButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _executePrediction,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.auto_graph),
      label: Text(_isLoading ? 'AI分析中...' : '成長予測を実行'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// ローディングインジケーター
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('AIが科学的根拠に基づいて分析中...'),
        ],
      ),
    );
  }

  /// 予測結果表示
  Widget _buildPredictionResult() {
    final result = _predictionResult!;
    final curve = result['curve'] as List<Map<String, dynamic>>;
    final scientificBasis = result['scientificBasis'] as String;
    final citations = result['citations'] as List<Map<String, dynamic>>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 予測カード
        Card(
          color: Colors.purple.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 4ヶ月後の予測',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900,
                  ),
                ),
                const SizedBox(height: 16),
                ...curve.map((point) {
                  final month = point['month'] as int;
                  final predicted = point['predicted'] as double;
                  final lower = point['confidenceLower'] as double;
                  final upper = point['confidenceUpper'] as double;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${month}ヶ月後',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${predicted.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                            Text(
                              '信頼区間: ${lower.toStringAsFixed(1)}-${upper.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 科学的根拠
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔬 科学的根拠',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  scientificBasis,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 引用論文
        if (citations.isNotEmpty) ...[
          const Text(
            '📚 参考文献',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...citations.map((citation) {
            return ScientificCitationCard(
              citation: citation['citation'] as String,
              finding: citation['finding'] as String,
              effectSize: citation['effectSize'] as String,
            );
          }),
        ],
      ],
    );
  }
}

// ========================================
// Tab 3: 効果分析タブ
// ========================================

class _EffectAnalysisTab extends StatefulWidget {
  @override
  State<_EffectAnalysisTab> createState() => _EffectAnalysisTabState();
}

class _EffectAnalysisTabState extends State<_EffectAnalysisTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // フォーム入力値
  final _formKey = GlobalKey<FormState>();
  String _selectedBodyPart = '大胸筋';
  int _currentSets = 12;
  int _currentFrequency = 2;
  String _selectedLevel = '中級者';
  String _selectedGender = '女性';
  int _selectedAge = 25;

  // 分析結果
  Map<String, dynamic>? _analysisResult;
  bool _isLoading = false;

  // 部位選択肢
  final List<String> _bodyParts = [
    '大胸筋',
    '広背筋',
    '大腿四頭筋',
    '上腕二頭筋',
    '上腕三頭筋',
    '三角筋',
  ];

  // レベル選択肢
  final List<String> _levels = ['初心者', '中級者', '上級者'];

  /// 効果分析を実行
  Future<void> _executeAnalysis() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _analysisResult = null;
    });

    try {
      final result = await TrainingAnalysisService.analyzeTrainingEffect(
        bodyPart: _selectedBodyPart,
        currentSetsPerWeek: _currentSets,
        currentFrequency: _currentFrequency,
        level: _selectedLevel,
        gender: _selectedGender,
        age: _selectedAge,
        recentHistory: [], // 空リストで提供（履歴なし）
      );

      setState(() {
        _analysisResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析の生成に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー
            _buildHeader(),
            const SizedBox(height: 24),

            // 入力フォーム
            _buildInputForm(),
            const SizedBox(height: 24),

            // 分析実行ボタン
            _buildAnalyzeButton(),
            const SizedBox(height: 32),

            // 分析結果
            if (_isLoading)
              _buildLoadingIndicator()
            else if (_analysisResult != null)
              _buildAnalysisResult(),
          ],
        ),
      ),
    );
  }

  /// ヘッダー
  Widget _buildHeader() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.analytics, size: 40, color: Colors.orange.shade700),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'トレーニング効果分析',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '最適なボリュームと頻度を科学的に分析',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 入力フォーム
  Widget _buildInputForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '現在のトレーニング状況',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 対象部位
            _buildDropdownField(
              label: '対象部位',
              value: _selectedBodyPart,
              items: _bodyParts,
              onChanged: (value) {
                setState(() {
                  _selectedBodyPart = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 週あたりセット数
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderField(
                  label: 'この部位の週あたりセット数',
                  value: _currentSets.toDouble(),
                  min: 4,
                  max: 24,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() {
                      _currentSets = value.toInt();
                    });
                  },
                  displayValue: '${_currentSets}セット',
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ $_selectedBodyPart のトレーニングで週に実施する総セット数',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // トレーニング頻度
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderField(
                  label: 'この部位のトレーニング頻度',
                  value: _currentFrequency.toDouble(),
                  min: 1,
                  max: 6,
                  divisions: 5,
                  onChanged: (value) {
                    setState(() {
                      _currentFrequency = value.toInt();
                    });
                  },
                  displayValue: '週${_currentFrequency}回',
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ $_selectedBodyPart を週に何回トレーニングするか',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // トレーニングレベル
            _buildDropdownField(
              label: 'トレーニングレベル',
              value: _selectedLevel,
              items: _levels,
              onChanged: (value) {
                setState(() {
                  _selectedLevel = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 性別
            _buildDropdownField(
              label: '性別',
              value: _selectedGender,
              items: ['男性', '女性'],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 年齢
            _buildSliderField(
              label: '年齢',
              value: _selectedAge.toDouble(),
              min: 18,
              max: 70,
              divisions: 52,
              onChanged: (value) {
                setState(() {
                  _selectedAge = value.toInt();
                });
              },
              displayValue: '${_selectedAge}歳',
            ),
          ],
        ),
      ),
    );
  }

  /// ドロップダウンフィールド
  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      value: value,
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  /// スライダーフィールド
  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String displayValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: Colors.orange.shade700,
        ),
      ],
    );
  }

  /// 分析実行ボタン
  Widget _buildAnalyzeButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _executeAnalysis,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.auto_graph),
      label: Text(_isLoading ? 'AI分析中...' : '効果を分析'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// ローディングインジケーター
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('AIが最適なプログラムを分析中...'),
        ],
      ),
    );
  }

  /// 分析結果表示
  Widget _buildAnalysisResult() {
    final result = _analysisResult!;
    final analysis = result['analysis'] as String;
    final citations = result['citations'] as List<Map<String, dynamic>>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 分析結果カード
        Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 AI分析結果',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  analysis,
                  style: const TextStyle(fontSize: 14, height: 1.8),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 引用論文
        if (citations.isNotEmpty) ...[
          const Text(
            '📚 科学的根拠',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...citations.map((citation) {
            return ScientificCitationCard(
              citation: citation['citation'] as String,
              finding: citation['finding'] as String,
              effectSize: citation['effectSize'] as String,
            );
          }),
        ],
      ],
    );
  }
}
