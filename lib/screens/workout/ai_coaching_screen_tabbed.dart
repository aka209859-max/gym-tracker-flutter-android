import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/ai_prediction_service.dart';
import '../../services/training_analysis_service.dart';
import '../../services/subscription_service.dart';
import '../../services/reward_ad_service.dart';
import '../../services/ai_credit_service.dart';
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

  /// 設定メニューを表示
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // タイトル
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.deepPurple.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    '設定メニュー',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            // メニュー項目1: トレーニングメモ
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.note_alt,
                  color: Colors.blue.shade700,
                ),
              ),
              title: const Text(
                'トレーニングメモ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text('過去のトレーニング記録を確認'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/workout-memo');
              },
            ),
            // メニュー項目2: 個人要因設定
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_outline,
                  color: Colors.purple.shade700,
                ),
              ),
              title: const Text(
                '個人要因設定',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text('年齢・経験・睡眠・栄養などを編集'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/personal-factors');
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsMenu,
            tooltip: '設定',
          ),
        ],
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
        onPressed: isEnabled ? () {
          FocusScope.of(context).unfocus();
          _generateMenu(selectedParts);
        } : null,
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

  /// AIメニュー生成（サブスクリプションチェック統合）
  Future<void> _generateMenu(List<String> bodyParts) async {
    // ========================================
    // 🔐 Step 1: サブスクリプション状態チェック
    // ========================================
    final subscriptionService = SubscriptionService();
    final creditService = AICreditService();
    final rewardAdService = RewardAdService();
    
    final currentPlan = await subscriptionService.getCurrentPlan();
    debugPrint('🔍 [AI生成] 現在のプラン: $currentPlan');
    
    // ========================================
    // 🎯 Step 2: AI利用可能性チェック
    // ========================================
    final canUseAI = await creditService.canUseAI();
    debugPrint('🔍 [AI生成] AI使用可能: $canUseAI');
    
    if (!canUseAI) {
      // 無料プランでAIクレジットがない場合
      if (currentPlan == SubscriptionType.free) {
        // リワード広告で獲得可能かチェック
        final canEarnFromAd = await creditService.canEarnCreditFromAd();
        debugPrint('🔍 [AI生成] 広告視聴可能: $canEarnFromAd');
        
        if (canEarnFromAd) {
          // ========================================
          // 📺 Step 3: リワード広告ダイアログ表示
          // ========================================
          final shouldShowAd = await _showRewardAdDialog();
          
          if (shouldShowAd == true) {
            // 広告を表示してクレジット獲得
            final adSuccess = await _showRewardAdAndEarn();
            
            if (!adSuccess) {
              // 広告表示失敗
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('広告の読み込みに失敗しました。しばらくしてからお試しください。'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
            // 広告視聴成功 → 下記のAI生成処理に進む
          } else {
            // ユーザーがキャンセル
            return;
          }
        } else {
          // 今月の広告視聴上限に達している
          if (mounted) {
            await _showUpgradeDialog('今月の無料AI利用回数を使い切りました');
          }
          return;
        }
      } else {
        // 有料プランで月次上限に達している
        if (mounted) {
          await _showUpgradeDialog('今月のAI利用回数を使い切りました');
        }
        return;
      }
    }
    
    // ========================================
    // 🤖 Step 4: AI生成処理（クレジット消費含む）
    // ========================================
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

        // ========================================
        // ✅ Step 5: AI生成成功 → クレジット消費
        // ========================================
        final consumeSuccess = await creditService.consumeAICredit();
        debugPrint('✅ AIクレジット消費: $consumeSuccess');
        
        setState(() {
          _generatedMenu = text;
          _isGenerating = false;
        });

        debugPrint('✅ メニュー生成成功');
        
        // 残りクレジット表示
        if (mounted) {
          final statusMessage = await creditService.getAIUsageStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI生成完了! ($statusMessage)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
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

  /// リワード広告ダイアログ表示
  Future<bool?> _showRewardAdDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.play_circle_outline, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('動画でAI機能解放'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '無料プランでは、動画広告を視聴することでAI機能を1回利用できます。',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '月3回まで動画視聴でAI利用可能',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('動画を視聴'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  /// リワード広告を表示してクレジット獲得
  Future<bool> _showRewardAdAndEarn() async {
    final rewardAdService = RewardAdService();
    
    // 広告読み込み待機ダイアログ表示
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('広告を読み込んでいます...'),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // 広告を読み込む
    await rewardAdService.loadRewardedAd();
    
    // 読み込み完了まで最大5秒待機
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (rewardAdService.isAdReady()) {
        break;
      }
    }
    
    // ローディングダイアログを閉じる
    if (mounted) {
      Navigator.of(context).pop();
    }
    
    // 広告表示
    if (rewardAdService.isAdReady()) {
      final success = await rewardAdService.showRewardedAd();
      
      if (success) {
        // 広告視聴成功メッセージ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎁 AI機能1回分を獲得しました!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return true;
      }
    }
    
    return false;
  }
  
  /// アップグレード促進ダイアログ表示
  Future<void> _showUpgradeDialog(String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text('プレミアムプランにアップグレード'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'プレミアムプランなら:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 月10回までAI機能が使い放題\n'
              '• 広告なしで快適に利用\n'
              '• お気に入りジム無制限\n'
              '• レビュー投稿可能',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '月額 ¥500',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('後で'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: サブスクリプション画面へ遷移
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('サブスクリプション機能は準備中です'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('アップグレード'),
          ),
        ],
      ),
    );
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
  bool _isLoading = false;  // ✅ 修正: 初期状態はローディングなし

  @override
  void initState() {
    super.initState();
    // ✅ 修正: 自動実行を削除（ユーザーが実行ボタンを押したときのみAI機能を使用）
  }

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

  /// 成長予測を実行(サブスクリプションチェック統合)
  Future<void> _executePrediction() async {
    if (!_formKey.currentState!.validate()) return;

    // ========================================
    // 🔐 Step 1: サブスクリプション状態チェック
    // ========================================
    final subscriptionService = SubscriptionService();
    final creditService = AICreditService();
    final rewardAdService = RewardAdService();
    
    final currentPlan = await subscriptionService.getCurrentPlan();
    debugPrint('🔍 [成長予測] 現在のプラン: $currentPlan');
    
    // ========================================
    // 🎯 Step 2: AI利用可能性チェック
    // ========================================
    final canUseAI = await creditService.canUseAI();
    debugPrint('🔍 [成長予測] AI使用可能: $canUseAI');
    
    if (!canUseAI) {
      // 無料プランでAIクレジットがない場合
      if (currentPlan == SubscriptionType.free) {
        // リワード広告で獲得可能かチェック
        final canEarnFromAd = await creditService.canEarnCreditFromAd();
        debugPrint('🔍 [成長予測] 広告視聴可能: $canEarnFromAd');
        
        if (canEarnFromAd) {
          // ========================================
          // 📺 Step 3: リワード広告ダイアログ表示
          // ========================================
          final shouldShowAd = await _showRewardAdDialog();
          
          if (shouldShowAd == true) {
            // 広告を表示してクレジット獲得
            final adSuccess = await _showRewardAdAndEarn();
            
            if (!adSuccess) {
              // 広告表示失敗
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('広告の読み込みに失敗しました。しばらくしてからお試しください。'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
            // 広告視聴成功 → 下記のAI生成処理に進む
          } else {
            // ユーザーがキャンセル
            return;
          }
        } else {
          // 今月の広告視聴上限に達している
          if (mounted) {
            await _showUpgradeDialog('今月の無料AI利用回数を使い切りました');
          }
          return;
        }
      } else {
        // 有料プランで月次上限に達している
        if (mounted) {
          await _showUpgradeDialog('今月のAI利用回数を使い切りました');
        }
        return;
      }
    }

    // ========================================
    // 🤖 Step 4: AI予測処理(クレジット消費含む)
    // ========================================
    setState(() {
      _isLoading = true;
      _predictionResult = null;
    });

    try {
      print('🚀 成長予測開始...');
      final result = await AIPredictionService.predictGrowth(
        currentWeight: double.parse(_weightController.text),
        level: _selectedLevel,
        frequency: _selectedFrequency,
        gender: _selectedGender,
        age: _selectedAge,
        bodyPart: _selectedBodyPart,
        monthsAhead: 4,
      );
      print('✅ 成長予測完了: ${result['success']}');

      if (result['success'] == true) {
        // ========================================
        // ✅ Step 5: AI生成成功 → クレジット消費
        // ========================================
        final consumeSuccess = await creditService.consumeAICredit();
        debugPrint('✅ AIクレジット消費: $consumeSuccess');
        
        // 残りクレジット表示
        if (mounted) {
          final statusMessage = await creditService.getAIUsageStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI予測完了! ($statusMessage)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _predictionResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 成長予測例外: $e');
      if (mounted) {
        setState(() {
          _predictionResult = {
            'success': false,
            'error': '予測の生成に失敗しました: $e',
          };
          _isLoading = false;
        });
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onEditingComplete: () => FocusScope.of(context).unfocus(),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ 女性は上半身の相対的筋力向上率が男性より高い（Roberts 2020）',
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
      onPressed: _isLoading ? null : () {
        FocusScope.of(context).unfocus();
        _executePrediction();
      },
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
    // nullチェック
    if (_predictionResult == null) {
      return Card(
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('予測結果がありません'),
        ),
      );
    }

    // エラーチェック
    if (_predictionResult!['success'] != true) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    '予測エラー',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                _predictionResult!['error']?.toString() ?? '不明なエラーが発生しました',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ),
        ),
      );
    }

    final result = _predictionResult!;
    
    // 必須フィールドチェック
    if (!result.containsKey('currentWeight') || 
        !result.containsKey('predictedWeight') ||
        !result.containsKey('aiAnalysis')) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '予測データが不完全です。もう一度お試しください。',
            style: TextStyle(color: Colors.orange.shade900),
          ),
        ),
      );
    }
    
    final currentWeight = result['currentWeight'] as double;
    final predictedWeight = result['predictedWeight'] as double;
    final growthPercentage = result['growthPercentage'] as int;
    final confidenceInterval = result['confidenceInterval'] as Map<String, dynamic>;
    final monthlyRate = result['monthlyRate'] as int;
    final weeklyRate = result['weeklyRate'] as double;
    final aiAnalysis = result['aiAnalysis'] as String;
    final scientificBasis = result['scientificBasis'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 予測結果サマリー
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 48,
                  color: Colors.green.shade700,
                ),
                const SizedBox(height: 16),
                const Text(
                  '4ヶ月後の予測',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${predictedWeight.round()}kg',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '現在: ${currentWeight.round()}kg → +$growthPercentage%の成長',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '信頼区間: ${confidenceInterval['lower'].round()}-${confidenceInterval['upper'].round()}kg',
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
        ),
        const SizedBox(height: 16),

        // 成長率カード
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      '成長率',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('月次成長', '+$monthlyRate%', Colors.blue),
                    _buildStatItem('週次成長', '+${weeklyRate.toStringAsFixed(1)}%', Colors.green),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // AI分析
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'AI詳細分析',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFormattedText(aiAnalysis),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 科学的根拠
        ScientificBasisSection(
          basis: scientificBasis.cast<Map<String, String>>(),
        ),
        const SizedBox(height: 8),

        // 信頼度インジケーター
        Center(
          child: ConfidenceIndicator(paperCount: scientificBasis.length),
        ),
      ],
    );
  }

  /// 統計アイテム
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// リワード広告ダイアログ表示
  Future<bool?> _showRewardAdDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.play_circle_outline, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('動画でAI機能解放'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '無料プランでは、動画広告を視聴することでAI機能を1回利用できます。',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '月3回まで動画視聴でAI利用可能',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('動画を視聴'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  /// リワード広告を表示してクレジット獲得
  Future<bool> _showRewardAdAndEarn() async {
    final rewardAdService = RewardAdService();
    
    // 広告読み込み待機ダイアログ表示
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('広告を読み込んでいます...'),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // 広告を読み込む
    await rewardAdService.loadRewardedAd();
    
    // 読み込み完了まで最大5秒待機
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (rewardAdService.isAdReady()) {
        break;
      }
    }
    
    // ローディングダイアログを閉じる
    if (mounted) {
      Navigator.of(context).pop();
    }
    
    // 広告表示
    if (rewardAdService.isAdReady()) {
      final success = await rewardAdService.showRewardedAd();
      
      if (success) {
        // 広告視聴成功メッセージ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎁 AI機能1回分を獲得しました!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return true;
      }
    }
    
    return false;
  }
  
  /// アップグレード促進ダイアログ表示
  Future<void> _showUpgradeDialog(String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text('プレミアムプランにアップグレード'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'プレミアムプランなら:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 月10回までAI機能が使い放題\n'
              '• 広告なしで快適に利用\n'
              '• お気に入りジム無制限\n'
              '• レビュー投稿可能',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '月額 ¥500',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('後で'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: サブスクリプション画面へ遷移
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('サブスクリプション機能は準備中です'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('アップグレード'),
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
        spans.add(TextSpan(text: line));
      } else {
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            spans.add(TextSpan(text: line.substring(lastIndex, match.start)));
          }
          spans.add(
            TextSpan(
              text: match.group(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
          lastIndex = match.end;
        }
        if (lastIndex < line.length) {
          spans.add(TextSpan(text: line.substring(lastIndex)));
        }
      }

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
  String _selectedExercise = 'ベンチプレス';  // 種目選択
  int _currentSets = 12;
  int _currentFrequency = 2;
  String _selectedLevel = '中級者';
  String _selectedGender = '女性';
  int _selectedAge = 25;
  bool _enablePlateauDetection = true;  // プラトー検出ON/OFF

  // 分析結果
  Map<String, dynamic>? _analysisResult;
  bool _isLoading = false;  // ✅ 修正: 初期状態はローディングなし

  @override
  void initState() {
    super.initState();
    // ✅ 修正: 自動実行を削除（ユーザーが実行ボタンを押したときのみAI機能を使用）
  }

  // 部位選択肢
  final List<String> _bodyParts = [
    '大胸筋',
    '広背筋',
    '大腿四頭筋',
    '上腕二頭筋',
    '上腕三頭筋',
    '三角筋',
  ];

  // 種目選択肢（部位ごと）
  final Map<String, List<String>> _exercisesByBodyPart = {
    '大胸筋': ['ベンチプレス', 'インクラインベンチプレス', 'ダンベルフライ', 'ディップス'],
    '広背筋': ['デッドリフト', 'ラットプルダウン', 'ベントオーバーロウ', 'チンニング'],
    '大腿四頭筋': ['スクワット', 'レッグプレス', 'レッグエクステンション', 'ランジ'],
    '上腕二頭筋': ['バーベルカール', 'ダンベルカール', 'ハンマーカール', 'プリーチャーカール'],
    '上腕三頭筋': ['トライセプスプレスダウン', 'ライイングトライセプスエクステンション', 'ディップス', 'クローズグリップベンチプレス'],
    '三角筋': ['ショルダープレス', 'サイドレイズ', 'フロントレイズ', 'リアレイズ'],
  };

  // レベル選択肢
  final List<String> _levels = ['初心者', '中級者', '上級者'];

  // 現在選択中の部位の種目リスト
  List<String> get _availableExercises => _exercisesByBodyPart[_selectedBodyPart] ?? [];

  /// 効果分析を実行(サブスクリプションチェック統合)
  Future<void> _executeAnalysis() async {
    if (!_formKey.currentState!.validate()) return;

    // ========================================
    // 🔐 Step 1: サブスクリプション状態チェック
    // ========================================
    final subscriptionService = SubscriptionService();
    final creditService = AICreditService();
    final rewardAdService = RewardAdService();
    
    final currentPlan = await subscriptionService.getCurrentPlan();
    debugPrint('🔍 [効果分析] 現在のプラン: $currentPlan');
    
    // ========================================
    // 🎯 Step 2: AI利用可能性チェック
    // ========================================
    final canUseAI = await creditService.canUseAI();
    debugPrint('🔍 [効果分析] AI使用可能: $canUseAI');
    
    if (!canUseAI) {
      // 無料プランでAIクレジットがない場合
      if (currentPlan == SubscriptionType.free) {
        // リワード広告で獲得可能かチェック
        final canEarnFromAd = await creditService.canEarnCreditFromAd();
        debugPrint('🔍 [効果分析] 広告視聴可能: $canEarnFromAd');
        
        if (canEarnFromAd) {
          // ========================================
          // 📺 Step 3: リワード広告ダイアログ表示
          // ========================================
          final shouldShowAd = await _showRewardAdDialog();
          
          if (shouldShowAd == true) {
            // 広告を表示してクレジット獲得
            final adSuccess = await _showRewardAdAndEarn();
            
            if (!adSuccess) {
              // 広告表示失敗
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('広告の読み込みに失敗しました。しばらくしてからお試しください。'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
            // 広告視聴成功 → 下記のAI生成処理に進む
          } else {
            // ユーザーがキャンセル
            return;
          }
        } else {
          // 今月の広告視聴上限に達している
          if (mounted) {
            await _showUpgradeDialog('今月の無料AI利用回数を使い切りました');
          }
          return;
        }
      } else {
        // 有料プランで月次上限に達している
        if (mounted) {
          await _showUpgradeDialog('今月のAI利用回数を使い切りました');
        }
        return;
      }
    }

    // ========================================
    // 🤖 Step 4: AI分析処理(クレジット消費含む)
    // ========================================
    setState(() {
      _isLoading = true;
      _analysisResult = null;
    });

    try {
      print('🚀 効果分析開始...');
      
      // プラトー検出が有効な場合、Firestoreから履歴を取得
      List<Map<String, dynamic>> recentHistory = [];
      if (_enablePlateauDetection) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          recentHistory = await _fetchRecentExerciseHistory(user.uid, _selectedExercise);
          print('📊 履歴取得: ${recentHistory.length}件');
        }
      }
      
      final result = await TrainingAnalysisService.analyzeTrainingEffect(
        bodyPart: _selectedBodyPart,
        currentSetsPerWeek: _currentSets,
        currentFrequency: _currentFrequency,
        level: _selectedLevel,
        gender: _selectedGender,
        age: _selectedAge,
        recentHistory: recentHistory,
      );
      print('✅ 効果分析完了: ${result['success']}');

      if (result['success'] == true) {
        // ========================================
        // ✅ Step 5: AI生成成功 → クレジット消費
        // ========================================
        final consumeSuccess = await creditService.consumeAICredit();
        debugPrint('✅ AIクレジット消費: $consumeSuccess');
        
        // 残りクレジット表示
        if (mounted) {
          final statusMessage = await creditService.getAIUsageStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI分析完了! ($statusMessage)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 効果分析例外: $e');
      if (mounted) {
        setState(() {
          _analysisResult = {
            'success': false,
            'error': '分析の生成に失敗しました: $e',
          };
          _isLoading = false;
        });
      }
    }
  }

  /// Firestoreから特定種目の直近4回のトレーニング記録を取得
  Future<List<Map<String, dynamic>>> _fetchRecentExerciseHistory(
    String userId,
    String exerciseName,
  ) async {
    try {
      // 直近30日間のworkoutログを取得
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final snapshot = await FirebaseFirestore.instance
          .collection('workouts')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('date', descending: true)
          .limit(20)  // 最大20件のワークアウトログを取得
          .get();

      final List<Map<String, dynamic>> exerciseRecords = [];
      
      // 各ワークアウトログから指定種目のデータを抽出
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final exercises = data['exercises'] as List<dynamic>?;
        
        if (exercises != null) {
          // 指定種目を探す
          for (final exercise in exercises) {
            final exerciseMap = exercise as Map<String, dynamic>;
            if (exerciseMap['name'] == exerciseName) {
              // 最大重量を計算
              final sets = exerciseMap['sets'] as List<dynamic>?;
              double maxWeight = 0;
              
              if (sets != null) {
                for (final set in sets) {
                  final setMap = set as Map<String, dynamic>;
                  final weight = setMap['weight']?.toDouble() ?? 0;
                  if (weight > maxWeight) {
                    maxWeight = weight;
                  }
                }
              }
              
              // 記録を追加（4件に達したら終了）
              exerciseRecords.add({
                'date': (data['date'] as Timestamp).toDate(),
                'weight': maxWeight,
                'sets': sets?.length ?? 0,
              });
              
              if (exerciseRecords.length >= 4) break;
            }
          }
        }
        
        if (exerciseRecords.length >= 4) break;
      }
      
      // 日付順にソート（新しい順）
      exerciseRecords.sort((a, b) => 
        (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      // 週番号を付与（直近が week 1）
      final result = <Map<String, dynamic>>[];
      for (int i = 0; i < exerciseRecords.length; i++) {
        result.add({
          'week': exerciseRecords.length - i,
          'weight': exerciseRecords[i]['weight'],
          'sets': exerciseRecords[i]['sets'],
        });
      }
      
      return result;
    } catch (e) {
      print('❌ 履歴取得エラー: $e');
      return [];
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
                  // 部位変更時に種目を自動選択
                  _selectedExercise = _availableExercises.isNotEmpty 
                      ? _availableExercises.first 
                      : 'ベンチプレス';
                });
              },
            ),
            const SizedBox(height: 16),

            // 種目選択
            _buildDropdownField(
              label: '種目（プラトー検出用）',
              value: _selectedExercise,
              items: _availableExercises,
              onChanged: (value) {
                setState(() {
                  _selectedExercise = value!;
                });
              },
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '※ 同じ種目で4回連続同じ重量の場合、停滞を検出',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // プラトー検出トグル
            SwitchListTile(
              title: const Text(
                'プラトー（停滞期）検出',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _enablePlateauDetection 
                    ? '実際のトレーニング記録から自動検出します' 
                    : '検出機能をOFFにしています',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              value: _enablePlateauDetection,
              onChanged: (value) {
                setState(() {
                  _enablePlateauDetection = value;
                });
              },
              activeColor: Colors.orange.shade700,
              contentPadding: EdgeInsets.zero,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '※ 女性は上半身の相対的筋力向上率が男性より高い（Roberts 2020）',
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
      onPressed: _isLoading ? null : () {
        FocusScope.of(context).unfocus();
        _executeAnalysis();
      },
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
    // nullチェック
    if (_analysisResult == null) {
      return Card(
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('分析結果がありません'),
        ),
      );
    }

    // エラーチェック
    if (_analysisResult!['success'] != true) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    '分析エラー',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                _analysisResult!['error']?.toString() ?? '不明なエラーが発生しました',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ),
        ),
      );
    }

    final result = _analysisResult!;
    
    // 必須フィールドチェック
    if (!result.containsKey('volumeAnalysis') || 
        !result.containsKey('frequencyAnalysis') ||
        !result.containsKey('aiAnalysis')) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '分析データが不完全です。もう一度お試しください。',
            style: TextStyle(color: Colors.orange.shade900),
          ),
        ),
      );
    }
    
    final volumeAnalysis = result['volumeAnalysis'] as Map<String, dynamic>;
    final frequencyAnalysis = result['frequencyAnalysis'] as Map<String, dynamic>;
    final plateauDetected = result['plateauDetected'] as bool;
    final growthTrend = result['growthTrend'] as Map<String, dynamic>;
    final recommendations = result['recommendations'] as List;
    final scientificBasis = result['scientificBasis'] as List;
    final aiAnalysis = result['aiAnalysis'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ステータスサマリー（トグルOFFの場合はプラトー無視）
        _buildStatusSummary(volumeAnalysis, frequencyAnalysis, 
          _enablePlateauDetection && plateauDetected, growthTrend),
        const SizedBox(height: 16),

        // ボリューム分析
        _buildVolumeAnalysis(volumeAnalysis),
        const SizedBox(height: 16),

        // 頻度分析
        _buildFrequencyAnalysis(frequencyAnalysis),
        const SizedBox(height: 16),

        // プラトー警告（トグルON かつ 検出された場合のみ表示）
        if (_enablePlateauDetection && plateauDetected) ...[
          _buildPlateauWarning(),
          const SizedBox(height: 16),
        ],

        // 推奨アクション
        _buildRecommendations(recommendations),
        const SizedBox(height: 16),

        // AI分析
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'AI詳細分析',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFormattedText(aiAnalysis),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 科学的根拠
        ScientificBasisSection(
          basis: scientificBasis.cast<Map<String, String>>(),
        ),
        const SizedBox(height: 8),

        // 信頼度インジケーター
        Center(
          child: ConfidenceIndicator(paperCount: scientificBasis.length),
        ),
      ],
    );
  }

  /// ステータスサマリー
  Widget _buildStatusSummary(
    Map<String, dynamic> volume,
    Map<String, dynamic> frequency,
    bool plateau,
    Map<String, dynamic> trend,
  ) {
    Color statusColor;
    IconData statusIcon;
    String statusMessage;

    if (plateau) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusMessage = 'プラトー検出：改善が必要';
    } else if (volume['status'] == 'optimal' && frequency['status'] == 'optimal') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusMessage = '最適なトレーニング中';
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.info;
      statusMessage = '改善の余地あり';
    }

    return Card(
      color: statusColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(statusIcon, size: 48, color: statusColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusMessage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '成長トレンド: ${trend['trend']}',
                    style: TextStyle(
                      fontSize: 14,
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

  /// ボリューム分析
  Widget _buildVolumeAnalysis(Map<String, dynamic> analysis) {
    final status = analysis['status'] as String;
    final advice = analysis['advice'] as String;
    
    Color statusColor;
    String statusLabel;
    
    switch (status) {
      case 'optimal':
        statusColor = Colors.green;
        statusLabel = '最適';
        break;
      case 'suboptimal':
        statusColor = Colors.blue;
        statusLabel = '最適以下';
        break;
      case 'insufficient':
        statusColor = Colors.orange;
        statusLabel = '不足';
        break;
      case 'excessive':
        statusColor = Colors.red;
        statusLabel = '過剰';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = '不明';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'ボリューム分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              advice,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  /// 頻度分析
  Widget _buildFrequencyAnalysis(Map<String, dynamic> analysis) {
    final status = analysis['status'] as String;
    final advice = analysis['advice'] as String;
    
    Color statusColor;
    String statusLabel;
    
    switch (status) {
      case 'optimal':
        statusColor = Colors.green;
        statusLabel = '最適';
        break;
      case 'suboptimal':
        statusColor = Colors.blue;
        statusLabel = '最適以下';
        break;
      case 'insufficient':
        statusColor = Colors.orange;
        statusLabel = '不足';
        break;
      case 'excessive':
        statusColor = Colors.red;
        statusLabel = '過剰';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = '不明';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  '頻度分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              advice,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  /// プラトー警告
  Widget _buildPlateauWarning() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.warning_amber, size: 40, color: Colors.orange.shade700),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'プラトー検出',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '成長が停滞しています。トレーニングを変更しましょう。',
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

  /// 推奨アクション
  Widget _buildRecommendations(List recommendations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.recommend, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Text(
                  '推奨アクション',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendations.map((rec) {
              final action = rec['action'] as String;
              final category = rec['category'] as String;
              final priority = rec['priority'] as String;
              
              Color priorityColor;
              switch (priority) {
                case 'high':
                  priorityColor = Colors.red;
                  break;
                case 'medium':
                  priorityColor = Colors.orange;
                  break;
                default:
                  priorityColor = Colors.blue;
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: priorityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            action,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// リワード広告ダイアログ表示
  Future<bool?> _showRewardAdDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.play_circle_outline, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('動画でAI機能解放'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '無料プランでは、動画広告を視聴することでAI機能を1回利用できます。',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '月3回まで動画視聴でAI利用可能',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('動画を視聴'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  /// リワード広告を表示してクレジット獲得
  Future<bool> _showRewardAdAndEarn() async {
    final rewardAdService = RewardAdService();
    
    // 広告読み込み待機ダイアログ表示
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('広告を読み込んでいます...'),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // 広告を読み込む
    await rewardAdService.loadRewardedAd();
    
    // 読み込み完了まで最大5秒待機
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (rewardAdService.isAdReady()) {
        break;
      }
    }
    
    // ローディングダイアログを閉じる
    if (mounted) {
      Navigator.of(context).pop();
    }
    
    // 広告表示
    if (rewardAdService.isAdReady()) {
      final success = await rewardAdService.showRewardedAd();
      
      if (success) {
        // 広告視聴成功メッセージ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎁 AI機能1回分を獲得しました!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return true;
      }
    }
    
    return false;
  }
  
  /// アップグレード促進ダイアログ表示
  Future<void> _showUpgradeDialog(String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text('プレミアムプランにアップグレード'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'プレミアムプランなら:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 月10回までAI機能が使い放題\n'
              '• 広告なしで快適に利用\n'
              '• お気に入りジム無制限\n'
              '• レビュー投稿可能',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '月額 ¥500',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('後で'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: サブスクリプション画面へ遷移
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('サブスクリプション機能は準備中です'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('アップグレード'),
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
        spans.add(TextSpan(text: line));
      } else {
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            spans.add(TextSpan(text: line.substring(lastIndex, match.start)));
          }
          spans.add(
            TextSpan(
              text: match.group(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
          lastIndex = match.end;
        }
        if (lastIndex < line.length) {
          spans.add(TextSpan(text: line.substring(lastIndex)));
        }
      }

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
}
