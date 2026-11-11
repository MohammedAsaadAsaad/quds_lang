import 'ast.dart';
import 'constants.dart';
import 'source.dart';

class Symbol {
  Symbol(this.name, this.dartName, this.type,
      {this.mutable = false,
      this.constant = false,
      this.constantValue,
      FunctionDeclaration? function,
      this.classDeclaration,
      this.classCase,
      this.parameterTypes = const [],
      this.readonly = false});
  final String name, dartName;
  String type;
  final bool mutable, constant;
  final ConstValue? constantValue;
  final overloads = <FunctionDeclaration>[];
  final ClassDeclaration? classDeclaration;
  final ClassCase? classCase;
  final List<String> parameterTypes;
  final bool readonly;
  FunctionDeclaration? get function =>
      overloads.length == 1 ? overloads.single : null;

  Symbol withFunction(FunctionDeclaration? function) {
    if (function != null) overloads.add(function);
    return this;
  }
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
  final imports = <ImportDeclaration>[];
  final warnings = <CompilerException>[];
  final wrapAs = <Expression, String>{};
  final captures = <CaptureExpression, List<(Symbol outer, Symbol copy)>>{};
  final shapes = <Node, List<String>>{};
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
          FunctionDeclaration? function,
          bool readonly = false}) =>
      Symbol(
              name,
              name == 'main' && function != null ? 'main' : '_q${_nextName++}',
              type,
              mutable: mutable,
              constant: constant,
              constantValue: constantValue,
              function: function,
              readonly: readonly)
          .withFunction(function);
  String? _expected;
  String? _doType;
  int _doDepth = 0;
  Never error(String code, String message, Node node) =>
      throw CompilerException(code, message, node.span);
  void warn(String code, String message, Node node) {
    model.warnings.add(CompilerException(code, message, node.span));
  }

  SemanticModel analyze(Program program) {
    _global.symbols['print'] = Symbol('print', 'print', 'void');
    _global.symbols['missing'] =
        Symbol('missing', 'missing', 'Optional<Never>', constant: true);
    _global.symbols['present'] =
        Symbol('present', 'present', 'Optional', parameterTypes: const ['*']);
    _global.symbols['Ok'] =
        Symbol('Ok', 'Ok', 'Result', parameterTypes: const ['*']);
    _global.symbols['Error'] =
        Symbol('Error', 'Error', 'Result', parameterTypes: const ['*']);
    final functions = <FunctionDeclaration>[];
    final tests = <TestDeclaration>[];
    for (final statement in program.statements) {
      switch (statement) {
        case FunctionDeclaration():
          registerFunction(statement, _global, functions);
        case Binding(mode: BindingMode.constant):
          break;
        case ClassDeclaration():
          registerClass(statement);
        case ImportDeclaration():
          registerImport(statement);
        case TestDeclaration():
          tests.add(statement);
        default:
          fail(
              'Module scope permits functions, classes, imports, and const bindings',
              statement);
      }
    }
    // Initializers run in source order and see only consts already evaluated.
    // Function bodies then see every top-level const, same as other functions.
    for (final statement in program.statements) {
      if (statement is Binding && statement.mode == BindingMode.constant) {
        check(statement);
      }
    }
    for (final statement in functions) {
      analyzeFunction(statement);
    }
    for (final statement in tests) {
      check(statement);
    }
    for (final statement in program.statements) {
      if (statement is ClassDeclaration) {
        for (final method in statement.methods) {
          analyzeMethod(statement, method);
        }
      }
    }
    final main = _global.symbols['main']?.function;
    if (main != null &&
        (main.parameters.isNotEmpty ||
            !{'void', 'Future<void>'}
                .contains(model.declarations[main]!.type))) {
      fail('main must have no parameters and return void', main);
    }
    return model;
  }

  bool sameSignature(FunctionDeclaration a, FunctionDeclaration b) {
    if (a.parameters.length != b.parameters.length) return false;
    for (var i = 0; i < a.parameters.length; i++) {
      if (a.parameters[i].type != b.parameters[i].type) return false;
    }
    return true;
  }

  void registerFunction(FunctionDeclaration statement, _Scope scope,
      [List<FunctionDeclaration>? functions]) {
    final type = statement.returnType ??
        (statement.expressionBody == null
            ? (statement.isAsync ? 'Future<void>' : 'void')
            : '<infer>');
    final effective = statement.isAsync &&
            statement.returnType != null &&
            !statement.returnType!.startsWith('Future<')
        ? 'Future<${statement.returnType}>'
        : type;
    if (effective != '<infer>') validateType(effective, statement);
    final symbol = create(statement.name, effective, function: statement);
    model.declarations[statement] = symbol;
    final existing = scope.symbols[statement.name];
    if (existing == null) {
      scope.symbols[statement.name] = symbol;
    } else if (existing.overloads.isEmpty ||
        existing.classDeclaration != null) {
      fail('Duplicate name: ${statement.name}', statement);
    } else if (existing.overloads
        .any((other) => sameSignature(other, statement))) {
      fail('Duplicate function or unsupported overload: ${statement.name}',
          statement);
    } else {
      existing.overloads.add(statement);
    }
    functions?.add(statement);
  }

  void registerClass(ClassDeclaration statement) {
    if (_global.lookup(statement.name) != null) {
      fail('Duplicate name: ${statement.name}', statement);
    }
    final symbol = Symbol(statement.name, statement.name, statement.name,
        classDeclaration: statement);
    _global.symbols[statement.name] = symbol;
    model.declarations[statement] = symbol;
    for (final item in statement.cases) {
      if (_global.lookup(item.name) != null) {
        fail('Duplicate case: ${item.name}', item);
      }
      final caseSymbol = Symbol(item.name, item.name, statement.name,
          classDeclaration: statement, classCase: item);
      _global.symbols[item.name] = caseSymbol;
      model.declarations[item] = caseSymbol;
    }
    for (final field in statement.fields) {
      validateType(field.type, field, allowVoid: false);
    }
    for (final method in statement.methods) {
      if (statement.annotations.contains('macro') && method.name == 'define') {
        continue;
      }
      final type = method.returnType ??
          (method.expressionBody == null
              ? (method.isAsync ? 'Future<void>' : 'void')
              : '<infer>');
      final effective = method.isAsync &&
              method.returnType != null &&
              !method.returnType!.startsWith('Future<')
          ? 'Future<${method.returnType}>'
          : type;
      if (effective != '<infer>') validateType(effective, method);
      final symbol =
          Symbol(method.name, method.name, effective, function: method)
              .withFunction(method);
      model.declarations[method] = symbol;
    }
  }

  void analyzeMethod(ClassDeclaration type, FunctionDeclaration method) {
    if (type.annotations.contains('macro') && method.name == 'define') return;
    final saved = _scope;
    _scope = _Scope(_global);
    for (final field in type.fields) {
      if (model.declarations[field] == null) {
        model.declarations[field] =
            Symbol(field.name, field.name, field.type, mutable: field.mutable);
      }
      _scope.symbols[field.name] = model.declarations[field]!;
    }
    analyzeFunction(method);
    _scope = saved;
  }

  void registerImport(ImportDeclaration node) {
    model.imports.add(node);
    if (node.uri == 'dart:math' && node.prefix == null) {
      void external(String name, String type, List<String> parameters) {
        _global.symbols[name] =
            Symbol(name, name, type, parameterTypes: parameters);
      }

      external('sqrt', 'double', ['num']);
      external('sin', 'double', ['num']);
      external('cos', 'double', ['num']);
      external('min', 'num', ['num', 'num']);
      external('max', 'num', ['num', 'num']);
      _global.symbols['pi'] = Symbol('pi', 'pi', 'double',
          constant: true, constantValue: ConstDouble(3.141592653589793));
    } else if (node.uri.startsWith('dart:') ||
        node.uri.startsWith('package:') ||
        node.uri.endsWith('.quds')) {
      return;
    } else {
      fail('Unknown import: ${node.uri}', node);
    }
  }

  void validateType(String type, Node node, {bool allowVoid = true}) {
    if (type.startsWith('readonly ')) {
      validateType(type.substring(9), node, allowVoid: false);
      return;
    }
    if (type.contains(' | ')) {
      for (final part in type.split(' | ')) {
        validateType(part.trim(), node, allowVoid: false);
      }
      return;
    }
    if ({'int', 'double', 'num', 'bool', 'String', 'Null'}.contains(type)) {
      return;
    }
    if (allowVoid && type == 'void') return;
    if (type.endsWith('?')) {
      validateType(type.substring(0, type.length - 1), node, allowVoid: false);
      return;
    }
    if (type.startsWith('List<') && type.endsWith('>')) {
      validateType(type.substring(5, type.length - 1), node, allowVoid: false);
      return;
    }
    if (type.startsWith('Set<') && type.endsWith('>')) {
      validateType(type.substring(4, type.length - 1), node, allowVoid: false);
      return;
    }
    if (type.startsWith('Map<') && type.endsWith('>')) {
      final inner = type.substring(4, type.length - 1);
      final splitAt = inner.indexOf(',');
      if (splitAt < 0) fail('Unsupported type: $type', node);
      validateType(inner.substring(0, splitAt).trim(), node, allowVoid: false);
      validateType(inner.substring(splitAt + 1).trim(), node, allowVoid: false);
      return;
    }
    if (type.startsWith('Optional<') && type.endsWith('>')) {
      validateType(type.substring(9, type.length - 1), node, allowVoid: false);
      return;
    }
    if (type.startsWith('Result<') && type.endsWith('>')) {
      final inner = type.substring(7, type.length - 1);
      final splitAt = inner.indexOf(',');
      if (splitAt < 0) fail('Unsupported type: $type', node);
      validateType(inner.substring(0, splitAt).trim(), node, allowVoid: false);
      validateType(inner.substring(splitAt + 1).trim(), node, allowVoid: false);
      return;
    }
    if (type.startsWith('Future<') && type.endsWith('>')) {
      validateType(type.substring(7, type.length - 1), node, allowVoid: true);
      return;
    }
    if (type.startsWith('Range<') && type.endsWith('>')) {
      validateType(type.substring(6, type.length - 1), node, allowVoid: false);
      return;
    }
    if (type.startsWith('(') && type.contains('->')) return;
    if (type.startsWith('(') && type.endsWith(')')) {
      final inner = type.substring(1, type.length - 1);
      if (inner.isEmpty) return;
      for (final part in inner.split(',')) {
        validateType(part.trim(), node, allowVoid: false);
      }
      return;
    }
    if (_global.symbols[type]?.classDeclaration != null ||
        _global.symbols[type]?.classCase != null) {
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
    _scope = _Scope(savedScope);
    _function = function;
    final declared = model.declarations[function]!.type;
    _returnType = function.isAsync &&
            declared.startsWith('Future<') &&
            declared.endsWith('>')
        ? declared.substring(7, declared.length - 1)
        : declared;
    final parameterNames = <String>[];
    for (final parameter in function.parameters) {
      validateType(parameter.type, parameter, allowVoid: false);
      if (_scope.lookup(parameter.name) != null)
        fail('Parameter would shadow an existing symbol: ${parameter.name}',
            parameter);
      final symbol =
          create(parameter.name, parameter.type, mutable: parameter.mutable);
      _scope.symbols[parameter.name] = symbol;
      model.declarations[parameter] = symbol;
      if (parameter.defaultValue case final value?) {
        restrictDefault(value, parameterNames.toSet(),
            function.parameters.map((item) => item.name).toSet());
        final type = expression(value);
        if (!compatible(type, parameter.type)) {
          fail('Default type $type is incompatible with ${parameter.type}',
              value);
        }
      }
      parameterNames.add(parameter.name);
    }
    if (function.expressionBody case final value?) {
      final type = expression(value);
      if (_returnType == '<infer>') {
        model.declarations[function]!.type =
            function.isAsync ? 'Future<$type>' : type;
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
        final savedExpected = _expected;
        if (node.type != null) {
          _expected = node.type;
        } else if (existing != null &&
            node.mode == BindingMode.inferred &&
            node.type == null) {
          _expected = existing.type;
        }
        final type = expression(node.value);
        _expected = savedExpected;
        if (type == 'void')
          fail('A void expression cannot initialize a binding', node);
        if (existing != null &&
            node.mode == BindingMode.inferred &&
            node.type == null) {
          if (existing.readonly) {
            error('E307', 'A readonly reference cannot be mutated', node);
          }
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
        if (node.mode == BindingMode.shadow ||
            node.mode == BindingMode.shadowMutable) {
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
        var stored = target;
        var readonly = false;
        if (stored.startsWith('readonly ')) {
          readonly = true;
          stored = stored.substring(9);
        }
        if (stored.contains(' | ') && !type.contains(' | ')) {
          model.wrapAs[node.value] = stored;
        }
        ConstValue? constantValue;
        if (node.mode == BindingMode.constant) {
          constantValue = _constants.evaluate(node.value);
          checkConstShape(target, constantValue);
        }
        final symbol = create(node.name, stored,
            mutable: node.mode == BindingMode.mutable ||
                node.mode == BindingMode.shadowMutable,
            constant: node.mode == BindingMode.constant,
            constantValue: constantValue,
            readonly: readonly);
        _scope.symbols[node.name] = symbol;
        model.declarations[node] = symbol;
      case IfStatement():
        if (expression(node.condition) != 'bool')
          fail('if condition must be bool', node.condition);
        statements(node.thenBody, nested: true);
        statements(node.elseBody, nested: true);
      case ForStatement():
        final type = expression(node.iterable);
        final element = elementType(type, node.iterable);
        if (_scope.lookup(node.name) != null)
          fail('Loop binding would shadow ${node.name}', node);
        final symbol = create(node.name, element);
        model.declarations[node] = symbol;
        final saved = _scope;
        _scope = _Scope(saved);
        _scope.symbols[node.name] = symbol;
        _loopDepth++;
        statements(node.body);
        _loopDepth--;
        _scope = saved;
      case WhileStatement():
        if (expression(node.condition) != 'bool') {
          fail('while condition must be bool', node.condition);
        }
        _loopDepth++;
        statements(node.body, nested: true);
        _loopDepth--;
      case BreakStatement():
      case ContinueStatement():
        final label = node is BreakStatement
            ? node.label
            : (node as ContinueStatement).label;
        if (label == null && _loopDepth == 0) {
          fail(
              '${node is BreakStatement ? 'break' : 'continue'} is outside a loop',
              node);
        }
        if (label != null && !_labels.contains(label)) {
          fail('Unknown label: $label', node);
        }
      case LabelStatement():
        if (node.statement is! ForStatement &&
            node.statement is! WhileStatement) {
          fail('A label must be attached to a loop', node);
        }
        _labels.add(node.name);
        check(node.statement);
        _labels.removeLast();
      case MatchStatement():
        final matched = expression(node.value);
        if (node.arms.isEmpty) fail('match needs at least one arm', node);
        for (final arm in node.arms) {
          final saved = _scope;
          _scope = _Scope(saved);
          bindPattern(arm.pattern, matched);
          if (arm.guard != null && expression(arm.guard!) != 'bool') {
            fail('when guard must be bool', arm.guard!);
          }
          statements(arm.body);
          _scope = saved;
        }
        checkExhaustive(node, matched);
      case DestructureStatement():
        final type = expression(node.value);
        bindPattern(node.pattern, type, declare: true);
      case ReturnStatement():
        if (_function == null)
          fail('return is only valid inside a function', node);
        final type = node.value == null ? 'void' : expression(node.value!);
        if (!compatible(type, _returnType!))
          fail('Return type $type is incompatible with $_returnType', node);
      case ExpressionStatement():
        expression(node.expression);
        if (node.expression is! CallExpression &&
            node.expression is! WithExpression &&
            node.expression is! DoExpression) {
          fail('Only calls may be used as expression statements', node);
        }
      case ResultStatement():
        if (_doDepth == 0) {
          error('E106', 'result is only valid inside do', node);
        }
        final type = expression(node.value);
        if (_doType != null && _doType != type) {
          error(
              'E300', 'result type $type is incompatible with $_doType', node);
        }
        _doType = type;
      case CForStatement():
        final savedFor = _scope;
        _scope = _Scope(savedFor);
        check(node.init);
        if (expression(node.condition) != 'bool') {
          fail('for condition must be bool', node.condition);
        }
        if (node.step case final step?) {
          if (_zeroStep(step)) {
            error('E801', 'A loop step cannot be zero', step);
          }
          expression(step);
        }
        _loopDepth++;
        statements(node.body);
        _loopDepth--;
        _scope = savedFor;
      case RepeatStatement():
        if (node.body.isEmpty) fail('repeat needs a body', node);
        _loopDepth++;
        statements(node.body, nested: true);
        _loopDepth--;
        if (expression(node.condition) != 'bool') {
          fail('repeat condition must be bool', node.condition);
        }
      case TestDeclaration():
        model.declarations[node] = create(node.title, 'void');
        statements(node.body, nested: true);
      case FunctionDeclaration():
        registerFunction(node, _scope);
        analyzeFunction(node);
      case ClassDeclaration():
      case ImportDeclaration():
        fail('Classes and imports belong at the top level', node);
    }
  }

  final _labels = <String>[];
  var _loopDepth = 0;

  String elementType(String type, Node node) {
    if (type.startsWith('List<') && type.endsWith('>')) {
      return type.substring(5, type.length - 1);
    }
    if (type.startsWith('Set<') && type.endsWith('>')) {
      return type.substring(4, type.length - 1);
    }
    if (type.startsWith('Range<') && type.endsWith('>')) {
      return type.substring(6, type.length - 1);
    }
    fail('for-in requires a List, Set, or range', node);
  }

  void bindPattern(Pattern pattern, String type, {bool declare = false}) {
    switch (pattern) {
      case WildcardPattern():
        return;
      case TypedPattern():
        if (pattern.name != null) {
          final symbol = create(pattern.name!, pattern.type);
          _scope.symbols[pattern.name!] = symbol;
          model.declarations[pattern] = symbol;
        }
      case BindingPattern():
        final existing = _scope.lookup(pattern.name);
        if (existing?.classCase != null) {
          model.references[pattern] = existing!;
          return;
        }
        if (declare) {
          if (_scope.lookup(pattern.name) != null &&
              !_scope.symbols.containsKey(pattern.name)) {
            fail(
                'Binding would shadow ${pattern.name}; use shadow in an inner scope',
                pattern);
          }
          final symbol = create(pattern.name, type);
          _scope.symbols[pattern.name] = symbol;
          model.declarations[pattern] = symbol;
        } else {
          final symbol = create(pattern.name, type);
          _scope.symbols[pattern.name] = symbol;
          model.declarations[pattern] = symbol;
        }
      case LiteralPattern():
        expression(pattern.literal);
      case ListPattern():
        final element = elementType(type, pattern);
        for (final item in pattern.elements) {
          bindPattern(item, element, declare: declare);
        }
      case ConstructorPattern():
        if (pattern.typeName.isEmpty &&
            type.startsWith('(') &&
            type.endsWith(')')) {
          final parts = type
              .substring(1, type.length - 1)
              .split(',')
              .map((part) => part.trim())
              .toList();
          for (var i = 0; i < pattern.fields.length; i++) {
            bindPattern(pattern.fields[i], i < parts.length ? parts[i] : type,
                declare: declare);
          }
          return;
        }
        final declaration =
            pattern.typeName.isEmpty ? null : _global.symbols[pattern.typeName];
        final fields =
            declaration?.classCase?.fields ?? const <FieldDeclaration>[];
        for (var i = 0; i < pattern.fields.length; i++) {
          final fieldType = i < fields.length ? fields[i].type : type;
          bindPattern(pattern.fields[i], fieldType, declare: declare);
        }
    }
  }

  bool compatible(String from, String to) {
    if (from == to || from == '*') return true;
    if (to.startsWith('readonly ')) {
      final source = from.startsWith('readonly ') ? from.substring(9) : from;
      return compatible(source, to.substring(9));
    }
    if (from.startsWith('readonly ')) return false;
    if (to.contains(' | ')) {
      return to.split(' | ').any((arm) => compatible(from, arm.trim()));
    }
    if (from.contains(' | ')) {
      return from.split(' | ').every((arm) => compatible(arm.trim(), to));
    }
    if (to == 'num' && (from == 'int' || from == 'double')) return true;
    if (to.endsWith('?')) {
      final inner = to.substring(0, to.length - 1);
      return from == 'Null' || compatible(from, inner);
    }
    return false;
  }

  String unwrap(String type) =>
      type.endsWith('?') ? type.substring(0, type.length - 1) : type;
  bool numeric(String type) => {'int', 'double', 'num'}.contains(type);
  String lambda(Lambda node) {
    for (final parameter in node.parameters) {
      if (parameter.type == '<infer>') {
        parameterType(parameter, 'int');
      } else {
        validateType(parameter.type, parameter, allowVoid: false);
        parameterType(parameter, parameter.type);
      }
    }
    final saved = _scope;
    _scope = _Scope(saved);
    for (final parameter in node.parameters) {
      _scope.symbols[parameter.name] = model.declarations[parameter]!;
    }
    String type;
    if (node.expressionBody case final value?) {
      type = expression(value);
    } else {
      final savedFunction = _function;
      final savedReturn = _returnType;
      _returnType = 'void';
      statements(node.body!);
      type = 'void';
      for (final statement in node.body!) {
        if (statement is ReturnStatement && statement.value != null) {
          type = expression(statement.value!);
          break;
        }
      }
      _function = savedFunction;
      _returnType = savedReturn;
    }
    _scope = saved;
    final parameters =
        node.parameters.map((p) => model.declarations[p]!.type).join(', ');
    return '($parameters) -> $type';
  }

  void parameterType(Parameter parameter, String type) {
    final symbol = create(parameter.name, type, mutable: parameter.mutable);
    model.declarations[parameter] = symbol;
  }

  String member(MemberAccess node) {
    final raw = expression(node.object);
    final type = raw.startsWith('readonly ') ? raw.substring(9) : raw;
    final base = unwrap(type);
    if (node.name == 'length' &&
        (base == 'String' ||
            base.startsWith('List<') ||
            base.startsWith('Set<') ||
            base.startsWith('Map<'))) {
      return node.nullAware || type.endsWith('?') ? 'int?' : 'int';
    }
    final declaration = _global.symbols[base]?.classDeclaration;
    if (declaration != null) {
      for (final field in declaration.fields) {
        if (field.name == node.name) {
          final fieldType = field.type;
          return node.nullAware || type.endsWith('?')
              ? '$fieldType?'
              : fieldType;
        }
      }
      for (final method in declaration.methods) {
        if (method.name == node.name) {
          return functionType(method);
        }
      }
    }
    fail('No member ${node.name} on $type', node);
  }

  String index(IndexExpression node) {
    final raw = expression(node.object);
    final type = unwrap(raw.startsWith('readonly ') ? raw.substring(9) : raw);
    final indexType = expression(node.index);
    if (type.startsWith('List<')) {
      if (!compatible(indexType, 'int'))
        fail('List index must be int', node.index);
      return type.substring(5, type.length - 1);
    }
    if (type.startsWith('Map<')) {
      final inner = type.substring(4, type.length - 1);
      final splitAt = inner.indexOf(',');
      final key = inner.substring(0, splitAt).trim();
      final value = inner.substring(splitAt + 1).trim();
      if (!compatible(indexType, key)) fail('Map key type is $key', node.index);
      return value;
    }
    if (type == 'String') {
      if (!compatible(indexType, 'int'))
        fail('String index must be int', node.index);
      return 'String';
    }
    fail('Cannot index $type', node);
  }

  String mapLiteral(MapExpression node) {
    if (node.keys.isEmpty) fail('Empty maps require a type annotation', node);
    var key = expression(node.keys.first);
    var value = expression(node.values.first);
    for (var i = 1; i < node.keys.length; i++) {
      final nextKey = expression(node.keys[i]);
      final nextValue = expression(node.values[i]);
      if (nextKey != key || nextValue != value) {
        fail('Map entries must share key and value types', node.values[i]);
      }
    }
    return 'Map<$key, $value>';
  }

  String setLiteral(SetExpression node) {
    if (node.elements.isEmpty)
      fail('Empty sets require a type annotation', node);
    var type = elementTypeOf(node.elements.first, aware(node.nullAware, 0));
    for (var i = 1; i < node.elements.length; i++) {
      final next = elementTypeOf(node.elements[i], aware(node.nullAware, i));
      if (next != type)
        fail('Set elements must share a type', node.elements[i]);
    }
    return 'Set<$type>';
  }

  String record(RecordExpression node) {
    final types = node.fields.map(expression).join(', ');
    return '($types)';
  }

  String range(RangeExpression node) {
    final start = expression(node.start);
    final end = expression(node.end);
    if (!numeric(start) || !numeric(end))
      fail('Range bounds must be numeric', node);
    final type = start == 'int' && end == 'int' ? 'int' : 'num';
    return 'Range<$type>';
  }

  String awaitExpression(AwaitExpression node) {
    if (_function == null || !_function!.isAsync) {
      fail('await is only valid inside async', node);
    }
    final type = expression(node.operand);
    if (type.startsWith('Future<') && type.endsWith('>')) {
      return type.substring(7, type.length - 1);
    }
    return type;
  }

  String propagate(PropagateExpression node) {
    final type = expression(node.operand);
    if (!type.startsWith('Result<')) fail('? expects a Result', node);
    final inner = type.substring(7, type.length - 1);
    final splitAt = inner.indexOf(',');
    final value = inner.substring(0, splitAt).trim();
    final error = inner.substring(splitAt + 1).trim();
    final returned = _returnType ?? '';
    if (!returned.startsWith('Result<') &&
        !returned.startsWith('Future<Result<')) {
      fail('? requires the enclosing function to return Result', node);
    }
    if (returned.startsWith('Result<')) {
      final expected = returned.substring(7, returned.length - 1);
      final expectedError =
          expected.substring(expected.indexOf(',') + 1).trim();
      if (expectedError != error && expectedError != 'Object') {
        fail('Result error $error is incompatible with $expectedError', node);
      }
    }
    return value;
  }

  String binaryType(String left, String op, String right, Node node) {
    if (left == 'void' || right == 'void')
      fail('Void expressions cannot be operands', node);
    if (op == '??') {
      final inner = unwrap(left);
      if (compatible(right, inner)) return inner;
      if (compatible(right, left)) return left;
    }
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
      Lambda() => lambda(node),
      MemberAccess() => member(node),
      IndexExpression() => index(node),
      MapExpression() => mapLiteral(node),
      SetExpression() => setLiteral(node),
      RecordExpression() => record(node),
      RangeExpression() => range(node),
      AwaitExpression() => awaitExpression(node),
      PropagateExpression() => propagate(node),
      DoExpression() => doExpression(node),
      CaptureExpression() => captureExpression(node),
      ConversionExpression() => conversion(node),
      WithExpression() => withExpression(node),
      DotShorthand() => dotShorthand(node),
      AssignExpression() => assignExpression(node),
      NullAwareElement() => elementTypeOf(node.value, true),
      CollectionIf() => collectionIfType(node),
      CollectionFor() => collectionForType(node),
    };
    model.types[node] = type;
    return type;
  }

  String identifier(Identifier node) {
    final symbol = _scope.lookup(node.name);
    if (symbol == null) fail('Undefined symbol: ${node.name}', node);
    if (symbol.overloads.length > 1) {
      fail('Choose one overload with a call or a typed context', node);
    }
    model.references[node] = symbol;
    if (symbol.function != null) return functionType(symbol.function!);
    if (symbol.parameterTypes.isNotEmpty) {
      return '(${symbol.parameterTypes.join(', ')}) -> ${symbol.type}';
    }
    return symbol.readonly ? 'readonly ${symbol.type}' : symbol.type;
  }

  String functionType(FunctionDeclaration function) {
    final parameters = function.parameters.map((p) => p.type).join(', ');
    final returns =
        model.declarations[function]?.type ?? function.returnType ?? 'void';
    return '($parameters) -> $returns';
  }

  String unary(UnaryExpression node) {
    final type = expression(node.operand);
    if (node.operator == '!' && type.endsWith('?')) return unwrap(type);
    if (node.operator == 'not' && type == 'bool') return 'bool';
    if (node.operator != 'not' && node.operator != '!' && numeric(type)) {
      return type;
    }
    fail('Invalid unary operator ${node.operator} for $type', node);
  }

  String list(ListExpression node) {
    if (node.elements.isEmpty)
      fail('Empty lists require contextual typing (not supported yet)', node);
    var type = elementTypeOf(node.elements.first, aware(node.nullAware, 0));
    for (var i = 1; i < node.elements.length; i++) {
      final next = elementTypeOf(node.elements[i], aware(node.nullAware, i));
      if (numeric(type) && numeric(next) && type != next) {
        type = 'num';
      } else if (type != next) {
        fail('List elements must have a common supported static type',
            node.elements[i]);
      }
    }
    return 'List<$type>';
  }

  bool aware(List<bool> flags, int index) =>
      index < flags.length && flags[index];

  String elementTypeOf(Expression element, bool nullAware) {
    if (element is NullAwareElement) {
      return elementTypeOf(element.value, true);
    }
    if (element is CollectionIf) return collectionIfType(element);
    if (element is CollectionFor) return collectionForType(element);
    final type = expression(element);
    if (type == 'void') fail('List elements cannot be void', element);
    if (!nullAware) return type;
    if (type == 'Null') {
      final expected = _expected;
      if (expected != null &&
          expected.startsWith('List<') &&
          expected.endsWith('>')) {
        return expected.substring(5, expected.length - 1);
      }
      error('E302', 'A null-aware element needs an expected element type',
          element);
    }
    return type.endsWith('?') ? unwrap(type) : type;
  }

  String interpolation(InterpolatedString node) {
    for (final part in node.parts) {
      if (expression(part) == 'void')
        fail('Cannot interpolate a void expression', part);
    }
    return 'String';
  }

  bool isHole(Expression node) => node is Identifier && node.name == '_';

  String call(CallExpression node) {
    final callee = node.callee;
    if (callee is MemberAccess) {
      final rawObject = expression(callee.object);
      if (rawObject.startsWith('readonly ') &&
          _mutating.contains(callee.name)) {
        error('E307', 'A readonly reference cannot be mutated', callee);
      }
      final objectType = unwrap(rawObject.startsWith('readonly ')
          ? rawObject.substring(9)
          : rawObject);
      final declaration = _global.symbols[objectType]?.classDeclaration;
      final method = declaration?.methods
          .where((item) => item.name == callee.name)
          .toList();
      if (method == null || method.isEmpty) {
        fail('No method ${callee.name} on $objectType', callee);
      }
      final function = method.single;
      model.references[callee] = model.declarations[function]!;
      final returned = applyArguments(node, function.parameters, function);
      return model.declarations[function]!.type == '<infer>'
          ? returned
          : model.declarations[function]!.type;
    }
    if (callee is! Identifier) {
      final type = expression(callee);
      if (!type.contains('->')) fail('Value is not callable', callee);
      final arrow = type.lastIndexOf('->');
      final parameters = type.substring(1, type.indexOf(')'));
      final returns = type.substring(arrow + 3).trim();
      final expected = parameters.isEmpty
          ? <String>[]
          : parameters.split(',').map((item) => item.trim()).toList();
      if (node.arguments.length != expected.length) {
        fail('Callable expects ${expected.length} arguments', node);
      }
      for (var i = 0; i < expected.length; i++) {
        final argument = expression(node.arguments[i].value);
        if (expected[i].isNotEmpty && !compatible(argument, expected[i])) {
          fail('Argument type $argument is incompatible with ${expected[i]}',
              node.arguments[i]);
        }
      }
      model.argumentOrder[node] = List.generate(expected.length, (i) => i);
      return returns;
    }
    final symbol = _scope.lookup(callee.name);
    if (symbol == null) fail('Undefined function: ${callee.name}', callee);
    model.references[callee] = symbol;
    final args = node.arguments;
    if (symbol.dartName == 'print') {
      if (args.length != 1 || args.single.name != null) {
        fail('print expects one positional argument', node);
      }
      if (expression(args.single.value) == 'void') {
        fail('Cannot print a void expression', node);
      }
      return 'void';
    }
    if (symbol.classCase != null) {
      return constructCase(node, symbol);
    }
    if (symbol.classDeclaration != null && symbol.classCase == null) {
      return constructClass(node, symbol.classDeclaration!);
    }
    if (symbol.parameterTypes.isNotEmpty && symbol.overloads.isEmpty) {
      return externalCall(node, symbol);
    }
    if (symbol.function == null &&
        symbol.overloads.isEmpty &&
        symbol.parameterTypes.isEmpty &&
        symbol.type.contains('->')) {
      final arrow = symbol.type.lastIndexOf('->');
      final parameters = symbol.type.substring(1, symbol.type.indexOf(')'));
      final returns = symbol.type.substring(arrow + 3).trim();
      final expected = parameters.trim().isEmpty
          ? <String>[]
          : parameters.split(',').map((item) => item.trim()).toList();
      if (node.arguments.length != expected.length) {
        fail('Callable expects ${expected.length} arguments', node);
      }
      for (var i = 0; i < expected.length; i++) {
        final argument = expression(node.arguments[i].value);
        if (expected[i].isNotEmpty && !compatible(argument, expected[i])) {
          fail('Argument type $argument is incompatible with ${expected[i]}',
              node.arguments[i]);
        }
      }
      model.argumentOrder[node] = List.generate(expected.length, (i) => i);
      return returns;
    }
    final candidates = symbol.overloads.isEmpty && symbol.function != null
        ? [symbol.function!]
        : symbol.overloads;
    if (candidates.isEmpty) fail('${callee.name} is not callable', callee);
    FunctionDeclaration? selected;
    for (final candidate in candidates) {
      if (candidate.returnType == null &&
          model.declarations[candidate]?.type == '<infer>') {
        analyzeFunction(candidate);
      }
      if (argumentsMatch(node, candidate.parameters, commit: false)) {
        if (selected != null) fail('Ambiguous overload: ${callee.name}', node);
        selected = candidate;
      }
    }
    if (selected == null) fail('No overload matches this call', node);
    model.references[callee] = model.declarations[selected]!;
    return applyArguments(node, selected.parameters, selected);
  }

  String externalCall(CallExpression node, Symbol symbol) {
    if (symbol.name == 'present') {
      if (node.arguments.length != 1)
        fail('present expects one argument', node);
      final type = expression(node.arguments.single.value);
      model.argumentOrder[node] = [0];
      return 'Optional<$type>';
    }
    if (symbol.name == 'Ok' || symbol.name == 'Error') {
      if (node.arguments.length != 1)
        fail('${symbol.name} expects one value', node);
      final type = expression(node.arguments.single.value);
      model.argumentOrder[node] = [0];
      final returned = _returnType;
      if (returned != null && returned.startsWith('Result<')) {
        return returned.startsWith('Future<')
            ? returned.substring(7, returned.length - 1)
            : returned;
      }
      return symbol.name == 'Ok'
          ? 'Result<$type, Object>'
          : 'Result<Object, $type>';
    }
    if (node.arguments.length != symbol.parameterTypes.length) {
      fail('${symbol.name} expects ${symbol.parameterTypes.length} arguments',
          node);
    }
    for (var i = 0; i < symbol.parameterTypes.length; i++) {
      final type = expression(node.arguments[i].value);
      final expected = symbol.parameterTypes[i];
      if (expected != '*' && !compatible(type, expected)) {
        fail('Argument type $type is incompatible with $expected',
            node.arguments[i]);
      }
    }
    model.argumentOrder[node] = List.generate(node.arguments.length, (i) => i);
    return symbol.type;
  }

  String constructClass(CallExpression node, ClassDeclaration type) {
    final parameters = <Parameter>[];
    for (final field in type.fields) {
      parameters.add(Parameter(field.name, field.type, false, field.span,
          defaultValue: field.requiredField ? null : field.initializer));
    }
    applyArguments(node, parameters, null);
    return type.name;
  }

  String constructCase(CallExpression node, Symbol symbol) {
    final fields = symbol.classCase!.fields;
    final parameters = [
      for (final field in fields)
        Parameter(field.name, field.type, false, field.span)
    ];
    applyArguments(node, parameters, null);
    return symbol.classDeclaration!.name;
  }

  bool argumentsMatch(CallExpression node, List<Parameter> parameters,
      {required bool commit}) {
    final order = List<int>.filled(parameters.length, -1);
    var positional = 0;
    var named = false;
    for (var i = 0; i < node.arguments.length; i++) {
      final argument = node.arguments[i];
      int target;
      if (argument.name == null) {
        if (named) return false;
        target = positional++;
      } else {
        named = true;
        target = parameters.indexWhere((p) => p.name == argument.name);
        if (target < 0) return false;
      }
      if (target >= parameters.length || order[target] != -1) return false;
      if (isHole(argument.value)) {
        order[target] = i;
        continue;
      }
      final type = expression(argument.value);
      if (!compatible(type, parameters[target].type)) return false;
      order[target] = i;
    }
    for (var i = 0; i < parameters.length; i++) {
      if (order[i] == -1 && parameters[i].defaultValue == null) {
        final hole = node.arguments.any((a) => isHole(a.value));
        if (!hole) return false;
      }
    }
    return true;
  }

  void restrictDefault(Expression node, Set<String> earlier, Set<String> all) {
    switch (node) {
      case Identifier()
          when all.contains(node.name) && !earlier.contains(node.name):
        fail('Default arguments may refer only to earlier parameters', node);
      case UnaryExpression():
        restrictDefault(node.operand, earlier, all);
      case BinaryExpression():
        restrictDefault(node.left, earlier, all);
        restrictDefault(node.right, earlier, all);
      case CallExpression():
        restrictDefault(node.callee, earlier, all);
        for (final argument in node.arguments) {
          restrictDefault(argument.value, earlier, all);
        }
      default:
        break;
    }
  }

  String applyArguments(CallExpression node, List<Parameter> parameters,
      FunctionDeclaration? function) {
    if (function != null &&
        parameters.any((parameter) => parameter.defaultValue != null)) {
      analyzeFunction(function);
    }
    if (!argumentsMatch(node, parameters, commit: true)) {
      fail('No overload matches this call', node);
    }
    final order = List<int>.filled(parameters.length, -1);
    var positional = 0;
    var named = false;
    final holes = <int>[];
    for (var i = 0; i < node.arguments.length; i++) {
      final argument = node.arguments[i];
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
      if (order[target] != -1) {
        fail('Duplicate argument: ${parameters[target].name}', argument);
      }
      if (isHole(argument.value)) {
        holes.add(target);
        order[target] = i;
        continue;
      }
      final type = expression(argument.value);
      if (!compatible(type, parameters[target].type)) {
        fail(
            'Argument type $type is incompatible with ${parameters[target].type}',
            argument);
      }
      order[target] = i;
    }
    for (var i = 0; i < parameters.length; i++) {
      if (order[i] != -1) continue;
      final fallback = parameters[i].defaultValue;
      if (fallback == null) fail('Missing required argument', node);
      final type = model.types[fallback] ?? expression(fallback);
      if (!compatible(type, parameters[i].type)) {
        fail('Default type $type is incompatible with ${parameters[i].type}',
            fallback);
      }
    }
    model.argumentOrder[node] = order;
    if (holes.isNotEmpty) {
      final types = holes.map((index) => parameters[index].type).join(', ');
      final returned = function == null
          ? 'void'
          : (model.declarations[function]?.type ??
              function.returnType ??
              'void');
      return '($types) -> $returned';
    }
    if (function != null && model.declarations[function]!.type == '<infer>') {
      analyzeFunction(function);
    }
    return function == null ? 'void' : model.declarations[function]!.type;
  }

  static const _mutating = {
    'add',
    'addAll',
    'remove',
    'removeAt',
    'removeLast',
    'removeWhere',
    'retainWhere',
    'clear',
    'insert',
    'insertAll',
    'putIfAbsent',
    'update',
    'updateAll',
    'shuffle',
    'sort',
    'fillRange',
    'replaceRange',
    'setAll',
    'removeRange',
  };

  String doExpression(DoExpression node) {
    final saved = _doType;
    _doType = null;
    _doDepth++;
    for (final statement in node.body) {
      check(statement);
    }
    _doDepth--;
    final type = _doType;
    _doType = saved;
    if (type == null) error('E109', 'do must finish with result', node);
    return type;
  }

  String captureExpression(CaptureExpression node) {
    final saved = _scope;
    _scope = _Scope(saved);
    final copies = <(Symbol, Symbol)>[];
    for (final name in node.names) {
      final outer = saved.lookup(name);
      if (outer == null) fail('Undefined symbol: $name', node);
      final copy = create(name, outer.type);
      _scope.symbols[name] = copy;
      copies.add((outer, copy));
    }
    model.captures[node] = copies;
    final type = expression(node.body);
    _scope = saved;
    return '() -> $type';
  }

  String conversion(ConversionExpression node) {
    final source =
        unwrap(expression(node.operand).replaceFirst('readonly ', ''));
    final target = node.type.endsWith('?')
        ? node.type.substring(0, node.type.length - 1)
        : node.type;
    validateType(target, node, allowVoid: false);
    if (source != target && !_convertible(source, target)) {
      error('E300', 'Cannot convert $source to $target', node);
    }
    if (!node.safe) return node.type;
    return node.type.endsWith('?') ? node.type : '${node.type}?';
  }

  bool _convertible(String from, String to) {
    const kinds = {'int', 'double', 'num', 'String', 'bool'};
    return kinds.contains(from) && kinds.contains(to);
  }

  String withExpression(WithExpression node) {
    final type = expression(node.receiver);
    if (type.startsWith('readonly ')) {
      error('E307', 'A readonly reference cannot be mutated', node);
    }
    final bare = unwrap(type);
    final declaration = _global.symbols[bare]?.classDeclaration;
    if (declaration == null) {
      error('E300', 'with requires a class value', node);
    }
    model.shapes[node] = declaration.fields.map((field) => field.name).toList();
    for (var i = 0; i < node.fields.length; i++) {
      final fields =
          declaration.fields.where((field) => field.name == node.fields[i]);
      if (fields.length != 1) {
        error('E300', 'No field ${node.fields[i]} on $bare', node);
      }
      final value = expression(node.values[i]);
      if (!compatible(value, fields.single.type)) {
        error(
            'E300', 'Cannot set ${node.fields[i]} from $value', node.values[i]);
      }
    }
    return type;
  }

  String dotShorthand(DotShorthand node) {
    final expected = _expected;
    if (expected == null) {
      error('E302', 'Dot shorthand needs one expected type', node);
    }
    var bare =
        expected.startsWith('readonly ') ? expected.substring(9) : expected;
    if (bare.endsWith('?')) bare = bare.substring(0, bare.length - 1);
    final symbol = _global.symbols[bare];
    final declaration = symbol?.classDeclaration;
    if (declaration == null) {
      error('E302', 'No type $bare for .${node.name}', node);
    }
    if (node.name == 'new') {
      if (node.arguments != null) {
        for (final argument in node.arguments!) {
          if (argument.name == null) {
            error('E500', 'Dot shorthand constructor uses named fields',
                argument);
          }
          final field = declaration.fields
              .where((item) => item.name == argument.name)
              .toList();
          if (field.length != 1) {
            error('E500', 'Unknown field ${argument.name}', argument);
          }
          final saved = _expected;
          _expected = field.single.type;
          final type = expression(argument.value);
          _expected = saved;
          if (!compatible(type, field.single.type)) {
            error('E300', 'Cannot initialize ${argument.name} with $type',
                argument);
          }
        }
      }
      return bare;
    }
    final matched =
        declaration.cases.where((item) => item.name == node.name).toList();
    if (matched.length != 1) {
      error('E302', 'No member ${node.name} on $bare', node);
    }
    return bare;
  }

  String assignExpression(AssignExpression node) {
    final symbol = _scope.lookup(node.name);
    if (symbol == null) fail('Undefined symbol: ${node.name}', node);
    if (symbol.readonly) {
      error('E307', 'A readonly reference cannot be mutated', node);
    }
    if (!symbol.mutable) {
      fail('Cannot assign immutable binding ${node.name}', node);
    }
    model.references[node] = symbol;
    final type = expression(node.value);
    final result = node.operator == '='
        ? type
        : binaryType(symbol.type, node.operator[0], type, node);
    if (!compatible(result, symbol.type)) {
      fail('Cannot assign $result to ${symbol.type}', node);
    }
    return symbol.type;
  }

  String collectionIfType(CollectionIf node) {
    if (expression(node.condition) != 'bool') {
      fail('collection if condition must be bool', node.condition);
    }
    if (node.thenElements.isEmpty) fail('collection if needs an element', node);
    final type = groupElementType(node.thenElements);
    if (node.elseElements.isNotEmpty) {
      final other = groupElementType(node.elseElements);
      if (other != type) {
        fail('List elements must have a common supported static type', node);
      }
    }
    return type;
  }

  String collectionForType(CollectionFor node) {
    final iterable = expression(node.iterable);
    final element = elementType(iterable, node.iterable);
    if (_scope.lookup(node.name) != null) {
      fail('Loop binding would shadow ${node.name}', node);
    }
    if (node.body.isEmpty) fail('collection for needs an element', node);
    final symbol = create(node.name, element);
    model.declarations[node] = symbol;
    final saved = _scope;
    _scope = _Scope(saved);
    _scope.symbols[node.name] = symbol;
    final type = groupElementType(node.body);
    _scope = saved;
    return type;
  }

  String groupElementType(List<Expression> elements) {
    var type = elementTypeOf(elements.first, false);
    for (var i = 1; i < elements.length; i++) {
      final next = elementTypeOf(elements[i], false);
      if (numeric(type) && numeric(next) && type != next) {
        type = 'num';
      } else if (type != next) {
        fail('List elements must have a common supported static type',
            elements[i]);
      }
    }
    return type;
  }

  bool _zeroStep(Expression step) {
    if (step is Literal && step.value == 0) return true;
    if (step is AssignExpression &&
        (step.operator == '+=' || step.operator == '-=') &&
        step.value is Literal &&
        (step.value as Literal).value == 0) {
      return true;
    }
    return false;
  }

  void checkExhaustive(MatchStatement node, String matched) {
    final universe = matched.contains(' | ')
        ? matched.split(' | ').map((part) => part.trim()).toSet()
        : _global.symbols[matched]?.classDeclaration?.kind == 'sealedType'
            ? _global.symbols[matched]!.classDeclaration!.cases
                .map((item) => item.name)
                .toSet()
            : null;
    if (universe == null || universe.isEmpty) return;
    final covered = <String>{};
    var closed = false;
    for (final arm in node.arms) {
      if (closed) {
        error('E313', 'Unreachable match arm', arm.pattern);
      }
      final names = _covered(arm.pattern, universe);
      if (arm.guard != null) continue;
      if (names == null) {
        covered.addAll(universe);
        closed = true;
      } else {
        covered.addAll(names);
        if (covered.containsAll(universe)) closed = true;
      }
    }
    if (!covered.containsAll(universe)) {
      warn('W001', 'match does not cover every case', node);
    }
  }

  Set<String>? _covered(Pattern pattern, Set<String> universe) {
    return switch (pattern) {
      WildcardPattern() => null,
      TypedPattern() => {pattern.type},
      BindingPattern() =>
        model.references[pattern]?.classCase == null ? null : {pattern.name},
      ConstructorPattern() =>
        pattern.typeName.isEmpty ? null : {pattern.typeName},
      LiteralPattern() || ListPattern() => <String>{},
    };
  }
}
