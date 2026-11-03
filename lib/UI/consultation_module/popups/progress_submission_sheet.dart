import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/controllers/consultation_controller/consultation_controller.dart';
import '../../../helper/device_only_photo_picker.dart';
import '../../../widgets/toasts.dart';
import '../../../widgets/v2/before_after_compare.dart';
import '../../../widgets/v2/measurement_input.dart';
import '../../../widgets/v2/rating_star_row.dart';
import '../../../widgets/v2/v2_bottom_sheet.dart';
import '../../../widgets/v2/v2_buttons.dart';
import 'photo_privacy_notice_sheet.dart';

/// `POPUP_DAY15_PROGRESS` / `POPUP_DAY30_PROGRESS` — single sheet
/// parameterised on `cycle` (15 or 30). Mandatory submission per
/// Section 9; rendered with `dismissible: false` (soft-block —
/// dismissable swipe is off but the user can hit a "Save & exit"
/// gesture by submitting partial then re-opening; build plan risk #5
/// chose soft-block over hard-block).
///
/// Photos NEVER touch the server. They're stored device-only via
/// [DeviceOnlyPhotoPicker] and surfaced inside the app for the user's
/// own before/after view (Section 10). First photo upload triggers
/// `POPUP_PHOTO_PRIVACY_NOTICE` once per user.
class ProgressSubmissionSheet extends StatefulWidget {
  final String planType; // diet | workout | combined
  final int userPlanId;
  final int cycle;       // 15 or 30

  const ProgressSubmissionSheet({
    Key? key,
    required this.planType,
    required this.userPlanId,
    required this.cycle,
  }) : super(key: key);

  static String popupVariableForCycle(int cycle) =>
      cycle == 15 ? 'POPUP_DAY15_PROGRESS' : 'POPUP_DAY30_PROGRESS';

  static const _photoPrivacyShownKey = 'photoPrivacyNoticeShown';
  static const _bucket = 'progress';

  static Future<void> show({
    required String planType,
    required int userPlanId,
    required int cycle,
  }) {
    return V2BottomSheet.show(
      title: cycle == 15 ? 'Day 15 progress' : 'Day 30 progress',
      dismissible: true,
      child: ProgressSubmissionSheet(
        planType: planType,
        userPlanId: userPlanId,
        cycle: cycle,
      ),
    );
  }

  @override
  State<ProgressSubmissionSheet> createState() =>
      _ProgressSubmissionSheetState();
}

class _ProgressSubmissionSheetState extends State<ProgressSubmissionSheet> {
  // Nullable + an explicit error string instead of `late final` — a
  // failed Get.find() used to throw straight out of initState with
  // nothing on screen but the sheet's own loading frame (dismissible:
  // false means no close button, so the user was stuck). Now any
  // failure here renders a real error state with a way out instead of
  // silently hanging (see `_initError` in build()).
  ConsultationController? _ctrl;
  String? _initError;

  // Measurements
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _waist = TextEditingController();
  final TextEditingController _hips = TextEditingController();
  final TextEditingController _chest = TextEditingController();
  final TextEditingController _arms = TextEditingController();
  final TextEditingController _thighs = TextEditingController();

  // Diet section
  String? _clothesFit;
  int? _sleepQuality;
  int? _satisfaction;

  // Workout section
  final TextEditingController _strengthNotes = TextEditingController();

  // Photos (device-only)
  List<String> _photoPaths = const [];
  bool _busy = false;
  bool _addingPhoto = false;

  // Section 9: "previous values pre-filled for comparison". Populated
  // async, same pattern as _loadPhotos below — the form renders
  // immediately either way; the "Last: X kg" ghost text under each
  // measurement just appears once this resolves (or never, on cycle 15 /
  // a first-time submission / a failed fetch — all silent, expected
  // states, not errors).
  Map<String, dynamic>? _previous;

  bool get _showsDiet =>
      widget.planType == 'diet' || widget.planType == 'combined';
  bool get _showsWorkout =>
      widget.planType == 'workout' || widget.planType == 'combined';

  static const _clothesFitOptions = [
    ('tighter', 'Tighter'),
    ('same', 'Same'),
    ('looser', 'Looser'),
  ];

  @override
  void initState() {
    super.initState();
    // Rebuild on typing so the "x of N answered" count updates.
    _weight.addListener(() { if (mounted) setState(() {}); });
    // Marker line — if this never shows up in logcat when the sheet is
    // opened, the widget tree never reached this file at all (stale
    // build / a different widget being shown), which is a completely
    // different bug than anything inside this class.
    debugPrint(
        '[ProgressSubmissionSheet] initState cycle=${widget.cycle} userPlanId=${widget.userPlanId} planType=${widget.planType}');
    try {
      _ctrl = Get.find<ConsultationController>();
    } catch (e, st) {
      debugPrint('[ProgressSubmissionSheet] Get.find<ConsultationController> failed: $e\n$st');
      _initError = 'Could not load this form ($e). Please close and reopen.';
      return; // don't kick off loads against a controller we don't have
    }
    _loadPhotos();
    _loadPrevious();
  }

  Future<void> _loadPrevious() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final previous = await ctrl.loadPreviousProgress(
      userPlanId: widget.userPlanId,
      cycle: widget.cycle,
    );
    if (!mounted || previous == null) return;
    setState(() => _previous = previous);
  }

  double? _prevValue(String key) {
    final v = _previous?[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  void dispose() {
    _weight.dispose();
    _waist.dispose();
    _hips.dispose();
    _chest.dispose();
    _arms.dispose();
    _thighs.dispose();
    _strengthNotes.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    final paths = await DeviceOnlyPhotoPicker.listBucket(
        ProgressSubmissionSheet._bucket);
    if (!mounted) return;
    setState(() => _photoPaths = paths);
  }

  Future<void> _maybeShowPrivacyNotice() async {
    final prefs = await SharedPreferences.getInstance();
    final shown =
        prefs.getBool(ProgressSubmissionSheet._photoPrivacyShownKey) ?? false;
    if (shown) return;
    await PhotoPrivacyNoticeSheet.show();
    await prefs.setBool(
        ProgressSubmissionSheet._photoPrivacyShownKey, true);
  }

  Future<void> _onAddPhoto() async {
    setState(() => _addingPhoto = true);
    await _maybeShowPrivacyNotice();
    if (!mounted) {
      setState(() => _addingPhoto = false);
      return;
    }
    // Show source picker — gallery vs camera. Keeping inline (small)
    // rather than another shared widget.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final source = await Get.bottomSheet<ImageSource>(
      Container(
        padding: EdgeInsets.fromLTRB(0, 12, 0, 12 + bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFF6DC55A)),
              title: const Text('Pick from gallery'),
              onTap: () => Get.back(result: ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFF6DC55A)),
              title: const Text('Take a new photo'),
              onTap: () => Get.back(result: ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      setState(() => _addingPhoto = false);
      return;
    }
    if (source == null) {
      setState(() => _addingPhoto = false);
      return;
    }
    final path = await DeviceOnlyPhotoPicker.pickAndStore(
      bucket: ProgressSubmissionSheet._bucket,
      source: source,
    );
    if (!mounted) return;
    setState(() => _addingPhoto = false);
    if (path != null) {
      await _loadPhotos();
    }
  }

  Future<void> _onDeletePhoto(String path) async {
    final ok = await DeviceOnlyPhotoPicker.delete(path);
    if (!mounted) return;
    if (ok) await _loadPhotos();
  }

  void _openCompare() {
    if (_photoPaths.length < 2) return;
    // Newest is _photoPaths[0] (listBucket sorts newest-first); pair it
    // with the oldest for the most informative compare.
    final after = _photoPaths.first;
    final before = _photoPaths.last;
    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: BeforeAfterCompare(
                beforePath: before,
                afterPath: after,
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                onPressed: () => Get.back<dynamic>(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Required questions, so Submit can say "1 of 3 answered".
  final _weightKey = GlobalKey();
  final _clothesKey = GlobalKey();
  final _satisfactionKey = GlobalKey();

  List<MapEntry<GlobalKey, bool>> get _required => [
        MapEntry(_weightKey, _weight.text.trim().isNotEmpty),
        if (_showsDiet) MapEntry(_clothesKey, _clothesFit != null),
        if (_showsDiet) MapEntry(_satisfactionKey, _satisfaction != null),
      ];

  void _nudgeMissing() {
    final miss = _required.firstWhere((e) => !e.value);
    final ctx = miss.key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.2);
    }
  }

  bool get _canSubmit {
    // Minimum required: weight. Other measurements are optional but
    // strongly encouraged. Diet section requires clothesFit.
    if (_weight.text.trim().isEmpty) return false;
    if (_showsDiet && (_clothesFit == null || _satisfaction == null)) {
      return false;
    }
    return true;
  }

  double? _parseDouble(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Map<String, dynamic> _buildBody() {
    return {
      'userPlanId': widget.userPlanId,
      'cycle': widget.cycle,
      if (_parseDouble(_weight.text) != null)
        'weightKg': _parseDouble(_weight.text),
      if (_parseDouble(_waist.text) != null)
        'waistCm': _parseDouble(_waist.text),
      if (_parseDouble(_hips.text) != null) 'hipsCm': _parseDouble(_hips.text),
      if (_parseDouble(_chest.text) != null)
        'chestCm': _parseDouble(_chest.text),
      if (_parseDouble(_arms.text) != null) 'armsCm': _parseDouble(_arms.text),
      if (_parseDouble(_thighs.text) != null)
        'thighsCm': _parseDouble(_thighs.text),
      if (_showsDiet) ...{
        'clothesFit': _clothesFit,
        if (_sleepQuality != null) 'sleepQuality': _sleepQuality,
        if (_satisfaction != null) 'satisfaction': _satisfaction,
      },
      if (_showsWorkout && _strengthNotes.text.trim().isNotEmpty)
        'strengthNotes': _strengthNotes.text.trim(),
    };
  }

  Future<void> _submit() async {
    final ctrl = _ctrl;
    if (!_canSubmit || ctrl == null) return;
    setState(() => _busy = true);
    final ok = await ctrl.submitProgress(_buildBody());
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    // Server retires the matching popup variable on success; mirror
    // client-side as defence in depth.
    await ctrl.completePopup(
      ProgressSubmissionSheet.popupVariableForCycle(widget.cycle),
      metadata: {'cycle': widget.cycle, 'userPlanId': widget.userPlanId},
    );
    Get.back<dynamic>();
    CustomToast.successToast(
        msg: 'Saved. Thank you — your dietitian will see this.');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '[ProgressSubmissionSheet] build() cycle=${widget.cycle} initError=$_initError');

    if (_initError != null) {
      // Visible, actionable failure instead of a silent hang. dismissible
      // is false on the parent sheet (no close icon in the shell), so
      // this is the only way out if setup failed.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE05C5C), size: 40),
          const SizedBox(height: 12),
          const Text(
            "Something went wrong loading this form.",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A3A22),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _initError!,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF7A8C78),
            ),
          ),
          const SizedBox(height: 20),
          V2SecondaryButton(
            label: 'Close',
            onPressed: () => Get.back<dynamic>(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.cycle == 15
              ? "We need this to plan your next 15 days."
              : "We need this to plan your renewal and next cycle.",
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Color(0xFF7A8C78),
            height: 1.5,
          ),
        ),

        // ── Measurements grid ─────────────────────────────
        const SizedBox(height: 22),
        // Same card + header look as the Log measurements screen.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEFF4EC)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF1A3A22).withValues(alpha: 0.04), offset: const Offset(0, 4), blurRadius: 14),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFF6FBF3), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.straighten_outlined, size: 16, color: Color(0xFF6DC55A)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Body Measurements',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A3A22))),
              SizedBox(height: 1),
              Text('Weight in kg · measure in cm consistently',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF7A8C78))),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        const _MeasurementGuide(),
        const SizedBox(height: 16),
        MeasurementInput(
          key: _weightKey,
          label: 'Current weight',
          unit: 'kg',
          controller: _weight,
          previousValue: _prevValue('weightKg'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: MeasurementInput(
                label: 'Waist',
                unit: 'cm',
                controller: _waist,
                previousValue: _prevValue('waistCm'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MeasurementInput(
                label: 'Hips',
                unit: 'cm',
                controller: _hips,
                previousValue: _prevValue('hipsCm'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MeasurementInput(
                label: 'Chest',
                unit: 'cm',
                controller: _chest,
                previousValue: _prevValue('chestCm'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MeasurementInput(
                label: 'Arms',
                unit: 'cm',
                controller: _arms,
                previousValue: _prevValue('armsCm'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MeasurementInput(
          label: 'Thighs',
          unit: 'cm',
          controller: _thighs,
          previousValue: _prevValue('thighsCm'),
        ),
          ]),
        ),

        // ── Diet-specific ─────────────────────────────────
        if (_showsDiet) ...[
          const SizedBox(height: 22),
          const _SectionHeader('How are you feeling?'),
          const SizedBox(height: 12),
          _SectionLabel('Clothes are fitting', key: _clothesKey),
          const SizedBox(height: 6),
          Row(
            children: _clothesFitOptions
                .map((o) => Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 8),
                        child: _PillChoice(
                          label: o.$2,
                          selected: _clothesFit == o.$1,
                          onTap: () =>
                              setState(() => _clothesFit = o.$1),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          const _SectionLabel('Sleep quality this cycle'),
          const SizedBox(height: 8),
          RatingStarRow(
            value: _sleepQuality,
            onChanged: (v) => setState(() => _sleepQuality = v),
          ),
          const SizedBox(height: 14),
          _SectionLabel('Overall satisfaction', key: _satisfactionKey),
          const SizedBox(height: 8),
          RatingStarRow(
            value: _satisfaction,
            onChanged: (v) => setState(() => _satisfaction = v),
          ),
        ],

        // ── Workout-specific ──────────────────────────────
        if (_showsWorkout) ...[
          const SizedBox(height: 22),
          const _SectionHeader('Strength + stamina'),
          const SizedBox(height: 12),
          const _SectionLabel(
              'What feels different from when you started?'),
          const SizedBox(height: 6),
          TextField(
            controller: _strengthNotes,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'e.g. "I can hold plank twice as long" or "stairs are easier"',
              hintStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Color(0xFF9AB09A),
              ),
              filled: true,
              fillColor: const Color(0xFFF5FDF2),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFFC8DEC4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFFC8DEC4)),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF1A3A22),
            ),
          ),
        ],

        // ── Photos (optional, device-only) ────────────────
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: _SectionHeader('Photos (optional)')),
            if (_photoPaths.length >= 2)
              TextButton.icon(
                onPressed: _openCompare,
                icon: const Icon(Icons.compare_arrows_rounded,
                    size: 16, color: Color(0xFF6DC55A)),
                label: const Text(
                  'Compare',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6DC55A),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Stored only on your phone. Not uploaded.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Color(0xFF9AB09A),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photoPaths.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i == 0) {
                return _AddPhotoTile(
                  busy: _addingPhoto,
                  onTap: _onAddPhoto,
                );
              }
              final path = _photoPaths[i - 1];
              return _PhotoThumb(
                path: path,
                onDelete: () => _onDeletePhoto(path),
              );
            },
          ),
        ),

        // ── Submit ────────────────────────────────────────
        const SizedBox(height: 24),
        V2PrimaryButton(
          label: !_canSubmit
              ? '${_required.where((e) => e.value).length} of ${_required.length} answered · Next →'
              : widget.cycle == 15
                  ? 'Submit Day 15 progress'
                  : 'Submit Day 30 progress',
          busy: _busy,
          onPressed: _busy ? null : (_canSubmit ? _submit : _nudgeMissing),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => Get.back<dynamic>(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              foregroundColor: const Color(0xFF7A8C78),
            ),
            child: const Text(
              'Maybe Later',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A8C78),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Private helpers ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1A3A22),
          letterSpacing: -0.2,
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A3A22),
          letterSpacing: 0.4,
        ),
      );
}

/// Section 9: "body measurements with a diagram of where to measure".
/// A small labelled body silhouette + a one-line consistency tip — not
/// meant to be anatomically precise, just enough for a user who's never
/// taken these measurements before to know roughly where each one goes.
class _MeasurementGuide extends StatelessWidget {
  const _MeasurementGuide();

  static const Color _label = Color(0xFF1A3A22);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FDF2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8DEC4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 118,
            child: CustomPaint(painter: _BodyDiagramPainter()),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where to measure',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _label,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Chest: fullest point  ·  Waist: narrowest point\n'
                  'Hips: widest point  ·  Arms: relaxed bicep  ·  Thighs: fullest point\n\n'
                  'Same time of day, same conditions each time keeps the comparison fair.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    height: 1.5,
                    color: Color(0xFF5C7059),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyDiagramPainter extends CustomPainter {
  static const Color _line = Color(0xFF1A3A22);
  static const Color _marker = Color(0xFF6DC55A);

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final marker = Paint()
      ..color = _marker
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Head.
    canvas.drawCircle(Offset(cx, h * 0.08), h * 0.07, outline);
    // Neck + torso outline (a simple tapered silhouette).
    final torso = Path()
      ..moveTo(cx - w * 0.16, h * 0.18) // shoulder L
      ..lineTo(cx + w * 0.16, h * 0.18) // shoulder R
      ..lineTo(cx + w * 0.22, h * 0.34) // chest R
      ..lineTo(cx + w * 0.13, h * 0.46) // waist R
      ..lineTo(cx + w * 0.20, h * 0.58) // hip R
      ..lineTo(cx + w * 0.14, h * 0.92) // leg R
      ..moveTo(cx - w * 0.16, h * 0.18)
      ..lineTo(cx - w * 0.22, h * 0.34) // chest L
      ..lineTo(cx - w * 0.13, h * 0.46) // waist L
      ..lineTo(cx - w * 0.20, h * 0.58) // hip L
      ..lineTo(cx - w * 0.14, h * 0.92); // leg L
    canvas.drawPath(torso, outline);
    // Arms (relaxed, at the sides).
    canvas.drawLine(
        Offset(cx - w * 0.16, h * 0.19), Offset(cx - w * 0.30, h * 0.42), outline);
    canvas.drawLine(
        Offset(cx + w * 0.16, h * 0.19), Offset(cx + w * 0.30, h * 0.42), outline);

    // Measurement markers — short horizontal dashes at each height.
    void drawMeasureLine(double heightFrac, double halfWidthFrac) {
      final y = h * heightFrac;
      final segments = 5;
      final totalW = w * halfWidthFrac * 2;
      final start = cx - w * halfWidthFrac;
      final dash = totalW / (segments * 1.6);
      for (var i = 0; i < segments; i++) {
        final x0 = start + i * dash * 1.6;
        canvas.drawLine(Offset(x0, y), Offset(x0 + dash, y), marker);
      }
    }

    drawMeasureLine(0.34, 0.24); // chest
    drawMeasureLine(0.46, 0.16); // waist
    drawMeasureLine(0.58, 0.22); // hips
    drawMeasureLine(0.30, 0.32); // arms (bicep height, wide to reach the arm line)
    drawMeasureLine(0.75, 0.16); // thighs
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PillChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PillChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1A3A22)
              : const Color(0xFFF5FDF2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF1A3A22)
                : const Color(0xFFC8DEC4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF1A3A22),
          ),
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  const _AddPhotoTile({required this.busy, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0xFFF5FDF2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFC8DEC4),
            style: BorderStyle.solid,
            width: 1.2,
          ),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF6DC55A)),
                  ),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded,
                      color: Color(0xFF6DC55A), size: 26),
                  SizedBox(height: 4),
                  Text(
                    'Add',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A3A22),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String path;
  final VoidCallback onDelete;
  const _PhotoThumb({required this.path, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            File(path),
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xCC1A3A22),
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
