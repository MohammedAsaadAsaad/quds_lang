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

const _builderCalls = {
  'addMethod',
  'addFunction',
  'addField',
  'addProperty',
  'addConstructor',
};

class _Added {
  _Added({
    List<FunctionDeclaration>? methods,
    List<FieldDeclaration>? fields,
    List<FunctionDeclaration>? functions,
    List<PropertyDeclaration>? properties,
    List<ConstructorDeclaration>? constructors,
  })  : methods = methods ?? <FunctionDeclaration>[],
        fields = fields ?? <FieldDeclaration>[],
        functions = functions ?? <FunctionDeclaration>[],
        properties = properties ?? <PropertyDeclaration>[],
        constructors = constructors ?? <ConstructorDeclaration>[];

  final List<FunctionDeclaration> methods;
  final List<FieldDeclaration> fields;
  final List<FunctionDeclaration> functions;
  final List<PropertyDeclaration> properties;
  final List<ConstructorDeclaration> constructors;

  int get length =>
      methods.length +
      fields.length +
      functions.length +
      properties.length +
      constructors.length;

  void absorb(_Added other) {
    methods.addAll(other.methods);
    fields.addAll(other.fields);
    functions.addAll(other.functions);
    properties.addAll(other.properties);
    constructors.addAll(other.constructors);
  }
}

/// Applies `@macro` classes. `declare` copies top-level functions.
/// `define` copies methods, fields, properties, and constructors.
/// Source text, a forbidden capability, a cycle, a depth past 8, or more
/// than 1000 added declarations is rejected.
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
  final functions = <Statement>[];
  final statements = <Statement>[];
  for (final statement in program.statements) {
    if (statement is ClassDeclaration &&
        hasAnnotation(statement.annotations, 'macro')) {
      continue;
    }
    if (statement is ClassDeclaration) {
      final methods = [...statement.methods];
      final fields = [...statement.fields];
      final properties = [...statement.properties];
      final constructors = [...statement.constructors];
      for (final note in statement.annotations) {
        if (note.name == 'macro') continue;
        final macro = macros[note.name];
        if (macro == null) {
          throw CompilerException(
              'E906', 'Unknown macro: ${note.name}', statement.span);
        }
        final added = _apply(macro, macros, <String>[], 1, note.span);
        if (added.length > 1000) {
          throw CompilerException(
              'E906', 'A macro added more than 1000 declarations', note.span);
        }
        methods.addAll(added.methods);
        fields.addAll(added.fields);
        properties.addAll(added.properties);
        constructors.addAll(added.constructors);
        functions.addAll(added.functions);
      }
      statements.add(ClassDeclaration(
          statement.name,
          statement.kind,
          fields,
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
          constructors: constructors,
          properties: properties,
          typeParameters: statement.typeParameters));
    } else {
      statements.add(statement);
    }
  }
  return Program([...functions, ...statements], program.span);
}

void _forbid(ClassDeclaration macro) {
  walkAst(macro, (node) {
    if (node is Identifier && _forbidden.contains(node.name)) {
      throw CompilerException(
          'E905', 'A macro uses a forbidden capability', node.span);
    }
  });
}

_Added _apply(
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
  final added = _Added();
  try {
    for (final note in macro.annotations) {
      if (note.name == 'macro') continue;
      final other = macros[note.name];
      if (other == null) continue;
      added.absorb(_apply(other, macros, stack, depth + 1, note.span));
    }
    if (!macro.methods.any((method) => method.name == 'declare') &&
        !macro.methods.any((method) => method.name == 'define')) {
      throw CompilerException(
          'E906', 'A macro class needs declare or define', macro.span);
    }
    added.absorb(_phase(macro, 'declare'));
    added.absorb(_phase(macro, 'define'));
  } finally {
    stack.removeLast();
  }
  return added;
}

_Added _phase(ClassDeclaration macro, String phase) {
  final found = macro.methods.where((method) => method.name == phase).toList();
  if (found.isEmpty) return _Added();
  if (found.length != 1) {
    throw CompilerException(
        'E906', 'A macro class needs one $phase method', macro.span);
  }
  final body = found.single.body;
  if (body == null) {
    throw CompilerException(
        'E906', '$phase must be a block of builder calls', macro.span);
  }
  final added = _Added();
  for (final statement in body) {
    final call = statement is ExpressionStatement ? statement.expression : null;
    final member = call is CallExpression && call.callee is MemberAccess
        ? call.callee as MemberAccess
        : null;
    final argument = call is CallExpression && call.arguments.length == 1
        ? call.arguments.single.value
        : null;
    if (member != null &&
        _builderCalls.contains(member.name) &&
        ((argument is Literal && argument.value is String) ||
            argument is InterpolatedString)) {
      throw CompilerException(
          'E905', 'A macro cannot emit source text', statement.span);
    }
    if (member == null ||
        !_builderCalls.contains(member.name) ||
        argument is! Identifier) {
      throw CompilerException(
          'E906',
          'Macros may only call builder.addMethod, addFunction, addField, addProperty, or addConstructor',
          statement.span);
    }
    if (phase == 'declare' && member.name != 'addFunction') {
      throw CompilerException(
          'E906', 'declare may only call builder.addFunction', statement.span);
    }
    if (phase == 'define' && member.name == 'addFunction') {
      throw CompilerException(
          'E906',
          'define adds members; top-level functions use declare',
          statement.span);
    }
    switch (member.name) {
      case 'addMethod':
      case 'addFunction':
        final method =
            macro.methods.where((item) => item.name == argument.name).toList();
        if (method.length != 1 ||
            method.single.name == 'define' ||
            method.single.name == 'declare') {
          throw CompilerException(
              'E906',
              '${member.name} target is not a method of ${macro.name}',
              argument.span);
        }
        if (member.name == 'addFunction') {
          added.functions.add(method.single);
        } else {
          added.methods.add(method.single);
        }
      case 'addField':
        final field =
            macro.fields.where((item) => item.name == argument.name).toList();
        if (field.length != 1) {
          throw CompilerException('E906',
              'addField target is not a field of ${macro.name}', argument.span);
        }
        added.fields.add(field.single);
      case 'addProperty':
        final property = macro.properties
            .where((item) => item.name == argument.name)
            .toList();
        if (property.length != 1) {
          throw CompilerException(
              'E906',
              'addProperty target is not a property of ${macro.name}',
              argument.span);
        }
        added.properties.add(property.single);
      case 'addConstructor':
        final constructor = macro.constructors.where((item) {
          if (argument.name == 'init') return item.name == null;
          return item.name == argument.name;
        }).toList();
        if (constructor.length != 1) {
          throw CompilerException(
              'E906',
              'addConstructor target is not a constructor of ${macro.name}',
              argument.span);
        }
        added.constructors.add(constructor.single);
    }
  }
  if (added.length > 1000) {
    throw CompilerException(
        'E906', 'A macro added more than 1000 declarations', macro.span);
  }
  return added;
}
