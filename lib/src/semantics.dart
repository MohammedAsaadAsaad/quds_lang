import 'ast.dart';
import 'constants.dart';
import 'source.dart';

class Symbol {
  Symbol(this.name, this.dartName, this.type,
      {this.mutable = false,
      this.constant = false,
      this.constantValue,
      this.function});
  final String name, dartName;
  String type;
  final bool mutable, constant;
  final ConstValue? constantValue;
  final FunctionDeclaration? function;
}

class _Scope {
  _Scope([this.parent]);
  final _Scope? parent;
  final symbols = <String, Symbol>{};
  Symbol? lookup(String name) => symbols[name] ?? parent?.lookup(name);
}

class SemanticModel {
  final references = <Node, Symbol>{};
  final declarations = <Node, Symbol>{};
  final assignments = <Binding>{};
  final types = <Expression, String>{};

  /// Parameter order expressed as indices into source-order arguments.
  final argumentOrder = <CallExpression, List<int>>{};

  /// Const expressions that were evaluated. Short-circuited operands are absent.
  final constants = <Expression, ConstValue>{};
}

class Analyzer {
  final model = SemanticModel();
  final _global = _Scope();
  late _Scope _scope = _global;
  final _checked = <FunctionDeclaration>{};
  final _checking = <FunctionDeclaration>{};
  FunctionDeclaration? _function;
  String? _returnType;
  int _nextName = 0;
  late final _constants = ConstantEvaluator(
    constants: model.constants,
    constantValueOf: (node) => model.references[node]?.constantValue,
    typeOf: (node) => model.types[node],
    fail: fail,
  );
  Never fail(String message, Node node) =>
      throw CompilerException('Q200', message, node.span);
  Symbol create(String name, String type,
          {bool mutable = false,
          bool constant = false,
          ConstValue? constantValue,
          FunctionDeclaration? function}) =>
      Symbol(
          name,
          name == 'main' && function != null ? 'main' : '_q${_nextName++}',
          type,
          mutable: mutable,
          constant: constant,
          constantValue: constantValue,
          function: function);
  SemanticModel analyze(Program program) {
    _global.symbols['print'] = Symbol('print', 'print', 'void');
    for (final statement in program.statements) {
      if (statement is! FunctionDeclaration)
        fail('MVP-0 permits only function declarations at module scope',
            statement);
      if (_global.lookup(statement.name) != null)
        fail('Duplicate function or unsupported overload: ${statement.name}',
            statement);
      final type = statement.returnType ??
          (statement.expressionBody == null ? 'void' : '<infer>');
      if (type != '<infer>') validateType(type, statement);
      final symbol = create(statement.name, type, function: statement);
      _global.symbols[statement.name] = symbol;
      model.declarations[statement] = symbol;
    }
    for (final statement in program.statements.cast<FunctionDeclaration>()) {
      analyzeFunction(statement);
    }
    final main = _global.symbols['main']?.function;
    if (main != null &&
        (main.parameters.isNotEmpty ||
            model.declarations[main]!.type != 'void')) {
      fail('main must have no parameters and return void in MVP-0', main);
    }
    return model;
  }

  void validateType(String type, Node node, {bool allowVoid = true}) {
    if ({'int', 'double', 'num', 'bool', 'String', 'Null'}.contains(type))
      return;
    if (allowVoid && type == 'void') return;
    if (type.startsWith('List<') && type.endsWith('>')) {
      validateType(type.substring(5, type.length - 1), node, allowVoid: false);
      return;
    }
    fail('Unsupported type: $type', node);
  }

  void analyzeFunction(FunctionDeclaration function) {
    if (_checked.contains(function)) return;
    if (!_checking.add(function)) {
      if (model.declarations[function]!.type == '<infer>')
        fail('Recursive expression functions require a return annotation',
            function);
      return;
    }
    final savedScope = _scope,
        savedFunction = _function,
        savedReturn = _returnType;
    _scope = _Scope(_global);
    _function = function;
    _returnType = model.declarations[function]!.type;
    for (final parameter in function.parameters) {
      validateType(parameter.type, parameter, allowVoid: false);
      if (_scope.lookup(parameter.name) != null)
        fail('Parameter would shadow an existing symbol: ${parameter.name}',
            parameter);
      final symbol =
          create(parameter.name, parameter.type, mutable: parameter.mutable);
      _scope.symbols[parameter.name] = symbol;
      model.declarations[parameter] = symbol;
    }
    if (function.expressionBody case final value?) {
      final type = expression(value);
      if (_returnType == '<infer>') {
        model.declarations[function]!.type = type;
      } else if (!compatible(type, _returnType!)) {
        fail('Return type $type is incompatible with $_returnType', value);
      }
    } else {
      statements(function.body!);
      if (_returnType != 'void' && !returns(function.body!))
        fail(
            'Non-void function must explicitly return on every path', function);
    }
    _scope = savedScope;
    _function = savedFunction;
    _returnType = savedReturn;
    _checking.remove(function);
    _checked.add(function);
  }

  bool returns(List<Statement> body) {
    for (final statement in body) {
      if (statement is ReturnStatement) return true;
      if (statement is IfStatement &&
          returns(statement.thenBody) &&
          returns(statement.elseBody)) return true;
    }
    return false;
  }

  void statements(List<Statement> body, {bool nested = false}) {
    final saved = _scope;
    if (nested) _scope = _Scope(_scope);
    for (final statement in body) {
      check(statement);
    }
    _scope = saved;
  }

  void check(Statement node) {
    switch (node) {
      case Binding():
        final existing = _scope.lookup(node.name);
        final type = expression(node.value);
        if (type == 'void')
          fail('A void expression cannot initialize a binding', node);
        if (existing != null &&
            node.mode == BindingMode.inferred &&
            node.type == null) {
          if (!existing.mutable)
            fail('Cannot assign immutable binding ${node.name}', node);
          final result = node.operator == '='
              ? type
              : binaryType(existing.type, node.operator[0], type, node);
          if (!compatible(result, existing.type))
            fail('Cannot assign $result to ${existing.type}', node);
          model.references[node] = existing;
          model.assignments.add(node);
          return;
        }
        if (node.operator != '=')
          fail(
              'Compound assignment requires an existing mutable binding', node);
        if (node.mode == BindingMode.shadow) {
          if (existing == null || _scope.symbols.containsKey(node.name))
            fail('shadow requires a binding in an outer scope', node);
        } else if (existing != null) {
          fail(
              'Binding would shadow ${node.name}; use shadow in an inner scope',
              node);
        }
        final target = node.type ?? type;
        validateType(target, node, allowVoid: false);
        if (!compatible(type, target))
          fail('Cannot initialize $target with $type', node);
        ConstValue? constantValue;
        if (node.mode == BindingMode.constant) {
          constantValue = _constants.evaluate(node.value);
          checkConstShape(target, constantValue);
        }
        final symbol = create(node.name, target,
            mutable: node.mode == BindingMode.mutable,
            constant: node.mode == BindingMode.constant,
            constantValue: constantValue);
        _scope.symbols[node.name] = symbol;
        model.declarations[node] = symbol;
      case IfStatement():
        if (expression(node.condition) != 'bool')
          fail('if condition must be bool', node.condition);
        statements(node.thenBody, nested: true);
        statements(node.elseBody, nested: true);
      case ForStatement():
        final type = expression(node.iterable);
        if (!type.startsWith('List<'))
          fail('for-in currently requires a List', node.iterable);
        if (_scope.lookup(node.name) != null)
          fail('Loop binding would shadow ${node.name}', node);
        final symbol = create(node.name, type.substring(5, type.length - 1));
        model.declarations[node] = symbol;
        final saved = _scope;
        _scope = _Scope(saved);
        _scope.symbols[node.name] = symbol;
        statements(node.body);
        _scope = saved;
      case ReturnStatement():
        if (_function == null)
          fail('return is only valid inside a function', node);
        final type = node.value == null ? 'void' : expression(node.value!);
        if (!compatible(type, _returnType!))
          fail('Return type $type is incompatible with $_returnType', node);
      case ExpressionStatement():
        expression(node.expression);
        if (node.expression is! CallExpression)
          fail('Only calls may be used as expression statements', node);
      case FunctionDeclaration():
        fail('Nested function declarations are not supported yet', node);
    }
  }

  bool compatible(String from, String to) =>
      from == to || to == 'num' && (from == 'int' || from == 'double');
  bool numeric(String type) => {'int', 'double', 'num'}.contains(type);
  String binaryType(String left, String op, String right, Node node) {
    if (left == 'void' || right == 'void')
      fail('Void expressions cannot be operands', node);
    if (op == '==' || op == '!=') return 'bool';
    if (op == 'and' || op == 'or') {
      if (left == 'bool' && right == 'bool') return 'bool';
    } else if (op == '+' && left == 'String' && right == 'String') {
      return 'String';
    } else if (numeric(left) && numeric(right)) {
      if ({'<', '<=', '>', '>='}.contains(op)) return 'bool';
      if (op == '/') return 'double';
      if (left == 'num' || right == 'num') return 'num';
      return left == 'double' || right == 'double' ? 'double' : 'int';
    }
    fail('Operator $op is not defined for $left and $right', node);
  }

  String expression(Expression node) {
    final type = switch (node) {
      Literal() => switch (node.value) {
          int() => 'int',
          double() => 'double',
          bool() => 'bool',
          String() => 'String',
          null => 'Null',
          _ => throw StateError('Unknown literal'),
        },
      Identifier() => identifier(node),
      UnaryExpression() => unary(node),
      BinaryExpression() => binaryType(
          expression(node.left), node.operator, expression(node.right), node),
      ListExpression() => list(node),
      CallExpression() => call(node),
      InterpolatedString() => interpolation(node),
    };
    model.types[node] = type;
    return type;
  }

  String identifier(Identifier node) {
    final symbol = _scope.lookup(node.name);
    if (symbol == null) fail('Undefined symbol: ${node.name}', node);
    if (symbol.function != null ||
        node.name == 'print' && symbol.dartName == 'print') {
      fail('Function values are not supported yet; invoke the function', node);
    }
    model.references[node] = symbol;
    return symbol.type;
  }

  String unary(UnaryExpression node) {
    final type = expression(node.operand);
    if (node.operator == 'not' && type == 'bool') return 'bool';
    if (node.operator != 'not' && numeric(type)) return type;
    fail('Invalid unary operator ${node.operator} for $type', node);
  }

  String list(ListExpression node) {
    if (node.elements.isEmpty)
      fail('Empty lists require contextual typing (not supported yet)', node);
    var type = expression(node.elements.first);
    if (type == 'void') fail('List elements cannot be void', node);
    for (final element in node.elements.skip(1)) {
      final next = expression(element);
      if (numeric(type) && numeric(next) && type != next) {
        type = 'num';
      } else if (type != next) {
        fail('List elements must have a common supported static type', element);
      }
    }
    return 'List<$type>';
  }

  String interpolation(InterpolatedString node) {
    for (final part in node.parts) {
      if (expression(part) == 'void')
        fail('Cannot interpolate a void expression', part);
    }
    return 'String';
  }

  String call(CallExpression node) {
    final callee = node.callee;
    if (callee is! Identifier)
      fail('Only statically named functions are supported', callee);
    final symbol = _scope.lookup(callee.name);
    if (symbol == null) fail('Undefined function: ${callee.name}', callee);
    model.references[callee] = symbol;
    final args = node.arguments;
    if (symbol.dartName == 'print') {
      if (args.length != 1 || args.single.name != null)
        fail('print expects one positional argument', node);
      if (expression(args.single.value) == 'void')
        fail('Cannot print a void expression', node);
      return 'void';
    }
    final function = symbol.function;
    if (function == null) fail('${callee.name} is not callable', callee);
    if (symbol.type == '<infer>') analyzeFunction(function);
    final parameters = function.parameters;
    final order = List<int>.filled(parameters.length, -1);
    var positional = 0;
    var named = false;
    for (var i = 0; i < args.length; i++) {
      final argument = args[i];
      int target;
      if (argument.name == null) {
        if (named)
          fail('Positional arguments must precede named arguments', argument);
        target = positional++;
      } else {
        named = true;
        target = parameters.indexWhere((p) => p.name == argument.name);
        if (target < 0) fail('Unknown argument: ${argument.name}', argument);
      }
      if (target >= parameters.length) fail('Too many arguments', argument);
      if (order[target] != -1)
        fail('Duplicate argument: ${parameters[target].name}', argument);
      final type = expression(argument.value);
      if (!compatible(type, parameters[target].type))
        fail(
            'Argument type $type is incompatible with ${parameters[target].type}',
            argument);
      order[target] = i;
    }
    if (order.contains(-1)) fail('Missing required argument', node);
    model.argumentOrder[node] = order;
    return symbol.type;
  }
}
