import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../data/models/consultation/dietitian_availability.dart';
import '../../../widgets/toasts.dart';
import '../../../widgets/v2/v2_bottom_sheet.dart';
import '../../../widgets/v2/v2_buttons.dart';
import 'dietitian_calendar_picker.dart';

/// Reused by:
///   • POPUP_BOOK_INITIAL_CONSULTATION   (kind = "initial")
///   • POPUP_BOOK_FOLLOWUP_CONSULTATION  (kind = "followup")
///
/// Caller threads in the dietitian + user IDs (the user's assigned
/// dietitian comes from the plan; user comes from auth). Sheet is the
/// only place that knows about the calendar picker.
class BookConsultationSheet extends StatefulWidget {
  /// Variable used for popup-state ack (dismiss / complete).
  final String popupVariable;

  /// Booking inputs threaded by the caller.
  final int dietitianId;
  final String? dietitianName;
  final int userId;
  final int userPlanId;
  final String kind; // "initial" | "followup"

  /// Set when this sheet is booking a REPLACEMENT slot for an existing
  /// appointment (the Diet-tab card's "Reschedule" button) rather than a
  /// fresh booking. After the new slot books successfully, the old
  /// appointment at this id is canceled so the user never ends up
  /// holding two active bookings at once. Best-effort: if the cancel
  /// call fails, the new booking still stands — that's the safer
  /// failure mode (never leaves the user with zero active bookings).
  final int? rescheduleAppointmentId;

  const BookConsultationSheet({
    Key? key,
    required this.popupVariable,
    required this.dietitianId,
    required this.userId,
    required this.userPlanId,
    required this.kind,
    this.dietitianName,
    this.rescheduleAppointmentId,
  }) : super(key: key);

  static Future<void> show({
    required String popupVariable,
    required int dietitianId,
    String? dietitianName,
    required int userId,
    required int userPlanId,
    required String kind,
    int? rescheduleAppointmentId,
  }) {
    return V2BottomSheet.show(
      title: rescheduleAppointmentId != null
          ? 'Reschedule your consultation'
          : (kind == 'initial'
              ? 'Book your first consultation'
              : 'Book your follow-up'),
      child: BookConsultationSheet(
        popupVariable: popupVariable,
        dietitianId: dietitianId,
        dietitianName: dietitianName,
        userId: userId,
        userPlanId: userPlanId,
        kind: kind,
        rescheduleAppointmentId: rescheduleAppointmentId,
      ),
    );
  }

  @override
  State<BookConsultationSheet> createState() => _BookConsultationSheetState();
}

class _BookConsultationSheetState extends State<BookConsultationSheet> {
  // Nullable + an explicit error, same reasoning as ProgressSubmissionSheet:
  // a Get.find() failure used to throw straight out of initState with
  // nothing to show but the loading spinner below (and unlike that
  // sheet, this one's `dismissible` defaults to true on V2BottomSheet,
  // so at least backdrop-tap/swipe still closes it — but it's still a
  // silent failure with no explanation).
  ConsultationController? _ctrl;
  String? _initError;
  bool _loading = true;
  bool _booking = false;
  DietitianAvailability? _availability;
  DietitianAvailabilitySlot? _selected;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[BookConsultationSheet] initState dietitianId=${widget.dietitianId} kind=${widget.kind}');
    try {
      _ctrl = Get.find<ConsultationController>();
    } catch (e) {
      debugPrint('[BookConsultationSheet] Get.find<ConsultationController> failed: $e');
      setState(() {
        _initError = 'Could not load this form ($e). Please close and reopen.';
        _loading = false;
      });
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    setState(() => _loading = true);
    debugPrint('[BookConsultationSheet] _load calling loadAvailability');
    // loadAvailability is bounded (15s timeout) as of this fix — this
    // call can no longer hang forever the way it used to when the
    // network stalled mid-request.
    final data = await ctrl.loadAvailability(dietitianId: widget.dietitianId);
    debugPrint('[BookConsultationSheet] _load got data=${data != null}');
    if (!mounted) return;
    setState(() {
      _availability = data;
      _loading = false;
      // Auto-select the first available slot so the CTA isn't disabled
      // on first paint — user can change with one tap.
      if (data != null) {
        _selected = data.slots.firstWhereOrNull((s) => s.available);
      }
    });
  }

  Future<void> _book() async {
    final ctrl = _ctrl;
    final s = _selected;
    if (s == null || ctrl == null) return;
    setState(() => _booking = true);
    final outcome = await ctrl.bookConsultation(
      date: s.date,
      userId: widget.userId,
      dietitianId: widget.dietitianId,
      timeSlotId: s.slotDietId ?? 0,
      userPlanId: widget.userPlanId,
      kind: widget.kind,
    );
    final ok = outcome.ok;
    // The backend updates the user's existing active booking with this
    // SAME dietitian in place rather than creating a second row (see the
    // dedup comment on createAppointment) — when that happened, the
    // returned id equals the one we're "rescheduling", so there's
    // nothing left to cancel. Only a genuinely different id (e.g. the
    // old booking was with a different dietitian) needs an explicit
    // cancel of the old row.
    if (ok &&
        widget.rescheduleAppointmentId != null &&
        outcome.appointmentId != widget.rescheduleAppointmentId) {
      await ctrl.cancelAppointment(widget.rescheduleAppointmentId!);
    }
    if (!mounted) return;
    setState(() => _booking = false);
    if (ok) {
      // Retire the popup — backend already wrote the appointment, but
      // we want the popup row marked completed so eligibility stops
      // surfacing it.
      await ctrl.completePopup(widget.popupVariable, metadata: {
        'date': s.date,
        'slotDietId': s.slotDietId,
      });
      Get.back<dynamic>();
      CustomToast.successToast(
        msg: widget.rescheduleAppointmentId != null
            ? 'Rescheduled. See you on ${s.date} at ${s.start}.'
            : 'Booked. See you on ${s.date} at ${s.start}.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '[BookConsultationSheet] build loading=$_loading initError=$_initError availability=${_availability != null}');

    if (_initError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE05C5C), size: 40),
          const SizedBox(height: 12),
          Text(
            _initError!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF7A8C78),
            ),
          ),
          const SizedBox(height: 16),
          V2SecondaryButton(label: 'Close', onPressed: () => Get.back<dynamic>()),
        ],
      );
    }

    if (_loading) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6DC55A)),
          ),
        ),
      );
    }
    if (_availability == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              "Couldn't load availability. Tap retry.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Color(0xFF7A8C78),
              ),
            ),
          ),
          V2SecondaryButton(label: 'Retry', onPressed: _load),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.dietitianName != null && widget.dietitianName!.isNotEmpty) ...[
          Text(
            'with ${widget.dietitianName}',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7A8C78),
            ),
          ),
          const SizedBox(height: 12),
        ],
        DietitianCalendarPicker(
          slots: _availability!.slots,
          selected: _selected,
          onSelect: (s) => setState(() => _selected = s),
        ),
        const SizedBox(height: 20),
        V2PrimaryButton(
          label: _selected == null
              ? 'Pick a slot'
              : 'Book ${_selected!.start ?? ''} on ${_selected!.date}',
          busy: _booking,
          onPressed: _selected == null || !_selected!.available ? null : _book,
        ),
        const SizedBox(height: 8),
        V2GhostButton(
          label: 'Maybe later',
          onPressed: _booking
              ? null
              : () {
                  _ctrl?.dismissPopup(widget.popupVariable);
                  Get.back<dynamic>();
                },
        ),
      ],
    );
  }
}
