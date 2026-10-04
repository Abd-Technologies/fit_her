import 'dart:convert';

import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/controllers/paid_home_controller/paid_home_controller.dart';
import 'package:fitness_zone_2/data/controllers/post_controller.dart';
import 'package:fitness_zone_2/data/controllers/workout_controller/work_out_controller.dart';
import 'package:fitness_zone_2/helper/notification_services.dart';
import 'package:fitness_zone_2/values/constants.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/get_clients_diet.dart';
import '../models/get_user_plan/get_workout_user_plan_details.dart';
import '../models/post_model.dart';
import '../models/upcoming_class_slot.dart';
import 'auth_controller/auth_controller.dart';
import 'socket_time_block.dart';

class SocketController extends GetxController {
  IO.Socket? socket;

  HomeController homeController = Get.find();

  // The socket opens bound to whoever was logged in at the time
  // (onConnect emits "getSlot" with that user's id — see socketInit below)
  // and nothing ever closed it on logout. Get.delete now calls this
  // automatically, so logging out actually drops the connection instead of
  // leaving it open and receiving/emitting events for a signed-out account.
  @override
  void onClose() {
    socket?.disconnect();
    socket = null;
    super.onClose();
  }

  void joinCommunity() {
    print('SocketController.joinCommunity');
    socket?.emit("joinCommunity");
  }

  void leaveCommunity() {
    print('SocketController.leaveCommunity');
    socket?.emit("leaveCommunity");
  }

  void joinPost(int postId) {
    print('SocketController.joinPost $postId');
    socket?.emit("joinPost", postId);
  }

  void leavePost(int postId) {
    print('SocketController.leavePost $postId');
    socket?.emit("leavePost", postId);
  }

  socketInit() {
    // Uses Constants.baseUrl so dev builds hit local server and prod
    // builds hit backend.thefither.com — previously hardcoded to prod.
    socket = IO.io(Constants.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 2000,
    });

    socket?.connect();
    socket?.onConnect((c) {
      print('SocketController.onConnect ${socket?.id}');
      socket?.emit("getSlot", {"id": Get.find<AuthController>().logInUser?.id});
    });
    socket?.onConnectError((error) {
      print('SocketController.onConnectError $error');
    });
    socket?.onError((error) {
      print('SocketController.onError $error');
    });
    socket?.onDisconnect((reason) {
      print('SocketController.onDisconnect $reason');
    });
    socket?.on("slotUpdate", (message) {
      if (message == null) return;

      final upcomingClassSlot = UpcomingClassSlot(
        upcomingSlot: Slot.fromJson(jsonDecode(message["upcomingSlot"])),
        trainer: ClientUser.fromJson(jsonDecode(message["trainer"])),
      );

      // Always update UI so she can see the class on screen
      homeController.upComingClassNotifier.value = upcomingClassSlot;

      // Only fire a local notification if the slot falls in her preferred time block
      final slot = upcomingClassSlot.upcomingSlot;
      if (slot != null && _isInPreferredTimeBlock(slot.start)) {
        final notifServices = Get.find<NotificationServices>();
        // Reuse the existing addNotification-style local push via RemoteMessage-like data.
        // Since we're coming from socket (not FCM), we show a local notification directly.
        notifServices.showLocalNotification(
          title: _titleForStatus(upcomingClassSlot.upcomingSlot?.status),
          body: _bodyForStatus(upcomingClassSlot.upcomingSlot?.status),
        );
      }

      // Instantly refresh the new home dashboard (comingUp tiles) and the
      // workout schedule screen so status changes (Confirmed, Cancelled,
      // In Progress) appear immediately without waiting for the 30s heartbeat.
      // Both calls are silent — no loading spinner, no error toast.
      _silentRefreshSchedule();
    });

    socket?.on("newPost", (message) {
      print('SocketController.newPost $message');
      if (message != null) {
        var post = Post.fromJson(message);
        if (post.approved) {
          final postController = Get.find<PostController>();
          final existing = postController.postsList.firstWhereOrNull((p) => p.id == post.id);
          if (existing == null) {
            postController.postsList.add(post);
            postController.postsList.refresh();
          }
        }
      }
    });

    socket?.on("replyWithUser", (message) {
      print('SocketController.replyWithUser $message');
      if (message != null) {
        final post = Get.find<PostController>().postsList.firstWhereOrNull((p) => p.id == message["postId"]);
        if (post != null) {
          final reply = Reply.fromJson(message);
          final alreadyExists = post.replies.any((r) => r.id == reply.id);
          if (!alreadyExists) {
            post.replies.add(reply);
            Get.find<PostController>().postsList.refresh();
          }
        }
      }
    });
    socket?.on("replyCreated", (message) {
      print('SocketController.replyCreated $message');
      if (message != null) {
        final dynamic postIdValue = message["postId"];
        final int? postId = postIdValue is int ? postIdValue : int.tryParse(postIdValue.toString());
        final replyJson = message["reply"];
        if (postId == null || replyJson == null) {
          return;
        }
        final post = Get.find<PostController>().postsList.firstWhereOrNull((p) => p.id == postId);
        if (post != null) {
          final reply = Reply.fromJson(replyJson);
          final alreadyExists = post.replies.any((r) => r.id == reply.id);
          if (!alreadyExists) {
            post.replies.add(reply);
            Get.find<PostController>().postsList.refresh();
          }
        }
      }
    });

    socket?.on("toggleLike", (message) {
      if (message != null) {
        final post = Get.find<PostController>().postsList.firstWhereOrNull((p) => p.id == int.parse(message["postId"]));
        print('SocketController.socketInit ${post}');
        if (post != null) {
          if (message["like"]) {
            post.likesCount.value++;
          } else {
            if (post.likesCount.value > 0) {
              post.likesCount.value--;
            }
          }
          Get.find<PostController>().postsList.refresh();
        }
      }
    });
  }

  /// Fires silent data refreshes on every screen that shows slot status.
  /// Called on every incoming [slotUpdate] socket event so Confirmed /
  /// Cancelled / In Progress changes appear instantly without waiting for
  /// the 30-second heartbeat timers in PaidHomeScreenV2 and WorkOutBottomScreen.
  ///
  /// Both calls are best-effort — we swallow errors so a stale controller
  /// (e.g., trainer device that never mounted WorkOutBottomScreen) can't
  /// crash the socket handler.
  void _silentRefreshSchedule() {
    // New home screen — refreshes comingUp slot tiles.
    try {
      Get.find<PaidHomeController>().silentRefresh();
    } catch (_) {}

    // Workout schedule screen — refreshes the full slot tree.
    // planId '0' is the "current plan" sentinel used across the app.
    try {
      Get.find<WorkOutController>().getDietPlanDetailsFunc('0', silent: true);
    } catch (_) {}
  }

  /// Returns true if [slotStart] falls inside the user's preferred time block.
  /// Handles both 24h ("08:00") and 12h ("8:00 AM" / "08:00 PM") formats.
  /// "all" or unset → always true (notify for everything).
  ///
  /// Delegates to socket_time_block.dart's pure `isSlotTimeInPreferredBlock`
  /// so the actual matching logic (and its tests) lives in one shared,
  /// dependency-free place — this wrapper just supplies the timeBlock
  /// preference from SharedPreferences. Every existing call site is
  /// unchanged.
  bool _isInPreferredTimeBlock(String? slotStart) {
    final prefs = Get.find<AuthController>().sharedPreferences;
    final timeBlock = prefs.getString(Constants.timeBlock) ?? 'all';
    return isSlotTimeInPreferredBlock(timeBlock, slotStart);
  }

  String _titleForStatus(String? status) => classReminderTitleForStatus(status);

  String _bodyForStatus(String? status) => classReminderBodyForStatus(status);

  getSlot() {
    socket?.emit("getSlot", {"id": Get.find<AuthController>().logInUser?.id});
  }

  @override
  void onInit() {
    socketInit();
    super.onInit();
  }
}
