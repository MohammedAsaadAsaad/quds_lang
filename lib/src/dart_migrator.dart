import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart' as dart;
import 'package:analyzer/dart/ast/ast.dart' as d;
import 'package:analyzer/dart/ast/token.dart' as tok;
import 'package:analyzer/dart/ast/visitor.dart' as dv;
import 'package:yaml_edit/yaml_edit.dart';

import 'compiler.dart' as compiler;
import 'lexer.dart';
import 'parser.dart';

enum MigrationFileStatus {
  ready,
  skippedGenerated,
  needsManualReview,
}

class MigrationFileReport {
  const MigrationFileReport({
    required this.relativePath,
    required this.sourceFile,
    required this.targetQudsPath,
    required this.status,
    this.qudsSource,
    this.issues = const [],
    this.notes = const [],
  });

  final String relativePath;
  final File sourceFile;
  final String targetQudsPath;
  final MigrationFileStatus status;
  final String? qudsSource;
  final List<String> issues;
  final List<String> notes;
}

class MigrationReport {
  const MigrationReport({
    required this.projectRoot,
    required this.packageName,
    required this.isFlutter,
    required this.hasQudsYaml,
    required this.files,
  });

  final Directory projectRoot;
  final String packageName;
  final bool isFlutter;
  final bool hasQudsYaml;
  final List<MigrationFileReport> files;

  List<MigrationFileReport> get readyFiles => [
        for (final file in files)
          if (file.status == MigrationFileStatus.ready) file,
      ];

  List<MigrationFileReport> get skippedFiles => [
        for (final file in files)
          if (file.status == MigrationFileStatus.skippedGenerated) file,
      ];

  List<MigrationFileReport> get blockedFiles => [
        for (final file in files)
          if (file.status == MigrationFileStatus.needsManualReview) file,
      ];

  bool get canMigrate => readyFiles.isNotEmpty;
  bool get fullyReady => readyFiles.isNotEmpty && blockedFiles.isEmpty;
}

class MigrationBackup {
  const MigrationBackup({
    required this.backupDirectory,
    required this.fileCount,
    this.analysisOptionsUpdated = false,
    this.gitignoreUpdated = false,
  });

  final Directory backupDirectory;
  final int fileCount;
  final bool analysisOptionsUpdated;
  final bool gitignoreUpdated;
}

class MigratedFileStat {
  const MigratedFileStat({
    required this.sourceDartPath,
    required this.targetQudsPath,
    required this.dartLines,
    required this.qudsLines,
  });

  final String sourceDartPath;
  final String targetQudsPath;
  final int dartLines;
  final int qudsLines;

  int get lineDelta => qudsLines - dartLines;
  int get linesSaved => dartLines - qudsLines;
}

class MigrationExecutionResult {
  const MigrationExecutionResult({
    required this.migratedFiles,
    required this.keptDartFiles,
    required this.qudsYamlCreated,
    required this.gitignoreUpdated,
    this.analysisOptionsUpdated = false,
    this.fileStats = const [],
  });

  final List<String> migratedFiles;
  final List<String> keptDartFiles;
  final bool qudsYamlCreated;
  final bool gitignoreUpdated;
  final bool analysisOptionsUpdated;
  final List<MigratedFileStat> fileStats;

  int get totalDartLines =>
      fileStats.fold<int>(0, (sum, item) => sum + item.dartLines);

  int get totalQudsLines =>
      fileStats.fold<int>(0, (sum, item) => sum + item.qudsLines);

  int get totalLinesSaved => totalDartLines - totalQudsLines;
}

/// Inspects a Dart or Flutter project under [projectRoot] and reports whether
/// its `lib/**/*.dart` sources can be migrated to Quds cleanly.
MigrationReport inspectProjectForMigration(Directory projectRoot) {
  final root = projectRoot.absolute;
  final pubspecFile = File(_join(root.path, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    throw FileSystemException('pubspec.yaml was not found', root.path);
  }
  final pubspecText = pubspecFile.readAsStringSync();
  final packageName =
      RegExp(r'''^[ \t]*name:[ \t]*["']?([^"'\s#]+)''', multiLine: true)
              .firstMatch(pubspecText)
              ?.group(1) ??
          root.uri.pathSegments.where((s) => s.isNotEmpty).last;
  final isFlutter = RegExp(r'^[ \t]*sdk:[ \t]*flutter\b', multiLine: true)
      .hasMatch(pubspecText);
  final hasQudsYaml = File(_join(root.path, 'quds.yaml')).existsSync();

  final libDir = Directory(_join(root.path, 'lib'));
  if (!libDir.existsSync()) {
    return MigrationReport(
      projectRoot: root,
      packageName: packageName,
      isFlutter: isFlutter,
      hasQudsYaml: hasQudsYaml,
      files: const [],
    );
  }

  final dartFiles = <File>[];
  void collect(Directory dir) {
    final entries = dir.listSync(followLinks: false)
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final entity in entries) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (name == 'quds_gen' || name == '_quds_sdk') continue;
        collect(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        dartFiles.add(entity);
      }
    }
  }

  collect(libDir);

  final candidateRelPaths = <String>{};
  final generatedMap = <String, String>{};
  for (final file in dartFiles) {
    final rel = _relativePosix(root, file);
    final content = file.readAsStringSync();
    final generatedReason = _generatedFileReason(rel, content);
    if (generatedReason != null) {
      generatedMap[rel] = generatedReason;
    } else {
      candidateRelPaths.add(rel);
    }
  }

  final reports = <MigrationFileReport>[];
  for (final file in dartFiles) {
    final rel = _relativePosix(root, file);
    final targetQuds = '${rel.substring(0, rel.length - 5)}.quds';
    if (generatedMap.containsKey(rel)) {
      reports.add(MigrationFileReport(
        relativePath: rel,
        sourceFile: file,
        targetQudsPath: targetQuds,
        status: MigrationFileStatus.skippedGenerated,
        notes: [generatedMap[rel]!],
      ));
      continue;
    }
    final content = file.readAsStringSync();
    final outcome = convertDartToQuds(
      content,
      packageName: packageName,
      migratedLibraryPaths: candidateRelPaths,
      currentRelativePath: rel,
    );
    if (outcome.qudsSource != null) {
      reports.add(MigrationFileReport(
        relativePath: rel,
        sourceFile: file,
        targetQudsPath: targetQuds,
        status: MigrationFileStatus.ready,
        qudsSource: outcome.qudsSource,
        notes: outcome.notes,
      ));
    } else {
      reports.add(MigrationFileReport(
        relativePath: rel,
        sourceFile: file,
        targetQudsPath: targetQuds,
        status: MigrationFileStatus.needsManualReview,
        issues: outcome.issues,
      ));
    }
  }

  // Stage ready converted files in an isolated temporary mirror and verify them
  // through Quds's full semantic analyzer + Dart emitter (not just parser).
  final readyIndices = [
    for (var i = 0; i < reports.length; i++)
      if (reports[i].status == MigrationFileStatus.ready) i,
  ];
  if (readyIndices.isNotEmpty) {
    final readyPaths = {
      for (final idx in readyIndices) reports[idx].relativePath,
    };
    final packageConfigFile =
        File(_join(_join(root.path, '.dart_tool'), 'package_config.json'));
    final hasPackageConfig = packageConfigFile.existsSync();
    final staging = Directory.systemTemp.createTempSync('quds-migrate-verify-');
    try {
      File(_join(staging.path, 'pubspec.yaml')).writeAsStringSync(pubspecText);
      File(_join(staging.path, 'quds.yaml'))
          .writeAsStringSync('language: 1.2\nname: $packageName\n');

      final stagedQuds = <int, (File, String)>{};
      for (final idx in readyIndices) {
        final item = reports[idx];
        var qudsText = item.qudsSource!;
        // If some sibling files were blocked, re-convert so imports targeting
        // non-migrated `.dart` files preserve their `.dart` suffix.
        if (readyPaths.length != candidateRelPaths.length) {
          final reconverted = convertDartToQuds(
            item.sourceFile.readAsStringSync(),
            packageName: packageName,
            migratedLibraryPaths: readyPaths,
            currentRelativePath: item.relativePath,
          );
          if (reconverted.qudsSource == null) {
            reports[idx] = MigrationFileReport(
              relativePath: item.relativePath,
              sourceFile: item.sourceFile,
              targetQudsPath: item.targetQudsPath,
              status: MigrationFileStatus.needsManualReview,
              issues: reconverted.issues,
            );
            continue;
          }
          qudsText = reconverted.qudsSource!;
          reports[idx] = MigrationFileReport(
            relativePath: item.relativePath,
            sourceFile: item.sourceFile,
            targetQudsPath: item.targetQudsPath,
            status: MigrationFileStatus.ready,
            qudsSource: qudsText,
            notes: reconverted.notes,
          );
        }
        final target = File(_join(staging.path, item.targetQudsPath));
        target.parent.createSync(recursive: true);
        target.writeAsStringSync(qudsText);
        stagedQuds[idx] = (target, qudsText);
      }

      for (final item in reports) {
        if (item.status != MigrationFileStatus.ready) {
          final copied = File(_join(staging.path, item.relativePath));
          copied.parent.createSync(recursive: true);
          item.sourceFile.copySync(copied.path);
        }
      }

      final externalPackageImport = RegExp(
        r'^[ \t]*(?:use|export)[ \t]+package:([A-Za-z0-9_]+)/',
        multiLine: true,
      );
      for (final entry in stagedQuds.entries) {
        final idx = entry.key;
        final (stagedFile, qudsText) = entry.value;
        final item = reports[idx];
        final importsExternalPackage = externalPackageImport
            .allMatches(qudsText)
            .any((m) => m.group(1) != packageName);
        if (importsExternalPackage && !hasPackageConfig) {
          reports[idx] = MigrationFileReport(
            relativePath: item.relativePath,
            sourceFile: item.sourceFile,
            targetQudsPath: item.targetQudsPath,
            status: MigrationFileStatus.ready,
            qudsSource: qudsText,
            notes: [
              ...item.notes,
              'External package imports verified by parser only (run pub get for full semantic check).',
            ],
          );
          continue;
        }
        try {
          compiler.compile(
            qudsText,
            file: stagedFile.path,
            flutter: isFlutter,
            packageConfigFrom: hasPackageConfig ? pubspecFile.path : null,
          );
        } on CompilerException catch (error) {
          reports[idx] = MigrationFileReport(
            relativePath: item.relativePath,
            sourceFile: item.sourceFile,
            targetQudsPath: item.targetQudsPath,
            status: MigrationFileStatus.needsManualReview,
            issues: [
              'Quds semantic check failed at line ${error.span.line}: ${error.code}: ${error.message}',
            ],
          );
        } catch (error) {
          reports[idx] = MigrationFileReport(
            relativePath: item.relativePath,
            sourceFile: item.sourceFile,
            targetQudsPath: item.targetQudsPath,
            status: MigrationFileStatus.needsManualReview,
            issues: ['Quds semantic check failed: $error'],
          );
        }
      }
    } finally {
      if (staging.existsSync()) {
        staging.deleteSync(recursive: true);
      }
    }
  }

  return MigrationReport(
    projectRoot: root,
    packageName: packageName,
    isFlutter: isFlutter,
    hasQudsYaml: hasQudsYaml,
    files: reports,
  );
}

/// Creates a full timestamped backup copy of `<projectRoot>/lib/` under
/// `<projectRoot>/.quds_backup/lib_<timestamp>/`, and excludes `.quds_backup/**`
/// from `analysis_options.yaml` and `.gitignore` before writing backup files so
/// editors and the Dart/Flutter analyzer never inspect old backed-up Dart code.
MigrationBackup backupProjectLib(Directory projectRoot, {DateTime? now}) {
  final root = projectRoot.absolute;
  final libDir = Directory(_join(root.path, 'lib'));
  if (!libDir.existsSync()) {
    throw FileSystemException('lib/ directory was not found', root.path);
  }

  // Exclude backup directory BEFORE creating Dart files inside it so IDE file
  // watchers and Dart Analysis Server never scan the backed-up sources.
  final analysisOptionsUpdated =
      _ensureAnalysisOptionsExclude(root, '.quds_backup/**');
  final gitignoreUpdated = _ensureGitignoreEntries(root, ['.quds_backup/']);

  final stamp = _timestamp(now ?? DateTime.now());
  final backupsRoot = Directory(_join(root.path, '.quds_backup'));
  backupsRoot.createSync(recursive: true);

  var destination = Directory(_join(backupsRoot.path, 'lib_$stamp'));
  var suffix = 2;
  while (destination.existsSync()) {
    destination = Directory(_join(backupsRoot.path, 'lib_${stamp}_$suffix'));
    suffix++;
  }
  destination.createSync(recursive: true);

  var count = 0;
  void copyTree(Directory from, Directory to) {
    for (final entity in from.listSync(followLinks: false)) {
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entity is Directory) {
        final child = Directory(_join(to.path, name))..createSync();
        copyTree(entity, child);
      } else if (entity is File) {
        entity.copySync(_join(to.path, name));
        count++;
      }
    }
  }

  copyTree(libDir, destination);
  return MigrationBackup(
    backupDirectory: destination,
    fileCount: count,
    analysisOptionsUpdated: analysisOptionsUpdated,
    gitignoreUpdated: gitignoreUpdated,
  );
}

/// Writes migrated `.quds` files for every ready file in [report], updates
/// `quds.yaml`, `analysis_options.yaml`, and `.gitignore`, and removes migrated
/// `.dart` files unless [keepDart] is true.
MigrationExecutionResult executeProjectMigration(
  MigrationReport report, {
  bool keepDart = false,
}) {
  final readyPaths = {for (final f in report.readyFiles) f.relativePath};
  final migrated = <String>[];
  final kept = <String>[];
  final stats = <MigratedFileStat>[];

  for (final item in report.readyFiles) {
    // Re-convert using only the actually-migrated path set so imports pointing
    // at blocked/generated `.dart` files preserve their `.dart` suffix.
    final source = item.sourceFile.readAsStringSync();
    final converted = convertDartToQuds(
      source,
      packageName: report.packageName,
      migratedLibraryPaths: readyPaths,
      currentRelativePath: item.relativePath,
    );
    final qudsText = converted.qudsSource ?? item.qudsSource;
    if (qudsText == null) {
      kept.add(item.relativePath);
      continue;
    }
    final normalizedQuds = qudsText.endsWith('\n') ? qudsText : '$qudsText\n';
    final targetFile =
        File(_join(report.projectRoot.path, item.targetQudsPath));
    targetFile.parent.createSync(recursive: true);
    targetFile.writeAsStringSync(normalizedQuds);
    if (!keepDart && item.sourceFile.existsSync()) {
      item.sourceFile.deleteSync();
    }
    migrated.add(item.targetQudsPath);
    stats.add(MigratedFileStat(
      sourceDartPath: item.relativePath,
      targetQudsPath: item.targetQudsPath,
      dartLines: _countLines(source),
      qudsLines: _countLines(normalizedQuds),
    ));
  }

  for (final item in report.files) {
    if (item.status != MigrationFileStatus.ready) {
      kept.add(item.relativePath);
    }
  }

  final qudsYaml = File(_join(report.projectRoot.path, 'quds.yaml'));
  var qudsYamlCreated = false;
  if (!qudsYaml.existsSync()) {
    qudsYaml.writeAsStringSync('language: 1.2\nname: ${report.packageName}\n');
    qudsYamlCreated = true;
  }

  final analysisOptionsUpdated =
      _ensureAnalysisOptionsExclude(report.projectRoot, '.quds_backup/**');

  final gitignoreUpdated = _ensureGitignoreEntries(
    report.projectRoot,
    [
      '.quds_backup/',
      if (report.isFlutter) 'lib/quds_gen/',
    ],
  );

  return MigrationExecutionResult(
    migratedFiles: migrated,
    keptDartFiles: kept,
    qudsYamlCreated: qudsYamlCreated,
    gitignoreUpdated: gitignoreUpdated,
    analysisOptionsUpdated: analysisOptionsUpdated,
    fileStats: stats,
  );
}

class DartConversionResult {
  const DartConversionResult({
    this.qudsSource,
    this.issues = const [],
    this.notes = const [],
  });

  final String? qudsSource;
  final List<String> issues;
  final List<String> notes;
}

/// Converts a single Dart compilation unit to valid Quds 1.2 source using
/// `package:analyzer`'s Dart AST and validates the output with Quds's parser
/// (and optionally Quds's full semantic compiler when [verifySemantics] is true).
DartConversionResult convertDartToQuds(
  String dartSource, {
  String? packageName,
  Set<String> migratedLibraryPaths = const {},
  String? currentRelativePath,
  bool verifySemantics = false,
  bool isFlutter = false,
  String? packageConfigFrom,
}) {
  final parsed = dart.parseString(
    content: dartSource,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  if (parsed.errors.isNotEmpty) {
    return DartConversionResult(
      issues: [
        for (final err in parsed.errors)
          'Line ${parsed.lineInfo.getLocation(err.offset).lineNumber}: Dart syntax error — ${err.message}',
      ],
    );
  }

  final emitter = _DartToQudsEmitter(
    lineInfo: parsed.lineInfo,
    packageName: packageName,
    migratedLibraryPaths: migratedLibraryPaths,
    currentRelativePath: currentRelativePath,
  );

  try {
    final quds = emitter.emitUnit(parsed.unit);
    final fileLabel = currentRelativePath ?? '<migrated>';
    // Validate that the emitted Quds source parses cleanly with Quds's parser.
    Parser(Lexer().tokenize(quds, file: fileLabel)).parse();
    if (verifySemantics) {
      compiler.compile(
        quds,
        file: '<input>',
        flutter: isFlutter,
        packageConfigFrom: packageConfigFrom,
      );
    }
    return DartConversionResult(qudsSource: quds, notes: emitter.notes);
  } on _UnsupportedDart catch (error) {
    return DartConversionResult(
        issues: ['Line ${error.line}: ${error.reason}']);
  } on CompilerException catch (error) {
    final stage = verifySemantics ? 'verification' : 'parse verification';
    return DartConversionResult(
      issues: [
        'Generated Quds failed $stage at line ${error.span.line}: ${error.code}: ${error.message}',
      ],
    );
  } catch (error) {
    return DartConversionResult(issues: ['Conversion failed: $error']);
  }
}

class _UnsupportedDart implements Exception {
  const _UnsupportedDart(this.line, this.reason);
  final int line;
  final String reason;
}

class _DartToQudsEmitter {
  _DartToQudsEmitter({
    required this.lineInfo,
    this.packageName,
    this.migratedLibraryPaths = const {},
    this.currentRelativePath,
  });

  final dynamic lineInfo;
  final String? packageName;
  final Set<String> migratedLibraryPaths;
  final String? currentRelativePath;
  final List<String> notes = [];

  /// Lexical variable scopes to emit Quds `shadow` whenever Dart shadows an
  /// outer local or parameter binding (`QUDS-090`).
  final List<Set<String>> _scopes = [];
  var _tempCounter = 0;
  final List<({int depth, List<String> lines})?> _hoistFrames = [];

  String _freshTemp([String prefix = '_qd']) => '$prefix${_tempCounter++}';

  String _withHoistFrame(int depth, String Function() emit) {
    final frame = (depth: depth, lines: <String>[]);
    _hoistFrames.add(frame);
    try {
      final body = emit();
      if (frame.lines.isEmpty) return body;
      return '${frame.lines.join('\n')}\n$body';
    } finally {
      _hoistFrames.removeLast();
    }
  }

  T _withoutHoisting<T>(T Function() body) {
    _hoistFrames.add(null);
    try {
      return body();
    } finally {
      _hoistFrames.removeLast();
    }
  }

  bool _needsBlockLambda(d.FunctionExpression node) {
    final body = node.body;
    if (body is d.ExpressionFunctionBody) {
      return !_canInlineLambdaExpr(body.expression);
    }
    if (body is d.BlockFunctionBody) {
      final stmts = body.block.statements;
      if (stmts.length != 1) return true;
      final single = stmts.single;
      if (single is d.ExpressionStatement) {
        return !_canInlineLambdaExpr(single.expression);
      }
      if (single is d.ReturnStatement && single.expression != null) {
        return !_canInlineLambdaExpr(single.expression!);
      }
      return true;
    }
    return true;
  }

  bool _canInlineLambdaExpr(d.Expression expr) {
    if (expr is d.AssignmentExpression ||
        expr is d.CascadeExpression ||
        expr is d.ThrowExpression ||
        expr is d.SwitchExpression) {
      return false;
    }
    if (expr is d.PostfixExpression &&
        (expr.operator.lexeme == '++' || expr.operator.lexeme == '--')) {
      return false;
    }
    if (expr is d.PrefixExpression &&
        (expr.operator.lexeme == '++' || expr.operator.lexeme == '--')) {
      return false;
    }
    if (expr is d.FunctionExpression && _needsBlockLambda(expr)) {
      return false;
    }
    return !_containsBlockConstruct(expr);
  }

  bool _containsBlockConstruct(d.AstNode root) {
    final finder = _BlockConstructFinder(this);
    root.visitChildren(finder);
    return finder.found;
  }

  String? _tryHoistBlockLambda(
    String params,
    String asyncMod,
    d.BlockFunctionBody body,
  ) {
    final frame = _hoistFrames.isEmpty ? null : _hoistFrames.last;
    if (frame == null) return null;
    final name = _freshTemp('_qfn');
    final pad = '  ' * frame.depth;
    final stmts = _statements(body.block.statements, frame.depth + 1);
    final blockBody =
        stmts.isEmpty ? '${'  ' * (frame.depth + 1)}return' : stmts;
    frame.lines.add('$pad$name = ($params)$asyncMod -> :\n$blockBody');
    return name;
  }

  static const _qudsReservedIdentifiers = {
    'readonly',
    'capture',
    'shadow',
    'sealed',
    'use',
    'label',
    'match',
    'type',
  };

  int _lineOf(d.AstNode node) =>
      lineInfo.getLocation(node.offset).lineNumber as int;

  Never _fail(d.AstNode node, String reason) =>
      throw _UnsupportedDart(_lineOf(node), reason);

  void _checkIdentifierName(d.AstNode node, String name) {
    if (_qudsReservedIdentifiers.contains(name)) {
      _fail(
        node,
        'identifier "$name" is a reserved keyword in Quds; rename it before migrating',
      );
    }
  }

  T _withScope<T>(T Function() body, {Iterable<String> initial = const []}) {
    _scopes.add({...initial});
    try {
      return body();
    } finally {
      _scopes.removeLast();
    }
  }

  bool _isDeclaredInOuterScope(String name) {
    for (var i = 0; i < _scopes.length - 1; i++) {
      if (_scopes[i].contains(name)) return true;
    }
    return false;
  }

  void _declareInCurrentScope(String name) {
    if (_scopes.isNotEmpty) {
      _scopes.last.add(name);
    }
  }

  Iterable<String> _parameterNames(d.FormalParameterList? list) {
    if (list == null) return const [];
    return [
      for (final p in list.parameters)
        if (p.name != null) p.name!.lexeme,
    ];
  }

  String emitUnit(d.CompilationUnit unit) {
    final blocks = <String>[];
    final directiveLines = <String>[];
    for (final directive in unit.directives) {
      final emitted = _directive(directive);
      if (emitted != null && emitted.isNotEmpty) {
        directiveLines.add(emitted);
      }
    }
    if (directiveLines.isNotEmpty) {
      blocks.add(directiveLines.join('\n'));
    }
    for (final decl in unit.declarations) {
      blocks.add(_declaration(decl));
    }
    return '${blocks.join('\n\n')}\n';
  }

  String _leadingComments(d.AstNode node, int depth) {
    final pad = '  ' * depth;
    final lines = <String>[];
    tok.Token? comment = node.beginToken.precedingComments;
    while (comment != null) {
      final lexeme = comment.lexeme.trim();
      if (lexeme.startsWith('///')) {
        lines.add('$pad$lexeme');
      } else if (lexeme.startsWith('//')) {
        final body = lexeme.substring(2).trimLeft();
        lines.add(body.isEmpty ? '$pad#' : '$pad# $body');
      } else if (lexeme.startsWith('/*') && lexeme.endsWith('*/')) {
        lines.add('$pad$lexeme');
      }
      comment = comment.next;
    }
    return lines.isEmpty ? '' : '${lines.join('\n')}\n';
  }

  String? _directive(d.Directive node) {
    if (node is d.LibraryDirective) return null;
    if (node is d.PartDirective || node is d.PartOfDirective) {
      _fail(node, 'part/part of directives require manual migration review');
    }
    if (node is d.ImportDirective) {
      if (node.configurations.isNotEmpty) {
        _fail(node,
            'conditional Dart imports require manual when-import migration');
      }
      final rawUri = node.uri.stringValue ?? '';
      final uri = _rewriteImportUri(rawUri);
      final buf = StringBuffer('use $uri');
      if (node.prefix != null) {
        buf.write(' as ${node.prefix!.name}');
      }
      if (node.deferredKeyword != null) {
        buf.write(' deferred');
      }
      buf.write(_combinators(node.combinators));
      return '${_leadingComments(node, 0)}$buf';
    }
    if (node is d.ExportDirective) {
      if (node.configurations.isNotEmpty) {
        _fail(node, 'conditional Dart exports require manual migration review');
      }
      final rawUri = node.uri.stringValue ?? '';
      final uri = _rewriteImportUri(rawUri);
      final buf = StringBuffer('export $uri');
      buf.write(_combinators(node.combinators));
      return '${_leadingComments(node, 0)}$buf';
    }
    _fail(node, 'unsupported directive: ${node.runtimeType}');
  }

  String _combinators(d.NodeList<d.Combinator> combinators) {
    final buf = StringBuffer();
    for (final c in combinators) {
      if (c is d.ShowCombinator) {
        buf.write(' show ${c.shownNames.map((n) => n.name).join(', ')}');
      } else if (c is d.HideCombinator) {
        buf.write(' hide ${c.hiddenNames.map((n) => n.name).join(', ')}');
      }
    }
    return buf.toString();
  }

  String _rewriteImportUri(String rawUri) {
    if (rawUri.startsWith('dart:')) return rawUri;
    if (rawUri.startsWith('package:')) {
      if (packageName != null &&
          rawUri.startsWith('package:$packageName/') &&
          rawUri.endsWith('.dart')) {
        final insideLib = rawUri.substring('package:$packageName/'.length);
        final candidate = 'lib/$insideLib';
        if (migratedLibraryPaths.contains(candidate)) {
          return rawUri.substring(0, rawUri.length - 5);
        }
      }
      return rawUri;
    }
    if (rawUri.endsWith('.dart') && currentRelativePath != null) {
      final resolved = _resolveRelativePosix(currentRelativePath!, rawUri);
      if (resolved != null && migratedLibraryPaths.contains(resolved)) {
        final noExt = rawUri.substring(0, rawUri.length - 5);
        if (packageName != null && resolved.startsWith('lib/')) {
          final inside = resolved.substring(4, resolved.length - 5);
          return 'package:$packageName/$inside';
        }
        return '"$noExt.quds"';
      }
    }
    return '"$rawUri"';
  }

  String _declaration(d.CompilationUnitMember node) {
    final comments = _leadingComments(node, 0);
    if (node is d.FunctionDeclaration) {
      return '$comments${_functionDeclaration(node, 0)}';
    }
    if (node is d.TopLevelVariableDeclaration) {
      return '$comments${_variableList(node.variables, 0)}';
    }
    if (node is d.ClassDeclaration) {
      return '$comments${_classDeclaration(node)}';
    }
    if (node is d.MixinDeclaration) {
      return '$comments${_mixinDeclaration(node)}';
    }
    if (node is d.EnumDeclaration) {
      return '$comments${_enumDeclaration(node)}';
    }
    if (node is d.ExtensionDeclaration) {
      return '$comments${_extensionDeclaration(node)}';
    }
    if (node is d.GenericTypeAlias) {
      return '$comments${_typeAlias(node)}';
    }
    _fail(node, 'unsupported top-level declaration: ${node.runtimeType}');
  }

  String _typeAlias(d.GenericTypeAlias node) {
    final tp = node.typeParameters?.toSource() ?? '';
    return 'type ${node.name.lexeme}$tp = ${_typeAnnotation(node.type)}';
  }

  String _enumDeclaration(d.EnumDeclaration node) {
    final body = node.body;
    final header = StringBuffer('enum ${node.namePart.typeName.lexeme}');
    final typeParams = node.namePart.typeParameters;
    if (typeParams != null) {
      header.write(typeParams.toSource());
    }
    if (node.withClause != null) {
      header.write(
          ' with ${node.withClause!.mixinTypes.map(_typeAnnotation).join(', ')}');
    }
    if (node.implementsClause != null) {
      header.write(
          ' implements ${node.implementsClause!.interfaces.map(_typeAnnotation).join(', ')}');
    }
    final buf = StringBuffer('$header:\n');
    for (final c in body.constants) {
      final name = c.name.lexeme;
      _checkIdentifierName(c, name);
      final args = c.arguments;
      if (args == null) {
        buf.writeln('  $name');
      } else {
        final ta = args.typeArguments == null
            ? ''
            : '<${args.typeArguments!.arguments.map(_typeAnnotation).join(', ')}>';
        final ctor = args.constructorSelector == null
            ? ''
            : '.${args.constructorSelector!.name.name}';
        final argText = _inlineArgs(args.argumentList, 1);
        buf.writeln('  $name$ta$ctor($argText)');
      }
    }
    if (body.members.isNotEmpty) {
      final hasExplicitCtor =
          body.members.any((m) => m is d.ConstructorDeclaration);
      final members = _classMembers(
        body.members,
        const {},
        1,
        hasExplicitConstructor: hasExplicitCtor,
      );
      if (members.isNotEmpty) {
        buf.writeln();
        buf.writeln(members.join('\n\n'));
      }
    }
    return buf.toString().trimRight();
  }

  String _extensionDeclaration(d.ExtensionDeclaration node) {
    final onClause = node.onClause;
    if (onClause == null) {
      _fail(node, 'extension without on-clause is unsupported');
    }
    final name = node.name != null ? ' ${node.name!.lexeme}' : '';
    final buf = StringBuffer(
        'extend ${_typeAnnotation(onClause.extendedType)}$name:\n');
    final members = _classMembers(node.body.members, const {}, 1);
    if (members.isEmpty) {
      _fail(node, 'empty extension declaration requires manual review');
    }
    buf.write(members.join('\n\n'));
    return buf.toString();
  }

  String _mixinDeclaration(d.MixinDeclaration node) {
    final tp = node.typeParameters?.toSource() ?? '';
    final buf = StringBuffer('mixin ${node.name.lexeme}$tp');
    if (node.onClause != null) {
      final supers =
          node.onClause!.superclassConstraints.map(_typeAnnotation).join(', ');
      buf.write(' on $supers');
    }
    if (node.implementsClause != null) {
      final impls =
          node.implementsClause!.interfaces.map(_typeAnnotation).join(', ');
      buf.write(' implements $impls');
    }
    buf.writeln(':');
    final members = _classMembers(node.body.members, const {}, 1);
    if (members.isEmpty) {
      _fail(node, 'empty mixin declaration requires manual review');
    }
    buf.write(members.join('\n\n'));
    return buf.toString();
  }

  String _classDeclaration(d.ClassDeclaration node) {
    final modifiers = <String>[];
    if (node.abstractKeyword != null) modifiers.add('abstract');
    if (node.sealedKeyword != null) modifiers.add('sealed');
    if (node.baseKeyword != null) modifiers.add('base');
    if (node.interfaceKeyword != null) modifiers.add('interface');
    if (node.finalKeyword != null) modifiers.add('final');
    if (node.mixinKeyword != null) modifiers.add('mixin');
    final prefix = modifiers.isEmpty ? '' : '${modifiers.join(' ')} ';
    final tp = node.namePart.typeParameters?.toSource() ?? '';
    final buf =
        StringBuffer('${prefix}class ${node.namePart.typeName.lexeme}$tp');
    if (node.extendsClause != null) {
      buf.write(' extends ${_typeAnnotation(node.extendsClause!.superclass)}');
    }
    if (node.withClause != null) {
      final mixins =
          node.withClause!.mixinTypes.map(_typeAnnotation).join(', ');
      buf.write(' with $mixins');
    }
    if (node.implementsClause != null) {
      final impls =
          node.implementsClause!.interfaces.map(_typeAnnotation).join(', ');
      buf.write(' implements $impls');
    }
    buf.writeln(':');

    final body = node.body;
    if (body is! d.BlockClassBody) {
      buf.write('  init()');
      return buf.toString();
    }

    // Analyze a simple default generative constructor (e.g. Flutter Widget
    // `const MyWidget({super.key, required this.title, this.count = 0});`)
    // and fold its field initializers directly into Quds field declarations!
    final absorbedFieldMeta = <String, _FieldCtorMeta>{};
    d.ConstructorDeclaration? absorbedCtor;
    final constructors =
        body.members.whereType<d.ConstructorDeclaration>().toList();
    if (constructors.length == 1) {
      final ctor = constructors.single;
      if (ctor.name == null &&
          ctor.factoryKeyword == null &&
          ctor.redirectedConstructor == null &&
          ctor.initializers.every(_isTrivialSuperKeyInit) &&
          ctor.body is d.EmptyFunctionBody &&
          _canAbsorbConstructor(ctor)) {
        absorbedCtor = ctor;
        for (final param in ctor.parameters.parameters) {
          final meta = _extractFieldCtorMeta(param);
          if (meta != null) {
            absorbedFieldMeta[meta.fieldName] = meta;
          }
        }
      }
    }

    final remaining = [
      for (final m in body.members)
        if (!identical(m, absorbedCtor)) m,
    ];
    final hasExplicitConstructor =
        remaining.any((m) => m is d.ConstructorDeclaration);
    final rendered = _classMembers(
      remaining,
      absorbedFieldMeta,
      1,
      hasExplicitConstructor: hasExplicitConstructor,
    );
    if (rendered.isEmpty) {
      buf.write('  init()');
    } else {
      buf.write(rendered.join('\n\n'));
    }
    return buf.toString();
  }

  bool _isTrivialSuperKeyInit(d.ConstructorInitializer init) {
    if (init is d.SuperConstructorInvocation) {
      return init.constructorName == null &&
          init.argumentList.arguments
              .every((a) => a is d.NamedArgument && a.name.lexeme == 'key');
    }
    return false;
  }

  bool _canAbsorbConstructor(d.ConstructorDeclaration ctor) {
    // Only absorb constructors whose field parameters are ALL named (e.g.
    // Flutter widgets `const MyWidget({super.key, required this.title})`),
    // because Quds's synthesized field constructor accepts named parameters.
    // Positional Dart constructors (`Point(this.x, this.y)`) must stay as
    // explicit `init(...)` so positional call sites remain 100% compatible.
    for (final param in ctor.parameters.parameters) {
      if (!param.isNamed) return false;
      if (param is d.FieldFormalParameter) continue;
      if (param is d.SuperFormalParameter && param.name.lexeme == 'key') {
        continue;
      }
      if (param is d.RegularFormalParameter && param.name?.lexeme == 'key') {
        continue;
      }
      return false;
    }
    return true;
  }

  _FieldCtorMeta? _extractFieldCtorMeta(d.FormalParameter param) {
    final isRequired = param.isRequiredNamed || param.isRequiredPositional;
    final defaultExpr = param.defaultClause?.value;
    if (param is d.FieldFormalParameter) {
      return _FieldCtorMeta(
        fieldName: param.name.lexeme,
        required: isRequired && defaultExpr == null,
        defaultValue: defaultExpr,
      );
    }
    return null;
  }

  List<String> _classMembers(
    List<d.ClassMember> members,
    Map<String, _FieldCtorMeta> absorbedFields,
    int depth, {
    bool hasExplicitConstructor = false,
  }) {
    final pad = '  ' * depth;
    final out = <String>[];
    final getterMap = <String, d.MethodDeclaration>{};
    final setterMap = <String, d.MethodDeclaration>{};
    for (final m in members) {
      if (m is d.MethodDeclaration) {
        if (m.isGetter) getterMap[m.name.lexeme] = m;
        if (m.isSetter) setterMap[m.name.lexeme] = m;
      }
    }
    final emittedProperties = <String>{};

    for (final member in members) {
      final comments = _leadingComments(member, depth);
      if (member is d.FieldDeclaration) {
        out.add(
            '$comments${_fieldDeclaration(member, absorbedFields, depth, hasExplicitConstructor: hasExplicitConstructor)}');
      } else if (member is d.ConstructorDeclaration) {
        out.add('$comments${_constructorDeclaration(member, depth)}');
      } else if (member is d.MethodDeclaration) {
        if (member.isGetter || member.isSetter) {
          final name = member.name.lexeme;
          if (!emittedProperties.add(name)) continue;
          out.add('$comments${_propertyDeclaration(
            name,
            getterMap[name],
            setterMap[name],
            depth,
          )}');
        } else if (member.isOperator) {
          out.add('$comments${_operatorDeclaration(member, depth)}');
        } else {
          out.add('$comments${_methodDeclaration(member, depth)}');
        }
      } else {
        out.add('$pad# skipped ${member.runtimeType}');
      }
    }
    return out;
  }

  String _fieldDeclaration(
    d.FieldDeclaration node,
    Map<String, _FieldCtorMeta> absorbed,
    int depth, {
    bool hasExplicitConstructor = false,
  }) {
    final pad = '  ' * depth;
    final isStatic = node.isStatic;
    final vars = node.fields;
    final isFinal = vars.isFinal;
    final isConst = vars.isConst;
    final isLate = vars.isLate;
    final typeText = vars.type == null ? null : _typeAnnotation(vars.type!);
    final lines = <String>[];
    for (final v in vars.variables) {
      final name = v.name.lexeme;
      _checkIdentifierName(v, name);
      final meta = absorbed[name];
      final prefix = StringBuffer();
      if (isStatic) prefix.write('static ');
      if (isLate) prefix.write('late ');
      if (isConst) {
        prefix.write('const ');
      } else if (!isFinal) {
        prefix.write('var ');
      }
      final typeSuffix = typeText == null ? '' : ': $typeText';
      if (v.initializer != null) {
        lines.add(
            '$pad$prefix$name$typeSuffix = ${_expression(v.initializer!, depth)}');
      } else if (meta != null && meta.defaultValue != null) {
        lines.add(
            '$pad$prefix$name$typeSuffix = ${_expression(meta.defaultValue!, depth)}');
      } else if (meta != null && meta.required) {
        lines.add('$pad$prefix$name$typeSuffix required');
      } else if (hasExplicitConstructor || isLate) {
        lines.add('$pad$prefix$name$typeSuffix');
      } else if (typeText != null && typeText.endsWith('?')) {
        lines.add('$pad$prefix$name$typeSuffix = null');
      } else {
        lines.add('$pad$prefix$name$typeSuffix required');
      }
    }
    return lines.join('\n');
  }

  String _constructorDeclaration(d.ConstructorDeclaration node, int depth) {
    final pad = '  ' * depth;
    if (node.redirectedConstructor != null) {
      _fail(node,
          'redirecting factory constructor requires manual migration review');
    }
    final kind = StringBuffer();
    if (node.factoryKeyword != null) kind.write('factory ');
    if (node.constKeyword != null) kind.write('const ');
    final name = node.name != null ? ' ${node.name!.lexeme}' : '';
    final params = _parameterList(node.parameters);
    final paramNames = _parameterNames(node.parameters).toSet();
    final body = node.body;

    return _withScope(() {
      final initLines = <String>[];
      var superSuffix = '';
      for (final init in node.initializers) {
        if (init is d.ConstructorFieldInitializer) {
          final fieldName = init.fieldName.name;
          final target =
              paramNames.contains(fieldName) ? 'this.$fieldName' : fieldName;
          initLines.add(
              '${'  ' * (depth + 1)}$target = ${_expression(init.expression, depth + 1)}');
        } else if (init is d.SuperConstructorInvocation) {
          if (!_isTrivialSuperKeyInit(init) &&
              (init.constructorName != null ||
                  init.argumentList.arguments.isNotEmpty)) {
            final ctorName = init.constructorName == null
                ? ''
                : '.${init.constructorName!.name}';
            final argsText = _inlineArgs(init.argumentList, depth);
            superSuffix = ' super$ctorName($argsText)';
          }
        } else if (init is d.RedirectingConstructorInvocation) {
          final ctorName = init.constructorName == null
              ? ''
              : '.${init.constructorName!.name}';
          final argsText = _inlineArgs(init.argumentList, depth);
          superSuffix = ' this$ctorName($argsText)';
        } else if (init is d.AssertInitializer) {
          initLines.add(
              '${'  ' * (depth + 1)}assert ${_expression(init.condition, depth + 1)}');
        } else {
          _fail(init,
              'constructor initializer ${init.runtimeType} requires manual review');
        }
      }
      final header = '$pad${kind}init$name($params)$superSuffix';
      if (body is d.EmptyFunctionBody) {
        if (initLines.isEmpty) {
          return header;
        }
        return '$header:\n${initLines.join('\n')}';
      }
      if (body is d.BlockFunctionBody) {
        final stmts = _statements(body.block.statements, depth + 1);
        final combined = [...initLines, if (stmts.isNotEmpty) stmts];
        if (combined.isEmpty) {
          return header;
        }
        return '$header:\n${combined.join('\n')}';
      }
      if (body is d.ExpressionFunctionBody) {
        return '$header = ${_expression(body.expression, depth)}';
      }
      _fail(node, 'unsupported constructor body');
    }, initial: paramNames);
  }

  String _propertyDeclaration(
    String name,
    d.MethodDeclaration? getter,
    d.MethodDeclaration? setter,
    int depth,
  ) {
    final pad = '  ' * depth;
    final isStatic = (getter?.isStatic ?? setter?.isStatic) == true;
    if (isStatic) {
      _fail(getter ?? setter!, 'static getter/setter requires manual review');
    }
    _checkIdentifierName(getter ?? setter!, name);
    final typeNode = getter?.returnType ??
        (setter?.parameters?.parameters.isNotEmpty == true
            ? _paramType(setter!.parameters!.parameters.first)
            : null);
    final typeName = typeNode == null ? 'dynamic' : _typeAnnotation(typeNode);

    final buf = StringBuffer('${pad}property $name: $typeName:\n');
    if (getter != null) {
      final body = getter.body;
      _withScope(() {
        if (body is d.ExpressionFunctionBody) {
          buf.writeln(
              '${'  ' * (depth + 1)}get = ${_expression(body.expression, depth + 1)}');
        } else {
          buf.writeln('${'  ' * (depth + 1)}get:');
          buf.writeln(_bodyStatements(body, depth + 2));
        }
      });
    }
    if (setter != null) {
      final paramName = setter.parameters?.parameters.isNotEmpty == true
          ? (setter.parameters!.parameters.first.name?.lexeme ?? 'value')
          : 'value';
      _checkIdentifierName(setter, paramName);
      _withScope(() {
        buf.writeln('${'  ' * (depth + 1)}set($paramName):');
        buf.writeln(_bodyStatements(setter.body, depth + 2));
      }, initial: [paramName]);
    }
    return buf.toString().trimRight();
  }

  String _operatorDeclaration(d.MethodDeclaration node, int depth) {
    final pad = '  ' * depth;
    final op = node.name.lexeme;
    final params =
        node.parameters == null ? '' : _parameterList(node.parameters!);
    final ret = node.returnType == null
        ? ''
        : ' -> ${_typeAnnotation(node.returnType!)}';
    return _withScope(
      () => _emitCallable('${pad}operator $op($params)$ret', node.body, depth),
      initial: _parameterNames(node.parameters),
    );
  }

  String _methodDeclaration(d.MethodDeclaration node, int depth) {
    final pad = '  ' * depth;
    final staticPrefix = node.isStatic ? 'static ' : '';
    final tp = node.typeParameters?.toSource() ?? '';
    final params =
        node.parameters == null ? '' : _parameterList(node.parameters!);
    final asyncMod = _asyncModifier(node.body);
    final ret = _returnTypeClause(node.returnType, node.body);
    final header =
        '$pad$staticPrefix${node.name.lexeme}$tp($params)$asyncMod$ret';
    return _withScope(
      () => _emitCallable(header, node.body, depth),
      initial: _parameterNames(node.parameters),
    );
  }

  String _functionDeclaration(d.FunctionDeclaration node, int depth) {
    final pad = '  ' * depth;
    final fn = node.functionExpression;
    if (node.isGetter || node.isSetter) {
      _fail(node, 'top-level getter/setter requires manual migration review');
    }
    final tp = fn.typeParameters?.toSource() ?? '';
    final params = fn.parameters == null ? '' : _parameterList(fn.parameters!);
    final asyncMod = _asyncModifier(fn.body);
    final ret = _returnTypeClause(node.returnType, fn.body);
    final header = '$pad${node.name.lexeme}$tp($params)$asyncMod$ret';
    return _withScope(
      () => _emitCallable(header, fn.body, depth),
      initial: _parameterNames(fn.parameters),
    );
  }

  String _asyncModifier(d.FunctionBody body) {
    if (body.isAsynchronous && body.isGenerator) return ' async*';
    if (body.isSynchronous && body.isGenerator) return ' sync*';
    if (body.isAsynchronous) return ' async';
    return '';
  }

  String _returnTypeClause(d.TypeAnnotation? type, d.FunctionBody body) {
    if (type == null) return '';
    var text = _typeAnnotation(type);
    if (body.isAsynchronous && body.isGenerator) {
      if (text.startsWith('Stream<') && text.endsWith('>')) {
        text = text.substring(7, text.length - 1).trim();
      } else if (text == 'Stream') {
        text = 'dynamic';
      }
    } else if (body.isSynchronous && body.isGenerator) {
      if (text.startsWith('Iterable<') && text.endsWith('>')) {
        text = text.substring(9, text.length - 1).trim();
      } else if (text == 'Iterable') {
        text = 'dynamic';
      }
    } else if (body.isAsynchronous) {
      if (text.startsWith('Future<') && text.endsWith('>')) {
        text = text.substring(7, text.length - 1).trim();
      } else if (text == 'Future') {
        text = 'dynamic';
      }
    }
    return ' -> $text';
  }

  String _emitCallable(String header, d.FunctionBody body, int depth) {
    if (body is d.EmptyFunctionBody) {
      return header;
    }
    if (body is d.ExpressionFunctionBody) {
      final expr = body.expression;
      final isVoid = header.endsWith('-> void');
      final pad = '  ' * (depth + 1);
      final frame = (depth: depth + 1, lines: <String>[]);
      _hoistFrames.add(frame);
      late final String rendered;
      final useBlock = _shouldFormatAsBlockCall(expr);
      try {
        rendered = _expression(
          expr,
          useBlock ? depth + 1 : depth,
          allowBlock: useBlock,
        );
      } finally {
        _hoistFrames.removeLast();
      }
      if (frame.lines.isNotEmpty) {
        final stmt = isVoid ? '$pad$rendered' : '${pad}return $rendered';
        return '$header:\n${frame.lines.join('\n')}\n$stmt';
      }
      if (useBlock) {
        return '$header:\n${pad}return $rendered';
      }
      return '$header = $rendered';
    }
    if (body is d.BlockFunctionBody) {
      final stmts = _statements(body.block.statements, depth + 1);
      return '$header:\n${stmts.isEmpty ? '${'  ' * (depth + 1)}return' : stmts}';
    }
    _fail(body, 'unsupported function body: ${body.runtimeType}');
  }

  String _bodyStatements(d.FunctionBody body, int depth) {
    final pad = '  ' * depth;
    if (body is d.ExpressionFunctionBody) {
      return _withHoistFrame(
        depth,
        () =>
            '${pad}return ${_expression(body.expression, depth, allowBlock: true)}',
      );
    }
    if (body is d.BlockFunctionBody) {
      final stmts = _statements(body.block.statements, depth);
      return stmts.isEmpty ? '${pad}return' : stmts;
    }
    _fail(body, 'unsupported accessor body');
  }

  String _parameterList(d.FormalParameterList list, {bool isLambda = false}) {
    final parts = <String>[];
    final optPositional = <String>[];
    for (final p in list.parameters) {
      final rendered = _singleParameter(p, isLambda: isLambda);
      if (p.isOptionalPositional) {
        optPositional.add(rendered);
      } else {
        parts.add(rendered);
      }
    }
    if (optPositional.isNotEmpty) {
      parts.add('[${optPositional.join(', ')}]');
    }
    return parts.join(', ');
  }

  d.TypeAnnotation? _paramType(d.FormalParameter p) => p.type;

  String _singleParameter(d.FormalParameter param, {bool isLambda = false}) {
    final isRequiredNamed = param.isRequiredNamed;
    final defaultValue = param.defaultClause?.value;

    final name = param.name?.lexeme ?? '_';
    if (name != '_') _checkIdentifierName(param, name);
    final buf = StringBuffer();
    final fnSuffix = param.functionTypedSuffix;
    String? type;
    if (fnSuffix != null) {
      final ret = param.type == null ? 'dynamic' : _typeAnnotation(param.type!);
      final ps = _parameterList(fnSuffix.formalParameters);
      final fnType = '($ps) -> $ret';
      type = fnSuffix.question != null ? '($fnType)?' : fnType;
      buf.write('$name: $type');
    } else if (param is d.FieldFormalParameter) {
      buf.write('this.$name');
      if (param.type != null) {
        type = _typeAnnotation(param.type!);
        buf.write(': $type');
      }
    } else if (param is d.SuperFormalParameter) {
      buf.write('super.$name');
      if (param.type != null) {
        type = _typeAnnotation(param.type!);
        buf.write(': $type');
      }
    } else if (param is d.RegularFormalParameter) {
      if (param.type == null && isLambda) {
        // Omit `: dynamic` on untyped lambda parameters so Quds contextual
        // type inference infers the exact element/callback parameter type.
        buf.write(name);
      } else {
        type = param.type == null ? 'dynamic' : _typeAnnotation(param.type!);
        buf.write('$name: $type');
      }
    } else {
      _fail(param, 'unsupported parameter form: ${param.runtimeType}');
    }

    if (isRequiredNamed && defaultValue == null) {
      buf.write(' required');
    } else if (defaultValue != null) {
      buf.write(' = ${_expression(defaultValue, 0)}');
    } else if (param.isOptionalNamed && type != null && type.endsWith('?')) {
      buf.write(' = null');
    }
    return buf.toString();
  }

  String _typeAnnotation(d.TypeAnnotation node) {
    if (node is d.NamedType) {
      final prefix =
          node.importPrefix != null ? '${node.importPrefix!.name.lexeme}.' : '';
      final args = node.typeArguments == null
          ? ''
          : '<${node.typeArguments!.arguments.map(_typeAnnotation).join(', ')}>';
      final q = node.question != null ? '?' : '';
      return '$prefix${node.name.lexeme}$args$q';
    }
    if (node is d.GenericFunctionType) {
      final ret = node.returnType == null
          ? 'dynamic'
          : _typeAnnotation(node.returnType!);
      final params = node.parameters.parameters.map((p) {
        if (p.type != null) {
          return _typeAnnotation(p.type!);
        }
        return 'dynamic';
      }).join(', ');
      final fn = '($params) -> $ret';
      return node.question != null ? '($fn)?' : fn;
    }
    if (node is d.RecordTypeAnnotation) {
      final parts = <String>[
        for (final f in node.positionalFields) _typeAnnotation(f.type),
        if (node.namedFields != null)
          for (final f in node.namedFields!.fields)
            '${f.name.lexeme}: ${_typeAnnotation(f.type)}',
      ];
      final q = node.question != null ? '?' : '';
      return '(${parts.join(', ')})$q';
    }
    return node.toSource();
  }

  String _statements(Iterable<d.Statement> list, int depth) {
    final rendered = <String>[];
    for (final s in list) {
      final comments = _leadingComments(s, depth);
      final text = _withHoistFrame(depth, () => _statement(s, depth));
      if (text.isNotEmpty) {
        rendered.add('$comments$text');
      } else if (comments.isNotEmpty) {
        rendered.add(comments.trimRight());
      }
    }
    return rendered.join('\n');
  }

  String _statement(d.Statement node, int depth) {
    final pad = '  ' * depth;
    if (node is d.EmptyStatement) return '';
    if (node is d.Block) {
      return _withScope(() => _statements(node.statements, depth));
    }
    if (node is d.LabeledStatement) {
      if (node.labels.length == 1) {
        final lbl = node.labels.single.name.lexeme;
        return '${pad}label $lbl\n${_statement(node.statement, depth)}';
      }
      _fail(node, 'multiple statement labels require manual migration review');
    }
    if (node is d.VariableDeclarationStatement) {
      return _variableList(node.variables, depth);
    }
    if (node is d.PatternVariableDeclarationStatement) {
      final decl = node.declaration;
      final mutable = decl.keyword.lexeme == 'var';
      final boundNames = <String>[];
      final valueExpr = _expression(decl.expression, depth);
      final lines = _patternDestructureLines(
        decl.pattern,
        valueExpr,
        depth,
        mutable: mutable,
        boundNames: boundNames,
      );
      for (final b in boundNames) {
        _declareInCurrentScope(b);
      }
      return lines.join('\n');
    }
    if (node is d.FunctionDeclarationStatement) {
      final fnName = node.functionDeclaration.name.lexeme;
      _declareInCurrentScope(fnName);
      return _functionDeclaration(node.functionDeclaration, depth);
    }
    if (node is d.ReturnStatement) {
      if (node.expression == null) return '${pad}return';
      return '${pad}return ${_expression(node.expression!, depth, allowBlock: true)}';
    }
    if (node is d.ExpressionStatement) {
      final expr = node.expression;
      if (expr is d.PatternAssignment) {
        final valueExpr = _expression(expr.expression, depth);
        final lines = _patternDestructureLines(
          expr.pattern,
          valueExpr,
          depth,
          mutable: false,
          assignment: true,
          boundNames: <String>[],
        );
        return lines.join('\n');
      }
      if (expr is d.PostfixExpression &&
          (expr.operator.lexeme == '++' || expr.operator.lexeme == '--')) {
        final op = expr.operator.lexeme == '++' ? '+=' : '-=';
        return '$pad${_expression(expr.operand, depth)} $op 1';
      }
      if (expr is d.PrefixExpression &&
          (expr.operator.lexeme == '++' || expr.operator.lexeme == '--')) {
        final op = expr.operator.lexeme == '++' ? '+=' : '-=';
        return '$pad${_expression(expr.operand, depth)} $op 1';
      }
      if (expr is d.CascadeExpression && expr.target is d.SimpleIdentifier) {
        return _emitCascadeSections(
          (expr.target as d.SimpleIdentifier).name,
          expr.cascadeSections,
          depth,
        );
      }
      return '$pad${_expression(expr, depth, allowBlock: true)}';
    }
    if (node is d.IfStatement) {
      return _ifStatement(node, depth);
    }
    if (node is d.ForStatement) {
      return _forStatement(node, depth);
    }
    if (node is d.WhileStatement) {
      final cond = _withoutHoisting(() => _expression(node.condition, depth));
      final body = _branchBody(node.body, depth + 1);
      return '${pad}while $cond:\n$body';
    }
    if (node is d.DoStatement) {
      final cond = _withoutHoisting(() => _expression(node.condition, depth));
      final body = _branchBody(node.body, depth + 1);
      return '${pad}repeat:\n$body\n${pad}while $cond';
    }
    if (node is d.SwitchStatement) {
      return _switchStatement(node, depth);
    }
    if (node is d.TryStatement) {
      return _tryStatement(node, depth);
    }
    if (node is d.BreakStatement) {
      return node.label == null
          ? '${pad}break'
          : '${pad}break ${node.label!.name}';
    }
    if (node is d.ContinueStatement) {
      return node.label == null
          ? '${pad}continue'
          : '${pad}continue ${node.label!.name}';
    }
    if (node is d.AssertStatement) {
      final msg =
          node.message == null ? '' : ', ${_expression(node.message!, depth)}';
      return '${pad}assert ${_expression(node.condition, depth)}$msg';
    }
    if (node is d.YieldStatement) {
      final kw = node.star != null ? 'yield*' : 'yield';
      return '$pad$kw ${_expression(node.expression, depth)}';
    }
    _fail(node, 'unsupported statement: ${node.runtimeType}');
  }

  String _emitCascadeSections(
    String target,
    List<d.Expression> sections,
    int depth,
  ) {
    final pad = '  ' * depth;
    final lines = <String>[];
    for (final section in sections) {
      if (section is d.MethodInvocation) {
        final ta = section.typeArguments == null
            ? ''
            : '<${section.typeArguments!.arguments.map(_typeAnnotation).join(', ')}>';
        final op = section.operator?.lexeme == '?..' ? '?.' : '.';
        lines.add(
            '$pad$target$op${section.methodName.name}$ta(${_inlineArgs(section.argumentList, depth)})');
      } else if (section is d.AssignmentExpression) {
        final lhs = section.leftHandSide;
        String targetLhs;
        if (lhs is d.PropertyAccess) {
          final op = lhs.operator.lexeme == '?..' ? '?.' : '.';
          targetLhs = '$target$op${lhs.propertyName.name}';
        } else if (lhs is d.IndexExpression) {
          final q = lhs.question != null ? '?' : '';
          targetLhs = '$target$q[${_expression(lhs.index, depth)}]';
        } else {
          _fail(section,
              'Dart cascade assignment requires manual migration review');
        }
        lines.add(
            '$pad$targetLhs ${section.operator.lexeme} ${_expression(section.rightHandSide, depth)}');
      } else {
        _fail(section, 'Dart cascade section requires manual migration review');
      }
    }
    return lines.join('\n');
  }

  String _branchBody(
    d.Statement stmt,
    int depth, {
    Iterable<String> extraScope = const [],
  }) {
    return _withScope(() {
      final text = stmt is d.Block
          ? _statements(stmt.statements, depth)
          : _withHoistFrame(depth, () => _statement(stmt, depth));
      return text.isEmpty ? '${'  ' * depth}null' : text;
    }, initial: extraScope);
  }

  String _ifHeader(d.IfStatement node, int depth, List<String> boundNames) {
    final expr = _expression(node.expression, depth);
    final cc = node.caseClause;
    if (cc == null) return expr;
    final pat = _dartPattern(cc.guardedPattern.pattern, depth, boundNames);
    final when = cc.guardedPattern.whenClause == null
        ? ''
        : ' when ${_withScope(() => _expression(cc.guardedPattern.whenClause!.expression, depth), initial: boundNames)}';
    return '$expr is $pat$when';
  }

  String _ifElementHeader(
      d.IfElement node, int depth, List<String> boundNames) {
    final expr = _expression(node.expression, depth);
    final cc = node.caseClause;
    if (cc == null) return expr;
    final pat = _dartPattern(cc.guardedPattern.pattern, depth, boundNames);
    final when = cc.guardedPattern.whenClause == null
        ? ''
        : ' when ${_withScope(() => _expression(cc.guardedPattern.whenClause!.expression, depth), initial: boundNames)}';
    return '$expr is $pat$when';
  }

  String _ifStatement(d.IfStatement node, int depth) {
    final pad = '  ' * depth;
    final boundNames = <String>[];
    final header = _ifHeader(node, depth, boundNames);
    final buf = StringBuffer(
        '${pad}if $header:\n${_branchBody(node.thenStatement, depth + 1, extraScope: boundNames)}');
    var elseStmt = node.elseStatement;
    while (elseStmt is d.IfStatement) {
      final elseBound = <String>[];
      final elseHeader = _ifHeader(elseStmt, depth, elseBound);
      buf.write(
          '\n${pad}else if $elseHeader:\n${_branchBody(elseStmt.thenStatement, depth + 1, extraScope: elseBound)}');
      elseStmt = elseStmt.elseStatement;
    }
    if (elseStmt != null) {
      buf.write('\n${pad}else:\n${_branchBody(elseStmt, depth + 1)}');
    }
    return buf.toString();
  }

  String _forStatement(d.ForStatement node, int depth) {
    final pad = '  ' * depth;
    final parts = node.forLoopParts;
    if (parts is d.ForEachPartsWithDeclaration) {
      final loopVar = parts.loopVariable.name.lexeme;
      _checkIdentifierName(parts.loopVariable, loopVar);
      final awaitPrefix = node.awaitKeyword != null ? 'await ' : '';
      final iter = _expression(parts.iterable, depth);
      final body = _branchBody(node.body, depth + 1, extraScope: [loopVar]);
      return '$pad${awaitPrefix}for $loopVar in $iter:\n$body';
    }
    if (parts is d.ForEachPartsWithIdentifier) {
      final awaitPrefix = node.awaitKeyword != null ? 'await ' : '';
      final iter = _expression(parts.iterable, depth);
      final body = _branchBody(node.body, depth + 1);
      return '$pad${awaitPrefix}for ${parts.identifier.name} in $iter:\n$body';
    }
    if (parts is d.ForEachPartsWithPattern) {
      final awaitPrefix = node.awaitKeyword != null ? 'await ' : '';
      final iter = _expression(parts.iterable, depth);
      final temp = _freshTemp('_qItem');
      final mutable = parts.keyword.lexeme == 'var';
      final bodyText = _withScope(() {
        final boundNames = <String>[];
        final destructLines = _patternDestructureLines(
          parts.pattern,
          temp,
          depth + 1,
          mutable: mutable,
          sourceIsTemp: true,
          boundNames: boundNames,
        );
        for (final b in boundNames) {
          _declareInCurrentScope(b);
        }
        final inner = _branchBody(node.body, depth + 1);
        return [...destructLines, inner].join('\n');
      }, initial: [temp]);
      return '$pad${awaitPrefix}for $temp in $iter:\n$bodyText';
    }
    if (parts is d.ForPartsWithDeclarations) {
      // Single-variable C-style `for (var i = init; cond; updater)`.
      if (parts.variables.variables.length == 1 &&
          parts.updaters.length <= 1 &&
          parts.variables.variables.single.initializer != null) {
        final v = parts.variables.variables.single;
        final varName = v.name.lexeme;
        _checkIdentifierName(v, varName);
        final initExpr = _expression(v.initializer!, depth);
        final body = _branchBody(node.body, depth + 1, extraScope: [varName]);

        // Recognize canonical `for (var i = a; i < b; i++)` -> `for i in a..<b:`
        // ONLY when the body does not mutate `i` (so behavior is 100% identical).
        if (parts.updaters.length == 1 &&
            parts.condition is d.BinaryExpression &&
            !_mutatesVariable(node.body, varName)) {
          final cond = parts.condition as d.BinaryExpression;
          final upd = parts.updaters.single;
          final isInc = (upd is d.PostfixExpression &&
                  upd.operator.lexeme == '++' &&
                  upd.operand.toSource() == varName) ||
              (upd is d.PrefixExpression &&
                  upd.operator.lexeme == '++' &&
                  upd.operand.toSource() == varName);
          if (isInc &&
              cond.leftOperand.toSource() == varName &&
              (cond.operator.lexeme == '<' || cond.operator.lexeme == '<=')) {
            final rangeOp = cond.operator.lexeme == '<' ? '..<' : '..';
            return '${pad}for $varName in $initExpr$rangeOp${_expression(cond.rightOperand, depth)}:\n$body';
          }
        }

        // Otherwise emit Quds native CForStatement:
        //   `for var i = init while cond step updater:`
        // which compiles directly to Dart's `for (var i = init; cond; updater)`
        // preserving exact `continue`, `break`, and loop-variable mutation semantics!
        final typeText = parts.variables.type == null
            ? ''
            : ': ${_typeAnnotation(parts.variables.type!)}';
        final condText = parts.condition == null
            ? 'true'
            : _expression(parts.condition!, depth);
        final stepClause = parts.updaters.isEmpty
            ? ''
            : ' step ${_updaterExpr(parts.updaters.single, depth)}';
        return '${pad}for var $varName$typeText = $initExpr while $condText$stepClause:\n$body';
      }

      // Multi-variable or multi-updater C-style for loop: only desugar to
      // `while` if there is no unnested `continue` (which would skip updaters).
      if (parts.updaters.isNotEmpty && _hasUnnestedContinue(node.body)) {
        _fail(node,
            'multi-variable for-loop with continue requires manual migration review');
      }
      final declNames = [
        for (final v in parts.variables.variables) v.name.lexeme,
      ];
      final lines = <String>[_variableList(parts.variables, depth)];
      final condText = parts.condition == null
          ? 'true'
          : _expression(parts.condition!, depth);
      final body = _branchBody(node.body, depth + 1, extraScope: declNames);
      final updaterLines = [
        for (final u in parts.updaters)
          '${'  ' * (depth + 1)}${_updaterExpr(u, depth + 1)}',
      ];
      lines.add('${pad}while $condText:');
      lines.add(body);
      lines.addAll(updaterLines);
      return lines.join('\n');
    }
    if (parts is d.ForPartsWithExpression) {
      if (parts.updaters.isNotEmpty && _hasUnnestedContinue(node.body)) {
        _fail(node,
            'expression-init for-loop with continue requires manual migration review');
      }
      final lines = <String>[];
      if (parts.initialization != null) {
        lines.add('$pad${_expression(parts.initialization!, depth)}');
      }
      final condText = parts.condition == null
          ? 'true'
          : _expression(parts.condition!, depth);
      final body = _branchBody(node.body, depth + 1);
      final updaterLines = [
        for (final u in parts.updaters)
          '${'  ' * (depth + 1)}${_updaterExpr(u, depth + 1)}',
      ];
      lines.add('${pad}while $condText:');
      lines.add(body);
      lines.addAll(updaterLines);
      return lines.join('\n');
    }
    _fail(node, 'unsupported for-loop form: ${parts.runtimeType}');
  }

  String _updaterExpr(d.Expression u, int depth) {
    if (u is d.PostfixExpression &&
        (u.operator.lexeme == '++' || u.operator.lexeme == '--')) {
      return '${_expression(u.operand, depth)} ${u.operator.lexeme == '++' ? '+=' : '-='} 1';
    }
    if (u is d.PrefixExpression &&
        (u.operator.lexeme == '++' || u.operator.lexeme == '--')) {
      return '${_expression(u.operand, depth)} ${u.operator.lexeme == '++' ? '+=' : '-='} 1';
    }
    return _expression(u, depth);
  }

  String _switchStatement(d.SwitchStatement node, int depth) {
    final pad = '  ' * depth;
    final innerPad = '  ' * (depth + 1);
    final buf =
        StringBuffer('${pad}match ${_expression(node.expression, depth)}:\n');
    final pendingPatterns = <String>[];

    for (var i = 0; i < node.members.length; i++) {
      final member = node.members[i];
      if (member.labels.isNotEmpty) {
        _fail(member, 'labeled switch case requires manual migration review');
      }
      if (member is d.SwitchDefault) {
        if (pendingPatterns.isNotEmpty) {
          // A case falling straight into `default:` behaves identically to
          // `default:` (`_`) as long as no guard is attached.
          pendingPatterns.clear();
        }
        final stmts = _stripTrailingSwitchBreak(member.statements);
        buf.writeln('${innerPad}_:');
        final rendered = _withScope(() => _statements(stmts, depth + 2));
        buf.writeln(rendered.isEmpty ? '${'  ' * (depth + 2)}null' : rendered);
        continue;
      }

      String pat;
      String? guard;
      final boundNames = <String>[];
      if (member is d.SwitchCase) {
        pat = _expression(member.expression, depth + 1);
      } else if (member is d.SwitchPatternCase) {
        pat =
            _dartPattern(member.guardedPattern.pattern, depth + 1, boundNames);
        if (member.guardedPattern.whenClause != null) {
          guard = _expression(
              member.guardedPattern.whenClause!.expression, depth + 1);
        }
      } else {
        _fail(member, 'unsupported switch member: ${member.runtimeType}');
      }

      // Dart allows grouped empty cases: `case 1: case 2: body(); break;`.
      if (member.statements.isEmpty && i + 1 < node.members.length) {
        if (guard != null || boundNames.isNotEmpty) {
          _fail(member,
              'grouped guarded/binding switch case requires manual migration review');
        }
        pendingPatterns.add(pat);
        continue;
      }

      final combinedPattern = pendingPatterns.isEmpty
          ? pat
          : '${pendingPatterns.join(' | ')} | $pat';
      pendingPatterns.clear();
      final guardClause = guard == null ? '' : ' when $guard';
      final stmts = _stripTrailingSwitchBreak(member.statements);
      buf.writeln('$innerPad$combinedPattern$guardClause:');
      final rendered = _withScope(
        () => _statements(stmts, depth + 2),
        initial: boundNames,
      );
      buf.writeln(rendered.isEmpty ? '${'  ' * (depth + 2)}null' : rendered);
    }
    return buf.toString().trimRight();
  }

  List<d.Statement> _stripTrailingSwitchBreak(List<d.Statement> statements) {
    if (statements.isEmpty) return const [];
    final out = [...statements];
    if (out.last is d.BreakStatement &&
        (out.last as d.BreakStatement).label == null) {
      out.removeLast();
    }
    return out;
  }

  String _dartPattern(
    d.DartPattern pattern,
    int depth,
    List<String> boundNames,
  ) {
    if (pattern is d.ConstantPattern) {
      return _expression(pattern.expression, depth);
    }
    if (pattern is d.WildcardPattern) {
      if (pattern.type != null) {
        return '${_typeAnnotation(pattern.type!)} _';
      }
      return '_';
    }
    if (pattern is d.LogicalOrPattern) {
      final l = _dartPattern(pattern.leftOperand, depth, boundNames);
      final r = _dartPattern(pattern.rightOperand, depth, boundNames);
      return '$l | $r';
    }
    if (pattern is d.LogicalAndPattern) {
      final l = _dartPattern(pattern.leftOperand, depth, boundNames);
      final r = _dartPattern(pattern.rightOperand, depth, boundNames);
      return '$l and $r';
    }
    if (pattern is d.ParenthesizedPattern) {
      return '(${_dartPattern(pattern.pattern, depth, boundNames)})';
    }
    if (pattern is d.RelationalPattern) {
      return '${pattern.operator.lexeme} ${_expression(pattern.operand, depth)}';
    }
    if (pattern is d.DeclaredVariablePattern) {
      final name = pattern.name.lexeme;
      _checkIdentifierName(pattern, name);
      final shadowPrefix = _isDeclaredInOuterScope(name) ? 'shadow ' : '';
      boundNames.add(name);
      if (pattern.type != null) {
        return '${_typeAnnotation(pattern.type!)} $shadowPrefix$name';
      }
      return '$shadowPrefix$name';
    }
    if (pattern is d.AssignedVariablePattern) {
      final name = pattern.name.lexeme;
      _checkIdentifierName(pattern, name);
      return name;
    }
    if (pattern is d.CastPattern) {
      final inner = _dartPattern(pattern.pattern, depth, boundNames);
      return '$inner as ${_typeAnnotation(pattern.type)}';
    }
    if (pattern is d.NullCheckPattern) {
      final inner = _dartPattern(pattern.pattern, depth, boundNames);
      return '$inner?';
    }
    if (pattern is d.NullAssertPattern) {
      final inner = _dartPattern(pattern.pattern, depth, boundNames);
      return '$inner!';
    }
    if (pattern is d.ObjectPattern) {
      final type = _typeAnnotation(pattern.type);
      final fields = pattern.fields.map((f) {
        final inner = _dartPattern(f.pattern, depth, boundNames);
        final explicit = f.name?.name?.lexeme;
        if (explicit != null) {
          return '$explicit: $inner';
        }
        // Shorthand `Point(:var x)` -> `Point(x: x)` (or `Point(x: shadow x)`).
        final inferred = _inferredPatternFieldName(f.pattern);
        if (inferred != null) {
          return '$inferred: $inner';
        }
        _fail(f, 'object pattern field without name requires manual review');
      }).join(', ');
      return '$type($fields)';
    }
    if (pattern is d.ListPattern) {
      final elems = pattern.elements.map((el) {
        if (el is d.RestPatternElement) {
          if (el.pattern == null) return '...';
          return '...${_dartPattern(el.pattern!, depth, boundNames)}';
        }
        if (el is d.DartPattern) {
          return _dartPattern(el, depth, boundNames);
        }
        _fail(el, 'unsupported list pattern element: ${el.runtimeType}');
      }).join(', ');
      return '[$elems]';
    }
    if (pattern is d.MapPattern) {
      final entries = pattern.elements.map((el) {
        if (el is d.MapPatternEntry) {
          final k = _expression(el.key, depth);
          final v = _dartPattern(el.value, depth, boundNames);
          return '$k: $v';
        }
        _fail(el, 'unsupported map pattern element: ${el.runtimeType}');
      }).join(', ');
      return 'map($entries)';
    }
    if (pattern is d.RecordPattern) {
      var hasNamed = false;
      final fields = pattern.fields.map((f) {
        final inner = _dartPattern(f.pattern, depth, boundNames);
        if (f.name != null) {
          hasNamed = true;
          final fieldName =
              f.name!.name?.lexeme ?? _inferredPatternFieldName(f.pattern);
          if (fieldName == null) {
            _fail(
                f, 'record pattern field without name requires manual review');
          }
          return '$fieldName: $inner';
        }
        return inner;
      }).toList();
      if (fields.length == 1 && !hasNamed) {
        return '(${fields.single},)';
      }
      return '(${fields.join(', ')})';
    }
    _fail(pattern,
        'Dart 3 pattern ${pattern.runtimeType} requires manual migration review');
  }

  bool _isSimpleIrrefutableDestructure(d.DartPattern pattern) {
    if (pattern is d.WildcardPattern) return pattern.type == null;
    if (pattern is d.DeclaredVariablePattern) return pattern.type == null;
    if (pattern is d.AssignedVariablePattern) return true;
    if (pattern is d.ParenthesizedPattern) {
      return _isSimpleIrrefutableDestructure(pattern.pattern);
    }
    if (pattern is d.RecordPattern) {
      return pattern.fields
          .every((f) => _isSimpleIrrefutableDestructure(f.pattern));
    }
    if (pattern is d.ListPattern) {
      return pattern.elements.every((el) {
        if (el is d.RestPatternElement) {
          return el.pattern == null ||
              _isSimpleIrrefutableDestructure(el.pattern!);
        }
        return el is d.DartPattern && _isSimpleIrrefutableDestructure(el);
      });
    }
    return false;
  }

  List<String> _patternDestructureLines(
    d.DartPattern pattern,
    String valueExpr,
    int depth, {
    required bool mutable,
    bool assignment = false,
    bool sourceIsTemp = false,
    required List<String> boundNames,
  }) {
    final pad = '  ' * depth;
    if ((pattern is d.RecordPattern || pattern is d.ListPattern) &&
        _isSimpleIrrefutableDestructure(pattern)) {
      final rendered = _dartPattern(pattern, depth, boundNames);
      final varPrefix = (!assignment && mutable) ? 'var ' : '';
      return ['$pad$varPrefix$rendered = $valueExpr'];
    }
    final lines = <String>[];
    _emitStructuralDestructure(
      pattern,
      valueExpr,
      depth,
      mutable: mutable,
      assignment: assignment,
      sourceIsTemp: sourceIsTemp,
      boundNames: boundNames,
      out: lines,
    );
    return lines;
  }

  void _emitStructuralDestructure(
    d.DartPattern pattern,
    String sourceExpr,
    int depth, {
    required bool mutable,
    required bool assignment,
    required bool sourceIsTemp,
    required List<String> boundNames,
    required List<String> out,
  }) {
    final pad = '  ' * depth;
    if (pattern is d.ParenthesizedPattern) {
      _emitStructuralDestructure(
        pattern.pattern,
        sourceExpr,
        depth,
        mutable: mutable,
        assignment: assignment,
        sourceIsTemp: sourceIsTemp,
        boundNames: boundNames,
        out: out,
      );
      return;
    }
    if (pattern is d.WildcardPattern) {
      if (!sourceIsTemp) {
        final tmp = _freshTemp();
        out.add('$pad$tmp = $sourceExpr');
      }
      return;
    }
    if (pattern is d.DeclaredVariablePattern) {
      final name = pattern.name.lexeme;
      _checkIdentifierName(pattern, name);
      final shadowPrefix = _isDeclaredInOuterScope(name) ? 'shadow ' : '';
      final varPrefix = mutable ? 'var ' : '';
      final typeSuffix =
          pattern.type == null ? '' : ': ${_typeAnnotation(pattern.type!)}';
      boundNames.add(name);
      out.add('$pad$shadowPrefix$varPrefix$name$typeSuffix = $sourceExpr');
      return;
    }
    if (pattern is d.AssignedVariablePattern) {
      final name = pattern.name.lexeme;
      _checkIdentifierName(pattern, name);
      out.add('$pad$name = $sourceExpr');
      return;
    }
    if (pattern is d.CastPattern) {
      _emitStructuralDestructure(
        pattern.pattern,
        '($sourceExpr as ${_typeAnnotation(pattern.type)})',
        depth,
        mutable: mutable,
        assignment: assignment,
        sourceIsTemp: false,
        boundNames: boundNames,
        out: out,
      );
      return;
    }
    if (pattern is d.NullAssertPattern) {
      _emitStructuralDestructure(
        pattern.pattern,
        '($sourceExpr!)',
        depth,
        mutable: mutable,
        assignment: assignment,
        sourceIsTemp: false,
        boundNames: boundNames,
        out: out,
      );
      return;
    }
    if ((pattern is d.RecordPattern || pattern is d.ListPattern) &&
        _isSimpleIrrefutableDestructure(pattern)) {
      final rendered = _dartPattern(pattern, depth, boundNames);
      final varPrefix = (!assignment && mutable) ? 'var ' : '';
      out.add('$pad$varPrefix$rendered = $sourceExpr');
      return;
    }
    String ensureTemp() {
      if (sourceIsTemp) return sourceExpr;
      final tmp = _freshTemp();
      out.add('$pad$tmp = $sourceExpr');
      return tmp;
    }

    if (pattern is d.ObjectPattern) {
      final tmp = ensureTemp();
      for (final f in pattern.fields) {
        final fieldName =
            f.name?.name?.lexeme ?? _inferredPatternFieldName(f.pattern);
        if (fieldName == null) {
          _fail(f, 'object pattern field without name requires manual review');
        }
        _emitStructuralDestructure(
          f.pattern,
          '$tmp.$fieldName',
          depth,
          mutable: mutable,
          assignment: assignment,
          sourceIsTemp: false,
          boundNames: boundNames,
          out: out,
        );
      }
      return;
    }
    if (pattern is d.RecordPattern) {
      final tmp = ensureTemp();
      var pos = 0;
      for (final f in pattern.fields) {
        final String access;
        if (f.name != null) {
          final fieldName =
              f.name!.name?.lexeme ?? _inferredPatternFieldName(f.pattern);
          if (fieldName == null) {
            _fail(
                f, 'record pattern field without name requires manual review');
          }
          access = '$tmp.$fieldName';
        } else {
          access = '$tmp.\$${++pos}';
        }
        _emitStructuralDestructure(
          f.pattern,
          access,
          depth,
          mutable: mutable,
          assignment: assignment,
          sourceIsTemp: false,
          boundNames: boundNames,
          out: out,
        );
      }
      return;
    }
    if (pattern is d.ListPattern) {
      final tmp = ensureTemp();
      var restAt = -1;
      for (var i = 0; i < pattern.elements.length; i++) {
        if (pattern.elements[i] is d.RestPatternElement) restAt = i;
      }
      final prefix = restAt < 0 ? pattern.elements.length : restAt;
      final suffix = restAt < 0 ? 0 : pattern.elements.length - restAt - 1;
      for (var i = 0; i < prefix; i++) {
        final el = pattern.elements[i];
        if (el is! d.DartPattern) {
          _fail(el, 'unsupported list pattern element: ${el.runtimeType}');
        }
        _emitStructuralDestructure(
          el,
          '$tmp[$i]',
          depth,
          mutable: mutable,
          assignment: assignment,
          sourceIsTemp: false,
          boundNames: boundNames,
          out: out,
        );
      }
      if (restAt >= 0) {
        final rest = pattern.elements[restAt] as d.RestPatternElement;
        if (rest.pattern != null) {
          final end = suffix == 0 ? '$tmp.length' : '$tmp.length - $suffix';
          _emitStructuralDestructure(
            rest.pattern!,
            '$tmp.sublist($prefix, $end)',
            depth,
            mutable: mutable,
            assignment: assignment,
            sourceIsTemp: false,
            boundNames: boundNames,
            out: out,
          );
        }
        for (var j = 0; j < suffix; j++) {
          final el = pattern.elements[restAt + 1 + j];
          if (el is! d.DartPattern) {
            _fail(el, 'unsupported list pattern element: ${el.runtimeType}');
          }
          _emitStructuralDestructure(
            el,
            '$tmp[($tmp.length - $suffix) + $j]',
            depth,
            mutable: mutable,
            assignment: assignment,
            sourceIsTemp: false,
            boundNames: boundNames,
            out: out,
          );
        }
      }
      return;
    }
    if (pattern is d.MapPattern) {
      final tmp = ensureTemp();
      for (final el in pattern.elements) {
        if (el is! d.MapPatternEntry) {
          _fail(el, 'unsupported map pattern element: ${el.runtimeType}');
        }
        final keyExpr = _expression(el.key, depth);
        _emitStructuralDestructure(
          el.value,
          '$tmp[$keyExpr]',
          depth,
          mutable: mutable,
          assignment: assignment,
          sourceIsTemp: false,
          boundNames: boundNames,
          out: out,
        );
      }
      return;
    }
    _fail(pattern,
        'Dart 3 destructuring pattern ${pattern.runtimeType} requires manual review');
  }

  String? _inferredPatternFieldName(d.DartPattern pattern) {
    if (pattern is d.DeclaredVariablePattern) return pattern.name.lexeme;
    if (pattern is d.AssignedVariablePattern) return pattern.name.lexeme;
    if (pattern is d.CastPattern) {
      return _inferredPatternFieldName(pattern.pattern);
    }
    if (pattern is d.NullCheckPattern) {
      return _inferredPatternFieldName(pattern.pattern);
    }
    if (pattern is d.NullAssertPattern) {
      return _inferredPatternFieldName(pattern.pattern);
    }
    if (pattern is d.ParenthesizedPattern) {
      return _inferredPatternFieldName(pattern.pattern);
    }
    return null;
  }

  String _tryStatement(d.TryStatement node, int depth) {
    final pad = '  ' * depth;
    final buf =
        StringBuffer('${pad}try:\n${_branchBody(node.body, depth + 1)}');
    for (final c in node.catchClauses) {
      final onType = c.exceptionType == null
          ? ''
          : ' ${_typeAnnotation(c.exceptionType!)}';
      final exc = c.exceptionParameter?.name.lexeme;
      final stack = c.stackTraceParameter?.name.lexeme;
      if (exc != null) _checkIdentifierName(c.exceptionParameter!, exc);
      if (stack != null) _checkIdentifierName(c.stackTraceParameter!, stack);
      final header = StringBuffer('${pad}catch');
      if (exc != null && onType.isNotEmpty) {
        header.write(' $exc:$onType');
      } else if (exc != null) {
        header.write(' $exc');
      } else if (onType.isNotEmpty) {
        header.write(' _:$onType');
      }
      if (stack != null) header.write(', $stack');
      final catchVars = [
        if (exc != null) exc,
        if (stack != null) stack,
      ];
      buf.write(
          '\n$header:\n${_branchBody(c.body, depth + 1, extraScope: catchVars)}');
    }
    if (node.finallyBlock != null) {
      buf.write(
          '\n${pad}finally:\n${_branchBody(node.finallyBlock!, depth + 1)}');
    }
    return buf.toString();
  }

  String _variableList(d.VariableDeclarationList node, int depth) {
    final pad = '  ' * depth;
    final isFinal = node.isFinal;
    final isConst = node.isConst;
    final isLate = node.isLate;
    final typeText = node.type == null ? null : _typeAnnotation(node.type!);
    final lines = <String>[];
    for (final v in node.variables) {
      final name = v.name.lexeme;
      _checkIdentifierName(v, name);
      final isShadowing = _scopes.length > 1 && _isDeclaredInOuterScope(name);
      final prefix = StringBuffer();
      if (isLate) prefix.write('late ');
      if (isConst) {
        prefix.write('const ');
      } else if (isShadowing) {
        prefix.write(isFinal ? 'shadow ' : 'shadow var ');
      } else if (!isFinal) {
        prefix.write('var ');
      }
      final typeSuffix = typeText == null ? '' : ': $typeText';
      final init = v.initializer;
      if (init is d.CascadeExpression) {
        final targetRhs = _expression(init.target, depth, allowBlock: true);
        lines.add('$pad$prefix$name$typeSuffix = $targetRhs');
        lines.add(_emitCascadeSections(name, init.cascadeSections, depth));
      } else if (init != null) {
        final rhs = _expression(init, depth, allowBlock: true);
        lines.add('$pad$prefix$name$typeSuffix = $rhs');
      } else if (typeText != null && typeText.endsWith('?') && !isLate) {
        lines.add('$pad$prefix$name$typeSuffix = null');
      } else {
        lines.add('$pad$prefix$name$typeSuffix');
      }
      _declareInCurrentScope(name);
    }
    return lines.join('\n');
  }

  bool _shouldFormatAsBlockCall(d.Expression node) {
    d.ArgumentList? args;
    if (node is d.InstanceCreationExpression) {
      args = node.argumentList;
    } else if (node is d.MethodInvocation && !node.isCascaded) {
      args = node.argumentList;
    }
    if (args == null) return false;
    final named = args.arguments.whereType<d.NamedArgument>().toList();
    if (named.isEmpty) return false;
    if (args.arguments.length - named.length > 1) return false;
    if (named.any((a) {
      final v = a.argumentExpression;
      return (v is d.FunctionExpression && _needsBlockLambda(v)) ||
          v is d.SwitchExpression ||
          _containsBlockConstruct(v);
    })) {
      return true;
    }
    if (named.length >= 2) {
      return args.toSource().length >= 52 ||
          named.any(
              (a) => a.name.lexeme == 'child' || a.name.lexeme == 'children');
    }
    final single = named.single;
    final key = single.name.lexeme;
    return (key == 'child' ||
            key == 'children' ||
            key == 'body' ||
            key == 'builder' ||
            key == 'itemBuilder' ||
            key == 'onTap' ||
            key == 'onPressed') &&
        args.toSource().length >= 52;
  }

  String _blockCall(
    String calleeHead,
    d.ArgumentList args,
    int depth,
  ) {
    final positional = <d.Expression>[];
    final named = <d.NamedArgument>[];
    for (final a in args.arguments) {
      if (a is d.NamedArgument) {
        named.add(a);
      } else {
        positional.add(a.argumentExpression);
      }
    }
    final head = positional.isEmpty
        ? '$calleeHead:'
        : '$calleeHead(${positional.map((e) => _expression(e, depth)).join(', ')}):';
    final buf = StringBuffer('$head\n');
    final childPad = '  ' * (depth + 1);
    for (final n in named) {
      final key = n.name.lexeme;
      final val = n.argumentExpression;
      if (val is d.ListLiteral &&
          val.elements.isNotEmpty &&
          (key == 'children' ||
              key == 'actions' ||
              key == 'destinations' ||
              val.toSource().length >= 60)) {
        buf.writeln('$childPad$key:');
        for (final el in val.elements) {
          buf.writeln(_collectionRow(el, depth + 2));
        }
      } else {
        buf.writeln(
            '$childPad$key: ${_expression(val, depth + 1, allowBlock: true)}');
      }
    }
    return buf.toString().trimRight();
  }

  String _collectionRow(d.CollectionElement element, int depth) {
    final pad = '  ' * depth;
    if (element is d.Expression) {
      return '$pad${_expression(element, depth, allowBlock: true)}';
    }
    if (element is d.SpreadElement) {
      final op = element.isNullAware ? '...?' : '...';
      return '$pad$op${_expression(element.expression, depth)}';
    }
    if (element is d.IfElement) {
      final boundNames = <String>[];
      final cond = _ifElementHeader(element, depth, boundNames);
      final thenRow = _withScope(
        () => boundNames.isEmpty
            ? _collectionRow(element.thenElement, depth + 1)
            : _withoutHoisting(
                () => _collectionRow(element.thenElement, depth + 1)),
        initial: boundNames,
      );
      final buf = StringBuffer('${pad}if $cond:\n$thenRow');
      if (element.elseElement != null) {
        buf.write(
            '\n${pad}else:\n${_collectionRow(element.elseElement!, depth + 1)}');
      }
      return buf.toString();
    }
    if (element is d.ForElement) {
      final parts = element.forLoopParts;
      if (parts is d.ForEachPartsWithDeclaration) {
        final body =
            _withoutHoisting(() => _collectionRow(element.body, depth + 1));
        return '${pad}for ${parts.loopVariable.name.lexeme} in ${_expression(parts.iterable, depth)}:\n$body';
      }
      if (parts is d.ForEachPartsWithIdentifier) {
        final body =
            _withoutHoisting(() => _collectionRow(element.body, depth + 1));
        return '${pad}for ${parts.identifier.name} in ${_expression(parts.iterable, depth)}:\n$body';
      }
    }
    _fail(element, 'unsupported collection element: ${element.runtimeType}');
  }

  String _inlineArgs(d.ArgumentList args, int depth) => args.arguments.map((a) {
        if (a is d.NamedArgument) {
          return '${a.name.lexeme}: ${_expression(a.argumentExpression, depth)}';
        }
        return _expression(a.argumentExpression, depth);
      }).join(', ');

  String _escapeQudsString(String value) {
    final encoded = jsonEncode(value);
    return encoded
        .substring(1, encoded.length - 1)
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}');
  }

  String _expression(d.Expression node, int depth, {bool allowBlock = false}) {
    if (node is d.SimpleStringLiteral) {
      if (node.isRaw) {
        // Raw Quds strings r"..." do not unescape `\"` or newlines; fall back
        // to an escaped regular string when the raw string contains quotes/newlines.
        if (!node.value.contains('"') &&
            !node.value.contains('\n') &&
            !node.value.contains('\r')) {
          return 'r"${node.value}"';
        }
        return '"${_escapeQudsString(node.value)}"';
      }
      return '"${_escapeQudsString(node.value)}"';
    }
    if (node is d.StringInterpolation) {
      final parts = node.elements.map((e) {
        if (e is d.InterpolationString) return _escapeQudsString(e.value);
        if (e is d.InterpolationExpression) {
          return '{${_expression(e.expression, depth)}}';
        }
        return '';
      }).join();
      return '"$parts"';
    }
    if (node is d.AdjacentStrings) {
      return node.strings.map((s) => _expression(s, depth)).join(' + ');
    }
    if (node is d.IntegerLiteral ||
        node is d.DoubleLiteral ||
        node is d.BooleanLiteral ||
        node is d.NullLiteral ||
        node is d.SimpleIdentifier ||
        node is d.ThisExpression ||
        node is d.SuperExpression) {
      return node.toSource();
    }
    if (node is d.ParenthesizedExpression) {
      return '(${_expression(node.expression, depth)})';
    }
    if (node is d.PrefixedIdentifier) {
      return '${node.prefix.name}.${node.identifier.name}';
    }
    if (node is d.PropertyAccess && !node.isCascaded) {
      return '${_expression(node.target!, depth)}${node.operator.lexeme}${node.propertyName.name}';
    }
    if (node is d.IndexExpression && !node.isCascaded) {
      final q = node.question != null ? '?' : '';
      return '${_expression(node.target!, depth)}$q[${_expression(node.index, depth)}]';
    }
    if (node is d.InstanceCreationExpression) {
      final callee = node.constructorName.toSource();
      if (allowBlock && _shouldFormatAsBlockCall(node)) {
        return _blockCall(callee, node.argumentList, depth);
      }
      return '$callee(${_inlineArgs(node.argumentList, depth)})';
    }
    if (node is d.MethodInvocation && !node.isCascaded) {
      final target = node.target == null
          ? ''
          : '${_expression(node.target!, depth)}${node.operator?.lexeme ?? '.'}';
      final ta = node.typeArguments == null
          ? ''
          : '<${node.typeArguments!.arguments.map(_typeAnnotation).join(', ')}>';
      final callee = '$target${node.methodName.name}$ta';
      if (allowBlock && _shouldFormatAsBlockCall(node)) {
        return _blockCall(callee, node.argumentList, depth);
      }
      return '$callee(${_inlineArgs(node.argumentList, depth)})';
    }
    if (node is d.FunctionExpressionInvocation) {
      final ta = node.typeArguments == null
          ? ''
          : '<${node.typeArguments!.arguments.map(_typeAnnotation).join(', ')}>';
      return '${_expression(node.function, depth)}$ta(${_inlineArgs(node.argumentList, depth)})';
    }
    if (node is d.AssignmentExpression) {
      final op = node.operator.lexeme;
      const qudsCompoundOps = {'=', '+=', '-=', '*=', '/=', '??='};
      if (qudsCompoundOps.contains(op)) {
        return '${_expression(node.leftHandSide, depth)} $op ${_expression(node.rightHandSide, depth, allowBlock: allowBlock)}';
      }
      // Desugar Dart-only compound ops (`~/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`, `>>>=`)
      // ONLY when LHS is a pure identifier (preserving left-to-right, exactly-once evaluation).
      if (node.leftHandSide is d.SimpleIdentifier && op.endsWith('=')) {
        final binOp = op.substring(0, op.length - 1);
        final lhs = (node.leftHandSide as d.SimpleIdentifier).name;
        final rhs = _expression(node.rightHandSide, depth);
        final rhsWrapped =
            node.rightHandSide is d.BinaryExpression ? '($rhs)' : rhs;
        return '$lhs = $lhs $binOp $rhsWrapped';
      }
      _fail(node,
          'compound assignment $op on complex target requires manual review');
    }
    if (node is d.BinaryExpression) {
      final dartOp = node.operator.lexeme;
      final op = switch (dartOp) {
        '&&' => 'and',
        '||' => 'or',
        final other => other,
      };
      var left = _expression(node.leftOperand, depth);
      var right = _expression(node.rightOperand, depth);
      // In Dart `??` binds tighter than `&&`/`||`, whereas in Quds `??` has
      // lower precedence than `and`/`or`. Always parenthesize across that boundary.
      if ((dartOp == '&&' || dartOp == '||') &&
          node.leftOperand is d.BinaryExpression &&
          (node.leftOperand as d.BinaryExpression).operator.lexeme == '??') {
        left = '($left)';
      }
      if ((dartOp == '&&' || dartOp == '||') &&
          node.rightOperand is d.BinaryExpression &&
          (node.rightOperand as d.BinaryExpression).operator.lexeme == '??') {
        right = '($right)';
      }
      if (dartOp == '??') {
        if (node.leftOperand is d.BinaryExpression) {
          final lo = (node.leftOperand as d.BinaryExpression).operator.lexeme;
          if (lo == '&&' || lo == '||') left = '($left)';
        }
        if (node.rightOperand is d.BinaryExpression) {
          final ro = (node.rightOperand as d.BinaryExpression).operator.lexeme;
          if (ro == '&&' || ro == '||') right = '($right)';
        }
      }
      return '$left $op $right';
    }
    if (node is d.PrefixExpression) {
      final op = node.operator.lexeme;
      if (op == '++' || op == '--') {
        _fail(node, 'prefix $op inside expression requires manual migration');
      }
      if (op == '!') return 'not ${_expression(node.operand, depth)}';
      return '$op${_expression(node.operand, depth)}';
    }
    if (node is d.PostfixExpression) {
      final op = node.operator.lexeme;
      if (op == '!') return '${_expression(node.operand, depth)}!';
      _fail(node, 'postfix $op inside expression requires manual migration');
    }
    if (node is d.IsExpression) {
      final op = node.notOperator != null ? 'is!' : 'is';
      return '${_expression(node.expression, depth)} $op ${_typeAnnotation(node.type)}';
    }
    if (node is d.AsExpression) {
      return '${_expression(node.expression, depth)} as ${_typeAnnotation(node.type)}';
    }
    if (node is d.ConditionalExpression) {
      final condText = _expression(node.condition, depth);
      final thenText = _expression(node.thenExpression, depth);
      final elseText = _expression(node.elseExpression, depth);
      return '(if $condText: $thenText else: $elseText)';
    }
    if (node is d.AwaitExpression) {
      return 'await ${_expression(node.expression, depth)}';
    }
    if (node is d.ThrowExpression) {
      return 'throw ${_expression(node.expression, depth)}';
    }
    if (node is d.RethrowExpression) {
      return 'rethrow';
    }
    if (node is d.ListLiteral) {
      final typeArg = node.typeArguments?.arguments.length == 1
          ? _typeAnnotation(node.typeArguments!.arguments.single)
          : null;
      if (node.elements.isEmpty) {
        if (typeArg != null) return 'List<$typeArg>.empty(growable: true)';
        return '[]';
      }
      final els = node.elements.map((e) => _inlineElement(e, depth)).join(', ');
      if (typeArg != null) return 'List<$typeArg>.of([$els])';
      return '[$els]';
    }
    if (node is d.SetOrMapLiteral) {
      return _setOrMapLiteral(node, depth, allowBlock: allowBlock);
    }
    if (node is d.RecordLiteral) {
      final parts = node.fields.map((f) {
        if (f is d.RecordLiteralNamedField) {
          return '${f.name.lexeme}: ${_expression(f.fieldExpression, depth)}';
        }
        return _expression(f.fieldExpression, depth);
      }).join(', ');
      return '($parts)';
    }
    if (node is d.FunctionExpression) {
      final params = node.parameters == null
          ? ''
          : _parameterList(node.parameters!, isLambda: true);
      final asyncMod = _asyncModifier(node.body);
      final body = node.body;
      return _withScope(() {
        if (body is d.ExpressionFunctionBody) {
          if (allowBlock) {
            final frame = (depth: depth + 1, lines: <String>[]);
            _hoistFrames.add(frame);
            late final String rendered;
            try {
              rendered = _expression(body.expression, depth + 1,
                  allowBlock: _shouldFormatAsBlockCall(body.expression));
            } finally {
              _hoistFrames.removeLast();
            }
            if (frame.lines.isNotEmpty) {
              final bodyPad = '  ' * (depth + 1);
              return '($params)$asyncMod -> :\n${frame.lines.join('\n')}\n${bodyPad}return $rendered';
            }
            if (_shouldFormatAsBlockCall(body.expression)) {
              final bodyPad = '  ' * (depth + 1);
              return '($params)$asyncMod -> :\n${bodyPad}return $rendered';
            }
            return '($params)$asyncMod -> $rendered';
          }
          if (!_canInlineLambdaExpr(body.expression)) {
            final frame = _hoistFrames.isEmpty ? null : _hoistFrames.last;
            if (frame != null) {
              final name = _freshTemp('_qfn');
              final pad = '  ' * frame.depth;
              final inner = _withHoistFrame(
                frame.depth + 1,
                () =>
                    '${'  ' * (frame.depth + 1)}return ${_expression(body.expression, frame.depth + 1, allowBlock: true)}',
              );
              frame.lines.add('$pad$name = ($params)$asyncMod -> :\n$inner');
              return name;
            }
          }
          return '($params)$asyncMod -> ${_withoutHoisting(() => _expression(body.expression, depth))}';
        }
        if (body is d.BlockFunctionBody) {
          if (!allowBlock) {
            if (body.block.statements.length == 1 &&
                body.block.statements.single is d.ExpressionStatement) {
              final expr =
                  (body.block.statements.single as d.ExpressionStatement)
                      .expression;
              if (_canInlineLambdaExpr(expr)) {
                return '($params)$asyncMod -> ${_withoutHoisting(() => _expression(expr, depth))}';
              }
            }
            if (body.block.statements.length == 1 &&
                body.block.statements.single is d.ReturnStatement &&
                (body.block.statements.single as d.ReturnStatement)
                        .expression !=
                    null) {
              final expr = (body.block.statements.single as d.ReturnStatement)
                  .expression!;
              if (_canInlineLambdaExpr(expr)) {
                return '($params)$asyncMod -> ${_withoutHoisting(() => _expression(expr, depth))}';
              }
            }
            final hoisted = _tryHoistBlockLambda(params, asyncMod, body);
            if (hoisted != null) return hoisted;
            _fail(node,
                'multiline block lambda inside inline call requires binding to a local variable');
          }
          final stmts = _statements(body.block.statements, depth + 1);
          return '($params)$asyncMod -> :\n${stmts.isEmpty ? '${'  ' * (depth + 1)}return' : stmts}';
        }
        _fail(node, 'unsupported lambda body: ${body.runtimeType}');
      }, initial: _parameterNames(node.parameters));
    }
    if (node is d.SwitchExpression) {
      if (!allowBlock) {
        _fail(node,
            'switch expression inside inline expression requires binding to a local variable');
      }
      final buf =
          StringBuffer('match ${_expression(node.expression, depth)}:\n');
      final armPad = '  ' * (depth + 1);
      for (final arm in node.cases) {
        final boundNames = <String>[];
        final pat =
            _dartPattern(arm.guardedPattern.pattern, depth + 1, boundNames);
        final guard = arm.guardedPattern.whenClause == null
            ? ''
            : ' when ${_withoutHoisting(() => _expression(arm.guardedPattern.whenClause!.expression, depth + 1))}';
        final armExpr = _withScope(
          () => _withoutHoisting(() => _expression(arm.expression, depth + 1)),
          initial: boundNames,
        );
        buf.writeln('$armPad$pat$guard: $armExpr');
      }
      return buf.toString().trimRight();
    }
    if (node is d.CascadeExpression) {
      _fail(node, 'Dart cascade (..) requires manual migration to Quds with');
    }
    _fail(node, 'unsupported expression: ${node.runtimeType}');
  }

  String _setOrMapLiteral(
    d.SetOrMapLiteral node,
    int depth, {
    required bool allowBlock,
  }) {
    final typeArgs = node.typeArguments?.arguments;
    final hasMapEntries = node.elements.any((e) => e is d.MapLiteralEntry);
    // On unresolved Dart AST, `{}` has `isMap == false && isSet == false`, but
    // in Dart an untyped empty `{}` is ALWAYS a Map, never a Set.
    final isSet = node.isSet ||
        (typeArgs != null && typeArgs.length == 1) ||
        (node.elements.isNotEmpty && !hasMapEntries && !node.isMap);
    final isMap = !isSet;

    if (isMap) {
      final typeSuffix = (typeArgs != null && typeArgs.length == 2)
          ? '<${_typeAnnotation(typeArgs[0])}, ${_typeAnnotation(typeArgs[1])}>'
          : '';
      if (node.elements.isEmpty) {
        return typeSuffix.isEmpty
            ? 'Map<dynamic, dynamic>()'
            : 'Map$typeSuffix()';
      }
      final allPlainEntries =
          node.elements.every((e) => e is d.MapLiteralEntry);
      if (allowBlock && typeSuffix.isEmpty && allPlainEntries) {
        final entryPad = '  ' * (depth + 1);
        final buf = StringBuffer('map:\n');
        for (final e in node.elements) {
          final entry = e as d.MapLiteralEntry;
          buf.writeln(
              '$entryPad${_expression(entry.key, depth + 1)}: ${_expression(entry.value, depth + 1)}');
        }
        return buf.toString().trimRight();
      }
      if (!allPlainEntries) {
        _fail(node, 'complex map literal element requires manual review');
      }
      final entries = node.elements.map((e) {
        final entry = e as d.MapLiteralEntry;
        return 'MapEntry(${_expression(entry.key, depth)}, ${_expression(entry.value, depth)})';
      }).join(', ');
      return 'Map$typeSuffix.fromEntries([$entries])';
    }

    // Set literal.
    final typeSuffix = (typeArgs != null && typeArgs.length == 1)
        ? '<${_typeAnnotation(typeArgs.single)}>'
        : '';
    if (node.elements.isEmpty) {
      return typeSuffix.isEmpty ? 'Set<dynamic>()' : 'Set$typeSuffix()';
    }
    if (allowBlock && typeSuffix.isEmpty) {
      final itemPad = '  ' * (depth + 1);
      final buf = StringBuffer('set:\n');
      for (final el in node.elements) {
        buf.writeln('$itemPad${_inlineElement(el, depth + 1)}');
      }
      return buf.toString().trimRight();
    }
    final els = node.elements.map((e) => _inlineElement(e, depth)).join(', ');
    return 'Set$typeSuffix.of([$els])';
  }

  String _inlineElement(d.CollectionElement e, int depth) {
    if (e is d.Expression) return _expression(e, depth);
    if (e is d.SpreadElement) {
      return '${e.isNullAware ? '...?' : '...'}${_expression(e.expression, depth)}';
    }
    if (e is d.IfElement) {
      final boundNames = <String>[];
      final cond = _ifElementHeader(e, depth, boundNames);
      final thenEl = _withScope(
        () => _inlineElement(e.thenElement, depth),
        initial: boundNames,
      );
      if (e.elseElement != null) {
        return 'if $cond: $thenEl else: ${_inlineElement(e.elseElement!, depth)}';
      }
      return 'if $cond: $thenEl';
    }
    if (e is d.ForElement) {
      final parts = e.forLoopParts;
      if (parts is d.ForEachPartsWithDeclaration) {
        final v = parts.loopVariable.name.lexeme;
        _checkIdentifierName(parts.loopVariable, v);
        final body = _withScope(
          () => _inlineElement(e.body, depth),
          initial: [v],
        );
        return 'for $v in ${_expression(parts.iterable, depth)}: $body';
      }
      if (parts is d.ForEachPartsWithIdentifier) {
        return 'for ${parts.identifier.name} in ${_expression(parts.iterable, depth)}: ${_inlineElement(e.body, depth)}';
      }
    }
    _fail(e, 'inline collection element ${e.runtimeType} requires block form');
  }

  bool _mutatesVariable(d.AstNode root, String varName) {
    var mutated = false;
    void walk(d.AstNode node) {
      if (mutated) return;
      if (node is d.AssignmentExpression &&
          node.leftHandSide is d.SimpleIdentifier &&
          (node.leftHandSide as d.SimpleIdentifier).name == varName) {
        mutated = true;
        return;
      }
      if (node is d.PrefixExpression &&
          (node.operator.lexeme == '++' || node.operator.lexeme == '--') &&
          node.operand is d.SimpleIdentifier &&
          (node.operand as d.SimpleIdentifier).name == varName) {
        mutated = true;
        return;
      }
      if (node is d.PostfixExpression &&
          (node.operator.lexeme == '++' || node.operator.lexeme == '--') &&
          node.operand is d.SimpleIdentifier &&
          (node.operand as d.SimpleIdentifier).name == varName) {
        mutated = true;
        return;
      }
      for (final entity in node.childEntities) {
        if (entity is d.AstNode) walk(entity);
      }
    }

    walk(root);
    return mutated;
  }

  bool _hasUnnestedContinue(d.AstNode root) {
    var found = false;
    void walk(d.AstNode node) {
      if (found) return;
      if (node is d.ContinueStatement && node.label == null) {
        found = true;
        return;
      }
      // Do not descend into nested loops or closures whose own `continue`
      // does not target the enclosing loop.
      if (node is d.ForStatement ||
          node is d.WhileStatement ||
          node is d.DoStatement ||
          node is d.FunctionExpression ||
          node is d.FunctionDeclaration) {
        return;
      }
      for (final entity in node.childEntities) {
        if (entity is d.AstNode) walk(entity);
      }
    }

    walk(root);
    return found;
  }
}

class _FieldCtorMeta {
  const _FieldCtorMeta({
    required this.fieldName,
    required this.required,
    this.defaultValue,
  });

  final String fieldName;
  final bool required;
  final d.Expression? defaultValue;
}

String? _generatedFileReason(String relativePosix, String content) {
  if (relativePosix.endsWith('.g.dart') ||
      relativePosix.endsWith('.freezed.dart') ||
      relativePosix.endsWith('.gr.dart') ||
      relativePosix.endsWith('.mocks.dart')) {
    return 'Code-generated Dart file (${relativePosix.split('/').last})';
  }
  final head = content.length > 300 ? content.substring(0, 300) : content;
  if (head.contains('// Generated by Quds') ||
      head.contains('GENERATED CODE - DO NOT MODIFY BY HAND')) {
    return 'Auto-generated file header detected';
  }
  return null;
}

String? _resolveRelativePosix(String fromRel, String target) {
  final baseDir = fromRel.contains('/')
      ? fromRel.substring(0, fromRel.lastIndexOf('/') + 1)
      : '';
  final resolved = Uri.parse('file:///$baseDir').resolve(target).path;
  if (!resolved.startsWith('/')) return null;
  return resolved.substring(1);
}

int _countLines(String content) {
  if (content.isEmpty) return 0;
  final normalized = content.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  return normalized.endsWith('\n') ? lines.length - 1 : lines.length;
}

bool _ensureAnalysisOptionsExclude(Directory root, String pattern) {
  final file = File(_join(root.path, 'analysis_options.yaml'));
  if (!file.existsSync()) {
    file.writeAsStringSync('analyzer:\n  exclude:\n    - $pattern\n');
    return true;
  }
  final existing = file.readAsStringSync();
  try {
    final editor = YamlEditor(existing);
    final rootNode = editor.parseAt([]).value;
    if (rootNode == null) {
      final sep = existing.isEmpty || existing.endsWith('\n') ? '' : '\n';
      file.writeAsStringSync(
          '${existing}${sep}analyzer:\n  exclude:\n    - $pattern\n');
      return true;
    }
    if (rootNode is! Map) return false;
    final analyzer = rootNode['analyzer'];
    if (analyzer == null) {
      editor.update([
        'analyzer'
      ], {
        'exclude': [pattern]
      });
    } else if (analyzer is Map) {
      final exclude = analyzer['exclude'];
      if (exclude == null) {
        editor.update(['analyzer', 'exclude'], [pattern]);
      } else if (exclude is List) {
        if (exclude.any((item) => item.toString() == pattern)) {
          return false;
        }
        editor.appendToList(['analyzer', 'exclude'], pattern);
      } else if (exclude is String) {
        if (exclude == pattern) return false;
        editor.update(['analyzer', 'exclude'], [exclude, pattern]);
      } else {
        return false;
      }
    } else {
      return false;
    }
    final updated = editor.toString();
    file.writeAsStringSync(updated.endsWith('\n') ? updated : '$updated\n');
    return true;
  } catch (_) {
    // Fall back safely without corrupting non-standard YAML.
    if (existing.contains(pattern)) return false;
    return false;
  }
}

bool _ensureGitignoreEntries(Directory root, List<String> entries) {
  final file = File(_join(root.path, '.gitignore'));
  final existing = file.existsSync() ? file.readAsStringSync() : '';
  final lines = existing.split('\n').map((l) => l.trim()).toSet();
  final missing = [
    for (final entry in entries)
      if (!lines.contains(entry)) entry,
  ];
  if (missing.isEmpty) return false;
  final sep = existing.isEmpty || existing.endsWith('\n') ? '' : '\n';
  file.writeAsStringSync('$existing$sep${missing.join('\n')}\n');
  return true;
}

String _timestamp(DateTime dt) {
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}${p2(dt.month)}${p2(dt.day)}_${p2(dt.hour)}${p2(dt.minute)}${p2(dt.second)}';
}

String _relativePosix(Directory root, File file) {
  final rootPath = root.absolute.path.replaceAll('\\', '/');
  final filePath = file.absolute.path.replaceAll('\\', '/');
  final prefix = rootPath.endsWith('/') ? rootPath : '$rootPath/';
  final matches = Platform.isWindows
      ? filePath.toLowerCase().startsWith(prefix.toLowerCase())
      : filePath.startsWith(prefix);
  return matches ? filePath.substring(prefix.length) : filePath;
}

String _join(String root, String relative) {
  final tail = relative.replaceAll('/', Platform.pathSeparator);
  if (root.endsWith(Platform.pathSeparator)) return '$root$tail';
  return '$root${Platform.pathSeparator}$tail';
}

class _BlockConstructFinder extends dv.RecursiveAstVisitor<void> {
  _BlockConstructFinder(this._migrator);

  final _DartToQudsEmitter _migrator;
  var found = false;

  @override
  void visitFunctionExpression(d.FunctionExpression node) {
    if (found) return;
    if (_migrator._needsBlockLambda(node)) {
      found = true;
      return;
    }
    super.visitFunctionExpression(node);
  }

  @override
  void visitSwitchExpression(d.SwitchExpression node) {
    found = true;
  }
}
