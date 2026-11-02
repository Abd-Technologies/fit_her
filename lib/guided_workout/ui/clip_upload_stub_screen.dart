import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../theme/app_colors.dart';

/// X5 — staff clip upload UI posting to contract endpoint (stub).
class ClipUploadStubScreen extends StatefulWidget {
  const ClipUploadStubScreen({super.key});

  @override
  State<ClipUploadStubScreen> createState() => _ClipUploadStubScreenState();
}

class _ClipUploadStubScreenState extends State<ClipUploadStubScreen> {
  String? _path;
  final _tagsController = TextEditingController();
  bool _busy = false;
  String? _status;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty) return;
    setState(() => _path = result.files.single.path);
  }

  Future<void> _upload() async {
    if (_path == null) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    // Contract: POST /admin/guided-clips (multipart) — deferred backend.
    final tags = _tagsController.text.trim();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status =
          'Queued locally${tags.isEmpty ? '' : ' ($tags)'}. Backend hosting will accept this multipart next.';
    });
  }

  @override
  void dispose() {
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload exercise clip'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF163220),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.video_file),
              label: Text(_path == null ? 'Pick video' : 'Change video'),
            ),
            if (_path != null) ...[
              const SizedBox(height: 8),
              Text(_path!, style: const TextStyle(fontSize: 11)),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (body area, impact, phase)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy || _path == null ? null : _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                _busy ? 'Uploading…' : 'Upload',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              Text(_status!),
            ],
          ],
        ),
      ),
    );
  }
}
