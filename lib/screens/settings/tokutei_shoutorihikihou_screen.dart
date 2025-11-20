import 'package:flutter/material.dart';

/// 特定商取引法に基づく表記画面
class TokuteiShoutorihikihouScreen extends StatelessWidget {
  const TokuteiShoutorihikihouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('特定商取引法に基づく表記'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '「特定商取引に関する法律」第11条に基づき、以下の通り表示いたします。',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoTable(context),
            const SizedBox(height: 20),
            _buildImportantNotice(),
            const SizedBox(height: 20),
            _buildRelatedLinks(),
            const SizedBox(height: 20),
            _buildContactSection(context),
            const SizedBox(height: 20),
            _buildDateSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTable(BuildContext context) {
    return Column(
      children: [
        _buildTableRow('販売事業者', '井上元'),
        _buildTableRow('運営統括責任者', '井上元'),
        _buildTableRow('所在地', '〒839-0817\n福岡県久留米市瀬下町243'),
        _buildTableRow(
          'お問い合わせ',
          'メールアドレス: i.hajime1219@outlook.jp\n（対応時間: 平日 10:00-18:00）',
        ),
        _buildTableRow(
          '販売価格',
          'Premiumプラン: ¥500/月（税込）\n'
          'Proプラン: ¥980/月（税込）\n\n'
          '※Freeプランは無料です\n'
          '（広告表示あり、AI機能は広告視聴で月3回まで利用可能）',
        ),
        _buildTableRow(
          '販売価格以外の必要料金',
          'インターネット接続料金、通信費等はお客様のご負担となります。',
        ),
        _buildTableRow(
          '支払方法',
          'Apple App Store決済（App内課金）\n'
          '※クレジットカード、デビットカード、Apple IDに登録された支払い方法による決済',
        ),
        _buildTableRow(
          '支払時期',
          '• サブスクリプション購入時に即時決済\n'
          '• 以降、毎月自動更新（解約しない限り継続課金）\n'
          '• 更新日の24時間前までに自動更新が行われます',
        ),
        _buildTableRow(
          'サービス提供時期',
          '決済完了後、即時利用可能となります。',
        ),
        _buildTableRow(
          '返品・返金について',
          'デジタルコンテンツの性質上、原則として返品・返金はお受けできません。\n\n'
          'ただし、以下の場合は返金申請が可能です：\n'
          '• Apple App Storeの返金ポリシーに基づく正当な理由がある場合\n'
          '• 技術的な問題により正常にサービスが提供されない場合\n'
          '• 誤って購入した場合（購入後すぐに申請が必要）\n\n'
          '返金申請方法：\n'
          'Apple App Storeサポートへ直接お問い合わせください。',
        ),
        _buildTableRow(
          '解約方法',
          'iOS:\n'
          '設定アプリ → Apple ID → サブスクリプション → GYM MATCH → サブスクリプションをキャンセル\n\n'
          '注意事項:\n'
          '• 解約は次回更新日の24時間前までに行ってください\n'
          '• 解約後も、現在の請求期間終了まではサービスをご利用いただけます\n'
          '• 解約後、Freeプランに自動的に移行されます',
        ),
        _buildTableRow(
          'サービス内容',
          'GYM MATCH - トレーニング管理アプリ\n\n'
          '主な機能:\n'
          '• トレーニング記録の管理・保存\n'
          '• ジム検索・位置情報表示（Google Maps連携）\n'
          '• AIによるトレーニングメニュー提案（Gemini API使用）\n'
          '• トレーニングデータの分析・可視化\n'
          '• 過去のトレーニング履歴閲覧\n\n'
          'プラン別機能:\n'
          '• Freeプラン: 基本機能、広告表示あり、AI機能は広告視聴で月3回まで\n'
          '• Premiumプラン: 広告非表示、AI機能月10回利用可能\n'
          '• Proプラン: 広告非表示、AI機能月30回利用可能',
        ),
        _buildTableRow(
          '動作環境',
          'iOS 12.0以降のiPhone/iPad\n※安定した動作にはiOS 14.0以降を推奨',
        ),
      ],
    );
  }

  Widget _buildTableRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade700, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                '📌 重要事項',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• 本サービスは継続課金型のサブスクリプションサービスです\n'
            '• 自動更新を停止しない限り、毎月自動的に課金されます\n'
            '• サブスクリプションの管理・解約は、Apple App Storeの設定から行えます\n'
            '• 本サービスのトレーニング提案は参考情報であり、医学的アドバイスではありません\n'
            '• 運動を始める前に医師に相談することを推奨します',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedLinks() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'プライバシーポリシー・利用規約',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '本サービスのプライバシーポリシーおよび利用規約は、アプリ内の設定メニューからご確認いただけます。',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.privacy_tip_outlined, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              const Text(
                '設定 → プライバシーポリシー',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.description_outlined, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              const Text(
                '設定 → 利用規約',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contact_mail, color: Colors.deepPurple.shade700),
              const SizedBox(width: 8),
              Text(
                'お問い合わせ先',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '本表記に関するご質問、サービスに関するお問い合わせは、以下までご連絡ください。',
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
            'X（旧Twitter）: @MatchGym71830',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            '（対応時間: 平日 10:00-18:00）',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '※お問い合わせへの回答には数日かかる場合がございます。予めご了承ください。',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
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
