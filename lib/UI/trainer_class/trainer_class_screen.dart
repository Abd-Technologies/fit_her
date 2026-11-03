import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fitness_zone_2/widgets/toasts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../values/constants.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

/// Trainer's class screen (Oct 2026).
///
/// One job: tap **Start**. The class room is the trainer's Zoom room, set
/// once by admin — nothing to paste. On a bad day she can switch the
/// platform to "Other link" for TODAY only.
///
///   Start → server marks the class live (users get "Join now" + a push)
///         → opens Zoom for her. Only shows "Class started" once the
///           server confirmed; otherwise "Couldn't start · tap to retry".
///   End / Cancel → same server endpoint (Cancel sends users the same
///         message + popup as an auto-cancel).
class TrainerClassScreen extends StatefulWidget {
  final int slotId;
  const TrainerClassScreen({super.key, required this.slotId});

  @override
  State<TrainerClassScreen> createState() => _TrainerClassScreenState();
}

const _ink = Color(0xFF1F2A1E);
const _soft = Color(0xFF66705F);
const _green = Color(0xFF4C6A4B);
const _lime = Color(0xFF8AD167);
const _limeBg = Color(0xFFEEF7E6);
const _red = Color(0xFFC2412D);
const _redBg = Color(0xFFFCEBE7);
const _amber = Color(0xFFB7791F);
const _amberBg = Color(0xFFFDF3DF);
const _line = Color(0xFFE3E8DF);

class _TrainerClassScreenState extends State<TrainerClassScreen> {
  Map<String, dynamic>? _c;
  bool _loading = true;
  bool _busy = false;
  String? _error; // shown under the main button
  String? _tooEarly; // "5:50 PM" when she tapped Start too early
  String _platform = 'zoom';
  final _linkCtrl = TextEditingController();

  String get _token =>
      Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
  ApiProvider get _api => Get.find<ApiProvider>();

  String get _status => '${_c?['status'] ?? 'Upcoming Class'}';
  bool get _live => _status == 'In Progress';
  bool get _cancelled => _status == 'Cancelled';
  bool get _ended => _status == 'Completed';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  void _apply(dynamic data) {
    if (data is! Map) return;
    _c = Map<String, dynamic>.from(data);
    _platform = '${_c!['platform'] ?? 'zoom'}';
    final b = _c!['backupLink'];
    if (b is String && b.isNotEmpty) _linkCtrl.text = b;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getData('${Constants.trainerClass}/${widget.slotId}',
          headers: {'accessToken': _token});
      if (r.body is Map && r.body['status'] == '1') {
        _apply(r.body['data']);
        _error = null;
      } else {
        _error = r.body is Map ? '${r.body['message']}' : 'Could not load the class.';
      }
    } catch (_) {
      _error = 'Could not load the class. Check your internet.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _setStatus(String status) async {
    try {
      final r = await _api.postData(Constants.updateSlotStatus,
          body: {'slotId': '${widget.slotId}', 'status': status},
          headers: {'accessToken': _token});
      if (r.body is Map && r.body['status'] == '1') {
        if (r.body['data'] is Map && (r.body['data'] as Map).isNotEmpty) {
          _apply(r.body['data']);
        } else {
          _c = {...?_c, 'status': status};
        }
        return true;
      }
      final data = r.body is Map ? r.body['data'] : null;
      if (data is Map && data['code'] == 'TOO_EARLY') {
        _tooEarly = '${data['opensAtLabel'] ?? ''}';
        _error = null;
        return false;
      }
      _error = r.body is Map ? '${r.body['message']}' : null;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _tooEarly = null;
    });
    // Up to 3 tries on a weak connection before asking her to retry.
    var ok = false;
    for (var i = 0; i < 3 && !ok; i++) {
      ok = await _setStatus('In Progress');
      if (!ok && (_error != null || _tooEarly != null)) break; // server said no (no room / too early)
      if (!ok) await Future.delayed(const Duration(seconds: 2));
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok && _tooEarly == null) _error ??= "Couldn't start. Tap to retry.";
    });
    if (ok) await _openRoom();
  }

  Future<void> _openRoom() async {
    final link = '${_c?['openLink'] ?? ''}';
    if (link.isEmpty) return;
    // The class is already live for users at this point. This only puts
    // the trainer (the host) into her Zoom room; users joining in the app
    // join this same room, so she needs to be in it.
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) {
      // No Zoom app on this phone: let the phone pick (browser → Zoom page).
      try {
        opened = await launchUrl(Uri.parse(link), mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
    if (!opened && mounted) {
      CustomToast.warnToast("Zoom didn't open",
          sub: 'Your class is live. Open the Zoom app and start your room.',
          action: 'Try again',
          onAction: _openRoom);
    }
  }

  Future<void> _confirmThen(String title, String body, String yes, String status) async {
    final go = await Get.dialog<bool>(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17)),
      content: Text(body, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, height: 1.45)),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Not now')),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: Text(yes, style: TextStyle(fontWeight: FontWeight.w700, color: status == 'Cancelled' ? _red : _green)),
        ),
      ],
    ));
    if (go != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await _setStatus(status);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error ??= 'Could not update. Tap to retry.';
    });
  }

  Future<void> _saveBackup({required bool clear}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _api.postData(Constants.trainerClassBackupLink,
          body: {'slotId': widget.slotId, 'link': clear ? null : _linkCtrl.text.trim()},
          headers: {'accessToken': _token});
      if (r.body is Map && r.body['status'] == '1') {
        _apply(r.body['data']);
        FhToast.show(FhToastKind.success, clear ? 'Back to Zoom' : 'Link saved for today',
            sub: clear ? 'Your class uses your Zoom room.' : 'Users will join with this link today.');
      } else {
        _error = r.body is Map ? '${r.body['message']}' : 'Could not save the link.';
      }
    } catch (_) {
      _error = 'Could not save the link. Check your internet.';
    }
    if (mounted) setState(() => _busy = false);
  }

  // ── UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text('Your class', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: FhLoader())
          : _c == null
              ? _errorState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _header(),
                      const SizedBox(height: 18),
                      if (!_live && !_ended && !_cancelled) _roomCard(),
                      if (!_live && !_ended && !_cancelled) const SizedBox(height: 18),
                      _mainAction(),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Poppins', color: _red, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ?? 'Could not load the class.', textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Poppins', color: _soft)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ]),
        ),
      );

  Widget _chip() {
    late Color bg, fg;
    late String text;
    if (_live) {
      bg = _redBg; fg = _red; text = '● LIVE';
    } else if (_cancelled) {
      bg = const Color(0xFFEDEFEA); fg = _soft; text = 'CANCELLED';
    } else if (_ended) {
      bg = const Color(0xFFEDEFEA); fg = _soft; text = 'ENDED';
    } else {
      bg = _amberBg; fg = _amber; text = 'NOT STARTED';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: fg, letterSpacing: .4)),
    );
  }

  Widget _header() {
    final c = _c!;
    final type = '${c['type'] ?? 'Class'}'.trim();
    final level = '${c['level'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${c['day'] ?? ''} · ${c['start'] ?? ''} – ${c['end'] ?? ''}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: _soft)),
          ),
          _chip(),
        ]),
        const SizedBox(height: 8),
        Text(type.isEmpty ? 'Class' : type,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: _ink)),
        if (level.isNotEmpty)
          Text('$level intensity', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _soft)),
      ]),
    );
  }

  Widget _roomCard() {
    final room = '${_c!['zoomRoom'] ?? ''}';
    final masked = room.length > 4 ? '••• ${room.substring(room.length - 4)}' : room;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Class room', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _platform,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'zoom', child: Text('Zoom (your room)', style: TextStyle(fontFamily: 'Poppins', fontSize: 14))),
            DropdownMenuItem(value: 'other', child: Text('Other link (today only)', style: TextStyle(fontFamily: 'Poppins', fontSize: 14))),
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
        if (_platform == 'zoom')
          room.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _amberBg, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    'No Zoom room is set for you yet. Ask admin to add it, or choose "Other link" for today.',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: _ink, height: 1.4),
                  ),
                )
              : Text('Your Zoom room $masked · set by admin',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _soft))
        else ...[
          TextField(
            controller: _linkCtrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://meet.google.com/…',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Expanded(
              child: Text('For today only. Tomorrow it goes back to Zoom.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _soft)),
            ),
            TextButton(
              onPressed: _busy ? null : () => _saveBackup(clear: false),
              child: const Text('Save link', style: TextStyle(fontWeight: FontWeight.w700, color: _green)),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _bigButton(String text, Color color, VoidCallback? onTap, {Color fg = Colors.white}) => SizedBox(
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: fg,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _busy ? null : onTap,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(text, style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _mainAction() {
    if (_cancelled || _ended) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFEDEFEA), borderRadius: BorderRadius.circular(16)),
        child: Text(_cancelled ? 'This class is cancelled for today.' : 'This class has ended. Thank you! 💚',
            textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Poppins', color: _soft)),
      );
    }
    if (_live) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _limeBg, borderRadius: BorderRadius.circular(16)),
          child: const Text('Class started · Live\nUsers can join now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: _green, height: 1.5)),
        ),
        const SizedBox(height: 12),
        _bigButton('Open Zoom again', _green, _openRoom),
        const SizedBox(height: 10),
        _bigButton('End class', Colors.white, () => _confirmThen(
              'End the class?', 'Users will no longer see Join now.', 'End class', 'Completed'),
            fg: _ink),
      ]);
    }
    final noRoom = _platform == 'zoom' && '${_c!['zoomRoom'] ?? ''}'.isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_tooEarly != null) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF3DF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF2D49B)),
          ),
          child: Row(children: [
            const Icon(Icons.schedule_rounded, color: Color(0xFFB7791F), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _tooEarly!.isEmpty
                    ? 'Too early. You can start 10 minutes before class time.'
                    : 'Too early. You can start at $_tooEarly (10 minutes before class).',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF7A4E0E), height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      _bigButton(_error != null ? 'Retry Start' : 'Start class', _lime, noRoom ? null : _start, fg: _ink),
      const SizedBox(height: 6),
      const Text('You can start from 10 minutes before class time.\nUsers get "Join now" the moment you start.',
          textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _soft, height: 1.4)),
      const SizedBox(height: 14),
      TextButton(
        onPressed: _busy
            ? null
            : () => _confirmThen('Cancel today\'s class?',
                'Users will be told it\'s cancelled and shown the next class.', 'Cancel class', 'Cancelled'),
        child: const Text('Cancel class', style: TextStyle(fontFamily: 'Poppins', color: _red, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}
