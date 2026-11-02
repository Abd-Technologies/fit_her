import 'package:flutter/material.dart';

import '../../data/models/get_user_plan/get_workout_user_plan_details.dart';

/// X2 — optional live class tag chips for schedule rows.
class ClassTagChips extends StatelessWidget {
  final Slot slot;
  final ValueChanged<String>? onSelected;
  final String? selected;

  const ClassTagChips({
    super.key,
    required this.slot,
    this.onSelected,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final tags = <String>{
      ...slot.tags,
      if (slot.intensityTag != null) slot.intensityTag!,
      if (slot.type != null && slot.type!.isNotEmpty) slot.type!,
    };
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((t) {
        final isSelected = selected == t;
        return FilterChip(
          label: Text(
            t,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF4F6B5A),
            ),
          ),
          selected: isSelected,
          onSelected: onSelected == null ? null : (_) => onSelected!(t),
          selectedColor: const Color(0xFF6DC55A),
          backgroundColor: const Color(0xFFF3F8F1),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}
