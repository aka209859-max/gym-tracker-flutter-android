import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// パートナーリクエスト画面（未実装）
class PartnerRequestsScreen extends StatelessWidget {
  const PartnerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.profile_01b6f7d1),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.general_e2ae645c,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.addWorkout,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
