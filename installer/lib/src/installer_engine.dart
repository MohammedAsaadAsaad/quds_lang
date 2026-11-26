import 'dart:async';
import 'dart:io';

import 'models.dart';
import 'system_analyzer.dart';

/// Executes the selected installation steps and streams live progress & logs
/// back to the UI so the user always sees what is running.
class InstallerEngine {
  InstallerEngine({CommandRunner? runner, DesktopOs? osOverride})
    : _runner = runner ?? const SystemCommandRunner(),
      _os = osOverride ?? _detectOs();

  final CommandRunner _runner;
  final DesktopOs _os;

  static DesktopOs _detectOs() {
    if (Platform.isWindows) return DesktopOs.windows;
    if (Platform.isMacOS) return DesktopOs.macos;
    return DesktopOs.linux;
  }

  /// Builds the ordered checklist of steps for [plan].
  List<InstallStepProgress> buildSteps(InstallPlan plan) {
    final steps = <InstallStepProgress>[];
    if (plan.removeLegacyQudsLang) {
      steps.add(
        const InstallStepProgress(
          id: 'legacy',
          titleAr: 'إزالة التفعيل القديم (quds_lang)',
          titleEn: 'Deactivate legacy quds_lang',
          state: StepRunState.pending,
        ),
      );
    }
    steps.add(
      InstallStepProgress(
        id: 'activate',
        titleAr: plan.source == InstallSource.pubDev
            ? 'تثبيت وتفعيل Quds CLI (${plan.qudsVersion}) من pub.dev'
            : 'تفعيل Quds CLI من المسار المحلي',
        titleEn: plan.source == InstallSource.pubDev
            ? 'Install & activate Quds CLI (${plan.qudsVersion}) from pub.dev'
            : 'Activate Quds CLI from local repository',
        state: StepRunState.pending,
      ),
    );
    if (plan.addToPath) {
      steps.add(
        const InstallStepProgress(
          id: 'path',
          titleAr: 'إضافة مسار pub-cache/bin إلى متغير PATH',
          titleEn: 'Add pub-cache/bin to user PATH',
          state: StepRunState.pending,
        ),
      );
    }
    if (plan.installEditorSupport && plan.selectedEditorIds.isNotEmpty) {
      steps.add(
        const InstallStepProgress(
          id: 'editors',
          titleAr:
              'تثبيت إضافات المحررات (VS Code / Cursor / JetBrains / Claude)',
          titleEn: 'Install editor extensions & IDE support',
          state: StepRunState.pending,
        ),
      );
    }
    if (plan.runVerification) {
      steps.add(
        const InstallStepProgress(
          id: 'verify',
          titleAr: 'التحقق النهائي من التثبيت (quds doctor)',
          titleEn: 'Verify installation (quds doctor)',
          state: StepRunState.pending,
        ),
      );
    }
    return steps;
  }

  /// Runs a single prerequisite action directly (e.g. `winget` or `brew`)
  /// while streaming live logs to [onLog].
  Future<bool> runPrerequisite(
    PrerequisiteAction action, {
    required void Function(LogEntry entry) onLog,
  }) async {
    if (!action.canRunDirectly || action.executable == null) {
      onLog(
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.warning,
          message: 'Run manually in terminal: ${action.command}',
        ),
      );
      return false;
    }
    onLog(
      LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.command,
        message: '\$ ${action.executable} ${action.arguments.join(' ')}',
      ),
    );
    try {
      final code = await _runner.stream(
        action.executable!,
        action.arguments,
        runInShell: _os == DesktopOs.windows,
        onLine: (line, {required isError}) => onLog(
          LogEntry(
            timestamp: DateTime.now(),
            level: isError ? LogLevel.warning : LogLevel.info,
            message: line,
          ),
        ),
      );
      if (code == 0) {
        onLog(
          LogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.success,
            message: 'Prerequisite installation completed successfully.',
          ),
        );
        return true;
      }
      onLog(
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.error,
          message: 'Command exited with code $code.',
        ),
      );
      return false;
    } catch (error) {
      onLog(
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.error,
          message: 'Failed to launch prerequisite installer: $error',
        ),
      );
      return false;
    }
  }

  /// Runs the complete installation [plan] against the detected [report].
  Future<bool> execute({
    required SystemReport report,
    required InstallPlan plan,
    required void Function(List<InstallStepProgress> steps) onStepsChanged,
    required void Function(LogEntry entry) onLog,
  }) async {
    final steps = buildSteps(plan);
    onStepsChanged(List.unmodifiable(steps));

    void updateStep(String id, StepRunState state, {String? subtitle}) {
      final idx = steps.indexWhere((s) => s.id == id);
      if (idx == -1) return;
      steps[idx] = steps[idx].copyWith(state: state, subtitle: subtitle);
      onStepsChanged(List.unmodifiable(steps));
    }

    void log(LogLevel level, String message) {
      onLog(
        LogEntry(timestamp: DateTime.now(), level: level, message: message),
      );
    }

    final dartExe = report.dartCheck.path ?? 'dart';
    final sep = _os == DesktopOs.windows ? r'\' : '/';
    final qudsExe =
        '${report.pubCacheBin}$sep${_os == DesktopOs.windows ? 'quds.bat' : 'quds'}';
    final runInShell = _os == DesktopOs.windows;

    // 1. Deactivate legacy quds_lang if present.
    if (plan.removeLegacyQudsLang) {
      updateStep('legacy', StepRunState.running);
      log(LogLevel.command, '\$ dart pub global deactivate quds_lang');
      try {
        final code = await _runner.stream(
          dartExe,
          ['pub', 'global', 'deactivate', 'quds_lang'],
          runInShell: runInShell,
          onLine: (line, {required isError}) =>
              log(isError ? LogLevel.warning : LogLevel.info, line),
        );
        updateStep(
          'legacy',
          code == 0 ? StepRunState.done : StepRunState.warning,
        );
      } catch (e) {
        log(LogLevel.warning, 'Skipped legacy cleanup: $e');
        updateStep('legacy', StepRunState.warning);
      }
    }

    // 2. Activate quds CLI.
    updateStep('activate', StepRunState.running);
    final activateArgs = plan.source == InstallSource.pubDev
        ? [
            'pub',
            'global',
            'activate',
            'quds',
            if (plan.qudsVersion.trim().isNotEmpty) plan.qudsVersion.trim(),
          ]
        : [
            'pub',
            'global',
            'activate',
            '--source',
            'path',
            plan.localRepoPath ?? '.',
          ];
    log(LogLevel.command, '\$ dart ${activateArgs.join(' ')}');
    try {
      final code = await _runner.stream(
        dartExe,
        activateArgs,
        runInShell: runInShell,
        onLine: (line, {required isError}) =>
            log(isError ? LogLevel.warning : LogLevel.info, line),
      );
      if (code != 0) {
        log(LogLevel.error, 'Quds activation failed with exit code $code.');
        updateStep('activate', StepRunState.failed);
        return false;
      }
      log(LogLevel.success, 'Quds CLI activated successfully.');
      updateStep('activate', StepRunState.done);
    } catch (e) {
      log(LogLevel.error, 'Failed to activate Quds CLI: $e');
      updateStep('activate', StepRunState.failed);
      return false;
    }

    // 3. Ensure pub-cache/bin is on PATH.
    if (plan.addToPath) {
      updateStep('path', StepRunState.running);
      final ok = await _persistPath(report.homeDir, report.pubCacheBin, log);
      updateStep('path', ok ? StepRunState.done : StepRunState.warning);
    }

    // 4. Install editor extensions via `quds install --no-update`.
    if (plan.installEditorSupport && plan.selectedEditorIds.isNotEmpty) {
      updateStep('editors', StepRunState.running);
      final cmd = File(qudsExe).existsSync() ? qudsExe : 'quds';
      final installArgs = plan.source == InstallSource.localPath
          ? ['install', '--no-update']
          : ['install'];
      log(LogLevel.command, '\$ quds ${installArgs.join(' ')}');
      try {
        final code = await _runner.stream(
          cmd,
          installArgs,
          runInShell: runInShell,
          onLine: (line, {required isError}) =>
              log(isError ? LogLevel.warning : LogLevel.info, line),
        );
        if (code == 0) {
          log(LogLevel.success, 'Editor extensions & IDE support configured.');
          updateStep('editors', StepRunState.done);
        } else {
          log(
            LogLevel.warning,
            'Editor installation exited with code $code (you can retry `quds install` later).',
          );
          updateStep('editors', StepRunState.warning);
        }
      } catch (e) {
        log(LogLevel.warning, 'Could not run quds install: $e');
        updateStep('editors', StepRunState.warning);
      }
    }

    // 5. Verification via `quds doctor`.
    if (plan.runVerification) {
      updateStep('verify', StepRunState.running);
      final cmd = File(qudsExe).existsSync() ? qudsExe : 'quds';
      log(LogLevel.command, '\$ quds doctor');
      try {
        final code = await _runner.stream(
          cmd,
          ['doctor'],
          runInShell: runInShell,
          onLine: (line, {required isError}) =>
              log(isError ? LogLevel.warning : LogLevel.info, line),
        );
        updateStep(
          'verify',
          code == 0 ? StepRunState.done : StepRunState.warning,
        );
        if (code == 0) {
          log(LogLevel.success, 'System verification passed!');
        }
      } catch (e) {
        log(LogLevel.warning, 'Verification skipped: $e');
        updateStep('verify', StepRunState.warning);
      }
    }

    return true;
  }

  Future<bool> _persistPath(
    String home,
    String binDir,
    void Function(LogLevel level, String message) log,
  ) async {
    try {
      if (_os == DesktopOs.windows) {
        final escaped = binDir.replaceAll("'", "''");
        final script =
            '''
\$bin = '$escaped'
\$user = [Environment]::GetEnvironmentVariable('Path', 'User')
if (\$user -split ';' -notcontains \$bin) {
  if ([string]::IsNullOrEmpty(\$user)) { \$next = \$bin } else { \$next = "\$user;\$bin" }
  [Environment]::SetEnvironmentVariable('Path', \$next, 'User')
  Write-Output "Added \$bin to Windows User PATH."
} else {
  Write-Output "\$bin is already in Windows User PATH."
}
''';
        log(
          LogLevel.command,
          '\$ powershell -NoProfile -Command <update PATH>',
        );
        final code = await _runner.stream(
          'powershell',
          ['-NoProfile', '-Command', script],
          onLine: (line, {required isError}) =>
              log(isError ? LogLevel.warning : LogLevel.info, line),
        );
        if (code == 0) {
          log(LogLevel.success, 'PATH configured: $binDir');
          return true;
        }
        return false;
      }

      // Linux & macOS shell profile files
      final exportLine = 'export PATH="\$PATH:$binDir"';
      final block = '\n# Quds language CLI\n$exportLine\n';
      var updated = 0;
      for (final rc in ['.bashrc', '.zshrc', '.profile']) {
        final file = File('$home/$rc');
        if (!file.existsSync() && rc == '.zshrc' && _os != DesktopOs.macos) {
          continue;
        }
        final existing = file.existsSync() ? file.readAsStringSync() : '';
        if (!existing.contains(binDir)) {
          file.writeAsStringSync('$existing$block');
          updated++;
        }
      }
      log(
        LogLevel.success,
        updated > 0
            ? 'Updated $updated shell profile(s) with $binDir.'
            : '$binDir is already configured in your shell profiles.',
      );
      return true;
    } catch (e) {
      log(LogLevel.warning, 'Could not automatically persist PATH: $e');
      return false;
    }
  }
}
