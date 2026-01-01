import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/advanced_fatigue_service.dart';

/// Phase 2b: 個人要因編集画面
/// 
/// Personal Factor Multiplier (PFM) の計算に使用される
/// 静的要因（年齢・経験）と動的要因（睡眠・栄養・アルコール）を編集
class PersonalFactorsScreen extends StatefulWidget {
  const PersonalFactorsScreen({super.key});

  @override
  State<PersonalFactorsScreen> createState() => _PersonalFactorsScreenState();
}

class _PersonalFactorsScreenState extends State<PersonalFactorsScreen> {
  final AdvancedFatigueService _advancedService = AdvancedFatigueService();
  final _formKey = GlobalKey<FormState>();

  // フォームコントローラー
  late TextEditingController _ageController;
  late TextEditingController _experienceController;
  late TextEditingController _sleepController;
  late TextEditingController _proteinController;
  late TextEditingController _alcoholController;

  UserProfile? _currentProfile;
  double _currentPFM = 1.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserProfile();
  }

  void _initializeControllers() {
    _ageController = TextEditingController();
    _experienceController = TextEditingController();
    _sleepController = TextEditingController();
    _proteinController = TextEditingController();
    _alcoholController = TextEditingController();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _advancedService.getUserProfile();
      final pfm = _advancedService.calculatePersonalFactorMultiplier(profile);

      setState(() {
        _currentProfile = profile;
        _currentPFM = pfm;
        _ageController.text = profile.age.toString();
        _experienceController.text = profile.trainingExperienceYears.toString();
        _sleepController.text = profile.sleepHoursLastNight.toString();
        _proteinController.text = profile.dailyProteinIntakeGrams.toString();
        _alcoholController.text = profile.alcoholUnitsLastDay.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error)),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final updatedProfile = UserProfile(
        age: int.parse(_ageController.text),
        trainingExperienceYears: int.parse(_experienceController.text),
        sleepHoursLastNight: double.parse(_sleepController.text),
        dailyProteinIntakeGrams: double.parse(_proteinController.text),
        alcoholUnitsLastDay: int.parse(_alcoholController.text),
        lastUpdated: DateTime.now(),
      );

      await _advancedService.saveUserProfile(updatedProfile);
      final newPFM = _advancedService.calculatePersonalFactorMultiplier(updatedProfile);

      setState(() {
        _currentProfile = updatedProfile;
        _currentPFM = newPFM;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 保存完了！現在のPFM: ${newPFM.toStringAsFixed(2)}x'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 保存エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _experienceController.dispose();
    _sleepController.dispose();
    _proteinController.dispose();
    _alcoholController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
        title: const Text('🔬 個人要因設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // PFM表示カード
                    _buildPFMCard(),
                    const SizedBox(height: 24),
                    
                    // 静的要因セクション
                    _buildSectionHeader(AppLocalizations.of(context)!.personalFactor_a8e6bc91, '変更頻度: 低'),
                    const SizedBox(height: 12),
                    _buildStaticFactorsCard(),
                    const SizedBox(height: 24),
                    
                    // 動的要因セクション
                    _buildSectionHeader(AppLocalizations.of(context)!.personalFactor_380ea875, '変更頻度: 高（日々更新推奨）'),
                    const SizedBox(height: 12),
                    _buildDynamicFactorsCard(),
                    const SizedBox(height: 32),
                    
                    // 保存ボタン
                    ElevatedButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        _saveProfile();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        '💾 保存して PFM を更新',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 科学的根拠フッター
                    _buildScientificFooter(),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildPFMCard() {
    return Card(
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              '現在の Personal Factor Multiplier',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${_currentPFM.toStringAsFixed(2)}x',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.purple[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '基礎Training Loadに掛け算されます',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            Divider(height: 24),
            Text(
              '最終更新: ${_currentProfile?.lastUpdated != null ? _formatDateTime(_currentProfile!.lastUpdated) : AppLocalizations.of(context)!.notSet}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStaticFactorsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 年齢
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onEditingComplete: () => FocusScope.of(context).nextFocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.age,
                suffixText: AppLocalizations.of(context)!.personalFactor_cfa20784,
                helperText: '<25歳: 0.95x, 40-50歳: 1.05x, 50+歳: 1.10x',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.cake),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)!.personalFactor_03a1c2ca;
                }
                final age = int.tryParse(value);
                if (age == null || age < 10 || age > 100) {
                  return AppLocalizations.of(context)!.personalFactor_fb13f7ed;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // トレーニング経験年数
            TextFormField(
              controller: _experienceController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onEditingComplete: () => FocusScope.of(context).nextFocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.personalFactor_5a712682,
                suffixText: AppLocalizations.of(context)!.annualPrice,
                helperText: '<1年: 1.10x, 3-5年: 0.95x, 5+年: 0.90x',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.fitness_center),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)!.personalFactor_31098440;
                }
                final years = int.tryParse(value);
                if (years == null || years < 0 || years > 50) {
                  return AppLocalizations.of(context)!.personalFactor_47d86eef;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicFactorsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 睡眠時間
            TextFormField(
              controller: _sleepController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              onEditingComplete: () => FocusScope.of(context).nextFocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.personalFactor_db37d13b,
                suffixText: AppLocalizations.of(context)!.time,
                helperText: '<6時間: 1.15x, 8+時間: 0.95x',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.bedtime),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)!.personalFactor_f3409cdd;
                }
                final hours = double.tryParse(value);
                if (hours == null || hours < 0 || hours > 24) {
                  return AppLocalizations.of(context)!.personalFactor_616dc22d;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // タンパク質摂取量
            TextFormField(
              controller: _proteinController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              onEditingComplete: () => FocusScope.of(context).nextFocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.personalFactor_9f7b01f0,
                suffixText: AppLocalizations.of(context)!.personalFactor_4da8beb5,
                helperText: '<84g(1.2g/kg): 1.10x, 112+g(1.6g/kg): 0.95x (体重70kg想定)',
                helperMaxLines: 3,
                prefixIcon: Icon(Icons.restaurant),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)!.personalFactor_59352db7;
                }
                final protein = double.tryParse(value);
                if (protein == null || protein < 0 || protein > 500) {
                  return AppLocalizations.of(context)!.personalFactor_b7206655;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // アルコール摂取量
            TextFormField(
              controller: _alcoholController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.personalFactor_e8aa7dea,
                suffixText: AppLocalizations.of(context)!.personalFactor_ec2007be,
                helperText: '1ユニット毎に+5% (ビール350ml≒1.4ユニット)',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.local_bar),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)!.personalFactor_38c38095;
                }
                final units = int.tryParse(value);
                if (units == null || units < 0 || units > 20) {
                  return AppLocalizations.of(context)!.personalFactor_df82df91;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScientificFooter() {
    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, size: 16, color: Colors.grey[700]),
                SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.scientificBasis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Personal Factor Multiplier (PFM) は、年齢・経験・睡眠・栄養・アルコールの5要素を統合して個人の疲労感受性を補正します。\n\n'
              '範囲: 0.7x - 1.3x (最小30%減〜最大30%増)\n'
              AppLocalizations.of(context)!.personalFactor_a5772517,
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help, color: Colors.blue),
            SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.settings),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                AppLocalizations.of(context)!.personalFactor_56a6d8a6,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                '📊 静的要因',
                '変更頻度が低い要素です:\n'
                '• 年齢: 加齢による回復力の変化\n'
                '• トレーニング経験: 適応能力の違い',
              ),
              const SizedBox(height: 12),
              _buildHelpSection(
                '⚡ 動的要因',
                '日々変動する要素です:\n'
                '• 睡眠時間: 回復の質\n'
                '• タンパク質摂取: 筋肉回復の材料\n'
                '• アルコール: 回復阻害要因',
              ),
              const SizedBox(height: 12),
              _buildHelpSection(
                '🎯 推奨更新頻度',
                '• 静的要因: 数ヶ月に1回\n'
                '• 動的要因: トレーニング前日・当日に更新',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.personalFactor_24d99a0b,
                        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.readLess),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
