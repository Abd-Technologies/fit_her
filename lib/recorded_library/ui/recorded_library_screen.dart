
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/tier_access_service.dart';
import '../../helper/analytics_helper.dart';
import '../../data/analytics/analytics_events.dart';
import '../../theme/app_colors.dart';
import '../recorded_library_controller.dart';
import 'recorded_class_player_screen.dart';

/// 3M1–3M8 library UI.
class RecordedLibraryScreen extends StatelessWidget {
  const RecordedLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<RecordedLibraryController>();
    final tier = Get.find<TierAccessService>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Recorded library'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
        actions: [
          Obx(() => IconButton(
                tooltip: 'Low data',
                onPressed: () => c.setLowData(!c.lowData.value),
                icon: Icon(
                  c.lowData.value ? Icons.signal_cellular_alt_2_bar : Icons.hd,
                ),
              )),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Obx(() => Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Calm'),
                      selected: c.styleFilter.value == 'calm',
                      onSelected: (on) =>
                          c.styleFilter.value = on ? 'calm' : '',
                    ),
                    FilterChip(
                      label: const Text('High energy'),
                      selected: c.styleFilter.value == 'high_energy',
                      onSelected: (on) =>
                          c.styleFilter.value = on ? 'high_energy' : '',
                    ),
                    FilterChip(
                      label: const Text('Strict'),
                      selected: c.styleFilter.value == 'strict',
                      onSelected: (on) =>
                          c.styleFilter.value = on ? 'strict' : '',
                    ),
                    FilterChip(
                      label: const Text('Micro 5min'),
                      selected: c.microOnly.value,
                      onSelected: (on) => c.microOnly.value = on,
                    ),
                  ],
                )),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Access: ${tier.libraryAccess} · Tier: ${tier.tier.value.name}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6F8B7A)),
            ),
          ),
          Expanded(
            child: Obx(() {
              final items = c.visible;
              if (items.isEmpty) {
                return const Center(child: Text('No classes match filters'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final cls = items[i];
                  final locked = !c.canPlay(cls);
                  final fav = c.favourites.contains(cls.id);
                  final prog = c.progress[cls.id] ?? 0;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFD8EDD4)),
                    ),
                    title: Text(cls.title),
                    subtitle: Text(
                      '${cls.durationMin} min · ${cls.trainerStyle} · ${cls.level}'
                      '${prog > 0 && prog < 1 ? ' · continue ${(prog * 100).round()}%' : ''}'
                      '${locked ? ' · locked' : ''}',
                    ),
                    trailing: IconButton(
                      icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
                      onPressed: () => c.toggleFavourite(cls.id),
                    ),
                    onTap: () async {
                      if (locked) {
                        await AnalyticsHelper.track(
                          AnalyticsEvents.unlimitedGateHit,
                          props: {'classId': cls.id},
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Upgrade to Unlimited for the full library',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      await AnalyticsHelper.track(
                        AnalyticsEvents.libraryClassStarted,
                        props: {'id': cls.id},
                      );
                      Get.to(() => RecordedClassPlayerScreen(cls: cls));
                    },
                  );
                },
              );
            }),
          ),
          Obx(() {
            if (c.programs.isEmpty) return const SizedBox.shrink();
            final p = c.programs.first;
            return ListTile(
              tileColor: const Color(0xFFF3F8F1),
              title: Text(p.title),
              subtitle: Text(
                c.activeProgramId.value == p.id
                    ? 'Week ${c.programWeek.value} of ${p.weeks}'
                    : '4-week program',
              ),
              trailing: TextButton(
                onPressed: () => c.activeProgramId.value == p.id
                    ? c.advanceProgramWeek()
                    : c.startProgram(p.id),
                child: Text(
                  c.activeProgramId.value == p.id ? 'Next week' : 'Start',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
