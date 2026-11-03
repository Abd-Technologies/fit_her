import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api_provider/api_provider.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../values/constants.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

/// Admin: free trial length (Oct 2026).
/// GET/POST /admin/trialDays. The saved value is used for every trial
/// (expiry, trial meal plan length, "your X-day trial" text, class
/// goal). Before anything is saved, .env TRIAL_DAYS (or 3) is used.
class TrialDaysScreen extends StatefulWidget {
  const TrialDaysScreen({super.key});

  @override
  State<TrialDaysScreen> createState() => _TrialDaysScreenState();
}

class _TrialDaysScreenState extends State<TrialDaysScreen> {
  static const _kInk = Color(0xFF1F2A1E);
  static const _kMuted = Color(0xFF66705F);
  static const _kGreen = Color(0xFF4C6A4B);
  static const _kBorder = Color(0xFFE3E8DF);
  static const _kRed = Color(0xFFC24A4A);

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

  String get _token =>
      Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
  ApiProvider get _api => Get.find<ApiProvider>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _int(dynamic v, int fallback) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

  void _apply(Map data) {
    _saved = _int(data['trialDays'], _saved);
    _days = _saved;
    _min = _int(data['min'], _min);
    _max = _int(data['max'], _max);
    _defaultDays = _int(data['defaultDays'], _defaultDays);
    _source = '${data['source'] ?? 'default'}';
  }

  Future<void> _load() async {
    try {
      final r = await _api.getData(Constants.adminTrialDays, headers: {'accessToken': _token});
      if (r.body is Map && r.body['status'] == '1' && r.body['data'] is Map) {
        _apply(r.body['data'] as Map);
      } else {
        _msgOk = false;
        _msg = r.body is Map ? '${r.body['message']}' : 'Could not load.';
      }
    } catch (_) {
      _msgOk = false;
      _msg = 'Could not load. Check your internet.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _msg = null;
    });
    try {
      final r = await _api.postData(Constants.adminTrialDays,
          body: {'trialDays': _days}, headers: {'accessToken': _token});
      if (r.body is Map && r.body['status'] == '1' && r.body['data'] is Map) {
        _apply(r.body['data'] as Map);
        _msgOk = true;
        _msg = '✓ Saved. Trials are now $_saved days.';
      } else {
        _msgOk = false;
        _msg = r.body is Map ? '${r.body['message']}' : 'Could not save.';
      }
    } catch (_) {
      _msgOk = false;
      _msg = 'Could not save. Check your internet.';
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) => IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(icon),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _kInk,
        title: const Text('Free Trial Length',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: FhLoader())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('How many days is the free trial?',
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15, color: _kInk)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _stepBtn(Icons.remove_rounded,
                          _saving || _days <= _min ? null : () => setState(() => _days--)),
                      SizedBox(
                        width: 110,
                        child: Column(children: [
                          Text('$_days',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 34, color: _kInk)),
                          Text(_days == 1 ? 'day' : 'days',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _kMuted)),
                        ]),
                      ),
                      _stepBtn(Icons.add_rounded,
                          _saving || _days >= _max ? null : () => setState(() => _days++)),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _saving || _days == _saved ? null : _save,
                        child: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                    if (_msg != null) ...[
                      const SizedBox(height: 10),
                      Text(_msg!,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: _msgOk ? _kGreen : _kRed)),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                Text(
                  (_source == 'admin'
                          ? 'Set here. '
                          : 'Not set here yet, using the server default ($_defaultDays days). ') +
                      'Allowed: $_min to $_max days.\n'
                      'Changes the trial end date, the trial meal plan length, '
                      '"your X-day trial" text and the class goal, for new trials and '
                      'for women already on a trial. Meal plans already made keep their days.',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, height: 1.5, color: _kMuted),
                ),
              ],
            ),
    );
  }
}
