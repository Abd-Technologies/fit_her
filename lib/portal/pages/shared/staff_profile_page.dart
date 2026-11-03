import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_session.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Profile for trainers and dietitians (app: ProfileScreen + Update
/// Speciality). Speciality, experience, total and description can be
/// edited here; the photo is changed in the mobile app.
class StaffProfilePage extends StatefulWidget {
  const StaffProfilePage({super.key});

  @override
  State<StaffProfilePage> createState() => _StaffProfilePageState();
}

class _StaffProfilePageState extends State<StaffProfilePage> {
  Map<String, dynamic>? _me; // speciality, experience, ... from the team list
  bool _loading = true;
  bool _failed = false;

  PortalSession get _s => Get.find<PortalSession>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final type = '${_s.user.value?['userType'] ?? ''}'.trim();
    Map<String, dynamic>? me;
    var failed = false;
    if (type.isNotEmpty) {
      final b = await PortalApi.get('${Constants.getUsersOnUserType}/$type');
      final d = b['data'];
      if (PortalApi.ok(b) && d is Map && d['users'] is List) {
        for (final u in (d['users'] as List).whereType<Map>()) {
          if ('${u['id']}' == '${_s.userId}') me = Map<String, dynamic>.from(u);
        }
      } else {
        failed = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _me = me ?? _me;
      _failed = failed && _me == null;
      _loading = false;
    });
  }

  Future<void> _edit(Map<String, dynamic> me, bool isDiet) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(me: me, userId: '${_s.userId}', isDiet: isDiet),
    );
    if (saved == true) _load();
  }

  static String _v(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty || s == 'null' ? '' : s;
  }

  Widget _row(String label, String value, {String empty = 'Not set yet'}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(label, style: PT.t(13, c: PT.sage))),
          Expanded(
            child: SelectableText(value.isEmpty ? empty : value,
                style: PT.t(13.5, w: value.isEmpty ? FontWeight.w400 : FontWeight.w500, c: value.isEmpty ? PT.sage : PT.ink)),
          ),
        ]),
      );

  Widget _box(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: PT.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: PT.t(15, w: FontWeight.w700)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );

  Widget _top() {
    final u = _s.user.value ?? const <String, dynamic>{};
    final name = _s.name.isEmpty ? 'Me' : _s.name;
    final img = _v(_me?['image']);
    final avatar = img.isEmpty ? null : PortalApi.file(img);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PT.card(),
      child: Row(children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: const Color(0xFFEAF7E4),
          foregroundImage: avatar == null ? null : NetworkImage(avatar),
          child: Text(name.substring(0, 1).toUpperCase(), style: PT.t(24, w: FontWeight.w700, c: PT.greenDark)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: PT.t(19, w: FontWeight.w700), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              StatusChip(_s.roleLabel),
              if (_v(u['email']).isNotEmpty) Text(_v(u['email']), style: PT.t(12.5, c: PT.sage)),
            ]),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _s.user.value ?? const <String, dynamic>{};
    final me = _me ?? const <String, dynamic>{};
    final isDiet = _s.role == PortalRole.dietitian;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Profile',
        sub: 'Your details as clients see them in the app.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _top(),
                const SizedBox(height: 16),
                _box('Contact', [
                  _row('Name', _s.name),
                  _row('Email', _v(u['email'])),
                  _row('Phone', _v(u['phone'])),
                ]),
                const SizedBox(height: 16),
                _box('Speciality', [
                  if (_loading && _me == null)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_failed)
                    Row(children: [
                      Expanded(child: Text("Couldn't load your details.", style: PT.t(13, c: PT.sage))),
                      TextButton(onPressed: _load, child: const Text('Try again')),
                    ])
                  else ...[
                    _row('Speciality', _v(me['speciality'])),
                    _row('Experience', _v(me['experience']).isEmpty ? '' : '${_v(me['experience'])} years'),
                    _row(isDiet ? 'Total clients' : 'Total patients', _v(me['totalPatients'])),
                    _row('About you', _v(me['description'])),
                  ],
                  const SizedBox(height: 10),
                  if (!_failed && !(_loading && _me == null))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        style: portalPrimary(),
                        onPressed: () => _edit(me, isDiet),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit details'),
                      ),
                    ),
                  const SizedBox(height: 10),
                  mobileOnlyNote('Changing your profile photo'),
                ]),
                const SizedBox(height: 16),
                _box('Settings', [
                  mobileOnlyNote('Notification settings'),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.logout_rounded, size: 18, color: PT.sage),
                    const SizedBox(width: 8),
                    Expanded(child: Text('To log out, use Log out at the top right.', style: PT.t(12.5, c: PT.sage))),
                  ]),
                ]),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.me, required this.userId, required this.isDiet});
  final Map<String, dynamic> me;
  final String userId;
  final bool isDiet;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  static String _v(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty || s == 'null' ? '' : s;
  }

  late final _spec = TextEditingController(text: _v(widget.me['speciality']));
  late final _exp = TextEditingController(text: _v(widget.me['experience']));
  late final _total = TextEditingController(text: _v(widget.me['totalPatients']));
  late final _desc = TextEditingController(text: _v(widget.me['description']));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_spec, _exp, _total, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final b = await PortalApi.post(Constants.updateUserProfile, {
      'userId': widget.userId,
      'speciality': _spec.text.trim(),
      'experience': _exp.text.trim(),
      'totalPatients': _total.text.trim(),
      'description': _desc.text.trim(),
    });
    if (!mounted) return;
    if (PortalApi.ok(b)) {
      portalToast('Profile saved');
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = PortalApi.msg(b);
      });
    }
  }

  Widget _f(String id, String label, TextEditingController c, {int lines = 1, bool number = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: ValueKey(id),
          controller: c,
          maxLines: lines,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          style: PT.t(13.5),
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Edit details', style: PT.t(17, w: FontWeight.w700)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _f('prof_spec', 'Speciality', _spec),
              _f('prof_exp', 'Experience (years)', _exp, number: true),
              _f('prof_total', widget.isDiet ? 'Total clients' : 'Total patients', _total, number: true),
              _f('prof_desc', 'About you', _desc, lines: 4),
              if (_error != null) Text(_error!, style: PT.t(12.5, c: PT.red)),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: Text('Cancel', style: PT.t(13.5, c: PT.sage)),
          ),
          ElevatedButton(
            style: portalPrimary(),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      );
}
