import 'package:flutter/services.dart';

class ZoomMeeting {
  static const MethodChannel _channel = MethodChannel('zoom_meeting');
  static const EventChannel _events = EventChannel('zoom_meeting/events');

  /// Why the last join failed (Zoom's code/message), for analytics.
  static String? lastError;

  static Stream<Map<String, dynamic>> get events {
    return _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{"event": event.toString()};
    });
  }

  // Initialize Zoom SDK
  static Future<bool> initializeZoom(String jwtToken) async {
    try {
      final Map<String, dynamic> arguments = {
        'jwtToken': jwtToken,
      };
      final bool result =
          await _channel.invokeMethod('initializeZoom', arguments);
      return result;
    } on PlatformException catch (e) {
      print('Failed to initialize Zoom: ${e.message}');
      return false;
    }
  }

  // Check if Zoom SDK is initialized
  static Future<bool> isInitialized() async {
    try {
      final bool result = await _channel.invokeMethod('isInitialized');
      return result;
    } on PlatformException catch (e) {
      print('Failed to check initialization status: ${e.message}');
      return false;
    }
  }

  // Join a meeting
  static Future<bool> joinMeeting({
    required String meetingNumber,
    required String displayName,
    String? jwtToken,
    String? password,
  }) async {
    try {
      final Map<String, dynamic> arguments = {
        'meetingNumber': meetingNumber,
        'displayName': displayName,
        if (jwtToken != null) 'jwtToken': jwtToken,
        if (password != null) 'password': password,
      };

      lastError = null;
      final bool result = await _channel.invokeMethod('joinMeeting', arguments);
      return result;
    } on PlatformException catch (e) {
      lastError = '${e.code}: ${e.message}';
      print('Failed to join meeting: ${e.message}');
      return false;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }

  // Leave current meeting
  static Future<bool> leaveMeeting() async {
    try {
      final bool result = await _channel.invokeMethod('leaveMeeting');
      return result;
    } on PlatformException catch (e) {
      print('Failed to leave meeting: ${e.message}');
      return false;
    }
  }
}

// Example usage class
class ZoomMeetingController {
  bool _isInitialized = false;
  bool get isReady => _isInitialized;

  Future<void> initialize(String jwtToken) async {
    _isInitialized = await ZoomMeeting.initializeZoom(jwtToken);
    if (_isInitialized) {
      print('Zoom SDK initialized successfully');
    } else {
      print('Failed to initialize Zoom SDK');
    }
  }

  Future<bool> joinMeeting({
    required String meetingNumber,
    required String displayName,
    String? jwtToken,
    String? password,
  }) async {
    var success = false;
    if (!_isInitialized) {
      ZoomMeeting.lastError = 'sdk_not_initialized';
      print('Zoom SDK not initialized. Please initialize first.');
      return success;
    }

    success = await ZoomMeeting.joinMeeting(
      meetingNumber: meetingNumber,
      displayName: displayName,
      jwtToken: jwtToken,
      password: password,
    );

    if (success) {
      return success;
      print('Joining meeting: $meetingNumber');
    } else {
      return success;
      print('Failed to join meeting');
    }
  }

  Future<void> leaveMeeting() async {
    final success = await ZoomMeeting.leaveMeeting();
    if (success) {
      print('Left meeting successfully');
    } else {
      print('Failed to leave meeting');
    }
  }
}
