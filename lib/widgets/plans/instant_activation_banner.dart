import 'package:flutter/material.dart';

/// Paywall trust strip: online payment activates access immediately.
class InstantActivationBanner extends StatelessWidget {
  const InstantActivationBanner({super.key});

  static const _border = Color(0xFFD8EDD4);
  static const _text = Color(0xFF163220);
  static const _accent = Color(0xFF6DC55A);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt_rounded, size: 18, color: _accent),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'JazzCash / EasyPaisa — instant activation after payment.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
