import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RMCalculatorScreen extends StatelessWidget {
  const RMCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('計算ツール'),
          backgroundColor: theme.colorScheme.primary,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            unselectedLabelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.calculate, size: 24), text: '1RM計算'),
              Tab(icon: Icon(Icons.fitness_center, size: 24), text: 'プレート計算'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OneRMCalculatorTab(),
            _PlateCalculatorTab(),
          ],
        ),
      ),
    );
  }
}

/// 1RM計算タブ
class _OneRMCalculatorTab extends StatefulWidget {
  const _OneRMCalculatorTab();

  @override
  State<_OneRMCalculatorTab> createState() => _OneRMCalculatorTabState();
}

class _OneRMCalculatorTabState extends State<_OneRMCalculatorTab> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  Map<int, double>? _rmResults;

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _calculateRM() {
    final weight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);

    if (weight != null && reps != null && reps > 0) {
      final oneRM = weight * (1 + reps / 30);
      
      final results = <int, double>{};
      for (int i = 1; i <= 20; i++) {
        results[i] = oneRM / (1 + (i - 1) / 30);
      }
      
      setState(() {
        _rmResults = results;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正しい数値を入力してください'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'RM (Repetition Maximum) 計算',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '挙上した重量と回数から、1RMを計算します',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onEditingComplete: () => FocusScope.of(context).nextFocus(),
            decoration: InputDecoration(
              labelText: '重量 (kg)',
              hintText: '例: 80',
              prefixIcon: const Icon(Icons.fitness_center),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextField(
            controller: _repsController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onEditingComplete: () => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              labelText: '回数',
              hintText: '例: 5',
              prefixIcon: const Icon(Icons.repeat),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              _calculateRM();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              '1RMを計算',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          if (_rmResults != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'RM計算結果（1～20RM）',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: 20,
                      itemBuilder: (context, index) {
                        final rm = index + 1;
                        final weight = _rmResults![rm]!;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: rm == 1 
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: rm == 1
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[300]!,
                              width: rm == 1 ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (rm == 1)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '最大',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (rm == 1) const SizedBox(width: 8),
                                  Text(
                                    '${rm}RM',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: rm == 1 ? FontWeight.bold : FontWeight.w600,
                                      color: rm == 1 
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    weight.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: rm == 1 ? 24 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: rm == 1
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'kg',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    const Text(
                      'RMについて',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• RM (Repetition Maximum)：特定の回数で挙上可能な最大重量\n'
                  '• 1RM：1回だけ挙上できる最大重量\n'
                  '• この計算はEpley式を使用しています\n'
                  '• 実際の1RMとは誤差がある可能性があります',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
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
}

/// プレート計算タブ（完全カスタマイズ版・視認性改善）
class _PlateCalculatorTab extends StatefulWidget {
  const _PlateCalculatorTab();

  @override
  State<_PlateCalculatorTab> createState() => _PlateCalculatorTabState();
}

class _PlateCalculatorTabState extends State<_PlateCalculatorTab> {
  final _targetWeightController = TextEditingController();
  double _barWeight = 20.0;
  Map<double, int>? _plateResults;
  
  // 利用可能なプレート一覧（すべてのプレート）
  static final Map<double, Color> _allPlates = {
    25.0: const Color(0xFFE53935),   // 赤 (25kg)
    20.0: const Color(0xFF1E88E5),   // 青 (20kg)
    15.0: const Color(0xFFFFB300),   // 黄色 (15kg)
    10.0: const Color(0xFF43A047),   // 緑 (10kg)
    5.0: const Color(0xFFFFFFFF),    // 白 (5kg)
    2.5: const Color(0xFF757575),    // グレー (2.5kg)
    1.25: const Color(0xFFAAAAAA),   // ライトグレー (1.25kg)
    1.0: const Color(0xFF90CAF9),    // ライトブルー (1kg)
    0.5: const Color(0xFFA5D6A7),    // ライトグリーン (0.5kg)
    0.25: const Color(0xFFFFE082),   // ライトイエロー (0.25kg)
  };
  
  // ユーザーが選択したプレート（デフォルトは標準セット）
  Set<double> _selectedPlates = {25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25, 1.0, 0.5, 0.25};
  
  bool _showPlateSettings = false;

  @override
  void initState() {
    super.initState();
    _loadPlateSettings();
  }

  @override
  void dispose() {
    _targetWeightController.dispose();
    super.dispose();
  }

  // プレート設定を読み込み
  Future<void> _loadPlateSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPlates = prefs.getStringList('selected_plates');
    if (savedPlates != null) {
      setState(() {
        _selectedPlates = savedPlates.map((s) => double.parse(s)).toSet();
      });
    }
  }

  // プレート設定を保存
  Future<void> _savePlateSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_plates',
      _selectedPlates.map((p) => p.toString()).toList(),
    );
  }

  // プリセット適用
  void _applyPreset(String preset) {
    setState(() {
      switch (preset) {
        case 'standard':
          _selectedPlates = {25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25, 1.0, 0.5, 0.25};
          break;
        case '20kg_base':
          _selectedPlates = {20.0, 15.0, 10.0, 5.0, 2.5, 1.25, 1.0, 0.5, 0.25};
          break;
        case 'basic':
          _selectedPlates = {20.0, 10.0, 5.0, 2.5};
          break;
      }
    });
    _savePlateSettings();
  }

  void _calculatePlates() {
    final targetWeight = double.tryParse(_targetWeightController.text);

    if (targetWeight == null || targetWeight <= _barWeight) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('バーの重量（${_barWeight}kg）より大きい値を入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedPlates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('利用可能なプレートを1つ以上選択してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double weightPerSide = (targetWeight - _barWeight) / 2;
    Map<double, int> plates = {};
    
    // 選択されたプレートを重い順にソート
    List<double> availablePlates = _selectedPlates.toList()..sort((a, b) => b.compareTo(a));

    for (double plate in availablePlates) {
      int count = (weightPerSide / plate).floor();
      if (count > 0) {
        plates[plate] = count;
        weightPerSide -= plate * count;
      }
    }

    setState(() {
      _plateResults = plates;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // タイトル
          const Text(
            'プレート計算機',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'バーベルに必要なプレート組み合わせを計算',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // プレート設定セクション
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings, color: theme.colorScheme.primary, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          '利用可能なプレート',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        _showPlateSettings ? Icons.expand_less : Icons.expand_more,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _showPlateSettings = !_showPlateSettings;
                        });
                      },
                    ),
                  ],
                ),
                
                if (_showPlateSettings) ...[
                  const SizedBox(height: 16),
                  
                  // クイック設定プリセット
                  const Text(
                    'クイック設定',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _presetButton('標準セット', 'standard', theme),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _presetButton('20kgベース', '20kg_base', theme),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _presetButton('基本セット', 'basic', theme),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // プレート個別選択
                  const Text(
                    'プレート選択（タップでON/OFF）',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allPlates.entries.map((entry) {
                      final plateWeight = entry.key;
                      final plateColor = entry.value;
                      final isSelected = _selectedPlates.contains(plateWeight);
                      
                      return _plateTile(plateWeight, plateColor, isSelected, theme);
                    }).toList(),
                  ),
                ],
                
                // 選択中のプレート表示（常に表示）
                if (!_showPlateSettings) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (() {
                      final sortedPlates = _selectedPlates.toList()
                        ..sort((a, b) => b.compareTo(a));
                      return sortedPlates.map((plate) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _allPlates[plate]!.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _allPlates[plate]!),
                          ),
                          child: Text(
                            '${plate}kg',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList();
                    })(),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // バー重量選択
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.straighten, color: Colors.grey[700], size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'バーの重量',
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
                    Expanded(
                      child: _barWeightButton(20.0, '20kg\n(標準)', theme),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _barWeightButton(15.0, '15kg\n(女性用)', theme),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _barWeightButton(10.0, '10kg\n(軽量)', theme),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 目標重量入力（大きく見やすく）
          TextField(
            controller: _targetWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onEditingComplete: () => FocusScope.of(context).unfocus(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: '目標重量 (kg)',
              labelStyle: const TextStyle(fontSize: 16),
              hintText: '例: 100',
              hintStyle: TextStyle(fontSize: 18, color: Colors.grey[400]),
              prefixIcon: Icon(Icons.fitness_center, size: 28, color: theme.colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 計算ボタン（大きく）
          ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              _calculatePlates();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: const Text(
              'プレートを計算',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 計算結果（視認性大幅改善）
          if (_plateResults != null && _plateResults!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                    theme.colorScheme.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ヘッダー
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '片側のプレート',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '両側に同じ組み合わせを装着',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // プレートリスト（大きく見やすく）
                  ..._plateResults!.entries.map((entry) {
                    final plateWeight = entry.key;
                    final plateCount = entry.value;
                    final plateColor = _allPlates[plateWeight] ?? Colors.grey;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: plateColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: plateColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // プレート視覚化
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: plateColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: plateColor, width: 4),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$plateWeight',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: plateColor == const Color(0xFFFFFFFF) 
                                          ? Colors.black 
                                          : plateColor,
                                    ),
                                  ),
                                  Text(
                                    'kg',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 24),
                          
                          // 乗算記号
                          Text(
                            '×',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          
                          const SizedBox(width: 24),
                          
                          // 枚数表示（大きく）
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: plateColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$plateCount枚',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: plateColor == const Color(0xFFFFFFFF) 
                                      ? Colors.black 
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 16),
                  
                  // 合計重量確認
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          '合計: ${_calculateTotalWeight().toStringAsFixed(1)}kg',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // 参考情報
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    const Text(
                      '使い方のヒント',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• ジムにあるプレートだけを選択してください\n'
                  '• プリセットから選択すると素早く設定できます\n'
                  '• 設定は自動保存されます\n'
                  '• 表示されるのは片側の枚数です（両側に装着）',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
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

  // 合計重量を計算
  double _calculateTotalWeight() {
    if (_plateResults == null) return 0;
    
    double plateTotalOneSide = 0;
    _plateResults!.forEach((weight, count) {
      plateTotalOneSide += weight * count;
    });
    
    return _barWeight + (plateTotalOneSide * 2);
  }

  // プリセットボタン
  Widget _presetButton(String label, String presetId, ThemeData theme) {
    return OutlinedButton(
      onPressed: () => _applyPreset(presetId),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        side: BorderSide(color: theme.colorScheme.primary, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // プレートタイル（選択用）
  Widget _plateTile(double weight, Color color, bool isSelected, ThemeData theme) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedPlates.remove(weight);
          } else {
            _selectedPlates.add(weight);
          }
        });
        _savePlateSettings();
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.3) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$weight',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color == const Color(0xFFFFFFFF) ? Colors.black : color,
                    ),
                  ),
                  Text(
                    'kg',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: color == const Color(0xFFFFFFFF) ? Colors.black : Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // バー重量選択ボタン
  Widget _barWeightButton(double weight, String label, ThemeData theme) {
    final isSelected = _barWeight == weight;
    return InkWell(
      onTap: () {
        setState(() {
          _barWeight = weight;
          _plateResults = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
