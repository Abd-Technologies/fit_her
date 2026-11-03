import UIKit
import UserNotifications
import Flutter
import Firebase
import MobileRTC

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let CHANNEL = "zoom_meeting"
    private let EVENTS_CHANNEL = "zoom_meeting/events"
    private var zoomEventSink: FlutterEventSink?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        // flutter_local_notifications (README, iOS setup): needed so phone
        // notifications show while the app is open and taps reach the app.
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
        }

        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
        let eventsChannel = FlutterEventChannel(name: EVENTS_CHANNEL, binaryMessenger: controller.binaryMessenger)
        eventsChannel.setStreamHandler(self)

        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            switch call.method {
            case "initializeZoom":
                self.initializeZoom(call: call, result: result)
            case "joinMeeting":
                self.joinMeeting(call: call, result: result)
            case "leaveMeeting":
                self.leaveMeeting(result: result)
            case "isInitialized":
                let isInitialized = MobileRTC.shared().isRTCAuthorized()
                result(isInitialized)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func initializeZoom(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let jwtToken = args["jwtToken"] as? String else {
            result(FlutterError(code: "NO_JWT", message: "Missing JWT token", details: nil))
            return
        }

        let context = MobileRTCSDKInitContext()
        context.domain = "zoom.us"
        context.enableLog = true

        let sdkInitialized = MobileRTC.shared().initialize(context)

        if sdkInitialized {
            let authService = MobileRTC.shared().getAuthService()
            authService?.jwtToken = jwtToken
            authService?.delegate = self
            authService?.sdkAuth()
        }

        result(sdkInitialized)
    }

    private func joinMeeting(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let meetingNumber = args["meetingNumber"] as? String,
              let displayName = args["displayName"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing meeting number or display name", details: nil))
            return
        }

        let joinParams = MobileRTCMeetingJoinParam()
        joinParams.userName = displayName
        joinParams.meetingNumber = meetingNumber
        joinParams.password = args["password"] as? String ?? ""

        let meetingService = MobileRTC.shared().getMeetingService()
        meetingService?.delegate = self
        let joinResponse = meetingService?.joinMeeting(with: joinParams)

        if joinResponse == .success {
            result(true)
        } else {

        let errorCode = joinResponse?.rawValue ?? 9999  // Fallback for nil
        result(FlutterError(
            code: "JOIN_FAILED",
            message: "Join meeting failed with code \(errorCode)",
            details: nil
        ))

        }
    }

    private func leaveMeeting(result: @escaping FlutterResult) {
        let meetingService = MobileRTC.shared().getMeetingService()
        meetingService?.leaveMeeting(with: .leave)
        result(true)
    }
}

// MARK: - MobileRTCAuthDelegate
extension AppDelegate: MobileRTCAuthDelegate {
    func onMobileRTCAuthReturn(_ returnValue: MobileRTCAuthError) {
        print("Zoom SDK Auth result: \(returnValue.rawValue)")
    }
}

// MARK: - MobileRTCMeetingServiceDelegate
extension AppDelegate: MobileRTCMeetingServiceDelegate {
    func onMeetingError(_ error: MobileRTCMeetError, message: String?) {
        print("Zoom meeting error: \(error.rawValue) - \(message ?? "")")
        sendZoomEvent([
            "event": "meeting_failed",
            "errorCode": error.rawValue,
            "message": message ?? ""
        ])
    }

    func onMeetingStateChange(_ state: MobileRTCMeetingState) {
        switch state {
        case .inMeeting:
            sendZoomEvent(["event": "meeting_in", "status": state.rawValue])
        case .ended, .idle:
            sendZoomEvent(["event": "meeting_left", "status": state.rawValue])
        case .failed:
            sendZoomEvent(["event": "meeting_failed", "status": state.rawValue])
        default:
            break
        }
    }

    func onJoinMeetingConfirmed() {
        sendZoomEvent(["event": "meeting_in"])
    }

    func onMeetingReady() {
        sendZoomEvent(["event": "meeting_ready"])
    }
}

// MARK: - FlutterStreamHandler
extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        zoomEventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        zoomEventSink = nil
        return nil
    }

    private func sendZoomEvent(_ payload: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.zoomEventSink?(payload)
        }
    }
}
