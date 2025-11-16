import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/workout_template.dart';

/// テンプレート作成画面
class CreateTemplateScreen extends StatefulWidget {
  const CreateTemplateScreen({super.key});

  @override
  State<CreateTemplateScreen> createState() => _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends State<CreateTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedMuscleGroup = '胸';
  final List<TemplateExerciseBuilder> _exercises = [];
  bool _isSaving = false;

  final List<String> _muscleGroups = ['胸', '背中', '脚', '肩', '二頭', '三頭'];
  
  @override
  void initState() {
    super.initState();
    _autoLoginIfNeeded();
  }
  
  /// 未ログイン時に自動的に匿名ログイン
  Future<void> _autoLoginIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        debugPrint('✅ テンプレート作成: 匿名認証成功');
      } catch (e) {
        debugPrint('❌ テンプレート作成: 匿名認証エラー: $e');
      }
    }
  }
  
  final Map<String, List<String>> _muscleGroupExercises = {
    '胸': ['ベンチプレス', 'ダンベルプレス', 'インクラインプレス', 'ケーブルフライ', 'ディップス'],
    '脚': ['スクワット', 'レッグプレス', 'レッグエクステンション', 'レッグカール', 'カーフレイズ'],
    '背中': ['デッドリフト', 'ラットプルダウン', 'ベントオーバーロウ', 'シーテッドロウ', '懸垂'],
    '肩': ['ショルダープレス', 'サイドレイズ', 'フロントレイズ', 'リアデルトフライ', 'アップライトロウ'],
    '二頭': ['バーベルカール', 'ダンベルカール', 'ハンマーカール', 'プリチャーカール', 'ケーブルカール'],
    '三頭': ['トライセプスエクステンション', 'スカルクラッシャー', 'ケーブルプッシュダウン', 'ディップス', 'キックバック'],
  };

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('テンプレート作成'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveTemplate,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check, color: Colors.white),
            label: const Text(
              '保存',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // テンプレート名
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'テンプレート名',
                hintText: '例: 胸トレーニング A',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'テンプレート名を入力してください';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // 説明（オプション）
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '説明（オプション）',
                hintText: '例: 胸を集中的に鍛えるメニュー',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 24),
            
            // 部位選択
            const Text(
              '主要部位',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _muscleGroups.map((group) {
                final isSelected = _selectedMuscleGroup == group;
                return ChoiceChip(
                  label: Text(group),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedMuscleGroup = group;
                    });
                  },
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 24),
            
            // 種目リスト
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '種目リスト',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('種目追加'),
                ),
              ],
            ),
            
            if (_exercises.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.fitness_center, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      '種目を追加してください',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              ..._exercises.asMap().entries.map((entry) {
                final index = entry.key;
                final exercise = entry.value;
                return _buildExerciseCard(index, exercise);
              }),
            
            const SizedBox(height: 80), // FAB用スペース
          ],
        ),
      ),
    );
  }

  /// 種目カード
  Widget _buildExerciseCard(int index, TemplateExerciseBuilder exercise) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: exercise.exerciseName,
                    decoration: const InputDecoration(
                      labelText: '種目',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _muscleGroupExercises[_selectedMuscleGroup]!
                        .map((name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        exercise.exerciseName = value!;
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _exercises.removeAt(index);
                    });
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: exercise.targetSets.toString(),
                    decoration: const InputDecoration(
                      labelText: 'セット数',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      exercise.targetSets = int.tryParse(value) ?? 3;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: exercise.targetReps.toString(),
                    decoration: const InputDecoration(
                      labelText: '回数',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      exercise.targetReps = int.tryParse(value) ?? 10;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: exercise.targetWeight?.toString() ?? '',
                    decoration: const InputDecoration(
                      labelText: '重量(kg)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      exercise.targetWeight = double.tryParse(value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 種目追加
  void _addExercise() {
    setState(() {
      _exercises.add(TemplateExerciseBuilder(
        exerciseName: _muscleGroupExercises[_selectedMuscleGroup]!.first,
        targetSets: 3,
        targetReps: 10,
      ));
    });
  }

  /// テンプレート保存
  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('種目を1つ以上追加してください')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // 匿名ログイン実装により、この状態には通常到達しない
        throw Exception('認証エラーが発生しました');
      }

      final template = WorkoutTemplate(
        id: '',
        userId: user.uid,
        name: _nameController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        muscleGroup: _selectedMuscleGroup,
        exercises: _exercises
            .map((e) => TemplateExercise(
                  exerciseName: e.exerciseName,
                  targetSets: e.targetSets,
                  targetReps: e.targetReps,
                  targetWeight: e.targetWeight,
                ))
            .toList(),
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('workout_templates')
          .add(template.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('テンプレートを保存しました')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

/// テンプレート種目ビルダー（編集用）
class TemplateExerciseBuilder {
  String exerciseName;
  int targetSets;
  int targetReps;
  double? targetWeight;

  TemplateExerciseBuilder({
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    this.targetWeight,
  });
}
