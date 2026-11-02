import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/services/community_moderation_service.dart';
import '../../theme/app_colors.dart';

Future<void> showReportBlockSheet(
  BuildContext context, {
  required String postId,
  String? authorId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Safety',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report post'),
              onTap: () async {
                await Get.find<CommunityModerationService>().reportPost(
                  postId: postId,
                  reason: 'user_report',
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thanks — we will review this')),
                  );
                }
              },
            ),
            if (authorId != null && authorId.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Block user'),
                onTap: () async {
                  await Get.find<CommunityModerationService>()
                      .blockUser(authorId);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.primaryDeep),
              ),
            ),
          ],
        ),
      );
    },
  );
}
