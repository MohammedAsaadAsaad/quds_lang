import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'installer_engine.dart';
import 'models.dart';
import 'system_analyzer.dart';
import 'theme.dart';

/// Root widget for the cross-platform Quds Desktop Installer.
class QudsInstallerApp extends StatefulWidget {
  const QudsInstallerApp({
    super.key,
    this.analyzer,
    this.engine,
    this.initialArabic = true,
    this.initialDark = true,
    this.enableAmbientAnimations = true,
    this.onClose,
  });

  final SystemAnalyzer? analyzer;
  final InstallerEngine? engine;
  final bool initialArabic;
  final bool initialDark;
  final bool enableAmbientAnimations;
  final VoidCallback? onClose;

  @override
  State<QudsInstallerApp> createState() => _QudsInstallerAppState();
}

class _QudsInstallerAppState extends State<QudsInstallerApp> {
  late bool _isArabic = widget.initialArabic;
  late bool _isDark = widget.initialDark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _isArabic ? 'مثبّت لغة قدس' : 'Quds Installer',
      theme: QudsPalette.lightTheme(),
      darkTheme: QudsPalette.darkTheme(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: Directionality(
        textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: _InstallerWizardScreen(
          analyzer: widget.analyzer ?? SystemAnalyzer(),
          engine: widget.engine ?? InstallerEngine(),
          isArabic: _isArabic,
          isDark: _isDark,
          enableAmbientAnimations: widget.enableAmbientAnimations,
          onToggleLanguage: () => setState(() => _isArabic = !_isArabic),
          onToggleTheme: () => setState(() => _isDark = !_isDark),
          onClose: widget.onClose,
        ),
      ),
    );
  }
}

class _InstallerWizardScreen extends StatefulWidget {
  const _InstallerWizardScreen({
    required this.analyzer,
    required this.engine,
    required this.isArabic,
    required this.isDark,
    required this.enableAmbientAnimations,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    this.onClose,
  });

  final SystemAnalyzer analyzer;
  final InstallerEngine engine;
  final bool isArabic;
  final bool isDark;
  final bool enableAmbientAnimations;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final VoidCallback? onClose;

  @override
  State<_InstallerWizardScreen> createState() => _InstallerWizardScreenState();
}

class _InstallerWizardScreenState extends State<_InstallerWizardScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0; // 0: Scan, 1: Options, 2: Installing, 3: Complete
  bool _scanning = true;
  SystemReport? _report;

  // Prerequisite helper state
  SystemCheckItem? _selectedPrereq;
  bool _runningPrereq = false;
  final List<LogEntry> _prereqLogs = [];

  // Step 2 customization state
  InstallSource _source = InstallSource.pubDev;
  final TextEditingController _versionController = TextEditingController(
    text: defaultQudsVersion,
  );
  final TextEditingController _localPathController = TextEditingController();
  bool _addToPath = true;
  bool _removeLegacy = false;
  bool _installEditors = true;
  final Set<String> _selectedEditors = {};
  bool _runVerification = true;

  // Step 3 installation progress state
  bool _installing = false;
  bool _installSucceeded = false;
  List<InstallStepProgress> _installSteps = [];
  final List<LogEntry> _installLogs = [];
  final ScrollController _logScrollController = ScrollController();

  // Subtle ambient animation for the Quds brand emblem
  late final AnimationController _pulseController;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    if (widget.enableAmbientAnimations) {
      _pulseController.repeat(reverse: true);
    }
    _runScan();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _versionController.dispose();
    _localPathController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    setState(() {
      _scanning = true;
    });
    final report = await widget.analyzer.scan();
    if (!mounted) return;
    setState(() {
      _report = report;
      _scanning = false;
      _addToPath = !report.pubCacheBinOnPath;
      _removeLegacy = report.legacyQudsLangActive;
      if (report.detectedLocalRepo != null &&
          _localPathController.text.isEmpty) {
        _localPathController.text = report.detectedLocalRepo!;
      }
      if (_selectedEditors.isEmpty) {
        for (final editor in report.detectedEditors) {
          _selectedEditors.add(editor.id);
        }
      }
      // Auto-focus prerequisite assistant if Dart SDK is missing or outdated.
      if (!report.canInstallQuds) {
        _selectedPrereq = report.dartCheck;
      } else if (_selectedPrereq?.id == 'dart') {
        _selectedPrereq = null;
      }
    });
  }

  Future<void> _runPrerequisiteAction(PrerequisiteAction action) async {
    setState(() {
      _runningPrereq = true;
      _prereqLogs.clear();
    });
    final ok = await widget.engine.runPrerequisite(
      action,
      onLog: (entry) {
        if (!mounted) return;
        setState(() => _prereqLogs.add(entry));
      },
    );
    if (!mounted) return;
    setState(() => _runningPrereq = false);
    if (ok) {
      await _runScan();
    }
  }

  InstallPlan _buildPlan() => InstallPlan(
    source: _source,
    qudsVersion: _versionController.text.trim().isEmpty
        ? defaultQudsVersion
        : _versionController.text.trim(),
    localRepoPath: _localPathController.text.trim().isEmpty
        ? _report?.detectedLocalRepo
        : _localPathController.text.trim(),
    addToPath: _addToPath,
    removeLegacyQudsLang: _removeLegacy,
    installEditorSupport: _installEditors,
    selectedEditorIds: Set<String>.from(_selectedEditors),
    runVerification: _runVerification,
  );

  Future<void> _startInstallation() async {
    final report = _report;
    if (report == null) return;
    final plan = _buildPlan();
    setState(() {
      _step = 2;
      _installing = true;
      _installSucceeded = false;
      _installLogs.clear();
      _installSteps = widget.engine.buildSteps(plan);
    });

    final ok = await widget.engine.execute(
      report: report,
      plan: plan,
      onStepsChanged: (steps) {
        if (!mounted) return;
        setState(() => _installSteps = steps);
      },
      onLog: (entry) {
        if (!mounted) return;
        setState(() => _installLogs.add(entry));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScrollController.hasClients) {
            _logScrollController.animateTo(
              _logScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _installing = false;
      _installSucceeded = ok;
      if (ok) {
        _step = 3;
      }
    });
  }

  Future<void> _copyText(String value, String labelAr, String labelEn) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('تم نسخ $labelAr', 'Copied $labelEn')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final borderColor = isDark
        ? QudsPalette.midnightBorder
        : QudsPalette.lightBorder;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          return Row(
            children: [
              _buildSidebar(compact: compact, borderColor: borderColor),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(borderColor),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.02),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _buildCurrentStep(),
                        ),
                      ),
                    ),
                    _buildBottomBar(borderColor),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar({required bool compact, required Color borderColor}) {
    final isDark = widget.isDark;
    final width = compact ? 220.0 : 272.0;

    final steps = [
      (
        icon: Icons.radar_rounded,
        titleAr: 'فحص النظام',
        titleEn: 'System Analysis',
        subAr: 'الأدوات والمتطلبات',
        subEn: 'SDKs & prerequisites',
      ),
      (
        icon: Icons.tune_rounded,
        titleAr: 'خيارات التثبيت',
        titleEn: 'Customize Setup',
        subAr: 'المصدر والمحررات',
        subEn: 'Source & editors',
      ),
      (
        icon: Icons.downloading_rounded,
        titleAr: 'التثبيت المباشر',
        titleEn: 'Installing',
        subAr: 'التقدم والسجل الحي',
        subEn: 'Live progress & logs',
      ),
      (
        icon: Icons.verified_rounded,
        titleAr: 'جاهز للانطلاق',
        titleEn: 'Complete',
        subAr: 'البداية السريعة',
        subEn: 'Quick start guide',
      ),
    ];

    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF0A162C), Color(0xFF071122)]
              : const [Color(0xFFFFFFFF), Color(0xFFEAF2FC)],
        ),
        border: BorderDirectional(end: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand header with animated Quds logo
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final glow = 0.20 + (_pulseController.value * 0.22);
                    return Container(
                      width: 82,
                      height: 82,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0E2144), Color(0xFF081429)],
                        ),
                        border: Border.all(
                          color: QudsPalette.domeGold.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: QudsPalette.domeGold.withValues(alpha: glow),
                            blurRadius: 22,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/quds_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                t('مثبّت لغة قدس', 'Quds Installer'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : QudsPalette.midnightBg,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: QudsPalette.domeGold.withValues(
                      alpha: isDark ? 0.16 : 0.22,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: QudsPalette.domeGold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    'Quds $defaultQudsVersion',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? QudsPalette.warmGold
                          : QudsPalette.midnightBg,
                    ),
                  ),
                ),
              ),
              if (_report != null) ...[
                const SizedBox(height: 10),
                Center(child: _osBadge(_report!.os, _report!.osLabel)),
              ],
              const SizedBox(height: 24),
              // Vertical stepper rail
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: List.generate(steps.length, (index) {
                      final item = steps[index];
                      final isActive = _step == index;
                      final isCompleted = _step > index;
                      final canTap =
                          !_installing &&
                          index <= 1 &&
                          (index == 0 || (_report?.canInstallQuds ?? false));
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: canTap
                              ? () => setState(() => _step = index)
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: isActive
                                  ? (isDark
                                        ? QudsPalette.royalBlue.withValues(
                                            alpha: 0.22,
                                          )
                                        : QudsPalette.deepBlue.withValues(
                                            alpha: 0.10,
                                          ))
                                  : Colors.transparent,
                              border: Border.all(
                                color: isActive
                                    ? (isDark
                                          ? QudsPalette.domeGold.withValues(
                                              alpha: 0.65,
                                            )
                                          : QudsPalette.deepBlue.withValues(
                                              alpha: 0.45,
                                            ))
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCompleted
                                        ? QudsPalette.okGreen
                                        : isActive
                                        ? QudsPalette.domeGold
                                        : (isDark
                                              ? QudsPalette.midnightCard
                                              : const Color(0xFFE2EBF8)),
                                  ),
                                  child: Icon(
                                    isCompleted
                                        ? Icons.check_rounded
                                        : item.icon,
                                    size: 17,
                                    color: isCompleted
                                        ? Colors.white
                                        : isActive
                                        ? QudsPalette.midnightBg
                                        : (isDark
                                              ? Colors.white70
                                              : QudsPalette.deepBlue),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t(item.titleAr, item.titleEn),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isActive
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: isActive
                                              ? (isDark
                                                    ? Colors.white
                                                    : QudsPalette.deepBlue)
                                              : (isDark
                                                    ? Colors.white70
                                                    : Colors.black87),
                                        ),
                                      ),
                                      Text(
                                        t(item.subAr, item.subEn),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const Divider(height: 20),
              // Language & Theme toggles
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('toggle-language-btn'),
                      onPressed: widget.onToggleLanguage,
                      icon: const Icon(Icons.translate_rounded, size: 16),
                      label: Text(
                        widget.isArabic ? 'English' : 'العربية',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    key: const Key('toggle-theme-btn'),
                    tooltip: t('تبديل المظهر', 'Toggle theme'),
                    onPressed: widget.onToggleTheme,
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _osBadge(DesktopOs os, String label) {
    final icon = switch (os) {
      DesktopOs.windows => Icons.window_rounded,
      DesktopOs.macos => Icons.laptop_mac_rounded,
      DesktopOs.linux => Icons.terminal_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : QudsPalette.deepBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: widget.isDark ? Colors.white70 : QudsPalette.deepBlue,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white70 : QudsPalette.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(Color borderColor) {
    final titles = [
      (
        t('تحليل النظام والمتطلبات القبلية', 'System Analysis & Prerequisites'),
        t(
          'نفحص بيئتك تلقائياً لتحديد ما هو جاهز وما يلزم تثبيته لعمل لغة قدس بسلاسة.',
          'Automatically inspecting your SDKs, PATH, and editors to prepare Quds.',
        ),
      ),
      (
        t(
          'تخصيص التثبيت وإضافات المحررات',
          'Customize Installation & Editor Support',
        ),
        t(
          'اختر مصدر التثبيت والمحررات التي تريد تفعيل دعم لغة قدس فيها.',
          'Choose the install source, PATH setup, and editor extensions to configure.',
        ),
      ),
      (
        t('جارٍ تثبيت وتهيئة لغة قدس', 'Installing & Configuring Quds'),
        t(
          'تابع تقدم كل خطوة ومخرجات الطرفية مباشرة في الوقت الحقيقي.',
          'Watch each installation phase and live command output in real time.',
        ),
      ),
      (
        t(
          'اكتمل التثبيت — أهلاً بك في لغة قدس!',
          'Installation Complete — Welcome to Quds!',
        ),
        t(
          'بيئتك جاهزة الآن لكتابة مشاريع Dart و Flutter بلغة قدس.',
          'Your machine is ready to build Dart and Flutter projects in Quds.',
        ),
      ),
    ];
    final current = titles[_step];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.$1,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  current.$2,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (_step == 0)
            OutlinedButton.icon(
              key: const Key('rescan-btn'),
              onPressed: _scanning || _runningPrereq ? null : _runScan,
              icon: _scanning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 17),
              label: Text(t('إعادة الفحص', 'Re-Scan')),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_step) {
      0 => _buildStepScan(),
      1 => _buildStepOptions(),
      2 => _buildStepInstalling(),
      _ => _buildStepComplete(),
    };
  }

  // ---------------------------------------------------------------------------
  // Step 1: System Analysis & Prerequisite Guidance
  // ---------------------------------------------------------------------------
  Widget _buildStepScan() {
    if (_scanning && _report == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: QudsPalette.domeGold,
                    ),
                  ),
                  Image.asset('assets/quds_logo.png', width: 42, height: 42),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              t(
                'جارٍ فحص النظام والأدوات والمحررات...',
                'Scanning your system, SDKs, and editors...',
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    final report = _report!;
    final ready = report.canInstallQuds;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: ready
                    ? (widget.isDark
                          ? const [Color(0xFF0E2942), Color(0xFF102A38)]
                          : const [Color(0xFFE9F5FF), Color(0xFFECFAF2)])
                    : (widget.isDark
                          ? const [Color(0xFF2B1F12), Color(0xFF1A1829)]
                          : const [Color(0xFFFFF5E5), Color(0xFFFFEFEF)]),
              ),
              border: Border.all(
                color: (ready ? QudsPalette.okGreen : QudsPalette.warnAmber)
                    .withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: QudsPalette.midnightBg,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: QudsPalette.domeGold.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Image.asset('assets/quds_logo.png'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ready
                            ? t(
                                'نظامك جاهز لتثبيت لغة قدس!',
                                'Your system is ready to install Quds!',
                              )
                            : t(
                                'يلزم تثبيت أو تحديث Dart SDK (3.3+) أولاً',
                                'Dart SDK 3.3+ is required before installing Quds',
                              ),
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ready
                            ? t(
                                'تم العثور على Dart ${report.dartCheck.version} و ${report.detectedEditors.length} محرر/بيئة تطوير على ${report.osLabel}.',
                                'Found Dart ${report.dartCheck.version} and ${report.detectedEditors.length} editor(s) on ${report.osLabel}.',
                              )
                            : t(
                                'استخدم مساعد المتطلبات بالأسفل لتثبيت Dart SDK بنقرة واحدة أو نسخ أمر التثبيت ثم أعد الفحص.',
                                'Use the Prerequisite Assistant below to install Dart SDK or copy the command, then click Re-Scan.',
                              ),
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.isDark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _statusPill(
                  ready ? CheckStatus.ready : CheckStatus.missing,
                  customAr: ready ? 'جاهز للتثبيت' : 'متطلب ناقص',
                  customEn: ready ? 'Ready' : 'Action needed',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(
            t('الأدوات الأساسية والمتطلبات', 'Core Tools & Requirements'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          // Core checks grid
          LayoutBuilder(
            builder: (context, box) {
              final twoCols = box.maxWidth >= 660;
              final itemWidth = twoCols
                  ? (box.maxWidth - 12) / 2
                  : box.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in report.coreChecks)
                    SizedBox(width: itemWidth, child: _buildCheckCard(item)),
                  SizedBox(width: box.maxWidth, child: _buildPathCard(report)),
                ],
              );
            },
          ),

          // Prerequisite Helper Panel
          if (_selectedPrereq != null && _selectedPrereq!.action != null) ...[
            const SizedBox(height: 18),
            _buildPrerequisiteHelper(_selectedPrereq!),
          ],

          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                t('المحررات والبيئات المكتشفة', 'Detected Editors & IDEs'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${report.detectedEditors.length}/${report.editors.length})',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: report.editors.map(_buildEditorChip).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckCard(SystemCheckItem item) {
    final canAssist = item.action != null && item.status != CheckStatus.ready;
    final isSelected = _selectedPrereq?.id == item.id;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? QudsPalette.domeGold
              : (widget.isDark
                    ? QudsPalette.midnightBorder
                    : QudsPalette.lightBorder),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusIcon(item.status),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t(item.nameAr, item.nameEn),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _statusPill(item.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t(item.detailAr, item.detailEn),
              style: TextStyle(
                fontSize: 12.5,
                color: widget.isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (item.path != null) ...[
              const SizedBox(height: 6),
              Text(
                item.path!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: widget.isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
            if (canAssist) ...[
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  key: Key('prereq-help-${item.id}'),
                  onPressed: () => setState(() => _selectedPrereq = item),
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: Text(
                    t('مساعد التثبيت القبلي', 'Install Guide'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPathCard(SystemReport report) {
    final onPath = report.pubCacheBinOnPath;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            _statusIcon(onPath ? CheckStatus.ready : CheckStatus.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(
                      'مسار الأوامر العامة (PATH / pub-cache/bin)',
                      'Global CLI PATH (pub-cache/bin)',
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    onPath
                        ? t(
                            'مضاف مسبقاً إلى PATH: ${report.pubCacheBin}',
                            'Already configured on PATH: ${report.pubCacheBin}',
                          )
                        : t(
                            'سيضيفه المثبّت تلقائياً إلى PATH: ${report.pubCacheBin}',
                            'Will be added to PATH automatically: ${report.pubCacheBin}',
                          ),
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            _statusPill(
              onPath ? CheckStatus.ready : CheckStatus.warning,
              customAr: onPath ? 'مضبوط' : 'سيُضبط تلقائياً',
              customEn: onPath ? 'Configured' : 'Will auto-fix',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrerequisiteHelper(SystemCheckItem item) {
    final action = item.action!;
    return Card(
      key: const Key('prereq-helper-panel'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: QudsPalette.domeGold.withValues(alpha: 0.7),
          width: 1.4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.build_circle_rounded,
                  color: QudsPalette.domeGold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t(
                      'مساعد المتطلبات القبلية: ${action.titleAr}',
                      'Prerequisite Assistant: ${action.titleEn}',
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t('إغلاق', 'Close'),
                  onPressed: () => setState(() => _selectedPrereq = null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF040A15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: QudsPalette.midnightBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      action.command,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        color: QudsPalette.warmGold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: t('نسخ الأمر', 'Copy command'),
                    onPressed: () =>
                        _copyText(action.command, 'أمر التثبيت', 'command'),
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 17,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (action.canRunDirectly)
                  FilledButton.icon(
                    key: const Key('run-prereq-btn'),
                    onPressed: _runningPrereq
                        ? null
                        : () => _runPrerequisiteAction(action),
                    icon: _runningPrereq
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: QudsPalette.midnightBg,
                            ),
                          )
                        : const Icon(
                            Icons.download_for_offline_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _runningPrereq
                          ? t('جارٍ التثبيت...', 'Installing...')
                          : t('تثبيت تلقائي الآن', 'Install Automatically'),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => widget.analyzer.openUrl(action.downloadUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: Text(t('فتح الصفحة الرسمية', 'Open Official Guide')),
                ),
                OutlinedButton.icon(
                  onPressed: _runningPrereq ? null : _runScan,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: Text(t('أعد الفحص الآن', 'Re-Scan Now')),
                ),
              ],
            ),
            if (_prereqLogs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                height: 120,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF040A15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: QudsPalette.midnightBorder),
                ),
                child: ListView.builder(
                  itemCount: _prereqLogs.length,
                  itemBuilder: (context, i) => _buildLogLine(_prereqLogs[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditorChip(EditorStatus editor) {
    final bg = editor.detected
        ? (widget.isDark ? QudsPalette.midnightCard : QudsPalette.lightSurface)
        : (widget.isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.03));
    final border = editor.extensionInstalled
        ? QudsPalette.okGreen.withValues(alpha: 0.55)
        : editor.detected
        ? QudsPalette.royalBlue.withValues(alpha: 0.55)
        : (widget.isDark
              ? QudsPalette.midnightBorder
              : QudsPalette.lightBorder);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            editor.extensionInstalled
                ? Icons.check_circle_rounded
                : editor.detected
                ? Icons.extension_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: editor.extensionInstalled
                ? QudsPalette.okGreen
                : editor.detected
                ? QudsPalette.domeGold
                : (widget.isDark ? Colors.white38 : Colors.black38),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editor.name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: editor.detected
                      ? null
                      : (widget.isDark ? Colors.white54 : Colors.black54),
                ),
              ),
              Text(
                editor.extensionInstalled
                    ? t('الإضافة مثبّتة', 'Extension installed')
                    : editor.detected
                    ? t(
                        'مكتشف — جاهز لتثبيت الإضافة',
                        'Detected — ready for extension',
                      )
                    : t('غير مثبّت على الجهاز', 'Not detected'),
                style: TextStyle(
                  fontSize: 10.5,
                  color: widget.isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Customize Installation Options
  // ---------------------------------------------------------------------------
  Widget _buildStepOptions() {
    final report = _report!;
    final hasLocalRepo = report.detectedLocalRepo != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Source selection
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_download_rounded,
                        color: QudsPalette.domeGold,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        t('مصدر تثبيت لغة قدس', 'Quds Package Source'),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _sourceChoiceTile(
                          selected: _source == InstallSource.pubDev,
                          title: t(
                            'pub.dev الرسمي (موصى به)',
                            'Official pub.dev (Recommended)',
                          ),
                          subtitle: t(
                            'يثبّت أحدث إصدار مستقر من حزمة quds عالمياً',
                            'Installs the published `quds` package globally',
                          ),
                          onTap: () =>
                              setState(() => _source = InstallSource.pubDev),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _sourceChoiceTile(
                          selected: _source == InstallSource.localPath,
                          title: t('مسار مستودع محلي', 'Local Repository Path'),
                          subtitle: hasLocalRepo
                              ? report.detectedLocalRepo!
                              : t(
                                  'للمطورين من نسخة Git محلية',
                                  'For contributors using a local checkout',
                                ),
                          onTap: () =>
                              setState(() => _source = InstallSource.localPath),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_source == InstallSource.pubDev)
                    TextField(
                      controller: _versionController,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: t(
                          'إصدار حزمة quds على pub.dev',
                          'Quds package version on pub.dev',
                        ),
                        hintText: defaultQudsVersion,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    )
                  else
                    TextField(
                      controller: _localPathController,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: t(
                          'مسار مجلد مستودع quds_lang المحلي',
                          'Local quds_lang repository path',
                        ),
                        hintText: '/path/to/quds_lang',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. System integration toggles
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _addToPath,
                    onChanged: (v) => setState(() => _addToPath = v),
                    title: Text(
                      t(
                        'إضافة pub-cache/bin إلى PATH تلقائياً',
                        'Add pub-cache/bin to user PATH automatically',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      report.pubCacheBin,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (report.legacyQudsLangActive)
                    SwitchListTile(
                      value: _removeLegacy,
                      onChanged: (v) => setState(() => _removeLegacy = v),
                      title: Text(
                        t(
                          'إزالة التفعيل القديم (quds_lang)',
                          'Deactivate legacy `quds_lang` global package',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        t(
                          'يمنع تعارض أمر quds بين الحزمة القديمة والجديدة',
                          'Prevents command collisions between legacy and new packages',
                        ),
                      ),
                    ),
                  SwitchListTile(
                    value: _runVerification,
                    onChanged: (v) => setState(() => _runVerification = v),
                    title: Text(
                      t(
                        'التحقق التلقائي بعد التثبيت (quds doctor)',
                        'Run post-install verification (quds doctor)',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      t(
                        'يتأكد من جاهزية CLI و Dart SDK وإضافات المحررات',
                        'Confirms CLI, Dart SDK, and editor support are healthy',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Editor extensions card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _installEditors,
                    onChanged: (v) => setState(() => _installEditors = v),
                    title: Text(
                      t(
                        'تثبيت إضافات المحررات وبيئات التطوير',
                        'Install Editor Extensions & IDE Support',
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      t(
                        'يشمل تلوين الصياغة والاختصارات لـ VS Code / Cursor / Windsurf و JetBrains / Android Studio ومهارة Claude Code',
                        'Includes syntax highlighting & snippets for VS Code / Cursor / Windsurf, JetBrains / Android Studio, and Claude Code',
                      ),
                    ),
                  ),
                  if (_installEditors) ...[
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: report.editors.map((editor) {
                        final checked = _selectedEditors.contains(editor.id);
                        return FilterChip(
                          selected: checked,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedEditors.add(editor.id);
                              } else {
                                _selectedEditors.remove(editor.id);
                              }
                            });
                          },
                          avatar: Icon(
                            editor.detected
                                ? Icons.check_circle_outline_rounded
                                : Icons.desktop_windows_rounded,
                            size: 16,
                          ),
                          label: Text(
                            editor.detected
                                ? editor.name
                                : '${editor.name} (${t('غير مكتشف', 'not detected')})',
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceChoiceTile({
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? (widget.isDark
                    ? QudsPalette.royalBlue.withValues(alpha: 0.22)
                    : QudsPalette.deepBlue.withValues(alpha: 0.08))
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? QudsPalette.domeGold
                : (widget.isDark
                      ? QudsPalette.midnightBorder
                      : QudsPalette.lightBorder),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 18,
                  color: selected ? QudsPalette.domeGold : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: widget.isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Live Installation Progress & Console
  // ---------------------------------------------------------------------------
  Widget _buildStepInstalling() {
    final total = _installSteps.isEmpty ? 1 : _installSteps.length;
    final completed = _installSteps
        .where(
          (s) =>
              s.state == StepRunState.done || s.state == StepRunState.warning,
        )
        .length;
    final running = _installSteps.any((s) => s.state == StepRunState.running)
        ? 0.35
        : 0.0;
    final progress = ((completed + running) / total).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Animated progress bar card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _installing
                              ? t(
                                  'جارٍ تنفيذ خطوات التثبيت...',
                                  'Running installation steps...',
                                )
                              : _installSucceeded
                              ? t(
                                  'اكتملت كل الخطوات بنجاح!',
                                  'All steps completed!',
                                )
                              : t(
                                  'توقّف التثبيت — راجع السجل بالأسفل',
                                  'Installation stopped — inspect logs below',
                                ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: QudsPalette.domeGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 350),
                    builder: (context, value, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 9,
                        backgroundColor: widget.isDark
                            ? QudsPalette.midnightBg
                            : const Color(0xFFE2EBF8),
                        color:
                            _installSteps.any(
                              (s) => s.state == StepRunState.failed,
                            )
                            ? QudsPalette.errRed
                            : QudsPalette.domeGold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._installSteps.map(_buildStepProgressRow),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Live Console Header + Output
          Row(
            children: [
              const Icon(
                Icons.terminal_rounded,
                size: 18,
                color: QudsPalette.domeGold,
              ),
              const SizedBox(width: 8),
              Text(
                t('سجل التثبيت المباشر', 'Live Installation Console'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _installLogs.isEmpty
                    ? null
                    : () => _copyText(
                        _installLogs.map((e) => e.message).join('\n'),
                        'سجل التثبيت',
                        'installation logs',
                      ),
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: Text(t('نسخ السجل', 'Copy Logs')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF040A15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: QudsPalette.midnightBorder),
              ),
              child: ListView.builder(
                controller: _logScrollController,
                itemCount: _installLogs.length,
                itemBuilder: (context, index) =>
                    _buildLogLine(_installLogs[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgressRow(InstallStepProgress step) {
    Widget leading;
    switch (step.state) {
      case StepRunState.running:
        leading = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: QudsPalette.domeGold,
          ),
        );
      case StepRunState.done:
        leading = const Icon(
          Icons.check_circle_rounded,
          size: 19,
          color: QudsPalette.okGreen,
        );
      case StepRunState.warning:
        leading = const Icon(
          Icons.warning_amber_rounded,
          size: 19,
          color: QudsPalette.warnAmber,
        );
      case StepRunState.failed:
        leading = const Icon(
          Icons.error_rounded,
          size: 19,
          color: QudsPalette.errRed,
        );
      case StepRunState.pending:
        leading = Icon(
          Icons.circle_outlined,
          size: 18,
          color: widget.isDark ? Colors.white38 : Colors.black38,
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t(step.titleAr, step.titleEn),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: step.state == StepRunState.running
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogLine(LogEntry entry) {
    final color = switch (entry.level) {
      LogLevel.command => QudsPalette.warmGold,
      LogLevel.success => QudsPalette.okGreen,
      LogLevel.warning => QudsPalette.warnAmber,
      LogLevel.error => QudsPalette.errRed,
      LogLevel.info => const Color(0xFFD6E4FF),
    };
    final hh = entry.timestamp.hour.toString().padLeft(2, '0');
    final mm = entry.timestamp.minute.toString().padLeft(2, '0');
    final ss = entry.timestamp.second.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '[$hh:$mm:$ss] ${entry.message}',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: color,
          height: 1.35,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4: Completion & Quick Start
  // ---------------------------------------------------------------------------
  Widget _buildStepComplete() {
    final quickCommands = [
      (
        cmd: 'quds create hello_quds',
        descAr: 'إنشاء مشروع Dart جديد بلغة قدس وتشغيله فوراً',
        descEn: 'Create a new Dart-target Quds project',
      ),
      (
        cmd: 'quds create --f my_app',
        descAr: 'إنشاء مشروع تطبيق Flutter كامل بلغة قدس',
        descEn: 'Create a Flutter application written in Quds',
      ),
      (
        cmd: 'quds doctor',
        descAr: 'فحص صحة البيئة والمحررات وإصدار Quds CLI',
        descEn: 'Check compiler, PATH, and editor extension health',
      ),
      (
        cmd: 'quds help',
        descAr: 'استعراض قائمة كل أوامر أداة قدس المنسقة',
        descEn: 'Explore all available Quds CLI commands',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isDark
                    ? const [Color(0xFF0E2942), Color(0xFF0D2E2A)]
                    : const [Color(0xFFEAF5FF), Color(0xFFE9FBF2)],
              ),
              border: Border.all(
                color: QudsPalette.okGreen.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: QudsPalette.midnightBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: QudsPalette.domeGold,
                          width: 1.8,
                        ),
                      ),
                      child: Image.asset('assets/quds_logo.png'),
                    ),
                    const Positioned(
                      right: -6,
                      bottom: -6,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: QudsPalette.okGreen,
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  t('تم تثبيت لغة قدس بنجاح!', 'Quds is installed and ready!'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    'افتح نافذة طرفية جديدة (Terminal / PowerShell) لتفعيل PATH المحدّث ثم جرّب أحد أوامر البداية السريعة بالأسفل.',
                    'Open a new terminal window if PATH was updated, then try any Quick Start command below.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: widget.isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => widget.analyzer.openUrl(
                        'https://pub.dev/packages/quds',
                      ),
                      icon: const Icon(Icons.menu_book_rounded, size: 17),
                      label: Text(t('توثيق pub.dev', 'Open pub.dev Docs')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _step = 0);
                        _runScan();
                      },
                      icon: const Icon(Icons.radar_rounded, size: 17),
                      label: Text(t('إعادة فحص النظام', 'Re-Scan System')),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(
            t('أوامر البداية السريعة', 'Quick Start Commands'),
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...quickCommands.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.cmd,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: QudsPalette.domeGold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              t(item.descAr, item.descEn),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: widget.isDark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.outlined(
                        tooltip: t('نسخ الأمر', 'Copy command'),
                        onPressed: () =>
                            _copyText(item.cmd, item.cmd, item.cmd),
                        icon: const Icon(Icons.copy_rounded, size: 17),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Action Bar
  // ---------------------------------------------------------------------------
  Widget _buildBottomBar(Color borderColor) {
    final canProceedToOptions =
        !_scanning && !_runningPrereq && (_report?.canInstallQuds ?? false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          if (_step == 1)
            OutlinedButton.icon(
              onPressed: () => setState(() => _step = 0),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: Text(t('السابق', 'Back')),
            )
          else if (_step == 2 && !_installing && !_installSucceeded)
            OutlinedButton.icon(
              onPressed: () => setState(() => _step = 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: Text(t('تعديل الخيارات', 'Back to Options')),
            ),
          const Spacer(),
          if (_step == 0)
            FilledButton.icon(
              key: const Key('next-to-options-btn'),
              onPressed: canProceedToOptions
                  ? () => setState(() => _step = 1)
                  : null,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                canProceedToOptions
                    ? t('متابعة إلى خيارات التثبيت', 'Continue to Options')
                    : t('أكمل تثبيت Dart SDK أولاً', 'Install Dart SDK First'),
              ),
            )
          else if (_step == 1)
            FilledButton.icon(
              key: const Key('start-install-btn'),
              onPressed: _startInstallation,
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: Text(t('بدء تثبيت لغة قدس', 'Install Quds Now')),
            )
          else if (_step == 2 && !_installing && !_installSucceeded)
            FilledButton.icon(
              onPressed: _startInstallation,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: Text(t('إعادة المحاولة', 'Retry Installation')),
            )
          else if (_step == 3)
            FilledButton.icon(
              key: const Key('finish-close-btn'),
              onPressed: () {
                if (widget.onClose != null) {
                  widget.onClose!();
                } else {
                  exit(0);
                }
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(t('إنهاء وإغلاق', 'Finish & Close')),
            ),
        ],
      ),
    );
  }

  Widget _statusIcon(CheckStatus status) {
    return switch (status) {
      CheckStatus.ready => const Icon(
        Icons.check_circle_rounded,
        color: QudsPalette.okGreen,
      ),
      CheckStatus.warning => const Icon(
        Icons.warning_amber_rounded,
        color: QudsPalette.warnAmber,
      ),
      CheckStatus.missing => const Icon(
        Icons.cancel_rounded,
        color: QudsPalette.errRed,
      ),
      CheckStatus.optional => const Icon(
        Icons.info_outline_rounded,
        color: QudsPalette.royalBlue,
      ),
    };
  }

  Widget _statusPill(CheckStatus status, {String? customAr, String? customEn}) {
    final (color, ar, en) = switch (status) {
      CheckStatus.ready => (QudsPalette.okGreen, 'جاهز', 'Ready'),
      CheckStatus.warning => (QudsPalette.warnAmber, 'تنبيه', 'Needs update'),
      CheckStatus.missing => (QudsPalette.errRed, 'ناقص', 'Missing'),
      CheckStatus.optional => (QudsPalette.royalBlue, 'اختياري', 'Optional'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        t(customAr ?? ar, customEn ?? en),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
