import 'package:flutter/material.dart';

/// 利用規約画面
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('利用規約'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '第1条（適用）',
              'この利用規約（以下「本規約」）は、井上元（以下「開発者」）が提供するGYM MATCHアプリ（以下「本アプリ」）の利用条件を定めるものです。ユーザーは、本アプリを利用することにより、本規約に同意したものとみなされます。',
            ),
            _buildSection(
              '第2条（サービス内容）',
              '本アプリは、以下の機能を提供します：\n\n'
              '• トレーニング記録の管理\n'
              '• ジム検索・位置情報表示\n'
              '• AIによるトレーニングメニュー提案\n'
              '• トレーニングデータの分析・可視化\n'
              '• 有料サブスクリプションプラン（Premium、Pro）',
            ),
            _buildSection(
              '第3条（禁止事項）',
              'ユーザーは、本アプリの利用にあたり、以下の行為をしてはなりません：\n\n'
              '• 法令または公序良俗に違反する行為\n'
              '• 本アプリのサーバーまたはネットワークの機能を破壊したり、妨害したりする行為\n'
              '• 他のユーザーに関する個人情報等を収集または蓄積する行為\n'
              '• 不正アクセスをし、またはこれを試みる行為\n'
              '• 本アプリの不具合を意図的に利用する行為',
            ),
            _buildSubscriptionSection(),
            _buildSection(
              '第5条（免責事項）',
              '• 開発者は、本アプリに起因してユーザーに生じたあらゆる損害について、一切の責任を負いません。\n'
              '• 本アプリのトレーニング提案は参考情報であり、医学的アドバイスではありません。運動を始める前に医師に相談してください。',
            ),
            _buildSection(
              '第6条（準拠法・裁判管轄）',
              '• 本規約の解釈にあたっては、日本法を準拠法とします。\n'
              '• 本アプリに関して紛争が生じた場合には、開発者の所在地を管轄する裁判所を専属的合意管轄とします。',
            ),
            const SizedBox(height: 20),
            _buildContactSection(context),
            const SizedBox(height: 20),
            _buildDateSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '第4条（サブスクリプション）',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'プラン内容',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPlanItem('Freeプラン', '基本機能（広告表示あり、AI機能は広告視聴で月3回まで）', Colors.grey),
                const SizedBox(height: 4),
                _buildPlanItem('Premiumプラン', '¥500/月（広告なし、AI機能月10回）', Colors.green),
                const SizedBox(height: 4),
                _buildPlanItem('Proプラン', '¥980/月（広告なし、AI機能月30回）', Colors.purple),
                const Divider(height: 24),
                const Text(
                  '支払方法',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'App内課金（Apple App Store）を通じて支払いが行われます。',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  '自動更新',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'サブスクリプションは自動更新されます。解約しない限り、毎月自動的に課金されます。',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  '解約方法',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'iOS: 設定 → Apple ID → サブスクリプション → GYM MATCH → サブスクリプションをキャンセル',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  '返金ポリシー',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Appleの返金ポリシーに準拠します。返金については、App Storeサポートにお問い合わせください。',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItem(String plan, String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$plan: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contact_mail, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'お問い合わせ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '本規約に関するお問い合わせは、以下の連絡先までお願いいたします。',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            '開発者: 井上元',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'メールアドレス: i.hajime1219@outlook.jp',
            style: TextStyle(fontSize: 13),
          ),
          const Text(
            '（対応時間: 平日 10:00-18:00）',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '制定日: 2025年11月20日',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            '最終更新日: 2025年11月20日',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            '施行日: 2025年11月20日',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
