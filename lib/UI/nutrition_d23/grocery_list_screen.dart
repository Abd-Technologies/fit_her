import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../../data/services/grocery_list_service.dart';
import '../../theme/app_colors.dart';

/// 2NH4 — AI grocery list with phase-aware swaps (local build).
class GroceryListScreen extends StatelessWidget {
  const GroceryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<GroceryListService>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Grocery list'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              String? phase;
              try {
                phase = Get.find<CycleThemeController>().phase.value.name;
              } catch (_) {}
              svc.rebuildFromSamplePlan(phase: phase);
            },
            child: const Text('Rebuild'),
          ),
        ],
      ),
      body: Obx(() {
        if (svc.items.isEmpty) {
          return Center(
            child: ElevatedButton(
              onPressed: () => svc.rebuildFromSamplePlan(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Build from my plan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }
        final byCat = <String, List<GroceryItem>>{};
        for (final i in svc.items) {
          byCat.putIfAbsent(i.category, () => []).add(i);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: byCat.entries.expand((e) {
            return [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  e.key,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              ...e.value.map(
                (item) => CheckboxListTile(
                  value: item.checked,
                  onChanged: (_) => svc.toggle(item.id),
                  activeColor: AppColors.primary,
                  title: Text(
                    item.name,
                    style: TextStyle(
                      decoration:
                          item.checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: item.phaseSwap == null
                      ? null
                      : Text(
                          'Phase swap: ${item.phaseSwap}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6F8B7A),
                          ),
                        ),
                ),
              ),
            ];
          }).toList(),
        );
      }),
    );
  }
}
