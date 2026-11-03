import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/Repos/cycle_repo/cycle_data_repository.dart';
import '../../data/controllers/auth_controller/auth_controller.dart';
import '../../data/controllers/cycle_theme_controller/cycle_theme_controller.dart';
import '../../data/controllers/paid_home_controller/paid_home_controller.dart';
import '../../data/services/cycle_engine.dart';
import '../../values/constants.dart';
import '../../values/dimens.dart';
import '../../values/my_colors.dart';
import '../../widgets/app_bar_widget.dart';
import '../../widgets/custom_button.dart';
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class CycleSettingsScreen extends StatefulWidget {
  const CycleSettingsScreen({Key? key}) : super(key: key);

  @override
  State<CycleSettingsScreen> createState() => _CycleSettingsScreenState();
}

class _CycleSettingsScreenState extends State<CycleSettingsScreen> {
  final AuthController _authController = Get.find();
  bool _loading = true;
  bool _hasData = false;
  bool _editing = false;

  // Form values
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _cycleLengthController =
      TextEditingController(text: '28');
  String? _selectedRegularity;
  bool _notSure = false;

  // Read-only display values
  String _displayDate = '';
  String _displayLength = '';
  String _displayRegularity = '';
  String _displayPhase = '';
  int _displayDay = 0;

  @override
  void initState() {
    super.initState();
    _fetchCycleData();
  }

  @override
  void dispose() {
    _cycleLengthController.dispose();
    super.dispose();
  }

  String get _token =>
      _authController.sharedPreferences.getString(Constants.accessToken) ?? '';

  Future<void> _fetchCycleData() async {
    final repo = Get.find<CycleDataRepository>();
    final response = await repo.getCycleData(accessToken: _token);

    if (response.body != null &&
        response.body['status'] == '1' &&
        response.body['data'] != null &&
        response.body['data']['dataProvided'] == 1) {
      final data = response.body['data'];
      final periodDate = data['lastPeriodDate'] as String?;
      final cycleLength = data['averageCycleLength'] as int? ?? 28;
      final regularity = data['isRegular'] as String?;

      _hasData = true;
      _displayLength = '$cycleLength days';
      _displayRegularity = regularity ?? 'Not set';

      if (periodDate != null) {
        final parsed = DateTime.parse(periodDate);
        _selectedDate = parsed;
        _displayDate = DateFormat('MMM dd, yyyy').format(parsed);

        final cycleInfo = CycleEngine.calculate(
          lastPeriodDate: parsed,
          cycleLength: cycleLength,
        );
        if (cycleInfo != null) {
          _displayPhase = cycleInfo.phase;
          _displayDay = cycleInfo.cycleDay;
        }
      }

      _cycleLengthController.text = cycleLength.toString();
      _selectedRegularity = regularity;
    } else {
      _hasData = false;
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _save() async {
    final length = int.tryParse(_cycleLengthController.text) ?? 28;
    if (length < 21 || length > 45) {
      Get.snackbar(
        'Invalid cycle length',
        'Please enter a value between 21 and 45 days',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MyColors.error,
        colorText: Colors.white,
      );
      return;
    }

    final repo = Get.find<CycleDataRepository>();
    final response = await repo.saveCycleData(
      accessToken: _token,
      body: {
        'lastPeriodDate': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'averageCycleLength': length,
        'isRegular': _selectedRegularity,
        'dataProvided': 1,
      },
    );

    if (response.body != null && response.body['status'] == '1') {
      Get.snackbar(
        'Updated',
        'Cycle data updated successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MyColors.buttonColor,
        colorText: Colors.white,
      );
      // Compute new phase client-side and push to global theme immediately.
      final length = int.tryParse(_cycleLengthController.text) ?? 28;
      final cycleInfo = CycleEngine.calculate(
        lastPeriodDate: _selectedDate,
        cycleLength: length,
      );
      try { Get.find<CycleThemeController>().setPhase(cycleInfo?.phase); } catch (_) {}
      // Refresh paid home dashboard in the background.
      try { Get.find<PaidHomeController>().refreshDashboard(); } catch (_) {}
      setState(() {
        _editing = false;
        _loading = true;
      });
      await _fetchCycleData();
    }
  }

  Future<void> _logNewPeriod() async {
    final repo = Get.find<CycleDataRepository>();
    final response = await repo.saveCycleData(
      accessToken: _token,
      body: {
        'lastPeriodDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'averageCycleLength':
            int.tryParse(_cycleLengthController.text) ?? 28,
        'isRegular': _selectedRegularity,
        'dataProvided': 1,
      },
    );

    if (response.body != null && response.body['status'] == '1') {
      Get.snackbar(
        'Period logged',
        'Day 1 — Menstrual phase. Take it easy today.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MyColors.buttonColor,
        colorText: Colors.white,
      );
      setState(() {
        _loading = true;
      });
      await _fetchCycleData();
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final earliest = now.subtract(const Duration(days: 60));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: earliest,
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: MyColors.buttonColor,
              onPrimary: Colors.white,
              onSurface: MyColors.textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: HelpingWidgets().appBarWidget(
        () => Get.back(),
        text: 'Cycle Data',
      ),
      body: _loading
          ? const Center(
              child: FhLoader())
          : SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: Dimens.size20),
                child: _hasData && !_editing
                    ? _buildReadOnlyView(textTheme)
                    : _buildEditForm(textTheme),
              ),
            ),
    );
  }

  Widget _buildReadOnlyView(TextTheme textTheme) {
    final phaseLabels = {
      'menstrual': 'Menstrual Phase \u{1F30A}',
      'follicular': 'Follicular Phase \u{1F331}',
      'ovulatory': 'Ovulatory Phase \u{2600}\u{FE0F}',
      'luteal': 'Luteal Phase \u{1F319}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20.h),

        // Phase card
        if (_displayPhase.isNotEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: MyColors.buttonColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                left: BorderSide(color: MyColors.buttonColor, width: 3),
              ),
            ),
            child: Text(
              '${phaseLabels[_displayPhase] ?? _displayPhase} \u2022 Day $_displayDay',
              style: textTheme.bodyMedium!.copyWith(
                color: MyColors.textColor3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        SizedBox(height: 24.h),

        // Data rows
        _buildInfoRow(textTheme, 'Last period', _displayDate),
        SizedBox(height: 16.h),
        _buildInfoRow(textTheme, 'Cycle length', _displayLength),
        SizedBox(height: 16.h),
        _buildInfoRow(textTheme, 'Regularity', _displayRegularity),
        SizedBox(height: 32.h),

        // Log New Period button
        CustomButton(
          text: 'Log New Period',
          onPressed: _logNewPeriod,
        ),
        SizedBox(height: 12.h),

        // Edit button
        CustomButton(
          text: 'Edit',
          color: Colors.white,
          textColor: MyColors.textColor3,
          borderColor: MyColors.buttonColor,
          onPressed: () {
            setState(() {
              _editing = true;
            });
          },
        ),
        SizedBox(height: 30.h),
      ],
    );
  }

  Widget _buildInfoRow(TextTheme textTheme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium!.copyWith(
            color: MyColors.textColorLow,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: textTheme.bodyMedium!.copyWith(
            color: MyColors.textColor3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20.h),

        Text(
          _hasData ? 'Edit Cycle Data' : 'Add Your Cycle Data',
          style: textTheme.headlineSmall!.copyWith(
            fontSize: 24.sp,
            color: MyColors.textColor3,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: Dimens.size5.h),
        Text(
          'This powers your daily insights and recommendations',
          style: textTheme.titleLarge!.copyWith(
            color: MyColors.textColorLow,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        SizedBox(height: 30.h),

        // Field 1: Last period start date
        Text(
          'Last period start date',
          style: textTheme.bodyMedium!.copyWith(
            color: MyColors.textColor3,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            height: 48,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: MyColors.textFieldColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MyColors.textColor, width: 1),
            ),
            child: Row(
              children: [
                Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                  style: textTheme.bodyMedium!.copyWith(
                    color: MyColors.textColor3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.calendar_today_outlined,
                    color: MyColors.textColorLow, size: 20),
              ],
            ),
          ),
        ),
        SizedBox(height: 28.h),

        // Field 2: Average cycle length
        Text(
          'Average cycle length',
          style: textTheme.bodyMedium!.copyWith(
            color: MyColors.textColor3,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _cycleLengthController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          enabled: !_notSure,
          onChanged: (_) {
            setState(() {
              _notSure = false;
            });
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: MyColors.textFieldColor,
            suffixText: 'days',
            suffixStyle: textTheme.bodyMedium!.copyWith(
              color: MyColors.textColorLow,
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: MyColors.textColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: MyColors.textColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: MyColors.buttonColor, width: 1),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: MyColors.textColor, width: 1),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        GestureDetector(
          onTap: () {
            setState(() {
              _notSure = true;
              _cycleLengthController.text = '28';
            });
          },
          child: Container(
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: _notSure
                  ? MyColors.buttonColor.withOpacity(0.15)
                  : MyColors.textFieldColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _notSure ? MyColors.buttonColor : MyColors.textColor,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                'Not sure',
                style: textTheme.bodyMedium!.copyWith(
                  color:
                      _notSure ? MyColors.buttonColor : MyColors.textColorLow,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 28.h),

        // Field 3: Is your cycle regular?
        Text(
          'Is your cycle regular?',
          style: textTheme.bodyMedium!.copyWith(
            color: MyColors.textColor3,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: ['Yes', 'Somewhat', 'No']
              .map((option) => Padding(
                    padding: EdgeInsets.only(right: 10.w),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRegularity =
                              _selectedRegularity == option.toLowerCase()
                                  ? null
                                  : option.toLowerCase();
                        });
                      },
                      child: Container(
                        height: 40,
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        decoration: BoxDecoration(
                          color: _selectedRegularity == option.toLowerCase()
                              ? MyColors.buttonColor.withOpacity(0.15)
                              : MyColors.textFieldColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                _selectedRegularity == option.toLowerCase()
                                    ? MyColors.buttonColor
                                    : MyColors.textColor,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            option,
                            style: textTheme.bodyMedium!.copyWith(
                              color: _selectedRegularity ==
                                      option.toLowerCase()
                                  ? MyColors.buttonColor
                                  : MyColors.textColorLow,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        SizedBox(height: 32.h),

        // Save button
        CustomButton(
          text: 'Save',
          onPressed: _save,
        ),

        // Cancel button (only in edit mode)
        if (_hasData && _editing) ...[
          SizedBox(height: 12.h),
          CustomButton(
            text: 'Cancel',
            color: Colors.white,
            textColor: MyColors.textColor3,
            borderColor: MyColors.buttonColor,
            onPressed: () {
              setState(() {
                _editing = false;
                _loading = true;
              });
              _fetchCycleData();
            },
          ),
        ],
        SizedBox(height: 30.h),
      ],
    );
  }
}
