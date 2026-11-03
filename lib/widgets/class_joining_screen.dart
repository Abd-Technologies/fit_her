import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/controllers/paid_home_controller/paid_home_controller.dart';

/// Full-screen "Joining live class" wait (Oct 2026). Shown from the
/// moment she taps Join until Zoom opens (HelpingWidgets.startMeeting
/// closes it). Steps tick on by themselves; a tip changes every 3 s so the
/// few seconds Zoom needs feel short. "×" just closes this screen.
class ClassJoiningScreen extends StatefulWidget {
  const ClassJoiningScreen({super.key, this.className, this.trainerName, this.onClose});

  final String? className;
  final String? trainerName;
  final VoidCallback? onClose;

  @override
  State<ClassJoiningScreen> createState() => _ClassJoiningScreenState();
}

class _ClassJoiningScreenState extends State<ClassJoiningScreen> with TickerProviderStateMixin {
  static const _green = Color(0xFF6DC55A);
  static const _mint = Color(0xFFA8F0C0);

  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);

  int _step = 0; // 0 saving spot, 1 connecting, 2 camera & sound, 3 all done
  int _tip = 0;
  final List<Timer> _timers = [];
  late final List<String> _tips = _buildTips();

  String get _trainer {
    final t = (widget.trainerName ?? '').trim();
    return t.isEmpty ? '' : t.split(RegExp(r'\s+')).first;
  }

  List<String> _buildTips() {
    final tips = <String>[
      'Keep a glass of water close 💧',
      'Turn your phone sideways for the full view 📱',
      'Clear a little space on the floor 🧘',
      'Camera is optional. Join the way you feel comfy 💚',
    ];
    try {
      final phase = Get.find<PaidHomeController>().dashboard.value?.cycle?.phase?.toLowerCase();
      const byPhase = {
        'menstrual': 'Period days: go gentle, every move counts 🌸',
        'follicular': 'Energy is rising: a great day to try a little more ⚡',
        'ovulation': 'Ovulation: your strongest days, push a little harder ✨',
        'luteal': 'Luteal phase: steady pace, breathe through it 🌙',
      };
      final line = phase == null ? null : byPhase[phase];
      if (line != null) tips.insert(1, line);
    } catch (_) {}
    return tips;
  }

  @override
  void initState() {
    super.initState();
    _timers.add(Timer(const Duration(milliseconds: 900), () => _go(1)));
    _timers.add(Timer(const Duration(milliseconds: 2600), () => _go(2)));
    _timers.add(Timer(const Duration(milliseconds: 4800), () => _go(3)));
    _timers.add(Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _tip = (_tip + 1) % _tips.length);
    }));
  }

  void _go(int s) {
    if (mounted) setState(() => _step = s);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final name = (widget.className ?? '').trim().isEmpty ? 'Live class' : widget.className!.trim();
    final initial = _trainer.isNotEmpty ? _trainer[0].toUpperCase() : '💪';
    final steps = [
      'Saving your spot',
      _trainer.isEmpty ? 'Connecting to the class' : "Connecting to $_trainer's room",
      'Setting up camera & sound',
    ];

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.7, -1.0),
              radius: 1.4,
              colors: [Color(0xFF2E5E36), Color(0xFF123019), Color(0xFF0D2413)],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFCFE0CA)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(
                      color: _mint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('● JOINING LIVE CLASS',
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700,
                            letterSpacing: 1.0, color: _mint)),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 190,
                    height: 190,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, __) {
                            final t = reduce ? 0.0 : _pulse.value;
                            return Container(
                              width: 146 + 12 * t,
                              height: 146 + 12 * t,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _green.withValues(alpha: 0.12 + 0.08 * t),
                              ),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: _spin,
                          builder: (_, __) => Transform.rotate(
                            angle: reduce ? 0 : _spin.value * 2 * math.pi,
                            child: const CustomPaint(size: Size(190, 190), painter: _RingPainter()),
                          ),
                        ),
                        Container(
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF7FD06A), Color(0xFF3E8E36)],
                            ),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 4),
                          ),
                          child: Text(initial,
                              style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 38, fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  if (_trainer.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('with $_trainer',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Color(0xFFCFE0CA))),
                  ],
                  const SizedBox(height: 24),
                  for (var i = 0; i < steps.length; i++) _stepRow(steps[i], i),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      key: ValueKey(_tip),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('WHILE YOU WAIT',
                              style: TextStyle(
                                  fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8, color: _mint)),
                          const SizedBox(height: 3),
                          Text(_tips[_tip],
                              style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 12.5, height: 1.45, color: Color(0xFFE3EFDF))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("You're counted from the moment you joined",
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF9FB79A))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepRow(String text, int i) {
    final done = _step > i;
    final now = _step == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: done
                ? Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: _green),
                    child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                  )
                : now
                    ? const CircularProgressIndicator(strokeWidth: 1.8, color: _mint)
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                        ),
                      ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: done || now ? FontWeight.w600 : FontWeight.w400,
                color: done || now ? Colors.white : Colors.white.withValues(alpha: 0.45),
              ),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(c, r, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6DC55A);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, math.pi * 0.55, false, arc);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
