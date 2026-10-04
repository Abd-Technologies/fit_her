import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
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
    const sdkKey = 'hLsFMz5nRKyRXt2SUOONw';
    const sdkSecret = 'R5z8c6RmcnSRdKbvacQwrjIdMDv7lTW6';
    generateZoomJwt(sdkKey: sdkKey, sdkSecret: sdkSecret);
  }

  @override
  void onClose() {
    _eventSubscription?.cancel();
    super.onClose();
  }

  Future<void> initializeZoom(String jwtToken) async {
    await zoomController.initialize(jwtToken);
    isInitialized.value = true;
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
    _activeSlotId = slotId;
    _activeMeetingNumber = meetingNumber;
    _activeClassName = className;
    _activeTrainerName = trainerName;
    _activeScheduledStartTime = scheduledStartTime;
    _presenceOpen = false;
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
      if (_presenceOpen) return;
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
    int expiryInSeconds = 360000000,
  }) {
    final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
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
    print('Generated Zoom JWT: $token');

    initializeZoom(token);
  }
}
