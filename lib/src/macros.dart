import 'ast.dart';
import 'source.dart';
import 'walk.dart';

const _forbidden = {
  'DateTime',
  'Random',
  'Stopwatch',
  'Platform',
  'Isolate',
  'HttpClient',
  'Socket',
  'WebSocket',
  'InternetAddress',
};

/// Copies methods named by `builder.addMethod` from an `@macro` class onto
/// each annotated class. Source text, a forbidden capability, a cycle, a
/// depth past 8, or more than 1000 added declarations is rejected.
Program expandMacros(Program program) {
  final macros = <String, ClassDeclaration>{};
  for (final statement in program.statements) {
    if (statement is ClassDeclaration &&
        hasAnnotation(statement.annotations, 'macro')) {
      macros[statement.name] = statement;
    }
  }
  if (macros.isEmpty) return program;
  for (final macro in macros.values) {
    _forbid(macro);
  }
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
        methods.addAll(_apply(macro, macros, <String>[], 1, note.span));
      }
      statements.add(ClassDeclaration(
          statement.name,
          statement.kind,
          statement.fields,
          methods,
          statement.cases,
          statement.annotations.where((note) => note.name == 'macro').toList(),
          statement.span,
          superclass: statement.superclass,
          mixins: statement.mixins,
          interfaces: statement.interfaces,
          onType: statement.onType,
          modifiers: statement.modifiers,
          requirements: statement.requirements,
          constructors: statement.constructors,
          properties: statement.properties,
          typeParameters: statement.typeParameters));
    } else {
      statements.add(statement);
    }
  }
  return Program(statements, program.span);
}

void _forbid(ClassDeclaration macro) {
  for (final method in macro.methods) {
    walkAst(method, (node) {
      if (node is Identifier && _forbidden.contains(node.name)) {
        throw CompilerException(
            'E905', 'A macro uses a forbidden capability', node.span);
      }
    });
  }
}

List<FunctionDeclaration> _apply(
  ClassDeclaration macro,
  Map<String, ClassDeclaration> macros,
  List<String> stack,
  int depth,
  SourceSpan span,
) {
  if (depth > 8) {
    throw CompilerException('E906', 'Macro expansion is past depth 8', span);
  }
  if (!stack.contains(macro.name)) {
    stack.add(macro.name);
  } else {
    throw CompilerException('E904', 'Macro expansion cycles', span);
  }
  final added = <FunctionDeclaration>[];
  try {
    for (final note in macro.annotations) {
      if (note.name == 'macro') continue;
      final other = macros[note.name];
      if (other == null) continue;
      added.addAll(_apply(other, macros, stack, depth + 1, note.span));
    }
    added.addAll(_methods(macro));
  } finally {
    stack.removeLast();
  }
  return added;
}

List<FunctionDeclaration> _methods(ClassDeclaration macro) {
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
    if (member != null &&
        member.name == 'addMethod' &&
        ((argument is Literal && argument.value is String) ||
            argument is InterpolatedString)) {
      throw CompilerException(
          'E905', 'A macro cannot emit source text', statement.span);
    }
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
  if (added.length > 1000) {
    throw CompilerException(
        'E906', 'A macro added more than 1000 declarations', macro.span);
  }
  return added;
}
