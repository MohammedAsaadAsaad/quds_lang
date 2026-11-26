import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quds_installer/src/installer_engine.dart';
import 'package:quds_installer/src/models.dart';
import 'package:quds_installer/src/system_analyzer.dart';
import 'package:quds_installer/src/wizard_ui.dart';

class _FakeCommandRunner implements CommandRunner {
  _FakeCommandRunner({this.exitCodes = const {}});

  final Map<String, int> exitCodes;
  final List<String> invoked = [];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final cmd = '$executable ${arguments.join(' ')}'.trim();
    invoked.add(cmd);
    return ProcessResult(0, exitCodes[executable] ?? 0, 'ok', '');
  }

  @override
  Future<int> stream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
    required void Function(String line, {required bool isError}) onLine,
  }) async {
    final cmd = '$executable ${arguments.join(' ')}'.trim();
    invoked.add(cmd);
    onLine('Simulated output for: $cmd', isError: false);
    final code = exitCodes[cmd] ?? exitCodes[executable] ?? 0;
    return code;
  }
}

class _StubAnalyzer extends SystemAnalyzer {
  _StubAnalyzer(this._report) : super(osOverride: _report.os);

  final SystemReport _report;

  @override
  Future<SystemReport> scan() async => _report;
}

SystemReport _sampleReport({
  required bool dartReady,
  bool legacyActive = false,
  DesktopOs os = DesktopOs.windows,
}) {
  return SystemReport(
    os: os,
    osLabel: switch (os) {
      DesktopOs.windows => 'Windows',
      DesktopOs.macos => 'macOS',
      DesktopOs.linux => 'Linux',
    },
    homeDir: r'C:\Users\dev',
    pubCacheBin: r'C:\Users\dev\AppData\Local\Pub\Cache\bin',
    pubCacheBinOnPath: false,
    dartCheck: dartReady
        ? const SystemCheckItem(
            id: 'dart',
            nameAr: 'حزمة Dart SDK',
            nameEn: 'Dart SDK',
            status: CheckStatus.ready,
            version: '3.8.0',
            path: r'C:\tools\dart-sdk\bin\dart.exe',
            detailAr: 'الإصدار 3.8.0 متوافق تماماً مع لغة قدس.',
            detailEn: 'Version 3.8.0 is fully compatible with Quds.',
            requiredForQuds: true,
          )
        : SystemCheckItem(
            id: 'dart',
            nameAr: 'حزمة Dart SDK',
            nameEn: 'Dart SDK',
            status: CheckStatus.missing,
            detailAr: 'مطلوب Dart 3.3.0 أو أحدث لتشغيل مترجم لغة قدس.',
            detailEn:
                'Dart 3.3.0 or newer is required to run the Quds compiler.',
            requiredForQuds: true,
            action: SystemAnalyzer.prerequisiteFor('dart', os),
          ),
    gitCheck: const SystemCheckItem(
      id: 'git',
      nameAr: 'أداة Git',
      nameEn: 'Git',
      status: CheckStatus.ready,
      version: '2.47.0',
      path: r'C:\Program Files\Git\cmd\git.exe',
      detailAr: 'مثبّت وجاهز (2.47.0).',
      detailEn: 'Installed and ready (2.47.0).',
    ),
    flutterCheck: const SystemCheckItem(
      id: 'flutter',
      nameAr: 'إطار Flutter SDK (اختياري)',
      nameEn: 'Flutter SDK (Optional)',
      status: CheckStatus.optional,
      detailAr: 'مطلوب فقط عند بناء تطبيقات واجهة رسومية بـ Flutter + قدس.',
      detailEn: 'Only needed if you plan to build Flutter UI apps with Quds.',
    ),
    qudsCheck: const SystemCheckItem(
      id: 'quds',
      nameAr: 'أداة لغة قدس (Quds CLI)',
      nameEn: 'Quds CLI',
      status: CheckStatus.missing,
      detailAr: 'غير مثبّتة بعد — جاهزة للتثبيت الآن.',
      detailEn: 'Not installed yet — ready to install now.',
    ),
    legacyQudsLangActive: legacyActive,
    editors: const [
      EditorStatus(
        id: 'vscode',
        name: 'Visual Studio Code',
        category: 'vscode',
        detected: true,
        extensionInstalled: false,
      ),
      EditorStatus(
        id: 'cursor',
        name: 'Cursor',
        category: 'vscode',
        detected: true,
        extensionInstalled: true,
        extensionVersion: '0.1.0',
      ),
      EditorStatus(
        id: 'jetbrains',
        name: 'Android Studio / JetBrains',
        category: 'jetbrains',
        detected: false,
        extensionInstalled: false,
      ),
      EditorStatus(
        id: 'claude',
        name: 'Claude Code',
        category: 'claude',
        detected: false,
        extensionInstalled: false,
      ),
    ],
    scannedAt: DateTime(2026, 11, 26),
  );
}

void main() {
  group('SystemAnalyzer helpers', () {
    test('validates Dart SDK semver compatibility (>=3.3.0 <4.0.0)', () {
      expect(SystemAnalyzer.isDartVersionSupported('3.3.0'), isTrue);
      expect(SystemAnalyzer.isDartVersionSupported('3.14.0'), isTrue);
      expect(SystemAnalyzer.isDartVersionSupported('3.2.9'), isFalse);
      expect(SystemAnalyzer.isDartVersionSupported('2.19.6'), isFalse);
      expect(SystemAnalyzer.isDartVersionSupported('4.0.0'), isFalse);
      expect(SystemAnalyzer.isDartVersionSupported(null), isFalse);
    });

    test('extracts semantic versions from tool output', () {
      expect(
        SystemAnalyzer.extractSemver('Dart SDK version: 3.14.0 (stable)'),
        '3.14.0',
      );
      expect(
        SystemAnalyzer.extractSemver('git version 2.47.1.windows.1'),
        '2.47.1',
      );
      expect(SystemAnalyzer.extractSemver('no version here'), isNull);
    });

    test(
      'provides OS-specific prerequisite actions for Windows, macOS, Linux',
      () {
        final winDart = SystemAnalyzer.prerequisiteFor(
          'dart',
          DesktopOs.windows,
        );
        expect(winDart.command, contains('winget install'));
        expect(winDart.canRunDirectly, isTrue);

        final macDart = SystemAnalyzer.prerequisiteFor('dart', DesktopOs.macos);
        expect(macDart.command, contains('brew install dart'));
        expect(macDart.canRunDirectly, isTrue);

        final linuxDart = SystemAnalyzer.prerequisiteFor(
          'dart',
          DesktopOs.linux,
        );
        expect(linuxDart.command, contains('apt-get install'));
        expect(linuxDart.canRunDirectly, isFalse);
      },
    );
  });

  group('InstallerEngine', () {
    test(
      'builds ordered steps and executes activation, PATH, editors, doctor',
      () async {
        final runner = _FakeCommandRunner();
        final engine = InstallerEngine(
          runner: runner,
          osOverride: DesktopOs.windows,
        );
        final report = _sampleReport(dartReady: true, legacyActive: true);
        final plan = InstallPlan(
          source: InstallSource.pubDev,
          qudsVersion: defaultQudsVersion,
          addToPath: true,
          removeLegacyQudsLang: true,
          installEditorSupport: true,
          selectedEditorIds: {'vscode', 'cursor'},
          runVerification: true,
        );

        final steps = engine.buildSteps(plan);
        expect(steps.map((s) => s.id).toList(), [
          'legacy',
          'activate',
          'path',
          'editors',
          'verify',
        ]);

        final logs = <LogEntry>[];
        List<InstallStepProgress> latestSteps = [];
        final ok = await engine.execute(
          report: report,
          plan: plan,
          onStepsChanged: (s) => latestSteps = s,
          onLog: logs.add,
        );

        expect(ok, isTrue);
        expect(latestSteps.every((s) => s.state == StepRunState.done), isTrue);
        expect(
          runner.invoked.any(
            (c) => c.contains('pub global deactivate quds_lang'),
          ),
          isTrue,
        );
        expect(
          runner.invoked.any(
            (c) => c.contains('pub global activate quds $defaultQudsVersion'),
          ),
          isTrue,
        );
        expect(runner.invoked.any((c) => c.contains('powershell')), isTrue);
        expect(runner.invoked.any((c) => c.contains('quds install')), isTrue);
        expect(runner.invoked.any((c) => c.contains('quds doctor')), isTrue);
        expect(logs, isNotEmpty);
      },
    );

    test(
      'stops and marks activate step failed when activation exits non-zero',
      () async {
        final runner = _FakeCommandRunner(
          exitCodes: {r'C:\tools\dart-sdk\bin\dart.exe': 65},
        );
        final engine = InstallerEngine(
          runner: runner,
          osOverride: DesktopOs.windows,
        );
        final report = _sampleReport(dartReady: true);
        final plan = InstallPlan(
          source: InstallSource.pubDev,
          qudsVersion: defaultQudsVersion,
          addToPath: true,
          removeLegacyQudsLang: false,
          installEditorSupport: true,
          selectedEditorIds: {'vscode'},
          runVerification: true,
        );

        List<InstallStepProgress> latestSteps = [];
        final ok = await engine.execute(
          report: report,
          plan: plan,
          onStepsChanged: (s) => latestSteps = s,
          onLog: (_) {},
        );

        expect(ok, isFalse);
        expect(
          latestSteps.firstWhere((s) => s.id == 'activate').state,
          StepRunState.failed,
        );
      },
    );
  });

  group('QudsInstallerApp widget flow', () {
    testWidgets(
      'shows prerequisite helper and blocks Next when Dart SDK is missing',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final analyzer = _StubAnalyzer(_sampleReport(dartReady: false));
        final engine = InstallerEngine(
          runner: _FakeCommandRunner(),
          osOverride: DesktopOs.windows,
        );

        await tester.pumpWidget(
          QudsInstallerApp(
            analyzer: analyzer,
            engine: engine,
            enableAmbientAnimations: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('مثبّت لغة قدس'), findsOneWidget);
        expect(find.byKey(const Key('prereq-helper-panel')), findsOneWidget);

        // Next button must be disabled until Dart SDK is ready.
        final nextBtn = tester.widget<FilledButton>(
          find.byKey(const Key('next-to-options-btn')),
        );
        expect(nextBtn.onPressed, isNull);

        // Switch language to English LTR & theme to Light cleanly.
        await tester.tap(find.byKey(const Key('toggle-language-btn')));
        await tester.pumpAndSettle();
        expect(find.text('Quds Installer'), findsOneWidget);

        await tester.tap(find.byKey(const Key('toggle-theme-btn')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'walks through all 4 steps from Scan -> Options -> Install -> Complete',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final analyzer = _StubAnalyzer(_sampleReport(dartReady: true));
        final runner = _FakeCommandRunner();
        final engine = InstallerEngine(
          runner: runner,
          osOverride: DesktopOs.windows,
        );
        var closed = false;

        await tester.pumpWidget(
          QudsInstallerApp(
            analyzer: analyzer,
            engine: engine,
            enableAmbientAnimations: false,
            onClose: () => closed = true,
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 -> Step 2
        await tester.tap(find.byKey(const Key('next-to-options-btn')));
        await tester.pumpAndSettle();
        expect(find.text('تخصيص التثبيت وإضافات المحررات'), findsOneWidget);

        // Step 2 -> Step 3 -> Step 4 (simulated runner completes immediately)
        await tester.tap(find.byKey(const Key('start-install-btn')));
        await tester.pumpAndSettle();

        expect(find.text('تم تثبيت لغة قدس بنجاح!'), findsOneWidget);
        expect(find.text('quds create hello_quds'), findsOneWidget);
        expect(find.text('quds create --f my_app'), findsOneWidget);

        await tester.tap(find.byKey(const Key('finish-close-btn')));
        await tester.pumpAndSettle();
        expect(closed, isTrue);
      },
    );
  });
}
