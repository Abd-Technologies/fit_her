import 'package:flutter/material.dart';

/// Fixed options for a workout class, shared by the trainer's Class
/// Details screen and the admin's Add Trainer Slots form, so both always
/// save the same spelling. The client screens colour and label classes by
/// these words (Yoga = purple, HIIT = orange, ...); a typo like "yogaa"
/// fell back to the plain default style.
const List<String> kClassTypeOptions = [
  'Yoga',
  'Pilates',
  'Zumba',
  'HIIT',
  'Strength',
  'Low Impact',
];
const List<String> kClassIntensityOptions = ['Low', 'Medium', 'High'];
const String kClassOptionOther = 'Other';

const Color _kInk = Color(0xFF1A3A22);
const Color _kAccent = Color(0xFF6DC55A);
const Color _kBorder = Color(0xFFD8EDD4);
const Color _kMuted = Color(0xFF7A8C78);

/// Tappable option chips bound to a [TextEditingController]: picking an
/// option writes it into the controller, so existing save code that reads
/// `controller.text` keeps working unchanged.
///
/// With [allowOther], an "Other" chip opens a text box for a custom value
/// (typed straight into the same controller). An existing value that
/// isn't one of the options shows as "Other" with the text filled in.
class ClassOptionPicker extends StatefulWidget {
  final String label;
  final List<String> options;
  final TextEditingController controller;
  final bool allowOther;

  const ClassOptionPicker({
    super.key,
    required this.label,
    required this.options,
    required this.controller,
    this.allowOther = false,
  });

  @override
  State<ClassOptionPicker> createState() => _ClassOptionPickerState();
}

class _ClassOptionPickerState extends State<ClassOptionPicker> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    final current = widget.controller.text.trim();
    if (current.isEmpty) return;
    final match = widget.options.firstWhere(
      (o) => o.toLowerCase() == current.toLowerCase(),
      orElse: () => '',
    );
    if (match.isNotEmpty) {
      _selected = match;
      widget.controller.text = match; // normalise spelling/case
    } else if (widget.allowOther) {
      _selected = kClassOptionOther;
    }
  }

  void _pick(String o) {
    setState(() {
      if (_selected == o) {
        _selected = null; // tap again to clear
        widget.controller.text = '';
      } else {
        _selected = o;
        widget.controller.text = o == kClassOptionOther ? '' : o;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.options, if (widget.allowOther) kClassOptionOther];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _kInk,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: all.map((o) {
            final on = o == _selected;
            return GestureDetector(
              onTap: () => _pick(o),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
        ),
        if (_selected == kClassOptionOther) ...[
          const SizedBox(height: 10),
          TextField(
            controller: widget.controller,
            maxLength: 30,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 13.5, color: _kInk),
            decoration: InputDecoration(
              hintText: 'Type the class name',
              hintStyle: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, color: _kMuted),
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
