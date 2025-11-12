import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ジム設備・施設編集画面（GYMMATCHManager用）
/// 
/// 機能:
/// - マシン・器具の追加・編集・削除
/// - 台数管理
/// - 施設・設備情報の編集（サウナ、プール、etc）
class GymEquipmentEditorScreen extends StatefulWidget {
  final String gymId;
  
  const GymEquipmentEditorScreen({
    super.key,
    required this.gymId,
  });

  @override
  State<GymEquipmentEditorScreen> createState() => _GymEquipmentEditorScreenState();
}

class _GymEquipmentEditorScreenState extends State<GymEquipmentEditorScreen> {
  Map<String, int> _equipment = {};
  List<String> _facilities = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // 設備候補
  final List<String> _facilityOptions = [
    'シャワー室',
    'サウナ',
    'プール',
    'スパ',
    'ロッカールーム',
    'パーソナルトレーニング',
    'グループレッスン',
    'Wi-Fi',
    '駐車場',
    '24時間営業',
    '女性専用エリア',
    'ストレッチエリア',
    '有酸素エリア',
    'フリーウェイトエリア',
  ];

  @override
  void initState() {
    super.initState();
    _loadGymData();
  }

  Future<void> _loadGymData() async {
    setState(() => _isLoading = true);

    try {
      final gymDoc = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .get();

      if (gymDoc.exists) {
        final data = gymDoc.data()!;
        setState(() {
          _equipment = data['equipment'] != null
              ? Map<String, int>.from(data['equipment'])
              : {};
          _facilities = data['facilities'] != null
              ? List<String>.from(data['facilities'])
              : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データ読み込みエラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .update({
        'equipment': _equipment,
        'facilities': _facilities,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _addEquipment() {
    final nameController = TextEditingController();
    final countController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('マシン・器具を追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '器具名',
                hintText: '例: レッグプレス',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: countController,
              decoration: const InputDecoration(
                labelText: '台数',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final count = int.tryParse(countController.text) ?? 1;
              
              if (name.isNotEmpty) {
                setState(() {
                  _equipment[name] = count;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設備・施設編集'),
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('保存'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // マシン・器具セクション
                  _buildEquipmentSection(),
                  const SizedBox(height: 32),
                  
                  // 施設・設備セクション
                  _buildFacilitiesSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildEquipmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'マシン・器具',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addEquipment,
                  icon: const Icon(Icons.add),
                  label: const Text('追加'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_equipment.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('まだマシン・器具が登録されていません'),
                ),
              )
            else
              ..._equipment.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 台数調整
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() {
                            if (entry.value > 1) {
                              _equipment[entry.key] = entry.value - 1;
                            }
                          });
                        },
                      ),
                      Text(
                        '${entry.value}台',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setState(() {
                            _equipment[entry.key] = entry.value + 1;
                          });
                        },
                      ),
                      // 削除
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _equipment.remove(entry.key);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitiesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '施設・設備',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _facilityOptions.map((facility) {
                final isSelected = _facilities.contains(facility);
                return FilterChip(
                  label: Text(facility),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _facilities.add(facility);
                      } else {
                        _facilities.remove(facility);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
