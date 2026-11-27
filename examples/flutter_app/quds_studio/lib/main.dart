import 'package:flutter/material.dart';

import 'studio_page.dart';

void main() {
  runApp(const QudsStudioApp(autoPlayAnimations: true));
}

class QudsStudioApp extends StatelessWidget {
  const QudsStudioApp({
    super.key,
    this.initialPresetIndex = 0,
    this.initialArabic = true,
    this.initialDark = true,
    this.autoRunInitial = true,
    this.autoPlayAnimations = false,
  });

  final int initialPresetIndex;
  final bool initialArabic;
  final bool initialDark;
  final bool autoRunInitial;
  final bool autoPlayAnimations;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quds Scientific Studio',
      debugShowCheckedModeBanner: false,
      home: QudsStudioPage(
        initialPresetIndex: initialPresetIndex,
        initialArabic: initialArabic,
        initialDark: initialDark,
        autoRunInitial: autoRunInitial,
        autoPlayAnimations: autoPlayAnimations,
      ),
    );
  }
}
