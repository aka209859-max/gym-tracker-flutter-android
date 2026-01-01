import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gym.dart';

/// パートナーオーナー専用: ビジター予約設定画面
class PartnerReservationSettingsScreen extends StatefulWidget {
  final String gymId;

  const PartnerReservationSettingsScreen({super.key, required this.gymId});

  @override
  State<PartnerReservationSettingsScreen> createState() =>
      _PartnerReservationSettingsScreenState();
}

class _PartnerReservationSettingsScreenState
    extends State<PartnerReservationSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _acceptsVisitors = false;
  Gym? _gym;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// 設定読み込み
  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore.collection('gyms').doc(widget.gymId).get();
      if (doc.exists) {
        _gym = Gym.fromFirestore(doc);
        setState(() {
          _acceptsVisitors = _gym?.acceptsVisitors ?? false;
          _emailController.text = _gym?.reservationEmail ?? '';
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

  /// 保存処理
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _firestore.collection('gyms').doc(widget.gymId).update({
        'acceptsVisitors': _acceptsVisitors,
        'reservationEmail': _emailController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 予約設定を更新しました！'),
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
        title: Text(AppLocalizations.of(context)!.settings),
        backgroundColor: Colors.orange[700],
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
              onPressed: _isSaving ? null : _saveSettings,
              tooltip: AppLocalizations.of(context)!.save,
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
                                  color: Colors.orange, size: 32),
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
                              AppLocalizations.of(context)!.settings,
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ビジター受付ON/OFF
                    Card(
                      child: SwitchListTile(
                        value: _acceptsVisitors,
                        onChanged: (value) {
                          setState(() {
                            _acceptsVisitors = value;
                          });
                        },
                        title: const Text(
                          AppLocalizations.of(context)!.profile_285758a8,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          _acceptsVisitors
                              ? AppLocalizations.of(context)!.profile_a54b51da
                              : AppLocalizations.of(context)!.profile_b3857acd,
                          style: const TextStyle(fontSize: 13),
                        ),
                        secondary: Icon(
                          _acceptsVisitors ? Icons.check_circle : Icons.cancel,
                          color:
                              _acceptsVisitors ? Colors.green : Colors.grey,
                          size: 32,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // メールアドレス設定
                    Text(AppLocalizations.of(context)!.email,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.email,
                        hintText: 'reservation@gym.com',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                        helperText: AppLocalizations.of(context)!.email,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: _acceptsVisitors,
                      validator: (value) {
                        if (_acceptsVisitors) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocalizations.of(context)!.emailRequired;
                          }
                          if (!value.contains('@')) {
                            return AppLocalizations.of(context)!.enterValidEmailAddress;
                          }
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // 注意事項
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber,
                              color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '※ 複数店舗を運営されている場合は、各店舗ごとに異なるメールアドレスを設定してください。\n※ 予約通知は現在Firebase Functions経由で送信されます（別途設定が必要です）。',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // プレビュー
                    if (_acceptsVisitors) ...[
                      const Text(
                        AppLocalizations.of(context)!.profile_599b1faa,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[600],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle,
                                            size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          AppLocalizations.of(context)!.visitorWelcome,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.orange[700]!, width: 2),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        color: Colors.orange[700]),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        AppLocalizations.of(context)!.visitorBooking,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.chevron_right,
                                        color: Colors.orange[700]),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 保存ボタン
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
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
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
