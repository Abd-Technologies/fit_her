import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/controllers/motivation_controller/motivation_controller.dart';
import '../../data/models/home_dashboard/home_dashboard_model.dart';
import '../../helper/analytics_helper.dart';
import '../../utils/app_clock.dart';
import '../../utils/slot_input_builder.dart'
    show parseSlotWallClock, minutesUntilStart;
import '../../utils/slot_ui_state.dart';
import '../app_bar_widget.dart';
import '../new_home/phase_theme.dart';

/// H-01 LIVE section.
///
/// Ported from the Workout Schedule screen's "STARTING SOON → LIVE" card
/// (see work_out_bottom_screen.dart's _buildLiveCard + lib/utils/slot_ui_state.dart)
/// so the home screen no longer needs a trainer to manually flip a slot to
/// "In Progress" before showing anything.
///
/// This widget still calls the shared [resolveSlotUIState] resolver for the
/// things it's authoritative on -- cancelled, the actual joinable/blocked
/// gate, and "the class is over" -- so Home can never disagree with the
/// Workout Schedule screen about whether a class is cancelled or genuinely
/// joinable. But the *pre-join* lifecycle Shaista asked for here (a
/// "Confirmed" status well before class, then a "Get ready" step once the
/// trainer's added the link and we're close to start, and finally "Live"
/// only once she taps "In Progress" from her panel) is specific to this
/// card's design and isn't something the schedule screen has adopted, so
/// it's computed locally in this file rather than added to the shared
/// resolver. That keeps this redesign from silently changing the Workout
/// Schedule screen's look too -- if that's wanted later, say so and this
/// logic can move into slot_ui_state.dart for both screens to share.
///
/// Phases, matching `Home_All43_Variants.html` CAT 2 where a mockup state
/// exists, plus three new pre-join states the mockup never designed for:
///   - cancelled       -- trainer cancelled the slot. No mockup state; own
///                        neutral "Cancelled" look, no button.
///   - confirmed        -- more than [_kGetReadyLeadMinutes] before start.
///                        No mockup state; own "Confirmed" look, no button
///                        (the class is scheduled and on -- nothing to do
///                        yet).
///   - waitingForLink   -- within [_kGetReadyLeadMinutes] of start (or
///                        already inside the class window) but the trainer
///                        hasn't added the Zoom link yet. Old grey-button
///                        "Trainer is setting up" look.
///   - getReady (H-06)  -- within [_kGetReadyLeadMinutes] of start (or
///                        inside the window) AND the trainer's link is up,
///                        but she hasn't tapped "In Progress" yet. Green
///                        ghost "Get ready" button.
///   - live, H-05        -- she tapped "In Progress": actually joinable,
///                        more than [_kNearEndMinutes] left.
///   - live, H-09        -- joinable, [_kNearEndMinutes] or less left
///                        ("Rejoin" + green "IN SESSION" pill).
///   - liveBlocked        -- joinable per the trainer, but this user is
///                        frozen/expired. Old grey-button look with the
///                        specific block-reason toast.
///
/// Title splits on the FIRST space: first word in bold #fff, rest muted.
/// A single-word title (e.g., "Yoga") renders all-bold with no muted suffix.
/// (H-09 is the one exception -- the mockup renders its title as a single
/// solid-bold string with no split, so that phase skips the split.)
class PaidHeroLiveSection extends StatefulWidget {
  final LiveClass? live;
  final PhaseTheme theme;
  // Frozen-plan awareness (architecture item #2): the backend already
  // refuses to let a frozen user join a live class (findFrozenActivePlan
  // gate in AdminController's join endpoint) -- this just makes the
  // button stop lying about it before the tap, instead of showing a live
  // "Join" CTA that only fails after the user taps it. Defaults to false
  // so nothing changes for any existing caller that doesn't pass it.
  final bool isFrozen;

  const PaidHeroLiveSection({
    Key? key,
    required this.live,
    required this.theme,
    this.isFrozen = false,
  }) : super(key: key);

  @override
  State<PaidHeroLiveSection> createState() => _PaidHeroLiveSectionState();
}

enum _Phase { cancelled, confirmed, waitingForLink, getReady, live, blocked }

class _PaidHeroLiveSectionState extends State<PaidHeroLiveSection> {
  // Local clock tick so a state that flips purely because of elapsed time
  // (e.g. "Confirmed" -> "Get ready", "LIVE" -> "IN SESSION") repaints
  // without waiting on the next network refresh. Same 30s cadence
  // PaidHeroComingUp already uses for its own countdown pills.
  Timer? _ticker;

  // Once a live class has this many minutes or fewer left, the card
  // switches from H-05's "Live now" look to H-09's "In progress" look
  // (green "IN SESSION" pill, "{M} min remaining", "Rejoin" button).
  static const int _kNearEndMinutes = 10;

  // How close to start (or already inside the window) before the card
  // moves on from "Confirmed" to "Get ready"/"trainer is setting up".
  static const int _kGetReadyLeadMinutes = 10;

  static const Color _readyGreen = Color(0xFF6DC55A);
  static const Color _liveRed = Color(0xFFE24B4A);
  static const Color _amber = Color(0xFFFAC775);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.live;
    if (l == null) return const SizedBox.shrink();

    // Anchor the slot's wall-clock start/end strings to today -- live
    // classes are always today's occurrence. If either fails to parse
    // (unexpected format from the backend), fall back to the old, simpler
    // "only show when explicitly In Progress" behavior rather than
    // crashing or guessing.
    final today = AppClock.now();
    final anchor = DateTime(today.year, today.month, today.day);
    final start = parseSlotWallClock(l.start, anchor);
    final end = parseSlotWallClock(l.end, anchor);
    if (start == null || end == null) {
      if (l.status != 'In Progress') return const SizedBox.shrink();
      return _legacyCard(l);
    }

    final now = AppClock.now();
    final state = resolveSlotUIState(
      slot: SlotInput(
        status: l.status,
        start: start,
        end: end,
        trainerLink: l.trainerLink,
      ),
      now: now,
      user: UserAccessInput(
        isFrozen: widget.isFrozen,
        // Home doesn't currently thread plan-remaining-days into this
        // widget (only the freeze flag) -- treat as not-expired so
        // behavior matches the pre-port version, which never gated on
        // expiry here either. Freezing is still fully honored below.
        remainingDays: widget.isFrozen ? 0 : 999,
      ),
    );

    // Hide only once the class has genuinely concluded. The backend only
    // ever sends a slot as `live` while today's occurrence is still
    // upcoming or inside its window, so these three should be rare in
    // practice -- kept as a defensive fallback, not the normal path.
    if (state == SlotUIState.past ||
        state == SlotUIState.endedNotAttended ||
        state == SlotUIState.endedEarly) {
      return const SizedBox.shrink();
    }

    final bool isCancelled = state == SlotUIState.cancelled;
    final bool isTrulyLive = state == SlotUIState.liveReady;
    final bool isBlocked = state == SlotUIState.liveBlocked;
    final bool hasLink = (l.trainerLink ?? '').trim().isNotEmpty;
    // True from `_kGetReadyLeadMinutes` before start all the way through
    // the rest of the class window -- once reached, it stays true, so
    // "Get ready" / "trainer is setting up" persists through any gap
    // between class time arriving and the trainer actually tapping
    // "In Progress", instead of the card going blank or reverting.
    final bool closeEnough =
        !now.isBefore(start.subtract(const Duration(minutes: _kGetReadyLeadMinutes)));

    final _Phase phase;
    if (isCancelled) {
      phase = _Phase.cancelled;
    } else if (isTrulyLive) {
      phase = _Phase.live;
    } else if (isBlocked) {
      phase = _Phase.blocked;
    } else if (!closeEnough) {
      phase = _Phase.confirmed;
    } else if (hasLink) {
      phase = _Phase.getReady;
    } else {
      phase = _Phase.waitingForLink;
    }

    final presentation = presentationForState(
      state,
      minutesUntilStart: null,
      blockReason:
          widget.isFrozen ? SlotBlockReason.frozen : SlotBlockReason.expired,
    );

    // Real time math off the already-parsed start/end, not a backend
    // field -- always in sync with the 30s ticker above rather than
    // whatever the last dashboard fetch happened to compute.
    final int elapsedMinutes = max(0, now.difference(start).inMinutes);
    final int remainingMinutes = max(0, end.difference(now).inMinutes);
    final bool hasStarted = !now.isBefore(start);

    final isNearEnd = phase == _Phase.live && remainingMinutes <= _kNearEndMinutes;

    // ── pill ─────────────────────────────────────────────────────────
    late final Color pillColor;
    late final String pillLabel;
    late final Color pillTextColor;
    late final bool showPillDot;
    switch (phase) {
      case _Phase.cancelled:
        pillColor = Colors.white24;
        pillLabel = 'CANCELLED';
        pillTextColor = Colors.white;
        showPillDot = false;
        break;
      case _Phase.confirmed:
        pillColor = _readyGreen.withOpacity(0.2);
        pillLabel = 'CONFIRMED';
        pillTextColor = _readyGreen;
        showPillDot = false;
        break;
      case _Phase.live:
        if (isNearEnd) {
          pillColor = _readyGreen.withOpacity(0.2);
          pillLabel = 'IN SESSION';
          pillTextColor = _readyGreen;
        } else {
          pillColor = _liveRed;
          pillLabel = 'LIVE';
          pillTextColor = Colors.white;
        }
        showPillDot = true;
        break;
      case _Phase.blocked:
        pillColor = _liveRed;
        pillLabel = 'LIVE';
        pillTextColor = Colors.white;
        showPillDot = false;
        break;
      case _Phase.getReady:
      case _Phase.waitingForLink:
        if (hasStarted) {
          // Scheduled start time has technically arrived, but the
          // resolver says `state` is still liveNotReady -- the trainer
          // hasn't flipped the class to "In Progress" yet (or hasn't
          // posted the link). This used to show a red "LIVE" pill here,
          // which was wrong: LIVE is reserved for _Phase.live, i.e. the
          // real backend status, not wall-clock time. Reuse the same
          // amber "not live yet" treatment as the pre-start countdown,
          // just with copy that matches where we actually are (waiting
          // on the trainer, not waiting on the clock).
          pillColor = _amber;
          pillLabel = 'GETTING READY';
          pillTextColor = Colors.white;
        } else {
          final mins = minutesUntilStart(start, now) ?? 0;
          pillColor = _amber;
          pillLabel = 'STARTING IN ${mins}M';
          pillTextColor = Colors.white;
        }
        showPillDot = false;
        break;
    }

    // ── status text next to the pill ────────────────────────────────
    String statusText;
    switch (phase) {
      case _Phase.cancelled:
        statusText = '';
        break;
      case _Phase.confirmed:
        statusText = 'Starts at ${DateFormat('h:mm a').format(start)}';
        break;
      case _Phase.live:
        if (isNearEnd) {
          statusText = '$elapsedMinutes min elapsed';
        } else {
          final parts = <String>[];
          if (l.participantCount != null) {
            parts.add('${l.participantCount} women');
          }
          parts.add('$elapsedMinutes min elapsed');
          statusText = parts.join(' · ');
        }
        break;
      case _Phase.blocked:
        // The button's toast already names the real reason (frozen /
        // expired) on tap -- no need to editorialize here too.
        statusText = '';
        break;
      case _Phase.waitingForLink:
        statusText = hasStarted ? 'Trainer is setting up' : '';
        break;
      case _Phase.getReady:
        // Same "meaningful, not misleading" treatment as the pill above:
        // once class time has passed but the trainer hasn't started it,
        // say so instead of staying blank.
        statusText = hasStarted ? 'Trainer is setting up' : '';
        break;
    }

    // ── title ────────────────────────────────────────────────────────
    final title = (l.classType ?? '').trim();
    final spaceIdx = title.indexOf(' ');
    final hasSuffix = spaceIdx > 0 && spaceIdx < title.length - 1;
    final firstWord = hasSuffix ? title.substring(0, spaceIdx) : title;
    final restWords = hasSuffix ? title.substring(spaceIdx + 1) : '';
    // H-09 renders the whole title as one solid-bold string, no split.
    final splitTitle = !isNearEnd;

    // ── subtitle ─────────────────────────────────────────────────────
    final subParts = <String>[];
    final trainer = (l.trainerName ?? '').trim();
    String? subtitleOverride;
    if (phase == _Phase.cancelled) {
      subtitleOverride = 'This class has been cancelled';
    } else if (phase == _Phase.live && isNearEnd) {
      subParts.add('$remainingMinutes min remaining');
      if (trainer.isNotEmpty) subParts.add(trainer);
    } else {
      if (trainer.isNotEmpty) subParts.add(trainer);
      if (l.durationMinutes != null) subParts.add('${l.durationMinutes} min');
      if (l.caloriesEstimate != null) subParts.add('${l.caloriesEstimate} kcal');
    }
    final subtitle = subtitleOverride ?? subParts.join(' · ');

    // ── button (none for cancelled / confirmed -- nothing to do yet) ──
    final bool showButton = phase != _Phase.cancelled && phase != _Phase.confirmed;
    // Countdown info row (H-06's "Starts at {time}" box) -- only while
    // there's still real time left to count down, i.e. pre-start
    // get-ready/waiting states. Once class time itself has arrived this
    // would just be stale, so it's dropped.
    final bool showInfoRow =
        (phase == _Phase.getReady || phase == _Phase.waitingForLink) && !hasStarted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showPillDot) ...[
                      const SizedBox(
                        width: 5,
                        height: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      pillLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: pillTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(
                          (phase == _Phase.live) ? 0.22 : 0.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    splitTitle
                        ? Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: hasSuffix ? '$firstWord ' : firstWord,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                    height: 1.0,
                                  ),
                                ),
                                if (hasSuffix)
                                  TextSpan(
                                    text: restWords,
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white.withOpacity(0.5),
                                      letterSpacing: -0.3,
                                      height: 1.0,
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                              height: 1.0,
                            ),
                          ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.26),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showButton) ...[
                const SizedBox(width: 14),
                _buildButton(presentation, l, phase, isNearEnd),
              ],
            ],
          ),
          if (showInfoRow) ...[
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'Starts at',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('h:mm a').format(start),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFAC775),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Button rendered off the phase computed in [build] plus the shared
  /// resolver's [SlotPresentation] for the two phases (live, blocked)
  /// where that presentation is accurate. "Get ready" / "waiting for
  /// link" aren't resolver-native states, so their label/toast/action are
  /// set directly here instead of pretending they came from
  /// [presentationForState].
  Widget _buildButton(
    SlotPresentation presentation,
    LiveClass l,
    _Phase phase,
    bool isNearEnd,
  ) {
    String label;
    Color? bg;
    Color textColor = Colors.white;
    Border? border;
    List<BoxShadow> shadow = const [];
    bool enabled = false;
    SlotButtonAction action = SlotButtonAction.none;
    String? toastMessage;

    switch (phase) {
      case _Phase.getReady:
        // H-06 "Get ready": green ghost/outline button. Not tappable into
        // the class yet -- joining is still gated on the trainer's manual
        // "In Progress" flip -- so the tap just reassures the user.
        label = 'Get ready';
        bg = _readyGreen.withOpacity(0.15);
        textColor = _readyGreen;
        border = Border.all(color: _readyGreen.withOpacity(0.3));
        enabled = true;
        action = SlotButtonAction.showToast;
        toastMessage = 'Hang tight, the trainer is about to start.';
        break;
      case _Phase.waitingForLink:
        label = 'Join';
        bg = Colors.white24;
        action = SlotButtonAction.showToast;
        toastMessage = 'Trainer is setting up, hold tight';
        break;
      case _Phase.blocked:
        // "Join" for copy parity with the live/getReady buttons --
        // presentation.buttonLabel is the resolver's generic "Join now".
        label = 'Join';
        bg = Colors.white24;
        action = presentation.action;
        toastMessage = presentation.toastMessage;
        break;
      case _Phase.live:
        label = isNearEnd ? 'Rejoin' : 'Join';
        bg = widget.theme.accent;
        enabled = true;
        action = presentation.action;
        // H-05's glow shadow; H-09's "Rejoin" has none in the mockup.
        if (!isNearEnd) {
          shadow = [
            BoxShadow(
                color: widget.theme.accent.withOpacity(0.33), blurRadius: 16),
          ];
        }
        break;
      case _Phase.cancelled:
      case _Phase.confirmed:
        // Never reached -- build() skips rendering a button for these.
        label = '';
        break;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(action, toastMessage, l),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(16),
            boxShadow: shadow,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: isNearEnd ? 13 : 14,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    SlotButtonAction action,
    String? toastMessage,
    LiveClass l,
  ) async {
    switch (action) {
      case SlotButtonAction.joinClass:
        final link = l.trainerLink ?? '';
        final id = l.slotId;
        if (link.isEmpty || id == null) return;

        await AnalyticsHelper.trackWorkoutJoinClicked(
          slotId: id.toString(),
          className: l.type,
          trainerName: l.trainerName,
          userTier: 'paid',
          linkType: link.contains('https') ? 'https_url' : 'zoom_native',
        );

        try {
          if (link.contains('https')) {
            if (Get.isRegistered<MotivationController>()) {
              await Get.find<MotivationController>().classPresenceJoin(
                slotId: id.toString(),
                className: l.type,
                trainerName: l.trainerName,
                scheduledStartTime: l.start,
              );
            }
            await launchUrl(Uri.parse(link));
          } else {
            await HelpingWidgets.startMeeting(
              link,
              id.toString(),
              className: l.type,
              trainerName: l.trainerName,
              scheduledStartTime: l.start,
            );
          }
        } catch (_) {
          HelpingWidgets.showError('Could not start the session. Please try again.');
        }
        break;
      case SlotButtonAction.showToast:
        if (toastMessage != null && toastMessage.isNotEmpty) {
          HelpingWidgets.showError(toastMessage);
        }
        break;
      case SlotButtonAction.none:
        break;
    }
  }

  /// Pre-port fallback: only used if the backend ever sends a live class
  /// whose start/end strings don't parse. Identical to the previous
  /// unconditional behavior (status must literally be "In Progress").
  Widget _legacyCard(LiveClass l) {
    final title = (l.classType ?? '').trim();
    final spaceIdx = title.indexOf(' ');
    final hasSuffix = spaceIdx > 0 && spaceIdx < title.length - 1;
    final firstWord = hasSuffix ? title.substring(0, spaceIdx) : title;
    final restWords = hasSuffix ? title.substring(spaceIdx + 1) : '';
    final statusParts = <String>[];
    if (l.participantCount != null) statusParts.add('${l.participantCount} women');
    if (l.elapsedMinutes != null) statusParts.add('${l.elapsedMinutes} min elapsed');
    final statusText = statusParts.join(' · ');
    final subParts = <String>[];
    final trainer = (l.trainerName ?? '').trim();
    if (trainer.isNotEmpty) subParts.add(trainer);
    if (l.durationMinutes != null) subParts.add('${l.durationMinutes} min');
    if (l.caloriesEstimate != null) subParts.add('${l.caloriesEstimate} kcal');
    final subtitle = subParts.join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: const BoxDecoration(
                  color: Color(0xFFE24B4A),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 5,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.22)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: hasSuffix ? '$firstWord ' : firstWord,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                              height: 1.0,
                            ),
                          ),
                          if (hasSuffix)
                            TextSpan(
                              text: restWords,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w300,
                                color: Colors.white.withOpacity(0.5),
                                letterSpacing: -0.3,
                                height: 1.0,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.26)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.isFrozen
                    ? null
                    : () {
                        final link = l.trainerLink;
                        final id = l.slotId;
                        if (link == null || link.isEmpty || id == null) return;
                        HelpingWidgets.startMeeting(link, id.toString());
                      },
                child: Opacity(
                  opacity: widget.isFrozen ? 0.45 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.theme.accent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: widget.isFrozen
                          ? const []
                          : [
                              BoxShadow(
                                color: widget.theme.accent.withOpacity(0.33),
                                blurRadius: 16,
                              ),
                            ],
                    ),
                    child: Text(
                      widget.isFrozen ? 'Paused' : 'Join',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
