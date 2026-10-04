// Report an Issue — lets a user describe a technical / app-service problem and
// optionally attach a screenshot. It posts to partner_backend
// (POST /users/app-issue), which relays it to the CRM where it lands in the
// ADMIN support queue (not the sales reps).
//
// Navigate to it from anywhere with:
//   Get.to(() => const ReportIssueScreen());

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide MultipartFile, FormData, Response;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../values/constants.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  static const List<String> _categories = <String>[
    "App not working",
    "Payment",
    "Diet / Plan",
    "Class / Session",
    "Other",
  ];

  // Maps the friendly label to the category code the backend/CRM expects.
  static const Map<String, String> _categoryCode = <String, String>{
    "App not working": "APP_ISSUE",
    "Payment": "PAYMENT",
    "Diet / Plan": "PLAN",
    "Class / Session": "CLASS",
    "Other": "OTHER",
  };

  final TextEditingController _messageCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String _category = _categories.first;
  File? _image;
  bool _submitting = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked =
          await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (picked != null) {
        setState(() => _image = File(picked.path));
      }
    } catch (e) {
      Get.snackbar("Could not attach image", e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("Choose from gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text("Take a photo"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final message = _messageCtrl.text.trim();
    if (message.isEmpty && _image == null) {
      Get.snackbar("Nothing to send",
          "Please describe the issue or attach a screenshot.",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _submitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(Constants.accessToken) ?? "";

      final uri = Uri.parse("${Constants.baseUrl}/users/app-issue");
      final request = http.MultipartRequest("POST", uri);
      request.headers["accessToken"] = token;
      request.fields["message"] = message;
      request.fields["category"] = _categoryCode[_category] ?? "OTHER";
      if (_image != null) {
        request.files
            .add(await http.MultipartFile.fromPath("image", _image!.path));
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      bool ok = false;
      try {
        final decoded = jsonDecode(resp.body);
        ok = decoded is Map && decoded["status"]?.toString() == "1";
      } catch (_) {
        ok = resp.statusCode >= 200 && resp.statusCode < 300;
      }

      if (ok) {
        Get.back();
        Get.snackbar("Issue sent",
            "Thanks — our team has received your message and will get back to you.",
            snackPosition: SnackPosition.BOTTOM);
      } else {
        // DEBUG: surface the real status + server response so we can see why.
        final bodyPreview =
            resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
        // ignore: avoid_print
        print("[ReportIssue] POST ${uri.toString()} -> ${resp.statusCode}: ${resp.body}");
        Get.snackbar("Couldn't send (${resp.statusCode})", bodyPreview,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 8));
      }
    } catch (e) {
      Get.snackbar("Couldn't send", e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(title: const Text("Report an Issue")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Tell us what's going wrong with the app or your service. "
                "Our support team (not sales) will look into it.",
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 18),

              const Text("Category", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _category,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _categories
                    .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 16),

              const Text("Describe the issue",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _messageCtrl,
                maxLines: 5,
                maxLength: 1000,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: "e.g. My diet plan isn't loading after I paid…",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),

              // Attachment
              if (_image != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_image!,
                          height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                    IconButton(
                      icon: const CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 14,
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                      onPressed: () => setState(() => _image = null),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _showImageSourceSheet,
                  icon: const Icon(Icons.attach_file),
                  label: const Text("Attach a screenshot (optional)"),
                ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Send to support",
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
