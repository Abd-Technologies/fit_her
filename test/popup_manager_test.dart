import 'package:fitness_zone_2/helper/popup_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final shown = <String>[];
  Future<bool> ask(String id, int rank, {bool urgent = false}) =>
      PopupManager.run(id, rank: rank, urgent: urgent, show: () async {
        shown.add(id);
        await Future.delayed(const Duration(milliseconds: 200));
      });
  void newOpen() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
  Future<void> pretendGapPassed() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('pm_last_closed_at',
        DateTime.now().subtract(const Duration(minutes: 31)).millisecondsSinceEpoch);
  }

  test('rules', () async {
    SharedPreferences.setMockInitialValues({});
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    PopupManager.init();

    // 1. Four at once: only the smallest rank opens.
    final r = await Future.wait([
      ask('announcement', PopupRank.announcement),
      ask('welcome', PopupRank.welcome),
      ask('notifications', PopupRank.notifications),
      ask('health', PopupRank.healthForm),
    ]);
    // Announcement is 2nd priority (right after urgent), so it wins.
    expect(shown, ['announcement']);
    expect(r, [true, false, false, false]);

    // 2. Same open, later ask: waits.
    expect(await ask('welcome', PopupRank.welcome), false);

    // 3. Urgent: always, doesn't use a turn.
    expect(await ask('class_cancelled', 0, urgent: true), true);

    // 4. New open but < 30 min since last closed: waits.
    newOpen();
    expect(await ask('welcome', PopupRank.welcome), false);

    // 5. New open, gap passed: shows (2nd of the day).
    await pretendGapPassed();
    newOpen();
    expect(await ask('welcome', PopupRank.welcome), true);

    // 6. Third planned today: waits even if gap passed.
    await pretendGapPassed();
    newOpen();
    expect(await ask('health', PopupRank.healthForm), false);

    // 7. New day, Home covered: waits until Home is free, then shows.
    final p = await SharedPreferences.getInstance();
    await p.setString('pm_day', 'old');
    await pretendGapPassed();
    newOpen();
    PopupManager.homeCovered = true;
    Future.delayed(const Duration(seconds: 2), () => PopupManager.homeCovered = false);
    final sw = Stopwatch()..start();
    expect(await ask('health', PopupRank.healthForm), true);
    expect(sw.elapsed.inSeconds >= 2, true);

    // 8. Other tab: waits too.
    await pretendGapPassed();
    newOpen();
    PopupManager.onHomeTab = false;
    var done = false;
    ask('renew', PopupRank.renew).then((v) => done = v);
    await Future.delayed(const Duration(seconds: 5));
    expect(done, false);
    PopupManager.onHomeTab = true;
    await Future.delayed(const Duration(seconds: 2));
    expect(done, true); // 2nd of the new day: shows
  }, timeout: const Timeout(Duration(minutes: 2)));
}
