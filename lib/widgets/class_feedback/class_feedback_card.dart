import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../values/constants.dart';
import '../anim/motion.dart';
import '../class_reminder/class_reminder_flow.dart';
import '../../helper/analytics_helper.dart';
import '../../helper/popup_manager.dart';
import '../../data/controllers/home_controller/home_controller.dart';

/// Class feedback (fitHer Flows › Class feedback).
///
/// When the server says there's a class to rate (she stayed 10+ min,
/// class over, < 24h ago, not rated in the last 3 days, not skipped
/// twice in a row):
///   1. A sheet pops up by itself: right after she leaves the class
///      (back from Zoom / in-app Zoom closed), else the next time she
///      opens the app. At most twice per class, 30+ min apart.
///   2. One star tap saves the rating; optional chips after.
///   3. Closed without rating: the small home card stays until the
///      24 hours are over. "Skip" stops asking for this class.

const _ink = Color(0xFF1F2A1E);
const _soft = Color(0xFF66705F);
const _deep = Color(0xFF4C6A4B);
const _limeBg = Color(0xFFEEF7E6);
const _lime = Color(0xFF8AD167);
const _line = Color(0xFFE3E8DE);
const _star = Color(0xFFF5B83D);
const _starOff = Color(0xFFE1E6DC);
const _red = Color(0xFFD9534F);
const _redBg = Color(0xFFFDF0EF);
const _redLine = Color(0xFFF0B8B5);

TextStyle _t(double size, {FontWeight w = FontWeight.w400, Color c = _ink, double? h}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: w, color: c, height: h);

/// Animation pass (#9): a lit star "pops" (1 -> 1.25 -> 1, ~250 ms).
/// [tick] changes on every tap so the pop restarts each time; [order]
/// staggers the stars a little (left to right). Reduce motion: no pop.
Widget _popStar(BuildContext context, Widget star, {required bool on, required int tick, int order = 0}) {
  if (!on || tick == 0 || Motion.calm(context)) return star;
  return star
      .animate(key: ValueKey('star_pop_$tick'), delay: Duration(milliseconds: order * 40))
      .scaleXY(begin: 1, end: 1.25, duration: const Duration(milliseconds: 110), curve: Curves.easeOut)
      .then()
      .scaleXY(begin: 1, end: 0.8, duration: const Duration(milliseconds: 140), curve: Curves.easeIn);
}

class ClassFeedbackController extends GetxController with WidgetsBindingObserver {
  static ClassFeedbackController ensure() => Get.isRegistered<ClassFeedbackController>()
      ? Get.find<ClassFeedbackController>()
      : Get.put(ClassFeedbackController(), permanent: true);

  final pending = Rxn<Map<String, dynamic>>();
  DateTime? _lastFetch;
  bool _fetching = false;
  String? _shownKey;
  bool _asking = false;

  ApiProvider get _api => Get.find<ApiProvider>();
  String get _token =>
      Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
  Map<String, String> get _headers => {'accessToken': _token};

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshPending();
  }

  /// Asks the server which class (if any) to rate. At most once a minute.
  Future<void> refreshPending({bool force = false}) async {
    if (_token.isEmpty || _fetching) return;
    if (!force && _lastFetch != null && DateTime.now().difference(_lastFetch!).inSeconds < 60) return;
    _fetching = true;
    try {
      // early=1: this app shows "Why did you leave early?" (Nov 2026).
      final r = await _api.getData('${Constants.classFeedbackPending}?early=1', headers: _headers);
      final body = r.body;
      if (body is Map && body['status'] == '1') {
        _lastFetch = DateTime.now();
        final data = body['data'];
        final p = data is Map ? data['pending'] : null;
        final next = p is Map ? Map<String, dynamic>.from(p) : null;
        // Mixpanel: card shown (once per class).
        if (next != null && '${next['slotId']}-${next['classDate']}' != _shownKey) {
          _shownKey = '${next['slotId']}-${next['classDate']}';
          AnalyticsHelper.classFeedbackCard('shown');
        }
        pending.value = next;
        if (next != null) _maybeAsk(next);
      }
    } catch (_) {
      // Quiet: the card simply doesn't show.
    } finally {
      _fetching = false;
    }
  }

  /// Opens the rating sheet by itself (max 2 times per class, 30 min apart,
  /// never on top of another popup: then the next check tries again).
  Future<void> _maybeAsk(Map<String, dynamic> p) async {
    if (_asking) return;
    final key = '${p['slotId']}-${p['classDate']}';
    final prefs = Get.find<AuthController>().sharedPreferences;
    final count = prefs.getInt('cf_ask_n_$key') ?? 0;
    final last = prefs.getInt('cf_ask_at_$key') ?? 0;
    if (count >= 2) return;
    if (count == 1 && DateTime.now().millisecondsSinceEpoch - last < 30 * 60 * 1000) return;
    _asking = true;
    try {
      // Let the screen settle after coming back from Zoom.
      await Future.delayed(const Duration(milliseconds: 900));
      final still = pending.value;
      if (still == null || '${still['slotId']}-${still['classDate']}' != key) return;
      // Pop-up manager: waits for its turn (see PopupRank). If it lost
      // its turn nothing is counted; the next check asks again.
      Object? res;
      Future<void> showIt() async {
          prefs.setInt('cf_ask_n_$key', count + 1);
          prefs.setInt('cf_ask_at_$key', DateTime.now().millisecondsSinceEpoch);
          AnalyticsHelper.classFeedbackCard(isLeftEarly(p) ? 'left_early_shown' : 'popup_shown');
          res = await Get.bottomSheet<Object>(
            isLeftEarly(p) ? _EarlySheet(p: p) : _AskSheet(p: p),
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
          );
      }
      // Nov 2026: the first ask is the "well done" moment right after
      // class (it replaces the trial celebration screen), so it opens as
      // soon as nothing else is on screen. The second ask waits its turn.
      if (count == 0) {
        await PopupManager.runNow('class_rating', () async {
          final now = pending.value;
          if (now == null || '${now['slotId']}-${now['classDate']}' != key) return;
          await showIt();
        });
      } else {
        await PopupManager.run(
          'class_rating',
          rank: PopupRank.classRating,
          show: () async {
            final now = pending.value;
            if (now == null || '${now['slotId']}-${now['classDate']}' != key) return;
            await showIt();
          },
        );
      }
      final picked = res;
      if (picked is _EarlyAnswer) {
        await sendEarly(p, picked);
      } else if (picked is _AskResult) {
        await afterAsk(p, picked);
      } else if (picked is int) {
        await startRating(p, picked);
      } else if (picked == 'skip') {
        await skip(p);
      }
      // Closed by swiping: the home card stays for later.
    } finally {
      _asking = false;
    }
  }

  Future<bool> send(Map<String, dynamic> p, int rating,
      {List<String>? tags, String? comment, bool finalise = false}) async {
    try {
      final r = await _api.postData(Constants.classFeedback, headers: _headers, body: {
        'slotId': p['slotId'],
        'classDate': p['classDate'],
        'rating': rating,
        if (tags != null) 'tags': tags,
        if (comment != null) 'comment': comment,
        'final': finalise,
      });
      return r.body is Map && r.body['status'] == '1';
    } catch (_) {
      return false;
    }
  }

  /// After the "well done" sheet: save how she feels (Day 3 energy uses
  /// it), then the rating. 4-5 stars: saved, done. 1-3: ask what went wrong.
  Future<void> afterAsk(Map<String, dynamic> p, _AskResult r) async {
    if (r.moodLevel != null) {
      final d = DateTime.now();
      final date =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      try {
        await _api.postData(Constants.saveDailyCheckin,
            headers: _headers, body: {'date': date, 'moodLevel': r.moodLevel});
      } catch (_) {}
    }
    if (r.stars <= 0) return; // closed without rating: the home card stays
    if (r.stars <= 3) {
      await startRating(p, r.stars);
      return;
    }
    pending.value = null;
    final ok = await send(p, r.stars, finalise: true);
    if (!ok) {
      pending.value = p;
      ClassReminderFlow.showReminderToast(
          "Couldn't send your rating", 'Please check your internet and try again.',
          error: true);
      return;
    }
    AnalyticsHelper.classFeedbackCard('answered', stars: r.stars);
  }

  /// "Why did you leave early?" instead of stars (server: kind=leftEarly).
  static bool isLeftEarly(Map<String, dynamic> p) => p['kind'] == 'leftEarly';

  /// Home card "Tell us" → the same sheet as the pop-up.
  Future<void> openEarly(Map<String, dynamic> p) async {
    final res = await Get.bottomSheet<Object>(
      _EarlySheet(p: p),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    if (res is _EarlyAnswer) {
      await sendEarly(p, res);
    } else if (res == 'skip') {
      await skip(p);
    }
  }

  /// Saves her reason. On failure the card comes back so she can retry.
  Future<void> sendEarly(Map<String, dynamic> p, _EarlyAnswer a) async {
    pending.value = null;
    var ok = false;
    try {
      final r = await _api.postData(Constants.classFeedback, headers: _headers, body: {
        'slotId': p['slotId'],
        'classDate': p['classDate'],
        'earlyReason': a.reason,
        if (a.note.trim().isNotEmpty) 'comment': a.note.trim(),
      });
      ok = r.body is Map && r.body['status'] == '1';
    } catch (_) {}
    if (!ok) {
      pending.value = p;
      ClassReminderFlow.showReminderToast(
          "Couldn't send it just now", 'Please check your internet and try again.',
          error: true);
      return;
    }
    AnalyticsHelper.classFeedbackCard('left_early_answered');
    ClassReminderFlow.showReminderToast('Thank you 💚', 'We hear you. See you in your next class.',
        icon: Icons.favorite_rounded);
  }

  Future<void> skip(Map<String, dynamic> p) async {
    pending.value = null;
    AnalyticsHelper.classFeedbackCard('dismissed');
    try {
      await _api.postData(Constants.classFeedbackSkip,
          headers: _headers, body: {'slotId': p['slotId'], 'classDate': p['classDate']});
    } catch (_) {}
  }

  /// Star tapped on the card: save the rating now (so it's never lost),
  /// open the chips sheet, then save the chips when the sheet closes.
  Future<void> startRating(Map<String, dynamic> p, int stars) async {
    pending.value = null;
    final first = send(p, stars); // saved now, so a closed app never loses it
    final draft = _Draft(stars);
    await Get.bottomSheet(
      _FeedbackSheet(p: p, draft: draft),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    await first; // never race the first save (one row per class)
    final ok = await send(p, draft.rating,
        tags: draft.tags.toList(), comment: draft.comment.trim(), finalise: true);
    if (!ok) {
      pending.value = p; // card comes back so she can try again
      ClassReminderFlow.showReminderToast(
          "Couldn't send your feedback", 'Please check your internet and try again.',
          error: true);
      return;
    }
    AnalyticsHelper.classFeedbackCard('answered', stars: draft.rating);
    // The sheet already showed its own "Thank you" (with a tick), so no
    // second toast here. Errors still show a toast above.

  }
}

class _Draft {
  _Draft(this.rating);
  int rating;
  final Set<String> tags = {};
  String comment = '';
}

String _when(Map<String, dynamic> p) {
  final now = DateTime.now();
  final today =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return p['classDate'] == today ? 'today' : 'yesterday';
}

/// The home card. Shows nothing unless the server says there's a class to rate.
class ClassFeedbackCard extends StatefulWidget {
  const ClassFeedbackCard({super.key});

  @override
  State<ClassFeedbackCard> createState() => _ClassFeedbackCardState();
}

class _ClassFeedbackCardState extends State<ClassFeedbackCard> {
  late final ClassFeedbackController _c = ClassFeedbackController.ensure();
  int _hover = 0;

  @override
  void initState() {
    super.initState();
    _c.refreshPending();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = _c.pending.value;
      if (p == null) return const SizedBox.shrink();
      if (ClassFeedbackController.isLeftEarly(p)) return _earlyCard(p);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
          boxShadow: const [BoxShadow(color: Color(0x1A4C6A4B), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Avatar('${p['trainerInitials'] ?? 'FH'}'),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('How was ${p['className']} with ${p['trainerFirstName']} ${_when(p)}?',
                    style: _t(13.5, w: FontWeight.w600, h: 1.3)),
                const SizedBox(height: 2),
                Text('${p['startLabel']} class · ${p['minutes']} min', style: _t(11.5, c: _soft)),
              ]),
            ),
            InkResponse(
              onTap: () => _c.skip(p),
              radius: 18,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 18, color: Color(0xFFA3AC9C)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final n = i + 1;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _hover = n),
                onTapCancel: () => setState(() => _hover = 0),
                onTap: () async {
                  await Future.delayed(const Duration(milliseconds: 160));
                  if (mounted) setState(() => _hover = 0);
                  _c.startRating(p, n);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(Icons.star_rounded, size: 34, color: n <= _hover ? _star : _starOff),
                ),
              );
            }),
          ),
        ]),
      );
    });
  }
}

extension on _ClassFeedbackCardState {
  /// Home card for "Why did you leave early?" (Nov 2026).
  Widget _earlyCard(Map<String, dynamic> p) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
          boxShadow: const [BoxShadow(color: Color(0x1A4C6A4B), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _Avatar('${p['trainerInitials'] ?? 'FH'}'),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Had to leave ${p['className']} early ${_when(p)}? That\'s okay 💚',
                  style: _t(13.5, w: FontWeight.w600, h: 1.3)),
              const SizedBox(height: 2),
              Text('Tell us how it felt, if you like', style: _t(11.5, c: _soft)),
            ]),
          ),
          TextButton(
            onPressed: () => _c.openEarly(p),
            child: Text('Share', style: _t(13, w: FontWeight.w700, c: _deep)),
          ),
          InkResponse(
            onTap: () => _c.skip(p),
            radius: 18,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 18, color: Color(0xFFA3AC9C)),
            ),
          ),
        ]),
      );
}

/// Her answer to "Why did you leave early?".
class _EarlyAnswer {
  const _EarlyAnswer(this.reason, this.note);
  final String reason;
  final String note;
}

/// "Why did you leave early?" — one tap on a reason (Other: a short note).
/// Returns an [_EarlyAnswer], 'skip', or null (swiped away).
class _EarlySheet extends StatefulWidget {
  const _EarlySheet({required this.p});
  final Map<String, dynamic> p;

  @override
  State<_EarlySheet> createState() => _EarlySheetState();
}

class _EarlySheetState extends State<_EarlySheet> {
  final _note = TextEditingController();
  String? _picked;

  List<String> get _reasons {
    final r = widget.p['earlyReasons'];
    return r is List && r.isNotEmpty
        ? List<String>.from(r)
        : const ['It felt too hard', 'It felt too easy', 'Sound or video trouble', 'Something came up', 'Something else'];
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _pick(String r) {
    if (r != 'Something else') {
      Get.back(result: _EarlyAnswer(r, ''));
      return;
    }
    setState(() => _picked = r);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFDADFD5), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 18),
              Center(child: _Avatar('${p['trainerInitials'] ?? 'FH'}')),
              const SizedBox(height: 10),
              Text('We noticed you left a little early', textAlign: TextAlign.center, style: _t(18, w: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('No worries at all 💚 If something wasn\'t right in ${p['className']} with '
                  '${p['trainerFirstName']}, tell us so we can make it better for you.',
                  textAlign: TextAlign.center, style: _t(12.5, c: _soft, h: 1.45)),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: _reasons.map((r) {
                  final sel = _picked == r;
                  return GestureDetector(
                    onTap: () => _pick(r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? _limeBg : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? _lime : _line),
                      ),
                      child: Text(r, style: _t(13, w: sel ? FontWeight.w600 : FontWeight.w500, c: sel ? _deep : _ink)),
                    ),
                  );
                }).toList(),
              ),
              if (_picked == 'Something else') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 300,
                  onChanged: (_) => setState(() {}),
                  style: _t(13),
                  decoration: InputDecoration(
                    hintText: 'Share a few words, only if you want…',
                    hintStyle: _t(13, c: const Color(0xFFA3AC9C)),
                    counterText: '',
                    contentPadding: const EdgeInsets.all(12),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lime)),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _note.text.trim().isEmpty
                      ? null
                      : () => Get.back(result: _EarlyAnswer('Something else', _note.text)),
                  child: Opacity(
                    opacity: _note.text.trim().isEmpty ? 0.5 : 1,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF89CB68), Color(0xFF8AD167)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('Send', style: _t(15, w: FontWeight.w600, c: Colors.white)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Get.back(result: 'skip'),
                child: Text('Not now', style: _t(13, w: FontWeight.w600, c: _soft)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: _limeBg, shape: BoxShape.circle),
        child: Text(text, style: _t(13, w: FontWeight.w700, c: _deep)),
      );
}

/// Her answer on the "well done" sheet.
class _AskResult {
  const _AskResult(this.stars, this.moodLevel);
  final int stars;
  final int? moodLevel; // DailyCheckin.moodLevel: 1 Great, 2 Tired, 3 Sore, 4 Energy
}

/// After class (Nov 2026): "Well done" + what she did, trial progress,
/// streak, kcal, one rating, how she feels, a Luna line for her phase.
/// Returns an [_AskResult] (Done), 'skip', or null (swiped away).
class _AskSheet extends StatefulWidget {
  const _AskSheet({required this.p});
  final Map<String, dynamic> p;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  int _lit = 0;
  int _popTick = 0;
  int? _mood;

  static const _moods = <(String, int)>[('Strong', 4), ('Good', 1), ('Tired', 2), ('Sore', 3)];

  Map<String, dynamic> get p => widget.p;

  String? get _nextClass {
    // From the server for everyone (paid and trial): her next class that
    // reminds her, e.g. "tomorrow 7:00 PM".
    final fromServer = '${p['nextClass'] ?? ''}'.trim();
    if (fromServer.isNotEmpty) return 'Next class $fromServer, reminder on';
    if (p['trial'] is! Map || !Get.isRegistered<HomeController>()) return null;
    try {
      final n = Get.find<HomeController>().nextTrialClass(pickedOnly: true);
      if (n == null || n.label == 'Live now') return null;
      return 'Next class ${n.label}, reminder on';
    } catch (_) {
      return null;
    }
  }

  Widget _pill(String text, Color bg, Color fg, {Widget? lead}) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (lead != null) ...[lead, const SizedBox(width: 6)],
          Text(text, style: _t(12.5, w: FontWeight.w600, c: fg)),
        ]),
      );

  Widget _badge(BuildContext context) {
    final calm = Motion.calm(context);
    Widget b = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF5DBB4A),
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: _limeBg, spreadRadius: 8)],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
    );
    if (!calm) {
      b = b.animate().scaleXY(begin: 0.3, end: 1, duration: const Duration(milliseconds: 600), curve: Curves.easeOutBack);
    }
    const bits = [
      (-52.0, -22.0, Color(0xFFF5B83D)),
      (50.0, -26.0, Color(0xFF5DBB4A)),
      (-40.0, 22.0, Color(0xFFE07A6B)),
      (46.0, 18.0, Color(0xFF9C8BD9)),
      (-8.0, -38.0, Color(0xFFF5B83D)),
    ];
    return SizedBox(
      width: 140,
      height: 90,
      child: Stack(alignment: Alignment.center, children: [
        for (final (dx, dy, c) in bits)
          calm
              ? Transform.translate(offset: Offset(dx, dy), child: _dot(c))
              : _dot(c)
                  .animate(delay: const Duration(milliseconds: 150))
                  .move(begin: Offset.zero, end: Offset(dx, dy), duration: const Duration(milliseconds: 700), curve: Curves.easeOut)
                  .fadeIn(duration: const Duration(milliseconds: 200)),
        b,
      ]),
    );
  }

  Widget _dot(Color c) => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  @override
  Widget build(BuildContext context) {
    final name = '${p['firstName'] ?? ''}'.trim();
    final known = p['minutesKnown'] != false;
    final minutes = p['minutes'];
    final benefit = '${p['benefit'] ?? ''}'.trim();
    final who = '${p['className']} with ${p['trainerFirstName']}';
    final line = [
      known && minutes is num && minutes > 0 ? '$minutes minutes of $who.' : 'You did $who.',
      if (benefit.isNotEmpty) benefit,
    ].join(' ');
    final trial = p['trial'] is Map ? Map<String, dynamic>.from(p['trial']) : null;
    final streak = p['streak'] is num ? (p['streak'] as num).toInt() : null;
    final kcal = p['kcal'] is num ? (p['kcal'] as num).toInt() : null;
    final luna = p['luna'] is Map ? Map<String, dynamic>.from(p['luna']) : null;
    final next = _nextClass;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDADFD5), borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 4),
            _badge(context),
            Text(name.isEmpty ? 'Well done!' : 'Well done, $name!',
                textAlign: TextAlign.center, style: _t(22, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(line, textAlign: TextAlign.center, style: _t(14, c: const Color(0xFF3D4A3A), h: 1.45)),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              if (trial != null)
                _pill(
                  (trial['attended'] ?? 0) >= (trial['goal'] ?? 3)
                      ? 'Trial goal done'
                      : '${trial['attended'] ?? 0} of ${trial['goal'] ?? 3} trial',
                  _limeBg,
                  _deep,
                  lead: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < ((trial['goal'] ?? 3) as num).toInt(); i++)
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < ((trial['attended'] ?? 0) as num).toInt() ? const Color(0xFF5DBB4A) : Colors.transparent,
                          border: Border.all(color: const Color(0xFF5DBB4A), width: 1.6),
                        ),
                      ),
                  ]),
                ),
              if (streak != null && streak > 0)
                _pill('$streak-day streak', const Color(0xFFFBF1DC), const Color(0xFF8A5A12),
                    lead: const Icon(Icons.local_fire_department_rounded, size: 15, color: Color(0xFFE0A12C))),
              if (kcal != null && kcal > 0)
                _pill('about $kcal kcal', const Color(0xFFFCE9E5), const Color(0xFF9A3B2C),
                    lead: const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFC9563F))),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEEF1EA)),
            const SizedBox(height: 12),
            Text('How was the class?', style: _t(15, w: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final n = i + 1;
                return Semantics(
                  button: true,
                  label: '$n ${n == 1 ? 'star' : 'stars'}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _lit = n;
                      _popTick++;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: _popStar(
                        context,
                        Icon(Icons.star_rounded, size: 40, color: n <= _lit ? _star : _starOff),
                        on: n <= _lit,
                        tick: _popTick,
                        order: i,
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (_lit > 0) ...[
              const SizedBox(height: 6),
              Text('And how do you feel now?', style: _t(13, c: _soft)),
              const SizedBox(height: 8),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                for (final (label, level) in _moods)
                  GestureDetector(
                    onTap: () => setState(() => _mood = _mood == level ? null : level),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _mood == level ? _limeBg : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _mood == level ? _lime : _line),
                      ),
                      child: Text(label,
                          style: _t(13, w: _mood == level ? FontWeight.w600 : FontWeight.w500, c: _mood == level ? _deep : _ink)),
                    ),
                  ),
              ]),
            ],
            if (luna != null && '${luna['tip'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFF5FAF1), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(color: Color(0xFF5DBB4A), shape: BoxShape.circle),
                    child: const Icon(Icons.nightlight_round, size: 15, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: 'Luna: ', style: _t(13, w: FontWeight.w600, c: const Color(0xFF3F8A2E))),
                      TextSpan(text: '${luna['label']}, ${luna['tip']}', style: _t(13, c: const Color(0xFF3D4A3A), h: 1.4)),
                    ])),
                  ),
                ]),
              ),
            ],
            if (next != null) ...[
              const SizedBox(height: 12),
              Text(next, style: _t(12, c: _soft)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF163220),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () => Get.back(result: _AskResult(_lit, _mood)),
                child: Text('Done', style: _t(15, w: FontWeight.w600, c: Colors.white)),
              ),
            ),
            if (_lit == 0)
              TextButton(
                onPressed: () => Get.back(result: 'skip'),
                child: Text('Skip rating', style: _t(12.5, w: FontWeight.w600, c: _soft)),
              ),
          ]),
        ),
      ),
    );
  }
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.p, required this.draft});
  final Map<String, dynamic> p;
  final _Draft draft;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _note = TextEditingController();
  int _popTick = 0;
  // Animation pass (#9): after Done/Send, a short "Thank you" with a tick,
  // then the sheet closes (the saving itself still runs after it closes,
  // in ClassFeedbackController.startRating, exactly as before).
  bool _thanks = false;

  Future<void> _done() async {
    if (_thanks) return;
    FocusScope.of(context).unfocus();
    setState(() => _thanks = true);
    await Future.delayed(const Duration(milliseconds: 1300));
    if (mounted) Get.back();
  }

  _Draft get d => widget.draft;
  bool get _happy => d.rating >= 4;

  List<String> _tags(String key) =>
      (widget.p[key] is List) ? List<String>.from(widget.p[key]) : const <String>[];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _setRating(int n) {
    final wasHappy = _happy;
    setState(() {
      d.rating = n;
      _popTick++;
      if (wasHappy != _happy) d.tags.clear(); // the chip set changed
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final tags = _tags(_happy ? 'goodTags' : 'badTags');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: AnimatedSize(
              duration: Motion.calm(context) ? Duration.zero : Motion.normal,
              curve: Motion.ease,
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
              duration: Motion.calm(context) ? Duration.zero : Motion.fast,
              child: _thanks
                  ? _ThanksView(
                      key: const ValueKey('cf_thanks'),
                      happy: _happy,
                      trainer: '${p['trainerFirstName'] ?? 'Your trainer'}',
                    )
                  : Column(key: const ValueKey('cf_form'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFDADFD5), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Text(_happy ? 'Glad you enjoyed it! 💚' : "Sorry it wasn't great",
                  textAlign: TextAlign.center, style: _t(17, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  _happy
                      ? '${p['className']} with ${p['trainerFirstName']} · ${p['startLabel']}'
                      : 'Tell us what went wrong. It stays private.',
                  textAlign: TextAlign.center,
                  style: _t(12.5, c: _soft)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final n = i + 1;
                  return GestureDetector(
                    onTap: () => _setRating(n),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _popStar(
                        context,
                        Icon(Icons.star_rounded, size: 32, color: n <= d.rating ? _star : _starOff),
                        on: n <= d.rating,
                        tick: _popTick,
                        order: i,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text.rich(TextSpan(children: [
                TextSpan(text: _happy ? 'What did you love? ' : 'What went wrong?', style: _t(13, w: FontWeight.w600)),
                if (_happy) TextSpan(text: '(optional)', style: _t(12, c: _soft)),
              ])),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) {
                  final sel = d.tags.contains(tag);
                  return GestureDetector(
                    onTap: () => setState(() => sel ? d.tags.remove(tag) : d.tags.add(tag)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? (_happy ? _limeBg : _redBg) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? (_happy ? _lime : _redLine) : _line),
                      ),
                      child: Text(tag,
                          style: _t(12.5,
                              w: sel ? FontWeight.w600 : FontWeight.w400,
                              c: sel ? (_happy ? _deep : _red) : _ink)),
                    ),
                  );
                }).toList(),
              ),
              if (!_happy) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  onChanged: (v) => d.comment = v,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 500,
                  style: _t(13),
                  decoration: InputDecoration(
                    hintText: 'Add a note (optional)…',
                    hintStyle: _t(13, c: const Color(0xFFA3AC9C)),
                    counterText: '',
                    contentPadding: const EdgeInsets.all(12),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lime)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _done,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF89CB68), Color(0xFF8AD167)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_happy ? 'Done' : 'Send', style: _t(15, w: FontWeight.w600, c: Colors.white)),
                ),
              ),
            ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Thank you" state shown for a moment after Done/Send.
/// The green tick pops in (~700 ms); reduce motion: shown still.
class _ThanksView extends StatelessWidget {
  const _ThanksView({super.key, required this.happy, required this.trainer});
  final bool happy;
  final String trainer;

  @override
  Widget build(BuildContext context) {
    final calm = Motion.calm(context);
    Widget tick = Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _limeBg, shape: BoxShape.circle),
      child: calm
          ? const Icon(Icons.check_rounded, size: 36, color: _deep)
          : const Icon(Icons.check_rounded, size: 36, color: _deep)
              .animate(delay: const Duration(milliseconds: 200))
              .fadeIn(duration: const Duration(milliseconds: 150))
              .scaleXY(begin: 0.2, end: 1, duration: const Duration(milliseconds: 450), curve: Curves.easeOutBack),
    );
    if (!calm) {
      tick = tick
          .animate()
          .fadeIn(duration: const Duration(milliseconds: 200))
          .scaleXY(begin: 0.6, end: 1, duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: tick),
        const SizedBox(height: 14),
        Text(happy ? 'Thank you! 💚' : 'Thanks for telling us',
            textAlign: TextAlign.center, style: _t(18, w: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
            happy
                ? '$trainer will see your rating.\nIt helps us make every class better.'
                : 'Our team will look into it.\nIt helps us make every class better.',
            textAlign: TextAlign.center,
            style: _t(12.5, c: _soft, h: 1.5)),
      ]),
    );
  }
}
