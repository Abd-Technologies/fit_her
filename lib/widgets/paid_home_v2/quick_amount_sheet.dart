import 'package:flutter/material.dart';

/// Small bottom sheet for a custom amount: quick picks plus − / + stepper.
/// Used by the water card ("Add water") and the sleep card ("How long did
/// you sleep?"). [onSave] returns true when it saved, then the sheet closes.
class QuickAmountSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<double> presets;
  final double initial;
  final double min;
  final double max;
  final double step;
  final String buttonLabel;
  final String Function(double) format;
  final Color accent;
  final Future<bool> Function(double value) onSave;

  const QuickAmountSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.presets,
    required this.initial,
    required this.min,
    required this.max,
    required this.step,
    required this.buttonLabel,
    required this.format,
    required this.accent,
    required this.onSave,
  });

  static Future<void> show(BuildContext context, QuickAmountSheet sheet) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF163220).withOpacity(0.35),
      builder: (_) => sheet,
    );
  }

  @override
  State<QuickAmountSheet> createState() => _QuickAmountSheetState();
}

class _QuickAmountSheetState extends State<QuickAmountSheet> {
  late double _value;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.clamp(widget.min, widget.max).toDouble();
  }

  void _nudge(int dir) => setState(() {
        _value = (_value + dir * widget.step).clamp(widget.min, widget.max).toDouble();
      });

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await widget.onSave(_value);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    const ink = Color(0xFF163220);
    const soft = Color(0xFF9AB09A);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomSafe + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFD8EDD4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(widget.title,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(height: 2),
          Text(widget.subtitle,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: soft)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.presets.map((p) {
              final on = (p - _value).abs() < 0.001;
              return GestureDetector(
                onTap: () => setState(() => _value = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? widget.accent : widget.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: on ? widget.accent : widget.accent.withOpacity(0.45)),
                  ),
                  child: Text(
                    widget.format(p),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: on ? Colors.white : widget.accent,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _round(Icons.remove_rounded, () => _nudge(-1)),
              SizedBox(
                width: 130,
                child: Text(
                  widget.format(_value),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w800, color: ink),
                ),
              ),
              _round(Icons.add_rounded, () => _nudge(1)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6DC55A),
                disabledBackgroundColor: const Color(0xFF6DC55A).withOpacity(0.5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.buttonLabel,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD8EDD4), width: 1.5),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF163220)),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// "✓ Done · Add more ›" — replaces the buttons once the goal is reached.
// Shared with the sleep card.
// ─────────────────────────────────────────────────────────────────────────────

class CardDoneLine extends StatelessWidget {
  final String done;
  final String action;
  final Color color;
  final VoidCallback onTap;
  const CardDoneLine({
    required this.done,
    required this.action,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 6),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE3EFE0))),
        ),
        child: Row(
          children: [
            Text(done,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6DC55A))),
            const Spacer(),
            Text(action,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

