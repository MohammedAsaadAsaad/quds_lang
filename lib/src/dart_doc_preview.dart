import 'dart:convert';
import 'package:analyzer/dart/analysis/utilities.dart' as dart;
import 'package:analyzer/dart/ast/ast.dart' as d;
import 'lexer.dart';
import 'parser.dart';

// Presentation only. Neither the library's documentation nor executable source
// is changed. Unsupported Dart stays visible in its original form.
final _previews = <String, String?>{};

String presentDartExamples(String markdown) {
  if (markdown.length > 50000) return markdown;
  return markdown.replaceAllMapped(
      RegExp(r'(^[ \t]*)(`{3,}|~{3,})dart[ \t]*\r?\n(.*?)^\1\2[ \t]*(?=\r?$)',
          multiLine: true, dotAll: true), (match) {
    final source = match[3]!;
    final converted = dartExampleToQuds(source);
    if (converted == null) {
      return '${match[0]}\n\n*Original Dart example; automatic Quds preview unavailable.*';
    }
    return '${match[1]}${match[2]}quds\n$converted\n${match[1]}${match[2]}\n\n*Quds example translated for display.*';
  });
}

String? dartExampleToQuds(String source) {
  if (_previews.containsKey(source)) return _previews[source];
  String? result;
  if (source.length <= 8000) {
    try {
      var parsed = dart.parseString(content: source, throwIfDiagnostics: false);
      final printer = _Preview();
      if (parsed.errors.isEmpty && parsed.unit.declarations.isNotEmpty) {
        result = [
          for (final directive in parsed.unit.directives)
            printer.directive(directive),
          for (final node in parsed.unit.declarations) printer.declaration(node)
        ].join('\n');
      } else {
        final terminated =
            source.trimRight().endsWith(';') ? source : '$source;';
        parsed = dart.parseString(
            content: 'void __preview() {\n$terminated\n}',
            throwIfDiagnostics: false);
        if (parsed.errors.isNotEmpty) {
          throw const FormatException('Not a complete Dart fragment');
        }
        final fn = parsed.unit.declarations.single as d.FunctionDeclaration;
        result = printer.statements(
            (fn.functionExpression.body as d.BlockFunctionBody)
                .block
                .statements,
            0);
      }
      // Inline comments require richer source mapping. Keep their original
      // placement instead of silently dropping or moving them.
      var token = parsed.unit.beginToken;
      while (true) {
        if (token.precedingComments != null) {
          throw const FormatException('Comment placement');
        }
        if (token.isEof) break;
        token = token.next!;
      }
      Parser(Lexer().tokenize(result)).parse();
    } catch (_) {
      result = null;
    }
  }
  if (_previews.length >= 64) _previews.remove(_previews.keys.first);
  _previews[source] = result;
  return result;
}

class _Preview {
  Never unsupported() =>
      throw const FormatException('Unsupported Dart preview');
  String directive(d.Directive node) {
    if (node is d.ImportDirective &&
        node.configurations.isEmpty &&
        node.combinators.isEmpty &&
        node.deferredKeyword == null) {
      return 'use ${node.uri.stringValue}${node.prefix == null ? '' : ' as ${node.prefix!.name}'}';
    }
    return unsupported();
  }

  String declaration(d.CompilationUnitMember node) {
    if (node is d.FunctionDeclaration) return function(node, 0);
    if (node is d.TopLevelVariableDeclaration) {
      return variables(node.variables, 0);
    }
    return unsupported();
  }

  String function(d.FunctionDeclaration node, int depth) {
    if (node.isGetter ||
        node.isSetter ||
        node.functionExpression.typeParameters != null) {
      return unsupported();
    }
    final fn = node.functionExpression;
    final parameters = fn.parameters;
    if (parameters == null) return unsupported();
    final args = parameters.parameters.map((p) {
      final source = p.toSource();
      // The Dart AST establishes parameter boundaries. Restrict conversion to
      // ordinary typed parameters; complex defaults/destructuring stay Dart.
      final match = RegExp(r'^([A-Za-z_][\w<>?,. ]*)\s+([A-Za-z_]\w*)$')
          .firstMatch(source);
      if (match == null ||
          source.startsWith('required ') ||
          source.startsWith('this.')) {
        return unsupported();
      }
      return '${match[2]}: ${match[1]}';
    }).join(', ');
    final body = fn.body;
    var returnType = node.returnType?.toSource();
    if (returnType == null) return unsupported();
    if (body.isAsynchronous) {
      if (!returnType.startsWith('Future<') || !returnType.endsWith('>')) {
        return unsupported();
      }
      returnType = returnType.substring(7, returnType.length - 1);
    }
    final head =
        '${'  ' * depth}${node.name.lexeme}($args)${body.isAsynchronous ? ' async' : ''} -> $returnType';
    if (body is d.ExpressionFunctionBody) {
      return '$head = ${expression(body.expression)}';
    }
    if (body is d.BlockFunctionBody && !body.isGenerator) {
      return '$head:\n${statements(body.block.statements, depth + 1)}';
    }
    return unsupported();
  }

  String statements(Iterable<d.Statement> nodes, int depth) => nodes
      .map((n) => statement(n, depth))
      .where((s) => s.isNotEmpty)
      .join('\n');
  String statement(d.Statement node, int depth) {
    final pad = '  ' * depth;
    if (node is d.EmptyStatement) return '';
    if (node is d.VariableDeclarationStatement) {
      return variables(node.variables, depth);
    }
    if (node is d.ExpressionStatement) {
      return '$pad${expression(node.expression)}';
    }
    if (node is d.ReturnStatement) {
      return '${pad}return${node.expression == null ? '' : ' ${expression(node.expression!)}'}';
    }
    if (node is d.FunctionDeclarationStatement) {
      return function(node.functionDeclaration, depth);
    }
    if (node is d.IfStatement) {
      String branch(d.Statement n) => n is d.Block
          ? statements(n.statements, depth + 1)
          : statement(n, depth + 1);
      return '${pad}if ${expression(node.expression)}:\n${branch(node.thenStatement)}${node.elseStatement == null ? '' : '\n${pad}else:\n${branch(node.elseStatement!)}'}';
    }
    return unsupported();
  }

  String variables(d.VariableDeclarationList node, int depth) {
    if (node.lateKeyword != null) return unsupported();
    final keyword = node.keyword?.lexeme;
    return node.variables.map((v) {
      if (v.initializer == null) return unsupported();
      final prefix = keyword == 'final'
          ? ''
          : keyword == 'const'
              ? 'const '
              : 'var ';
      return '${'  ' * depth}$prefix${v.name.lexeme}${node.type == null ? '' : ': ${node.type!.toSource()}'} = ${expression(v.initializer!)}';
    }).join('\n');
  }

  String arguments(d.ArgumentList args) =>
      args.arguments.map(argument).join(', ');
  String argument(d.AstNode node) {
    if (node.beginToken.next?.lexeme == ':') {
      final values = node.childEntities.whereType<d.Expression>().toList();
      if (values.length != 1) return unsupported();
      return '${node.beginToken.lexeme}: ${expression(values.single)}';
    }
    if (node is d.Expression) return expression(node);
    return unsupported();
  }

  String escaped(String value) => jsonEncode(value)
      .substring(1, jsonEncode(value).length - 1)
      .replaceAll('{', r'\{')
      .replaceAll('}', r'\}');
  String expression(d.Expression node) {
    if (node is d.SimpleStringLiteral) return '"${escaped(node.value)}"';
    if (node is d.StringInterpolation) {
      return '"${node.elements.map((e) => e is d.InterpolationString ? escaped(e.value) : '{${expression((e as d.InterpolationExpression).expression)}}').join()}"';
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
      return '(${expression(node.expression)})';
    }
    if (node is d.PrefixedIdentifier) {
      return '${node.prefix.name}.${node.identifier.name}';
    }
    if (node is d.PropertyAccess && !node.isCascaded) {
      return '${expression(node.target!)}${node.operator.lexeme}${node.propertyName.name}';
    }
    if (node is d.MethodInvocation && !node.isCascaded) {
      final target = node.target == null
          ? ''
          : '${expression(node.target!)}${node.operator?.lexeme ?? '.'}';
      if (node.typeArguments == null &&
          node.argumentList.arguments.isEmpty &&
          {'abs', 'round', 'floor', 'ceil'}.contains(node.methodName.name) &&
          node.target != null) {
        return unsupported();
      }
      return '$target${node.methodName.name}${node.typeArguments?.toSource() ?? ''}(${arguments(node.argumentList)})';
    }
    if (node is d.InstanceCreationExpression &&
        node.keyword?.lexeme != 'const') {
      return '${node.constructorName.toSource()}(${arguments(node.argumentList)})';
    }
    if (node is d.AssignmentExpression) {
      return '${expression(node.leftHandSide)} ${node.operator.lexeme} ${expression(node.rightHandSide)}';
    }
    if (node is d.BinaryExpression) {
      final op = switch (node.operator.lexeme) {
        '&&' => 'and',
        '||' => 'or',
        final s => s
      };
      return '(${expression(node.leftOperand)} $op ${expression(node.rightOperand)})';
    }
    if (node is d.PrefixExpression &&
        !{'++', '--'}.contains(node.operator.lexeme)) {
      return '${node.operator.lexeme == '!' ? 'not ' : node.operator.lexeme}${expression(node.operand)}';
    }
    if (node is d.ConditionalExpression) {
      return '(if (${expression(node.condition)}): (${expression(node.thenExpression)}) else: (${expression(node.elseExpression)}))';
    }
    if (node is d.AwaitExpression) {
      return 'await ${expression(node.expression)}';
    }
    if (node is d.ListLiteral &&
        node.constKeyword == null &&
        node.typeArguments == null) {
      return '[${node.elements.map((e) => e is d.Expression ? expression(e) : unsupported()).join(', ')}]';
    }
    return unsupported();
  }
}
