import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/controllers/home_controller/home_controller.dart';
import '../../../data/controllers/motivation_controller/motivation_controller.dart';
import '../../../data/controllers/workout_controller/work_out_controller.dart';
import '../../../data/models/get_user_plan/get_workout_user_plan_details.dart';
import '../../../data/services/recommendation_service.dart';
import '../../../helper/analytics_helper.dart';
import '../../../utils/app_clock.dart';
import '../../../utils/slot_input_builder.dart';
import '../../../utils/slot_ui_state.dart';
import '../../../widgets/app_bar_widget.dart';
import '../../../widgets/circular_progress.dart';

/// Sprint 3 / S-18 — Workout Schedule timeline.
///
/// Class signature, constructor, the API call (`getDietPlanDetailsFunc`),
/// the slot tap handler (`HelpingWidgets.showWorkoutBottomSheet`),
/// pull-to-refresh, back navigation and analytics surface (none — this
/// screen never had any) are preserved exactly. Only the widget tree is
/// replaced.
class WorkOutBottomScreen extends StatefulWidget {
  const WorkOutBottomScreen({
    super.key,
    required this.planId,
    this.showBackButton = true,
  });
  final String planId;
  final bool showBackButton;

  @override
  State<WorkOutBottomScreen> createState() => _WorkOutBottomScreenState();
}

class _WorkOutBottomScreenState extends State<WorkOutBottomScreen>
    with WidgetsBindingObserver {
  // Preserved Get.find() bindings (HomeController is required by the
  // showWorkoutBottomSheet call).
  final HomeController homeController = Get.find();
  final WorkOutController workOutController = Get.find();
  final MotivationController motivationController = Get.find();

  // ── S-18 design tokens (verbatim from Sprint3_Visual.html line 30+) ──
  static const Color _bg = Color(0xFFE8F4E0);
  static const Color _textDark = Color(0xFF1A3A22);
  static const Color _textMuted = Color(0xFF7A8C78);
  static const Color _textHint = Color(0xFF9AB09A);
  static const Color _connector = Color(0xFFC8DEC4);
  static const Color _liveBgDark = Color(0xFF0D2014);
  static const Color _accent = Color(0xFF6DC55A);
  static const Color _liveRed = Color(0xFFE24B4A);
  static const Color _moderate = Color(0xFFFAC775);
  static const Color _intense = Color(0xFFFF8A8A);
  static const Color _circleBorder = Color(0xFFC8E8BC);

  // Founder-approved social-proof copy for the LIVE card. Replaces the
  // mockup's "34 women" — fake numbers undermine brand integrity. When
  // backend exposes real attendance count, swap to "$count women joined".
  static const String _liveCommunityCopy = 'Your community is here';

  late DateTime _selectedDate;
  late DateTime _weekStart; // Monday of the displayed week

  final ScrollController _timelineScrollController = ScrollController();
  final GlobalKey _activeSlotKey = GlobalKey();
  bool _hasAutoScrolled = false;

  // Step 4 sync layers — see [_kHeartbeatInterval] / [_kClockTickerInterval]
  // / [_kStaleAfter] for cadence rationale.
  Timer? _heartbeatTimer;
  Timer? _clockTickerTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // Wall-clock timestamp of the last successful heartbeat fetch. Drives
  // the "Reconnecting…" banner via [_isStale].
  DateTime? _lastContactAt;

  // In-flight guard. Without this, a slow heartbeat can be still
  // awaiting its API call when the next 30s tick (or a reconnect /
  // resume trigger) fires another one. Two concurrent fetches waste
  // bandwidth and can let a later success hide an earlier failure.
  bool _heartbeatInFlight = false;

  // Heartbeat refetches the schedule every 30s. Lighter on the eyes than
  // 60s when status flips happen mid-class.
  static const Duration _kHeartbeatInterval = Duration(seconds: 30);

  // Local-only re-evaluation of the time window so the LIVE/STARTING
  // SOON badge and "N min" countdown stay current without a network
  // call. 30s matches heartbeat for predictability.
  static const Duration _kClockTickerInterval = Duration(seconds: 30);

  // No successful contact in 60s = show banner. Two missed heartbeats.
  static const Duration _kStaleAfter = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    final now = AppClock.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _weekStart = _mondayOfWeek(_selectedDate);

    // Track schedule view
    final isTrial = homeController.isFreeTrialUser.value;
    AnalyticsHelper.trackWorkoutScheduleViewed(
      planId: widget.planId,
      userTier: isTrial ? 'free_trial' : 'paid',
      dayOfWeek: DateFormat('EEEE').format(_selectedDate),
    );

    WidgetsBinding.instance.addObserver(this);

    // Attendance stats power the past-class ✓ checkmark (per-date, not
    // per-slot — a Phase D backend ticket will add per-slot precision).
    if (motivationController.motivationStats.value == null &&
        !motivationController.isLoadingStats.value) {
      motivationController.fetchMotivationStats();
    }

    // Heartbeat — silent schedule refetch. 30s cadence catches
    // admin-side flips (start session / add link / cancel) within
    // half a minute even with the realtime socket offline.
    _heartbeatTimer = Timer.periodic(_kHeartbeatInterval, (_) => _heartbeat());

    // Clock ticker — local-only setState. Drives the LIVE/STARTING
    // SOON badge transition and the "N min" countdown. Decoupled from
    // network so we never block the UI on a stalled fetch.
    _clockTickerTimer = Timer.periodic(_kClockTickerInterval, (_) {
      if (mounted) setState(() {});
    });

    // Network reconnect trigger.
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _clockTickerTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── Step 4 sync triggers ────────────────────────────────────────────────
  // All three triggers funnel into [_heartbeat]: a silent schedule refetch
  // that updates [_lastContactAt] on success so the banner can hide.

  Future<void> _heartbeat({String reason = 'tick'}) async {
    if (!mounted || _heartbeatInFlight) return;
    _heartbeatInFlight = true;
    try {
      debugPrint('[WorkoutSchedule] heartbeat ($reason)');
      final ok = await workOutController.getDietPlanDetailsFunc(
        widget.planId,
        silent: true,
      );
      if (!mounted || !ok) return;
      setState(() => _lastContactAt = AppClock.now());
    } finally {
      _heartbeatInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foreground trigger — we may have missed many heartbeats while
    // backgrounded; refetch now so the screen is current on first
    // glance after resume.
    if (state == AppLifecycleState.resumed) {
      _hasAutoScrolled = false;
      _heartbeat(reason: 'resumed');
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final reachable = results.any(
      (r) => r != ConnectivityResult.none,
    );
    if (reachable) {
      _heartbeat(reason: 'reconnect');
    }
  }

  bool get _isStale {
    if (_lastContactAt == null) return false; // pre-first-contact, hide banner
    return AppClock.now().difference(_lastContactAt!) > _kStaleAfter;
  }

  static DateTime _mondayOfWeek(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: _bg,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _bg,
      body: Obx(() {
        if (!workOutController.workOutPlanDetailsLoad.value) {
          return const Center(child: CircularProgress());
        }
        return SafeArea(
          child: Column(
            children: [
              if (_isStale) _buildReconnectingBanner(),
              _buildHeader(),
              _buildDayStrip(),
              SizedBox(height: 12.h),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _hasAutoScrolled = false;
                    // Preserved API call — same arg, same shape.
                    workOutController.getDietPlanDetailsFunc(widget.planId,
                        forceRefresh: true);
                    if (motivationController.motivationStats.value == null &&
                        !motivationController.isLoadingStats.value) {
                      motivationController.fetchMotivationStats();
                    }
                  },
                  // Inner Obx so the timeline rebuilds when motivationStats
                  // arrives (drives the ✓ checkmark on past cards).
                  child: Obx(() {
                    // Touch motivationStats so this Obx subscribes to it.
                    motivationController.motivationStats.value;
                    return _buildTimelineScrollable();
                  }),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── "Reconnecting…" banner ─────────────────────────────────────────────
  // Shown above the header when no successful heartbeat has landed in
  // [_kStaleAfter]. Hides automatically when the next heartbeat
  // succeeds (it sets [_lastContactAt] and rebuild flips [_isStale] off).
  Widget _buildReconnectingBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      color: _moderate,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12.w,
            height: 12.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'Reconnecting…',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Header: back button + YOUR SCHEDULE title + week chevrons ──────────
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.showBackButton) ...[
            _circleButton(icon: Icons.arrow_back, onTap: () => Get.back()),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'YOUR SCHEDULE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: _textMuted,
                    letterSpacing: 0.88, // 0.08em × 11
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  DateFormat('EEEE, d MMMM').format(_selectedDate),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                    letterSpacing: -0.44, // -0.02em × 22
                  ),
                ),
              ],
            ),
          ),
          _circleButton(
            icon: Icons.chevron_left,
            onTap: () => _navigateWeek(-1),
          ),
          SizedBox(width: 6.w),
          _circleButton(
            icon: Icons.chevron_right,
            onTap: () => _navigateWeek(1),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: _circleBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: _textDark, size: 18.w),
      ),
    );
  }

  // ── Day strip: 7 weekday pills ──────────────────────────────────────────
  Widget _buildDayStrip() {
    final dates = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        children: [
          for (int i = 0; i < dates.length; i++) ...[
            Expanded(child: _buildDayPill(dates[i])),
            if (i < dates.length - 1) SizedBox(width: 5.w),
          ],
        ],
      ),
    );
  }

  Widget _buildDayPill(DateTime d) {
    final selected = _isSelected(d);
    final letter = DateFormat('E').format(d).substring(0, 1);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = DateTime(d.year, d.month, d.day);
          _hasAutoScrolled = false;
        });
        AnalyticsHelper.trackWorkoutDaySelected(
          selectedDate: DateFormat('yyyy-MM-dd').format(d),
          dayName: DateFormat('EEEE').format(d),
          isToday: _isToday(d),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 9.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: selected ? _liveBgDark : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              letter,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: selected ? _accent : _textMuted,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              '${d.day}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = AppClock.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  int _findActiveSlotIndex(List<Slot> slots) {
    if (slots.isEmpty || !_isToday(_selectedDate)) return -1;

    // 1. Any slot currently LIVE
    for (int i = 0; i < slots.length; i++) {
      if (_isLiveState(_stateFor(slots[i]))) {
        return i;
      }
    }

    // 2. First upcoming slot (soon or far)
    for (int i = 0; i < slots.length; i++) {
      final s = _stateFor(slots[i]);
      if (!_isPastState(s) &&
          s != SlotUIState.cancelled &&
          s != SlotUIState.endedEarly) {
        return i;
      }
    }

    return -1;
  }

  void _scrollToActiveSlot() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasAutoScrolled) return;
      final targetContext = _activeSlotKey.currentContext;
      if (targetContext != null) {
        _hasAutoScrolled = true;
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          alignment: 0.0,
        );
      }
    });
  }

  // ── Timeline (or empty state) ──────────────────────────────────────────
  Widget _buildTimelineScrollable() {
    final slots = _slotsForSelectedDay();
    if (slots.isEmpty) {
      // AlwaysScrollable so RefreshIndicator still works on empty days.
      return SingleChildScrollView(
        controller: _timelineScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 380.h,
          child: _buildEmptyState(),
        ),
      );
    }

    final activeIndex = _findActiveSlotIndex(slots);
    if (!_hasAutoScrolled && activeIndex > 0) {
      _scrollToActiveSlot();
    }

    return SingleChildScrollView(
      controller: _timelineScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 30.h),
      child: Column(
        children: [
          for (int i = 0; i < slots.length; i++)
            _buildTimelineRow(
              slots[i],
              isLast: i == slots.length - 1,
              key: (i == activeIndex) ? _activeSlotKey : null,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, size: 48.w, color: _connector),
            SizedBox(height: 12.h),
            Text(
              'No classes today',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Pick another day in the strip above.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.sp,
                color: _textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Single timeline row: time | dot+connector | card ───────────────────
  Widget _buildTimelineRow(Slot slot, {required bool isLast, Key? key}) {
    final state = _stateFor(slot);
    final access = buildUserAccess(homeController);
    final input = buildSlotInput(slot, _selectedDate);
    final mins = (state == SlotUIState.upcomingSoon && input != null)
        ? minutesUntilStart(input.start, AppClock.now())
        : null;
    final presentation = presentationForState(
      state,
      minutesUntilStart: mins,
      blockReason: blockReasonFor(access),
    );
    return KeyedSubtree(
      key: key,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 50.w, child: _buildTimeColumn(slot, state)),
            SizedBox(width: 14.w),
            SizedBox(width: 12.w, child: _buildDotColumn(state, isLast)),
            SizedBox(width: 14.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
                child: _buildCard(slot, state, presentation),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // States below are grouped only for VISUAL purposes — the resolver
  // already drove the decision; these helpers just paint accordingly.
  bool _isLiveState(SlotUIState s) =>
      s == SlotUIState.liveReady ||
      s == SlotUIState.liveNotReady ||
      s == SlotUIState.liveBlocked;

  bool _isPastState(SlotUIState s) =>
      s == SlotUIState.past || s == SlotUIState.endedNotAttended;

  bool _isUpcomingState(SlotUIState s) =>
      s == SlotUIState.upcomingFar || s == SlotUIState.upcomingSoon;

  Widget _buildTimeColumn(Slot slot, SlotUIState state) {
    if (_isLiveState(state)) {
      final left = _liveMinutesLeft(slot);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 4.h),
          Text(
            'NOW',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: _liveRed,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            left != null ? '$left min' : '—',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: _liveRed,
            ),
          ),
        ],
      );
    }

    // Past, upcoming, cancelled: show the slot's start time as "10:30" + "AM".
    final parts = (slot.start).split(' ');
    final time = parts.isNotEmpty ? parts[0] : slot.start;
    final ampm = parts.length > 1 ? parts[1] : '';
    final muted = _isPastState(state) || state == SlotUIState.cancelled || state == SlotUIState.endedEarly;
    final timeColor = muted ? _textMuted : _textDark;
    final ampmColor = muted ? _textHint : _textMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 4.h),
        Text(
          time,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: timeColor,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          ampm,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: ampmColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDotColumn(SlotUIState state, bool isLast) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 4.h),
        _buildDot(state),
        Expanded(
          child: Container(
            width: 2,
            margin: EdgeInsets.symmetric(vertical: 4.h),
            color: isLast ? Colors.transparent : _connector,
          ),
        ),
      ],
    );
  }

  Widget _buildDot(SlotUIState state) {
    if (_isLiveState(state)) {
      // Red filled dot, white border, red glow ring.
      return Container(
        width: 14.w,
        height: 14.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _liveRed,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: _liveRed.withValues(alpha: 0.45),
              spreadRadius: 2,
              blurRadius: 0,
            ),
          ],
        ),
      );
    }
    if (_isPastState(state) || state == SlotUIState.endedEarly) {
      return Container(
        width: 12.w,
        height: 12.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: _accent, width: 2),
        ),
      );
    }
    // upcoming + cancelled share the neutral hollow dot.
    return Container(
      width: 12.w,
      height: 12.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _connector, width: 2),
      ),
    );
  }

  // ── Class card variants ─────────────────────────────────────────────────
  Widget _buildCard(
      Slot slot, SlotUIState state, SlotPresentation presentation) {
    if (state == SlotUIState.cancelled) return _buildCancelledCard(slot);
    if (state == SlotUIState.endedEarly) return _buildEndedEarlyCard(slot);
    if (_isPastState(state)) return _buildPastCard(slot);
    if (_isUpcomingState(state)) return _buildUpcomingCard(slot, presentation);
    return _buildLiveCard(slot, presentation);
  }

  Widget _buildPastCard(Slot slot) {
    final attended = _attendedOnSelectedDate();
    final intensity = _intensityFromSlotType(slot.type);
    final duration = _durationMinutes(slot);
    final trainer = _trainerName(slot);
    return GestureDetector(
      onTap: () => _onSlotTap(slot),
      child: Opacity(
        opacity: 0.6,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      slot.type ?? 'Class',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                  ),
                  if (attended)
                    Padding(
                      padding: EdgeInsets.only(left: 4.w),
                      child: Icon(Icons.check, size: 14.w, color: _accent),
                    ),
                ],
              ),
              SizedBox(height: 2.h),
              Text(
                _metaLine(trainer, duration, _intensityLabel(intensity)),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.sp,
                  color: _textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingCard(Slot slot, SlotPresentation presentation) {
    final intensity = _intensityFromSlotType(slot.type);
    final intensityColor = _intensityColor(intensity);
    final duration = _durationMinutes(slot);
    final trainer = _trainerName(slot);
    final showCountdown =
        presentation.appearance == SlotButtonAppearance.disabled &&
            presentation.buttonLabel != null;
    return GestureDetector(
      onTap: () => _onSlotTap(slot),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: intensityColor, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slot.type ?? 'Class',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            ),
            SizedBox(height: 2.h),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.sp,
                  color: _textMuted,
                ),
                children: [
                  TextSpan(
                    text:
                        '$trainer · ${duration != null ? "${duration}m" : "—"} · ',
                  ),
                  TextSpan(
                    text: _intensityLabel(intensity),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: intensityColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (showCountdown) ...[
              SizedBox(height: 8.h),
              _buildPresentationButton(slot, presentation, dark: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledCard(Slot slot) {
    return GestureDetector(
      onTap: () => _onSlotTap(slot),
      child: Opacity(
        opacity: 0.6,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                slot.type ?? 'Class',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: _liveRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Cancelled',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: _liveRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card shown when the trainer ended the session before the scheduled
  /// end time. Status is "Completed" but [now < slot.end], so [resolveSlotUIState]
  /// returns [SlotUIState.endedEarly]. No join button — session is over.
  Widget _buildEndedEarlyCard(Slot slot) {
    // Amber tone — distinct from the red "Cancelled" badge.
    const Color amber = Color(0xFFFF9F43);
    final trainer = _trainerName(slot);
    final duration = _durationMinutes(slot);
    final intensity = _intensityFromSlotType(slot.type);
    return GestureDetector(
      onTap: () => _onSlotTap(slot),
      child: Opacity(
        opacity: 0.7,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                slot.type ?? 'Class',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                _metaLine(trainer, duration, _intensityLabel(intensity)),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.sp,
                  color: _textMuted,
                ),
              ),
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Session ended early',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: amber,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Renders a button purely from a [SlotPresentation]. The widget makes
  // no decisions of its own — color, label, and onPressed are picked
  // straight off the struct. Add a new state in the resolver, this
  // surface follows automatically.
  Widget _buildPresentationButton(
    Slot slot,
    SlotPresentation presentation, {
    required bool dark,
  }) {
    if (presentation.appearance == SlotButtonAppearance.hidden) {
      return const SizedBox.shrink();
    }
    final isEnabled = presentation.appearance == SlotButtonAppearance.enabled;
    final bg = switch (presentation.buttonColor) {
      SlotButtonColor.accent => _accent,
      SlotButtonColor.grey =>
        dark ? Colors.white.withValues(alpha: 0.18) : _connector,
      SlotButtonColor.none => Colors.transparent,
    };
    final fg = isEnabled
        ? _liveBgDark
        : (dark ? Colors.white.withValues(alpha: 0.7) : _textMuted);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => HelpingWidgets.dispatchSlotAction(
          context: context,
          homeController: homeController,
          presentation: presentation,
          slot: slot,
          anchorDate: _selectedDate,
        ),
        child: Text(
          presentation.buttonLabel ?? '',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCard(Slot slot, SlotPresentation presentation) {
    final intensity = _intensityFromSlotType(slot.type);
    final duration = _durationMinutes(slot);
    final trainer = _trainerName(slot);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: _liveBgDark,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildLiveCardBadge(presentation),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        // Drop the social-proof copy when not actually
                        // joinable — it's misleading next to a grey button.
                        presentation.appearance == SlotButtonAppearance.enabled
                            ? _liveCommunityCopy
                            : 'Trainer is setting up',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  slot.type ?? 'Class',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -0.18,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  _metaLine(trainer, duration, _intensityLabel(intensity)),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.sp,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(height: 14.h),
                _buildPresentationButton(slot, presentation, dark: true),
              ],
            ),
          ),
          // Decorative green-glow circle, top-right corner. Painted over
          // the dark surface but BEHIND the content (drawn first in Stack).
          Positioned(
            top: -30.h,
            right: -30.w,
            child: IgnorePointer(
              child: Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Pill rendered top-left of the dark live card. Drives off the same
  // [SlotPresentation] the button uses, so it can never disagree with
  // the button's enabled state. Red "LIVE" only when the button is
  // actually joinable; otherwise an amber "STARTING SOON" pill.
  Widget _buildLiveCardBadge(SlotPresentation presentation) {
    final isLive = presentation.appearance == SlotButtonAppearance.enabled;
    final bgColor = isLive ? _liveRed : _moderate;
    final label = isLive ? 'LIVE' : 'STARTING SOON';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 5.w,
              height: 5.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 5.w),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }

  // Popup-open smart trigger: refresh just this slot's status before
  // rendering the sheet, so the in-popup button never lags the schedule
  // card. Lightweight per-slot endpoint — single round-trip. The popup
  // opens immediately; when the patch returns we call setState so any
  // freshly-flipped status reaches the bottom-sheet's button.
  void _onSlotTap(Slot slot) {
    final id = slot.id;
    workOutController.refreshSlotStatus(id).then((patch) {
      if (!mounted || patch == null) return;
      setState(() => _lastContactAt = AppClock.now());
    });
    HelpingWidgets.showWorkoutBottomSheet(
      context: context,
      slot: slot,
      homeController: homeController,
      anchorDate: _selectedDate,
    );
  }

  // ── Selection + week navigation helpers ─────────────────────────────────
  bool _isSelected(DateTime d) =>
      d.year == _selectedDate.year &&
      d.month == _selectedDate.month &&
      d.day == _selectedDate.day;

  void _navigateWeek(int direction) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * direction));
      // Keep selected weekday position relative to the new week.
      final selectedWeekdayOffset = _selectedDate.weekday - 1;
      _selectedDate = _weekStart.add(Duration(days: selectedWeekdayOffset));
      _hasAutoScrolled = false;
    });
  }

  // ── Slots for the currently-selected weekday, sorted by start time ─────
  List<Slot> _slotsForSelectedDay() {
    final plan = workOutController.getUserWorkoutPlanDetailsPlan;
    if (plan == null || plan.trainerSlots.isEmpty) return [];
    final weekdayName = DateFormat('EEEE').format(_selectedDate);
    final match = plan.trainerSlots.firstWhere(
      (ts) => ts.day == weekdayName,
      orElse: () => TrainerSlot(id: 0, day: weekdayName, slots: []),
    );
    final slots = [...match.slots];
    slots.sort((a, b) {
      final aT = parseSlotWallClock(a.start, _selectedDate);
      final bT = parseSlotWallClock(b.start, _selectedDate);
      if (aT == null && bT == null) return 0;
      if (aT == null) return 1;
      if (bT == null) return -1;
      return aT.compareTo(bT);
    });
    return slots;
  }

  // ── Resolver bridge ─────────────────────────────────────────────────────
  // The single source of truth for what the schedule should render for a
  // given slot. Both this screen and the bottom-sheet popup call into
  // `resolveSlotUIState` so they cannot disagree.
  SlotUIState _stateFor(Slot slot) {
    final input = buildSlotInput(slot, _selectedDate);
    if (input == null) return SlotUIState.upcomingFar;
    return resolveSlotUIState(
      slot: input,
      now: AppClock.now(),
      user: buildUserAccess(homeController),
    );
  }

  int? _durationMinutes(Slot slot) {
    final s = parseSlotWallClock(slot.start, _selectedDate);
    final e = parseSlotWallClock(slot.end, _selectedDate);
    if (s == null || e == null) return null;
    final mins = e.difference(s).inMinutes;
    return mins > 0 ? mins : null;
  }

  int? _liveMinutesLeft(Slot slot) {
    final e = parseSlotWallClock(slot.end, _selectedDate);
    if (e == null) return null;
    final left = e.difference(AppClock.now()).inMinutes;
    return left > 0 ? left : 0;
  }

  String _trainerName(Slot slot) {
    final t = slot.trainer;
    if (t == null) return 'Trainer';
    // ClientUser.firstName / lastName are non-nullable per the model.
    final joined = '${t.firstName} ${t.lastName}'.trim();
    return joined.isEmpty ? 'Trainer' : joined;
  }

  String _metaLine(String trainer, int? durationMin, String intensity) {
    final dur = durationMin != null ? '${durationMin}m' : '—';
    return '$trainer · $dur · $intensity';
  }

  // ── Date-level attendance ✓ ────────────────────────────────────────────
  // Per-date check (not per-slot) — Phase D backend ticket will add
  // per-slot precision. Until then, ANY past slot on a date the user
  // attended gets the ✓.
  bool _attendedOnSelectedDate() {
    final stats = motivationController.motivationStats.value;
    if (stats == null) return false;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return stats.attendanceHistory
        .any((e) => e.attended == 1 && e.date == dateStr);
  }

  // ── Intensity mapping (Gap 1, Option C — RecommendationService) ───────
  // Reuses Phase 5's RecommendationService.getSlotIntensity which maps
  // class-type strings to high/medium/low. Translation:
  //   high   → intense    (#FF8A8A)
  //   medium → moderate   (#FAC775)
  //   low    → gentle OR restorative (heuristic on type name)
  //   null   → moderate   (founder fallback for unknown types)
  _IntensityLevel _intensityFromSlotType(String? type) {
    final raw = RecommendationService.getSlotIntensity(type);
    switch (raw) {
      case 'high':
        return _IntensityLevel.intense;
      case 'medium':
        return _IntensityLevel.moderate;
      case 'low':
        final lower = (type ?? '').toLowerCase();
        if (lower.contains('restore') ||
            lower.contains('stretch') ||
            lower.contains('wind')) {
          return _IntensityLevel.restorative;
        }
        return _IntensityLevel.gentle;
      default:
        return _IntensityLevel.moderate;
    }
  }

  String _intensityLabel(_IntensityLevel l) {
    switch (l) {
      case _IntensityLevel.gentle:
        return 'gentle';
      case _IntensityLevel.moderate:
        return 'moderate';
      case _IntensityLevel.intense:
        return 'intense';
      case _IntensityLevel.restorative:
        return 'restorative';
    }
  }

  Color _intensityColor(_IntensityLevel l) {
    switch (l) {
      case _IntensityLevel.gentle:
      case _IntensityLevel.restorative:
        return _accent;
      case _IntensityLevel.moderate:
        return _moderate;
      case _IntensityLevel.intense:
        return _intense;
    }
  }
}

enum _IntensityLevel { gentle, moderate, intense, restorative }
