import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../values/constants.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

/// Admin: class rooms (fitHer Flows › Live class).
///
///   MAIN CLASS ROOM: one Zoom meeting every trainer uses. Set it once here.
///   Own room (optional, per trainer): only if she teaches at the SAME time
///   as another trainer. Empty = she uses the main room.
///
/// Users only get the link when the trainer taps Start.
const _ink = Color(0xFF1F2A1E);
const _soft = Color(0xFF66705F);
const _deep = Color(0xFF4C6A4B);
const _lime = Color(0xFF8AD167);
const _limeBg = Color(0xFFEEF7E6);
const _line = Color(0xFFE3E8DF);
const _amber = Color(0xFFB7791F);
const _red = Color(0xFFC2412D);

TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _ink, double? h}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: s, fontWeight: w, color: c, height: h);

class TrainerRoomsScreen extends StatefulWidget {
  const TrainerRoomsScreen({super.key});

  @override
  State<TrainerRoomsScreen> createState() => _TrainerRoomsScreenState();
}

class _TrainerRoomsScreenState extends State<TrainerRoomsScreen> {
  List<Map<String, dynamic>> _trainers = [];
  final Map<int, TextEditingController> _ctrl = {};
  final _mainCtrl = TextEditingController();
  String? _mainRoom;
  bool _mainSaving = false;
  String? _mainMsg;
  final Set<int> _saving = {};
  final Set<int> _open = {}; // trainers whose "own room" box is expanded
  final Map<int, String> _msg = {};
  bool _loading = true;
  String? _error;

  String get _token =>
      Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
  ApiProvider get _api => Get.find<ApiProvider>();

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
    try {
      final r = await _api.getData(Constants.trainerRooms, headers: {'accessToken': _token});
      if (r.body is Map && r.body['status'] == '1') {
        final data = r.body['data'] is Map ? r.body['data'] as Map : const {};
        _mainRoom = (data['mainRoom'] ?? '').toString().isEmpty ? null : '${data['mainRoom']}';
        _mainCtrl.text = _mainRoom ?? '';
        final list = (data['trainers'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _trainers = list;
        for (final t in list) {
          final id = t['id'] as int;
          _ctrl.putIfAbsent(id, () => TextEditingController()).text = '${t['zoomRoom'] ?? ''}';
        }
        _error = null;
      } else {
        _error = r.body is Map ? '${r.body['message']}' : 'Could not load class rooms.';
      }
    } catch (_) {
      _error = 'Could not load class rooms. Check your internet.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveMain() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _mainSaving = true;
      _mainMsg = null;
    });
    try {
      final r = await _api.postData(Constants.mainClassRoom,
          body: {'zoomRoom': _mainCtrl.text.trim()}, headers: {'accessToken': _token});
      if (r.body is Map && r.body['status'] == '1') {
        final d = r.body['data'] as Map? ?? {};
        _mainRoom = '${d['mainRoom']}';
        _mainCtrl.text = _mainRoom!;
        _mainMsg = '✓ Saved · ${d['classesUpdated'] ?? 0} classes use it';
      } else {
        _mainMsg = r.body is Map ? '${r.body['message']}' : 'Could not save.';
      }
    } catch (_) {
      _mainMsg = 'Could not save. Check your internet.';
    }
    if (mounted) setState(() => _mainSaving = false);
  }

  /// [clear] = remove her own room, she goes back to the main room.
  Future<void> _saveOwn(int id, {bool clear = false}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving.add(id);
      _msg.remove(id);
    });
    try {
      final r = await _api.postData(Constants.trainerRoom,
          body: {'trainerId': id, 'zoomRoom': clear ? '' : _ctrl[id]!.text.trim()},
          headers: {'accessToken': _token});
      if (r.body is Map && r.body['status'] == '1') {
        final d = r.body['data'] as Map? ?? {};
        final room = (d['zoomRoom'] ?? '').toString();
        _ctrl[id]!.text = room;
        for (final t in _trainers) {
          if (t['id'] == id) t['zoomRoom'] = room.isEmpty ? null : room;
        }
        if (room.isEmpty) _open.remove(id);
        _msg[id] = room.isEmpty ? '✓ Back on the main room' : '✓ Own room saved';
      } else {
        _msg[id] = r.body is Map ? '${r.body['message']}' : 'Could not save.';
      }
    } catch (_) {
      _msg[id] = 'Could not save. Check your internet.';
    }
    if (mounted) setState(() => _saving.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        title: Text('Class Zoom Room', style: _t(17, w: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: FhLoader())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: _t(13, c: _red)),
                    ),
                  _mainCard(),
                  const SizedBox(height: 22),
                  Text('Trainers', style: _t(15, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Everyone uses the main room. Give a trainer her own room only if she teaches '
                    'at the same time as someone else.',
                    style: _t(12.5, c: _soft, h: 1.4),
                  ),
                  const SizedBox(height: 12),
                  if (_trainers.isEmpty && _error == null)
                    Text('No trainers yet. Add a trainer account first.', style: _t(13, c: _soft)),
                  for (final t in _trainers) _row(t),
                ],
              ),
            ),
    );
  }

  Widget _field(TextEditingController c) => TextField(
        controller: c,
        keyboardType: TextInputType.text,
        style: _t(14),
        decoration: InputDecoration(
          hintText: 'Zoom meeting number or invite link',
          hintStyle: _t(13, c: const Color(0xFFA3AC9C)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lime)),
        ),
      );

  Widget _saveBtn({required bool busy, required VoidCallback onTap, String label = 'Save'}) => SizedBox(
        height: 46,
        child: ElevatedButton(
          onPressed: busy ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _lime,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: _t(14, w: FontWeight.w600, c: Colors.white)),
        ),
      );

  Widget _msgText(String? m) => m == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(m, style: _t(12, c: m.startsWith('✓') ? _deep : _red)),
        );

  Widget _mainCard() {
    final has = _mainRoom != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: has ? _lime : const Color(0xFFE9A23B), width: 1.4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: _limeBg, shape: BoxShape.circle),
            child: const Icon(Icons.videocam_rounded, color: _deep, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Main class room', style: _t(15, w: FontWeight.w700)),
              Text('All trainers use this Zoom meeting', style: _t(12, c: _soft)),
            ]),
          ),
        ]),
        if (!has)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text("Not set yet: classes can't start until a room is set.",
                style: _t(12.5, c: _amber, w: FontWeight.w500)),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field(_mainCtrl)),
          const SizedBox(width: 10),
          _saveBtn(busy: _mainSaving, onTap: _saveMain),
        ]),
        _msgText(_mainMsg),
        const SizedBox(height: 10),
        Text(
          'Zoom tips: paid account · recurring meeting with "No fixed time" · passcode OFF · '
          'add every trainer as Alternative host.',
          style: _t(11.5, c: _soft, h: 1.4),
        ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> t) {
    final id = t['id'] as int;
    final own = '${t['zoomRoom'] ?? ''}';
    final hasOwn = own.isNotEmpty;
    final open = hasOwn || _open.contains(id);
    final name = '${t['name'] ?? ''}'.isEmpty ? '${t['email']}' : '${t['name']}';
    final status = hasOwn
        ? 'Own room · $own'
        : (_mainRoom != null ? 'Uses the main room' : 'No room yet');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: _t(14.5, w: FontWeight.w600)),
              Text('${t['classes'] ?? 0} classes · $status',
                  style: _t(12, c: (!hasOwn && _mainRoom == null) ? _amber : _soft)),
            ]),
          ),
          if (!open)
            TextButton(
              onPressed: () => setState(() => _open.add(id)),
              child: Text('Own room', style: _t(12.5, w: FontWeight.w600, c: _deep)),
            ),
        ]),
        if (open) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(_ctrl[id]!)),
            const SizedBox(width: 10),
            _saveBtn(busy: _saving.contains(id), onTap: () => _saveOwn(id)),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _saving.contains(id)
                  ? null
                  : () => hasOwn ? _saveOwn(id, clear: true) : setState(() => _open.remove(id)),
              child: Text(hasOwn ? 'Remove, use the main room' : 'Cancel',
                  style: _t(12.5, c: _soft, w: FontWeight.w500)),
            ),
          ),
        ],
        _msgText(_msg[id]),
      ]),
    );
  }
}
