import 'package:flutter/material.dart';

import 'studio_page.dart';

void main() {
  runApp(const QudsStudioApp(autoPlayAnimations: true));
}

ThemeData buildQudsStudioTheme({required bool isDark}) => ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: 'IBMPlexSansArabic',
      colorSchemeSeed: const Color(0xFF2563EB),
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF060B16) : const Color(0xFFF1F5F9),
    );

class QudsStudioApp extends StatefulWidget {
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
  State<QudsStudioApp> createState() => _QudsStudioAppState();
}

class _QudsStudioAppState extends State<QudsStudioApp> {
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = widget.initialDark;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quds Scientific Studio',
      debugShowCheckedModeBanner: false,
      theme: buildQudsStudioTheme(isDark: false),
      darkTheme: buildQudsStudioTheme(isDark: true),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: QudsStudioPage(
        initialPresetIndex: widget.initialPresetIndex,
        initialArabic: widget.initialArabic,
        initialDark: _isDark,
        autoRunInitial: widget.autoRunInitial,
        autoPlayAnimations: widget.autoPlayAnimations,
        onDarkModeChanged: (v) {
          if (_isDark != v) {
            setState(() => _isDark = v);
          }
        },
      ),
    );
  }
}
