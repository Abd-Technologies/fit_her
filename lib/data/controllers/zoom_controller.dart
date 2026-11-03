import '../../widgets/class_feedback/class_feedback_card.dart';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

import '../../zoom_meeting.dart';
import 'motivation_controller/motivation_controller.dart';

class ZoomMeetingGetxController extends GetxController {
  final ZoomMeetingController zoomController = ZoomMeetingController();

  // State
  var isInitialized = false.obs;
  var status = 'Not initialized'.obs;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  String? _activeSlotId;
  String? _activeMeetingNumber;
  String? _activeClassName;
  String? _activeTrainerName;
  String? _activeScheduledStartTime;
  bool _presenceOpen = false;

  @override
  void onInit() {
    super.onInit();
    _eventSubscription = ZoomMeeting.events.listen(_handleZoomEvent);
    _makeTokenAndInit();
  }

  DateTime? _jwtMadeAt;

  void _makeTokenAndInit() {
    // From .env (Oct 2026), no longer written in the code.
    final sdkKey = dotenv.env['ZOOM_SDK_KEY'] ?? '';
    final sdkSecret = dotenv.env['ZOOM_SDK_SECRET'] ?? '';
    if (sdkKey.isEmpty || sdkSecret.isEmpty) {
      status.value = 'Zoom keys missing in .env';
      return;
    }
    _jwtMadeAt = DateTime.now();
    generateZoomJwt(sdkKey: sdkKey, sdkSecret: sdkSecret);
  }

  @override
  void onClose() {
    _eventSubscription?.cancel();
    super.onClose();
  }

  Future<void> initializeZoom(String jwtToken) async {
    await zoomController.initialize(jwtToken);
    isInitialized.value = zoomController.isReady;
    status.value = 'Initialized';
  }

  Future<bool> joinMeeting(
    String meetingNumber,
    String name, {
    String? slotId,
    String? className,
    String? trainerName,
    String? scheduledStartTime,
  }) async {
    status.value = 'Joining meeting...';
    // Zoom only accepts a sign-in token valid for at most 48 h. The old one
    // was made once (valid ~11 years, so Zoom refused it) — make a fresh
    // one when it's older than 12 h (or the SDK isn't ready), then give
    // the SDK a moment to sign in before joining.
    final stale = _jwtMadeAt == null ||
        DateTime.now().difference(_jwtMadeAt!) > const Duration(hours: 12) ||
        !isInitialized.value;
    if (stale) {
      _makeTokenAndInit();
      await Future.delayed(const Duration(milliseconds: 2500));
    }
    _activeSlotId = slotId;
    _activeMeetingNumber = meetingNumber;
    _activeClassName = className;
    _activeTrainerName = trainerName;
    _activeScheduledStartTime = scheduledStartTime;
    _presenceOpen = false;
    // Oct 2026: record her join as soon as she taps Join, not only when
    // the Zoom SDK reports "meeting_in". That event often never arrived,
    // so the server had no join at all and her class counted as 0
    // (Classes, trial "1 of 3", streak). The server keeps one open row
    // per class, so the later "meeting_in" call doesn't add a second one.
    if (slotId != null && slotId.isNotEmpty && Get.isRegistered<MotivationController>()) {
      try {
        await Get.find<MotivationController>().classPresenceJoin(
          slotId: slotId,
          meetingNumber: meetingNumber,
          className: className,
          trainerName: trainerName,
          scheduledStartTime: scheduledStartTime,
        );
        _presenceOpen = true; // so "left" / "failed" closes it
      } catch (_) {}
    }
    return await zoomController.joinMeeting(
      meetingNumber: meetingNumber,
      displayName: name,
      password: null,
    );
  }

  Future<void> leaveMeeting() async {
    status.value = 'Leaving meeting...';
    await zoomController.leaveMeeting();
    status.value = 'Left meeting';
  }

  Future<void> _handleZoomEvent(Map<String, dynamic> event) async {
    final eventName = event['event']?.toString() ?? '';
    final slotId = _activeSlotId;
    if (slotId == null || slotId.isEmpty) return;
    if (!Get.isRegistered<MotivationController>()) return;

    if (eventName == 'meeting_in') {
      // Already recorded when she tapped Join; just update the status.
      if (_presenceOpen) {
        status.value = 'In meeting';
        return;
      }
      _presenceOpen = true;
      status.value = 'In meeting';
      await Get.find<MotivationController>().classPresenceJoin(
        slotId: slotId,
        meetingNumber: _activeMeetingNumber,
        className: _activeClassName,
        trainerName: _activeTrainerName,
        scheduledStartTime: _activeScheduledStartTime,
      );
      return;
    }

    if (eventName == 'meeting_left' ||
        eventName == 'meeting_ended' ||
        eventName == 'meeting_failed') {
      if (!_presenceOpen) return;
      _presenceOpen = false;
      status.value = 'Left meeting';
      final reason = eventName == 'meeting_failed'
          ? 'failed'
          : (eventName == 'meeting_ended' ? 'meeting_ended' : 'completed');
      await Get.find<MotivationController>().classPresenceLeave(
        slotId: slotId,
        meetingNumber: _activeMeetingNumber,
        className: _activeClassName,
        trainerName: _activeTrainerName,
        exitReason: reason,
      );
      // Back from the class: ask for a rating right away if it's over.
      Future.delayed(const Duration(seconds: 3),
          () => ClassFeedbackController.ensure().refreshPending(force: true));
      _activeSlotId = null;
      _activeMeetingNumber = null;
      _activeClassName = null;
      _activeTrainerName = null;
      _activeScheduledStartTime = null;
    }
  }

  void generateZoomJwt({
    required String sdkKey,
    required String sdkSecret,
    // Zoom Meeting SDK: exp at most 48 h after iat (we use 24 h).
    int expiryInSeconds = 24 * 3600,
  }) {
    // A little in the past so a phone clock slightly ahead doesn't fail.
    final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 30;
    final exp = iat + expiryInSeconds;

    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final payload = {
      'appKey': sdkKey,
      'iat': iat,
      'exp': exp,
      'tokenExp': exp,
    };

    String base64UrlEncode(Object value) =>
        base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');

    final headerEncoded = base64UrlEncode(header);
    final payloadEncoded = base64UrlEncode(payload);
    final data = '$headerEncoded.$payloadEncoded';

    final hmac = Hmac(sha256, utf8.encode(sdkSecret));
    final signature = hmac.convert(utf8.encode(data));
    final signatureEncoded =
        base64Url.encode(signature.bytes).replaceAll('=', '');

    final token = '$data.$signatureEncoded';

    initializeZoom(token);
  }
}
