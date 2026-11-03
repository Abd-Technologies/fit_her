// import 'package:flutter/material.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// class InAppWebViewScreen extends StatefulWidget {
//   InAppWebViewScreen(this.url, {super.key});
//   String url;
//
//   @override
//   _InAppWebViewScreenState createState() => _InAppWebViewScreenState();
// }
//
// class _InAppWebViewScreenState extends State<InAppWebViewScreen> with WidgetsBindingObserver {
//   InAppWebViewController? webViewController;
//   AppLifecycleState? _lastLifecycleState;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this); // Start observing lifecycle events
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this); // Stop observing lifecycle events
//     super.dispose();
//   }
//   var googleMeetUrl = Uri.parse("https://meet.google.com/");
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);
//
//     // Listen for when the app is resumed
//     if (state == AppLifecycleState.resumed && _lastLifecycleState == AppLifecycleState.paused) {
//       print('User returned to the app after using Google Meet.');
//     }
//
//     _lastLifecycleState = state;
//   }
//
//   Future<void> _launchGoogleMeet(String url) async {
//     Uri googleMeetUri = Uri.parse(url);
//     if (await canLaunchUrl(googleMeetUri)) {
//       await launchUrl(googleMeetUri, mode: LaunchMode.externalApplication);
//     } else {
//       throw 'Could not launch Google Meet URL';
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("InAppWebView Example"),
//       ),
//       body: InAppWebView(
//         initialSettings: InAppWebViewSettings(
//           useShouldOverrideUrlLoading: true,
//           javaScriptEnabled: true,
//           javaScriptCanOpenWindowsAutomatically: true,
//         ),
//         initialUrlRequest: URLRequest(
//           url: WebUri("https://meet.google.com/landing"),
//         ),
//         onWebViewCreated: (controller) {
//           webViewController = controller;
//         },
//         // shouldOverrideUrlLoading: (controller, navigationAction) async {
//         //   Uri url = navigationAction.request.url!;
//         //   if (url.host.contains("meet.google.com")) {
//         //     // If the URL is for Google Meet, open in external browser
//         //     await _launchGoogleMeet(url.toString());
//         //     return NavigationActionPolicy.CANCEL; // Cancel the WebView from loading the page
//         //   }
//         //   return NavigationActionPolicy.ALLOW; // Otherwise, allow the WebView to load the page
//         // },
//         onLoadStop: (controller, url) async {
//           print("Page finished loading: $url");
//         },
//         onProgressChanged: (controller, progress) {
//           setState(() {
//             print("Loading progress: $progress%");
//           });
//         },
//       ),
//     );
//   }
// }

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';


class AppWebView extends StatefulWidget {
  final String url;
  final String? appName;

  const AppWebView({
    required this.url,
    this.appName,
    Key? key,
  }) : super(key: key);

  @override
  State<AppWebView> createState() => _AppWebViewState();
}

class _AppWebViewState extends State<AppWebView> {
  late InAppWebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("Loaded URL: ${widget.url}");

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(widget.appName ?? "WebView"),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            // initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useHybridComposition: true,
                // hardwareAcceleration: true,
                cacheEnabled: true,
                // iframeCsp:"worker-src" ,
                clearCache: true,
                // incognito: true,
                // horizontalScrollBarEnabled: true,
                mediaPlaybackRequiresUserGesture:
                    false, // Allow autoplay for media
                allowsInlineMediaPlayback: true,
                allowBackgroundAudioPlaying: true,
                domStorageEnabled: true,
                // userAgent: "Mozilla/5.0 (Windows NT 11.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.5993.116 Safari/537.36",

                // Enable DOM storage for sites like Facebook
                // userAgent:"random"
                userAgent:
                    "Mozilla/5.0 (Windows NT 11.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"

                // "Mozilla/5.0 (Windows NT 11.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
                ),

            onWebViewCreated: (InAppWebViewController controller) {
              _controller = controller;
            },
            onLoadStart: (controller, url) {
              log("URL IS loaded ${url}------");
              log("END URL");
              setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) async {
              setState(() => _isLoading = false);

              // Handle specific URL patterns for navigation or triggers.
              if (url != null && url.toString().contains('example')) {
                Navigator.pop(context);
              }
            },

            onProgressChanged: (controller, progress) {
              if (progress == 100) {
                setState(() => _isLoading = false);
              }
            },
            onReceivedError: (controller, url, code) {
              setState(() => _isLoading = false);
              // Optionally handle error display or retry mechanisms.
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {},

            // controller: webViewController,
          ),
          if (_isLoading)
            const Center(
              child: FhLoader(),
            ),
        ],
      ),
    );
  }
}
