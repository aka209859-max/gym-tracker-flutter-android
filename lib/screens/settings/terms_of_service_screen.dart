import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// 利用規約画面
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.termsOfService),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              AppLocalizations.of(context)!.profile_6a8629ce,
              'この利用規約（以下「本規約」）は、井上元（以下「開発者」）が提供するGYM MATCHアプリ（以下「本アプリ」）の利用条件を定めるものです。ユーザーは、本アプリを利用することにより、本規約に同意したものとみなされます。',
            ),
            _buildSection(
              AppLocalizations.of(context)!.profile_7a557256,
              '本アプリは、以下の機能を提供します：\n\n'
              '• トレーニング記録の管理\n'
              '• ジム検索・位置情報表示\n'
              '• AIによるトレーニングメニュー提案\n'
              '• トレーニングデータの分析・可視化\n'
              '• 有料サブスクリプションプラン（Premium、Pro）',
            ),
            _buildSection(
              AppLocalizations.of(context)!.profile_94636bb4,
              'ユーザーは、本アプリの利用にあたり、以下の行為をしてはなりません：\n\n'
              '• 法令または公序良俗に違反する行為\n'
              '• 本アプリのサーバーまたはネットワークの機能を破壊したり、妨害したりする行為\n'
              '• 他のユーザーに関する個人情報等を収集または蓄積する行為\n'
              '• 不正アクセスをし、またはこれを試みる行為\n'
              '• 本アプリの不具合を意図的に利用する行為',
            ),
            _buildSubscriptionSection(),
            _buildSection(
              AppLocalizations.of(context)!.profile_2324b2ad,
              '• 開発者は、本アプリに起因してユーザーに生じたあらゆる損害について、一切の責任を負いません。\n'
              '• 本アプリのトレーニング提案は参考情報であり、医学的アドバイスではありません。運動を始める前に医師に相談してください。',
            ),
            _buildSection(
              AppLocalizations.of(context)!.profile_177dff1d,
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
            AppLocalizations.of(context)!.profile_4f41f161,
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
                  AppLocalizations.of(context)!.profile_147e8136,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPlanItem(AppLocalizations.of(context)!.profile_fd09fa4b, AppLocalizations.of(context)!.profile_68b026c0, Colors.grey),
                const SizedBox(height: 4),
                _buildPlanItem(AppLocalizations.of(context)!.premiumPlan, AppLocalizations.of(context)!.profile_c29470ee, Colors.green),
                const SizedBox(height: 4),
                _buildPlanItem(AppLocalizations.of(context)!.proPlan, AppLocalizations.of(context)!.profile_bf865e58, Colors.purple),
                const Divider(height: 24),
                const Text(
                  AppLocalizations.of(context)!.profile_86ba31c5,
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
                  AppLocalizations.of(context)!.profile_fbe7f25b,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppLocalizations.of(context)!.profile_4347a89b,
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppLocalizations.of(context)!.profile_867becd2,
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
                  AppLocalizations.of(context)!.profile_d875e5b0,
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
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.contactUs,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            AppLocalizations.of(context)!.profile_dc441f37,
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
          SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.email,
            style: const TextStyle(fontSize: 13),
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
      child: Column(
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
