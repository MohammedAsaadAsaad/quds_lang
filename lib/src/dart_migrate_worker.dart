import 'dart:io';

import 'dart_migrator.dart';

/// Isolated worker entrypoint for `quds migrate` on Dart/Flutter projects.
///
/// Kept separate from `bin/quds.dart` so `package:analyzer` is loaded only when
/// migrating a Dart/Flutter project and never slows down `run`/`build`/`create`.
Future<void> main(List<String> arguments) async {
  var checkOnly = false;
  var autoApprove = false;
  var keepDart = false;
  String? targetDir;

  for (final arg in arguments) {
    if (arg == '--check' || arg == '--dry-run') {
      checkOnly = true;
    } else if (arg == '--yes' || arg == '-y') {
      autoApprove = true;
    } else if (arg == '--keep-dart') {
      keepDart = true;
    } else if (arg.startsWith('-')) {
      stderr.writeln('Unknown option for migrate: $arg');
      stderr.writeln(
          'Usage: quds migrate [project-dir] [--check|--dry-run] [--yes|-y] [--keep-dart]');
      exitCode = 64;
      return;
    } else if (targetDir == null) {
      targetDir = arg;
    } else {
      stderr.writeln(
          'Usage: quds migrate [project-dir] [--check|--dry-run] [--yes|-y] [--keep-dart]');
      exitCode = 64;
      return;
    }
  }

  final projectDir = Directory(targetDir ?? '.').absolute;
  if (!projectDir.existsSync()) {
    stderr.writeln('Directory not found: ${projectDir.path}');
    exitCode = 66;
    return;
  }
  final pubspec =
      File('${projectDir.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln(
        'No pubspec.yaml found in ${projectDir.path}. Run `quds migrate` inside a Dart or Flutter project (or pass a project directory).');
    exitCode = 65;
    return;
  }

  // Step 1: Feasibility check.
  stdout.writeln('[1/3] Checking project feasibility for Quds migration...');
  final MigrationReport report;
  try {
    report = inspectProjectForMigration(projectDir);
  } on FileSystemException catch (error) {
    stderr.writeln('Migration check failed: ${error.message}');
    exitCode = 65;
    return;
  }

  final kind = report.isFlutter ? 'Flutter' : 'Dart';
  stdout.writeln('  Project: ${report.packageName} ($kind)');
  stdout.writeln('  Root:    ${report.projectRoot.path}');
  if (report.dartSdkConstraint != null) {
    stdout.writeln('  SDK:     ${report.dartSdkConstraint}');
  }
  if (!report.isSdkCompatible) {
    stderr.writeln('\n[BLOCKED] ${report.sdkCompatibilityError}');
    stdout.writeln(
        '\nFeasibility: BLOCKED — project Dart SDK is incompatible with Quds (requires Dart >=3.3.0 <4.0.0).');
    exitCode = 1;
    return;
  }
  stdout.writeln(
      '  Files:   ${report.readyFiles.length} ready, ${report.skippedFiles.length} skipped (generated), ${report.blockedFiles.length} need manual review');

  if (report.files.isEmpty) {
    stdout
        .writeln('\nNo Dart files were found under lib/. Nothing to migrate.');
    return;
  }

  for (final file in report.readyFiles) {
    stdout.writeln('  [OK]     ${file.relativePath} -> ${file.targetQudsPath}');
  }
  for (final file in report.skippedFiles) {
    final reason = file.notes.isEmpty ? 'generated' : file.notes.first;
    stdout.writeln('  [SKIP]   ${file.relativePath} ($reason)');
  }
  for (final file in report.blockedFiles) {
    stdout.writeln('  [REVIEW] ${file.relativePath}');
    for (final issue in file.issues) {
      stdout.writeln('           - $issue');
    }
  }

  if (!report.canMigrate) {
    stdout.writeln(
        '\nFeasibility: BLOCKED — no lib/**/*.dart files can be migrated automatically right now.');
    if (report.blockedFiles.isNotEmpty) {
      stdout.writeln(
          'Resolve the items marked [REVIEW] above and re-run `quds migrate`.');
      exitCode = 1;
    }
    return;
  }

  if (report.fullyReady) {
    stdout.writeln(
        '\nFeasibility: READY — all ${report.readyFiles.length} Dart file(s) can be migrated cleanly to Quds.');
  } else {
    stdout.writeln(
        '\nFeasibility: PARTIAL — ${report.readyFiles.length} file(s) can be migrated automatically; ${report.blockedFiles.length} file(s) will stay as .dart for manual review.');
  }

  if (checkOnly) {
    if (report.blockedFiles.isNotEmpty) exitCode = 1;
    return;
  }

  // Step 2: Backup lib/.
  stdout.writeln('\n[2/3] Backing up lib/ before migration...');
  final MigrationBackup backup;
  try {
    backup = backupProjectLib(projectDir);
  } on FileSystemException catch (error) {
    stderr.writeln('Backup failed: ${error.message}');
    exitCode = 73;
    return;
  }
  stdout.writeln(
      '  Backed up ${backup.fileCount} file(s) to ${backup.backupDirectory.path}');
  if (backup.analysisOptionsUpdated) {
    stdout.writeln(
        '  Excluded .quds_backup/** in analysis_options.yaml (editors & Dart analyzer will ignore backup files)');
  }

  // Step 3: Ask the user before starting migration.
  if (!autoApprove) {
    stdout.writeln('\n[3/3] Backup is complete.');
    stdout.write(
        'Start migrating ${report.readyFiles.length} file(s) from Dart to Quds? [y/N]: ');
    await stdout.flush();
    final response = (stdin.readLineSync() ?? '').trim().toLowerCase();
    if (response != 'y' && response != 'yes') {
      stdout.writeln('Migration cancelled. Original lib/ was not modified.');
      stdout.writeln('Backup preserved at: ${backup.backupDirectory.path}');
      return;
    }
  } else {
    stdout.writeln('\n[3/3] Starting migration (--yes)...');
  }

  final result = executeProjectMigration(report, keepDart: keepDart);
  stdout.writeln(
      '\nMigration Summary (${result.migratedFiles.length} file(s) migrated to Quds):');
  if (result.fileStats.isNotEmpty) {
    for (final stat in result.fileStats) {
      stdout.writeln(
          '  + ${stat.targetQudsPath}  (${stat.dartLines} -> ${stat.qudsLines} lines, ${_formatLineDelta(stat.dartLines, stat.qudsLines)})');
    }
    stdout.writeln(
        '  Total lines: ${result.totalDartLines} Dart -> ${result.totalQudsLines} Quds (${_formatLineDelta(result.totalDartLines, result.totalQudsLines)})');
  } else {
    for (final path in result.migratedFiles) {
      stdout.writeln('  + $path');
    }
  }
  if (result.keptDartFiles.isNotEmpty) {
    stdout.writeln(
        'Preserved ${result.keptDartFiles.length} .dart file(s) (generated or requiring manual review):');
    for (final path in result.keptDartFiles) {
      stdout.writeln('  = $path');
    }
  }
  if (result.qudsYamlCreated) {
    stdout.writeln('Created quds.yaml (language: 1.2)');
  }
  if (result.analysisOptionsUpdated && !backup.analysisOptionsUpdated) {
    stdout.writeln('Updated analysis_options.yaml (excluded .quds_backup/**)');
  }
  if (result.gitignoreUpdated || backup.gitignoreUpdated) {
    stdout.writeln(
        'Updated .gitignore (.quds_backup/${report.isFlutter ? ', lib/quds_gen/' : ''})');
  }
  stdout.writeln('Backup saved at: ${backup.backupDirectory.path}');
  if (report.isFlutter) {
    stdout.writeln('Next step: run `quds run -d <device>` or `quds analyze`.');
  } else {
    stdout.writeln('Next step: run `quds analyze` or `quds run`.');
  }
}

String _formatLineDelta(int before, int after) {
  final delta = after - before;
  if (before <= 0) {
    return delta == 0 ? '0 lines' : '${delta > 0 ? '+' : ''}$delta lines';
  }
  final pct = (delta.abs() * 100.0 / before).toStringAsFixed(1);
  if (delta < 0) return '$delta lines, -$pct%';
  if (delta > 0) return '+$delta lines, +$pct%';
  return '0 lines, 0.0%';
}
