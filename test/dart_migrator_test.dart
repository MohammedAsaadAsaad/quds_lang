import 'dart:convert';
import 'dart:io';

import 'package:quds/migrate.dart';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

late Directory _snapshotDir;
late String _qudsSnapshot;
late String _workerSnapshot;

Map<String, String> _envWithWorker([Map<String, String>? base]) => {
      ...(base ?? Platform.environment),
      'QUDS_MIGRATE_WORKER': _workerSnapshot,
    };

Future<ProcessResult> _runQuds(
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
}) =>
    Process.run(
      Platform.resolvedExecutable,
      [_qudsSnapshot, ...args],
      workingDirectory: workingDirectory,
      environment: _envWithWorker(environment),
    );

Future<({int exitCode, String stdout, String stderr})> _runQudsWithStdin(
  List<String> args,
  String input, {
  String? workingDirectory,
}) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    [_qudsSnapshot, ...args],
    workingDirectory: workingDirectory,
    environment: _envWithWorker(),
  );
  final outFuture = process.stdout.transform(utf8.decoder).join();
  final errFuture = process.stderr.transform(utf8.decoder).join();
  process.stdin.write(input);
  await process.stdin.close();
  final code = await process.exitCode;
  return (
    exitCode: code,
    stdout: await outFuture,
    stderr: await errFuture,
  );
}

void main() {
  setUpAll(() async {
    _snapshotDir = Directory.systemTemp.createTempSync('quds-migrator-dill-');
    _qudsSnapshot = '${_snapshotDir.path}/quds.dill';
    _workerSnapshot = '${_snapshotDir.path}/migrate_worker.dill';
    final compiled = await Process.run(
      Platform.resolvedExecutable,
      ['compile', 'kernel', 'bin/quds.dart', '-o', _qudsSnapshot],
    );
    if (compiled.exitCode != 0) {
      fail(
          'Failed to compile bin/quds.dart: ${compiled.stdout}\n${compiled.stderr}');
    }
    final workerCompiled = await Process.run(
      Platform.resolvedExecutable,
      [
        'compile',
        'kernel',
        'lib/src/dart_migrate_worker.dart',
        '-o',
        _workerSnapshot,
      ],
    );
    if (workerCompiled.exitCode != 0) {
      fail(
          'Failed to compile dart_migrate_worker.dart: ${workerCompiled.stdout}\n${workerCompiled.stderr}');
    }
  });

  tearDownAll(() {
    if (_snapshotDir.existsSync()) {
      _snapshotDir.deleteSync(recursive: true);
    }
  });
  group('convertDartToQuds', () {
    test('converts Dart classes, properties, loops, and control flow to Quds',
        () {
      const dartCode = '''
// Counter helper
class Counter {
  final String title;
  int _value;

  Counter({required this.title, int initial = 0}) : _value = initial;

  int get value => _value;

  void increment([int step = 1]) {
    for (var i = 0; i < step; i++) {
      _value += 1;
    }
  }

  String describe() {
    if (_value == 0 || title.isEmpty) {
      return 'empty';
    }
    return '\$title: \$_value';
  }
}
''';
      final result = convertDartToQuds(dartCode);
      expect(result.issues, isEmpty, reason: result.issues.join('\n'));
      expect(result.qudsSource, isNotNull);
      final quds = result.qudsSource!;
      expect(quds, contains('# Counter helper'));
      expect(quds, contains('class Counter:'));
      expect(quds, contains('property value: int:'));
      expect(quds, contains('get = _value'));
      expect(quds, contains('for i in 0..<step:'));
      expect(quds, contains('or'));
      // Must parse cleanly with Quds parser.
      expect(() => Parser(Lexer().tokenize(quds)).parse(), returnsNormally);
    });

    test('converts Flutter widget trees to paren-free Quds block syntax', () {
      const flutterDart = '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final items = ['Budget', 'Savings'];
    return MaterialApp(
      title: 'Ledger',
      home: Scaffold(
        appBar: AppBar(title: const Text('Ledger')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (items.isEmpty)
              const Text('Empty')
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(item),
                ),
          ],
        ),
      ),
    );
  }
}
''';
      final result = convertDartToQuds(flutterDart);
      expect(result.issues, isEmpty, reason: result.issues.join('\n'));
      expect(result.qudsSource, isNotNull);
      final quds = result.qudsSource!;
      expect(quds, contains('use package:flutter/material.dart'));
      expect(quds, contains('class MyApp extends StatelessWidget:'));
      expect(quds, contains('MaterialApp:'));
      expect(quds, contains('Column:'));
      expect(quds, contains('children:'));
      expect(quds, contains('for item in items:'));
      expect(() => Parser(Lexer().tokenize(quds)).parse(), returnsNormally);
    });

    test('reports clear line-numbered issues for unsupported Dart constructs',
        () {
      const partDart = '''
part of 'other.dart';

int helper() => 1;
''';
      final result = convertDartToQuds(partDart);
      expect(result.qudsSource, isNull);
      expect(result.issues, isNotEmpty);
      expect(result.issues.first, contains('Line 1'));
    });
  });

  group('quds migrate CLI workflow', () {
    Directory makeSampleDartProject({bool includeBlocked = false}) {
      final dir = Directory.systemTemp.createTempSync('quds-migrate-proj-');
      File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: sample_app
version: 1.0.0
environment:
  sdk: ">=3.3.0 <4.0.0"
''');
      Directory('${dir.path}/lib').createSync(recursive: true);
      File('${dir.path}/lib/math_utils.dart').writeAsStringSync('''
int doubleIt(int n) => n * 2;

int sumRange(int limit) {
  var total = 0;
  for (var i = 0; i < limit; i++) {
    total += i;
  }
  return total;
}
''');
      File('${dir.path}/lib/main.dart').writeAsStringSync('''
import 'math_utils.dart';

void main() {
  final a = doubleIt(6);
  final b = sumRange(5);
  print('result=\$a,\$b');
}
''');
      File('${dir.path}/lib/model.g.dart').writeAsStringSync('''
// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'model.dart';
''');
      if (includeBlocked) {
        File('${dir.path}/lib/legacy_part.dart').writeAsStringSync('''
part of 'main.dart';
int x() => 1;
''');
      }
      return dir;
    }

    test('--check prints feasibility report without backup or modifying files',
        () async {
      final dir = makeSampleDartProject();
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = await _runQuds(['migrate', '--check', dir.path]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final out = result.stdout as String;
      expect(out, contains('[1/3] Checking project feasibility'));
      expect(out, contains('sample_app (Dart)'));
      expect(out, contains('[OK]     lib/main.dart -> lib/main.quds'));
      expect(
          out, contains('[OK]     lib/math_utils.dart -> lib/math_utils.quds'));
      expect(out, contains('[SKIP]   lib/model.g.dart'));
      expect(out, contains('Feasibility: READY'));
      expect(Directory('${dir.path}/.quds_backup').existsSync(), isFalse);
      expect(File('${dir.path}/lib/main.quds').existsSync(), isFalse);
      expect(File('${dir.path}/lib/main.dart').existsSync(), isTrue);
    });

    test('interactive decline creates lib/ backup then leaves lib/ untouched',
        () async {
      final dir = makeSampleDartProject();
      addTearDown(() => dir.deleteSync(recursive: true));

      final originalMain = File('${dir.path}/lib/main.dart').readAsStringSync();
      final res = await _runQudsWithStdin(['migrate', dir.path], 'n\n');
      expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
      expect(res.stdout, contains('[1/3] Checking project feasibility'));
      expect(res.stdout, contains('[2/3] Backing up lib/'));
      expect(res.stdout, contains('[3/3] Backup is complete.'));
      expect(
          res.stdout, contains('Start migrating 2 file(s) from Dart to Quds?'));
      expect(res.stdout, contains('Migration cancelled'));

      // Backup exists and contains original lib files.
      final backupRoot = Directory('${dir.path}/.quds_backup');
      expect(backupRoot.existsSync(), isTrue);
      final backups = backupRoot.listSync().whereType<Directory>().toList();
      expect(backups, hasLength(1));
      expect(File('${backups.single.path}/main.dart').readAsStringSync(),
          originalMain);
      expect(
          File('${backups.single.path}/math_utils.dart').existsSync(), isTrue);

      // Backup is immediately excluded from editors/analyzer even when cancelled.
      final analysisOptions = File('${dir.path}/analysis_options.yaml');
      expect(analysisOptions.existsSync(), isTrue);
      expect(analysisOptions.readAsStringSync(), contains('.quds_backup/**'));

      // Original lib/ was NOT modified.
      expect(File('${dir.path}/lib/main.dart').existsSync(), isTrue);
      expect(File('${dir.path}/lib/main.quds').existsSync(), isFalse);
      expect(File('${dir.path}/quds.yaml').existsSync(), isFalse);
    });

    test(
        'interactive confirmation backs up lib/, prints line-count summary, migrates to .quds, and migrated app executes with quds run',
        () async {
      final dir = makeSampleDartProject();
      addTearDown(() => dir.deleteSync(recursive: true));

      final res = await _runQudsWithStdin(['migrate', dir.path], 'y\n');
      expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
      expect(res.stdout, contains('[1/3] Checking project feasibility'));
      expect(res.stdout, contains('[2/3] Backing up lib/'));
      expect(res.stdout,
          contains('Excluded .quds_backup/** in analysis_options.yaml'));
      expect(res.stdout,
          contains('Migration Summary (2 file(s) migrated to Quds):'));
      expect(res.stdout, contains('+ lib/main.quds'));
      expect(res.stdout, contains('+ lib/math_utils.quds'));
      expect(res.stdout, matches(RegExp(r'\(\d+ -> \d+ lines,')));
      expect(res.stdout, matches(RegExp(r'Total lines: \d+ Dart -> \d+ Quds')));
      expect(res.stdout, contains('Created quds.yaml'));

      // Backup created before migration.
      final backups = Directory('${dir.path}/.quds_backup')
          .listSync()
          .whereType<Directory>()
          .toList();
      expect(backups, hasLength(1));
      expect(File('${backups.single.path}/main.dart').existsSync(), isTrue);

      // Migrated files replaced .dart, generated file preserved.
      expect(File('${dir.path}/lib/main.quds').existsSync(), isTrue);
      expect(File('${dir.path}/lib/math_utils.quds').existsSync(), isTrue);
      expect(File('${dir.path}/lib/main.dart').existsSync(), isFalse);
      expect(File('${dir.path}/lib/math_utils.dart').existsSync(), isFalse);
      expect(File('${dir.path}/lib/model.g.dart').existsSync(), isTrue);
      expect(File('${dir.path}/quds.yaml').readAsStringSync(),
          contains('language: 1.2'));
      expect(File('${dir.path}/.gitignore').readAsStringSync(),
          contains('.quds_backup/'));
      expect(File('${dir.path}/analysis_options.yaml').readAsStringSync(),
          contains('.quds_backup/**'));

      // Run the migrated Quds program end-to-end!
      final run =
          await _runQuds(['run', 'lib/main.quds'], workingDirectory: dir.path);
      expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
      expect((run.stdout as String).trim(), 'result=12,10');
    });

    test(
        'preserves existing analysis_options.yaml rules and dart analyze ignores backed-up Dart files',
        () async {
      final dir = Directory.systemTemp.createTempSync('quds-migrate-analyze-');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: analyze_check_app
version: 1.0.0
environment:
  sdk: ">=3.3.0 <4.0.0"
''');
      File('${dir.path}/analysis_options.yaml').writeAsStringSync('''
analyzer:
  exclude:
    - lib/generated/**
linter:
  rules:
    - avoid_print
''');
      Directory('${dir.path}/lib').createSync(recursive: true);
      File('${dir.path}/lib/main.dart').writeAsStringSync('''
int add(int a, int b) {
  final sum = a + b;
  return sum;
}
''');

      final report = inspectProjectForMigration(dir);
      final backup = backupProjectLib(dir);
      expect(backup.analysisOptionsUpdated, isTrue);
      final exec = executeProjectMigration(report);
      expect(exec.fileStats, hasLength(1));
      expect(exec.totalDartLines, 4);
      expect(exec.totalQudsLines, greaterThan(0));
      expect(exec.totalQudsLines, lessThanOrEqualTo(exec.totalDartLines));

      final optionsText =
          File('${dir.path}/analysis_options.yaml').readAsStringSync();
      expect(optionsText, contains('lib/generated/**'));
      expect(optionsText, contains('.quds_backup/**'));
      expect(optionsText, contains('avoid_print'));

      // Even if a broken Dart file sits inside .quds_backup/, dart analyze must
      // completely ignore it so editors never surface errors from the backup.
      File('${backup.backupDirectory.path}/broken_old.dart')
          .writeAsStringSync('this is not valid dart syntax {{{{');

      final analyzed = await Process.run(
        Platform.resolvedExecutable,
        ['analyze'],
        workingDirectory: dir.path,
      );
      expect(analyzed.exitCode, 0,
          reason: '${analyzed.stdout}\n${analyzed.stderr}');
      expect(analyzed.stdout, contains('No issues found!'));
    });

    test('migrates Flutter project and adds lib/quds_gen/ to .gitignore',
        () async {
      final dir = Directory.systemTemp.createTempSync('quds-migrate-flutter-');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: demo_flutter
dependencies:
  flutter:
    sdk: flutter
''');
      Directory('${dir.path}/lib').createSync(recursive: true);
      File('${dir.path}/lib/main.dart').writeAsStringSync('''
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo',
      home: Scaffold(
        body: Center(
          child: const Text('Hello Quds'),
        ),
      ),
    );
  }
}
''');

      final res = await _runQuds(['migrate', '--yes', '--keep-dart', dir.path]);
      expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
      final out = res.stdout as String;
      expect(out, contains('demo_flutter (Flutter)'));
      expect(out, contains('Feasibility: READY'));
      expect(File('${dir.path}/lib/main.quds').existsSync(), isTrue);
      expect(File('${dir.path}/lib/main.dart').existsSync(), isTrue);
      final gitignore = File('${dir.path}/.gitignore').readAsStringSync();
      expect(gitignore, contains('.quds_backup/'));
      expect(gitignore, contains('lib/quds_gen/'));
      final qudsMain = File('${dir.path}/lib/main.quds').readAsStringSync();
      expect(qudsMain, contains('MaterialApp:'));
      expect(() => Parser(Lexer().tokenize(qudsMain)).parse(), returnsNormally);
    });

    test('reports PARTIAL feasibility when some files need manual review',
        () async {
      final dir = makeSampleDartProject(includeBlocked: true);
      addTearDown(() => dir.deleteSync(recursive: true));

      final check = await _runQuds(['migrate', '--check', dir.path]);
      expect(check.exitCode, 1);
      final out = check.stdout as String;
      expect(out, contains('[REVIEW] lib/legacy_part.dart'));
      expect(out, contains('Feasibility: PARTIAL'));
    });
  });

  group('quds create --f <name>', () {
    Directory makeFakeFlutterBin() {
      final bin = Directory.systemTemp.createTempSync('quds-fake-flutter-');
      final script = File('${bin.path}/flutter');
      script.writeAsStringSync('''#!/usr/bin/env bash
if [ "\$1" = "create" ]; then
  name="\$2"
  mkdir -p "\$name/lib" "\$name/test"
  cat > "\$name/pubspec.yaml" <<EOF
name: \$name
dependencies:
  flutter:
    sdk: flutter
EOF
  echo "void main() {}" > "\$name/lib/main.dart"
  echo "void main() {}" > "\$name/test/widget_test.dart"
  echo "Fake flutter created \$name"
  exit 0
fi
exit 0
''');
      Process.runSync('chmod', ['+x', script.path]);
      return bin;
    }

    test('supports --f, -f, --flutter, and backwards-compatible flutter',
        () async {
      if (Platform.isWindows) return;
      final fakeBin = makeFakeFlutterBin();
      final workspace =
          Directory.systemTemp.createTempSync('quds-create-flags-');
      addTearDown(() {
        fakeBin.deleteSync(recursive: true);
        workspace.deleteSync(recursive: true);
      });
      final env = Map<String, String>.from(Platform.environment);
      env['PATH'] = '${fakeBin.path}:${env['PATH'] ?? ''}';

      for (final entry in [
        (['create', '--f', 'app_one'], 'app_one'),
        (['create', '-f', 'app_two'], 'app_two'),
        (['create', '--flutter', 'app_three'], 'app_three'),
        (['create', 'flutter', 'app_four'], 'app_four'),
      ]) {
        final res = await _runQuds(
          entry.$1,
          workingDirectory: workspace.path,
          environment: env,
        );
        expect(res.exitCode, 0,
            reason: 'args=${entry.$1}\n${res.stdout}\n${res.stderr}');
        expect(res.stdout, contains('Created Flutter project ${entry.$2}'));
        expect(File('${workspace.path}/${entry.$2}/lib/main.quds').existsSync(),
            isTrue);
        expect(File('${workspace.path}/${entry.$2}/lib/main.dart').existsSync(),
            isFalse);
        expect(File('${workspace.path}/${entry.$2}/quds.yaml').existsSync(),
            isTrue);
      }
    });
  });
}
