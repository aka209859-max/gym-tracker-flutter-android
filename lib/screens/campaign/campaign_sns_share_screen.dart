import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/campaign_application.dart';
import '../../services/campaign_service.dart';

/// SNSシェア依頼画面
/// 
/// ユニークコード + テンプレート提供
/// スマホ対応（QRコード方式）
class CampaignSnsShareScreen extends StatefulWidget {
  final CampaignApplication application;

  const CampaignSnsShareScreen({
    super.key,
    required this.application,
  });

  @override
  State<CampaignSnsShareScreen> createState() => _CampaignSnsShareScreenState();
}

class _CampaignSnsShareScreenState extends State<CampaignSnsShareScreen> {
  final CampaignService _campaignService = CampaignService();
  bool _isPosting = false;
  bool _hasPosted = false;

  String get _template {
    return _campaignService.generateSnsTemplate(
      uniqueCode: widget.application.uniqueCode,
      previousAppName: widget.application.previousAppName,
      planType: widget.application.planType,
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _template));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ テンプレートをコピーしました！'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareToSns() async {
    try {
      await Share.share(
        _template,
        subject: 'GYM MATCH 乗り換え体験',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('シェアエラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmPosted() async {
    setState(() {
      _isPosting = true;
    });

    try {
      // SNS投稿完了報告
      await _campaignService.reportSnsPosted(
        applicationId: widget.application.id,
      );

      setState(() {
        _hasPosted = true;
      });

      if (mounted) {
        // 確認中ダイアログ表示
        _showCheckingDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  void _showCheckingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('投稿を受付ました！'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              '自動確認システムが投稿を検証中...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '数分以内に結果をお知らせします',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // ダイアログ閉じる
              Navigator.of(context).pop(); // この画面も閉じる
            },
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final benefit = widget.application.planType == 'premium' ? '2ヶ月無料' : '初月無料';

    return Scaffold(
      appBar: AppBar(
        title: const Text('📱 SNSでシェア'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ステップ表示
            _buildStepIndicator(),
            const SizedBox(height: 32),

            // ユニークコード表示
            _buildUniqueCodeCard(),
            const SizedBox(height: 24),

            // テンプレート表示
            _buildTemplateCard(),
            const SizedBox(height: 24),

            // 投稿手順
            _buildInstructionsCard(),
            const SizedBox(height: 32),

            // アクションボタン
            if (!_hasPosted) ...[
              ElevatedButton.icon(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy),
                label: const Text('テンプレートをコピー'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _shareToSns,
                icon: const Icon(Icons.share),
                label: const Text('SNSアプリで投稿'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                '投稿完了後、下のボタンをタップ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isPosting ? null : _confirmPosted,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
                child: _isPosting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '✅ 投稿しました（$benefit獲得）',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[700],
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '投稿を受付ました！',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '自動確認システムが検証中です',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Card(
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildStepCircle('1', true),
            Expanded(child: _buildStepLine(true)),
            _buildStepCircle('2', false),
            Expanded(child: _buildStepLine(false)),
            _buildStepCircle('3', false),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle(String number, bool isActive) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? Colors.purple[700] : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Container(
      height: 2,
      color: isActive ? Colors.purple[700] : Colors.grey[300],
    );
  }

  Widget _buildUniqueCodeCard() {
    return Card(
      elevation: 4,
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.vpn_key, color: Colors.amber[700], size: 28),
                const SizedBox(width: 8),
                const Text(
                  'あなたの認証コード',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300, width: 2),
              ),
              child: SelectableText(
                widget.application.uniqueCode,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[900],
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ このコードを投稿に必ず含めてください',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.article, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '投稿テンプレート',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _template,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '💡 自由に編集してOKですが、認証コードとハッシュタグは必須です',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.checklist, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '投稿手順',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInstructionStep('1', '「テンプレートをコピー」をタップ'),
            _buildInstructionStep('2', 'X（旧Twitter）またはInstagramアプリを開く'),
            _buildInstructionStep('3', 'コピーしたテンプレートを貼り付けて投稿'),
            _buildInstructionStep('4', 'このアプリに戻って「投稿しました」をタップ'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '自動確認システムが数分以内に投稿を検証します',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[800],
                      ),
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

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue[700],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
