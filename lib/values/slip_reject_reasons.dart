import 'package:flutter/material.dart';

/// Reasons the admin picks when rejecting a payment slip (Oct 2026).
/// The chosen text is sent to her in the push, so keep them short and kind.
const List<String> kSlipRejectReasons = [
  'Paid to the wrong account',
  'Payment not received',
  'Photo not clear',
  'Slip is too old',
  'Amount is less than the plan price',
  'Slip already used',
];

/// Asks the admin why. Returns the reason, or null if she cancelled.
Future<String?> pickSlipRejectReason(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (c) {
      String? picked;
      return StatefulBuilder(builder: (c, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Why are you rejecting it?',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('She will see this reason.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF66705F))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in kSlipRejectReasons)
                  ChoiceChip(
                    label: Text(r, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5)),
                    selected: picked == r,
                    onSelected: (_) => setState(() => picked = r),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: picked == null ? null : () => Navigator.of(c).pop(picked),
              child: Text('Reject',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: picked == null ? Colors.grey : const Color(0xFFC24A4A))),
            ),
          ],
        );
      });
    },
  );
}
