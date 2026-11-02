import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/food_diary/food_diary_entry.dart';
import '../../data/services/food_db_service.dart';
import '../../data/services/food_diary_service.dart';
import '../../theme/app_colors.dart';
import 'food_search_sheet.dart';

Future<FoodDiaryEntry?> showEditFoodDiarySheet(
  BuildContext context,
  FoodDiaryEntry entry,
) {
  return showModalBottomSheet<FoodDiaryEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EditFoodDiarySheet(entry: entry),
  );
}

class _EditFoodDiarySheet extends StatefulWidget {
  final FoodDiaryEntry entry;
  const _EditFoodDiarySheet({required this.entry});

  @override
  State<_EditFoodDiarySheet> createState() => _EditFoodDiarySheetState();
}

class _EditFoodDiarySheetState extends State<_EditFoodDiarySheet> {
  late FoodItem food;
  double portion = 1.0;

  @override
  void initState() {
    super.initState();
    food = Get.find<FoodDbService>().byId(widget.entry.foodId) ??
        FoodItem(
          id: widget.entry.foodId,
          nameEn: widget.entry.name,
          nameRoman: widget.entry.name,
          aliases: const [],
          serving: widget.entry.serving,
          calories: widget.entry.calories,
          protein: widget.entry.protein,
          carbs: widget.entry.carbs,
          fat: widget.entry.fat,
          fibre: 0,
        );
    portion = widget.entry.portion;
  }

  Future<void> _save() async {
    final updated = await Get.find<FoodDiaryService>().editEntry(
      id: widget.entry.id,
      food: food,
      portion: portion,
    );
    if (mounted) Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Correct meal',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(food.nameEn),
            subtitle: Text('${food.serving} · ${food.calories} kcal'),
            trailing: TextButton(
              onPressed: () async {
                final picked = await showFoodSearchSheet(context);
                if (picked != null) setState(() => food = picked);
              },
              child: const Text('Change'),
            ),
          ),
          Text('Portion × ${portion.toStringAsFixed(1)}'),
          Slider(
            value: portion,
            min: 0.5,
            max: 3,
            divisions: 5,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => portion = v),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Save · ${(food.calories * portion).round()} kcal',
                style: const TextStyle(
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
