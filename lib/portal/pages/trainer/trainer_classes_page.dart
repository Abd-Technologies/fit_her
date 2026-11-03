import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';
import '../../shell/portal_nav.dart';
import '../../widgets/portal_ui.dart';

/// Trainer: her week of classes (app: TrainerHomeScreen) with the class
/// screen (TrainerClassScreen) and Class Details on the right.
/// Start (marks the class live + opens her Zoom room in a new tab), End,
/// Cancel, the "Other link" for today and the class details all work here.
class TrainerClassesPage extends StatefulWidget {
  const TrainerClassesPage({super.key});

  @override
  State<TrainerClassesPage> createState() => _TrainerClassesPageState();
}

// Same fixed options as widgets/class_option_picker.dart in the app.
const List<String> _kClassTypes = ['Yoga', 'Pilates', 'Zumba', 'HIIT', 'Strength', 'Low Impact'];
const List<String> _kIntensities = ['Low', 'Medium', 'High'];
const String _kOther = 'Other';

class _TrainerClassesPageState extends State<TrainerClassesPage> {
  // list
  List<Map<String, dynamic>>? _days;
  bool _loading = true;
  Map<String, dynamic>? _ratings;

  // selected class
  int? _selId;
  Map<String, dynamic>? _c;
  bool _cLoading = false;
  String? _cError;
  bool _busy = false;
  String? _actionError;
  String _platform = 'zoom';
  final _linkCtrl = TextEditingController();

  // class details form
  String? _type;
  String? _level;
  final _customType = TextEditingController();
  final _desc = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRatings();
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    _customType.dispose();
    _desc.dispose();
    super.dispose();
  }

  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

  static String _time(dynamic v) {
    final s = '${v ?? ''}'.trim();
    final n = int.tryParse(s);
    if (n != null && n > 100000) return DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(n));
    return s;
  }

  static int? _id(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

  // ---------- loading ----------

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final uid = Get.find<PortalSession>().userId ?? 0;
    final b = await PortalApi.get('${Constants.getTrainerHome}/$uid');
    List<Map<String, dynamic>>? days;
    if (PortalApi.ok(b) && b['data'] is Map) {
      days = _list((b['data'] as Map)['trainerSlots']);
      for (final d in days) {
        d['slots'] = _list(d['slots']);
      }
    } else if (!silent) {
      portalToast("Couldn't load your classes", sub: PortalApi.msg(b), error: true);
    }
    if (!mounted) return;
    setState(() {
      _days = days ?? _days;
      _loading = false;
    });
  }

  Future<void> _loadRatings() async {
    final b = await PortalApi.get(Constants.classFeedbackTrainer, query: {'days': '30'});
    if (!mounted) return;
    if (PortalApi.ok(b) && b['data'] is Map) setState(() => _ratings = Map<String, dynamic>.from(b['data']));
  }

  Map<String, dynamic>? _slot(int? id) {
    if (id == null) return null;
    for (final d in _days ?? const <Map<String, dynamic>>[]) {
      for (final s in (d['slots'] as List).cast<Map<String, dynamic>>()) {
        if (_id(s['id']) == id) return s;
      }
    }
    return null;
  }

  String _dayOf(int? id) {
    for (final d in _days ?? const <Map<String, dynamic>>[]) {
      for (final s in (d['slots'] as List).cast<Map<String, dynamic>>()) {
        if (_id(s['id']) == id) return '${d['day'] ?? ''}';
      }
    }
    return '';
  }

  void _select(Map<String, dynamic> s) {
    final id = _id(s['id']);
    if (id == null) return;
    final type = '${s['type'] ?? ''}'.trim();
    final level = '${s['level'] ?? ''}'.trim();
    setState(() {
      _selId = id;
      _tooEarly = null;
      _c = null;
      _cError = null;
      _actionError = null;
      _platform = 'zoom';
      _linkCtrl.clear();
      if (type.isEmpty || type == 'null') {
        _type = null;
        _customType.clear();
      } else if (_kClassTypes.contains(type)) {
        _type = type;
        _customType.clear();
      } else {
        _type = _kOther;
        _customType.text = type;
      }
      _level = _kIntensities.contains(level) ? level : null;
      final desc = '${s['description'] ?? ''}';
      _desc.text = desc == 'null' ? '' : desc;
    });
    _loadClass();
  }

  void _apply(dynamic data) {
    if (data is! Map) return;
    _c = Map<String, dynamic>.from(data);
    _platform = '${_c!['platform'] ?? 'zoom'}';
    final b = _c!['backupLink'];
    if (b is String && b.isNotEmpty) _linkCtrl.text = b;
    final s = _slot(_selId);
    if (s != null && _c!['status'] != null) s['status'] = _c!['status'];
  }

  Future<void> _loadClass() async {
    final id = _selId;
    if (id == null) return;
    setState(() {
      _cLoading = true;
      _cError = null;
    });
    final b = await PortalApi.get('${Constants.trainerClass}/$id');
    if (!mounted || _selId != id) return;
    setState(() {
      if (PortalApi.ok(b)) {
        _apply(b['data']);
      } else {
        _cError = PortalApi.msg(b, 'Could not load the class.');
      }
      _cLoading = false;
    });
  }

  // ---------- actions (same API calls as the app) ----------

  String get _status => '${_c?['status'] ?? 'Upcoming Class'}';
  bool get _live => _status == 'In Progress';
  bool get _cancelled => _status == 'Cancelled';
  bool get _ended => _status == 'Completed';

  /// Classes run on Pakistan days. Start and Cancel only work for TODAY's
  /// class (a class's status is today's status and resets at midnight).
  static String _todayPkt() =>
      DateFormat('EEEE').format(DateTime.now().toUtc().add(const Duration(hours: 5)));
  bool get _isToday {
    final d = _dayOf(_selId).trim();
    return d.isEmpty || d.toLowerCase() == _todayPkt().toLowerCase();
  }

  Future<bool> _ask(String title, String body, String yes, {bool danger = false}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: PT.t(17, w: FontWeight.w700)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(body, style: PT.t(13.5, h: 1.45)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Not now', style: PT.t(13.5, c: PT.sage))),
          danger
              ? OutlinedButton(style: portalDanger(), onPressed: () => Navigator.pop(c, true), child: Text(yes))
              : ElevatedButton(style: portalPrimary(), onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
      ),
    );
    return r == true;
  }

  String? _tooEarly; // "opens at 5:40 AM" when she taps Start too early

  /// Same as the app: mark the class live (users get "Your class is live"
  /// and Join now), up to 3 tries on a weak connection, then open her room.
  Future<void> _start() async {
    final id = _selId;
    if (id == null || _busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
      _tooEarly = null;
    });
    var ok = false;
    Map<String, dynamic> b = const {};
    for (var i = 0; i < 3 && !ok; i++) {
      b = await PortalApi.post(Constants.updateSlotStatus, {'slotId': '$id', 'status': 'In Progress'});
      ok = PortalApi.ok(b);
      if (!ok) {
        final d = b['data'];
        if (d is Map && d['code'] == 'TOO_EARLY') {
          _tooEarly = '${d['opensAtLabel'] ?? ''}';
          break;
        }
        if (b['message'] != null && '${b['message']}'.isNotEmpty && !'${b['message']}'.contains("Couldn't reach")) break;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        final d = b['data'];
        if (d is Map && d.isNotEmpty && _selId == id) {
          _apply(d);
        } else if (_selId == id) {
          _c = {...?_c, 'status': 'In Progress'};
        }
        final sl = _slot(id);
        if (sl != null) sl['status'] = 'In Progress';
      } else if (_tooEarly == null) {
        _actionError = PortalApi.msg(b, "Couldn't start. Please try again.");
      }
    });
    if (ok) {
      portalToast('Your class is live', sub: 'Users got "Join now". Opening your Zoom room…');
      await _openRoom();
    }
  }

  /// Opens her Zoom room in a new tab (Zoom app or browser). The class is
  /// already live for users; this only puts her (the host) in the room.
  Future<void> _openRoom() async {
    final link = '${_c?['openLink'] ?? ''}'.trim();
    if (link.isEmpty) {
      portalToast('No Zoom room for this class', sub: 'Ask the admin to set the class room.', error: true);
      return;
    }
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(link), webOnlyWindowName: '_blank');
    } catch (_) {}
    if (!opened && mounted) {
      portalToast("Zoom didn't open", sub: 'Your browser may have blocked it. Click "Open Zoom" below.', error: true);
    }
  }

  Future<void> _changeStatus(String title, String body, String yes, String status) async {
    final id = _selId;
    if (id == null || _busy) return;
    final go = await _ask(title, body, yes, danger: status == 'Cancelled');
    if (!go || !mounted) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    final b = await PortalApi.post(Constants.updateSlotStatus, {'slotId': '$id', 'status': status});
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (PortalApi.ok(b)) {
        final d = b['data'];
        if (d is Map && d.isNotEmpty && _selId == id) {
          _apply(d);
        } else if (_selId == id) {
          _c = {...?_c, 'status': status};
        }
        final s = _slot(id);
        if (s != null) s['status'] = status;
      } else {
        _actionError = PortalApi.msg(b, 'Could not update. Please try again.');
      }
    });
    if (PortalApi.ok(b)) {
      portalToast(status == 'Cancelled' ? 'Class cancelled' : 'Class ended',
          sub: status == 'Cancelled' ? 'Users are told it is cancelled.' : 'Users no longer see Join now.');
    }
  }

  static const _kCancelReasons = [
    'I am sick',
    'Family emergency',
    'Internet / power problem',
    'Other',
  ];

  /// Emergency cancel (Nov 2026): she picks a reason (sent to the admins
  /// and saved in the Class diary), then women are told and shown the
  /// next class. Today's class only.
  Future<void> _cancelWithReason() async {
    final id = _selId;
    if (id == null || _busy) return;
    String? picked;
    final other = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) {
          final text = picked == 'Other' ? other.text.trim() : (picked ?? '');
          final canSend = text.isNotEmpty;
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text("Cancel today's class?", style: PT.t(17, w: FontWeight.w700)),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Women will be told it's cancelled and shown the next class. The admin team is told too.",
                    style: PT.t(13.5, h: 1.45)),
                const SizedBox(height: 14),
                Text('Why are you cancelling?', style: PT.t(13, w: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in _kCancelReasons)
                      ChoiceChip(
                        label: Text(r),
                        selected: picked == r,
                        showCheckmark: false,
                        labelStyle: PT.t(12.5, w: FontWeight.w600, c: picked == r ? Colors.white : PT.ink),
                        selectedColor: PT.green,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: picked == r ? PT.green : PT.line),
                        onSelected: (_) => setD(() => picked = r),
                      ),
                  ],
                ),
                if (picked == 'Other') ...[
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('t_cancel_other_reason'),
                    controller: other,
                    maxLength: 150,
                    autofocus: true,
                    onChanged: (_) => setD(() {}),
                    decoration: const InputDecoration(hintText: 'Tell us briefly what happened'),
                  ),
                ],
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text('Not now', style: PT.t(13.5, c: PT.sage)),
              ),
              OutlinedButton(
                style: portalDanger(),
                onPressed: canSend ? () => Navigator.pop(c, picked == 'Other' ? 'Other: $text' : text) : null,
                child: const Text('Cancel class'),
              ),
            ],
          );
        },
      ),
    );
    other.dispose();
    if (reason == null || !mounted) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    final b = await PortalApi.post(
        Constants.updateSlotStatus, {'slotId': '$id', 'status': 'Cancelled', 'reason': reason});
    if (!mounted) return;
    final ok = PortalApi.ok(b);
    setState(() {
      _busy = false;
      if (ok) {
        if (_selId == id) _c = {...?_c, 'status': 'Cancelled'};
        final s = _slot(id);
        if (s != null) s['status'] = 'Cancelled';
      } else {
        _actionError = PortalApi.msg(b, 'Could not cancel. Please try again.');
      }
    });
    if (ok) {
      portalToast('Class cancelled', sub: 'Women are told and shown the next class. The admin team is informed.');
    }
  }

  Future<void> _saveBackup({required bool clear}) async {
    final id = _selId;
    if (id == null) return;
    final link = _linkCtrl.text.trim();
    if (!clear && link.isEmpty) {
      setState(() => _actionError = 'Paste the link first.');
      return;
    }
    setState(() {
      _busy = true;
      _actionError = null;
    });
    final b = await PortalApi.post(Constants.trainerClassBackupLink, {'slotId': id, 'link': clear ? null : link});
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (PortalApi.ok(b)) {
        if (_selId == id) _apply(b['data']);
      } else {
        _actionError = PortalApi.msg(b, 'Could not save the link.');
      }
    });
    if (PortalApi.ok(b)) {
      portalToast(clear ? 'Back to Zoom' : 'Link saved for today',
          sub: clear ? 'Your class uses your Zoom room.' : 'Users will join with this link today.');
    }
  }

  Future<void> _saveDetails() async {
    final id = _selId;
    if (id == null || _saving) return;
    final chosenType = _type == _kOther ? _customType.text.trim() : (_type ?? '').trim();
    if (chosenType.isEmpty) {
      portalToast('Class type needed', sub: 'Pick a class type, or choose Other and type it.', error: true);
      return;
    }
    if (_level == null) {
      portalToast('Intensity needed', sub: 'Pick Low, Medium or High.', error: true);
      return;
    }
    setState(() => _saving = true);
    final b = await PortalApi.post(Constants.updateSlotTrainer, {
      'type': chosenType,
      'level': _level,
      'description': _desc.text.trim(),
      'slotId': id,
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (PortalApi.ok(b)) {
        final s = _slot(id);
        if (s != null) {
          s['type'] = chosenType;
          s['level'] = _level;
          s['description'] = _desc.text.trim();
        }
        if (_selId == id && _c != null) {
          _c!['type'] = chosenType;
          _c!['level'] = _level;
        }
      }
    });
    if (PortalApi.ok(b)) {
      portalToast('Class details saved', sub: PortalApi.msg(b, 'Clients see the new details on their schedule.'));
    } else {
      portalToast("Couldn't save the details", sub: PortalApi.msg(b), error: true);
    }
  }

  // ---------- small pieces ----------

  Widget _chip() {
    if (_live) return const StatusChip('● LIVE', color: PT.red);
    if (_cancelled) return const StatusChip('CANCELLED', color: PT.sage);
    if (_ended) return const StatusChip('ENDED', color: PT.sage);
    return const StatusChip('NOT STARTED', color: PT.amber);
  }

  Widget? _listChip(dynamic status) {
    switch ('${status ?? ''}') {
      case 'In Progress':
        return const StatusChip('Live', color: PT.red);
      case 'Cancelled':
        return const StatusChip('Cancelled', color: PT.sage);
      case 'Completed':
        return const StatusChip('Ended', color: PT.sage);
    }
    return null;
  }

  Widget _box(String title, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: PT.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: PT.t(14.5, w: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _choices(List<String> options, String? selected, ValueChanged<String> onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((o) {
          final sel = o == selected;
          return ChoiceChip(
            label: Text(o),
            selected: sel,
            showCheckmark: false,
            labelStyle: PT.t(12.5, w: FontWeight.w600, c: sel ? Colors.white : PT.ink),
            selectedColor: PT.green,
            backgroundColor: Colors.white,
            side: BorderSide(color: sel ? PT.green : PT.line),
            onSelected: _saving ? null : (_) => setState(() => onPick(o)),
          );
        }).toList(),
      );

  Widget _ratingsTile() {
    final r = _ratings;
    final avg = r?['average'];
    final avgText = avg == null ? '–' : (avg is num ? avg.toStringAsFixed(1) : '$avg');
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => portalGo('t_ratings'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: PT.card(),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: Color(0xFFEAF7E4), shape: BoxShape.circle),
            child: const Icon(Icons.star_rounded, color: PT.greenDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('My ratings', style: PT.t(14, w: FontWeight.w600)),
              Text(
                r == null ? 'What clients say about your classes' : '$avgText★ from ${r['count'] ?? 0} ratings · last 30 days',
                style: PT.t(12, c: PT.sage),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: PT.sage),
        ]),
      ),
    );
  }

  // ---------- list ----------

  Widget _classList() {
    final days = _days ?? const <Map<String, dynamic>>[];
    final hasAny = days.any((d) => (d['slots'] as List).isNotEmpty);
    return ListView(
      children: [
        _ratingsTile(),
        const SizedBox(height: 16),
        if (!hasAny)
          const PortalEmpty(
            icon: Icons.event_busy_outlined,
            title: 'No classes yet',
            sub: 'When admin gives you class times, they show here.',
          ),
        for (final d in days)
          if ((d['slots'] as List).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text('${d['day'] ?? ''}', style: PT.t(15, w: FontWeight.w700)),
            ),
            for (final s in (d['slots'] as List).cast<Map<String, dynamic>>()) _slotRow(s),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _slotRow(Map<String, dynamic> s) {
    final id = _id(s['id']);
    final sel = id != null && id == _selId;
    final type = '${s['type'] ?? ''}'.trim();
    final level = '${s['level'] ?? ''}'.trim();
    final sub = [
      if (type.isNotEmpty && type != 'null') type,
      if (level.isNotEmpty && level != 'null') '$level intensity',
    ].join(' · ');
    final chip = _listChip(s['status']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: sel ? const Color(0xFFEAF7E4) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _select(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? PT.green : PT.line),
            ),
            child: Row(children: [
              const Icon(Icons.schedule_rounded, size: 18, color: PT.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_time(s['start'])} – ${_time(s['end'])}',
                      style: PT.t(13.5, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  Text(sub.isEmpty ? 'No class details yet' : sub,
                      style: PT.t(12, c: PT.sage), overflow: TextOverflow.ellipsis),
                ]),
              ),
              if (chip != null) ...[const SizedBox(width: 8), chip],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: PT.sage, size: 20),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------- detail ----------

  Widget _detail({required bool showBack}) {
    if (_selId == null) {
      return Container(
        decoration: PT.card(),
        child: const PortalEmpty(
          icon: Icons.touch_app_outlined,
          title: 'Pick a class',
          sub: 'Choose a class on the left to see it, end or cancel it, or edit its details.',
        ),
      );
    }
    Widget body;
    if (_cLoading && _c == null) {
      body = const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    } else if (_c == null) {
      body = Container(
        decoration: PT.card(),
        child: PortalEmpty(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load the class',
          sub: _cError,
          action: TextButton(onPressed: _loadClass, child: const Text('Try again')),
        ),
      );
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(),
        const SizedBox(height: 14),
        if (!_live && !_ended && !_cancelled) ...[_roomCard(), const SizedBox(height: 14)],
        _mainAction(),
        if (_actionError != null) ...[
          const SizedBox(height: 10),
          Text(_actionError!, textAlign: TextAlign.center, style: PT.t(13, c: PT.red)),
        ],
        const SizedBox(height: 14),
        _detailsForm(),
      ]);
    }
    return ListView(children: [
      Row(children: [
        if (showBack)
          TextButton.icon(
            onPressed: () => setState(() => _selId = null),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('All classes'),
          ),
        const Spacer(),
        IconButton(
          tooltip: 'Reload this class',
          onPressed: _cLoading ? null : _loadClass,
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
      ]),
      body,
    ]);
  }

  Widget _header() {
    final c = _c!;
    final s = _slot(_selId);
    final day = _dayOf(_selId).isNotEmpty ? _dayOf(_selId) : '${c['day'] ?? ''}';
    final start = s != null ? _time(s['start']) : _time(c['start']);
    final end = s != null ? _time(s['end']) : _time(c['end']);
    final type = '${c['type'] ?? ''}'.trim();
    final level = '${c['level'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('$day · $start – $end', style: PT.t(12.5, c: PT.sage))),
          _chip(),
        ]),
        const SizedBox(height: 8),
        Text(type.isEmpty || type == 'null' ? 'Class' : type, style: PT.t(22, w: FontWeight.w700)),
        if (level.isNotEmpty && level != 'null') Text('$level intensity', style: PT.t(13, c: PT.sage)),
      ]),
    );
  }

  Widget _roomCard() {
    final room = '${_c!['zoomRoom'] ?? ''}';
    final roomSet = room.isNotEmpty && room != 'null';
    final masked = room.length > 4 ? '••• ${room.substring(room.length - 4)}' : room;
    return _box(
      'Class room',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<String>(
          value: _platform == 'other' ? 'other' : 'zoom',
          items: [
            DropdownMenuItem(value: 'zoom', child: Text('Zoom (your room)', style: PT.t(13.5))),
            DropdownMenuItem(value: 'other', child: Text('Other link (today only)', style: PT.t(13.5))),
          ],
          onChanged: _busy
              ? null
              : (v) {
                  if (v == null || v == _platform) return;
                  final wasOther = _c!['platform'] == 'other';
                  setState(() => _platform = v);
                  // Back to Zoom: clear today's other link on the server.
                  if (v == 'zoom' && wasOther) _saveBackup(clear: true);
                },
        ),
        const SizedBox(height: 10),
        if (_platform != 'other')
          roomSet
              ? Text('Your Zoom room $masked · set by admin', style: PT.t(13, c: PT.sage))
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFDF3DF), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'No Zoom room is set for you yet. Ask admin to add it, or choose "Other link" for today.',
                    style: PT.t(12.5, h: 1.4),
                  ),
                )
        else ...[
          TextField(
            key: const ValueKey('t_class_backup_link'),
            controller: _linkCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: 'https://meet.google.com/…'),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('For today only. Tomorrow it goes back to Zoom.', style: PT.t(12, c: PT.sage)),
              TextButton(
                onPressed: _busy ? null : () => _saveBackup(clear: false),
                child: Text('Save link', style: PT.t(13, w: FontWeight.w700, c: PT.greenDark)),
              ),
            ],
          ),
        ],
      ]),
    );
  }

  Widget _mainAction() {
    if (_cancelled || _ended) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFEDEFEA), borderRadius: BorderRadius.circular(16)),
        child: Text(_cancelled ? 'This class is cancelled for today.' : 'This class has ended. Thank you! 💚',
            textAlign: TextAlign.center, style: PT.t(13.5, c: PT.sage)),
      );
    }
    if (_live) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFEAF7E4), borderRadius: BorderRadius.circular(16)),
          child: Text('Class started · Live\nUsers can join now.',
              textAlign: TextAlign.center, style: PT.t(14, w: FontWeight.w700, c: PT.greenDark, h: 1.5)),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: portalPrimary(),
          onPressed: _openRoom,
          icon: const Icon(Icons.videocam_outlined, size: 18),
          label: const Text('Open Zoom'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _changeStatus('End the class?', 'Users will no longer see Join now.', 'End class', 'Completed'),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('End class')),
        ),
      ]);
    }
    if (!_isToday) {
      final day = _dayOf(_selId);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFEDEFEA), borderRadius: BorderRadius.circular(16)),
        child: Text('This class is on $day. You can start or cancel it on $day.',
            textAlign: TextAlign.center, style: PT.t(13.5, c: PT.sage, h: 1.4)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          style: portalPrimary(),
          onPressed: _busy ? null : _start,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow_rounded, size: 22),
          label: Text(_busy ? 'Starting…' : 'Start class', style: PT.t(15, w: FontWeight.w700, c: Colors.white)),
        ),
      ),
      if (_tooEarly != null) ...[
        const SizedBox(height: 8),
        Text(
          _tooEarly!.isEmpty ? "It's too early to start." : 'Too early — you can start from ${_tooEarly!}.',
          textAlign: TextAlign.center,
          style: PT.t(12.5, w: FontWeight.w600, c: PT.amber),
        ),
      ],
      const SizedBox(height: 6),
      Text('You can start from 10 minutes before class time. Users get "Join now" the moment you start, '
          'and your Zoom room opens in a new tab.',
          textAlign: TextAlign.center, style: PT.t(12, c: PT.sage, h: 1.4)),
      const SizedBox(height: 12),
      Center(
        child: OutlinedButton(
          style: portalDanger(),
          onPressed: _busy ? null : _cancelWithReason,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Cancel class'),
        ),
      ),
    ]);
  }

  Widget _detailsForm() => _box(
        'Class details',
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Class type', style: PT.t(13, w: FontWeight.w700)),
          const SizedBox(height: 8),
          _choices([..._kClassTypes, _kOther], _type, (v) => _type = v),
          if (_type == _kOther) ...[
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('t_class_custom_type'),
              controller: _customType,
              maxLength: 30,
              decoration: const InputDecoration(hintText: 'Type the class name'),
            ),
          ],
          const SizedBox(height: 16),
          Text('Intensity', style: PT.t(13, w: FontWeight.w700)),
          const SizedBox(height: 8),
          _choices(_kIntensities, _level, (v) => _level = v),
          const SizedBox(height: 16),
          Text('Description', style: PT.t(13, w: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('t_class_description'),
            controller: _desc,
            minLines: 3,
            maxLines: 5,
            maxLength: 300,
            decoration: const InputDecoration(hintText: 'What will clients do in this class?'),
          ),
          Text('Clients see the class type and intensity on their schedule.', style: PT.t(11.5, c: PT.sage)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: portalPrimary(),
              onPressed: _saving ? null : _saveDetails,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save details'),
            ),
          ),
        ]),
      );

  // ---------- page ----------

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'My classes',
        sub: 'Your weekly classes. Pick one to end or cancel it, set a backup link for today, or edit its details.',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading
                ? null
                : () {
                    _load();
                    _loadRatings();
                    if (_selId != null) _loadClass();
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      Expanded(
        child: _loading && _days == null
            ? const Center(child: CircularProgressIndicator())
            : _days == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load your classes",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : LayoutBuilder(builder: (c, box) {
                    if (box.maxWidth >= 900) {
                      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SizedBox(width: 360, child: _classList()),
                        const SizedBox(width: 20),
                        Expanded(child: _detail(showBack: false)),
                      ]);
                    }
                    return _selId == null ? _classList() : _detail(showBack: true);
                  }),
      ),
    ]);
  }
}
