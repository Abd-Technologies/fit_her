import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:fitness_zone_2/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../values/my_imgs.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final AuthController authController = Get.find();

  @override
  void initState() {
    super.initState();
    authController.fetchNotifications(markRead: true);
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }, text: "Notifications"),
      bottomNavigationBar: ValueListenableBuilder<List<dynamic>?>(
        valueListenable: authController.sharedPrefNotifier,
        builder: (context, value, child) {
          if (value == null || value.isEmpty) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            top: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: CustomButton(
                text: "Mark All Read",
                onPressed: () {
                  authController.markAllNotificationsRead();
                },
                // Wave 0 U-03 — neutral secondary style; reserve red for
                // destructive actions only.
                color: const Color(0xFF6F8B7A),
                borderColor: const Color(0xFF6F8B7A),
              ),
            ),
          );
        },
      ),
      body: ValueListenableBuilder<List<dynamic>?>(
        valueListenable: authController.sharedPrefNotifier,
        builder: (context, value, child) {
          if (value == null || value.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF4F7F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFF8AD167),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF163220),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When you receive class reminders, updates, or announcements, they will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Color(0xFF7A8C78),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) => Dismissible(
              key: UniqueKey(),
              onDismissed: (dismiss) {
                authController.removeItem(index);
              },
              background: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                color: Colors.red,
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                        height: 40,
                        width: 40,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.white10),
                        child: Image.asset(
                          MyImgs.logo,
                          height: 30,
                        )),
                    title: Text(
                      value[index].title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      value[index].body,
                      style: textTheme.titleLarge!
                          .copyWith(color: Colors.grey),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      height: 1,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                  )
                ],
              ),
            ),
            separatorBuilder: (context, index) => const SizedBox(
              height: 0,
            ),
            itemCount: value.length,
          );
        },
      ),
    );
  }
}
