import 'package:gym_match/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// POセッション管理画面
class POSessionsScreen extends StatelessWidget {
  final String partnerId;

  const POSessionsScreen({super.key, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.general_119d8156,
              style: TextStyle(fontSize: 20, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.general_daeb1c39,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            const Chip(
              label: Text(AppLocalizations.of(context)!.general_ebcbe40e),
              backgroundColor: Colors.blue,
              labelStyle: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.addWorkout)),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
