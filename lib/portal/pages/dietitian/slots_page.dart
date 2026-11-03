import 'package:flutter/material.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';
import 'd_ui.dart';

/// "Slots available": pick a weekday, then add, change or remove the
/// time slots clients can book on that day, each with its Google Meet
/// link. Save sends the whole day at once (the server checks the times,
/// overlaps, and refuses to remove a slot that still has bookings).
class DietitianSlotsPage extends StatefulWidget {
  const DietitianSlotsPage({super.key});

  @override
  State<DietitianSlotsPage> createState() => _DietitianSlotsPageState();
}

/// "5:10 AM" -> 310. Unknown text sorts last.
int _clockMinutes(String t) {
  final m = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])?').firstMatch(t);
  if (m == null) return 24 * 60;
  var h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  final ap = m.group(3)?.toUpperCase();
  if (ap == 'PM' && h < 12) h += 12;
  if (ap == 'AM' && h == 12) h = 0;
  return h * 60 + min;
}

class _EditSlot {
  _EditSlot({required this.uid, this.id, required this.start, required this.end, required String link})
      : link = TextEditingController(text: link);
  final int uid;
  final dynamic id; // null = new slot
  String start;
  String end;
  final TextEditingController link;
}

class _DietitianSlotsPageState extends State<DietitianSlotsPage> {
  List<Map<String, dynamic>>? _days;
  bool _loadingDays = true;
  String? _daysError;

  int? _dayId;
  List<_EditSlot>? _slots;
  bool _loadingSlots = false;
  String? _slotsError;
  bool _dirty = false;
  bool _saving = false;
  int _uid = 0;

  // Nov 2026: one Meet link for all her slots.
  final TextEditingController _allLink = TextEditingController();
  bool _savingAll = false;

  @override
  void initState() {
    super.initState();
    _loadDays();
  }

  @override
  void dispose() {
    _allLink.dispose();
    _disposeSlots();
    super.dispose();
  }

  void _disposeSlots() {
    for (final s in _slots ?? const <_EditSlot>[]) {
      s.link.dispose();
    }
  }

  String _dayName(int? id) =>
      '${(_days ?? const <Map<String, dynamic>>[]).where((d) => dInt(d['id']) == id).firstOrNull?['day'] ?? ''}';

  Future<void> _loadDays() async {
    setState(() {
      _loadingDays = true;
      _daysError = null;
    });
    final b = await PortalApi.get(Constants.dietTimes);
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['dietTimes'] is List) {
      list = dMaps(d['dietTimes']);
    } else {
      _daysError = PortalApi.msg(b, "Couldn't load the days.");
    }
    if (!mounted) return;
    setState(() {
      _loadingDays = false;
      if (list != null) {
        _days = list;
      } else if (_days != null) {
        portalToast("Couldn't refresh", sub: _daysError, error: true);
      }
    });
    if (list != null && list.isNotEmpty && (_dayId == null || !list.any((e) => dInt(e['id']) == _dayId))) {
      _openDay(dInt(list.first['id']), ask: false);
    } else if (_dayId != null && list != null) {
      _loadSlots();
    }
  }

  Future<void> _openDay(int id, {bool ask = true}) async {
    if (id == _dayId && _slots != null) return;
    if (ask && _dirty) {
      final yes = await portalConfirm(context,
          title: 'Discard changes?',
          body: "You haven't saved the slots for ${_dayName(_dayId)}. Leave without saving?",
          yes: 'Discard',
          danger: true);
      if (!yes) return;
    }
    setState(() => _dayId = id);
    await _loadSlots();
  }

  Future<void> _loadSlots() async {
    final dayId = _dayId;
    if (dayId == null) return;
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
    });
    final b = await PortalApi.post(Constants.dietTimes, {'dietitionId': dMyId(), 'dayId': dayId});
    if (!mounted || dayId != _dayId) return;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['slots'] is List) {
      final fresh = dMaps(d['slots'])
          .map((s) => _EditSlot(
                uid: _uid++,
                id: s['id'],
                start: dSlotTime(s['start']),
                end: dSlotTime(s['end']),
                link: (s['dietitionLink'] is String) ? s['dietitionLink'] as String : '',
              ))
          .toList()
        // In time order (earliest first), not the order they were added.
        ..sort((a, b) => _clockMinutes(a.start).compareTo(_clockMinutes(b.start)));
      setState(() {
        _disposeSlots();
        _slots = fresh;
        _dirty = false;
        _loadingSlots = false;
      });
    } else {
      setState(() {
        _disposeSlots();
        _slots = null;
        _loadingSlots = false;
        _slotsError = PortalApi.msg(b, "Couldn't load the slots.");
      });
    }
  }

  void _add() {
    setState(() {
      _slots!.add(_EditSlot(uid: _uid++, start: '9:00 AM', end: '7:00 PM', link: ''));
      _dirty = true;
    });
  }

  void _remove(_EditSlot s) {
    setState(() {
      _slots!.remove(s);
      _dirty = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => s.link.dispose());
  }

  Future<void> _pick(_EditSlot s, bool start) async {
    final cur = dParseTime(start ? s.start : s.end);
    final t = await showTimePicker(context: context, initialTime: cur ?? TimeOfDay.now());
    if (t == null || !mounted) return;
    setState(() {
      if (start) {
        s.start = dFormatTime(t);
      } else {
        s.end = dFormatTime(t);
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final dayId = _dayId;
    final slots = _slots;
    if (dayId == null || slots == null) return;
    setState(() => _saving = true);
    final b = await PortalApi.post('${Constants.dietTimes}/addOrUpdateDaySlot', {
      'dietitionId': dMyId(),
      'dayId': '$dayId',
      'slotsList': [
        for (final s in slots) {'start': s.start, 'end': s.end, 'id': s.id, 'dietitionLink': s.link.text},
      ],
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (PortalApi.ok(b)) {
      portalToast(PortalApi.msg(b, 'Slots saved'), sub: _dayName(dayId));
      _dirty = false;
      _loadSlots();
    } else {
      portalToast("Couldn't save the slots", sub: PortalApi.msg(b), error: true);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────
  Widget _dayTile(Map<String, dynamic> d) {
    final id = dInt(d['id']);
    final sel = id == _dayId;
    return Material(
      color: sel ? const Color(0xFFEAF7E4) : Colors.white,
      child: InkWell(
        onTap: () => _openDay(id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PT.line))),
          child: Row(children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: sel ? PT.green : PT.sage),
            const SizedBox(width: 10),
            Expanded(child: Text('${d['day'] ?? ''}', style: PT.t(13.5, w: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            if (sel && _dirty) const StatusChip('Not saved', color: PT.amber),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AB09A)),
          ]),
        ),
      ),
    );
  }

  Widget _timeBox(_EditSlot s, bool start) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: PT.ink,
          side: const BorderSide(color: PT.line),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _saving ? null : () => _pick(s, start),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.access_time_rounded, size: 15, color: PT.sage),
          const SizedBox(width: 6),
          Text(start ? s.start : s.end, style: PT.t(14, w: FontWeight.w500)),
        ]),
      );

  Widget _slotRow(_EditSlot s, int i) => Container(
        key: ValueKey('slot_${s.uid}'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(14), border: Border.all(color: PT.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('Slot ${i + 1}', style: PT.t(12.5, w: FontWeight.w700, c: PT.greenDark)),
            if (s.id == null) ...[const SizedBox(width: 8), const StatusChip('New', color: PT.amber)],
            const Spacer(),
            IconButton(
              tooltip: 'Remove slot',
              onPressed: _saving ? null : () => _remove(s),
              icon: const Icon(Icons.remove_circle_outline_rounded, color: PT.red),
            ),
          ]),
          Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _timeBox(s, true),
            Text('to', style: PT.t(13, c: PT.sage)),
            _timeBox(s, false),
          ]),
          const SizedBox(height: 10),
          TextField(
            key: ValueKey('slot_link_${s.uid}'),
            controller: s.link,
            enabled: !_saving,
            onChanged: (_) {
              if (!_dirty) setState(() => _dirty = true);
            },
            style: PT.t(13),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.videocam_outlined, size: 18),
              hintText: 'Google Meet link for this slot',
            ),
          ),
        ]),
      );

  Future<void> _saveAllLink() async {
    final link = _allLink.text.trim();
    if (link.isEmpty) return;
    if (_dirty) {
      portalToast('Save your slot changes first', error: true);
      return;
    }
    setState(() => _savingAll = true);
    final b = await PortalApi.post('${Constants.dietTimes}/setLinkForAllSlots', {'link': link});
    if (!mounted) return;
    setState(() => _savingAll = false);
    if (!PortalApi.ok(b)) {
      portalToast("Couldn't save the link", sub: PortalApi.msg(b), error: true);
      return;
    }
    final d = b['data'] is Map ? b['data'] as Map : const {};
    final n = d['upcomingBookings'] is num ? (d['upcomingBookings'] as num).toInt() : 0;
    portalToast(PortalApi.msg(b, 'Link saved on all your slots'),
        sub: n > 0 ? '$n upcoming booking${n == 1 ? '' : 's'} updated too' : null);
    _allLink.clear();
    if (_dayId != null) _loadSlots();
  }

  /// One Meet link for every slot (Nov 2026). Every client books into one
  /// of her slots, so this is the link they all get.
  Widget _allLinkBox() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: PT.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Your Meet link for all slots', style: PT.t(14, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
              'Paste one permanent Google Meet link. It is saved on all your slots and on bookings already made. '
              'Tip: in Meet, keep "Ask to join" on so you let each client in yourself.',
              style: PT.t(12, c: PT.sage, h: 1.4)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _allLink,
                enabled: !_savingAll,
                style: PT.t(13),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.videocam_outlined, size: 18),
                  hintText: 'https://meet.google.com/abc-defg-hij',
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: portalPrimary(),
              onPressed: _savingAll ? null : _saveAllLink,
              child: Text(_savingAll ? 'Saving…' : 'Use for all slots'),
            ),
          ]),
        ]),
      );

  Widget _editor() {
    final name = _dayName(_dayId);
    Widget body;
    if (_loadingSlots && _slots == null) {
      body = const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    } else if (_slots == null) {
      body = PortalEmpty(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load the slots",
        sub: _slotsError,
        action: TextButton(onPressed: _loadSlots, child: const Text('Try again')),
      );
    } else if (_slots!.isEmpty) {
      body = PortalEmpty(
        icon: Icons.event_busy_outlined,
        title: 'No slots on $name',
        sub: 'Add a slot so clients can book you on this day.',
        action: OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add slot')),
      );
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < _slots!.length; i++) _slotRow(_slots![i], i),
      ]);
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name.isEmpty ? 'Slots' : name, style: PT.t(19, w: FontWeight.w700)),
            Text('Set your available time slots on ${name.isEmpty ? 'this day' : name}', style: PT.t(12.5, c: PT.sage)),
          ]),
          Wrap(spacing: 10, runSpacing: 8, children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: PT.ink,
                side: const BorderSide(color: PT.green),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_slots == null || _saving) ? null : _add,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add slot'),
            ),
            ElevatedButton.icon(
              style: portalPrimary(),
              onPressed: (_slots == null || _saving) ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
            ),
          ]),
        ]),
        if (_loadingSlots && _slots != null) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(minHeight: 2)),
        const SizedBox(height: 16),
        body,
        const SizedBox(height: 4),
        Text('Times are Pakistan time. A slot that still has bookings can\'t be removed until those are cancelled.',
            style: PT.t(11.5, c: PT.sage)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _days ?? const <Map<String, dynamic>>[];
    final wide = MediaQuery.of(context).size.width >= 1100;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Slots available',
        sub: 'Set your available time slots to let clients easily book appointments during your free hours.',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: (_loadingDays || _saving) ? null : _loadDays,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      if (_days != null && (_days ?? const []).isNotEmpty) _allLinkBox(),
      Expanded(
        child: _loadingDays && _days == null
            ? const Center(child: CircularProgressIndicator())
            : _days == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load the days",
                    sub: _daysError,
                    action: TextButton(onPressed: _loadDays, child: const Text('Try again')),
                  )
                : days.isEmpty
                    ? const PortalEmpty(icon: Icons.event_busy_outlined, title: 'No days set up yet')
                    : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: wide ? 260 : 200,
                          decoration: PT.card(),
                          clipBehavior: Clip.antiAlias,
                          child: ListView(shrinkWrap: true, children: days.map(_dayTile).toList()),
                        ),
                        const SizedBox(width: 18),
                        Expanded(child: SingleChildScrollView(child: _editor())),
                      ]),
      ),
    ]);
  }
}
