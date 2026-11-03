import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import '../zoom_meeting.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:fitness_zone_2/data/services/youtube_tutorial_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

class ZoomMeetingWidget extends StatefulWidget {
  const ZoomMeetingWidget({super.key});

  @override
  State<ZoomMeetingWidget> createState() => _ZoomMeetingWidgetState();
}

class _ZoomMeetingWidgetState extends State<ZoomMeetingWidget> {
  final ZoomMeetingController _controller = ZoomMeetingController();
  final TextEditingController _meetingNumberController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isInitialized = false;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    // From .env (Oct 2026), no longer written in the code.
    final sdkKey = dotenv.env['ZOOM_SDK_KEY'] ?? '';
    final sdkSecret = dotenv.env['ZOOM_SDK_SECRET'] ?? '';

    generateZoomJwt(sdkKey: sdkKey, sdkSecret: sdkSecret);
  }

  Future<void> _initializeZoom(jwtToken) async {
    await _controller.initialize(jwtToken);
    setState(() {
      _isInitialized = true;
      _status = 'Initialized';
    });
  }

  Future<void> _joinMeeting() async {
    if (_meetingNumberController.text.isEmpty || _displayNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter meeting number and display name')),
      );
      return;
    }

    setState(() {
      _status = 'Joining meeting...';
    });

    await _controller.joinMeeting(
      meetingNumber: _meetingNumberController.text,
      displayName: _displayNameController.text,
      password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
    );
  }

  Future<void> _leaveMeeting() async {
    setState(() {
      _status = 'Leaving meeting...';
    });

    await _controller.leaveMeeting();
    setState(() {
      _status = 'Left meeting';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zoom Meeting'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isInitialized ? Icons.check_circle : Icons.error,
                            color: _isInitialized ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Zoom SDK Status: ${_isInitialized ? "Initialized" : "Not Initialized"}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Status: $_status'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _meetingNumberController,
                decoration: const InputDecoration(
                  labelText: 'Meeting Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.meeting_room),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isInitialized
                    ? () {
                        _joinMeeting();
                      }
                    : null,
                icon: const Icon(Icons.video_call),
                label: const Text('Join Meeting'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isInitialized ? _leaveMeeting : null,
                icon: const Icon(Icons.call_end),
                label: const Text('Leave Meeting'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instructions:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('1. Enter the meeting number provided by the host'),
                      Text('2. Enter your display name'),
                      Text('3. Enter password if required'),
                      Text('4. Tap "Join Meeting" to start'),
                      Text('5. Use "Leave Meeting" to exit'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _meetingNumberController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  generateZoomJwt({
    required String sdkKey,
    required String sdkSecret,
    int expiryInSeconds = 360000000,
  }) {
    final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000; // in seconds
    final exp = iat + expiryInSeconds;

    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final payload = {
      'appKey': sdkKey,
      'iat': iat,
      'exp': exp,
      'tokenExp': exp,
    };

    String base64UrlEncode(Object value) => base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');

    final headerEncoded = base64UrlEncode(header);
    final payloadEncoded = base64UrlEncode(payload);
    final data = '$headerEncoded.$payloadEncoded';

    final hmac = Hmac(sha256, utf8.encode(sdkSecret));
    final signature = hmac.convert(utf8.encode(data));
    final signatureEncoded = base64Url.encode(signature.bytes).replaceAll('=', '');
    var token = '$data.$signatureEncoded';

    print('_ZoomMeetingWidgetState.generateZoomJwt ${token}');
    _initializeZoom(token);
  }
}
