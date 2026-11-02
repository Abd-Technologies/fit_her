import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/progress_photo_service.dart';
import '../../theme/app_colors.dart';

/// 2M10 — private progress photo timeline + compare.
class ProgressPhotoTimelineScreen extends StatefulWidget {
  const ProgressPhotoTimelineScreen({super.key});

  @override
  State<ProgressPhotoTimelineScreen> createState() =>
      _ProgressPhotoTimelineScreenState();
}

class _ProgressPhotoTimelineScreenState
    extends State<ProgressPhotoTimelineScreen> {
  String? compareA;
  String? compareB;

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<ProgressPhotoService>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Progress photos'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final file =
              await ImagePicker().pickImage(source: ImageSource.gallery);
          if (file == null) return;
          await svc.add(path: file.path, label: 'Progress');
        },
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
      body: Obx(() {
        if (svc.photos.isEmpty) {
          return const Center(
            child: Text(
              'Private photos stay on your device.',
              style: TextStyle(color: Color(0xFF6F8B7A)),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (compareA != null && compareB != null) ...[
              const Text('Compare', style: TextStyle(fontWeight: FontWeight.w700)),
              Row(
                children: [
                  Expanded(child: Image.file(File(compareA!), height: 160)),
                  const SizedBox(width: 8),
                  Expanded(child: Image.file(File(compareB!), height: 160)),
                ],
              ),
              const Divider(),
            ],
            ...svc.photos.map((p) {
              final path = p['path'] ?? '';
              return ListTile(
                leading: path.isEmpty
                    ? const Icon(Icons.image)
                    : Image.file(File(path), width: 48, height: 48, fit: BoxFit.cover),
                title: Text(p['label'] ?? 'Photo'),
                subtitle: Text(p['at'] ?? ''),
                onTap: () => setState(() {
                  if (compareA == null) {
                    compareA = path;
                  } else if (compareB == null) {
                    compareB = path;
                  } else {
                    compareA = path;
                    compareB = null;
                  }
                }),
              );
            }),
          ],
        );
      }),
    );
  }
}
