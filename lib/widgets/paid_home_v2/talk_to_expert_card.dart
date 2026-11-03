import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../UI/consultation_module/booking/book_consultation_sheet.dart';
import '../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../data/controllers/diet_plan_user_controller/diet_plan_user_controller.dart';
import '../../data/controllers/home_controller/home_controller.dart';

/// "Talk to an expert" card on the paid home, above the Luna card.
/// Opens the existing consultation booking sheet.
///
/// Shows only when she has a dietitian on her plan and no call is already
/// booked (pending, confirmed or live). The green line uses her
/// dietitian's real free slots: "Slots available today", "Next slot:
/// Tue", or "Pick a time that suits you".
class TalkToExpertCard extends StatefulWidget {
  /// Diet tab (Oct 2026): before her first consultation the card says
  /// it is how she gets her own plan (she is on the general AI plan).
  final bool forDietTab;
  const TalkToExpertCard({super.key, this.forDietTab = false});

  @override
  State<TalkToExpertCard> createState() => _TalkToExpertCardState();
}

class _TalkToExpertCardState extends State<TalkToExpertCard> {
  final _diet = Get.find<DietPlanUserController>();
  final _consult = Get.find<ConsultationController>();

  bool _ready = false;
  String _slotLine = 'Pick a time that suits you';

  // Last answer, kept while the app runs (Oct 2026). Home rebuilds this
  // card when she comes back from another screen; starting hidden until
  // the reload finished made it pop in a second later every time. Now it
  // shows straight away and quietly updates.
  static bool _everReady = false;
  static String _lastSlotLine = 'Pick a time that suits you';
  Worker? _apptWatch;
  int? _lastApptKey;

  @override
  void initState() {
    super.initState();
    _ready = _everReady;
    _slotLine = _lastSlotLine;
    _load();
    // Oct 2026: re-check when her booking changes anywhere (cancelled on
    // Home, booked from a pop-up…) so the Book card comes back right after
    // she cancels, on every tab, without reopening the screen.
    _apptWatch = ever(_consult.upcomingAppointment, (a) {
      final key = a == null ? null : Object.hash(a.id, a.status);
      if (key == _lastApptKey) return;
      _lastApptKey = key;
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _apptWatch?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _diet.loadBookingContext(refresh: true);
    if (!_ready) await _consult.loadUpcomingAppointment();
    _lastApptKey = _consult.upcomingAppointment.value == null
        ? null
        : Object.hash(_consult.upcomingAppointment.value!.id,
            _consult.upcomingAppointment.value!.status);
    final ctx = _diet.bookingContext.value;
    if (ctx != null && ctx.canBook) {
      final now = DateTime.now();
      final fmt = DateFormat('yyyy-MM-dd');
      final av = await _consult.loadAvailability(
        dietitianId: ctx.dietitianId!,
        from: fmt.format(now),
        to: fmt.format(now.add(const Duration(days: 7))),
      );
      final free = (av?.slots ?? const []).where((s) => s.available).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      if (free.isNotEmpty) {
        final first = DateTime.tryParse(free.first.date);
        if (free.first.date == fmt.format(now)) {
          _slotLine = 'Slots available today';
        } else if (first != null) {
          final tomorrow = fmt.format(now.add(const Duration(days: 1)));
          _slotLine = free.first.date == tomorrow
              ? 'Next slot: tomorrow'
              : 'Next slot: ${DateFormat('EEE').format(first)}';
        }
      }
    }
    _everReady = true;
    _lastSlotLine = _slotLine;
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _book() async {
    final ctx = _diet.bookingContext.value;
    if (ctx == null || !ctx.canBook) return;
    // Server says which consultation she can book right now; fall back
    // to the old guess only on backends without nextStep.
    final followup = ctx.nextStep != null
        ? ctx.nextStep == 'book_followup'
        : ctx.hasActivePlan;
    await BookConsultationSheet.show(
      popupVariable: followup
          ? 'POPUP_BOOK_FOLLOWUP_CONSULTATION'
          : 'POPUP_BOOK_INITIAL_CONSULTATION',
      dietitianId: ctx.dietitianId!,
      dietitianName: ctx.planPreparing?.dietitianName,
      userId: ctx.userId!,
      userPlanId: ctx.userPlanId!,
      kind: followup ? 'followup' : 'initial',
    );
    // Booked? The card hides itself once the call is on the calendar.
    await _consult.loadUpcomingAppointment();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ctx = _diet.bookingContext.value;
      final appt = _consult.upcomingAppointment.value;
      final booked = appt != null &&
          const ['pending', 'confirmed', 'In Progress'].contains(appt.status);
      // Only offer a booking the server will accept: her initial
      // consultation, or the follow-up once her Day-15 check-in is in.
      final canBookNow = ctx?.nextStep == null ||
          ctx!.nextStep == 'book_initial' ||
          ctx.nextStep == 'book_followup';
      // Plan paused: no consultations until she resumes (Oct 2026).
      final frozen = Get.isRegistered<HomeController>() &&
          Get.find<HomeController>().planFrozen.value;
      if (frozen || !_ready || ctx == null || !ctx.canBook || booked || !canBookNow) {
        return const SizedBox.shrink();
      }
      // Diet tab with no plan: the empty-state card below already offers
      // "Book a Consultation"; don't show two booking prompts.
      // Also hidden when the plan has ended or ends within 2 days: the
      // Diet tab's next-step strip / plan card has the button (Oct 2026).
      if (widget.forDietTab &&
          (_diet.activePlan.value == null ||
              _diet.planHasEnded ||
              (_diet.daysRemainingInPlan ?? 99) <= 1)) {
        return const SizedBox.shrink();
      }
      // Oct 2026: say what the call is FOR, on Home and the Diet tab.
      //   1st call  -> it's how she gets her diet plan
      //   2nd call  -> the follow-up (review + update)
      //   otherwise -> a call with her dietitian about plan, food, progress
      final first = ctx.nextStep == 'book_initial';
      final followUp = ctx.nextStep == 'book_followup';
      final title = followUp
          ? 'Book your follow-up call'
          : first
              ? 'Diet plan made for you'
              : 'Ask your dietitian';
      final sub = followUp
          ? 'Review progress, update your plan'
          : first
              ? '1:1 call · plan in 2 working days'
              : '1:1 call about food or progress';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD8EDD4), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF163220).withOpacity(0.05),
                offset: const Offset(0, 2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7E4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medical_services_outlined,
                    size: 20, color: Color(0xFF3F9B35)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF163220),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Color(0xFF6F8B7A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4AA877),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _slotLine,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4AA877),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _book,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4AA877),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Book',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
