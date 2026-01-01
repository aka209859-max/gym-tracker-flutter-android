import 'package:gym_match/gen/app_localizations.dart';
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
        SnackBar(
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
            content: Text(AppLocalizations.of(context)!.error),
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
            content: Text(AppLocalizations.of(context)!.error),
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
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.postSubmitted),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
                          AppLocalizations.of(context)!.confirm,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.general_4dbf836e,
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
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final benefit = widget.application.planType == 'premium' ? AppLocalizations.of(context)!.general_9aff674f : AppLocalizations.of(context)!.general_6fd93ccd;

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
                label: Text(AppLocalizations.of(context)!.general_a1817327),
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
                label: Text(AppLocalizations.of(context)!.general_b5b7e374),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.purchaseCompleted(AppLocalizations.of(context)!.general_140fbc0e),
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
                    SizedBox(height: 12),
                    Text(
                          AppLocalizations.of(context)!.postSubmitted,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.confirm,
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
                  AppLocalizations.of(context)!.general_c8bef2a9,
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
            Row(
              children: [
                Icon(Icons.article, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.general_5aab3d07,
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
            Row(
              children: [
                Icon(Icons.checklist, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.general_4b8a8d52,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInstructionStep('1', AppLocalizations.of(context)!.general_3ad25210),
            _buildInstructionStep('2', AppLocalizations.of(context)!.general_e8477f45),
            _buildInstructionStep('3', AppLocalizations.of(context)!.general_d9c86932),
            _buildInstructionStep('4', AppLocalizations.of(context)!.general_4da5e52b),
            SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.green[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.confirm,
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
