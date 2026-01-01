import 'package:gym_match/gen/app_localizations.dart';
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
    AppLocalizations.of(context)!.gym_bd5c63c1,
    AppLocalizations.of(context)!.gym_d816d814,
    AppLocalizations.of(context)!.gym_62b8a10f,
    AppLocalizations.of(context)!.gym_a88b1eac,
    AppLocalizations.of(context)!.gym_3f1c4a99,
    AppLocalizations.of(context)!.personalTraining,
    AppLocalizations.of(context)!.gym_0f5d9dd9,
    'Wi-Fi',
    AppLocalizations.of(context)!.gym_6cec8734,
    AppLocalizations.of(context)!.gym_fc767436,
    AppLocalizations.of(context)!.gym_ae762a12,
    AppLocalizations.of(context)!.gym_7d1e3afa,
    AppLocalizations.of(context)!.gym_1741ee33,
    AppLocalizations.of(context)!.gym_bdb55ce3,
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
        final data = gymDoc.data();
        if (data == null) {
          throw Exception(AppLocalizations.of(context)!.gym_c7e47d32);
        }
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
            content: Text(AppLocalizations.of(context)!.dataLoadError),
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.saved),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.saveFailed),
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
        title: Text(AppLocalizations.of(context)!.addWorkout),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.gym_17c1e0c7,
                hintText: '例: レッグプレス',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: countController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.gym_d441d8be,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
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
            child: Text(AppLocalizations.of(context)!.add),
          ),
        ],
      ),
    ).then((_) {
      // メモリリーク防止：Controllerを破棄
      nameController.dispose();
      countController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.edit),
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
                  : Icon(Icons.save),
              label: Text(AppLocalizations.of(context)!.save),
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
                  AppLocalizations.of(context)!.gym_841a92b0,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addEquipment,
                  icon: Icon(Icons.add),
                  label: Text(AppLocalizations.of(context)!.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_equipment.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(AppLocalizations.of(context)!.emailNotRegistered),
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
              AppLocalizations.of(context)!.gym_36f6e41f,
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
