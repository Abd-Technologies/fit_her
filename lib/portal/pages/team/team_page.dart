import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Team members (trainers, dietitians, doctors) + "Add team member".
/// Same calls as the app: GET /admin/getTeamMember, POST /admin/addTeamMember.
class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

/// Role values exactly as the app sends them, with friendly labels.
const List<MapEntry<String, String>> kTeamRoles = [
  MapEntry('Dietition', 'Dietitian'),
  MapEntry('Trainer', 'Trainer'),
  MapEntry('Gynecologist', 'Gynecologist'),
  MapEntry('Psychiatrist', 'Psychiatrist'),
  MapEntry('Customer_Support_Representative', 'Customer support'),
];

String teamRoleLabel(dynamic v) {
  final s = '${v ?? ''}';
  for (final r in kTeamRoles) {
    if (r.key.toLowerCase() == s.toLowerCase()) return r.value;
  }
  return s.replaceAll('_', ' ');
}

Color _roleColor(String v) => switch (v.toLowerCase()) {
      'trainer' => PT.green,
      'dietition' || 'dietitian' => PT.greenDark,
      'gynecologist' => PT.amber,
      'psychiatrist' => const Color(0xFF5B6FB5),
      _ => PT.sage,
    };

class _TeamPageState extends State<TeamPage> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  String _q = '';
  String _role = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final b = await PortalApi.get('/admin/getTeamMember');
    List<Map<String, dynamic>>? list;
    final d = b['data'];
    if (PortalApi.ok(b) && d is Map && d['data'] is List) {
      list = (d['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      portalToast("Couldn't load the team", sub: PortalApi.msg(b), error: true);
    }
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => const _AddMemberDialog());
    if (saved == true) _load();
  }

  List<Map<String, dynamic>> get _shown {
    final q = _q.trim().toLowerCase();
    return (_items ?? const <Map<String, dynamic>>[]).where((m) {
      if (_role.isNotEmpty && '${m['userType']}'.toLowerCase() != _role.toLowerCase()) return false;
      if (q.isEmpty) return true;
      final hay = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''} ${m['email'] ?? ''} ${m['phone'] ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Widget _cell(String text, {bool bold = false}) =>
      SelectableText(text.trim().isEmpty ? '—' : text, style: PT.t(13, w: bold ? FontWeight.w600 : FontWeight.w400));

  Widget _avatar(Map<String, dynamic> m) {
    final img = '${m['image'] ?? ''}';
    final name = '${m['firstName'] ?? ''}'.trim();
    final letter = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 16,
      backgroundColor: PT.wash,
      foregroundImage: img.isEmpty || img == 'null' ? null : NetworkImage(PortalApi.file(img)),
      child: Text(letter, style: PT.t(13, w: FontWeight.w600, c: PT.greenDark)),
    );
  }

  Widget _filters() {
    final roles = kTeamRoles.where((r) => r.key != 'Customer_Support_Representative').toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 280,
          child: TextField(
            key: const ValueKey('team_search'),
            controller: _search,
            style: PT.t(13.5),
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Search name, email or phone',
              prefixIcon: Icon(Icons.search_rounded, size: 18),
            ),
          ),
        ),
        ChoiceChip(
          label: const Text('Everyone'),
          selected: _role.isEmpty,
          onSelected: (_) => setState(() => _role = ''),
        ),
        for (final r in roles)
          ChoiceChip(
            label: Text(r.value),
            selected: _role == r.key,
            onSelected: (_) => setState(() => _role = _role == r.key ? '' : r.key),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Team',
        sub: 'Trainers, dietitians and doctors who can log in. Customer support people are added here too, '
            'but they do not show in this list.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: portalPrimary(),
            onPressed: _add,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Add team member'),
          ),
        ],
      ),
      Expanded(
        child: _loading && _items == null
            ? const Center(child: CircularProgressIndicator())
            : _items == null
                ? PortalEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load the team",
                    action: TextButton(onPressed: _load, child: const Text('Try again')),
                  )
                : _items!.isEmpty
                    ? PortalEmpty(
                        icon: Icons.groups_outlined,
                        title: 'No team members yet',
                        sub: 'Add your first trainer or dietitian.',
                        action: ElevatedButton(style: portalPrimary(), onPressed: _add, child: const Text('Add team member')),
                      )
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _filters(),
                        Expanded(
                          child: shown.isEmpty
                              ? const PortalEmpty(icon: Icons.search_off_rounded, title: 'Nobody matches')
                              : SingleChildScrollView(
                                  child: Container(
                                    decoration: PT.card(),
                                    clipBehavior: Clip.antiAlias,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(minWidth: 900),
                                        child: DataTable(
                                          headingRowColor: WidgetStateProperty.all(PT.wash),
                                          headingTextStyle: PT.t(12, w: FontWeight.w700, c: PT.sage),
                                          dataRowMinHeight: 54,
                                          dataRowMaxHeight: 64,
                                          columns: const [
                                            DataColumn(label: Text('NAME')),
                                            DataColumn(label: Text('EMAIL')),
                                            DataColumn(label: Text('PHONE')),
                                            DataColumn(label: Text('ROLE')),
                                          ],
                                          rows: shown.map((m) {
                                            final role = '${m['userType'] ?? ''}';
                                            return DataRow(cells: [
                                              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                                _avatar(m),
                                                const SizedBox(width: 10),
                                                _cell('${m['firstName'] ?? ''} ${m['lastName'] ?? ''}', bold: true),
                                              ])),
                                              DataCell(_cell('${m['email'] ?? ''}')),
                                              DataCell(_cell('${m['phone'] ?? ''}')),
                                              DataCell(StatusChip(teamRoleLabel(role), color: _roleColor(role))),
                                            ]);
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('${shown.length} of ${_items!.length} people', style: PT.t(12, c: PT.sage)),
                        ),
                      ]),
      ),
    ]);
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _role = kTeamRoles.first.key;
  bool _showPass = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String id, String label, TextEditingController c,
          {String? hint, TextInputType? type, bool password = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: ValueKey(id),
          controller: c,
          style: PT.t(13.5),
          keyboardType: type,
          obscureText: password && !_showPass,
          inputFormatters: [LengthLimitingTextInputFormatter(30), FilteringTextInputFormatter.singleLineFormatter],
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            suffixIcon: password
                ? IconButton(
                    tooltip: _showPass ? 'Hide' : 'Show',
                    onPressed: () => setState(() => _showPass = !_showPass),
                    icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                  )
                : null,
          ),
        ),
      );

  Future<void> _save() async {
    if (_first.text.isEmpty || _last.text.isEmpty || _email.text.isEmpty || _phone.text.isEmpty) {
      setState(() => _error = 'Please provide all information.');
      return;
    }
    if (!_email.text.trim().isEmail) {
      setState(() => _error = 'Please provide a valid email.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Please set a password so they can log in.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final b = await PortalApi.post('/admin/addTeamMember', {
      'firstName': _first.text,
      'lastName': _last.text,
      'email': _email.text,
      'password': _password.text,
      'phone': _phone.text,
      'userType': _role,
      'planId': null,
    });
    if (!mounted) return;
    if (PortalApi.ok(b)) {
      portalToast('Team member added', sub: PortalApi.msg(b, '${_first.text} ${_last.text}'));
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = PortalApi.msg(b);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Add team member', style: PT.t(17, w: FontWeight.w700)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                key: const ValueKey('tm_role'),
                value: _role,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Role'),
                items: kTeamRoles
                    .map((r) => DropdownMenuItem(value: r.key, child: Text(r.value, style: PT.t(13.5))))
                    .toList(),
                onChanged: _saving ? null : (v) => setState(() => _role = v ?? _role),
              ),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _field('tm_first', 'First name', _first)),
              const SizedBox(width: 10),
              Expanded(child: _field('tm_last', 'Last name', _last)),
            ]),
            _field('tm_email', 'Email', _email, hint: 'name@example.com', type: TextInputType.emailAddress),
            _field('tm_phone', 'Phone number', _phone, hint: '03XXXXXXXXX', type: TextInputType.phone),
            _field('tm_password', 'Password', _password, hint: 'They use this to log in', password: true),
            Text('They log in to the app with this email and password. A profile photo can be added later from the mobile app.',
                style: PT.t(12, c: PT.sage, h: 1.4)),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: PT.t(12.5, c: PT.red)),
            ],
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
          child: Text(_saving ? 'Adding…' : 'Add'),
        ),
      ],
    );
  }
}
