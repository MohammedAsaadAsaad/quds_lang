import 'dart:io';

import 'ast.dart';
import 'emitter.dart';
import 'lexer.dart';
import 'libraries.dart';
import 'macros.dart';
import 'parser.dart';
import 'semantics.dart';
import 'sourcemap.dart';

class Compilation {
  const Compilation(this.program, this.semantics, this.dart,
      {this.sourceMap, this.dependencies = const []});
  final Program program;
  final SemanticModel semantics;
  final String dart;
  final String? sourceMap;

  /// Absolute paths of this source and the `.quds` files it loaded.
  final List<String> dependencies;
}

Compilation compile(String source, {String file = '<input>'}) {
  final parsed = Parser(Lexer().tokenize(source, file: file)).parse();
  final program = expandMacros(parsed);
  final sourcePath = file == '<input>' ? file : File(file).absolute.path;
  if (sourcePath != '<input>') _checkLanguage(sourcePath);
  final libraries = <String, Program>{};
  var library = sourcePath;
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
  final semantics = Analyzer(library: library, file: sourcePath)
      .analyze(program, libraries: libraries);
  semantics.protectWithMeta =
      sourcePath != '<input>' && packageDependsOnMeta(sourcePath);
  final emitter = DartEmitter(semantics);
  final dart = emitter.emit(program);
  final generated = file.endsWith('.quds')
      ? '${file.substring(0, file.length - 5)}.dart'
      : 'out.dart';
  final dependencies = libraries.keys.toList()..sort();
  return Compilation(program, semantics, dart,
      sourceMap: sourceMapFor(emitter, generated, file),
      dependencies: dependencies);
}

void _loadLibraries(
    Program program, String from, Map<String, Program> libraries) {
  for (final statement in program.statements) {
    final uri = switch (statement) {
      ImportDeclaration()
          when statement.uri.endsWith('.quds') ||
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
