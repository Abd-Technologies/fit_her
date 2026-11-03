import '../../../helper/pk_time.dart';

/// Returned by GET /appointment/me/current. Represents the signed-in
/// user's single most relevant consultation booking, if any — used to
/// render the "your booked consultation" card on the Diet tab
/// (Reschedule/Cancel while pending, the "Join Meeting" state machine
/// once confirmed, and a short post-completion window so the "your plan
/// will be delivered in 2 working days" message has something to show).
///
/// `null` in place of an instance means "nothing to show right now",
/// which is a normal, expected state — not an error.
class UpcomingAppointment {
  final int id;
  final String date; // YYYY-MM-DD
  final String status; // pending | confirmed | In Progress | completed
  final String? kind; // initial | followup
  final int userId;
  final int userPlanId;
  final int dietitianId;
  final String? dietitianName;
  final String? slotStart;
  final String? slotEnd;

  // The dietitian's Meet link for this slot, once she's saved one. Null
  // until then — drives the grey ("no link yet") vs. yellow ("link's in,
  // waiting for her to start") stage of the Join Meeting button.
  final String? dietitionLink;

  // True when this appointment's scheduled time has passed by more than
  // the grace window but not yet the staleness cutoff, and no no-show
  // has been reported — mirrors popupEligibility.js's
  // NO_SHOW_GRACE_MINUTES/NO_SHOW_STALE_HOURS rule (via
  // consultationBookingController.js's isAwaitingConsultant). Drives an
  // inline "consultant hasn't joined" notice on this card instead of the
  // old blocking popup.
  final bool awaitingConsultant;

  // True only when `status == 'canceled'` AND this specific
  // cancellation was caused by the dietitian never showing up (not an
  // ordinary client/dietitian-initiated cancel). Drives a dedicated
  // "your dietitian missed this session — rebook free" card state.
  final bool noShow;

  // Free days the server added to her package for that missed session.
  final int noShowBonusDays;

  // SHE (the client) missed this session; it was canceled. Drives the
  // "you missed your session" card. Never true for a dietitian no-show.
  final bool clientNoShow;

  // She has already rated this (completed) consultation.
  final bool reviewed;

  // Her dietitian cancelled this session (free days were added).
  final bool dietitianCanceled;

  // True only when `status == 'canceled'` AND this specific
  // cancellation was caused by the dietitian never confirming the
  // booking at all (as opposed to noShow, where she DID confirm but
  // never joined). Drives a dedicated "please reschedule" card state.
  final bool expired;

  // Consultation change policy (backend helper/bookingPolicy.js):
  // reschedule only until 24h before; inside 24h she can cancel only
  // while her one free late change for this package is unused.
  final bool lateChangeAvailable;

  // She missed a session after using her late change — self-booking is
  // locked until our team helps her rebook.
  final bool bookingLocked;

  // Oct 2026: confirmed but not started 10+ min after its start time;
  // the dietitian and our team were alerted (helper/dietitianLateCheck.js).
  final bool dietitianLate;

  // Oct 2026: on hold until her payment is confirmed (no join link; it
  // can't start). helper/paymentVerify.js on the server.
  final bool paymentHold;

  // Nov 2026: over and she was in it → the rating pop-up may ask her.
  final bool askReview;

  // Nov 2026: her plan was sent after this session (delivery steps done).
  final bool planDelivered;

  const UpcomingAppointment({
    required this.id,
    required this.date,
    required this.status,
    this.kind,
    required this.userId,
    required this.userPlanId,
    required this.dietitianId,
    this.dietitianName,
    this.slotStart,
    this.slotEnd,
    this.dietitionLink,
    this.awaitingConsultant = false,
    this.noShow = false,
    this.noShowBonusDays = 0,
    this.clientNoShow = false,
    this.reviewed = false,
    this.dietitianCanceled = false,
    this.expired = false,
    this.lateChangeAvailable = true,
    this.bookingLocked = false,
    this.dietitianLate = false,
    this.paymentHold = false,
    this.askReview = false,
    this.planDelivered = false,
  });

  /// Reschedule only makes sense before the dietitian has committed to
  /// the slot. Once she's confirmed it, rescheduling is off the table —
  /// the card switches to the Join Meeting flow instead — and Cancel is
  /// handled separately from this flag.
  bool get canModify => status == 'pending';

  factory UpcomingAppointment.fromJson(Map<String, dynamic> json) {
    // Nov 2026: date and times in HER phone's time (dietitians set them in
    // Pakistan time). helper/pk_time.dart.
    final pkDate = (json['date'] as String?) ?? '';
    final ls = PkTime.toLocal(pkDate, json['slotStart'] as String?);
    final le = PkTime.toLocal(pkDate, json['slotEnd'] as String?);
    return UpcomingAppointment(
      id: (json['id'] as num).toInt(),
      date: ls != null ? PkTime.ymd(ls) : pkDate,
      status: (json['status'] as String?) ?? 'pending',
      kind: json['kind'] as String?,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      userPlanId: (json['userPlanId'] as num?)?.toInt() ?? 0,
      dietitianId: (json['dietitianId'] as num?)?.toInt() ?? 0,
      dietitianName: json['dietitianName'] as String?,
      slotStart: ls != null ? PkTime.clock(ls) : json['slotStart'] as String?,
      slotEnd: le != null ? PkTime.clock(le) : json['slotEnd'] as String?,
      dietitionLink: (json['dietitionLink'] as String?)?.trim().isNotEmpty ==
              true
          ? json['dietitionLink'] as String
          : null,
      awaitingConsultant: (json['awaitingConsultant'] as bool?) ?? false,
      noShow: (json['noShow'] as bool?) ?? false,
      noShowBonusDays: (json['noShowBonusDays'] as num?)?.toInt() ?? 0,
      clientNoShow: json['clientNoShow'] == true,
      reviewed: json['reviewed'] == true,
      dietitianCanceled: json['dietitianCanceled'] == true,
      expired: (json['expired'] as bool?) ?? false,
      lateChangeAvailable: json['lateChangeAvailable'] != false,
      bookingLocked: json['bookingLocked'] == true,
      dietitianLate: json['dietitianLate'] == true,
      paymentHold: json['paymentHold'] == true,
      askReview: json['askReview'] == true,
      planDelivered: json['planDelivered'] == true,
    );
  }
}
