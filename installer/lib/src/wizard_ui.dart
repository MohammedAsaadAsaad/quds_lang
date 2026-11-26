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

class _InstallerWizardScreenState extends State<_InstallerWizardScreen> {
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
  bool _showAllEditors = false;
  final Set<String> _selectedEditors = {};
  bool _runVerification = true;

  // Step 3 installation progress state
  bool _installing = false;
  bool _installSucceeded = false;
  List<InstallStepProgress> _installSteps = [];
  final List<LogEntry> _installLogs = [];
  final ScrollController _logScrollController = ScrollController();

  String t(String ar, String en) => widget.isArabic ? ar : en;

  Color get _border =>
      widget.isDark ? QudsPalette.darkBorder : QudsPalette.lightBorder;
  Color get _textPrimary => widget.isDark
      ? QudsPalette.darkTextPrimary
      : QudsPalette.lightTextPrimary;
  Color get _textSecondary => widget.isDark
      ? QudsPalette.darkTextSecondary
      : QudsPalette.lightTextSecondary;
  Color get _textMuted =>
      widget.isDark ? QudsPalette.darkTextMuted : QudsPalette.lightTextMuted;
  Color get _surface =>
      widget.isDark ? QudsPalette.darkSurface : QudsPalette.lightSurface;

  @override
  void initState() {
    super.initState();
    _runScan();
  }

  @override
  void dispose() {
    _versionController.dispose();
    _localPathController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    setState(() => _scanning = true);
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
              duration: const Duration(milliseconds: 160),
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
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sidebarWidth = constraints.maxWidth < 860 ? 204.0 : 236.0;
          return Row(
            children: [
              _buildSidebar(width: sidebarWidth),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.015),
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
                    _buildBottomBar(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Calm Minimal Sidebar
  // ---------------------------------------------------------------------------
  Widget _buildSidebar({required double width}) {
    final steps = [
      (t('فحص النظام', 'System Analysis')),
      (t('خيارات التثبيت', 'Setup Options')),
      (t('التثبيت', 'Installing')),
      (t('جاهز للانطلاق', 'Complete')),
    ];

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: widget.isDark
            ? QudsPalette.darkSidebar
            : QudsPalette.lightSidebar,
        border: BorderDirectional(end: BorderSide(color: _border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Clean brand mark (no neon glow)
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1426),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: QudsPalette.domeGold.withValues(alpha: 0.38),
                      ),
                    ),
                    child: Image.asset(
                      'assets/quds_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('مثبّت لغة قدس', 'Quds Installer'),
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _report == null
                              ? defaultQudsVersion
                              : '$defaultQudsVersion · ${_report!.osLabel}',
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: _textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Minimal numbered stepper
              Expanded(
                child: Column(
                  children: List.generate(steps.length, (index) {
                    final isActive = _step == index;
                    final isCompleted = _step > index;
                    final canTap =
                        !_installing &&
                        index <= 1 &&
                        (index == 0 || (_report?.canInstallQuds ?? false));

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: canTap
                            ? () => setState(() => _step = index)
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: isActive
                                ? (widget.isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : QudsPalette.deepBlue.withValues(
                                          alpha: 0.07,
                                        ))
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompleted
                                      ? QudsPalette.okGreen
                                      : isActive
                                      ? (widget.isDark
                                            ? QudsPalette.domeGold
                                            : QudsPalette.deepBlue)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isCompleted
                                        ? QudsPalette.okGreen
                                        : isActive
                                        ? Colors.transparent
                                        : _border,
                                  ),
                                ),
                                child: isCompleted
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      )
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isActive
                                              ? (widget.isDark
                                                    ? QudsPalette.darkCanvas
                                                    : Colors.white)
                                              : _textMuted,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  steps[index],
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isActive
                                        ? _textPrimary
                                        : _textSecondary,
                                  ),
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

              const Divider(),
              const SizedBox(height: 12),

              // Quiet footer controls
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('toggle-language-btn'),
                      onPressed: widget.onToggleLanguage,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      child: Text(widget.isArabic ? 'English' : 'العربية'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    key: const Key('toggle-theme-btn'),
                    tooltip: t('تبديل المظهر', 'Toggle theme'),
                    onPressed: widget.onToggleTheme,
                    style: IconButton.styleFrom(
                      side: BorderSide(color: _border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(
                      widget.isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 17,
                      color: _textSecondary,
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

  // ---------------------------------------------------------------------------
  // Clean Top Header
  // ---------------------------------------------------------------------------
  Widget _buildTopBar() {
    final titles = [
      (
        t('فحص النظام والمتطلبات', 'System Analysis'),
        t(
          'نراجع أدوات النظام والمحررات قبل بدء التثبيت.',
          'Checking installed SDKs, PATH, and editors before setup.',
        ),
      ),
      (
        t('خيارات التثبيت', 'Customize Setup'),
        t(
          'اختر مصدر الحزمة وإعدادات النظام والمحررات.',
          'Configure package source, PATH, and editor extensions.',
        ),
      ),
      (
        t('جارٍ التثبيت', 'Installing Quds'),
        t(
          'تُنفّذ الخطوات وتُعرض المخرجات مباشرة.',
          'Running setup steps with live output below.',
        ),
      ),
      (
        t('اكتمل التثبيت', 'Installation Complete'),
        t(
          'لغة قدس جاهزة للعمل على جهازك.',
          'Quds is configured and ready to use.',
        ),
      ),
    ];
    final current = titles[_step];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.$1,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  current.$2,
                  style: TextStyle(fontSize: 13, color: _textSecondary),
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
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
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

  Widget _centeredPage(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: child,
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Step 1: Calm Unified Checklist & Prerequisite Assistant
  // ---------------------------------------------------------------------------
  Widget _buildStepScan() {
    if (_scanning && _report == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: QudsPalette.domeGold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('جارٍ فحص النظام...', 'Analyzing your environment...'),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final report = _report!;
    final ready = report.canInstallQuds;
    final detectedEditors = report.detectedEditors;
    final hiddenCount = report.editors.length - detectedEditors.length;

    return _centeredPage(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quiet single-line status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: (ready ? QudsPalette.okGreen : QudsPalette.warnAmber)
                  .withValues(alpha: widget.isDark ? 0.08 : 0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (ready ? QudsPalette.okGreen : QudsPalette.warnAmber)
                    .withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  ready
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 19,
                  color: ready ? QudsPalette.okGreen : QudsPalette.warnAmber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ready
                        ? t(
                            'نظامك جاهز لتثبيت لغة قدس — Dart ${report.dartCheck.version} متوافق و${detectedEditors.length} محررات مكتشفة.',
                            'Your system is ready — Dart ${report.dartCheck.version} is compatible and ${detectedEditors.length} editor(s) detected.',
                          )
                        : t(
                            'يلزم تثبيت أو تحديث Dart SDK 3.3+ قبل المتابعة. استخدم المساعد بالأسفل.',
                            'Dart SDK 3.3+ is required before continuing. Use the assistant below.',
                          ),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Unified environment checklist card
          _sectionLabel(t('بيئة النظام', 'Environment')),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildCheckRow(report.dartCheck),
                const Divider(),
                _buildQudsRow(report),
                const Divider(),
                _buildCheckRow(report.gitCheck),
                const Divider(),
                _buildCheckRow(report.flutterCheck),
                const Divider(),
                _buildPathRow(report),
              ],
            ),
          ),

          // Prerequisite Helper Panel (shown when required or requested)
          if (_selectedPrereq != null && _selectedPrereq!.action != null) ...[
            const SizedBox(height: 18),
            _buildPrerequisiteHelper(_selectedPrereq!),
          ],

          const SizedBox(height: 22),

          // Clean detected editors strip (no noise from undetected tools)
          Row(
            children: [
              _sectionLabel(t('المحررات المكتشفة', 'Detected Editors')),
              const SizedBox(width: 8),
              if (hiddenCount > 0)
                Text(
                  t(
                    '($hiddenCount أخرى غير مثبّتة)',
                    '($hiddenCount not installed)',
                  ),
                  style: TextStyle(fontSize: 12, color: _textMuted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (detectedEditors.isEmpty)
            Text(
              t(
                'لم يُكتشف محرر مدعوم حالياً — يمكنك تثبيت الإضافات لاحقاً عبر quds install.',
                'No supported editors detected yet — you can run `quds install` later.',
              ),
              style: TextStyle(fontSize: 13, color: _textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detectedEditors.map(_buildEditorPill).toList(),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: _textSecondary,
    ),
  );

  Widget _buildCheckRow(SystemCheckItem item) {
    final canAssist = item.action != null && item.status != CheckStatus.ready;
    final (dotColor, statusText) = switch (item.status) {
      CheckStatus.ready => (QudsPalette.okGreen, t('جاهز', 'Ready')),
      CheckStatus.warning => (QudsPalette.warnAmber, t('تحديث', 'Update')),
      CheckStatus.missing => (QudsPalette.errRed, t('مطلوب', 'Missing')),
      CheckStatus.optional => (_textMuted, t('اختياري', 'Optional')),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          _statusDot(dotColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      t(item.nameAr, item.nameEn),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    if (item.version != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        item.version!,
                        style: TextStyle(
                          fontFamily: QudsPalette.fontMono,
                          fontSize: 11.5,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  t(item.detailAr, item.detailEn),
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
              ],
            ),
          ),
          if (canAssist) ...[
            TextButton(
              key: Key('prereq-help-${item.id}'),
              onPressed: () => setState(() => _selectedPrereq = item),
              child: Text(t('مساعد التثبيت', 'Install Guide')),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQudsRow(SystemReport report) {
    final item = report.qudsCheck;
    final installed = item.status == CheckStatus.ready;
    final dotColor = installed
        ? QudsPalette.okGreen
        : (widget.isDark ? QudsPalette.domeGold : QudsPalette.deepBlue);
    final label = installed
        ? t('مثبّتة', 'Installed')
        : report.legacyQudsLangActive
        ? t('سيُحدّث', 'Will upgrade')
        : t('سيُثبّت الآن', 'Will install');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          _statusDot(dotColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      t(item.nameAr, item.nameEn),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    if (item.version != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        item.version!,
                        style: TextStyle(
                          fontFamily: QudsPalette.fontMono,
                          fontSize: 11.5,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  t(item.detailAr, item.detailEn),
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
              ],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathRow(SystemReport report) {
    final onPath = report.pubCacheBinOnPath;
    final color = onPath ? QudsPalette.okGreen : _textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          _statusDot(onPath ? QudsPalette.okGreen : QudsPalette.royalBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('مسار الأوامر العامة (PATH)', 'Global CLI PATH'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.pubCacheBin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: QudsPalette.fontMono,
                    fontSize: 11.5,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            onPath
                ? t('مضبوط', 'Configured')
                : t('سيُضبط تلقائياً', 'Auto-configure'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _buildEditorPill(EditorStatus editor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            editor.extensionInstalled
                ? Icons.check_circle_rounded
                : Icons.extension_outlined,
            size: 15,
            color: editor.extensionInstalled
                ? QudsPalette.okGreen
                : _textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            editor.name,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
          ),
          if (editor.extensionInstalled) ...[
            const SizedBox(width: 6),
            Text(
              t('مثبّتة', 'Installed'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: QudsPalette.okGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrerequisiteHelper(SystemCheckItem item) {
    final action = item.action!;
    return Card(
      key: const Key('prereq-helper-panel'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: QudsPalette.domeGold.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t(
                      'مساعد المتطلبات القبلية — ${action.titleAr}',
                      'Prerequisite Assistant — ${action.titleEn}',
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t('إغلاق', 'Close'),
                  onPressed: () => setState(() => _selectedPrereq = null),
                  icon: Icon(Icons.close_rounded, size: 17, color: _textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: QudsPalette.darkConsole,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: QudsPalette.darkBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      action.command,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: QudsPalette.fontMono,
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
                      size: 16,
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
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: QudsPalette.darkCanvas,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 17),
                    label: Text(
                      _runningPrereq
                          ? t('جارٍ التثبيت...', 'Installing...')
                          : t('تثبيت تلقائي', 'Install Automatically'),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => widget.analyzer.openUrl(action.downloadUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(t('الدليل الرسمي', 'Official Guide')),
                ),
                OutlinedButton.icon(
                  onPressed: _runningPrereq ? null : _runScan,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(t('إعادة الفحص', 'Re-Scan')),
                ),
              ],
            ),
            if (_prereqLogs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                height: 110,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: QudsPalette.darkConsole,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: QudsPalette.darkBorder),
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

  // ---------------------------------------------------------------------------
  // Step 2: Clean Grouped Preferences
  // ---------------------------------------------------------------------------
  Widget _buildStepOptions() {
    final report = _report!;
    final visibleEditors = _showAllEditors || report.detectedEditors.isEmpty
        ? report.editors
        : report.detectedEditors;

    return _centeredPage(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(t('مصدر التثبيت', 'Package Source')),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _sourceSegment(
                          selected: _source == InstallSource.pubDev,
                          title: t('pub.dev الرسمي', 'Official pub.dev'),
                          onTap: () =>
                              setState(() => _source = InstallSource.pubDev),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _sourceSegment(
                          selected: _source == InstallSource.localPath,
                          title: t('مسار محلي', 'Local Repository'),
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
                      style: const TextStyle(
                        fontFamily: QudsPalette.fontMono,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        labelText: t('الإصدار', 'Version'),
                        hintText: defaultQudsVersion,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                    )
                  else
                    TextField(
                      controller: _localPathController,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: QudsPalette.fontMono,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        labelText: t('مسار المستودع المحلي', 'Local path'),
                        hintText: '/path/to/quds_lang',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          _sectionLabel(t('إعدادات النظام', 'System Configuration')),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _addToPath,
                  onChanged: (v) => setState(() => _addToPath = v),
                  title: Text(
                    t(
                      'إضافة pub-cache/bin إلى PATH تلقائياً',
                      'Add pub-cache/bin to PATH automatically',
                    ),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    report.pubCacheBin,
                    style: TextStyle(
                      fontFamily: QudsPalette.fontMono,
                      fontSize: 11.5,
                      color: _textMuted,
                    ),
                  ),
                ),
                if (report.legacyQudsLangActive) ...[
                  const Divider(),
                  SwitchListTile(
                    value: _removeLegacy,
                    onChanged: (v) => setState(() => _removeLegacy = v),
                    title: Text(
                      t(
                        'إزالة الحزمة القديمة quds_lang',
                        'Remove legacy quds_lang activation',
                      ),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Divider(),
                SwitchListTile(
                  value: _runVerification,
                  onChanged: (v) => setState(() => _runVerification = v),
                  title: Text(
                    t(
                      'التحقق التلقائي بعد التثبيت (quds doctor)',
                      'Verify installation with quds doctor',
                    ),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  value: _installEditors,
                  onChanged: (v) => setState(() => _installEditors = v),
                  title: Text(
                    t(
                      'تثبيت إضافات المحررات وبيئات التطوير',
                      'Install editor extensions & IDE support',
                    ),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    t(
                      'VS Code / Cursor / Windsurf / JetBrains / Claude Code',
                      'VS Code / Cursor / Windsurf / JetBrains / Claude Code',
                    ),
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ),
                if (_installEditors) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: visibleEditors.map((editor) {
                            final checked = _selectedEditors.contains(
                              editor.id,
                            );
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
                              label: Text(
                                editor.name,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            );
                          }).toList(),
                        ),
                        if (report.detectedEditors.length <
                            report.editors.length) ...[
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => setState(
                              () => _showAllEditors = !_showAllEditors,
                            ),
                            child: Text(
                              _showAllEditors
                                  ? t(
                                      'إخفاء غير المثبّتة',
                                      'Hide undetected editors',
                                    )
                                  : t(
                                      'عرض جميع المحررات المدعومة',
                                      'Show all supported editors',
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceSegment({
    required bool selected,
    required String title,
    required VoidCallback onTap,
  }) {
    final activeBorder = widget.isDark
        ? QudsPalette.domeGold
        : QudsPalette.deepBlue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? activeBorder.withValues(alpha: widget.isDark ? 0.12 : 0.08)
              : Colors.transparent,
          border: Border.all(color: selected ? activeBorder : _border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 16,
              color: selected ? activeBorder : _textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? _textPrimary : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Minimalist Progress & Live Console
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
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
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
                                  ? t('اكتملت كل الخطوات', 'Completed')
                                  : t(
                                      'توقّف التثبيت — راجع السجل',
                                      'Installation stopped — check logs',
                                    ),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              fontFamily: QudsPalette.fontMono,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark
                                  ? QudsPalette.domeGold
                                  : QudsPalette.deepBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 5,
                            backgroundColor: _border,
                            color:
                                _installSteps.any(
                                  (s) => s.state == StepRunState.failed,
                                )
                                ? QudsPalette.errRed
                                : (widget.isDark
                                      ? QudsPalette.domeGold
                                      : QudsPalette.deepBlue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._installSteps.map(_buildStepProgressRow),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _sectionLabel(t('سجل المخرجات', 'Console Output')),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _installLogs.isEmpty
                        ? null
                        : () => _copyText(
                            _installLogs.map((e) => e.message).join('\n'),
                            'سجل التثبيت',
                            'logs',
                          ),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: Text(t('نسخ السجل', 'Copy Logs')),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: QudsPalette.darkConsole,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
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
        ),
      ),
    );
  }

  Widget _buildStepProgressRow(InstallStepProgress step) {
    final Widget icon = switch (step.state) {
      StepRunState.running => const SizedBox(
        width: 15,
        height: 15,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: QudsPalette.domeGold,
        ),
      ),
      StepRunState.done => const Icon(
        Icons.check_circle_rounded,
        size: 16,
        color: QudsPalette.okGreen,
      ),
      StepRunState.warning => const Icon(
        Icons.info_outline_rounded,
        size: 16,
        color: QudsPalette.warnAmber,
      ),
      StepRunState.failed => const Icon(
        Icons.cancel_rounded,
        size: 16,
        color: QudsPalette.errRed,
      ),
      StepRunState.pending => Icon(
        Icons.circle_outlined,
        size: 15,
        color: _textMuted,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              t(step.titleAr, step.titleEn),
              style: TextStyle(
                fontSize: 13,
                fontWeight: step.state == StepRunState.running
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: step.state == StepRunState.pending
                    ? _textSecondary
                    : _textPrimary,
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
      LogLevel.info => const Color(0xFFCBD5E1),
    };
    final hh = entry.timestamp.hour.toString().padLeft(2, '0');
    final mm = entry.timestamp.minute.toString().padLeft(2, '0');
    final ss = entry.timestamp.second.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$hh:$mm:$ss  ${entry.message}',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontFamily: QudsPalette.fontMono,
          fontSize: 12,
          color: color,
          height: 1.45,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4: Serene Completion & Quick Start
  // ---------------------------------------------------------------------------
  Widget _buildStepComplete() {
    final quickCommands = [
      (
        cmd: 'quds create hello_quds',
        descAr: 'إنشاء مشروع Dart جديد بلغة قدس',
        descEn: 'Create a new Dart-target Quds project',
      ),
      (
        cmd: 'quds create --f my_app',
        descAr: 'إنشاء تطبيق Flutter كامل بلغة قدس',
        descEn: 'Create a Flutter app written in Quds',
      ),
      (
        cmd: 'quds doctor',
        descAr: 'فحص صحة البيئة والمحررات',
        descEn: 'Verify CLI and editor health',
      ),
      (
        cmd: 'quds help',
        descAr: 'عرض جميع أوامر Quds CLI',
        descEn: 'List all Quds CLI commands',
      ),
    ];

    return _centeredPage(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1426),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: QudsPalette.domeGold.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Image.asset('assets/quds_logo.png'),
                      ),
                      const Positioned(
                        right: -5,
                        bottom: -5,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: QudsPalette.okGreen,
                          child: Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t(
                      'تم تثبيت لغة قدس بنجاح!',
                      'Quds is installed and ready!',
                    ),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t(
                      'افتح نافذة طرفية جديدة لتفعيل PATH ثم ابدأ بأحد الأوامر أدناه.',
                      'Open a new terminal window if PATH was updated, then try a command below.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => widget.analyzer.openUrl(
                          'https://pub.dev/packages/quds',
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: Text(t('توثيق pub.dev', 'pub.dev Docs')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _step = 0);
                          _runScan();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: Text(t('إعادة فحص النظام', 'Re-Scan')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(t('أوامر البداية السريعة', 'Quick Start')),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < quickCommands.length; i++) ...[
                  if (i > 0) const Divider(),
                  Padding(
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
                                quickCommands[i].cmd,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontFamily: QudsPalette.fontMono,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDark
                                      ? QudsPalette.warmGold
                                      : QudsPalette.deepBlue,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t(
                                  quickCommands[i].descAr,
                                  quickCommands[i].descEn,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: t('نسخ الأمر', 'Copy command'),
                          onPressed: () => _copyText(
                            quickCommands[i].cmd,
                            quickCommands[i].cmd,
                            quickCommands[i].cmd,
                          ),
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Clean Bottom Action Bar
  // ---------------------------------------------------------------------------
  Widget _buildBottomBar() {
    final canProceed =
        !_scanning && !_runningPrereq && (_report?.canInstallQuds ?? false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          if (_step == 1)
            OutlinedButton(
              onPressed: () => setState(() => _step = 0),
              child: Text(t('السابق', 'Back')),
            )
          else if (_step == 2 && !_installing && !_installSucceeded)
            OutlinedButton(
              onPressed: () => setState(() => _step = 1),
              child: Text(t('تعديل الخيارات', 'Back to Options')),
            ),
          const Spacer(),
          if (_step == 0)
            FilledButton(
              key: const Key('next-to-options-btn'),
              onPressed: canProceed ? () => setState(() => _step = 1) : null,
              child: Text(
                canProceed
                    ? t('متابعة', 'Continue')
                    : t('ثبّت Dart SDK أولاً', 'Install Dart SDK First'),
              ),
            )
          else if (_step == 1)
            FilledButton(
              key: const Key('start-install-btn'),
              onPressed: _startInstallation,
              child: Text(t('تثبيت لغة قدس', 'Install Quds')),
            )
          else if (_step == 2 && !_installing && !_installSucceeded)
            FilledButton(
              onPressed: _startInstallation,
              child: Text(t('إعادة المحاولة', 'Retry')),
            )
          else if (_step == 3)
            FilledButton(
              key: const Key('finish-close-btn'),
              onPressed: () {
                if (widget.onClose != null) {
                  widget.onClose!();
                } else {
                  exit(0);
                }
              },
              child: Text(t('إنهاء', 'Finish')),
            ),
        ],
      ),
    );
  }
}
