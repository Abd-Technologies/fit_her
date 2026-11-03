import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/diet_contoller/diet_controller.dart';
import '../../../data/models/get_clients_diet.dart';
import 'client_consultation_screen.dart';
import 'generate_plan_screen.dart';
import 'plan_review_edit_screen.dart';

/// Every client who has had her consultation but hasn't received her
/// plan yet, most urgent first. Each card walks the dietitian through
/// the same three steps:
///   1. Review form   (edit the pre-consultation form, overwrites hers)
///   2. Generate plan (AI builds a draft from that form)
///   3. Deliver       (review the draft, edit meals, send it)
/// The plan is due 48 hours after the consultation ends.
class PlansToDeliverScreen extends StatefulWidget {
  const PlansToDeliverScreen({super.key});

  @override
  State<PlansToDeliverScreen> createState() => _PlansToDeliverScreenState();
}

const _kBg = Color(0xFFE8F4E0);
const _kInk = Color(0xFF1A3A22);
const _kSoft = Color(0xFF7A8C78);
const _kAccent = Color(0xFF6DC55A);
const _kBorder = Color(0xFFD8EDD4);
const _kAlert = Color(0xFFC0392B);
const _kWarn = Color(0xFFC77B2B);

class _PlansToDeliverScreenState extends State<PlansToDeliverScreen> {
  final DietController _diet = Get.find<DietController>();

  @override
  void initState() {
    super.initState();
    // After the first frame: starting the load flips observable state
    // that other screens' Obx widgets watch, and doing that while this
    // screen is still being built crashed with "markNeedsBuild called
    // during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    _diet.clientsOfDietFunc();
  }

  List<Cliet> _owed() {
    final list = (_diet.getDietClientsModel?.cliets ?? [])
        .where((c) => c.planPipeline?.owed == true)
        .toList();
    list.sort((a, b) =>
        a.planPipeline!.hoursLeft.compareTo(b.planPipeline!.hoursLeft));
    return list;
  }

  Future<void> _go(Widget Function() page) async {
    await Get.to<dynamic>(page);
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kInk),
        title: const Text(
          'Plans to deliver',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kInk,
          ),
        ),
      ),
      body: Obx(() {
        if (!_diet.clientDataLoad.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
            ),
          );
        }
        final error = _diet.clientDataError.value;
        if (error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 36, color: _kSoft),
                  const SizedBox(height: 10),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 14, color: _kInk),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text(
                      'Try again',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        color: _kAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final owed = _owed();
        return RefreshIndicator(
          color: _kAccent,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              const Text(
                "Every plan is due within 2 working days of the consultation (weekends don't count).",
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kSoft),
              ),
              const SizedBox(height: 14),
              if (owed.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text(
                      "You're all caught up. No plans owed right now.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 14, color: _kSoft),
                    ),
                  ),
                )
              else
                ...owed.map((c) => _card(c)),
            ],
          ),
        );
      }),
    );
  }

  Widget _card(Cliet c) {
    final p = c.planPipeline!;
    final name = c.user == null
        ? 'Client'
        : '${c.user!.firstName} ${c.user!.lastName}'.trim();
    final hasDraft = p.draftPlanId != null;

    final Color timeColor = p.overdue
        ? _kAlert
        : p.hoursLeft <= 12
            ? _kWarn
            : _kAccent;
    final String timeLabel = p.overdue
        ? 'Overdue by ${_fmtHours(-p.hoursLeft)}'
        : 'Due in ${_fmtHours(p.hoursLeft)}';

    // Next step decides the main button.
    late final String cta;
    late final VoidCallback onCta;
    if (hasDraft) {
      cta = 'Review and deliver';
      onCta = () => _go(() => PlanReviewEditScreen(dietPlanId: p.draftPlanId!));
    } else if (!p.formReviewed) {
      cta = 'Review form';
      onCta = () => _go(() =>
          ClientConsultationScreen(userId: c.user?.id ?? 0, clientName: name));
    } else {
      cta = 'Generate AI plan';
      onCta = () => _go(() => GeneratePlanScreen(
            userId: c.user?.id ?? 0,
            userPlanId: c.id,
            userDisplayName: name,
          ));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.overdue ? _kAlert.withOpacity(0.35) : _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: timeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  timeLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: timeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _step('1', 'Form', p.formReviewed),
              _line(p.formReviewed),
              _step('2', 'AI plan', hasDraft),
              _line(hasDraft),
              _step('3', 'Deliver', false),
            ],
          ),
          if (!p.hasForm) ...[
            const SizedBox(height: 10),
            const Text(
              "She hasn't filled her form. Fill it with her before generating.",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: _kWarn),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onCta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.overdue ? _kAlert : _kAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    cta,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Skip straight to generating if the form was fine as is.
              if (!hasDraft && !p.formReviewed) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _go(() => GeneratePlanScreen(
                        userId: c.user?.id ?? 0,
                        userPlanId: c.id,
                        userDisplayName: name,
                      )),
                  child: const Text(
                    'Skip to plan',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _kInk,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtHours(int h) {
    if (h < 1) return 'under 1h';
    if (h < 24) return '${h}h';
    final d = h ~/ 24;
    final r = h % 24;
    return r == 0 ? '${d}d' : '${d}d ${r}h';
  }

  Widget _step(String n, String label, bool done) {
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? _kAccent : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: done ? _kAccent : _kBorder, width: 1.5),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : Text(
                  n,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _kSoft,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: done ? _kInk : _kSoft,
          ),
        ),
      ],
    );
  }

  Widget _line(bool done) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
          color: done ? _kAccent : _kBorder,
        ),
      );
}
