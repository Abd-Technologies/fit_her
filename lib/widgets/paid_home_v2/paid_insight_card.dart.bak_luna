import 'package:flutter/material.dart';

import '../../data/models/home_dashboard/home_dashboard_model.dart';
import '../new_home/phase_theme.dart';

/// Dark-green insight card that sits in the cream scroll body directly
/// below the hero. Traced to the `insightCard()` helper in
/// `new screens/Home_All43_Variants.html` lines 77-86.
///
/// Visual: `#163220` bg with phase-accent border, phase-accent icon badge,
/// bold accent "FitHer AI" title + muted "· Today's insight" subtitle,
/// multi-line insight body at 62% white.
class PaidInsightCard extends StatelessWidget {
  final HomeDashboardModel dashboard;

  const PaidInsightCard({Key? key, required this.dashboard}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final insight = dashboard.insight;
    if (insight == null ||
        insight.text == null ||
        insight.text!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    // Accent resolution: prefer backend-supplied hex; on any parse error
    // fall back to the theme's phase-derived accent. Never throws.
    final themeAccent =
        PhaseTheme.forPhaseString(dashboard.cycle?.phase).insightAccent;
    final accent = _parseHex(insight.accentHex) ?? themeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF163220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withOpacity(0.16), // HTML: ${accent}28
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF163220).withOpacity(0.15),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon badge — 26×26, accent-tinted bg + border, robot icon.
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.13), // HTML: ${accent}22
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accent.withOpacity(0.20), // HTML: ${accent}33
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 14,
                  color: accent,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'FitHer AI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '· Today\'s insight',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.25),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.text!,
            // No maxLines — let long insights wrap naturally per spec.
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.62),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// Tolerant `#RRGGBB` / `#AARRGGBB` / bare 6-or-8-hex parser. Returns null
  /// on any failure — caller uses the theme accent as fallback so the
  /// widget can't crash on a bad server payload.
  static Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      var s = hex.startsWith('#') ? hex.substring(1) : hex;
      if (s.length == 6) s = 'FF$s';
      if (s.length != 8) return null;
      return Color(int.parse(s, radix: 16));
    } catch (_) {
      return null;
    }
  }
}
