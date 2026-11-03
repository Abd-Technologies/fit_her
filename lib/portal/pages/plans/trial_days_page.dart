import 'package:flutter/material.dart';

import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Free trial length (Oct 2026). Same calls as the app:
/// GET /admin/trialDays, POST /admin/trialDays { trialDays }.
class TrialDaysPage extends StatefulWidget {
  const TrialDaysPage({super.key});

  @override
  State<TrialDaysPage> createState() => _TrialDaysPageState();
}

class _TrialDaysPageState extends State<TrialDaysPage> {
  bool _loading = true;
  bool _saving = false;
  int _days = 3;
  int _saved = 3;
  int _min = 1;
  int _max = 14;
  int _defaultDays = 3;
  String _source = 'default';
  String? _msg;
  bool _msgOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _int(dynamic v, int fallback) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

  void _apply(Map d) {
    _saved = _int(d['trialDays'], _saved);
    _days = _saved;
    _min = _int(d['min'], _min);
    _max = _int(d['max'], _max);
    _defaultDays = _int(d['defaultDays'], _defaultDays);
    _source = '${d['source'] ?? 'default'}';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final b = await PortalApi.get('/admin/trialDays');
    if (PortalApi.ok(b) && b['data'] is Map) {
      _apply(b['data'] as Map);
      _msg = null;
    } else {
      _msgOk = false;
      _msg = PortalApi.msg(b, "Couldn't load the trial length.");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _msg = null;
    });
    final b = await PortalApi.post('/admin/trialDays', {'trialDays': _days});
    if (!mounted) return;
    if (PortalApi.ok(b) && b['data'] is Map) {
      _apply(b['data'] as Map);
      _msgOk = true;
      _msg = 'Saved. Trials are now $_saved days.';
      portalToast('Trial length saved');
    } else {
      _msgOk = false;
      _msg = PortalApi.msg(b, "Couldn't save.");
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Free trial length',
        sub: 'How many days a free trial lasts. Used for the trial end date, the trial meal plan, '
            '"your X-day trial" text and the class goal.',
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: PT.card(),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Trial days', style: PT.t(15.5, w: FontWeight.w700)),
                        const SizedBox(height: 14),
                        Row(children: [
                          IconButton.outlined(
                            onPressed: _saving || _days <= _min ? null : () => setState(() => _days--),
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text('$_days ${_days == 1 ? 'day' : 'days'}',
                                textAlign: TextAlign.center, style: PT.t(18, w: FontWeight.w700)),
                          ),
                          IconButton.outlined(
                            onPressed: _saving || _days >= _max ? null : () => setState(() => _days++),
                            icon: const Icon(Icons.add_rounded),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            style: portalPrimary(),
                            onPressed: _saving || _days == _saved ? null : _save,
                            child: _saving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Save'),
                          ),
                        ]),
                        if (_msg != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_msg!, style: PT.t(12.5, c: _msgOk ? PT.greenDark : PT.red)),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          (_source == 'admin'
                                  ? 'Set here. '
                                  : 'Not set here yet, using the server default ($_defaultDays days). ') +
                              'Allowed: $_min to $_max days. Applies to new trials and women already on a trial; '
                              'meal plans already made keep their days.',
                          style: PT.t(12, c: PT.sage, h: 1.45),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
      ),
    ]);
  }
}
