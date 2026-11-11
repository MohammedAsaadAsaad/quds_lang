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
  final semantics = Analyzer().analyze(program);
  final emitter = DartEmitter(semantics);
  final dart = emitter.emit(program);
  final generated = file.endsWith('.quds')
      ? '${file.substring(0, file.length - 5)}.dart'
      : 'out.dart';
  return Compilation(program, semantics, dart,
      sourceMap: sourceMapFor(emitter, generated, file));
}
