import 'package:flutter/material.dart';

import 'anim/fh_loader.dart';

/// App-wide loading placeholder: the Fit Her loader (was a plain circle).
class CircularProgress extends StatelessWidget {
  const CircularProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: FhLoader());
  }
}
