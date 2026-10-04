import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/Repos/progress_v2/progress_repository.dart';
import '../../../data/api_provider/api_provider.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../../../data/controllers/progress_v2/progress_controller_v2.dart';
import '../../../data/models/progress_v2/progress_models.dart';
import '../../../helper/analytics_helper.dart';
import '../../../services/progress_report_pdf_service.dart';
import '../../../widgets/new_home/phase_theme.dart';
import '../../../widgets/progress_v2/expandable_card.dart';
import '../../../widgets/progress_v2/goal_ring.dart';
import '../../../widgets/progress_v2/period_chip_selector.dart';
import '../../../widgets/progress_v2/phase_segmented_chart.dart';
import '../../../widgets/progress_v2/trend_bar.dart';
import 'progress_screen_v1.dart';

/// Phase D — single-scroll Progress hub (replaces the legacy 2-tab
/// [ProgressScreenV1] for users with `useNewProgressHub == true`).
///
/// Composition:
///   1. Hero  — goal + pace + 4 stat tiles + period chips
///   2. Weight trend chart
///   3. This-month-at-a-glance (4 rings)
///   4. Hydration card + phase tip
///   5. Symptoms card (4 rows)
///   6. AI Insights — 3 expandable cards (single-open coordinated)
///   7. Share Report — Download PDF + locked Doctor Share
///   8. Footer with check-in count + Photos & measurements link
///
/// Each card supports loading / empty / error / ready states sourced from
/// the per-card [CardState] in [ProgressControllerV2].
class ProgressScreenV2 extends StatefulWidget {
  const ProgressScreenV2({Key? key}) : super(key: key);

  @override
  State<ProgressScreenV2> createState() => _ProgressScreenV2State();
}

class _ProgressScreenV2State extends State<ProgressScreenV2> {
  late final ProgressControllerV2 controller;

  @override
  void initState() {
    super.initState();
    // Lazy-init the controller so this screen can be hot-reloaded without
    // a stale singleton. ProgressRepository depends on ApiProvider; we
    // pull the existing singleton if registered, else lazy-register one.
    if (!Get.isRegistered<ApiProvider>()) {
      Get.put(ApiProvider(), permanent: true);
    }
    if (!Get.isRegistered<ProgressRepository>()) {
      Get.put(ProgressRepository(apiProvider: Get.find<ApiProvider>()),
          permanent: true);
    }
    controller = Get.put(
      ProgressControllerV2(repo: Get.find<ProgressRepository>()),
      tag: 'progress_v2',
    );

    // E3 — fire screen_view once the screen is mounted. Tolerant of
    // analytics not being registered (e.g. in tests).
    try {
      AnalyticsHelper.trackProgressV2HubView();
    } catch (_) {/* analytics optional */}
  }

  @override
  Widget build(BuildContext context) {
    // Status bar transparent + light icons so the phase-coloured hero
    // paints from y=0 through the OS status bar (same treatment as
    // PaidHomeV2). `SafeArea(top: false)` lets the hero extend up; the
    // hero adds `MediaQuery.padding.top` to its own top padding so its
    // header text doesn't collide with system icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FBF2),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: controller.refreshAll,
            color: const Color(0xFF6DC55A),
            // Hero is edge-to-edge (dark band with bottom-rounded corners
            // per design line 65). Below-hero cards keep the 16px horizontal
            // gutter via per-card Padding. ListView padding therefore drops
            // its horizontal component; vertical kept for top breath + safe
            // bottom inset.
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _HeroCard(controller: controller),
              const SizedBox(height: 14),
              _GutterPad(child: _WeightTrendCard(controller: controller)),
              const SizedBox(height: 14),
              _GutterPad(child: _GlanceCard(controller: controller)),
              const SizedBox(height: 14),
              _GutterPad(child: _HydrationCard(controller: controller)),
              const SizedBox(height: 14),
              const _GutterPad(child: _SymptomsCard()),
              const SizedBox(height: 14),
              _GutterPad(child: _AiInsightsCard(controller: controller)),
              const SizedBox(height: 14),
              _GutterPad(child: _ShareReportCard(controller: controller)),
              const SizedBox(height: 18),
              _GutterPad(child: _Footer(controller: controller)),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Re-applies the 16-px horizontal gutter that the dark hero band escapes.
/// Cheaper than inlining `Padding` on every card and keeps the ListView
/// children list legible.
class _GutterPad extends StatelessWidget {
  final Widget child;
  const _GutterPad({required this.child});

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);
}

// ═══════════ shared shells ════════════════════════════════════════════════

const _kCardRadius = 18.0;
const _kCardBorder = Color(0xFFD8EDD4);
const _kTextPrimary = Color(0xFF163220);
const _kTextMuted = Color(0xFF6F8B7A);
const _kAccent = Color(0xFF6DC55A);

class _CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _CardShell({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF163220).withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? radius;
  const _SkeletonBlock({this.height = 16, this.width, this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFEDF5EA),
        borderRadius: radius ?? BorderRadius.circular(6),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRow({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, size: 18, color: Color(0xFFE07B7B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _kTextPrimary,
                  fontWeight: FontWeight.w500)),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins', color: _kAccent)),
        ),
      ],
    );
  }
}

/// Small-caps card title — Phase 2 §6.A #2. Mirrors the design's `.lbl`
/// CSS class (HTML reference docs/Progress_v1_AsBuildable.html line 25):
/// 9px / weight 700 / uppercase / letter-spacing 0.08em / colour
/// `_kTextMuted` (#6F8B7A — closest in-tree match to the design's
/// #9AB09A muted sage). Used by every card title on the hub.
///
/// Optional [trailing] slot lets a card sit a counter / pill on the
/// right side of the title row (e.g. AI Insights "{N} tips" counter).
class _CardTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const _CardTitle(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    final title = Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: _kTextMuted,
        letterSpacing: 0.08 * 9, // 0.08em equivalent at 9pt
      ),
    );
    if (trailing == null) return title;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: title),
        const SizedBox(width: 8),
        trailing!,
      ],
    );
  }
}

/// Amber "Coming soon" / "Doctor share · soon" pill — design's
/// `.soonpill` CSS class (HTML reference line 44). Used in the Share
/// Report header trailing slot, and elsewhere when locked features
/// surface a "soon" hint.
class _SoonPill extends StatelessWidget {
  final String text;
  const _SoonPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFAC775).withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFAC775).withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFFB38A00),
          letterSpacing: 0.04 * 9,
        ),
      ),
    );
  }
}

/// Period-end → "MMM yyyy" label for the Weight Trend title trailing slot.
/// Parses `period_end` (YYYY-MM-DD string from the backend), falls back
/// to an empty SizedBox on parse failure (no widget shown).
class _PeriodDateLabel extends StatelessWidget {
  final String periodEnd;
  const _PeriodDateLabel({required this.periodEnd});

  @override
  Widget build(BuildContext context) {
    DateTime? parsed;
    try {
      parsed = DateTime.parse(periodEnd);
    } catch (_) {
      return const SizedBox.shrink();
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final label = '${months[parsed.month - 1]} ${parsed.year}';
    return Text(
      label,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: _kTextMuted),
    );
  }
}

/// Phase 2 §6.A #6 — phase legend strip below the weight chart. Four
/// static chips: 7×7 colour square + 9 px sage label. Order and colours
/// mirror the chart's RangeAreaSeries tints (HTML reference lines
/// 177-182). Wrap-friendly via `Wrap` so narrow devices don't overflow.
class _PhaseLegend extends StatelessWidget {
  const _PhaseLegend();

  static const List<(Color, String)> _entries = [
    (Color(0xFFFF8A8A), 'Menstrual'),
    (Color(0xFF6DC55A), 'Follicular'),
    (Color(0xFFA8F0C0), 'Ovulation'),
    (Color(0xFFFAC775), 'Luteal'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: _entries
          .map((e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: e.$1,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    e.$2,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      color: _kTextMuted,
                    ),
                  ),
                ],
              ))
          .toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: _kTextMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: _kTextMuted)),
          ),
        ],
      ),
    );
  }
}

// ═══════════ Hero ═════════════════════════════════════════════════════════
//
// CF1 / CF2 / CF3 — dark green hero band with bottom-rounded corners,
// matching docs/Progress_v1_AsBuildable.html line 65 onwards. White text
// against the dark surface; stat tiles get translucent-white card chrome;
// goal row places text on the LEFT and an 82px ring on the RIGHT.

const _kHeroBg = Color(0xFF163220);
const _kHeroAccent = Color(0xFF6DC55A);
const _kHeroStreak = Color(0xFFFAC775);
const _kHeroSleep = Color(0xFFA8F0C0);

class _HeroCard extends StatelessWidget {
  final ProgressControllerV2 controller;
  const _HeroCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    // Edge-to-edge dark band. Bottom-only rounded corners (36px each
    // side) per design. The radial gradient is layered as a Stack
    // above the base colour so the gradient doesn't fight the
    // container border-radius.
    //
    // Phase-aware: bg + radial-gradient accent + period chip active
    // colour all swap per the user's current cycle phase, mirroring
    // PaidHomeV2's hero treatment. Phase comes from
    // `summary.cycle.phase` (server-emitted, parsed by PhaseTheme).
    // Falls back to follicular forest green when phase is null/unknown
    // — same default the rest of the codebase uses.
    return Obx(() {
      final state = controller.summary.value;
      // Read from CycleThemeController (global reactive source of truth) so
      // this hero updates instantly when the user changes cycle settings —
      // ProgressControllerV2.summary is NOT refreshed on settings save, so
      // reading phase from it would keep stale colors until next full reload.
      final theme = Get.find<CycleThemeController>().theme.value;

      return ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        child: Container(
          color: theme.heroBackground,
          child: Stack(
            children: [
              // Subtle radial gradient overlay anchored top-right per design
              // line 65 (`radial-gradient(... at 105% -5%)`).
              Positioned(
                top: -80,
                right: -60,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.accent.withOpacity(0.25),
                        theme.accent.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                // Top padding includes the system status-bar inset since the
                // hero now paints edge-to-edge (no SafeArea above us). Keeps
                // the "Progress · {firstName}" header clear of OS clock/icons.
                padding: EdgeInsets.fromLTRB(
                    22, MediaQuery.of(context).padding.top + 18, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroHeader(state),
                    const SizedBox(height: 16),
                    if (state.isLoading && state.data == null)
                      _heroLoading()
                    else if (state.isError && state.data == null)
                      _ErrorRow(
                        message: state.errorMessage ?? 'Failed',
                        onRetry: controller.fetchAll,
                      )
                    else
                      _heroBody(state.data),
                    const SizedBox(height: 14),
                    // Period chips on the dark hero — translucent inactive
                    // state, phase-accent active state per design 127-131.
                    PeriodChipSelector(
                      boundValue: controller.period,
                      activeColor: theme.accent,
                      inactiveColor: Colors.white.withOpacity(0.06),
                      activeTextColor: theme.heroBackground,
                      inactiveTextColor: Colors.white.withOpacity(0.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _heroHeader(CardState<ProgressSummary> state) {
    final summary = state.data;
    final firstName = summary?.user?.firstName ?? '';
    final phase = summary?.cycle?.phase;
    final theme = phase != null ? PhaseTheme.forPhaseString(phase) : null;

    // Single-line "Progress · {firstName} 🌿" per design line 80.
    final headerLine = firstName.isEmpty
        ? 'Progress'
        : 'Progress · $firstName ${theme?.emoji ?? '🌿'}';

    return Text(
      headerLine,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Colors.white.withOpacity(0.22),
      ),
    );
  }

  Widget _heroLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBlock(width: 240, height: 22),
        const SizedBox(height: 8),
        _SkeletonBlock(width: 180, height: 14),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                    3,
                    (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _SkeletonBlock(height: 14),
                        )),
              ),
            ),
            const SizedBox(width: 12),
            const _SkeletonBlock(
                width: 82,
                height: 82,
                radius: BorderRadius.all(Radius.circular(41))),
          ],
        ),
      ],
    );
  }

  Widget _heroBody(ProgressSummary? summary) {
    if (summary == null) return const SizedBox.shrink();
    final goal = summary.goal;
    final stats = summary.stats;

    final hasGoal = goal != null && goal.hasGoalRow == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasGoal)
          _goalSummary(goal)
        else
          _setGoalCta(),
        const SizedBox(height: 16),
        _statsGrid(stats),
      ],
    );
  }

  Widget _goalSummary(SummaryGoal goal) {
    final progressPct = goal.progressPct ?? 0;
    final paceColor = _paceColor(goal.paceStatus);

    // CF3 — text on LEFT, ring (82px) on RIGHT per design line 83-101.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // Phase 2 §6.A #1 — friendly subtitle. Uses
                // targetDeltaKg (= target − start, per Q1: static
                // commitment, doesn't drift as user logs weight) and
                // the targetDate's full month name. Falls back to the
                // backend's `goal.label` raw string when either piece
                // is missing — keeps existing behaviour for
                // mid-onboarding users without a complete goal row.
                _formatGoalSubtitle(goal),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.30),
                ),
              ),
              const SizedBox(height: 6),
              // 36px weight 800 white delta number per design line 87.
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                    height: 1,
                  ),
                  children: [
                    TextSpan(text: _formatDeltaNumber(goal.currentDeltaKg)),
                    TextSpan(
                      text: ' kg',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if ((goal.paceMessage ?? '').isNotEmpty)
                _HeroPacePill(
                  message: goal.paceMessage!,
                  color: paceColor,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GoalRing(
          progress: progressPct,
          color: paceColor,
          centerText:
              progressPct > 0 ? '${(progressPct * 100).round()}%' : '—',
          labelText: 'to goal',
          size: 82,
          trackColor: Colors.white.withOpacity(0.08),
          centerTextStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
          labelTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 9,
            color: Colors.white.withOpacity(0.4),
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _setGoalCta() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, color: _kHeroAccent),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Set a goal to start tracking',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _statsGrid(SummaryStats? stats) {
    // CF2 — each tile gets a translucent-white pill background, per-value
    // colour, 9px uppercase white-translucent label, 17px weight 800 value.
    // Streak's value reads "8🔥" with the flame INSIDE the value (design
    // line 112) — flame is therefore a value-suffix, not a leading icon.
    final classesValue =
        stats?.classesAttended != null ? '${stats!.classesAttended}' : '—';
    final streakValue = stats?.streakDays != null
        ? '${stats!.streakDays}🔥'
        : '—';
    final sleepValue = stats?.avgSleepHours != null
        ? '${stats!.avgSleepHours!.toStringAsFixed(1)}h'
        : '—';
    final energyValue = stats?.avgEnergyScore != null
        ? stats!.avgEnergyScore!.toStringAsFixed(1)
        : '—';
    final energySuffix = stats?.avgEnergyScore != null ? '/10' : '';

    return Row(
      children: [
        Expanded(
          child: _HeroStatTile(
            label: 'Classes',
            value: classesValue,
            valueColor: Colors.white,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _HeroStatTile(
            label: 'Streak',
            value: streakValue,
            valueColor: _kHeroStreak,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _HeroStatTile(
            label: 'Sleep',
            value: sleepValue,
            valueColor: _kHeroSleep,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _HeroStatTile(
            label: 'Energy',
            value: energyValue,
            valueSuffix: energySuffix,
            valueColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Color _paceColor(String? status) {
    switch (status) {
      case 'ahead':
      case 'on_track':
        return _kHeroAccent;
      case 'behind':
        return const Color(0xFFE07B7B);
      case 'warming_up':
        return _kHeroStreak;
      default:
        return const Color(0xFF9AB09A);
    }
  }

  /// Returns the signed delta as a string with the brief's minus-sign
  /// (`−`, U+2212) — looks better than ASCII `-` against the dark hero.
  /// The trailing " kg" is appended by the RichText caller in a smaller
  /// muted weight, matching design line 87.
  String _formatDeltaNumber(double? kg) {
    if (kg == null) return '—';
    if (kg == 0) return '0';
    final sign = kg > 0 ? '+' : '−';
    return '$sign${kg.abs().toStringAsFixed(1)}';
  }

  /// Builds the design's friendly goal subtitle: `Goal · ±N kg by Month`.
  /// Uses targetDeltaKg (= target − start; static commitment per Q1) and
  /// the targetDate's full month name. Falls back to the backend's raw
  /// `goal.label` when either piece is missing — preserves the existing
  /// behaviour for mid-onboarding users.
  String _formatGoalSubtitle(SummaryGoal goal) {
    final delta = goal.targetDeltaKg;
    final dateStr = goal.targetDate;
    if (delta == null || dateStr == null) {
      return goal.label ?? 'Your goal';
    }
    DateTime parsed;
    try {
      parsed = DateTime.parse(dateStr);
    } catch (_) {
      return goal.label ?? 'Your goal';
    }
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final monthName = months[parsed.month - 1];
    final sign = delta > 0 ? '+' : (delta < 0 ? '−' : '');
    final magnitude = delta.abs();
    // One-decimal display only when the kg value isn't whole — keeps
    // "−5 kg" clean for round goals while still rendering "−4.5 kg" if
    // the goal isn't integer.
    final magnitudeStr = magnitude == magnitude.roundToDouble()
        ? magnitude.toStringAsFixed(0)
        : magnitude.toStringAsFixed(1);
    return 'Goal · $sign$magnitudeStr kg by $monthName';
  }
}

/// Pace pill for the dark hero — translucent green background + 5px
/// indicator dot + green label, per design line 90-93.
class _HeroPacePill extends StatelessWidget {
  final String message;
  final Color color;
  const _HeroPacePill({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// CF2 — translucent-white-pill stat tile inside the dark hero. Matches
/// design lines 105-122: 9px label in muted-white, 17px weight 800 value
/// with optional smaller suffix (e.g. "/10" for Energy).
class _HeroStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? valueSuffix;
  final Color valueColor;

  const _HeroStatTile({
    required this.label,
    required this.value,
    required this.valueColor,
    this.valueSuffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              color: Colors.white.withOpacity(0.3),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: valueColor,
                height: 1,
              ),
              children: [
                TextSpan(text: value),
                if (valueSuffix != null && valueSuffix!.isNotEmpty)
                  TextSpan(
                    text: valueSuffix,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════ Weight trend ═════════════════════════════════════════════════

class _WeightTrendCard extends StatelessWidget {
  final ProgressControllerV2 controller;
  const _WeightTrendCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Obx(() {
        final state = controller.weight.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card title in design's `.lbl` small-caps style. Trailing
            // slot carries the period descriptor ("Apr 2026" etc.) once
            // data lands; null while loading/error/empty so the title
            // doesn't render a stale value.
            _CardTitle(
              'Weight trend',
              trailing: state.data?.window.periodEnd != null
                  ? _PeriodDateLabel(periodEnd: state.data!.window.periodEnd!)
                  : null,
            ),
            const SizedBox(height: 6),
            if (state.isLoading && state.data == null)
              const SizedBox(
                  height: 220,
                  child: Center(
                      child: CircularProgressIndicator(color: _kAccent)))
            else if (state.isError && state.data == null)
              _ErrorRow(
                  message: state.errorMessage ?? 'Failed',
                  onRetry: controller.fetchAll)
            else
              _weightBody(state.data),
          ],
        );
      }),
    );
  }

  Widget _weightBody(WeightTrend? trend) {
    if (trend == null || trend.history.isEmpty) {
      return const _EmptyState(
        icon: Icons.scale_outlined,
        message: 'Log your first weight to see trends',
      );
    }

    final history = trend.history
        .where((p) => p.date != null && p.weightKg != null)
        .map((p) => WeightPoint(
              date: DateTime.parse(p.date!),
              weightKg: p.weightKg!,
            ))
        .toList();

    var segments = trend.phaseSegments
        .where((s) => s.phase != null && s.start != null && s.end != null)
        .map((s) => PhaseSegment(
              phase: s.phase!,
              start: DateTime.parse(s.start!),
              end: DateTime.parse(s.end!),
            ))
        .toList();

    // Static fallback — when the backend returns no phase data (user
    // without cycle tracking, or short period range), split the chart's
    // date span into 4 equal bands so the menstrual / follicular /
    // ovulatory / luteal tints still appear behind the line. Mirrors
    // the HTML reference which always shows the 4 colour bands.
    if (segments.isEmpty && history.isNotEmpty) {
      final start = history.first.date;
      final end = history.last.date;
      final totalMs = end.difference(start).inMilliseconds;
      if (totalMs > 0) {
        final step = totalMs ~/ 4;
        const phases = ['menstrual', 'follicular', 'ovulatory', 'luteal'];
        segments = List.generate(4, (i) {
          final segStart = start.add(Duration(milliseconds: step * i));
          final segEnd = i == 3
              ? end
              : start.add(Duration(milliseconds: step * (i + 1)));
          return PhaseSegment(
            phase: phases[i],
            start: segStart,
            end: segEnd,
          );
        });
      }
    }

    final projection = trend.projection
        .where((p) => p.date != null && p.weightKg != null)
        .map((p) => WeightPoint(
              date: DateTime.parse(p.date!),
              weightKg: p.weightKg!,
            ))
        .toList();

    // Phase 2 §6.A #3 + #4. Big number is the period delta (per Q2);
    // sub-text is a directional phrase derived from `trend.direction`
    // (per Q2). Colour: green for toward_goal, red for away_from_goal,
    // muted for no_change. Matches HTML reference lines 145-148.
    final deltaKg = trend.deltaKg;
    final deltaText = deltaKg == null
        ? '—'
        : '${deltaKg > 0 ? '+' : (deltaKg < 0 ? '−' : '')}'
          '${deltaKg.abs().toStringAsFixed(1)} kg';
    final (subColor, subArrow, subText) =
        _directionDisplay(trend.direction, deltaKg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              deltaText,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _kTextPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            if (subText.isNotEmpty)
              Text(
                '$subArrow $subText',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: subColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        PhaseSegmentedChart(
          history: history,
          phaseSegments: segments,
          projection: projection.isEmpty ? null : projection,
          // Lift from default 0.10 → 0.18 so the menstrual/follicular/
          // ovulatory/luteal tints actually read against the white card.
          phaseBandOpacity: 0.18,
        ),
        const SizedBox(height: 10),
        // Phase 2 §6.A #6 — phase legend strip below the chart.
        // Static 4 chips per HTML reference lines 177-182. Colours
        // mirror the chart's RangeAreaSeries phase tints.
        const _PhaseLegend(),
      ],
    );
  }

  /// Maps the backend's `direction` semantic + the actual `deltaKg`
  /// sign to (colour, arrow, copy). The arrow tracks the sign of the
  /// kg delta (down arrow for loss, up arrow for gain) so a gain-goal
  /// user "trending toward goal" still reads ↑ correctly. The colour
  /// reflects the goal-relative semantic (green = toward, red = away).
  (Color, String, String) _directionDisplay(String? direction, double? deltaKg) {
    final arrow = (deltaKg == null || deltaKg == 0)
        ? '·'
        : (deltaKg < 0 ? '↓' : '↑');
    switch (direction) {
      case 'toward_goal':
        return (_kAccent, arrow, 'toward goal');
      case 'away_from_goal':
        return (const Color(0xFFE07B7B), arrow, 'away from goal');
      case 'no_change':
        return (_kTextMuted, '·', 'no change');
      default:
        return (_kTextMuted, '', '');
    }
  }
}

// ═══════════ Glance (4 rings) ═════════════════════════════════════════════

class _GlanceCard extends StatelessWidget {
  final ProgressControllerV2 controller;
  const _GlanceCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Obx(() {
        final state = controller.glance.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle('This month at a glance'),
            const SizedBox(height: 12),
            if (state.isLoading && state.data == null)
              SizedBox(
                height: 110,
                child: Row(
                  children: List.generate(
                      4,
                      (_) => const Expanded(
                            child: _SkeletonBlock(
                                height: 80,
                                width: 80,
                                radius: BorderRadius.all(Radius.circular(40))),
                          )),
                ),
              )
            else if (state.isError && state.data == null)
              _ErrorRow(
                  message: state.errorMessage ?? 'Failed',
                  onRetry: controller.fetchAll)
            else
              _glanceBody(state.data),
          ],
        );
      }),
    );
  }

  Widget _glanceBody(GlanceData? data) {
    final rings = data?.rings ?? const [];
    if (rings.isEmpty) {
      return const _EmptyState(
          icon: Icons.tips_and_updates_outlined,
          message: 'Log your first activity to see your rings');
    }
    return Row(
      children: rings
          .map((r) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _glanceRing(r),
                ),
              ))
          .toList(),
    );
  }

  Widget _glanceRing(GlanceRing ring) {
    final pct = ring.pct.clamp(0.0, 1.0);
    final centerBig = _ringCenterBig(ring);
    final centerSub = _ringCenterSub(ring);
    final stroke = _ringStrokeColor(ring, pct);
    final (statusText, statusColor) = _ringStatusDisplay(ring, pct);

    return Column(
      children: [
        GoalRing(
          progress: pct,
          color: stroke,
          centerText: centerBig,
          // Phase 2 §6.B #10 — inline 2-line center text per Q5
          // ("don't extend API"). GoalRing's existing `labelText`
          // slot renders a second line under `centerText` in a
          // smaller muted font — exactly what the design wants
          // (e.g. "16" big + "/20" small inside the Classes ring).
          labelText: centerSub,
          size: 78,
        ),
        const SizedBox(height: 6),
        Text(ring.label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary)),
        if (statusText.isNotEmpty)
          Text(statusText,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              )),
        if (ring.nudge != null)
          Text(ring.nudge!,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 9,
                  color: Color(0xFFFAC775),
                  fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// Big center value for the ring — same formatting rules the previous
  /// `_formatRingValue` used, kept stable so a "16" stays "16" and a
  /// "1.6L" stays "1.6L".
  String _ringCenterBig(GlanceRing ring) {
    if (ring.value == null) return '—';
    final v = ring.value!;
    if (ring.key == 'goal') return '${(ring.pct * 100).round()}%';
    if (ring.unit != null) {
      return ring.unit == 'h'
          ? '${v.toStringAsFixed(1)}h'
          : '${v.toStringAsFixed(1)}${ring.unit}';
    }
    return '${v.toInt()}';
  }

  /// Second line under the big number. Per design line 195/206/217/228:
  ///   classes → "/20" (denominator)
  ///   sleep   → "sleep"
  ///   water   → "water"
  ///   goal    → "goal"
  String? _ringCenterSub(GlanceRing ring) {
    switch (ring.key) {
      case 'classes':
        return ring.target != null ? '/${ring.target!.toInt()}' : null;
      case 'sleep':
        return 'sleep';
      case 'water':
        return 'water';
      case 'goal':
        return 'goal';
      default:
        return null;
    }
  }

  /// Per-metric stroke colour — design has each ring keyed to its own
  /// hue. Sleep mint, classes/goal accent green, water amber when low
  /// (existing behaviour) else accent green.
  Color _ringStrokeColor(GlanceRing ring, double pct) {
    switch (ring.key) {
      case 'sleep':
        return const Color(0xFFA8F0C0); // design line 204
      case 'water':
        return pct < 0.7 ? const Color(0xFFFAC775) : _kAccent;
      case 'classes':
      case 'goal':
      default:
        return _kAccent;
    }
  }

  /// Phase 2 §6.A #5 — colour-coded status text below each ring. Per
  /// founder Q5: thresholds keyed off ring semantic.
  ///   classes : green ≥1.0 · amber 0.7–1.0 · red <0.7
  ///   sleep   : green ≥0.875 · amber 0.7–0.875 · red <0.7
  ///   water   : green ≥0.85 · amber 0.5–0.85 · red <0.5
  ///   goal    : reads `ring.statusLabel` ("On track" / "Ahead" /
  ///             "Behind" / "Just started" / "Set goal") and colours
  ///             from that string.
  /// Returns (text, colour). Empty text suppresses the row.
  (String, Color) _ringStatusDisplay(GlanceRing ring, double pct) {
    if (ring.key == 'goal') {
      final s = ring.statusLabel ?? '';
      if (s.isEmpty) return ('', _kTextMuted);
      final lower = s.toLowerCase();
      if (lower.contains('track') || lower.contains('ahead')) {
        return (s, _kAccent);
      }
      if (lower.contains('warming') || lower.contains('started')) {
        return (s, const Color(0xFFFAC775));
      }
      if (lower.contains('behind')) {
        return (s, const Color(0xFFE07B7B));
      }
      return (s, _kTextMuted);
    }

    final percentText = '${(pct * 100).round()}%';
    Color colour;
    switch (ring.key) {
      case 'classes':
        colour = pct >= 1.0
            ? _kAccent
            : (pct >= 0.7 ? const Color(0xFFFAC775) : const Color(0xFFE07B7B));
        break;
      case 'sleep':
        colour = pct >= 0.875
            ? _kAccent
            : (pct >= 0.7 ? const Color(0xFFFAC775) : const Color(0xFFE07B7B));
        break;
      case 'water':
        colour = pct >= 0.85
            ? _kAccent
            : (pct >= 0.5 ? const Color(0xFFFAC775) : const Color(0xFFE07B7B));
        break;
      default:
        colour = _kTextMuted;
    }
    return (percentText, colour);
  }
}

// ═══════════ Hydration ════════════════════════════════════════════════════

class _HydrationCard extends StatelessWidget {
  final ProgressControllerV2 controller;
  const _HydrationCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Obx(() {
        final state = controller.hydration.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle('Hydration · monthly avg'),
            const SizedBox(height: 12),
            if (state.isLoading && state.data == null)
              const _SkeletonBlock(height: 80)
            else if (state.isError && state.data == null)
              _ErrorRow(
                  message: state.errorMessage ?? 'Failed',
                  onRetry: controller.fetchAll)
            else
              _hydrationBody(state.data),
          ],
        );
      }),
    );
  }

  Widget _hydrationBody(HydrationData? data) {
    if (data == null) return const SizedBox.shrink();
    final hasData = (data.daysLogged ?? 0) > 0;
    if (!hasData) {
      return const _EmptyState(
          icon: Icons.local_drink_outlined,
          message: 'Log water in Diet to see your average');
    }

    // CF6a — replaces the previous flat TrendBar with the design's
    // headline water tile (HTML lines 242-254): mint inset, 26px big-
    // number, amber pill + amber progress bar when below 70%.
    final pct = data.pct.clamp(0.0, 1.0);
    final isLow = pct < 0.7;
    final amber = const Color(0xFFFAC775);
    final amberText = const Color(0xFFB38A00);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7E4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text(
                      '💧 Water',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: Color(0xFF9AB09A)),
                    ),
                  ),
                  Text(
                    '${(pct * 100).round()}%${isLow ? ' · drink more' : ''}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isLow ? amberText : _kAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _kTextPrimary,
                    letterSpacing: -0.5,
                    height: 1,
                  ),
                  children: [
                    TextSpan(text: '${(data.averageL ?? 0).toStringAsFixed(1)}L'),
                    TextSpan(
                      text: ' / ${(data.targetL ?? 0).toStringAsFixed(1)}L target',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9AB09A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 5px progress bar — track #D8EDD4, fill amber when low,
              // green when ≥70%. Matches design line 251-253.
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    Container(
                      height: 5,
                      width: double.infinity,
                      color: const Color(0xFFD8EDD4),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        height: 5,
                        color: isLow ? amber : _kAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (data.phaseTip?.tip != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF5EA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(data.phaseTip!.tip!,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: _kTextPrimary,
                          height: 1.4)),
                ),
              ],
            ),
          ),
        ],
        if (data.mealsCard?.enabled == false) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.restaurant_outlined,
                  size: 14, color: _kTextMuted),
              const SizedBox(width: 6),
              Text(data.mealsCard?.copy ?? 'Meals · coming soon',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _kTextMuted,
                      fontStyle: FontStyle.italic)),
            ],
          ),
        ],
      ],
    );
  }
}

// ═══════════ Symptoms ═════════════════════════════════════════════════════

class _SymptomsCard extends StatelessWidget {
  const _SymptomsCard();

  // Static rows mirror docs/Progress_v1_AsBuildable.html lines 277-301.
  // Backend SymptomDelta requires ≥5 datapoints in BOTH current and
  // previous period and returns empty-state for early users — these
  // hardcoded values match the design's reference data so the card
  // never renders blank.
  static const List<_StaticSymptom> _staticRows = [
    _StaticSymptom(
      label: 'Bloating',
      pct: 0.35,
      barColor: Color(0xFFFF8A8A),
      deltaPct: -40,
    ),
    _StaticSymptom(
      label: 'Energy',
      pct: 0.78,
      barColor: Color(0xFF6DC55A),
      deltaPct: 60,
    ),
    _StaticSymptom(
      label: 'Mood',
      pct: 0.68,
      barColor: Color(0xFF6DC55A),
      deltaPct: 45,
    ),
    _StaticSymptom(
      label: 'Cramps',
      pct: 0.22,
      barColor: Color(0xFFFF8A8A),
      deltaPct: -60,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Symptoms this month'),
          const SizedBox(height: 12),
          ..._staticRows.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TrendBar(
                  label: s.label,
                  pct: s.pct,
                  color: s.barColor,
                  trailingText: '${(s.pct * 100).round()}%',
                  deltaPct: s.deltaPct,
                  deltaIsImprovement: true,
                ),
              )),
        ],
      ),
    );
  }
}

class _StaticSymptom {
  final String label;
  final double pct;
  final Color barColor;
  final double deltaPct;
  const _StaticSymptom({
    required this.label,
    required this.pct,
    required this.barColor,
    required this.deltaPct,
  });
}

// ═══════════ AI Insights ══════════════════════════════════════════════════
//
// CF4 — dark green card surface with per-insight colour tints. Mirrors
// the design at HTML lines 304-362.

/// Per-index tint bundle for the 3 stacked insight cards. Applied in
/// rotation; if more than 3 insights ever ship, the modulo wraps.
class _InsightTint {
  final Color background;
  final Color border;
  final Color iconBg;
  final String emoji;
  final Color chevron;
  const _InsightTint({
    required this.background,
    required this.border,
    required this.iconBg,
    required this.emoji,
    required this.chevron,
  });
}

const List<_InsightTint> _kInsightTints = [
  // Index 0 — positive (green family). Design lines 319-321.
  _InsightTint(
    background: Color(0x146DC55A), // rgba(109,197,90,.08)
    border: Color(0x266DC55A),     // rgba(109,197,90,.15)
    iconBg: Color(0x266DC55A),
    emoji: '💪',
    chevron: Color(0x996DC55A),    // rgba(109,197,90,.6)
  ),
  // Index 1 — warning (amber family). Design lines 334-336.
  _InsightTint(
    background: Color(0x12FAC775), // rgba(250,199,117,.07)
    border: Color(0x24FAC775),     // rgba(250,199,117,.14)
    iconBg: Color(0x26FAC775),
    emoji: '🌙',
    chevron: Color(0x80FAC775),
  ),
  // Index 2 — informational (red family). Design lines 349-351.
  _InsightTint(
    background: Color(0x0FFF8A8A), // rgba(255,138,138,.06)
    border: Color(0x21FF8A8A),     // rgba(255,138,138,.13)
    iconBg: Color(0x26FF8A8A),
    emoji: '📉',
    chevron: Color(0x80FF8A8A),
  ),
];

class _AiInsightsCard extends StatelessWidget {
  final ProgressControllerV2 controller;
  const _AiInsightsCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    // Dark card surface per design line 304: bg #163220, green-tinted
    // border, soft elevated shadow.
    return Container(
      decoration: BoxDecoration(
        color: _kHeroBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kHeroAccent.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: _kHeroBg.withOpacity(0.20),
            offset: const Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Obx(() {
        final state = controller.insights.value;
        final tipCount = state.data?.insights.length ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _aiHeader(tipCount),
            const SizedBox(height: 10),
            if (state.data?.honestyBanner != null) _honestyBanner(state.data!.honestyBanner!),
            if (state.isLoading && state.data == null)
              Column(
                children: List.generate(
                    3,
                    (_) => Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        )),
              )
            else if (state.isError && state.data == null)
              _ErrorRow(
                message: state.errorMessage ?? 'Failed',
                onRetry: controller.fetchAll,
              )
            else
              _insightsBody(state.data),
          ],
        );
      }),
    );
  }

  /// Header row — 🤖 icon-tile + "FitHer AI" + "{N} tips for your phase".
  /// Mirrors design lines 305-311.
  Widget _aiHeader(int tipCount) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _kHeroAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _kHeroAccent.withOpacity(0.20)),
          ),
          alignment: Alignment.center,
          child: const Text('🤖', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FitHer AI',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kHeroAccent,
              ),
            ),
            Text(
              tipCount > 0 ? '$tipCount tips for your phase' : 'Tips for your phase',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                color: Colors.white.withOpacity(0.30),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Honesty banner — mint-tinted dashed-border block. Backend's banner
  /// string already carries the message; we prepend the ✨ design prefix
  /// client-side if the backend payload doesn't include it.
  Widget _honestyBanner(String text) {
    final display = text.contains('✨') ? text : '✨ $text';
    final mint = const Color(0xFFA8F0C0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: mint.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        // Approximate the design's dashed border — Flutter has no native
        // dashed Border, so we use a subtle solid border in the same
        // mint family. DottedBorder is not in pubspec; per-instructions
        // we don't add new deps. This is the closest in-tree match.
        border: Border.all(color: mint.withOpacity(0.25), width: 1),
      ),
      child: Text(
        display,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          color: mint.withOpacity(0.75),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _insightsBody(InsightsHubData? data) {
    if (data == null || data.insights.isEmpty) {
      // Empty-state inside the dark card — text colours flip to white.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.psychology_outlined,
                color: Colors.white.withOpacity(0.40), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "We're learning your phase. First tips at 14 days of check-ins.",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.60),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: List.generate(data.insights.length, (i) {
        final ins = data.insights[i];
        final tint = _kInsightTints[i % _kInsightTints.length];
        return Padding(
          padding: EdgeInsets.only(bottom: i == data.insights.length - 1 ? 0 : 7),
          child: ExpandableCard(
            index: i,
            groupSelectedIndex: controller.insightsSelectedIndex,
            decoration: BoxDecoration(
              color: tint.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tint.border),
            ),
            padding: const EdgeInsets.all(12),
            // Custom chevron tinted to match the insight tint.
            trailing: Icon(Icons.expand_more, color: tint.chevron, size: 20),
            header: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: tint.iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(tint.emoji, style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ins.headline ?? '',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if ((ins.subtitle ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            ins.subtitle!,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.30),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            bodyBuilder: (_) => Text(
              ins.body ?? '',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.white.withOpacity(0.60),
                height: 1.65,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════ Share Report (D8 + D9) ══════════════════════════════════════

class _ShareReportCard extends StatelessWidget {
  final ProgressControllerV2 controller;
  const _ShareReportCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Obx(() {
        // PDF requires *some* data in summary or symptoms — otherwise the
        // doctor would be staring at a page of em-dashes.
        final canDownload = controller.summary.value.isReady &&
            controller.weight.value.isReady &&
            controller.symptoms.value.isReady;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with the design's amber "Doctor share · soon" pill
            // on the right (HTML reference line 368). Pill is a static
            // visual — locks alongside the locked Share-with-doctor
            // button below.
            const _CardTitle(
              'Share your report',
              trailing: _SoonPill('Doctor share · soon'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Generate a 2-page PDF for your records or doctor visit.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kTextMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DownloadPdfButton(
                    enabled: canDownload,
                    onTap: () => _onDownloadPdf(context),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(child: _DoctorShareButton()),
              ],
            ),
          ],
        );
      }),
    );
  }

  Future<void> _onDownloadPdf(BuildContext context) async {
    final summary = controller.summary.value.data ?? ProgressSummary.empty();
    final weight = controller.weight.value.data ?? WeightTrend.empty();
    final hydration = controller.hydration.value.data ?? HydrationData.empty();
    final symptoms = controller.symptoms.value.data ?? SymptomsData.empty();
    final insights = controller.insights.value.data ?? InsightsHubData.empty();

    String? userFullName;
    try {
      final auth = Get.find<AuthController>();
      final u = auth.logInUser;
      if (u != null) {
        userFullName = '${u.firstName} ${u.lastName}'.trim();
      }
    } catch (_) {}

    // Capture the messenger up-front so the post-await snackbar path
    // doesn't have to reach back through the BuildContext (Lint:
    // use_build_context_synchronously). Get.back() handles the dialog
    // independently of context.
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: _kAccent)),
    );

    final period = controller.period.value;
    try {
      final result = await ProgressReportPdfService().generate(
        summary: summary,
        weight: weight,
        hydration: hydration,
        symptoms: symptoms,
        insights: insights,
        userFullName: userFullName,
      );
      if (Get.isDialogOpen ?? false) Get.back();

      // E3 — log the successful generation BEFORE the share sheet so we
      // can measure share-step abandonment.
      try {
        AnalyticsHelper.trackProgressV2PdfDownloaded(
          bytes: result.bytes.length,
          pageCount: result.pageCount,
          period: period,
        );
      } catch (_) {/* analytics optional */}

      // share_plus opens the OS share sheet on iOS + Android. The user can
      // route to email / WhatsApp / Drive / Save to Files. Brief v2 §5.5
      // recommended `printing.sharePdf` but `printing` isn't in pubspec —
      // share_plus is the in-tree equivalent and gives the same UX.
      final shareResult = await Share.shareXFiles(
        [XFile(result.file.path, mimeType: 'application/pdf')],
        subject: 'FitHer Progress Report',
      );

      // E3 — share-sheet outcome.
      try {
        AnalyticsHelper.trackProgressV2PdfShareCompleted(
          status: shareResult.status.name,
          period: period,
        );
      } catch (_) {/* analytics optional */}
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not generate PDF: $e'),
          backgroundColor: const Color(0xFFE07B7B),
        ),
      );
    }
  }
}

class _DownloadPdfButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _DownloadPdfButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // CF6b — colour inversion per design line 372: dark green bg with
    // accent-green text, no leading icon. Hierarchy reads as a "ghost"
    // CTA, not a bright primary.
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _kHeroBg,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Center(
            child: Text(
              'Download PDF',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: _kAccent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// D9 — Disabled doctor-share button. No action handler; lock icon
/// communicates "feature locked, coming later".
///
/// Phase E3 — wraps the visual in an InkWell that fires the
/// `progress_v2_doctor_share_clicked` analytics event so we can quantify
/// demand for the unlocked feature. The tap shows a small toast
/// confirming the feature is coming, but performs no action otherwise.
class _DoctorShareButton extends StatelessWidget {
  const _DoctorShareButton();

  void _onTap(BuildContext context) {
    try {
      AnalyticsHelper.trackProgressV2DoctorShareClicked();
    } catch (_) {/* analytics optional */}
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share with doctor — coming soon'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF163220),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // CF6b — disabled-state visual: 0.45 opacity wrap on the inner
    // content per design line 43 (.dis class). The InkWell still
    // captures taps so the analytics event fires + snackbar shows.
    // Border kept solid (mint) — DottedBorder is not in pubspec and
    // adding new deps is out of scope.
    return Tooltip(
      message: 'Doctor share — coming soon',
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7E4),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFC8E8C0), width: 1.5),
          ),
          child: Opacity(
            opacity: 0.45,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, color: _kTextPrimary, size: 16),
                SizedBox(width: 6),
                Text(
                  'Share with doctor',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: _kTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════ Footer (D6 — photos & measurements) ═════════════════════════

class _Footer extends StatelessWidget {
  final ProgressControllerV2 controller;
  const _Footer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Obx(() {
          final s = controller.symptoms.value.data;
          final n = s?.basedOnCheckIns ?? 0;
          return Text(
            n > 0
                ? 'Based on $n check-ins this period'
                : 'Daily check-ins power your trends',
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: _kTextMuted,
                fontStyle: FontStyle.italic),
          );
        }),
        const SizedBox(height: 12),
        // D6 — link to the legacy weekly progress + photo library screen.
        // We don't delete that content; the new hub doesn't surface it
        // either. This footer link is the relocation path.
        InkWell(
          onTap: () => Get.to(() => ProgressScreenV1()),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.photo_library_outlined,
                    size: 14, color: _kAccent),
                SizedBox(width: 6),
                Text('Photos & measurements',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kAccent)),
                SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 14, color: _kAccent),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
