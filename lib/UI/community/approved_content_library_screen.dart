import 'package:flutter/material.dart';

/// 1P2 — seeded approved content library (CMS later).
class ApprovedContentLibraryScreen extends StatelessWidget {
  const ApprovedContentLibraryScreen({super.key});

  static const _items = [
    (
      'Iron in your luteal week',
      'Dietitian-approved tips for energy dips.',
      'Dietitian'
    ),
    (
      'When rest is the workout',
      'Doctor-reviewed guidance on listening to fatigue.',
      'Doctor'
    ),
    (
      'Community guidelines',
      'How we keep FitHer safe and kind.',
      'FitHer'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7E4),
      appBar: AppBar(
        title: const Text(
          'Approved library',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Color(0xFF163220),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF163220)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final item = _items[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD8EDD4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$3.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9AB09A),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.$1,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF163220),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Color(0xFF6F8B7A),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
