/// 📚 科学的引用カードウィジェット
/// 
/// 論文の引用情報を表示するカード
library;

import 'package:flutter/material.dart';

/// 科学的引用カード
class ScientificCitationCard extends StatelessWidget {
  final String citation;
  final String finding;
  final String? effectSize;
  final bool isExpanded;

  const ScientificCitationCard({
    super.key,
    required this.citation,
    required this.finding,
    this.effectSize,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 0,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // アイコン
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.science,
                size: 16,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 12),

            // コンテンツ
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 引用
                  Text(
                    citation,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 発見内容
                  Text(
                    finding,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),

                  // 効果量
                  if (effectSize != null && effectSize != 'N/A') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        effectSize!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 科学的根拠セクション（折りたたみ可能）
class ScientificBasisSection extends StatefulWidget {
  final List<Map<String, String>> basis;

  const ScientificBasisSection({
    super.key,
    required this.basis,
  });

  @override
  State<ScientificBasisSection> createState() =>
      _ScientificBasisSectionState();
}

class _ScientificBasisSectionState extends State<ScientificBasisSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.school,
              color: Colors.blue.shade700,
            ),
            title: const Text(
              AppLocalizations.of(context)!.scientificBasis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              '${widget.basis.length}本の査読付き論文',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
              ),
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: widget.basis.map((item) {
                  return ScientificCitationCard(
                    citation: item['citation']!,
                    finding: item['finding']!,
                    effectSize: item['effectSize'],
                    isExpanded: true,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 信頼度インジケーター
class ConfidenceIndicator extends StatelessWidget {
  final int paperCount;

  const ConfidenceIndicator({
    super.key,
    required this.paperCount,
  });

  @override
  Widget build(BuildContext context) {
    // 論文数に基づく信頼度（3段階）
    String level;
    Color color;
    IconData icon;

    if (paperCount >= 5) {
      level = AppLocalizations.of(context)!.general_23ce592c;
      color = Colors.green;
      icon = Icons.verified;
    } else if (paperCount >= 3) {
      level = AppLocalizations.of(context)!.general_9afb9ad5;
      color = Colors.orange;
      icon = Icons.check_circle;
    } else {
      level = AppLocalizations.of(context)!.general_310ee291;
      color = Colors.grey;
      icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            level,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($paperCount本)',
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
