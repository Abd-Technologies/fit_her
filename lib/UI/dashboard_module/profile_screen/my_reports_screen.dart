import 'package:fitness_zone_2/helper/progress_report_access.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import 'package:fitness_zone_2/UI/dashboard_module/bottom_bar_screen/progress_screen_v2.dart';
import 'package:fitness_zone_2/widgets/weekly_checkin/weekly_checkin_sheet.dart';
import 'package:fitness_zone_2/data/Repos/progress_v2/progress_repository.dart';
import 'package:fitness_zone_2/data/api_provider/api_provider.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/data/controllers/motivation_controller/motivation_controller.dart';
import 'package:fitness_zone_2/data/models/progress_v2/progress_models.dart';
import 'package:fitness_zone_2/services/progress_report_pdf_service.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final AuthController authController = Get.find();
  bool _isGeneratingPdf = false;
  // Report unlocks after her first weekly check-in (server rule).
  ProgressReportAccess? _access;

  @override
  void initState() {
    super.initState();
    ProgressReportAccess.load().then((a) {
      if (mounted) setState(() => _access = a);
    });
  }

  static const _kCanvas = Color(0xFFF9FCF7);
  static const _kCardBg = Colors.white;
  static const _kCardBorder = Color(0xFFEFF4EC);
  static const _kIconWashBg = Color(0xFFF6FBF3);
  static const _kTextPrimary = Color(0xFF1A3A22);
  static const _kSage = Color(0xFF7A8C78);
  static const _kAccent = Color(0xFF6DC55A);
  static const _kStreak = Color(0xFFE87A3E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(),
              const SizedBox(height: 16),
              const Text(
                'My Reports',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _kTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your health overview, weekly measurements, and clinical progress reports.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: _kSage,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),

              // 1. Current Health & Biometrics Overview
              _overviewCard(),
              const SizedBox(height: 16),

              // 2. Body Measurements Card
              _measurementsCard(),
              const SizedBox(height: 16),

              // 3. Clinical Progress Hub Card
              _progressHubCard(),
              const SizedBox(height: 16),

              // 4. Download PDF Report Card
              _pdfReportCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Top Bar ───────────────────────────────────────────────────────────
  Widget _topBar() {
    return Row(
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
          'Reports',
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
    );
  }

  // ─── 1. Health Overview Card ───────────────────────────────────────────
  Widget _overviewCard() {
    final weight = authController.editWeight.text.trim();
    final bmi = authController.editBmi.text.trim();
    final goal = authController.mainGoal.value.trim();

    final mc = Get.isRegistered<MotivationController>()
        ? Get.find<MotivationController>()
        : null;
    final stats = mc?.motivationStats.value;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _kIconWashBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center_outlined,
                    size: 16, color: _kAccent),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HEALTH OVERVIEW',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kSage,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Latest Biometrics',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (stats != null && stats.streak > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kStreak.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${stats.streak} 🔥',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _kStreak,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: _kCardBorder),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  label: 'Current Weight',
                  value: weight.isNotEmpty ? '$weight kg' : '—',
                ),
              ),
              Expanded(
                child: _metricTile(
                  label: 'BMI Score',
                  value: bmi.isNotEmpty ? bmi : '—',
                ),
              ),
              Expanded(
                child: _metricTile(
                  label: 'Attendance',
                  value: stats != null ? '${stats.daysAttendedLast30}/30' : '—',
                ),
              ),
            ],
          ),
          if (goal.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kIconWashBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined, size: 14, color: _kAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Goal: $goal',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 2. Weekly Measurements Card ───────────────────────────────────────
  Widget _measurementsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _kIconWashBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.straighten_outlined,
                    size: 16, color: _kAccent),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BODY MEASUREMENTS',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kSage,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Weekly Body Check-in',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Track waist, hips, chest, arms, and thighs week by week to monitor fat loss and toning beyond just the scale.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: _kSage,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _actionButton(
            label: 'Log / Update Measurements →',
            // One weekly check-in (Oct 2026): same weekly record as the
            // check-in; the old full form is no longer used here.
            onTap: () => WeeklyCheckinSheet.logMeasurements(),
          ),
        ],
      ),
    );
  }

  // ─── 3. Clinical Progress Hub Card ─────────────────────────────────────
  Widget _progressHubCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _kIconWashBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights_outlined,
                    size: 16, color: _kAccent),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLINICAL INSIGHTS',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kSage,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Interactive Progress Hub',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Explore full weight trends, pace projections, 4-ring activity glance, hydration tracking, and hormonal phase symptoms.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: _kSage,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _actionButton(
            label: 'Open Progress Hub →',
            isPrimary: false,
            onTap: () => Get.to(() => const ProgressScreenV2()),
          ),
        ],
      ),
    );
  }

  // ─── 4. PDF Report Card ────────────────────────────────────────────────
  Widget _pdfReportCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined,
                    size: 16, color: Color(0xFFE05252)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXPORT REPORT',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kSage,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Official Health PDF',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Generate a clinical 2-page PDF summary of your health progress, biometric changes, and check-ins to share with your doctor or keep for your files.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: _kSage,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          if (_access != null && !_access!.canDownload) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kIconWashBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kCardBorder),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lock_outline_rounded, size: 18, color: _kAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_access!.lockedText,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kTextPrimary, height: 1.4)),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            _actionButton(
              label: 'Log measurements →',
              onTap: () async {
                final saved = await WeeklyCheckinSheet.logMeasurements();
                if (saved) {
                  final a = await ProgressReportAccess.load();
                  if (mounted) setState(() => _access = a);
                }
              },
            ),
          ] else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isGeneratingPdf ? null : _generateAndDownloadPdf,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kTextPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isGeneratingPdf
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded,
                            size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Download PDF Report',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PDF Generation Action ─────────────────────────────────────────────
  Future<void> _generateAndDownloadPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      if (!Get.isRegistered<ApiProvider>()) {
        Get.put(ApiProvider(), permanent: true);
      }
      if (!Get.isRegistered<ProgressRepository>()) {
        Get.put(ProgressRepository(apiProvider: Get.find<ApiProvider>()),
            permanent: true);
      }

      final repo = Get.find<ProgressRepository>();
      final summary =
          await repo.getSummary(period: 'month') ?? ProgressSummary.empty();
      final weight =
          await repo.getWeight(period: 'month') ?? WeightTrend.empty();
      final hydration =
          await repo.getHydration(period: 'month') ?? HydrationData.empty();
      final symptoms =
          await repo.getSymptoms(period: 'month') ?? SymptomsData.empty();
      final insights =
          await repo.getInsightsHub(period: 'month') ?? InsightsHubData.empty();

      String? userFullName;
      final u = authController.logInUser;
      if (u != null) {
        userFullName = '${u.firstName} ${u.lastName}'.trim();
      }

      final result = await ProgressReportPdfService().generate(
        summary: summary,
        weight: weight,
        hydration: hydration,
        symptoms: symptoms,
        insights: insights,
        userFullName: userFullName,
        // Body measurements from the weekly check-in (Oct 2026).
        measurements: await WeeklyCheckinSheet.loadHistory(),
      );

      await Share.shareXFiles(
        [XFile(result.file.path, mimeType: 'application/pdf')],
        subject: 'FitHer Progress Report',
      );
    } catch (e) {
      Get.snackbar(
        'Export Report',
        'Could not generate report right now. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ─── UI Helpers ────────────────────────────────────────────────────────
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
            blurRadius: 12,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _metricTile({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: _kSage,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _kTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onTap,
    bool isPrimary = true,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPrimary ? _kAccent : _kIconWashBg,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary ? null : Border.all(color: _kCardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isPrimary ? Colors.white : _kTextPrimary,
          ),
        ),
      ),
    );
  }
}
