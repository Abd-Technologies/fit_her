import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/food_prefs/food_preferences.dart';
import '../../data/services/food_preferences_service.dart';
import '../../theme/app_colors.dart';

/// 2NH1 — diet type, allergies (hard), dislikes (soft).
class FoodPreferencesScreen extends StatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  State<FoodPreferencesScreen> createState() => _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends State<FoodPreferencesScreen> {
  late String dietType;
  late Set<String> allergies;
  late Set<String> dislikes;
  final _dislikeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cur = Get.find<FoodPreferencesService>().current.value;
    dietType = cur.dietType;
    allergies = {...cur.allergies};
    dislikes = {...cur.dislikes};
  }

  @override
  void dispose() {
    _dislikeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await Get.find<FoodPreferencesService>().save(FoodPreferences(
      dietType: dietType,
      allergies: allergies.toList(),
      dislikes: dislikes.toList(),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food preferences saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Food preferences'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Diet type',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FoodPreferences.dietTypes.map((d) {
              return ChoiceChip(
                label: Text(d.replaceAll('_', ' ')),
                selected: dietType == d,
                onSelected: (_) => setState(() => dietType = d),
                selectedColor: AppColors.primary.withValues(alpha: 0.25),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Allergies (hard block)',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'These never appear in plans, scores, or grocery swaps.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF6F8B7A),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FoodPreferences.allergyOptions.map((a) {
              final on = allergies.contains(a);
              return FilterChip(
                label: Text(a),
                selected: on,
                onSelected: (v) => setState(() {
                  if (v) {
                    allergies.add(a);
                  } else {
                    allergies.remove(a);
                  }
                }),
                selectedColor: const Color(0xFFFFE0E0),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Dislikes (soft)',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dislikeCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. bitter gourd',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final t = _dislikeCtrl.text.trim();
                  if (t.isEmpty) return;
                  setState(() {
                    dislikes.add(t.toLowerCase());
                    _dislikeCtrl.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: dislikes
                .map(
                  (d) => Chip(
                    label: Text(d),
                    onDeleted: () => setState(() => dislikes.remove(d)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
