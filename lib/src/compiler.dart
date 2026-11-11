import 'ast.dart';
import 'emitter.dart';
import 'lexer.dart';
import 'parser.dart';
import 'semantics.dart';

class Compilation {
  const Compilation(this.program, this.semantics, this.dart);
  final Program program;
  final SemanticModel semantics;
  final String dart;
}

Compilation compile(String source, {String file = '<input>'}) {
  final program = Parser(Lexer().tokenize(source, file: file)).parse();
  final semantics = Analyzer().analyze(program);
  return Compilation(program, semantics, DartEmitter(semantics).emit(program));
}
