import 'ast.dart';
import 'source.dart';

/// Copies methods named by `builder.addMethod` from an `@macro` class onto
/// each annotated class. Any other macro statement is rejected.
Program expandMacros(Program program) {
  final macros = <String, ClassDeclaration>{};
  for (final statement in program.statements) {
    if (statement is ClassDeclaration &&
        hasAnnotation(statement.annotations, 'macro')) {
      macros[statement.name] = statement;
    }
  }
  if (macros.isEmpty) return program;
  final statements = <Statement>[];
  for (final statement in program.statements) {
    if (statement is ClassDeclaration &&
        hasAnnotation(statement.annotations, 'macro')) {
      continue;
    }
    if (statement is ClassDeclaration) {
      final methods = [...statement.methods];
      for (final note in statement.annotations) {
        if (note.name == 'macro') continue;
        final macro = macros[note.name];
        if (macro == null) {
          throw CompilerException(
              'E906', 'Unknown macro: ${note.name}', statement.span);
        }
        methods.addAll(_expand(macro));
      }
      statements.add(ClassDeclaration(
          statement.name,
          statement.kind,
          statement.fields,
          methods,
          statement.cases,
          statement.annotations.where((note) => note.name == 'macro').toList(),
          statement.span));
    } else {
      statements.add(statement);
    }
  }
  return Program(statements, program.span);
}

List<FunctionDeclaration> _expand(ClassDeclaration macro) {
  final define = macro.methods.where((method) => method.name == 'define');
  if (define.length != 1) {
    throw CompilerException(
        'E906', 'A macro class needs one define method', macro.span);
  }
  final body = define.single.body;
  if (body == null) {
    throw CompilerException('E906',
        'define must be a block that calls builder.addMethod', macro.span);
  }
  final added = <FunctionDeclaration>[];
  for (final statement in body) {
    final call = statement is ExpressionStatement ? statement.expression : null;
    final member = call is CallExpression && call.callee is MemberAccess
        ? call.callee as MemberAccess
        : null;
    final argument = call is CallExpression && call.arguments.length == 1
        ? call.arguments.single.value
        : null;
    if (member == null ||
        member.name != 'addMethod' ||
        argument is! Identifier) {
      throw CompilerException(
          'E906',
          'Macros may only call builder.addMethod with a method of the macro class',
          statement.span);
    }
    final method =
        macro.methods.where((item) => item.name == argument.name).toList();
    if (method.length != 1 || method.single.name == 'define') {
      throw CompilerException('E906',
          'addMethod target is not a method of ${macro.name}', argument.span);
    }
    added.add(method.single);
  }
  return added;
}
