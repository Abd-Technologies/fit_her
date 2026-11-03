import 'package:flutter/material.dart';

import '../portal_api.dart';
import '../portal_theme.dart';
import '../shell/portal_nav.dart';

/// Admin Dashboard (Oct 2026): what needs the admin now, same as the
/// app's admin home buttons. Each button opens its page. Hidden when 0.
///   payments to confirm  → AI-approved slips (48 h money check)
///   slips to approve     → slips the AI could not approve
///   emergency days       → a dietitian's 3rd+ emergency day this month
class AdminAlertsBar extends StatefulWidget {
  const AdminAlertsBar({super.key});

  @override
  State<AdminAlertsBar> createState() => _AdminAlertsBarState();
}

class _AdminAlertsBarState extends State<AdminAlertsBar> {
  int _toConfirm = 0;
  int _toApprove = 0;
  int _emergency = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static List _list(dynamic d, String key) {
    if (d is List) return d;
    if (d is Map && d[key] is List) return d[key] as List;
    return const [];
  }

  Future<void> _load() async {
    final r = await Future.wait([
      PortalApi.get('/admin/payment-checks'),
      PortalApi.get('/admin/getAllPlanImages'),
      PortalApi.get('/emergency-day/awaiting'),
    ]);
    if (!mounted) return;
    setState(() {
      _toConfirm = PortalApi.ok(r[0])
          ? _list(r[0]['data'], 'items').whereType<Map>().where((e) => e['status'] == 'pending').length
          : 0;
      _toApprove = PortalApi.ok(r[1]) ? _list(r[1]['data'], 'data').length : 0;
      _emergency = PortalApi.ok(r[2]) ? _list(r[2]['data'], 'items').length : 0;
    });
  }

  Widget _btn(String text, IconData icon, Color color, String goKey) => Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => portalGo(goKey),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(text, style: PT.t(13.5, w: FontWeight.w700, c: color)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ]),
          ),
        ),
      );

  String _n(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    if (_toConfirm == 0 && _toApprove == 0 && _emergency == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(spacing: 10, runSpacing: 10, children: [
        if (_toConfirm > 0)
          _btn('${_n(_toConfirm, 'payment')} to confirm', Icons.verified_outlined, PT.red, 'payment_checks'),
        if (_toApprove > 0)
          _btn('${_n(_toApprove, 'slip')} to approve', Icons.receipt_long_outlined, PT.amber, 'slips'),
        if (_emergency > 0)
          _btn('${_n(_emergency, 'emergency day')} to approve', Icons.event_busy_outlined, PT.red, 'emergency_days'),
      ]),
    );
  }
}
