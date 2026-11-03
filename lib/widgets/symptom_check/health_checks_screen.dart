import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/api_provider/api_provider.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../helper/analytics_helper.dart';
import '../../UI/auth_module/pcos/endometriosis_config.dart';
import '../../UI/auth_module/pcos/generic_screening_intro.dart';
import '../../UI/auth_module/pcos/menopause_config.dart';
import '../../UI/auth_module/pcos/pcos_config.dart';
import '../../UI/auth_module/pcos/postpartum_config.dart';
import '../../UI/auth_module/pcos/screening_data.dart';
import '../../UI/auth_module/pcos/thyroid_config.dart';
import '../../values/constants.dart';

/// "Health checks" (Oct 2026): every check in one place. She picks the
/// ones she wants (one or more): PCOS, thyroid, endometriosis, menopause,
/// after-birth recovery. Each shows her last result, or "Due" for the
/// monthly check of a condition she already has.
class HealthChecksScreen extends StatefulWidget {
  const HealthChecksScreen({super.key, this.where = 'home'});
  final String where;

  @override
  State<HealthChecksScreen> createState() => _HealthChecksScreenState();
}

class _Check {
  final ScreeningConfig config;
  final String name;
  final String about;
  /// Shown blurred with "Coming soon" (Oct 2026: only PCOS is live).
  final bool comingSoon;
  const _Check(this.config, this.name, this.about, {this.comingSoon = false});
}

final _checks = <_Check>[
  _Check(pcosConfig, 'PCOS', 'Irregular periods, acne, weight gain, extra hair'),
  _Check(thyroidConfig, 'Thyroid', 'Tiredness, feeling cold, hair fall, dry skin', comingSoon: true),
  _Check(endometriosisConfig, 'Endometriosis', 'Very painful periods, pain in the lower belly', comingSoon: true),
  _Check(menopauseConfig, 'Menopause', 'Hot flushes, poor sleep, mood changes', comingSoon: true),
  _Check(postpartumConfig, 'After birth', 'Recovery, mood and energy after having a baby', comingSoon: true),
];

const _ink = Color(0xFF163220);
const _soft = Color(0xFF6F8B7A);
const _green = Color(0xFF3C9A2C);
const _amber = Color(0xFFB7791F);
const _amberBg = Color(0xFFFDF3DF);
const _red = Color(0xFFC2412D);
const _redBg = Color(0xFFFCEBE7);
const _okBg = Color(0xFFEAF6E6);

class _HealthChecksScreenState extends State<HealthChecksScreen> {
  bool _loading = true;
  final Map<String, Map<String, dynamic>> _latest = {};
  String? _known;
  bool _due = false;

  String get _token =>
      Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Get.find<ApiProvider>()
          .getData('${Constants.getHealthScreening}/summary', headers: {'accessToken': _token});
      final b = r.body;
      if (b is Map && b['status'] == '1' && b['data'] is Map) {
        final d = b['data'] as Map;
        _latest.clear();
        if (d['results'] is List) {
          for (final x in (d['results'] as List).whereType<Map>()) {
            final m = Map<String, dynamic>.from(x);
            _latest['${m['conditionType']}'] = m;
          }
        }
        final t = d['tracking'] is Map ? d['tracking'] as Map : const {};
        _known = t['known']?.toString();
        _due = t['dueThisMonth'] != false;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _take(_Check c) async {
    AnalyticsHelper.track('symptom_check_opened', {
      'from': '${widget.where}_hub',
      'screening': c.config.conditionType,
    });
    await Get.to(() => GenericScreeningIntro(config: c.config));
    if (mounted) _load();
  }

  String _date(dynamic iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    return d == null ? '' : DateFormat('d MMM').format(d);
  }

  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: fg)),
      );

  Widget _row(_Check c) {
    final key = c.config.conditionType;
    final last = _latest[key];
    final dueHere = _known == key && _due;
    Widget? chip;
    String button = 'Take check';
    if (dueHere) {
      chip = _chip('Monthly check due', _amber, _amberBg);
      button = last == null ? 'Take check' : 'Check again';
    } else if (last != null) {
      final risk = '${last['riskLevel'] ?? 'low'}';
      final when = _date(last['takenAt']);
      chip = risk == 'high'
          ? _chip('High signs · $when', _red, _redBg)
          : risk == 'moderate'
              ? _chip('Some signs · $when', _amber, _amberBg)
              : _chip('Low signs · $when', _green, _okBg);
      button = 'Check again';
    }
    // Coming soon: blurred, not tappable. A woman who already took it (or
    // whose monthly check is due) keeps using it.
    if (c.comingSoon && last == null && !dueHere) return _soon(c);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dueHere ? _amber.withOpacity(0.5) : const Color(0xFFD8EDD4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFF1F7EE), borderRadius: BorderRadius.circular(14)),
            child: Text(c.config.intro.emoji, style: const TextStyle(fontSize: 21)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.name} check',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w600, color: _ink)),
                const SizedBox(height: 2),
                Text(c.about,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, height: 1.35, color: _soft)),
                if (chip != null) ...[const SizedBox(height: 6), chip],
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _take(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: last == null || dueHere ? const Color(0xFF6DC55A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: last == null || dueHere ? null : Border.all(color: const Color(0xFFCFE7C6)),
              ),
              child: Text(button,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: last == null || dueHere ? Colors.white : _green,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _soon(_Check c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8EDD4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
              child: Opacity(
                opacity: 0.55,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: const Color(0xFFF1F7EE), borderRadius: BorderRadius.circular(14)),
                        child: Text(c.config.intro.emoji, style: const TextStyle(fontSize: 21)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${c.name} check',
                                style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w600, color: _ink)),
                            const SizedBox(height: 2),
                            Text(c.about,
                                style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 11.5, height: 1.35, color: _soft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: _ink.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 3))],
              ),
              child: Text('🔒  ${c.name} check · Coming soon',
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F2),
        elevation: 0,
        foregroundColor: _ink,
        title: const Text('Health checks',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w600, color: _ink)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF6DC55A))))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const Text(
                    'Pick any check you want. Each takes about 2 minutes, and you can take more than one.',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.45, color: _soft),
                  ),
                  const SizedBox(height: 14),
                  for (final c in _checks) _row(c),
                  const SizedBox(height: 6),
                  const Text(
                    'These checks are not a medical diagnosis. Talk to your doctor if you are worried.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _soft),
                  ),
                ],
              ),
            ),
    );
  }
}
