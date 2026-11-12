import 'dart:io';

import 'ast.dart';
import 'emitter.dart';
import 'lexer.dart';
import 'macros.dart';
import 'parser.dart';
import 'semantics.dart';
import 'sourcemap.dart';

class Compilation {
  const Compilation(this.program, this.semantics, this.dart, {this.sourceMap});
  final Program program;
  final SemanticModel semantics;
  final String dart;
  final String? sourceMap;
}

Compilation compile(String source, {String file = '<input>'}) {
  final parsed = Parser(Lexer().tokenize(source, file: file)).parse();
  final program = expandMacros(parsed);
  final library = file == '<input>' ? file : File(file).absolute.path;
  final libraries = <String, Program>{};
  if (library != '<input>') {
    libraries[library] = program;
    _loadLibraries(program, library, libraries);
  }
  final semantics =
      Analyzer(library: library).analyze(program, libraries: libraries);
  final emitter = DartEmitter(semantics);
  final dart = emitter.emit(program);
  final generated = file.endsWith('.quds')
      ? '${file.substring(0, file.length - 5)}.dart'
      : 'out.dart';
  return Compilation(program, semantics, dart,
      sourceMap: sourceMapFor(emitter, generated, file));
}

void _loadLibraries(
    Program program, String from, Map<String, Program> libraries) {
  for (final statement in program.statements) {
    if (statement is! ImportDeclaration || !statement.uri.endsWith('.quds')) {
      continue;
    }
    final path = Uri.file(from).resolve(statement.uri).toFilePath();
    if (libraries.containsKey(path)) continue;
    final file = File(path);
    if (!file.existsSync()) continue;
    final parsed =
        Parser(Lexer().tokenize(file.readAsStringSync(), file: path)).parse();
    final loaded = expandMacros(parsed);
    libraries[path] = loaded;
    _loadLibraries(loaded, path, libraries);
  }
}
