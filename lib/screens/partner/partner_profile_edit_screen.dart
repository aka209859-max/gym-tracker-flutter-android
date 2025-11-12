import 'package:flutter/material.dart';
import '../../services/partner_service.dart';

/// パートナープロフィール編集画面（簡易版）
class PartnerProfileEditScreen extends StatefulWidget {
  const PartnerProfileEditScreen({super.key});

  @override
  State<PartnerProfileEditScreen> createState() => _PartnerProfileEditScreenState();
}

class _PartnerProfileEditScreenState extends State<PartnerProfileEditScreen> {
  final PartnerService _partnerService = PartnerService();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _bioController = TextEditingController();
  String _experienceLevel = 'beginner';
  final List<String> _selectedExercises = [];
  final List<String> _selectedGoals = [];
  bool _isLoading = false;

  final List<String> _availableExercises = [
    'ベンチプレス', 'スクワット', 'デッドリフト', '懸垂',
    'ショルダープレス', 'バーベルロー', 'レッグプレス', '有酸素運動',
  ];

  final List<String> _availableGoals = [
    '筋力アップ', '筋肥大', 'ダイエット', '体力向上',
    'ボディメイク', 'コンテスト出場', '健康維持',
  ];

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _partnerService.updatePartnerProfile(
        bio: _bioController.text.trim(),
        experienceLevel: _experienceLevel,
        preferredExercises: _selectedExercises,
        goals: _selectedGoals,
        isAvailable: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プロフィールを更新しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'プロフィール編集',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 自己紹介
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: '自己紹介',
                hintText: 'トレーニングについて自由に書いてください',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '自己紹介を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // 経験レベル
            const Text('経験レベル', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _experienceLevel,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'beginner', child: Text('初心者')),
                DropdownMenuItem(value: 'intermediate', child: Text('中級者')),
                DropdownMenuItem(value: 'advanced', child: Text('上級者')),
              ],
              onChanged: (value) {
                setState(() => _experienceLevel = value!);
              },
            ),
            const SizedBox(height: 24),

            // 好きな種目
            const Text('好きな種目', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableExercises.map((exercise) {
                final isSelected = _selectedExercises.contains(exercise);
                return FilterChip(
                  label: Text(exercise),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedExercises.add(exercise);
                      } else {
                        _selectedExercises.remove(exercise);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 目標
            const Text('目標', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableGoals.map((goal) {
                final isSelected = _selectedGoals.contains(goal);
                return FilterChip(
                  label: Text(goal),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedGoals.add(goal);
                      } else {
                        _selectedGoals.remove(goal);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('保存', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
