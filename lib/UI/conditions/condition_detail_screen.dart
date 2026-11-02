
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../conditions/condition_module_engine.dart';
import '../../theme/app_colors.dart';

class ConditionDetailScreen extends StatefulWidget {
  final String moduleId;
  const ConditionDetailScreen({super.key, required this.moduleId});

  @override
  State<ConditionDetailScreen> createState() => _ConditionDetailScreenState();
}

class _ConditionDetailScreenState extends State<ConditionDetailScreen> {
  final _note = TextEditingController();
  double pain = 5;
  String location = 'pelvis';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = Get.find<ConditionModuleEngine>();
    final mod = engine.catalog.firstWhereOrNull((m) => m.id == widget.moduleId);
    if (mod == null) {
      return const Scaffold(body: Center(child: Text('Unknown module')));
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(mod.title),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(mod.safetyPrompt, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          Text('Nutrition rules: ${mod.nutritionRules.join(", ")}'),
          Text('Workout: ${mod.workoutModifiers.join(", ")}'),
          Text('Community: ${mod.communitySpace}'),
          const Divider(height: 32),
          if (widget.moduleId == 'endometriosis') ...[
            const Text('Pain diary', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Location: $location'),
            Wrap(
              spacing: 8,
              children: ['pelvis', 'back', 'legs', 'abdomen']
                  .map((l) => ChoiceChip(
                        label: Text(l),
                        selected: location == l,
                        onSelected: (_) => setState(() => location = l),
                      ))
                  .toList(),
            ),
            Text('Pain ${pain.round()}/10'),
            Slider(
              value: pain,
              min: 0,
              max: 10,
              divisions: 10,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => pain = v),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'What helped'),
            ),
            ElevatedButton(
              onPressed: () async {
                await engine.savePainDiary({
                  'location': location,
                  'pain': pain.round(),
                  'helped': _note.text.trim(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pain entry saved')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save entry', style: TextStyle(color: Colors.white)),
            ),
          ],
          if (widget.moduleId == 'ttc') ...[
            const Text('TTC log', style: TextStyle(fontWeight: FontWeight.w700)),
            ElevatedButton(
              onPressed: () async {
                await engine.saveTtcEntry({
                  'bbt': null,
                  'mucus': 'note',
                  'opk': 'unset',
                  'intercourse': false,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('TTC day saved (edit fields later)')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Log fertile-window day',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
          if (widget.moduleId == 'pms_pmdd') ...[
            ElevatedButton(
              onPressed: () async {
                await engine.savePmsRating({'mood': 3, 'irritability': 2});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PMS rating saved')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Log pre-period rating',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
          if (widget.moduleId == 'perimenopause') ...[
            ElevatedButton(
              onPressed: () async {
                await engine.savePeriSymptoms({
                  'hot_flushes': 1,
                  'night_sweats': 0,
                  'brain_fog': 1,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Peri symptoms saved')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Log peri symptoms',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
          if (widget.moduleId == 'postpartum') ...[
            ElevatedButton(
              onPressed: () async {
                await engine.savePostpartumMeta({
                  'feeding': 'breast',
                  'weeks': 8,
                  'delivery': 'vaginal',
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Postpartum profile saved')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save recovery profile',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
          if (widget.moduleId == 'thyroid') ...[
            ElevatedButton(
              onPressed: () async {
                await engine.saveThyroidMeta({
                  'type': 'underactive',
                  'medReminder': '07:00',
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Thyroid profile saved (no dose advice)')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save thyroid profile',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
          if (widget.moduleId == 'pcos') ...[
            Text('Tracking: ${mod.tracking.join(", ")}'),
            const Text(
              'Uses skin/hair, cravings, and meds logs from Delivery 2.',
              style: TextStyle(color: Color(0xFF6F8B7A)),
            ),
          ],
        ],
      ),
    );
  }
}
