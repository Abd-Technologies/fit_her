import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Weekly class timetable: for each day, the class slots with their time,
/// trainer and workout details. Same calls as the app:
/// GET /admin/getAllTimesWithSlots, GET /admin/get_users_based_on_types/Trainer,
/// POST /admin/update_slots {times: [...]}.
class TrainerSlotsPage extends StatefulWidget {
  const TrainerSlotsPage({super.key});

  @override
  State<TrainerSlotsPage> createState() => _TrainerSlotsPageState();
}

const List<String> _kTypes = ['Yoga', 'Pilates', 'Zumba', 'HIIT', 'Strength', 'Low Impact'];
const List<String> _kLevels = ['Low', 'Medium', 'High'];
const String _kOther = 'Other';

/// Reads "08:00 AM", "8:00 pm", "14:30" or a legacy ms timestamp.
TimeOfDay? _parseTime(dynamic raw) {
  final s = '${raw ?? ''}'.trim();
  if (s.isEmpty || s == 'Start Time' || s == 'End Time' || s == 'null') return null;
  final n = int.tryParse(s);
  if (n != null && s.length >= 10) {
    final d = DateTime.fromMillisecondsSinceEpoch(n);
    return TimeOfDay(hour: d.hour, minute: d.minute);
  }
  final m = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])?$').firstMatch(s);
  if (m == null) return null;
  var h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  final ap = m.group(3)?.toUpperCase();
  if (ap == 'PM' && h != 12) h += 12;
  if (ap == 'AM' && h == 12) h = 0;
  if (h > 23 || min > 59) return null;
  return TimeOfDay(hour: h, minute: min);
}

/// "08:00 AM" (the format the server keeps).
String _fmtTime(TimeOfDay t) {
  final h12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '${h12.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $ap';
}

int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

int _uid = 0;

class _Slot {
  _Slot({this.id, this.dayId, this.start, this.end, this.trainerId, String? type, String? level, String? description})
      : key = 'slot_${_uid++}' {
    typeC.text = type ?? '';
    levelC.text = level ?? '';
    descC.text = description ?? '';
    final t = typeC.text.trim();
    if (t.isNotEmpty) {
      final match = _kTypes.firstWhere((o) => o.toLowerCase() == t.toLowerCase(), orElse: () => '');
      if (match.isNotEmpty) {
        typeC.text = match;
      } else {
        typeOther = true;
      }
    }
    final l = levelC.text.trim();
    if (l.isNotEmpty) {
      final match = _kLevels.firstWhere((o) => o.toLowerCase() == l.toLowerCase(), orElse: () => '');
      if (match.isNotEmpty) levelC.text = match;
    }
  }

  final String key;
  int? id;
  int? dayId;
  TimeOfDay? start;
  TimeOfDay? end;
  int? trainerId;
  bool typeOther = false;
  final typeC = TextEditingController();
  final levelC = TextEditingController();
  final descC = TextEditingController();

  bool get complete => start != null && end != null && trainerId != null;

  void dispose() {
    typeC.dispose();
    levelC.dispose();
    descC.dispose();
  }

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Map<String, dynamic> toJson() => {
        'start': _fmtTime(start!),
        'end': _fmtTime(end!),
        'trainerId': trainerId,
        'id': id,
        'dayId': dayId,
        'type': _v(typeC),
        'level': _v(levelC),
        'description': _v(descC),
      };
}

class _Day {
  _Day(this.id, this.day, this.slots);
  final int id;
  final String day;
  final List<_Slot> slots;
}

class _TrainerSlotsPageState extends State<TrainerSlotsPage> {
  List<_Day>? _days;
  List<Map<String, dynamic>> _trainers = [];
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  final Set<String> _open = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposeDays();
    super.dispose();
  }

  void _disposeDays() {
    for (final d in _days ?? const <_Day>[]) {
      for (final s in d.slots) {
        s.dispose();
      }
    }
  }

  Future<void> _load() async {
    if (_dirty) {
      final go = await portalConfirm(context,
          title: 'Throw away changes?',
          body: 'You have changes that are not saved yet. Reloading will lose them.',
          yes: 'Reload',
          danger: true);
      if (!go) return;
    }
    setState(() => _loading = true);
    final res = await Future.wait([
      PortalApi.get('/admin/getAllTimesWithSlots'),
      PortalApi.get('/admin/get_users_based_on_types/Trainer'),
    ]);
    final tb = res[0];
    final ub = res[1];
    List<_Day>? days;
    final td = tb['data'];
    if (PortalApi.ok(tb) && td is Map && td['times'] is List) {
      days = [];
      for (final t in (td['times'] as List).whereType<Map>()) {
        final id = (t['id'] as num?)?.toInt() ?? 0;
        final raw = t['Slots'] is List ? t['Slots'] as List : (t['slots'] is List ? t['slots'] as List : const []);
        final slots = raw.whereType<Map>().map((s) {
          return _Slot(
            id: (s['id'] as num?)?.toInt(),
            dayId: (s['TimeId'] as num?)?.toInt() ?? id,
            start: _parseTime(s['start']),
            end: _parseTime(s['end']),
            trainerId: (s['trainerId'] as num?)?.toInt(),
            type: s['type']?.toString(),
            level: s['level']?.toString(),
            description: s['description']?.toString(),
          );
        }).toList();
        slots.sort((a, b) => (a.start == null ? 9999 : _mins(a.start!)).compareTo(b.start == null ? 9999 : _mins(b.start!)));
        if (slots.isEmpty) slots.add(_Slot(dayId: id));
        days.add(_Day(id, '${t['day'] ?? ''}', slots));
      }
    } else {
      portalToast("Couldn't load the slots", sub: PortalApi.msg(tb), error: true);
    }
    final trainers = <Map<String, dynamic>>[];
    final ud = ub['data'];
    if (PortalApi.ok(ub) && ud is Map && ud['users'] is List) {
      trainers.addAll((ud['users'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    } else if (days != null) {
      portalToast("Couldn't load the trainers", sub: PortalApi.msg(ub), error: true);
    }
    if (!mounted) return;
    final old = _days;
    setState(() {
      _days = days;
      _trainers = trainers;
      _loading = false;
      _dirty = false;
      _open.clear();
    });
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final d in old) {
          for (final s in d.slots) {
            s.dispose();
          }
        }
      });
    }
  }

  void _changed() => setState(() => _dirty = true);

  String _trainerName(int? id) {
    if (id == null) return 'No trainer yet';
    for (final t in _trainers) {
      if ((t['id'] as num?)?.toInt() == id) return '${t['firstName'] ?? ''} ${t['lastName'] ?? ''}'.trim();
    }
    return 'Trainer #$id';
  }

  Future<void> _pickTime(_Slot s, bool isStart) async {
    final cur = isStart ? s.start : s.end;
    final t = await showTimePicker(
      context: context,
      initialTime: cur ?? (isStart ? const TimeOfDay(hour: 8, minute: 0) : (s.start ?? const TimeOfDay(hour: 9, minute: 0))),
      helpText: isStart ? 'Class starts at' : 'Class ends at',
    );
    if (t == null) return;
    setState(() {
      if (isStart) {
        s.start = t;
      } else {
        s.end = t;
      }
      _dirty = true;
    });
  }

  void _addSlot(_Day d) {
    final s = _Slot(dayId: d.id);
    setState(() {
      d.slots.add(s);
      _open.add(s.key);
      _dirty = true;
    });
  }

  /// Saved slot: delete on the server (it leaves every schedule; past
  /// attendance and feedback stay). Not-saved slot: just remove it here.
  Future<void> _deleteSaved(_Day d, _Slot s) async {
    final when = (s.start != null && s.end != null) ? '${_fmtTime(s.start!)} - ${_fmtTime(s.end!)}' : '';
    final sure = await portalConfirm(
      context,
      title: 'Delete this class slot?',
      body: '${d.day}${when.isEmpty ? '' : ' $when'} will be removed from the timetable for everyone. '
          'Women booked into it will no longer see it. Past attendance and ratings are kept.',
      yes: 'Delete slot',
      danger: true,
    );
    if (!sure) return;
    final b = await PortalApi.post('/admin/slots/${s.id}/delete', {});
    if (!mounted) return;
    if (PortalApi.ok(b)) {
      portalToast('Slot deleted', sub: '${d.day}${when.isEmpty ? '' : ' · $when'}');
      _removeSlot(d, s, markDirty: false);
    } else {
      portalToast("Couldn't delete", sub: PortalApi.msg(b), error: true);
    }
  }

  void _removeSlot(_Day d, _Slot s, {bool markDirty = true}) {
    setState(() {
      d.slots.remove(s);
      _open.remove(s.key);
      if (d.slots.isEmpty) d.slots.add(_Slot(dayId: d.id));
      if (markDirty) _dirty = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => s.dispose());
  }

  Future<void> _save() async {
    final days = _days;
    if (days == null) return;
    var skipped = 0;
    final times = <Map<String, dynamic>>[];
    for (final d in days) {
      final ok = <Map<String, dynamic>>[];
      for (final s in d.slots) {
        if (s.complete) {
          ok.add(s.toJson());
        } else if (s.start != null || s.end != null || s.trainerId != null) {
          skipped++;
        }
      }
      if (ok.isNotEmpty) times.add({'day': d.day, 'id': d.id, 'slots': ok});
    }
    if (times.isEmpty) {
      portalToast('Nothing to save yet', sub: 'Each slot needs a start time, an end time and a trainer.', error: true);
      return;
    }
    if (skipped > 0) {
      final go = await portalConfirm(context,
          title: 'Some slots are not finished',
          body: '$skipped slot(s) are missing a start time, end time or trainer. They will not be saved. Save the rest?',
          yes: 'Save the rest');
      if (!go) return;
    }
    setState(() => _saving = true);
    final b = await PortalApi.post('/admin/update_slots', {'times': times});
    if (!mounted) return;
    setState(() => _saving = false);
    if (PortalApi.ok(b)) {
      portalToast('Slots saved', sub: PortalApi.msg(b, ''));
      _dirty = false;
      _load();
    } else {
      portalToast("Couldn't save the slots", sub: PortalApi.msg(b), error: true);
    }
  }

  // ---------- UI ----------

  Widget _timeBox(_Slot s, bool isStart) {
    final t = isStart ? s.start : s.end;
    return OutlinedButton.icon(
      onPressed: () => _pickTime(s, isStart),
      style: OutlinedButton.styleFrom(
        foregroundColor: PT.ink,
        side: const BorderSide(color: PT.line),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.schedule_rounded, size: 17, color: PT.green),
      label: Text(t == null ? (isStart ? 'Start time' : 'End time') : _fmtTime(t),
          style: PT.t(13.5, c: t == null ? PT.sage : PT.ink, w: t == null ? FontWeight.w400 : FontWeight.w600)),
    );
  }

  Widget _trainerBox(_Slot s) {
    final ids = _trainers.map((t) => (t['id'] as num?)?.toInt()).whereType<int>().toSet();
    final value = ids.contains(s.trainerId) ? s.trainerId : null;
    return DropdownButtonFormField<int?>(
      key: ValueKey('${s.key}_trainer_${_trainers.length}'),
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Trainer'),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text('Select trainer', style: PT.t(13.5, c: PT.sage))),
        ..._trainers.where((t) => t['id'] is num).map((t) => DropdownMenuItem<int?>(
              value: (t['id'] as num).toInt(),
              child: Text('${t['firstName'] ?? ''} ${t['lastName'] ?? ''}'.trim(),
                  overflow: TextOverflow.ellipsis, style: PT.t(13.5)),
            )),
      ],
      onChanged: (v) {
        s.trainerId = v;
        _changed();
      },
    );
  }

  Widget _chips(String label, List<String> options, TextEditingController c, _Slot s, {bool other = false}) {
    final cur = c.text.trim();
    final all = [...options, if (other) _kOther];
    String? selected;
    if (other && s.typeOther) {
      selected = _kOther;
    } else if (options.contains(cur)) {
      selected = cur;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: PT.t(12.5, w: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final o in all)
          ChoiceChip(
            label: Text(o, style: PT.t(12.5, w: FontWeight.w600, c: o == selected ? Colors.white : PT.ink)),
            selected: o == selected,
            selectedColor: PT.green,
            backgroundColor: Colors.white,
            showCheckmark: false,
            side: BorderSide(color: o == selected ? PT.green : PT.line),
            onSelected: (_) {
              setState(() {
                if (o == selected) {
                  c.text = '';
                  if (o == _kOther) s.typeOther = false;
                } else if (o == _kOther) {
                  s.typeOther = true;
                  c.text = '';
                } else {
                  if (other) s.typeOther = false;
                  c.text = o;
                }
                _dirty = true;
              });
            },
          ),
      ]),
      if (other && s.typeOther) ...[
        const SizedBox(height: 8),
        SizedBox(
          width: 260,
          child: TextField(
            key: ValueKey('${s.key}_type_other'),
            controller: c,
            maxLength: 30,
            style: PT.t(13.5),
            onChanged: (_) => _dirty = true,
            decoration: const InputDecoration(hintText: 'Type the class name', counterText: ''),
          ),
        ),
      ],
    ]);
  }

  Widget _slotCard(_Day d, _Slot s) {
    final open = _open.contains(s.key);
    final saved = s.id != null;
    final title = (s.start == null && s.end == null)
        ? 'New slot'
        : '${s.start == null ? '?' : _fmtTime(s.start!)}  to  ${s.end == null ? '?' : _fmtTime(s.end!)}';
    final bits = <String>[
      _trainerName(s.trainerId),
      if (s.typeC.text.trim().isNotEmpty) s.typeC.text.trim(),
      if (s.levelC.text.trim().isNotEmpty) '${s.levelC.text.trim()} intensity',
    ];
    final timeWarn = s.start != null && s.end != null && _mins(s.end!) <= _mins(s.start!);
    return Container(
      key: ValueKey(s.key),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.complete ? PT.line : const Color(0xFFF0DCC4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => open ? _open.remove(s.key) : _open.add(s.key)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(children: [
              Icon(s.complete ? Icons.event_available_rounded : Icons.edit_calendar_outlined,
                  size: 18, color: s.complete ? PT.green : PT.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: PT.t(13.5, w: FontWeight.w600)),
                  Text(bits.join('  ·  '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: PT.t(12, c: s.trainerId == null ? PT.amber : PT.sage)),
                ]),
              ),
              if (!saved) const Padding(padding: EdgeInsets.only(right: 4), child: StatusChip('Not saved', color: PT.amber)),
              saved
                  ? IconButton(
                      tooltip: 'Delete this slot',
                      onPressed: () => _deleteSaved(d, s),
                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: PT.red),
                    )
                  : IconButton(
                      tooltip: 'Remove this slot',
                      onPressed: () => _removeSlot(d, s),
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 19, color: PT.red),
                    ),
              Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: PT.sage),
              const SizedBox(width: 6),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth > 720;
              final times = Wrap(spacing: 10, runSpacing: 10, children: [_timeBox(s, true), _timeBox(s, false)]);
              final trainer = SizedBox(width: wide ? 300 : double.infinity, child: _trainerBox(s));
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Divider(height: 1, color: PT.line),
                const SizedBox(height: 12),
                wide
                    ? Row(children: [times, const SizedBox(width: 16), trainer])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [times, const SizedBox(height: 10), trainer]),
                if (timeWarn)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('The end time is before the start time. Please check.', style: PT.t(12, c: PT.amber)),
                  ),
                const SizedBox(height: 14),
                Wrap(spacing: 28, runSpacing: 14, children: [
                  _chips('Class type', _kTypes, s.typeC, s, other: true),
                  _chips('Intensity', _kLevels, s.levelC, s),
                ]),
                const SizedBox(height: 14),
                TextField(
                  key: ValueKey('${s.key}_desc'),
                  controller: s.descC,
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 4,
                  style: PT.t(13.5),
                  onChanged: (_) => _dirty = true,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'What the class is about',
                  ),
                ),
                Text('Workout details are optional. Left empty, anything the trainer already filled in stays.',
                    style: PT.t(11.5, c: PT.sage)),
              ]);
            }),
          ),
      ]),
    );
  }

  Widget _dayCard(_Day d) {
    final done = d.slots.where((s) => s.complete).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(d.day, style: PT.t(15.5, w: FontWeight.w700))),
          Text(done == 1 ? '1 class' : '$done classes', style: PT.t(12, c: PT.sage)),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _addSlot(d),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add slot'),
          ),
        ]),
        const SizedBox(height: 8),
        for (final s in d.slots) _slotCard(d, s),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Trainer slots',
        sub: 'The weekly class timetable. For each day, set the class times and who teaches. '
            'Click a slot to edit it, then press Save.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading || _saving ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: portalPrimary(),
            onPressed: _saving || _loading || days == null ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_saving ? 'Saving…' : (_dirty ? 'Save changes' : 'Save')),
          ),
        ],
      ),
      Expanded(
        child: _loading && days == null
            ? const Center(child: CircularProgressIndicator())
            : days == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load the slots",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : days.isEmpty
                    ? const PortalEmpty(icon: Icons.calendar_month_outlined, title: 'No days set up yet')
                    : ListView(children: [
                        if (_trainers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('No trainers found. Add a trainer on the Team page first.',
                                style: PT.t(12.5, c: PT.amber, w: FontWeight.w500)),
                          ),
                        if (_dirty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('You have changes that are not saved yet.',
                                style: PT.t(12.5, c: PT.amber, w: FontWeight.w500)),
                          ),
                        for (final d in days) _dayCard(d),
                      ]),
      ),
    ]);
  }
}
