import 'package:flutter/material.dart';

import '../portal_theme.dart';

/// Page title row: title, short help line, actions on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.sub, this.actions = const []});
  final String title;
  final String? sub;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: PT.t(22, w: FontWeight.w700)),
              if (sub != null) ...[
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Text(sub!, style: PT.t(13, c: PT.sage, h: 1.45)),
                ),
              ],
            ]),
          ),
          ...actions,
        ]),
      );
}

/// Small rounded status chip.
class StatusChip extends StatelessWidget {
  const StatusChip(this.text, {super.key, this.color = PT.green});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: PT.t(11.5, w: FontWeight.w600, c: color)),
      );
}

/// Centered message used for empty / error states.
class PortalEmpty extends StatelessWidget {
  const PortalEmpty({super.key, required this.icon, required this.title, this.sub, this.action});
  final IconData icon;
  final String title;
  final String? sub;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: PT.green),
            const SizedBox(height: 10),
            Text(title, style: PT.t(16, w: FontWeight.w600)),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(sub!, textAlign: TextAlign.center, style: PT.t(13, c: PT.sage)),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ]),
        ),
      );
}

/// Green filled button.
ButtonStyle portalPrimary() => ElevatedButton.styleFrom(
      backgroundColor: PT.green,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13.5),
    );

/// Red outline button.
ButtonStyle portalDanger() => OutlinedButton.styleFrom(
      foregroundColor: PT.red,
      side: const BorderSide(color: Color(0xFFEBC6C6)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13.5),
    );

/// Yes / no confirm dialog. Returns true when confirmed.
Future<bool> portalConfirm(BuildContext context,
    {required String title, required String body, required String yes, bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: PT.t(17, w: FontWeight.w700)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(body, style: PT.t(13.5, h: 1.45)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: PT.t(13.5, c: PT.sage))),
        danger
            ? OutlinedButton(style: portalDanger(), onPressed: () => Navigator.pop(c, true), child: Text(yes))
            : ElevatedButton(style: portalPrimary(), onPressed: () => Navigator.pop(c, true), child: Text(yes)),
      ],
    ),
  );
  return r == true;
}

/// Full-size slip / photo viewer (zoom with mouse wheel or pinch).
void portalShowImage(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.network(url, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(child: Text("Couldn't load the image", style: PT.t(13, c: Colors.white)))),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close, color: Colors.white)),
        ),
      ]),
    ),
  );
}

/// "3 h ago" style time.
String portalAgo(dynamic iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '';
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '$m min ago';
  if (m < 60 * 24) return '${m ~/ 60} h ago';
  return '${m ~/ (60 * 24)} d ago';
}

/// For the 4 mobile-only actions (start class, photos, downloads, notifications).
Widget mobileOnlyNote(String what) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12), border: Border.all(color: PT.line)),
      child: Row(children: [
        const Icon(Icons.phone_iphone_rounded, size: 18, color: PT.green),
        const SizedBox(width: 8),
        Expanded(child: Text('$what: please use the Fit Her mobile app for this.', style: PT.t(12.5))),
      ]),
    );
