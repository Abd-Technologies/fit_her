import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Class Zoom rooms. One main room every trainer uses; a trainer gets her
/// own room only if she teaches at the same time as someone else.
/// Same calls as the app: GET /admin/trainerRooms, POST /admin/mainClassRoom,
/// POST /admin/trainerRoom.
class ZoomRoomPage extends StatefulWidget {
  const ZoomRoomPage({super.key});

  @override
  State<ZoomRoomPage> createState() => _ZoomRoomPageState();
}

class _ZoomRoomPageState extends State<ZoomRoomPage> {
  List<Map<String, dynamic>>? _trainers;
  final Map<int, TextEditingController> _ctrl = {};
  final _mainCtrl = TextEditingController();
  String? _mainRoom;
  bool _mainSaving = false;
  String? _mainMsg;
  bool _mainOk = false;
  final Set<int> _saving = {};
  final Set<int> _open = {};
  final Map<int, String> _msg = {};
  final Map<int, bool> _msgOk = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    _mainCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final b = await PortalApi.get('/admin/trainerRooms');
    if (PortalApi.ok(b)) {
      final data = b['data'] is Map ? b['data'] as Map : const {};
      final main = '${data['mainRoom'] ?? ''}';
      _mainRoom = main.isEmpty || main == 'null' ? null : main;
      _mainCtrl.text = _mainRoom ?? '';
      final list = (data['trainers'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['id'] is num)
          .toList();
      for (final t in list) {
        final id = (t['id'] as num).toInt();
        final room = '${t['zoomRoom'] ?? ''}';
        _ctrl.putIfAbsent(id, () => TextEditingController()).text = room == 'null' ? '' : room;
      }
      _trainers = list;
      _error = null;
    } else {
      _error = PortalApi.msg(b, "Couldn't load the class rooms.");
      if (_trainers == null) portalToast("Couldn't load the class rooms", sub: _error, error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveMain() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _mainSaving = true;
      _mainMsg = null;
    });
    final b = await PortalApi.post('/admin/mainClassRoom', {'zoomRoom': _mainCtrl.text.trim()});
    if (!mounted) return;
    if (PortalApi.ok(b)) {
      final d = b['data'] is Map ? b['data'] as Map : const {};
      final room = '${d['mainRoom'] ?? _mainCtrl.text.trim()}';
      _mainRoom = room.isEmpty || room == 'null' ? null : room;
      _mainCtrl.text = _mainRoom ?? '';
      _mainOk = true;
      _mainMsg = 'Saved. ${d['classesUpdated'] ?? 0} classes use it.';
      portalToast('Main class room saved');
    } else {
      _mainOk = false;
      _mainMsg = PortalApi.msg(b, "Couldn't save.");
    }
    setState(() => _mainSaving = false);
  }

  /// [clear] = remove her own room, she goes back to the main room.
  Future<void> _saveOwn(int id, {bool clear = false}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving.add(id);
      _msg.remove(id);
    });
    final b = await PortalApi.post('/admin/trainerRoom', {'trainerId': id, 'zoomRoom': clear ? '' : _ctrl[id]!.text.trim()});
    if (!mounted) return;
    if (PortalApi.ok(b)) {
      final d = b['data'] is Map ? b['data'] as Map : const {};
      var room = '${d['zoomRoom'] ?? ''}';
      if (room == 'null') room = '';
      _ctrl[id]!.text = room;
      for (final t in _trainers ?? const <Map<String, dynamic>>[]) {
        if ((t['id'] as num).toInt() == id) t['zoomRoom'] = room.isEmpty ? null : room;
      }
      if (room.isEmpty) _open.remove(id);
      _msgOk[id] = true;
      _msg[id] = room.isEmpty ? 'Back on the main room.' : 'Own room saved.';
    } else {
      _msgOk[id] = false;
      _msg[id] = PortalApi.msg(b, "Couldn't save.");
    }
    setState(() => _saving.remove(id));
  }

  Widget _field(String id, TextEditingController c) => TextField(
        key: ValueKey(id),
        controller: c,
        style: PT.t(13.5),
        decoration: const InputDecoration(hintText: 'Zoom meeting number or invite link'),
      );

  Widget _saveBtn({required bool busy, required VoidCallback onTap}) => ElevatedButton(
        style: portalPrimary(),
        onPressed: busy ? null : onTap,
        child: busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Save'),
      );

  Widget _msgText(String? m, bool ok) => m == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, size: 15, color: ok ? PT.greenDark : PT.red),
            const SizedBox(width: 6),
            Expanded(child: Text(m, style: PT.t(12, c: ok ? PT.greenDark : PT.red))),
          ]),
        );

  Widget _mainCard() {
    final has = _mainRoom != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: has ? PT.green : PT.amber, width: 1.4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: PT.wash, shape: BoxShape.circle),
            child: const Icon(Icons.videocam_rounded, color: PT.greenDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Main class room', style: PT.t(15.5, w: FontWeight.w700)),
              Text('All trainers use this Zoom meeting', style: PT.t(12.5, c: PT.sage)),
            ]),
          ),
        ]),
        if (!has)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text("Not set yet: classes can't start until a room is set.",
                style: PT.t(12.5, c: PT.amber, w: FontWeight.w500)),
          ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _field('zoom_main', _mainCtrl)),
          const SizedBox(width: 10),
          _saveBtn(busy: _mainSaving, onTap: _saveMain),
        ]),
        _msgText(_mainMsg, _mainOk),
        const SizedBox(height: 12),
        Text(
          'Zoom tips: paid account · recurring meeting with "No fixed time" · passcode OFF · '
          'add every trainer as Alternative host. Students only get the link when the trainer starts the class.',
          style: PT.t(11.5, c: PT.sage, h: 1.45),
        ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> t) {
    final id = (t['id'] as num).toInt();
    final own = '${t['zoomRoom'] ?? ''}';
    final hasOwn = own.isNotEmpty && own != 'null';
    final open = hasOwn || _open.contains(id);
    final name = '${t['name'] ?? ''}'.trim().isEmpty ? '${t['email'] ?? 'Trainer #$id'}' : '${t['name']}';
    final noRoom = !hasOwn && _mainRoom == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: PT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: PT.t(14, w: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${t['classes'] ?? 0} classes', style: PT.t(12, c: PT.sage)),
            ]),
          ),
          hasOwn
              ? const StatusChip('Own room')
              : noRoom
                  ? const StatusChip('No room yet', color: PT.amber)
                  : const StatusChip('Uses the main room', color: PT.sage),
          if (!open) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: () => setState(() => _open.add(id)), child: const Text('Give own room')),
          ],
        ]),
        if (hasOwn)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SelectableText(own, style: PT.t(12, c: PT.sage)),
          ),
        if (open) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('zoom_trainer_$id', _ctrl[id]!)),
            const SizedBox(width: 10),
            _saveBtn(busy: _saving.contains(id), onTap: () => _saveOwn(id)),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _saving.contains(id)
                  ? null
                  : () => hasOwn ? _saveOwn(id, clear: true) : setState(() => _open.remove(id)),
              child: Text(hasOwn ? 'Remove, use the main room' : 'Cancel', style: PT.t(12.5, c: PT.sage, w: FontWeight.w500)),
            ),
          ),
        ],
        _msgText(_msg[id], _msgOk[id] ?? false),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _trainers;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Class Zoom room',
        sub: 'The Zoom meeting used for live classes. Starting a class is done by the trainer in the mobile app.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading && list == null
            ? const Center(child: CircularProgressIndicator())
            : list == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load the class rooms",
                    sub: _error,
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : ListView(children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(_error!, style: PT.t(13, c: PT.red)),
                            ),
                          _mainCard(),
                          const SizedBox(height: 22),
                          Text('Trainers', style: PT.t(15.5, w: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            'Everyone uses the main room. Give a trainer her own room only if she teaches '
                            'at the same time as someone else.',
                            style: PT.t(12.5, c: PT.sage, h: 1.4),
                          ),
                          const SizedBox(height: 12),
                          if (list.isEmpty)
                            const PortalEmpty(
                              icon: Icons.person_search_outlined,
                              title: 'No trainers yet',
                              sub: 'Add a trainer on the Team page first.',
                            ),
                          for (final t in list) _row(t),
                          const SizedBox(height: 8),
                          mobileOnlyNote('Starting a Zoom class'),
                        ]),
                      ),
                    ),
                  ]),
      ),
    ]);
  }
}
