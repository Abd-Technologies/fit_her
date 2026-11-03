import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:fitness_zone_2/UI/auth_module/sign_up_screen/goal_screen.dart';
import 'package:fitness_zone_2/UI/auth_module/sign_up_screen/sign_up_screen_questions.dart';
import 'package:fitness_zone_2/data/controllers/auth_controller/auth_controller.dart';
import 'package:fitness_zone_2/values/constants.dart';

/// Read-only view of the signed-in user's personal details. Reached from
/// the V1 Profile screen → "Personal details" menu row. An "Edit" button
/// at the bottom routes into the existing GoalScreen → SignUpScreenQuestions
/// flow so we don't fork the edit path.
class PersonalDetailsScreen extends StatelessWidget {
  PersonalDetailsScreen({super.key});

  final AuthController authController = Get.find();

  static const _kCanvas = Color(0xFFF9FCF7);
  static const _kCardBorder = Color(0xFFEFF4EC);
  static const _kIconWashBg = Color(0xFFF6FBF3);
  static const _kTextPrimary = Color(0xFF1A3A22);
  static const _kSage = Color(0xFF7A8C78);
  static const _kAccent = Color(0xFF6DC55A);

  @override
  Widget build(BuildContext context) {
    final phone = (authController.logInUser?.phone != null &&
            authController.logInUser!.phone.trim().isNotEmpty)
        ? authController.logInUser!.phone
        : (authController.sharedPreferences.getString(Constants.userMobileNumber) ?? '');

    final rows = <_DetailRow>[
      _DetailRow('First name', authController.editFirstName.text),
      _DetailRow('Last name', authController.editLastName.text),
      _DetailRow('Email', authController.editEmail.text),
      _DetailRow('Phone', phone),
      _DetailRow('Age', authController.editAge.text),
      _DetailRow('Height', authController.editHeight.text),
      _DetailRow('Weight', authController.editWeight.text),
      _DetailRow('BMI', authController.editBmi.text),
      _DetailRow('Main goal', authController.mainGoal.value),
    ];

    return Scaffold(
      backgroundColor: _kCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(),
              const SizedBox(height: 18),
              const Text(
                'Personal details',
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
                'Your account information.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _kSage,
                ),
              ),
              const SizedBox(height: 18),
              _card(
                child: Column(
                  children: [
                    for (int i = 0; i < rows.length; i++) ...[
                      _detailRow(rows[i]),
                      if (i < rows.length - 1)
                        Container(height: 1, color: _kCardBorder),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _editButton(),
              const SizedBox(height: 28),
              // Oct 2026: moved here from the main Profile screen (it sat
              // right under "Sign out", too easy to hit by mistake).
              _deleteAccount(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deleteAccount() {
    return Column(children: [
      Container(height: 1, color: const Color(0xFFE6EEE2)),
      const SizedBox(height: 14),
      const Text(
        'Delete your account and all your data. This can\'t be undone.',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF8A9A88), height: 1.4),
      ),
      TextButton(
        onPressed: () => Get.defaultDialog(
          title: 'Delete your account?',
          content: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Your profile, plan history and progress will be removed. This can\'t be undone.',
              textAlign: TextAlign.center,
            ),
          ),
          textConfirm: 'Delete',
          textCancel: 'Keep my account',
          confirmTextColor: Colors.white,
          buttonColor: const Color(0xFFC24A4A),
          onConfirm: () {
            Get.back();
            authController.deleteUser();
          },
        ),
        child: const Text(
          'Delete account',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFFC24A4A),
          ),
        ),
      ),
    ]);
  }

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
            child: const Icon(Icons.arrow_back,
                size: 16, color: _kTextPrimary),
          ),
        ),
        const Spacer(),
        const Text(
          'Profile',
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

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kTextPrimary.withOpacity(0.06),
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _detailRow(_DetailRow row) {
    final value = row.value.trim().isEmpty ? '—' : row.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              row.label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _kSage,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Get.to(() => GoalScreen(
            showBackButton: true,
            initialGoal: Get.find<AuthController>().mainGoal.value,
            onNext: (goal) {
              Get.to(() => SignUpScreenQuestions(selectedGoal: goal));
            },
          )),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kAccent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kAccent.withOpacity(0.30),
              offset: const Offset(0, 4),
              blurRadius: 14,
            ),
          ],
        ),
        child: const Text(
          'Edit details',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}
