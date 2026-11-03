import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// V2BottomSheet — shared shell for every paid-user pop-up (Phase 2C).
/// Mirrors the V2 visual language used in `paid_home_v2/`: mint page
/// bg `#E8F4E0`, 25-radius top corners, dark `#0D2014` text colour, soft
/// drag handle, optional close button.
///
/// Use the static `show<T>()` helper instead of constructing directly:
///
///   final result = await V2BottomSheet.show<bool>(
///     title: 'Day 7 review',
///     child: const Day7ReviewBody(),
///     dismissible: false, // mandatory popups can pass false
///   );
///
/// `dismissible=false` blocks tap-outside / swipe-down dismissal — used
/// for the mandatory Day 15/30 progress submission (build plan risk #5,
/// soft-block default — popup persists until submitted).
class V2BottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool dismissible;

  /// false = skip the built-in title/close row entirely, for sheets that
  /// draw their own header (e.g. BookInitialReminderSheet's avatar +
  /// eyebrow + title + close layout). Default true keeps every existing
  /// sheet exactly as it was.
  final bool showHeader;

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _drag = Color(0xFFC8DEC4);
  static const Color _textDark = Color(0xFF1A3A22);
  static const Color _textMuted = Color(0xFF7A8C78);
  static const BorderRadius _topRadius = BorderRadius.only(
    topLeft: Radius.circular(25),
    topRight: Radius.circular(25),
  );

  const V2BottomSheet({
    Key? key,
    this.title,
    required this.child,
    this.dismissible = true,
    this.showHeader = true,
  }) : super(key: key);

  /// Helper that wraps `Get.bottomSheet` with the V2 shell. Returns
  /// whatever the body popped via `Get.back(result: ...)`.
  static Future<T?> show<T>({
    String? title,
    required Widget child,
    bool dismissible = true,
    bool showHeader = true,
  }) {
    return Get.bottomSheet<T>(
      V2BottomSheet(
        title: title,
        dismissible: dismissible,
        showHeader: showHeader,
        child: child,
      ),
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      // Without an explicit barrierColor this had no scrim at all, so
      // whatever screen opened the sheet (e.g. PlanReviewEditScreen)
      // stayed fully lit behind it — normal-contrast, fully readable —
      // instead of dimmed. Combined with the keyboard eating a big
      // chunk of the viewport for a short form like Edit Meal, that
      // read as the background "bleeding through" the sheet rather than
      // a page sitting politely behind a modal.
      barrierColor: Colors.black.withOpacity(0.45),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      // AnimatedPadding (not a static Padding) so the sheet slides up in
      // step with the keyboard's own show/hide animation instead of
      // snapping to the new inset a frame late — that one-frame lag was
      // the other half of the "content looks like it's floating loose
      // over the page" glitch on lower-end devices.
      // Oct 2026: no keyboard padding here any more. Get.bottomSheet
      // already lifts the sheet above the keyboard; adding it again here
      // lifted it TWICE, so with the keyboard open the sheet floated
      // half-way up the screen with Home showing below it (weekly
      // check-in weight box).
      child: Padding(
        padding: EdgeInsets.zero,
        child: Container(
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: _topRadius,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          // Fits above the keyboard when it is open.
          constraints: BoxConstraints(
            maxHeight: (MediaQuery.of(context).size.height - viewInsets) * 0.92,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle (only visible when dismissible — mandatory
              // popups have no pull-down affordance).
              if (dismissible)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _drag,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),

              // Title row + close button.
              if (showHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: title != null
                          ? Text(
                              title!,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (dismissible)
                      IconButton(
                        icon: const Icon(Icons.close, size: 22, color: _textMuted),
                        onPressed: () => Get.back<dynamic>(),
                      )
                    else
                      const SizedBox(width: 8, height: 44),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
