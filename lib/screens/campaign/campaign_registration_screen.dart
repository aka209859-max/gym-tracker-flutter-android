import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/campaign_service.dart';
import '../../models/campaign_application.dart';
import 'campaign_sns_share_screen.dart';

/// キャンペーン登録画面
/// 
/// プラン登録時に乗り換え前アプリ名を入力
class CampaignRegistrationScreen extends StatefulWidget {
  final String planType; // 'premium' or 'pro'

  const CampaignRegistrationScreen({
    super.key,
    required this.planType,
  });

  @override
  State<CampaignRegistrationScreen> createState() => _CampaignRegistrationScreenState();
}

class _CampaignRegistrationScreenState extends State<CampaignRegistrationScreen> {
  final CampaignService _campaignService = CampaignService();
  final TextEditingController _appNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  // 人気アプリのリスト
  final List<String> _popularApps = [
    '筋トレMEMO',
    'FiNC',
    'Nike Training Club',
    'MyFitnessPal',
    'Strava',
    'その他',
  ];

  String? _selectedApp;

  @override
  void dispose() {
    _appNameController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final appName = _selectedApp == 'その他'
        ? _appNameController.text
        : _selectedApp!;

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: 実際のユーザーID取得
      const userId = 'example_user_id';

      final application = await _campaignService.createApplication(
        userId: userId,
        planType: widget.planType,
        previousAppName: appName,
      );

      if (mounted) {
        // SNSシェア画面へ遷移
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CampaignSnsShareScreen(
              application: application,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final benefit = widget.planType == 'premium' ? '初月無料' : '2ヶ月無料';

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎉 乗り換え割キャンペーン'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // キャンペーンヘッダー
                    _buildCampaignHeader(benefit),
                    const SizedBox(height: 32),

                    // アプリ選択セクション
                    _buildAppSelectionSection(),
                    const SizedBox(height: 32),

                    // 条件説明
                    _buildConditionsSection(benefit),
                    const SizedBox(height: 32),

                    // 申請ボタン
                    ElevatedButton(
                      onPressed: _submitApplication,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        '✅ $benefitを申請する',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCampaignHeader(String benefit) {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.card_giftcard,
              size: 64,
              color: Colors.orange[700],
            ),
            const SizedBox(height: 16),
            Text(
              '他社アプリから乗り換えで',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              benefit,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '完全自動承認システム',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '乗り換え前のアプリを選択',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '以前使っていた筋トレアプリを教えてください',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ..._popularApps.map((app) => RadioListTile<String>(
                      title: Text(app),
                      value: app,
                      groupValue: _selectedApp,
                      onChanged: (value) {
                        setState(() {
                          _selectedApp = value;
                        });
                      },
                    )),
                if (_selectedApp == 'その他') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _appNameController,
                    decoration: const InputDecoration(
                      labelText: 'アプリ名を入力',
                      hintText: '例: トレーニング日記',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_selectedApp == 'その他' &&
                          (value == null || value.isEmpty)) {
                        return 'アプリ名を入力してください';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConditionsSection(String benefit) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  '$benefit獲得条件',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildConditionItem('1️⃣', '乗り換え前アプリ名を登録'),
            _buildConditionItem('2️⃣', 'SNSで体験をシェア（テンプレート提供）'),
            _buildConditionItem('3️⃣', '自動確認後、即座に特典適用'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '完全自動承認！CEOによる手動確認なし',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold,
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

  Widget _buildConditionItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
