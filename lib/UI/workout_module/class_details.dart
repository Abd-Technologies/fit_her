import 'package:fitness_zone_2/data/controllers/workout_controller/work_out_controller.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../widgets/custom_textfield.dart';
import '../../widgets/class_option_picker.dart';

/// Trainer: set a class's type, intensity and description.
///
/// Type and intensity are picked from fixed options instead of typed, so
/// every class uses the same spelling. The client screens colour and
/// label classes by these words (Yoga = purple, HIIT = orange, ...), so a
/// typo like "yogaa" or "Hit" used to fall back to the plain default
/// style. "Other" still lets the trainer type her own class type.
class ClassDetails extends StatefulWidget {
  const ClassDetails({super.key, required this.slotId});
  final int slotId;

  @override
  State<ClassDetails> createState() => _ClassDetailsState();
}

// Option lists live in widgets/class_option_picker.dart (shared with the
// admin's Add Trainer Slots form) so both save the same spelling.
const List<String> _kClassTypes = kClassTypeOptions;
const List<String> _kIntensities = kClassIntensityOptions;
const String _kOther = kClassOptionOther;

const Color _kInk = Color(0xFF1A3A22);
const Color _kMuted = Color(0xFF7A8C78);
const Color _kAccent = Color(0xFF6DC55A);
const Color _kBorder = Color(0xFFD8EDD4);

class _ClassDetailsState extends State<ClassDetails> {
  final TextEditingController level = TextEditingController();
  final TextEditingController type = TextEditingController();
  final TextEditingController customType = TextEditingController();
  final TextEditingController description = TextEditingController();

  String? _type;
  String? _level;

  @override
  void dispose() {
    level.dispose();
    type.dispose();
    customType.dispose();
    description.dispose();
    super.dispose();
  }

  void _save() {
    final chosenType =
        _type == _kOther ? customType.text.trim() : (_type ?? '').trim();
    if (chosenType.isEmpty) {
      Get.snackbar('Class type needed', 'Pick a class type, or choose Other and type it.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_level == null) {
      Get.snackbar('Intensity needed', 'Pick Low, Medium or High.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    type.text = chosenType;
    level.text = _level!;
    Get.find<WorkOutController>()
        .updateClassDetails(widget.slotId, type, level, description);
  }

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _kInk,
          ),
        ),
      );

  Widget _chips(List<String> options, String? selected, ValueChanged<String> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final on = o == selected;
        return GestureDetector(
          onTap: () => onTap(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: on ? _kAccent : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: on ? _kAccent : _kBorder),
            ),
            child: Text(
              o,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : _kInk,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }, text: "Class Details"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),
            _label('Class type'),
            _chips([..._kClassTypes, _kOther], _type,
                (v) => setState(() => _type = v)),
            if (_type == _kOther) ...[
              SizedBox(height: 12.h),
              CustomTextField(
                keyboardType: TextInputType.text,
                text: "Type the class name".tr,
                length: 30,
                controller: customType,
                inputFormatters: FilteringTextInputFormatter.singleLineFormatter,
              ),
            ],
            SizedBox(height: 22.h),
            _label('Intensity'),
            _chips(_kIntensities, _level, (v) => setState(() => _level = v)),
            SizedBox(height: 22.h),
            _label('Description'),
            CustomTextField(
              height: 100,
              keyboardType: TextInputType.text,
              text: "What will clients do in this class?".tr,
              length: 300,
              controller: description,
              inputFormatters: FilteringTextInputFormatter.singleLineFormatter,
            ),
            SizedBox(height: 8.h),
            const Text(
              'Clients see the class type and intensity on their schedule.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: _kMuted),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
      bottomNavigationBar:
          HelpingWidgets().bottomBarButtonWidget(onTap: _save),
    );
  }
}
