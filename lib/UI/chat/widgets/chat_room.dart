import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitness_zone_2/data/api_provider/chat_api_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

import '../../../../data/GetServices/CheckConnectionService.dart';
import '../../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../../data/controllers/home_controller/home_controller.dart';
import '../../../../values/constants.dart';
import '../../../../values/my_colors.dart';
import '../../../../widgets/app_bar_widget.dart';
import '../../../../widgets/toasts.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class ChatRoom extends StatefulWidget {
  final String chatRoomId;
  final Map<String, dynamic> userMap;
  bool isUpdated = false;
  bool showBack;
  String? title;
  ChatRoom(
      {required this.chatRoomId,
      required this.userMap,
      this.showBack = false,
      this.title});

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CheckConnectionService connectionService = CheckConnectionService();
  AuthController authController = Get.find();

  bool temp = false;

  bool audio = false;

  List<QueryDocumentSnapshot> listMessage = [];

  late String recordFilePath;

  final TextEditingController _message = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  updateUnread() async {
    var login = authController.logInUser;
    await _firestore
        .collection("users")
        .doc(login!.id.toString())
        .collection("myusers")
        .doc(widget.userMap["id"])
        .update({"newMessageArrived": false});
  }

  Future<bool> isAvailableUser(
      {required String idFrom, required String compareWith}) async {
    bool isAvailable = false;
    QuerySnapshot userSubCollection = await _firestore
        .collection("users")
        .doc(idFrom)
        .collection("myusers")
        .get();

    for (var element in userSubCollection.docs) {
      if (element["id"] == compareWith) {
        isAvailable = true;
        break;
      }
    }
    return isAvailable;
  }

  updateCollection(
      {required String collectionId,
      required String userId,
      required bool isAvailable,
      required String firstName,
      required String lastName,
      bool isMe = false,
      String? roomId,
      required String deviceToke}) async {
    // roomId is saved on both list entries so the web portal opens the
    // exact same room (the id is built from String.hashCode, which differs
    // between phone and web).
    if (isAvailable) {
      Get.log("User is available");
      await _firestore
          .collection("users")
          .doc(collectionId)
          .collection("myusers")
          .doc(userId)
          .update({
        "newMessageArrived": isMe ? false : true,
        if (roomId != null && roomId.isNotEmpty) "roomId": roomId,
      });
    } else {
      await _firestore
          .collection("users")
          .doc(collectionId)
          .collection("myusers")
          .doc(userId)
          .set({
        "id": userId,
        "name": "$firstName $lastName",
        "time": Timestamp.now(),
        "remoteId": 0,
        "days": "",
        "newMessageArrived": isMe ? false : true,
        "deviceToken": deviceToke,
        if (roomId != null && roomId.isNotEmpty) "roomId": roomId,
      });
    }
  }

  Future<void> checkAndAddUser() async {
    try {
      var login = authController.logInUser;

      bool isAvailableOther = await isAvailableUser(
          idFrom: widget.userMap["id"], compareWith: login!.id.toString());
      bool isAvailableCurrent = await isAvailableUser(
          compareWith: widget.userMap["id"], idFrom: login.id.toString());

      updateCollection(
          collectionId: widget.userMap["id"],
          userId: login.id.toString(),
          isAvailable: isAvailableOther,
          firstName: login.firstName,
          lastName: login.lastName,
          roomId: widget.chatRoomId,
          deviceToke: authController.sharedPreferences
                  .getString(Constants.deviceToken) ??
              "");
      updateCollection(
          userId: widget.userMap["id"],
          collectionId: login.id.toString(),
          isAvailable: isAvailableCurrent,
          firstName: widget.userMap["name"].split(" ").first ?? "",
          lastName: widget.userMap["name"].split(" ").last ?? "",
          isMe: true,
          roomId: widget.chatRoomId,
          deviceToke: widget.userMap["deviceToken"] ?? "");
    } catch (e) {
      Get.log("Error: $e");
    }
  }

  void onSendMessage() async {
    try {
      await connectionService.checkConnection().then((value) async {
        if (!value) {
          CustomToast.failToast(msg: "Check your internet connection");
        } else {
          if (_message.text.isEmpty) {
            CustomToast.failToast(msg: "Please enter some text");
          } else if (!Get.find<HomeController>().hasActivePackage) {
            CustomToast.failToast(
                msg:
                    "You need an active package to send messages. Please subscribe to a plan first.");
          } else {
            await _firestore
                .collection(Constants.chatRoom)
                .doc(widget.chatRoomId)
                .collection(Constants.allMessages)
                .add({
              "sendBy": Get.find<AuthController>().logInUser!.id,
              "name":
                  "${Get.find<AuthController>().logInUser!.firstName} ${Get.find<AuthController>().logInUser!.lastName}",
              "message": _message.text,
              "time": Timestamp.now()
            });
            checkAndAddUser();
            Get.find<AuthController>().sendMessageNotifications({
              "title": "A new message arrived",
              "body": _message.text,
              "deviceToken": widget.userMap["deviceToken"],
              "toUserId": widget.userMap["id"],
            });
            _message.clear();
          }
        }
      });
    } catch (e) {
      CustomToast.failToast(
          msg: "Something went wrong, please try again later");
    }
  }

  @override
  void initState() {
    updateUnread();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GetBuilder<AuthController>(builder: (homeController) {
      return GestureDetector(
          onTap: () {
            //    Get.find<AudioController>().selectedId="";
          },
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: HelpingWidgets().appBarWidget(
                widget.showBack
                    ? () {
                        Get.back();
                      }
                    : null,
                text: widget.title ?? "Chat Room"),
            body:
                // SingleChildScrollView(
                //     child:
                Column(
              children: [
                Expanded(
                  child: SizedBox(
                    //height: size.height / 1.25,
                    width: size.width,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection(Constants.chatRoom)
                          .doc(widget.chatRoomId)
                          .collection(Constants.allMessages)
                          .orderBy('time', descending: true)
                          .snapshots(),
                      builder: (BuildContext context, snapshot) {
                        print("snapshot $snapshot");
                        if (snapshot.data != null) {
                          return Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  itemCount: snapshot.data!.docs.length,
                                  shrinkWrap: false,
                                  reverse: true,
                                  itemBuilder: (context, index) {
                                    Map<String, dynamic> map =
                                        snapshot.data!.docs[index].data()
                                            as Map<String, dynamic>;
                                    return messages(
                                      size,
                                      map,
                                      context,
                                      index,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        } else {
                          return const Center(
                              child: FhLoader());
                        }
                      },
                    ),
                  ),
                ),
                Container(
                  height: 48.h,
                  margin:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          child: TextFormField(
                            expands: true,
                            controller: _message,
                            //  cursorHeight: 30,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            onChanged: (value) {},
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.all(10),
                              hintText: "Send Message ...",
                              hintStyle: const TextStyle(
                                decoration: TextDecoration.none,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 10.w,
                      ),

                      Container(
                        // padding: EdgeInsets.all(8),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: MyColors.buttonColor),
                        child: IconButton(
                            icon: Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 25.w,
                            ),
                            onPressed: onSendMessage),
                      )

                      //   );
                      // }),
                    ],
                  ),
                ),
              ],
            ),
            //    ),
          ));
    });
  }

  Widget messages(
      Size size, Map<String, dynamic> map, BuildContext context, int index) {
    return Container(
      width: size.width,
      alignment: map['sendBy'] == Get.find<AuthController>().logInUser!.id
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 8, top: 7, bottom: 5),
        margin: EdgeInsets.only(
            left: map['sendBy'] == Get.find<AuthController>().logInUser!.id
                ? 100
                : 10,
            right: map['sendBy'] == Get.find<AuthController>().logInUser!.id
                ? 10
                : 100,
            bottom: 5,
            top: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
              topRight: const Radius.circular(15),
              topLeft: const Radius.circular(15),
              bottomLeft:
                  map['sendBy'] == Get.find<AuthController>().logInUser!.id
                      ? const Radius.circular(15)
                      : const Radius.circular(0),
              bottomRight:
                  map['sendBy'] == Get.find<AuthController>().logInUser!.id
                      ? const Radius.circular(0)
                      : const Radius.circular(15)),
          color: map['sendBy'] == Get.find<AuthController>().logInUser!.id
              ? MyColors.grey.withOpacity(0.3)
              : MyColors.buttonColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Get.find<AuthController>().logInUser!.userType == Constants.user
                  ? map['name'] ?? ""
                  : "${map['name']} (${map["sendBy"]})" ?? "",
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            SizedBox(
              height: 5.h,
            ),
            Text(
              map['message'],
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: map['sendBy'] == Get.find<AuthController>().logInUser!.id
                    ? Colors.black
                    : Colors.white,
              ),
            ),
            SizedBox(
              height: 5.h,
            ),
            Text(
              HelpingWidgets.getDateFromTimeStamp(map["time"]),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: map['sendBy'] == Get.find<AuthController>().logInUser!.id
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
