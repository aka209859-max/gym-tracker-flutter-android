import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gym.dart';

/// パートナーオーナー専用: マシン・設備情報編集画面
class PartnerEquipmentEditorScreen extends StatefulWidget {
  final String gymId;

  const PartnerEquipmentEditorScreen({super.key, required this.gymId});

  @override
  State<PartnerEquipmentEditorScreen> createState() =>
      _PartnerEquipmentEditorScreenState();
}

class _PartnerEquipmentEditorScreenState
    extends State<PartnerEquipmentEditorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // マシン種類のマスタリスト
  final List<String> _availableEquipment = [
    AppLocalizations.of(context)!.general_c43e173a,
    AppLocalizations.of(context)!.gym_8b54efdd,
    AppLocalizations.of(context)!.exerciseLegPress,
    AppLocalizations.of(context)!.exerciseBenchPress,
    AppLocalizations.of(context)!.general_34cda07f,
    AppLocalizations.of(context)!.gym_40e07129,
    AppLocalizations.of(context)!.exerciseAerobicBike,
    AppLocalizations.of(context)!.dumbbell,
    AppLocalizations.of(context)!.barbell,
    AppLocalizations.of(context)!.exerciseLatPulldown,
    AppLocalizations.of(context)!.exerciseLegExtension,
    AppLocalizations.of(context)!.exerciseLegCurl,
    AppLocalizations.of(context)!.general_921ddbac,
    AppLocalizations.of(context)!.exerciseShoulderPress,
    AppLocalizations.of(context)!.exercise_cfc4f367,
    AppLocalizations.of(context)!.general_c2994ab4,
    AppLocalizations.of(context)!.workout_c196525e,
    AppLocalizations.of(context)!.workout_4c6d7db7,
    AppLocalizations.of(context)!.general_58db9535,
    AppLocalizations.of(context)!.bodyPartOther,
  ];

  Map<String, int> _equipmentData = {};
  bool _isLoading = true;
  bool _isSaving = false;
  Gym? _gym;

  @override
  void initState() {
    super.initState();
    _loadEquipmentData();
  }

  /// 設備データ読み込み
  Future<void> _loadEquipmentData() async {
    try {
      final doc = await _firestore.collection('gyms').doc(widget.gymId).get();
      if (doc.exists) {
        _gym = Gym.fromFirestore(doc);
        setState(() {
          _equipmentData = _gym?.equipment ?? {};
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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

  /// マシン台数を更新
  void _updateEquipmentCount(String equipment, int count) {
    setState(() {
      if (count > 0) {
        _equipmentData[equipment] = count;
      } else {
        _equipmentData.remove(equipment);
      }
    });
  }

  /// 保存処理
  Future<void> _saveEquipmentData() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _firestore.collection('gyms').doc(widget.gymId).update({
        'equipment': _equipmentData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 設備情報を更新しました！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.edit),
        backgroundColor: Colors.amber[700],
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveEquipmentData,
              tooltip: AppLocalizations.of(context)!.saveWorkout,
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
                  // 店舗情報
                  if (_gym != null) ...[
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.fitness_center,
                                color: Colors.amber, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _gym!.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _gym!.address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 説明
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue[700], size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.confirm,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // マシンリスト
                  const Text(
                    AppLocalizations.of(context)!.gym_2689426f,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // マシン選択リスト
                  ..._availableEquipment.map((equipment) {
                    final currentCount = _equipmentData[equipment] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // マシン名
                            Expanded(
                              child: Text(
                                equipment,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 台数選択
                            Row(
                              children: [
                                IconButton(
                                  onPressed: currentCount > 0
                                      ? () => _updateEquipmentCount(
                                          equipment, currentCount - 1)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: Colors.red[700],
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '$currentCount',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: currentCount < 99
                                      ? () => _updateEquipmentCount(
                                          equipment, currentCount + 1)
                                      : null,
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: Colors.blue[700],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // 保存ボタン
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveEquipmentData,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.save),
                      label: Text(AppLocalizations.of(context)!.save,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
