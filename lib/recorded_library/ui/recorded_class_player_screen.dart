
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import '../models/recorded_class.dart';
import '../recorded_library_controller.dart';

class RecordedClassPlayerScreen extends StatefulWidget {
  final RecordedClass cls;
  const RecordedClassPlayerScreen({super.key, required this.cls});

  @override
  State<RecordedClassPlayerScreen> createState() =>
      _RecordedClassPlayerScreenState();
}

class _RecordedClassPlayerScreenState extends State<RecordedClassPlayerScreen> {
  double position = 0;

  @override
  void initState() {
    super.initState();
    final c = Get.find<RecordedLibraryController>();
    position = c.progress[widget.cls.id] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<RecordedLibraryController>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.cls.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                color: const Color(0xFF1A1A1A),
                child: Text(
                  c.lowData.value
                      ? 'Low-data stream stub\n${widget.cls.streamUrl}'
                      : 'HD stream stub\n${widget.cls.streamUrl}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
            Slider(
              value: position.clamp(0, 1),
              onChanged: (v) => setState(() => position = v),
              onChangeEnd: (v) => c.saveProgress(widget.cls.id, v),
              activeColor: AppColors.primary,
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => c.toggleDownload(widget.cls.id),
                  child: Obx(() => Text(
                        c.downloaded.contains(widget.cls.id)
                            ? 'Downloaded'
                            : 'Download offline',
                        style: const TextStyle(color: Colors.white),
                      )),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    await c.markComplete(widget.cls.id);
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Mark done',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
