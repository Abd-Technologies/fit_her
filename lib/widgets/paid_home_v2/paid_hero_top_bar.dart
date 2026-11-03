import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../UI/dashboard_module/home_screen/notification_screen.dart';
import '../../UI/dashboard_module/profile_screen/profile_screen_user.dart';
import '../../data/controllers/home_controller/home_controller.dart';
import '../new_home/phase_theme.dart';

/// H-01 top bar, right-anchored: bell (with red dot) + avatar.
/// No fake "9:41" — the phone OS renders the real clock above the status bar.
/// Top padding includes `MediaQuery.padding.top` so bell + avatar clear the
/// system UI since the hero paints edge-to-edge under the status bar.
class PaidHeroTopBar extends StatelessWidget {
  final PhaseTheme theme;
  final String initial;

  const PaidHeroTopBar({
    Key? key,
    required this.theme,
    required this.initial,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topInset = mq.padding.top + 14;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, topInset, 22, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Same target + read-state handling as the old UserHomeScreen's
            // bell (lib/widgets/user_home_screen.dart:508-526) -- reuses the
            // existing, already-working notification list + unread-dot flag
            // rather than building a second one for the v2 home screen.
            onTap: () {
              Get.find<HomeController>().showDotHome.value = false;
              Get.to(() => const NotificationScreen());
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                  ),
                  child: const Text('🔔', style: TextStyle(fontSize: 13)),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Obx(() {
                    final show = Get.find<HomeController>().showDotHome.value;
                    if (!show) return const SizedBox.shrink();
                    // 10px (was 6px with a 2px border: hardly visible).
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4D4D),
                        shape: BoxShape.circle,
                        // Border matches hero bg so the dot looks "cut" into
                        // the bell circle, not floating on top of it.
                        border: Border.all(
                          color: theme.heroBackground,
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Same navigation the old UserHomeScreen uses at
            // lib/widgets/user_home_screen.dart:373. Logout lives inside
            // ProfileScreenUser (at profile_screen_user.dart:47).
            onTap: () => Get.to(() => ProfileScreenUser()),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.accent,
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
