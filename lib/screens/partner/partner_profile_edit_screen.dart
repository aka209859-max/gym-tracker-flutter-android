import 'package:gym_match/gen/app_localizations.dart';
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
    AppLocalizations.of(context)!.exerciseBenchPress, AppLocalizations.of(context)!.exerciseSquat, AppLocalizations.of(context)!.exerciseDeadlift, AppLocalizations.of(context)!.exercisePullUp,
    AppLocalizations.of(context)!.exerciseShoulderPress, AppLocalizations.of(context)!.profile_f95990eb, AppLocalizations.of(context)!.exerciseLegPress, AppLocalizations.of(context)!.cardio,
  ];

  final List<String> _availableGoals = [
    AppLocalizations.of(context)!.profile_6c3c4ee6, AppLocalizations.of(context)!.goalMuscleGain, AppLocalizations.of(context)!.goalDiet, AppLocalizations.of(context)!.profile_64b9cf75,
    AppLocalizations.of(context)!.profile_f415da04, AppLocalizations.of(context)!.profile_9c79b1fe, AppLocalizations.of(context)!.healthMaintenance,
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.updateProfileSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error),
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
        title: Text(AppLocalizations.of(context)!.editProfile,
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
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.bio,
                hintText: AppLocalizations.of(context)!.profile_8e9e3b47,
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppLocalizations.of(context)!.profile_f93815e7;
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // 経験レベル
            Text(AppLocalizations.of(context)!.experienceLevel, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _experienceLevel,
              decoration: InputDecoration(border: OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: 'beginner', child: Text(AppLocalizations.of(context)!.beginner)),
                DropdownMenuItem(value: 'intermediate', child: Text(AppLocalizations.of(context)!.levelIntermediate)),
                DropdownMenuItem(value: 'advanced', child: Text(AppLocalizations.of(context)!.advanced)),
              ],
              onChanged: (value) {
                setState(() => _experienceLevel = value!);
              },
            ),
            const SizedBox(height: 24),

            // 好きな種目
            Text(AppLocalizations.of(context)!.profile_539d673a, style: TextStyle(fontWeight: FontWeight.bold)),
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
            Text(AppLocalizations.of(context)!.goal, style: TextStyle(fontWeight: FontWeight.bold)),
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
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(AppLocalizations.of(context)!.save, style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
