
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../conditions/condition_module_engine.dart';
import '../../theme/app_colors.dart';
import 'condition_detail_screen.dart';

/// 3H1–3H11 condition module picker + engine.
class ConditionModulesScreen extends StatelessWidget {
  const ConditionModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = Get.find<ConditionModuleEngine>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Condition modules'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: Obx(() {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Multi-select. When rules conflict, the cautious setting wins.',
              style: TextStyle(color: Color(0xFF6F8B7A), fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...engine.catalog.map((m) {
              final on = engine.activeIds.contains(m.id);
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFD8EDD4)),
                ),
                child: SwitchListTile(
                  activeColor: AppColors.primary,
                  title: Text(m.title),
                  subtitle: Text(
                    on ? 'Active · tap for module tools' : 'Off',
                  ),
                  value: on,
                  onChanged: (v) => engine.setActive(m.id, v),
                  secondary: IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => Get.to(
                      () => ConditionDetailScreen(moduleId: m.id),
                    ),
                  ),
                ),
              );
            }),
            if (engine.activeModules.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Notification cap today: ${engine.notificationCap}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(engine.combinedSafetyPrompt,
                  style: const TextStyle(fontSize: 12)),
            ],
          ],
        );
      }),
    );
  }
}
