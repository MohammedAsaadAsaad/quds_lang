import 'dart:io';

import 'ast.dart';
import 'augment.dart';
import 'emitter.dart';
import 'lexer.dart';
import 'libraries.dart';
import 'macros.dart';
import 'parser.dart';
import 'sdk.dart';
import 'readonly_runtime_source.dart';
import 'semantics.dart';
import 'sourcemap.dart';

/// One `.quds` file emitted by `@GenerateModel`.
class GeneratedModel {
  const GeneratedModel(this.fileName, this.source, this.sourceMap);
  final String fileName;
  final String source;
  final String sourceMap;
}

/// Generated Dart for one `quds:` library, written beside the caller's output.
class SdkBundle {
  const SdkBundle(this.fileName, this.source);
  final String fileName;
  final String source;
}

class Compilation {
  const Compilation(this.program, this.semantics, this.dart,
      {this.sourceMap,
      this.dependencies = const [],
      this.models = const [],
      this.bundles = const []});
  final Program program;
  final SemanticModel semantics;
  final String dart;
  final String? sourceMap;

  /// Absolute paths of this source and the `.quds` files it loaded.
  final List<String> dependencies;

  /// Deterministic Quds sources derived from `@GenerateModel` classes.
  final List<GeneratedModel> models;

  /// SDK libraries this program imports, as sibling Dart files.
  final List<SdkBundle> bundles;
}

/// Relocate the shared runtime when emitting a dependency graph into several
/// directories. All modules must resolve to the same runtime library URI.
Compilation relocateReadonlyRuntime(Compilation result, String relativeUri) {
  if (relativeUri == 'quds_readonly.dart') return result;
  final uri = Uri.parse(relativeUri);
  if (uri.hasScheme ||
      relativeUri.contains("'") ||
      relativeUri.contains(r'$') ||
      relativeUri.contains('\n')) {
    throw ArgumentError.value(
        relativeUri, 'relativeUri', 'Expected a relative generated-file URI');
  }
  String relocate(String source) =>
      source.replaceAll("import 'quds_readonly.dart'", "import '$relativeUri'");
  return Compilation(result.program, result.semantics, relocate(result.dart),
      sourceMap: result.sourceMap,
      dependencies: result.dependencies,
      models: result.models,
      bundles: [
        for (final bundle in result.bundles)
          SdkBundle(
              bundle.fileName == 'quds_readonly.dart'
                  ? uri.toFilePath()
                  : bundle.fileName,
              relocate(bundle.source))
      ]);
}

/// Route generated SDK libraries to one directory for the entire output graph.
/// All SDK bundles remain siblings there, preserving Dart type/error identity.
Compilation relocateGeneratedLibraries(Compilation result, String directory) {
  if (directory.isEmpty) return result;
  final uri = Uri.parse(directory);
  if (uri.hasScheme ||
      uri.hasAuthority ||
      !directory.endsWith('/') ||
      directory.contains("'") ||
      directory.contains(r'$') ||
      directory.contains('\n')) {
    throw ArgumentError.value(
        directory, 'directory', 'Expected a relative directory URI');
  }
  final names = {
    'quds_readonly.dart',
    ...sdkLibraryNames().map(sdkDartFileName)
  };
  String relocate(String source) => source.split('\n').map((line) {
        for (final name in names) {
          for (final kind in ['import', 'export']) {
            final prefix = "$kind '$name'";
            if (line.startsWith(prefix))
              return "$kind '$directory$name'${line.substring(prefix.length)}";
          }
        }
        return line;
      }).join('\n');
  return Compilation(result.program, result.semantics, relocate(result.dart),
      sourceMap: result.sourceMap,
      dependencies: result.dependencies,
      models: result.models,
      bundles: [
        for (final bundle in result.bundles)
          SdkBundle('$directory${bundle.fileName}', bundle.source)
      ]);
}

/// Writes [result]'s SDK libraries into [directory].
void writeSdkBundles(String directory, Compilation result) {
  for (final bundle in result.bundles) {
    final file = File('$directory${Platform.pathSeparator}${bundle.fileName}');
    if (file.existsSync() && file.readAsStringSync() == bundle.source) continue;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(bundle.source);
  }
}

Compilation compile(String source,
    {String file = '<input>', bool partial = false, bool emitDart = true}) {
  final parser = Parser(Lexer().tokenize(source, file: file));
  final parsed = parser.parse(partial: partial);
  if (partial && parser.errors.isNotEmpty && parsed.statements.isEmpty) {
    throw parser.errors.first;
  }
  var program = expandMacros(parsed);
  final sourcePath = file == '<input>' ? file : File(file).absolute.path;
  if (sourcePath != '<input>') _checkLanguage(sourcePath);
  final libraries = <String, Program>{};
  var library = sourcePath;
  _loadSdkImports(program, libraries);
  if (sourcePath != '<input>') {
    libraries[sourcePath] = program;
    _loadLibraries(program, sourcePath, libraries);
    final parts = program.statements.whereType<PartDirective>().toList();
    final ofs = parts.where((item) => item.of).toList();
    final owned = parts.where((item) => !item.of).toList();
    if (ofs.length == 1 && owned.isEmpty) {
      library = Uri.file(sourcePath).resolve(ofs.single.uri).toFilePath();
    }
  }
  final normalized = normalizeConversions(
      normalizeAugments({...libraries, sourcePath: program}));
  libraries
    ..clear()
    ..addAll(normalized);
  program = normalized[sourcePath]!;
  if (sourcePath == '<input>') libraries.remove(sourcePath);
  final semantics = Analyzer(library: library, file: sourcePath)
      .analyze(program, libraries: libraries);
  semantics.protectWithMeta =
      sourcePath != '<input>' && packageDependsOnMeta(sourcePath);
  final emitter = DartEmitter(semantics);
  final dart = emitter.emit(program);
  if (!emitDart)
    return Compilation(program, semantics, '',
        dependencies: [
          for (final key in libraries.keys)
            if (!key.startsWith('quds:')) key,
        ]..sort());
  final generated = file.endsWith('.quds')
      ? '${file.substring(0, file.length - 5)}.dart'
      : 'out.dart';
  final dependencies = [
    for (final key in libraries.keys)
      if (!key.startsWith('quds:')) key,
  ]..sort();
  return Compilation(program, semantics, dart,
      sourceMap: sourceMapFor(emitter, generated, file,
          program: program, source: source),
      dependencies: dependencies,
      models: _generatedModels(program, file),
      bundles: _compilationBundles(semantics, dart));
}

List<SdkBundle> _compilationBundles(SemanticModel semantics, String dart) {
  final result = _sdkBundles(semantics);
  if (dart.contains("import 'quds_readonly.dart'") ||
      result.any((b) => b.source.contains("import 'quds_readonly.dart'"))) {
    result.add(SdkBundle('quds_readonly.dart', readonlyRuntimeSource));
  }
  return result;
}

final _sdkDartCache = <String, String>{};
var _compilingSdk = false;

String? _sdkDart(String name) {
  final source = readSdk(name);
  if (source == null) return null;
  final cached = _sdkDartCache[source];
  if (cached != null) return cached;
  if (_compilingSdk) return null;
  _compilingSdk = true;
  try {
    final path = sdkPath(name);
    final dart =
        (path == null ? compile(source) : compile(source, file: path)).dart;
    _sdkDartCache[source] = dart;
    return dart;
  } finally {
    _compilingSdk = false;
  }
}

List<SdkBundle> _sdkBundles(SemanticModel semantics) {
  final bundles = <SdkBundle>[];
  final seen = <String>{};
  final uris = <String>{
    for (final node in semantics.imports)
      if (emitsSdkImport(node, semantics)) node.uri,
    // A converter or type reached through a local export still needs its SDK
    // artifact even when the caller has no direct `use quds:...` directive.
    ...semantics.usedSdk,
  };
  for (final uri in uris) {
    final name = sdkLibraryName(uri);
    if (name == null || !seen.add(name)) continue;
    final dart = _sdkDart(name);
    if (dart == null) continue;
    bundles.add(SdkBundle(sdkDartFileName(name), dart));
  }
  return bundles;
}

void _loadSdkImports(Program program, Map<String, Program> libraries) {
  for (final statement in program.statements) {
    if (statement is! ImportDeclaration) continue;
    final name = sdkLibraryName(statement.uri);
    if (name == null || libraries.containsKey(statement.uri)) continue;
    // Sections select names from one library; they must share declaration
    // identity with each other and with an import of the whole SDK library.
    final target = libraryTarget(statement.uri);
    final cached = libraries[target];
    if (cached != null) {
      libraries[statement.uri] = cached;
      continue;
    }
    final source = readSdk(name);
    if (source == null) continue;
    final path = sdkPath(name) ?? target;
    final parsed = Parser(Lexer().tokenize(source, file: path)).parse();
    final loaded = expandMacros(parsed);
    libraries[target] = loaded;
    libraries[statement.uri] = loaded;
    _loadSdkImports(loaded, libraries);
  }
}

/// Parse and analyze [source]. Every recorded parse error is returned. A
/// later failure is that one error. A successful program returns its warnings.
List<CompilerException> diagnose(String source,
    {String file = '<input>', bool emitDart = true}) {
  Parser? parser;
  try {
    parser = Parser(Lexer().tokenize(source, file: file));
    parser.parse();
  } on CompilerException catch (error) {
    if (parser != null && parser.errors.isNotEmpty) {
      return List<CompilerException>.of(parser.errors);
    }
    return [error];
  }
  try {
    return List<CompilerException>.of(
        compile(source, file: file, emitDart: emitDart).semantics.warnings);
  } on CompilerException catch (error) {
    return [error];
  }
}

List<GeneratedModel> _generatedModels(Program program, String file) {
  final names = <String>{
    for (final statement in program.statements)
      if (statement is ClassDeclaration) statement.name,
  };
  final files = <String>{};
  final models = <GeneratedModel>[];
  for (final statement in program.statements) {
    if (statement is! ClassDeclaration) continue;
    final notes = statement.annotations
        .where((note) => note.name == 'GenerateModel')
        .toList();
    if (notes.isEmpty) continue;
    if (notes.any((note) => note.arguments.isNotEmpty)) {
      throw CompilerException(
          'E500', 'GenerateModel takes no arguments', notes.first.span);
    }
    final name = '${statement.name}Model';
    final fileName = '${_snake(name)}.quds';
    if (names.contains(name) || !files.add(fileName)) {
      throw CompilerException(
          'E904', 'Generator collision: $name', statement.span);
    }
    names.add(name);
    final fields = statement.fields.where((item) => !item.isStatic).toList();
    final buffer = StringBuffer()
      ..writeln('# Generated from ${statement.name}. Do not edit.')
      ..writeln('value class $name:');
    final mappings = <(int, SourceSpan)>[
      (1, statement.span),
      (2, statement.span),
    ];
    if (fields.isEmpty) {
      buffer.writeln('  marker: int = 1');
      mappings.add((3, statement.span));
    } else {
      for (var i = 0; i < fields.length; i++) {
        buffer.writeln('  ${fields[i].name}: ${fields[i].type}');
        mappings.add((i + 3, fields[i].span));
      }
    }
    models.add(GeneratedModel(fileName, buffer.toString(),
        encodeSourceMap(fileName, file, mappings)));
  }
  return models;
}

String _snake(String name) {
  final buffer = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final char = name[i];
    final upper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (i > 0 && upper) buffer.write('_');
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}

void _loadLibraries(
    Program program, String from, Map<String, Program> libraries) {
  for (final statement in program.statements) {
    final uri = switch (statement) {
      ImportDeclaration()
          when libraryTarget(statement.uri).endsWith('.quds') ||
              statement.uri.startsWith('package:') ||
              statement.uri.startsWith('generated:') =>
        statement.uri,
      PartDirective() when statement.uri.endsWith('.quds') => statement.uri,
      _ => null,
    };
    if (uri == null) continue;
    final path = resolveLibraryPath(from, uri);
    if (path == null || libraries.containsKey(path)) continue;
    final file = File(path);
    if (!file.existsSync()) continue;
    final parsed =
        Parser(Lexer().tokenize(file.readAsStringSync(), file: path)).parse();
    final loaded = expandMacros(parsed);
    libraries[path] = loaded;
    _loadSdkImports(loaded, libraries);
    _loadLibraries(loaded, path, libraries);
  }
}

/// A comment does not select a version. Only `language:` in `quds.yaml`
/// beside the source does, and a value other than 1.2 is E901.
void _checkLanguage(String file) {
  final yaml = File('${File(file).parent.path}/quds.yaml');
  if (!yaml.existsSync()) return;
  final match = RegExp(r'^[ \t]*language:[ \t]*"?([^"\s#]+)"?', multiLine: true)
      .firstMatch(yaml.readAsStringSync());
  if (match == null || match.group(1) == '1.2') return;
  throw CompilerException(
      'E901',
      'The declared language version is not supported',
      SourceSpan(1, 1, 0, file: file));
}
