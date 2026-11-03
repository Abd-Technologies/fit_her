import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/controllers/auth_controller/auth_controller.dart';
import '../../../data/controllers/home_controller/home_controller.dart';
import '../../../widgets/toasts.dart';

class MeasureMentScreen extends StatefulWidget {
  final bool showAppBar;

  /// Shown as a pop-up sheet (weekly check-in reminder, home prompt).
  final bool asSheet;
  const MeasureMentScreen({Key? key, this.showAppBar = false, this.asSheet = false}) : super(key: key);

  /// The weekly check-in as a pop-up, same form as Log measurements.
  /// Returns true when she saved it.
  static Future<bool> showSheet() async {
    final r = await Get.bottomSheet<bool>(
      const MeasureMentScreen(asSheet: true),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    return r == true;
  }

  /// Done in the last 6 days (on this phone)?
  static bool doneThisWeek() {
    try {
      final at = Get.find<AuthController>().sharedPreferences.getInt('weekly_report_at');
      if (at == null) return false;
      return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at)).inDays < 6;
    } catch (_) {
      return false;
    }
  }

  @override
  State<MeasureMentScreen> createState() => _MeasureMentScreenState();
}

class _MeasureMentScreenState extends State<MeasureMentScreen> {
  final HomeController homeController = Get.find();
  bool _isSubmitting = false;

  static const _kCanvas = Color(0xFFF9FCF7);
  static const _kCardBg = Colors.white;
  static const _kCardBorder = Color(0xFFEFF4EC);
  static const _kIconWashBg = Color(0xFFF6FBF3);
  static const _kTextPrimary = Color(0xFF1A3A22);
  static const _kSage = Color(0xFF7A8C78);
  static const _kAccent = Color(0xFF6DC55A);
  static const _kAccentSoft = Color(0xFF8CE07B);
  static const _kStreak = Color(0xFFE87A3E);

  @override
  void initState() {
    super.initState();
    // Pre-fill current date with today's date if empty
    if (homeController.currentDate.text.isEmpty) {
      homeController.currentDate.text =
          DateFormat("dd/MM/yyyy").format(DateTime.now());
    }
    // First day date + weight: remembered from her earlier check-ins.
    try {
      final prefs = Get.find<AuthController>().sharedPreferences;
      if (homeController.firstDay.text.isEmpty) {
        homeController.firstDay.text = prefs.getString('weekly_first_day') ?? '';
      }
      if (homeController.firstWeight.text.isEmpty) {
        homeController.firstWeight.text = prefs.getString('weekly_first_weight') ?? '';
      }
    } catch (_) {}
    // Pre-fill current weight from profile if empty
    if (homeController.currentWeight.text.isEmpty &&
        Get.isRegistered<AuthController>()) {
      final authWeight = Get.find<AuthController>().editWeight.text.trim();
      if (authWeight.isNotEmpty) {
        homeController.currentWeight.text = authWeight;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asSheet) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: _kCanvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
            child: Row(children: [
              const Spacer(),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFDADFD5), borderRadius: BorderRadius.circular(4)),
              ),
              const Spacer(),
            ]),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Get.back(result: false),
              icon: const Icon(Icons.close_rounded, color: _kSage),
            ),
          ),
          Expanded(child: _content(bottomPad: MediaQuery.of(context).viewInsets.bottom + 24)),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: _kCanvas,
      body: SafeArea(child: _content()),
    );
  }

  Widget _content({double bottomPad = 40}) {
    return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, widget.asSheet ? 0 : 10, 20, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showAppBar && !widget.asSheet) _topBar(),
              _headerIntro(),
              const SizedBox(height: 18),

              // 1. Dates & Weight Card
              _datesAndWeightCard(),
              const SizedBox(height: 16),

              // 2. Body Circumference Card
              _circumferenceCard(),
              const SizedBox(height: 16),

              // 3. Weekly Reflection / Notes Card
              _reflectionCard(),
              const SizedBox(height: 16),

              // 4. Emoji Satisfaction Rating Card
              _satisfactionCard(),
              const SizedBox(height: 24),

              // 5. Submit Button
              _submitButton(),
              const SizedBox(height: 24),
            ],
          ),
    );
  }

  // ─── Top Bar ───────────────────────────────────────────────────────────
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Get.back(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kTextPrimary.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, size: 16, color: _kTextPrimary),
            ),
          ),
          const Spacer(),
          const Text(
            'My Weekly Report',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ─── Header Intro ──────────────────────────────────────────────────────
  Widget _headerIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'WEEKLY CHECK-IN',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _kSage,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Body Measurements',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _kTextPrimary,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Track your body circumference and weight changes week by week to observe toning and fat loss beyond the scale.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: _kSage,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  // ─── 1. Dates & Weight Card ────────────────────────────────────────────
  Widget _datesAndWeightCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.calendar_today_outlined,
            title: 'Timeline & Body Weight',
            subtitle: 'Starting vs. current check-in values',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _datePickerField(
                  label: '1st Day Date',
                  controller: homeController.firstDay,
                  hint: 'Select date',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _datePickerField(
                  label: 'Current Date',
                  controller: homeController.currentDate,
                  hint: 'Today',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _numberInputField(
                  label: '1st Day Weight',
                  controller: homeController.firstWeight,
                  hint: 'e.g. 68',
                  unit: 'kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberInputField(
                  label: 'Current Weight',
                  controller: homeController.currentWeight,
                  hint: 'e.g. 66',
                  unit: 'kg',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2. Circumference Card ─────────────────────────────────────────────
  Widget _circumferenceCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.straighten_outlined,
            title: 'Circumference Measurements',
            subtitle: 'Measure in inches or cm consistently',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _numberInputField(
                  label: 'Waist',
                  controller: homeController.waist,
                  hint: 'e.g. 30',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberInputField(
                  label: 'Hips',
                  controller: homeController.hips,
                  hint: 'e.g. 38',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numberInputField(
                  label: 'Chest',
                  controller: homeController.chest,
                  hint: 'e.g. 34',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberInputField(
                  label: 'Abdomen',
                  controller: homeController.abdonmen,
                  hint: 'e.g. 32',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numberInputField(
                  label: 'Arms',
                  controller: homeController.arms,
                  hint: 'e.g. 11',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberInputField(
                  label: 'Shoulder',
                  controller: homeController.shoulder,
                  hint: 'e.g. 15',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numberInputField(
                  label: 'Thighs',
                  controller: homeController.thighs,
                  hint: 'e.g. 22',
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 3. Reflection / Feedback Card ─────────────────────────────────────
  Widget _reflectionCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Weekly Feedback',
            subtitle: 'How was your experience this week?',
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _kIconWashBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kCardBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              controller: homeController.tellUsMore,
              maxLines: 4,
              minLines: 3,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kTextPrimary,
              ),
              decoration: const InputDecoration(
                hintText:
                    'Tell us about your workouts, diet compliance, energy levels, or service experience...',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: _kSage,
                  height: 1.4,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. Satisfaction Rating Card ───────────────────────────────────────
  Widget _satisfactionCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.sentiment_satisfied_alt_outlined,
            title: 'Weekly Progress Satisfaction',
            subtitle: 'Select how you feel about your progress',
          ),
          const SizedBox(height: 14),
          Obx(() {
            final selectedIdx = homeController.selectedSatisfaction.value;
            final label = (selectedIdx >= 0 &&
                    selectedIdx < homeController.labels.length)
                ? homeController.labels[selectedIdx]
                : 'Satisfied';
            return Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kAccent,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(homeController.satisfactionEmojis.length,
                (index) {
              return Obx(() {
                final isSelected =
                    homeController.selectedSatisfaction.value == index;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    homeController.selectedSatisfaction.value = index;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kAccent.withOpacity(0.15)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _kAccent : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: Text(
                      homeController.satisfactionEmojis[index],
                      style: TextStyle(
                        fontSize: isSelected ? 34 : 28,
                      ),
                    ),
                  ),
                );
              });
            }),
          ),
        ],
      ),
    );
  }

  // ─── 5. Submit Button ──────────────────────────────────────────────────
  Widget _submitButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isSubmitting ? null : _handleSubmit,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kAccent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _kAccent.withOpacity(0.35),
              offset: const Offset(0, 6),
              blurRadius: 16,
            ),
          ],
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Submit Weekly Report',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── Submission Logic ──────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (homeController.firstDay.text.trim().isEmpty ||
        homeController.currentDate.text.trim().isEmpty ||
        homeController.firstWeight.text.trim().isEmpty ||
        homeController.currentWeight.text.trim().isEmpty ||
        homeController.waist.text.trim().isEmpty ||
        homeController.hips.text.trim().isEmpty ||
        homeController.shoulder.text.trim().isEmpty ||
        homeController.arms.text.trim().isEmpty ||
        homeController.chest.text.trim().isEmpty ||
        homeController.abdonmen.text.trim().isEmpty ||
        homeController.thighs.text.trim().isEmpty) {
      // (Weekly feedback is optional.)
      CustomToast.failToast(msg: "Please fill in all measurement fields");
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final ok = await homeController.updateMyWeeklyReport();
      if (ok && mounted && (widget.showAppBar || widget.asSheet)) {
        // Opened as its own screen / pop-up: close after saving.
        Get.back(result: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── UI Helper Widgets ─────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kTextPrimary.withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _kIconWashBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: _kAccent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kTextPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: _kSage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _numberInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _kIconWashBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kCardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: _kSage,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (unit != null)
                Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kSage,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _datePickerField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              builder: (BuildContext context, Widget? child) {
                return Theme(
                  data: ThemeData.light().copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: _kAccent,
                      onPrimary: Colors.white,
                      onSurface: _kTextPrimary,
                    ),
                    dialogBackgroundColor: Colors.white,
                  ),
                  child: child!,
                );
              },
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2099),
            );
            if (picked != null) {
              setState(() {
                controller.text = DateFormat("dd/MM/yyyy").format(picked);
              });
            }
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _kIconWashBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kCardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.text.isNotEmpty ? controller.text : hint,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: controller.text.isNotEmpty
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: controller.text.isNotEmpty
                          ? _kTextPrimary
                          : _kSage,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: _kAccent),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
