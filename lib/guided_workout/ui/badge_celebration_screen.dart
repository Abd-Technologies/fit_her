import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 1M6 — one-shot badge unlock celebration.
class BadgeCelebrationScreen extends StatelessWidget {
  final String badgeId;
  final String title;
  final String message;

  const BadgeCelebrationScreen({
    super.key,
    required this.badgeId,
    required this.title,
    required this.message,
  });

  static const labels = <String, (String, String)>{
    'first_log': ('First log', 'You started building your body picture.'),
    'first_workout': ('First workout', 'You finished your first guided session.'),
    'streak_3': ('3-day streak', 'Three active days in a row.'),
    'streak_7': ('7-day streak', 'A full week of showing up.'),
    'streak_30': ('30-day streak', 'A month of consistency.'),
  };

  factory BadgeCelebrationScreen.forId(String id) {
    final pair = labels[id] ?? (id, 'Milestone unlocked');
    return BadgeCelebrationScreen(
      badgeId: id,
      title: pair.$1,
      message: pair.$2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF163220),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 72, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF163220),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
