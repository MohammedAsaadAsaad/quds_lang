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
      this.readonly = false,
      this.late = false,
      this.lateOpen = false,
      this.reactive = ''});
  final String name, dartName;
  String type;
  final bool mutable, constant, late, lateOpen;

  /// Empty, `state`, or `computed`.
  final String reactive;
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
  final enumNames = <String>{};
  final traces = <CatchClause, Symbol>{};
  final variadicArguments = <CallExpression, List<int>>{};
  final implicitThis = <Identifier>{};
  final extensions = <ExtensionDeclaration>[];
  final aliases = <String, String>{};

  String resolve(String type) {
    var current = type;
    final seen = <String>{};
    while (seen.add(current)) {
      var next = current;
      for (final entry in aliases.entries) {
        next = next.replaceAll(
            RegExp('\\b${RegExp.escape(entry.key)}\\b'), entry.value);
      }
      if (next == current) return current;
      current = next;
    }
    return type;
  }

  final wrapAs = <Expression, String>{};
  final captures = <CaptureExpression, List<(Symbol outer, Symbol copy)>>{};
  final shapes = <Node, List<String>>{};
  final skipped = <Statement>{};
  final parts = <PartDirective>[];
  final asyncDefers = <DeferStatement>{};
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
      throw CompilerException(registryCode(message), message, node.span);
  Symbol create(String name, String type,
          {bool mutable = false,
          bool constant = false,
          ConstValue? constantValue,
          FunctionDeclaration? function,
          bool readonly = false,
          bool late = false,
          bool lateOpen = false,
          String reactive = ''}) =>
      Symbol(
              name,
              name == 'main' && function != null ? 'main' : '_q${_nextName++}',
              type,
              mutable: mutable,
              constant: constant,
              constantValue: constantValue,
              function: function,
              readonly: readonly,
              late: late,
              lateOpen: lateOpen,
              reactive: reactive)
          .withFunction(function);
  String? _expected;
  String? _thisType;
  final _fieldSymbols = <Symbol>{};
  var _readonlyMethod = false;
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
    for (final statement in program.statements) {
      if (statement is AliasDeclaration) {
        model.aliases[statement.name] = statement.target;
      }
    }
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
        case ExtensionDeclaration():
          registerExtension(statement);
        case AliasDeclaration():
          break;
        case ImportDeclaration():
          registerImport(statement);
        case PartDirective():
          model.parts.add(statement);
        case WhenStatement():
          registerWhen(statement);
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
        checkShape(statement);
        checkRequirements(statement);
        for (final method in statement.methods) {
          analyzeMethod(statement, method);
        }
        for (final constructor in statement.constructors) {
          analyzeConstructor(statement, constructor);
        }
        for (final property in statement.properties) {
          analyzeProperty(statement, property);
        }
      }
      if (statement is ExtensionDeclaration) {
        for (final method in statement.methods) {
          analyzeExtension(statement, method);
        }
      }
    }
    if (model.parts.any((part) => part.of) &&
        model.parts.any((part) => !part.of)) {
      final mismatched = model.parts.firstWhere((part) => part.of);
      error('E903', 'part of does not match the library', mismatched);
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
      if (a.parameters[i].variadic != b.parameters[i].variadic) return false;
      if (a.parameters[i].type != b.parameters[i].type) return false;
    }
    return true;
  }

  void registerFunction(FunctionDeclaration statement, _Scope scope,
      [List<FunctionDeclaration>? functions]) {
    final type = statement.returnType ??
        (statement.expressionBody == null
            ? (statement.generator == 'sync'
                ? 'void'
                : statement.generator == 'async' || statement.isAsync
                    ? 'void'
                    : 'void')
            : '<infer>');
    final effective = statement.generator == 'sync'
        ? (statement.returnType == null
            ? '<infer>'
            : 'Iterable<${statement.returnType}>')
        : statement.generator == 'async'
            ? (statement.returnType == null
                ? '<infer>'
                : 'Stream<${statement.returnType}>')
            : statement.isAsync &&
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
    if (statement.kind == 'enum') model.enumNames.add(statement.name);
    _global.symbols[statement.name] = symbol;
    model.declarations[statement] = symbol;
    for (final item in statement.cases) {
      if (_global.lookup(item.name) != null) {
        fail('Duplicate case: ${item.name}', item);
      }
      final dartName = statement.kind == 'enum'
          ? '${statement.name}.${item.name}'
          : item.name;
      final caseSymbol = Symbol(item.name, dartName, statement.name,
          classDeclaration: statement, classCase: item);
      _global.symbols[item.name] = caseSymbol;
      model.declarations[item] = caseSymbol;
    }
    for (final field in statement.fields) {
      if (field.type == '<infer>') continue;
      validateType(field.type, field, allowVoid: false);
    }
    for (final field in statement.fields.where((item) => item.isStatic)) {
      analyzeStaticField(field);
    }
    for (final method in statement.methods) {
      if (statement.annotations.contains('macro') && method.name == 'define') {
        continue;
      }
      final declared = method.isOperator && method.returnType == null
          ? (const {'==', '<', '<=', '>', '>='}.contains(method.name)
              ? 'bool'
              : statement.name)
          : method.returnType;
      final type = declared ??
          (method.expressionBody == null
              ? (method.isAsync ? 'Future<void>' : 'void')
              : '<infer>');
      final effective = method.isAsync &&
              method.returnType != null &&
              !method.returnType!.startsWith('Future<')
          ? 'Future<${method.returnType}>'
          : type;
      if (effective != '<infer>') validateType(effective, method);
      final dartName = method.isOperator
          ? method.name
          : method.visibility == 'private' && !method.name.startsWith('_')
              ? '_${method.name}'
              : method.name;
      final symbol = Symbol(method.name, dartName, effective, function: method)
          .withFunction(method);
      model.declarations[method] = symbol;
    }
  }

  void registerExtension(ExtensionDeclaration statement) {
    model.extensions.add(statement);
    for (final method in statement.methods) {
      final type = method.returnType ??
          (method.expressionBody == null ? 'void' : '<infer>');
      if (type != '<infer>') validateType(type, method);
      final symbol = Symbol(method.name, method.name, type, function: method)
          .withFunction(method);
      model.declarations[method] = symbol;
    }
  }

  void checkShape(ClassDeclaration type) {
    if (type.modifiers.contains('singleton')) {
      for (final field in type.fields) {
        if (field.initializer == null) {
          error('E704', 'A singleton field is not initialized', field);
        }
      }
    }
    if (type.kind == 'value' || type.modifiers.contains('value')) {
      for (final field in type.fields) {
        if (field.mutable) {
          error('E706', 'A value class field cannot be var', field);
        }
      }
    }
    if (type.constructors.isNotEmpty &&
        !type.modifiers.contains('abstract') &&
        type.kind != 'interface') {
      for (final field in type.fields) {
        if (field.mutable || field.initializer != null) continue;
        for (final constructor
            in type.constructors.where((item) => !item.factory)) {
          final initialized = constructor.parameters.any((parameter) =>
              parameter.initializing == 'this' && parameter.name == field.name);
          if (!initialized && !_bodyAssigns(constructor.body, field.name)) {
            error('E704', 'A final field is not initialized', field);
          }
        }
      }
    }
    final parentName = type.superclass;
    final parent = parentName == null
        ? null
        : _global.symbols[parentName]?.classDeclaration;
    if (parent != null &&
        (parent.modifiers.contains('final') || parent.kind == 'final')) {
      error('E720', 'A final class cannot be extended', type);
    }
    if (parent != null && parent.modifiers.contains('base')) {
      final allowed = type.modifiers.contains('base') ||
          type.modifiers.contains('final') ||
          type.modifiers.contains('sealed') ||
          type.kind == 'sealed';
      if (!allowed) {
        error('E720',
            'A subtype of a base class must be base, final, or sealed', type);
      }
    }
    for (final name in type.interfaces) {
      final face = _global.symbols[name]?.classDeclaration;
      if (face == null || face.kind != 'interface') {
        error('E700', 'implements expects an interface', type);
      }
      for (final field in face.fields) {
        final found = type.fields.where((item) => item.name == field.name);
        if (found.isEmpty || found.single.type != field.type) {
          error('E700', 'interface member ${field.name} is not implemented',
              type);
        }
      }
    }
    for (final name in type.mixins) {
      final mixin = _global.symbols[name]?.classDeclaration;
      if (mixin == null ||
          (mixin.kind != 'mixin' && mixin.kind != 'mixinClass')) {
        error('E702', 'with expects a mixin', type);
      }
      final onType = mixin.onType;
      if (onType != null && !_satisfiesOn(type, onType)) {
        error('E702', 'mixin $name requires $onType', type);
      }
    }
  }

  bool _satisfiesOn(ClassDeclaration type, String onType) {
    var name = type.superclass;
    while (name != null) {
      if (name == onType) return true;
      name = _global.symbols[name]?.classDeclaration?.superclass;
    }
    return false;
  }

  void analyzeExtension(ExtensionDeclaration type, FunctionDeclaration method) {
    final saved = _scope;
    final savedThis = _thisType;
    _scope = _Scope(_global);
    _thisType = type.target;
    analyzeFunction(method);
    _thisType = savedThis;
    _scope = saved;
  }

  void checkRequirements(ClassDeclaration type) {
    if (type.requirements.isEmpty) return;
    final saved = _scope;
    final savedThis = _thisType;
    _scope = _Scope(_global);
    _thisType = type.name;
    for (final field in type.fields) {
      _scope.symbols[field.name] =
          Symbol(field.name, field.name, model.resolve(field.type));
    }
    for (final requirement in type.requirements) {
      final condition = expression(requirement);
      if (condition != 'bool') {
        fail('require condition must be bool', requirement);
      }
    }
    _thisType = savedThis;
    _scope = saved;
  }

  void analyzeMethod(ClassDeclaration type, FunctionDeclaration method) {
    if (type.annotations.contains('macro') && method.name == 'define') return;
    final saved = _scope;
    final savedThis = _thisType;
    final savedReadonly = _readonlyMethod;
    _scope = _Scope(_global);
    _thisType = type.onType ?? type.name;
    _readonlyMethod = method.readonlyMethod;
    _installFields(type);
    analyzeFunction(method);
    _readonlyMethod = savedReadonly;
    _thisType = savedThis;
    _scope = saved;
  }

  void analyzeConstructor(
      ClassDeclaration type, ConstructorDeclaration constructor) {
    final saved = _scope;
    final savedThis = _thisType;
    _scope = _Scope(_global);
    _thisType = type.name;
    _installFields(type, assignable: true);
    for (final parameter in _ctorParameters(type, constructor)) {
      final symbol =
          Symbol(parameter.name, parameter.name, model.resolve(parameter.type));
      _scope.symbols[parameter.name] = symbol;
      model.declarations[parameter] = symbol;
      final original = constructor.parameters
          .where((item) => item.name == parameter.name)
          .firstOrNull;
      if (original != null) model.declarations[original] = symbol;
    }
    if (constructor.expressionBody case final value?) {
      final returned = expression(value);
      if (!compatible(returned, type.name) && !constructor.factory) {
        final target = _redirectName(value);
        if (target == null ||
            !type.constructors.any((item) => item.name == target)) {
          fail('A redirecting constructor must target a constructor', value);
        }
      }
    } else if (constructor.body != null) {
      statements(constructor.body!);
    }
    _thisType = savedThis;
    _scope = saved;
  }

  void analyzeProperty(ClassDeclaration type, PropertyDeclaration property) {
    final saved = _scope;
    final savedThis = _thisType;
    _scope = _Scope(_global);
    _thisType = type.name;
    _installFields(type);
    if (property.getter case final getter?) {
      final returned = expression(getter);
      if (!compatible(returned, property.type)) {
        fail('Getter type $returned is incompatible with ${property.type}',
            getter);
      }
    } else if (property.getterBody case final body?) {
      statements(body);
    }
    if (property.setterBody case final body?) {
      final nested = _scope;
      _scope = _Scope(nested);
      final param = property.setter ?? 'value';
      _scope.symbols[param] = Symbol(param, param, property.type);
      statements(body);
      _scope = nested;
    }
    _thisType = savedThis;
    _scope = saved;
  }

  void analyzeStaticField(FieldDeclaration field) {
    final value = field.initializer;
    if (value == null) fail('A static field needs an initializer', field);
    final String type;
    if (field.isConst) {
      final constant = _constants.evaluate(value);
      type = switch (constant) {
        ConstInt() => 'int',
        ConstDouble() => 'double',
        ConstBool() => 'bool',
        ConstString() => 'String',
        _ => 'Object',
      };
    } else {
      type = expression(value);
    }
    final declared = field.type == '<infer>' ? type : field.type;
    if (field.type != '<infer>') {
      validateType(field.type, field, allowVoid: false);
    }
    if (!compatible(type, declared)) {
      fail('Cannot initialize $declared with $type', value);
    }
    model.declarations[field] = Symbol(field.name, field.name, declared);
  }

  void _installFields(ClassDeclaration type, {bool assignable = false}) {
    for (final field in _fieldsOf(type)) {
      if (field.isStatic) continue;
      final dart = field.visibility == 'private' && !field.name.startsWith('_')
          ? '_${field.name}'
          : field.name;
      final symbol = Symbol(field.name, dart, model.resolve(field.type),
          mutable: assignable || field.mutable);
      if (assignable) {
        _scope.symbols[field.name] = symbol;
      } else {
        model.declarations[field] ??= symbol;
        _scope.symbols[field.name] = model.declarations[field]!;
        _fieldSymbols.add(model.declarations[field]!);
      }
    }
  }

  List<Parameter> _ctorParameters(
      ClassDeclaration type, ConstructorDeclaration constructor) {
    return [
      for (final parameter in constructor.parameters)
        if (parameter.initializing.isEmpty)
          parameter
        else
          Parameter(
              parameter.name,
              _fieldType(type, parameter.name, parameter.span),
              false,
              parameter.span,
              initializing: parameter.initializing)
    ];
  }

  String _fieldType(ClassDeclaration type, String name, SourceSpan span) {
    final found = _fieldsOf(type).where((field) => field.name == name);
    if (found.isEmpty) {
      throw CompilerException(
          'E200', 'No field $name for an initializing formal', span);
    }
    return model.resolve(found.first.type);
  }

  bool _bodyAssigns(List<Statement>? body, String name) {
    if (body == null) return false;
    for (final statement in body) {
      if (statement is Binding &&
          statement.name == name &&
          statement.operator == '=') {
        return true;
      }
      if (statement is MemberAssignment &&
          statement.object is ThisExpression &&
          statement.name == name) {
        return true;
      }
      if (statement is IfStatement &&
          _bodyAssigns(statement.thenBody, name) &&
          _bodyAssigns(statement.elseBody, name)) {
        return true;
      }
    }
    return false;
  }

  String? _redirectName(Expression node) {
    if (node is Identifier) return node.name;
    if (node is CallExpression && node.callee is Identifier) {
      return (node.callee as Identifier).name;
    }
    return null;
  }

  void registerWhen(WhenStatement node) {
    final selected = _constBool(node.condition);
    if (selected == null) {
      error(
          'E902', 'A when condition is not a constant boolean', node.condition);
    }
    if (!selected) {
      model.skipped.add(node);
      return;
    }
    for (final statement in node.body) {
      switch (statement) {
        case ImportDeclaration():
          registerImport(statement);
        case WhenStatement():
          registerWhen(statement);
        default:
          fail('A top-level when contains use directives', statement);
      }
    }
  }

  bool? _constBool(Expression node) {
    if (node is Literal && node.value is bool) return node.value as bool;
    final flag = _libraryFlag(node);
    if (flag != null) return flag;
    if (node is UnaryExpression &&
        (node.operator == 'not' || node.operator == '!')) {
      final inner = _constBool(node.operand);
      if (inner != null) return !inner;
    }
    if (node is BinaryExpression &&
        (node.operator == 'and' || node.operator == 'or')) {
      final left = _constBool(node.left);
      final right = _constBool(node.right);
      if (left == null || right == null) return null;
      return node.operator == 'and' ? left && right : left || right;
    }
    if (node is BinaryExpression &&
        (node.operator == '==' || node.operator == '!=')) {
      final left = _constText(node.left);
      final right = _constText(node.right);
      if (left == null || right == null) return null;
      final same = left == right;
      return node.operator == '==' ? same : !same;
    }
    return null;
  }

  String? _constText(Expression node) {
    if (node is Literal && node.value is String) return node.value as String;
    if (node is Identifier && node.name == 'platform') return 'vm';
    return null;
  }

  bool? _libraryFlag(Expression node) {
    final path = _memberPath(node);
    if (path == null || !path.startsWith('dart.library.')) return null;
    const enabled = {
      'dart.library.core',
      'dart.library.io',
      'dart.library.async',
      'dart.library.collection',
      'dart.library.convert',
      'dart.library.typed_data',
    };
    return enabled.contains(path);
  }

  String? _memberPath(Expression node) {
    if (node is Identifier) return node.name;
    if (node is MemberAccess && !node.nullAware) {
      final parent = _memberPath(node.object);
      if (parent == null) return null;
      return '$parent.${node.name}';
    }
    return null;
  }

  void registerImport(ImportDeclaration node) {
    if (node.condition != null) {
      final selected = _constBool(node.condition!);
      if (selected == null) {
        error('E902', 'A when condition is not a constant boolean',
            node.condition!);
      }
      if (!selected) {
        model.skipped.add(node);
        return;
      }
    }
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
    final resolved = model.resolve(type);
    if (resolved != type) {
      validateType(resolved, node, allowVoid: allowVoid);
      return;
    }
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
    if ({
      'int',
      'double',
      'num',
      'bool',
      'String',
      'Null',
      'Object',
      'StackTrace'
    }.contains(type)) {
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
    if ((type.startsWith('Iterable<') || type.startsWith('Stream<')) &&
        type.endsWith('>')) {
      validateType(type.substring(type.indexOf('<') + 1, type.length - 1), node,
          allowVoid: false);
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
    _returnType = function.generator == 'sync' &&
            declared.startsWith('Iterable<') &&
            declared.endsWith('>')
        ? declared.substring(9, declared.length - 1)
        : function.generator == 'async' &&
                declared.startsWith('Stream<') &&
                declared.endsWith('>')
            ? declared.substring(7, declared.length - 1)
            : function.isAsync &&
                    declared.startsWith('Future<') &&
                    declared.endsWith('>')
                ? declared.substring(7, declared.length - 1)
                : declared;
    final parameterNames = <String>[];
    for (final parameter in function.parameters) {
      final stored =
          parameter.variadic ? 'List<${parameter.type}>' : parameter.type;
      validateType(stored, parameter, allowVoid: false);
      if (_scope.lookup(parameter.name) != null)
        fail('Parameter would shadow an existing symbol: ${parameter.name}',
            parameter);
      final symbol = create(parameter.name, stored, mutable: parameter.mutable);
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
        model.declarations[function]!.type = function.generator == 'sync'
            ? 'Iterable<$type>'
            : function.generator == 'async'
                ? 'Stream<$type>'
                : function.isAsync
                    ? 'Future<$type>'
                    : type;
      } else if (!compatible(type, _returnType!)) {
        fail('Return type $type is incompatible with $_returnType', value);
      }
    } else {
      statements(function.body!);
      if (function.generator.isEmpty &&
          _returnType != 'void' &&
          !returns(function.body!)) {
        fail(
            'Non-void function must explicitly return on every path', function);
      }
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
        if (node.mode == BindingMode.state ||
            node.mode == BindingMode.computed) {
          if (_scope.lookup(node.name) != null) {
            fail(
                'Binding would shadow ${node.name}; use shadow in an inner scope',
                node);
          }
          if (node.operator != '=') {
            fail('state and computed require =', node);
          }
          final reactive =
              node.mode == BindingMode.state ? 'state' : 'computed';
          final symbol = create(node.name, node.type ?? '<infer>',
              mutable: node.mode == BindingMode.state, reactive: reactive);
          _scope.symbols[node.name] = symbol;
          model.declarations[node] = symbol;
          final savedExpected = _expected;
          if (node.type != null) _expected = node.type;
          final type = expression(node.value);
          _expected = savedExpected;
          if (type == 'void') {
            fail('A void expression cannot initialize a binding', node);
          }
          final target = node.type ?? type;
          validateType(target, node, allowVoid: false);
          if (!compatible(type, target)) {
            fail('Cannot initialize $target with $type', node);
          }
          symbol.type = target;
          if (reactive == 'computed' && computedCycle(node.name, node.value)) {
            warn('W007', 'computed dependency cycle', node);
          }
          return;
        }
        final existing = _scope.lookup(node.name);
        final savedExpected = _expected;
        if (node.type != null) {
          _expected = node.type;
        } else if (existing != null &&
            node.mode == BindingMode.inferred &&
            node.type == null) {
          _expected = existing.type;
        }
        if (node.open) {
          _expected = savedExpected;
          if (node.type == null) fail('late binding needs a type', node);
          validateType(node.type!, node, allowVoid: false);
          final stored = node.type!.startsWith('readonly ')
              ? node.type!.substring(9)
              : node.type!;
          final symbol = create(node.name, stored,
              mutable: node.mode == BindingMode.lateMutable,
              late: true,
              lateOpen: true,
              readonly: node.type!.startsWith('readonly '));
          _scope.symbols[node.name] = symbol;
          model.declarations[node] = symbol;
          return;
        }
        final type = expression(node.value);
        _expected = savedExpected;
        if (type == 'void')
          fail('A void expression cannot initialize a binding', node);
        if (existing != null &&
            node.mode == BindingMode.inferred &&
            node.type == null) {
          if (existing.readonly ||
              (_readonlyMethod && _fieldSymbols.contains(existing))) {
            error('E307', 'A readonly reference cannot be mutated', node);
          }
          if (!existing.mutable && !existing.lateOpen)
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
                node.mode == BindingMode.shadowMutable ||
                node.mode == BindingMode.lateMutable,
            constant: node.mode == BindingMode.constant,
            constantValue: constantValue,
            readonly: readonly,
            late: node.mode == BindingMode.lateFinal ||
                node.mode == BindingMode.lateMutable);
        _scope.symbols[node.name] = symbol;
        model.declarations[node] = symbol;
      case IfStatement():
        if (expression(node.condition) != 'bool')
          fail('if condition must be bool', node.condition);
        statements(node.thenBody, nested: true);
        statements(node.elseBody, nested: true);
      case ForStatement():
        final type = expression(node.iterable);
        if (node.awaiting && (_function == null || !_function!.isAsync)) {
          error('E803', 'await for is only valid inside async', node);
        }
        final element = node.awaiting
            ? (type.startsWith('Stream<') && type.endsWith('>')
                ? type.substring(7, type.length - 1)
                : fail('await for requires a Stream', node.iterable))
            : elementType(type, node.iterable);
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
            node.statement is! WhileStatement &&
            node.statement is! RepeatStatement &&
            node.statement is! CForStatement) {
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
        checkExhaustive(node, matched, node.arms.map((arm) => arm.pattern),
            node.arms.map((arm) => arm.guard));
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
            node.expression is! DoExpression &&
            node.expression is! TryExpression &&
            node.expression is! MatchExpression &&
            node.expression is! IfExpression) {
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
      case TryStatement():
        statements(node.body, nested: true);
        for (final clause in node.catches) {
          final savedCatch = _scope;
          _scope = _Scope(savedCatch);
          final caught = clause.type ?? 'Object';
          validateType(caught, clause);
          final symbol = create(clause.name, caught);
          _scope.symbols[clause.name] = symbol;
          model.declarations[clause] = symbol;
          if (clause.trace != null) {
            final trace = create(clause.trace!, 'StackTrace');
            _scope.symbols[clause.trace!] = trace;
            model.traces[clause] = trace;
          }
          _catchDepth++;
          statements(clause.body);
          _catchDepth--;
          _scope = savedCatch;
        }
        if (node.finallyBody.isNotEmpty) {
          statements(node.finallyBody, nested: true);
        }
      case ThrowStatement():
        if (expression(node.value) == 'void') {
          fail('throw needs a value', node.value);
        }
      case RethrowStatement():
        if (_catchDepth == 0) {
          error('E107', 'rethrow is only valid inside catch', node);
        }
      case YieldStatement():
        if (_function == null || _function!.generator.isEmpty) {
          error('E804', 'yield is only valid inside a generator', node);
        }
        final yielded = expression(node.value);
        if (node.star) {
          final inner = elementType(yielded, node.value);
          if (_returnType == '<infer>') {
            _returnType = inner;
            model.declarations[_function!]!.type =
                _function!.generator == 'sync'
                    ? 'Iterable<$inner>'
                    : 'Stream<$inner>';
          } else if (!compatible(inner, _returnType!)) {
            fail('yield* type $inner is incompatible with $_returnType', node);
          }
        } else if (_returnType == '<infer>') {
          _returnType = yielded;
          model.declarations[_function!]!.type = _function!.generator == 'sync'
              ? 'Iterable<$yielded>'
              : 'Stream<$yielded>';
        } else if (!compatible(yielded, _returnType!)) {
          fail('yield type $yielded is incompatible with $_returnType', node);
        }
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
      case WatchStatement():
        expression(node.value);
        statements(node.body, nested: true);
      case RequireStatement():
        final condition = expression(node.condition);
        if (condition != 'bool') {
          fail('require condition must be bool', node.condition);
        }
      case IfCaseStatement():
        final matched = expression(node.scrutinee);
        final savedCase = _scope;
        _scope = _Scope(savedCase);
        bindPattern(node.pattern, matched, declare: true);
        statements(node.body);
        _scope = savedCase;
      case WhenStatement():
        final selected = _constBool(node.condition);
        if (selected == null) {
          error('E902', 'A when condition is not a constant boolean',
              node.condition);
        }
        if (!selected) {
          model.skipped.add(node);
          break;
        }
        statements(node.body, nested: true);
      case IfLetStatement():
        final raw = expression(node.value);
        if (!raw.endsWith('?') && raw != 'Null') {
          fail('if let requires a nullable value', node.value);
        }
        if (_scope.lookup(node.name) != null) {
          fail(
              'Binding would shadow ${node.name}; use shadow in an inner scope',
              node);
        }
        final savedLet = _scope;
        _scope = _Scope(savedLet);
        final bound = create(node.name, unwrap(raw));
        _scope.symbols[node.name] = bound;
        model.declarations[node] = bound;
        statements(node.thenBody);
        _scope = savedLet;
        if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
      case DeferStatement():
        if (_containsAwait(node.expression)) {
          model.asyncDefers.add(node);
          if (_function?.isAsync != true) {
            error(
                'E803', 'async defer is only valid in an async function', node);
          }
        }
        expression(node.expression);
      case UsingStatement():
        if (node.async && _function?.isAsync != true) {
          error('E803', 'using async is only valid in an async function', node);
        }
        final used = expression(node.value);
        final usedType =
            unwrap(used.startsWith('readonly ') ? used.substring(9) : used);
        final declaration = _global.symbols[usedType]?.classDeclaration;
        if (declaration == null || _method(declaration, 'dispose') == null) {
          fail('using requires a value with dispose', node.value);
        }
        final savedUsing = _scope;
        _scope = _Scope(savedUsing);
        final resource = create(node.name, usedType);
        _scope.symbols[node.name] = resource;
        model.declarations[node] = resource;
        statements(node.body);
        _scope = savedUsing;
      case MemberAssignment():
        _assignMember(node);
      case PartDirective():
        fail('part belongs at the top level', node);
      case AliasDeclaration():
      case ExtensionDeclaration():
      case ClassDeclaration():
      case ImportDeclaration():
        fail('Classes and imports belong at the top level', node);
    }
  }

  void _assignMember(MemberAssignment node) {
    final raw = expression(node.object);
    if (raw.startsWith('readonly ') ||
        (_readonlyMethod &&
            (node.object is ThisExpression ||
                node.object is Identifier &&
                    model.implicitThis.contains(node.object)))) {
      error('E307', 'A readonly reference cannot be mutated', node);
    }
    final type = unwrap(raw);
    final declaration = _global.symbols[type]?.classDeclaration;
    if (declaration == null) fail('No member ${node.name} on $raw', node);
    final properties =
        _propertiesOf(declaration).where((item) => item.name == node.name);
    if (properties.isNotEmpty) {
      final property = properties.first;
      if (property.setter == null && property.setterBody == null) {
        fail('Property ${node.name} is read-only', node);
      }
      final value = expression(node.value);
      if (!compatible(value, property.type)) {
        fail('Cannot assign $value to ${property.type}', node);
      }
      model.references[node] = Symbol(
          property.name, _dartMember(type, property.name), property.type);
      return;
    }
    final fields =
        _fieldsOf(declaration).where((item) => item.name == node.name);
    if (fields.isEmpty || !fields.first.mutable) {
      fail('Cannot assign immutable field ${node.name}', node);
    }
    final value = expression(node.value);
    if (!compatible(value, fields.first.type)) {
      fail('Cannot assign $value to ${fields.first.type}', node);
    }
    model.references[node] = Symbol(fields.first.name,
        _dartMember(type, fields.first.name), fields.first.type);
  }

  final _labels = <String>[];
  var _loopDepth = 0;
  var _catchDepth = 0;

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
    if (type.startsWith('Iterable<') && type.endsWith('>')) {
      return type.substring(9, type.length - 1);
    }
    if (type.startsWith('Stream<') && type.endsWith('>')) {
      return type.substring(7, type.length - 1);
    }
    fail('for-in requires a List, Set, range, or iterable', node);
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
    from = model.resolve(from);
    to = model.resolve(to);
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
    if (node.name == 'instance' &&
        declaration != null &&
        declaration.modifiers.contains('singleton')) {
      return declaration.name;
    }
    final onType = _isTypeReference(node.object);
    if (declaration != null) {
      final field =
          _fieldsOf(declaration).where((item) => item.name == node.name);
      final method = field.isEmpty ? _method(declaration, node.name) : null;
      final isStatic =
          field.isNotEmpty ? field.first.isStatic : method?.isStatic ?? false;
      if ((field.isNotEmpty || method != null) && isStatic != onType) {
        fail(
            isStatic
                ? 'Static member ${node.name} is used on an instance'
                : 'Instance member ${node.name} is used on the type',
            node);
      }
    }
    final found = memberType(base, node.name);
    if (found != null) {
      model.references[node] =
          Symbol(node.name, _dartMember(base, node.name), found);
      if (found.contains('->')) return found;
      return node.nullAware || type.endsWith('?') ? '$found?' : found;
    }
    fail('No member ${node.name} on $type', node);
  }

  bool _isTypeReference(Expression node) {
    if (node is! Identifier) return false;
    final symbol = model.references[node];
    return symbol?.classDeclaration != null && symbol!.classCase == null;
  }

  bool _containsAwait(Expression node) => switch (node) {
        AwaitExpression() => true,
        UnaryExpression() => _containsAwait(node.operand),
        BinaryExpression() =>
          _containsAwait(node.left) || _containsAwait(node.right),
        CallExpression() => _containsAwait(node.callee) ||
            node.arguments.any((argument) => _containsAwait(argument.value)),
        MemberAccess() => _containsAwait(node.object),
        _ => false,
      };

  String? memberType(String type, String name) {
    final declaration = _global.symbols[type]?.classDeclaration;
    if (declaration != null) {
      for (final field in _fieldsOf(declaration)) {
        if (field.name == name) {
          return model.declarations[field]?.type ?? field.type;
        }
      }
      for (final property in _propertiesOf(declaration)) {
        if (property.name == name) return property.type;
      }
      final method = _method(declaration, name);
      if (method != null) return functionType(method);
    }
    final extensions = _extensions(type, name);
    if (extensions.length > 1) {
      error('E205', 'Two extensions define $name and neither is more specific',
          extensions.first);
    }
    if (extensions.length == 1) return functionType(extensions.single);
    return null;
  }

  List<PropertyDeclaration> _propertiesOf(ClassDeclaration type) {
    final inherited = <PropertyDeclaration>[];
    var name = type.superclass;
    while (name != null) {
      final parent = _global.symbols[name]?.classDeclaration;
      if (parent == null) break;
      inherited.insertAll(0, parent.properties);
      name = parent.superclass;
    }
    return [...inherited, ...type.properties];
  }

  String _dartMember(String type, String name) {
    final declaration = _global.symbols[type]?.classDeclaration;
    if (declaration == null) return name;
    for (final field in declaration.fields) {
      if (field.name == name) {
        return field.visibility == 'private' && !name.startsWith('_')
            ? '_$name'
            : name;
      }
    }
    for (final property in declaration.properties) {
      if (property.name == name) {
        return property.visibility == 'private' && !name.startsWith('_')
            ? '_$name'
            : name;
      }
    }
    for (final method in declaration.methods) {
      if (method.name == name) {
        return model.declarations[method]?.dartName ?? name;
      }
    }
    final parent = declaration.superclass;
    if (parent == null) return name;
    return _dartMember(parent, name);
  }

  List<FieldDeclaration> _fieldsOf(ClassDeclaration type) {
    final inherited = <FieldDeclaration>[];
    var name = type.superclass;
    while (name != null) {
      final parent = _global.symbols[name]?.classDeclaration;
      if (parent == null) break;
      inherited.insertAll(0, parent.fields);
      name = parent.superclass;
    }
    return [...inherited, ...type.fields];
  }

  FunctionDeclaration? _method(ClassDeclaration type, String name) {
    for (final method in type.methods) {
      if (method.name == name) return method;
    }
    for (final mixin in type.mixins.reversed) {
      final declaration = _global.symbols[mixin]?.classDeclaration;
      if (declaration == null) continue;
      final found = _method(declaration, name);
      if (found != null) return found;
    }
    final parent = type.superclass == null
        ? null
        : _global.symbols[type.superclass!]?.classDeclaration;
    if (parent != null) return _method(parent, name);
    return null;
  }

  List<FunctionDeclaration> _extensions(String type, String name) => [
        for (final extension in model.extensions)
          if (extension.target == type)
            for (final method in extension.methods)
              if (method.name == name) method
      ];

  bool computedCycle(String name, Expression body) {
    bool walk(Expression node, Set<String> stack) {
      switch (node) {
        case Identifier():
          final symbol = model.references[node];
          if (symbol == null || symbol.reactive != 'computed') return false;
          if (stack.contains(symbol.name)) return true;
          return false;
        case UnaryExpression():
          return walk(node.operand, stack);
        case BinaryExpression():
          return walk(node.left, stack) || walk(node.right, stack);
        case CallExpression():
          return walk(node.callee, stack) ||
              node.arguments.any((argument) => walk(argument.value, stack));
        default:
          return false;
      }
    }

    return walk(body, {name});
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
    String? key;
    String? value;
    void unify(String nextKey, String nextValue, Node at) {
      if (key == null) {
        key = nextKey;
        value = nextValue;
        return;
      }
      if (nextKey != key || nextValue != value) {
        fail('Map entries must share key and value types', at);
      }
    }

    for (var i = 0; i < node.keys.length; i++) {
      final entry = node.keys[i];
      if (entry is SpreadElement) {
        var spread = expression(entry.operand);
        if (entry.nullAware) {
          if (!spread.endsWith('?')) {
            fail('...? requires a nullable map', entry);
          }
          spread = unwrap(spread);
        }
        if (!spread.startsWith('Map<') || !spread.endsWith('>')) {
          fail('A map spread requires a map', entry);
        }
        final inner = spread.substring(4, spread.length - 1);
        final splitAt = inner.indexOf(',');
        unify(inner.substring(0, splitAt).trim(),
            inner.substring(splitAt + 1).trim(), entry);
      } else if (entry is MapComprehension) {
        final shaped = mapControl(entry);
        unify(shaped.$1, shaped.$2, entry);
      } else {
        unify(expression(entry), expression(node.values[i]), node.values[i]);
      }
    }
    return 'Map<$key, $value>';
  }

  String mapControlType(MapComprehension node) {
    final shaped = mapControl(node);
    return 'Map<${shaped.$1}, ${shaped.$2}>';
  }

  (String, String) mapControl(MapComprehension node) {
    if (node.name != null) {
      final iterable = expression(node.iterable!);
      final element = elementType(iterable, node.iterable!);
      if (_scope.lookup(node.name!) != null) {
        fail('Loop binding would shadow ${node.name}', node);
      }
      final symbol = create(node.name!, element);
      model.declarations[node] = symbol;
      final saved = _scope;
      _scope = _Scope(saved);
      _scope.symbols[node.name!] = symbol;
      final shaped = mapLiteral(node.thenMap);
      model.types[node.thenMap] = shaped;
      _scope = saved;
      final inner = shaped.substring(4, shaped.length - 1);
      final splitAt = inner.indexOf(',');
      return (
        inner.substring(0, splitAt).trim(),
        inner.substring(splitAt + 1).trim()
      );
    }
    if (expression(node.condition!) != 'bool') {
      fail('collection if condition must be bool', node.condition!);
    }
    final thenType = mapLiteral(node.thenMap);
    model.types[node.thenMap] = thenType;
    if (node.elseMap != null) {
      final elseType = mapLiteral(node.elseMap!);
      model.types[node.elseMap!] = elseType;
      if (elseType != thenType) {
        fail('Map entries must share key and value types', node);
      }
    }
    final inner = thenType.substring(4, thenType.length - 1);
    final splitAt = inner.indexOf(',');
    return (
      inner.substring(0, splitAt).trim(),
      inner.substring(splitAt + 1).trim()
    );
  }

  String spreadElementType(SpreadElement element) {
    var type = expression(element.operand);
    if (element.nullAware) {
      if (!type.endsWith('?')) {
        fail('...? requires a nullable collection', element);
      }
      type = unwrap(type);
    }
    return elementType(type, element);
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
    final owner = _global.symbols[unwrap(left)]?.classDeclaration;
    final method = owner == null ? null : _method(owner, op);
    if (owner != null && method != null && method.isOperator) {
      if (method.parameters.isNotEmpty) {
        final expected = method.parameters.first.type;
        if (expected != '<field>' && !compatible(right, expected)) {
          fail('Operator $op is not defined for $left and $right', node);
        }
      }
      return model.declarations[method]?.type ??
          method.returnType ??
          owner.name;
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
      SpreadElement() => spreadElementType(node),
      MapComprehension() => mapControlType(node),
      IfExpression() => ifExpression(node),
      MatchExpression() => matchExpression(node),
      TryExpression() => tryExpression(node),
      ThisExpression() => thisExpression(node),
    };
    model.types[node] = type;
    return type;
  }

  String identifier(Identifier node) {
    final symbol = _scope.lookup(node.name);
    if (symbol == null && _thisType != null) {
      final member = memberType(_thisType!, node.name);
      if (member != null) {
        model.implicitThis.add(node);
        model.references[node] =
            Symbol(node.name, _dartMember(_thisType!, node.name), member);
        return member;
      }
    }
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
    if (element is SpreadElement) return spreadElementType(element);
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

  bool variadicArgument(Argument argument, Parameter parameter) {
    if (argument.value is SpreadElement) {
      final spread = argument.value as SpreadElement;
      final type = expression(spread.operand);
      final bare = spread.nullAware ? unwrap(type) : type;
      if (spread.nullAware && !type.endsWith('?')) return false;
      final element = _collectionElement(bare);
      return element != null && compatible(element, parameter.type);
    }
    final saved = _expected;
    _expected = parameter.type;
    final type = expression(argument.value);
    _expected = saved;
    return compatible(type, parameter.type);
  }

  String? _collectionElement(String type) {
    for (final prefix in ['List<', 'Set<', 'Iterable<', 'Range<']) {
      if (type.startsWith(prefix) && type.endsWith('>')) {
        return type.substring(prefix.length, type.length - 1);
      }
    }
    return null;
  }

  String call(CallExpression node) {
    final callee = node.callee;
    if (callee is MemberAccess && callee.object is Identifier) {
      final owner = _scope.lookup((callee.object as Identifier).name);
      final type = owner?.classDeclaration;
      final named = type?.constructors
          .where((constructor) => constructor.name == callee.name)
          .toList();
      if (type != null && named != null && named.isNotEmpty) {
        model.references[callee.object as Identifier] = owner!;
        final parameters = _ctorParameters(type, named.first);
        applyArguments(node, parameters, null);
        model.references[callee] = Symbol(callee.name, callee.name, type.name,
            function: FunctionDeclaration(callee.name, parameters, type.name,
                null, null, named.first.span));
        return type.name;
      }
    }
    if (callee is MemberAccess) {
      final rawObject = expression(callee.object);
      if (callee.name == 'copyWith') {
        final objectType = unwrap(rawObject.startsWith('readonly ')
            ? rawObject.substring(9)
            : rawObject);
        final declaration = _global.symbols[objectType]?.classDeclaration;
        if (declaration != null &&
            (declaration.kind == 'value' ||
                declaration.modifiers.contains('value'))) {
          for (final argument in node.arguments) {
            if (argument.name == null) {
              fail('copyWith arguments are named', argument);
            }
            final fields = _fieldsOf(declaration)
                .where((field) => field.name == argument.name);
            if (fields.isEmpty) {
              fail('Unknown argument: ${argument.name}', argument);
            }
            if (argument.value is Identifier &&
                (argument.value as Identifier).name == 'missing') {
              continue;
            }
            final value = expression(argument.value);
            if (!compatible(value, fields.first.type)) {
              fail(
                  'Argument type $value is incompatible with ${fields.first.type}',
                  argument);
            }
          }
          model.references[callee] =
              Symbol('copyWith', 'copyWith', declaration.name);
          return declaration.name;
        }
      }
      if (rawObject.startsWith('readonly ') &&
          _mutating.contains(callee.name)) {
        error('E307', 'A readonly reference cannot be mutated', callee);
      }
      final objectType = unwrap(rawObject.startsWith('readonly ')
          ? rawObject.substring(9)
          : rawObject);
      final declaration = _global.symbols[objectType]?.classDeclaration;
      final function =
          declaration == null ? null : _method(declaration, callee.name);
      final resolved = function ??
          () {
            final found = _extensions(objectType, callee.name);
            if (found.length > 1) {
              error(
                  'E205',
                  'Two extensions define ${callee.name} and neither is more specific',
                  callee);
            }
            return found.isEmpty ? null : found.single;
          }();
      if (resolved == null) {
        fail('No method ${callee.name} on $objectType', callee);
      }
      if (resolved.isStatic != _isTypeReference(callee.object)) {
        fail(
            resolved.isStatic
                ? 'Static member ${callee.name} is used on an instance'
                : 'Instance member ${callee.name} is used on the type',
            callee);
      }
      final functionResolved = resolved;
      model.references[callee] = model.declarations[functionResolved]!;
      final returned =
          applyArguments(node, functionResolved.parameters, functionResolved);
      return model.declarations[functionResolved]!.type == '<infer>'
          ? returned
          : model.declarations[functionResolved]!.type;
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
    if (symbol == null && _thisType != null) {
      final declaration = _global.symbols[_thisType!]?.classDeclaration;
      final method =
          declaration == null ? null : _method(declaration, callee.name);
      final extensions = method == null
          ? _extensions(_thisType!, callee.name)
          : <FunctionDeclaration>[];
      final resolved =
          method ?? (extensions.length == 1 ? extensions.single : null);
      if (extensions.length > 1) {
        error('E205', 'Two extensions define ${callee.name}', callee);
      }
      if (resolved != null) {
        if (resolved.isStatic) {
          fail('Static member ${callee.name} is used on an instance', callee);
        }
        if (_readonlyMethod && !resolved.readonlyMethod) {
          error('E307', 'A readonly method may only read this', callee);
        }
        model.implicitThis.add(callee);
        model.references[callee] = model.declarations[resolved]!;
        return applyArguments(node, resolved.parameters, resolved);
      }
    }
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
        final current = selected;
        final selectedVariadic =
            current != null && current.parameters.any((p) => p.variadic);
        final candidateVariadic = candidate.parameters.any((p) => p.variadic);
        if (selected != null && selectedVariadic == candidateVariadic) {
          fail('Ambiguous overload: ${callee.name}', node);
        }
        if (selected == null || (selectedVariadic && !candidateVariadic)) {
          selected = candidate;
        }
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
    if (type.modifiers.contains('singleton')) {
      fail(
          'Singleton ${type.name} is available as ${type.name}.instance', node);
    }
    if (type.modifiers.contains('abstract') || type.kind == 'interface') {
      error('E700', 'An abstract type cannot be constructed', node);
    }
    if (type.kind == 'extensionType') {
      final field = type.fields.single;
      applyArguments(
          node,
          [Parameter(field.name, model.resolve(field.type), false, field.span)],
          null);
      return type.name;
    }
    if (type.constructors.isNotEmpty) {
      final unnamed =
          type.constructors.where((constructor) => constructor.name == null);
      if (unnamed.isEmpty) {
        fail('${type.name} has no unnamed constructor', node);
      }
      final constructor = unnamed.first;
      final parameters = _ctorParameters(type, constructor);
      applyArguments(node, parameters, null);
      model.references[node.callee] = Symbol(type.name, type.name, type.name,
          function: FunctionDeclaration(type.name, parameters, type.name,
              constructor.body, constructor.expressionBody, constructor.span));
      return type.name;
    }
    final parameters = <Parameter>[];
    for (final field in _fieldsOf(type)) {
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
        if (parameters.isNotEmpty &&
            parameters.last.variadic &&
            positional >= parameters.length - 1) {
          if (!variadicArgument(argument, parameters.last)) return false;
          positional++;
          continue;
        }
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
      final savedExpected = _expected;
      if (parameters[target].type != '<infer>') {
        _expected = parameters[target].type;
      }
      final type = expression(argument.value);
      _expected = savedExpected;
      if (!compatible(type, parameters[target].type)) return false;
      order[target] = i;
    }
    for (var i = 0; i < parameters.length; i++) {
      if (parameters[i].variadic) continue;
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
    final rest = <int>[];
    var positional = 0;
    var named = false;
    final holes = <int>[];
    for (var i = 0; i < node.arguments.length; i++) {
      final argument = node.arguments[i];
      int target;
      if (argument.name == null) {
        if (named)
          fail('Positional arguments must precede named arguments', argument);
        if (parameters.isNotEmpty &&
            parameters.last.variadic &&
            positional >= parameters.length - 1) {
          if (!variadicArgument(argument, parameters.last)) {
            fail('Variadic argument does not match ${parameters.last.type}',
                argument);
          }
          rest.add(i);
          positional++;
          continue;
        }
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
      final savedExpected = _expected;
      if (parameters[target].type != '<infer>') {
        _expected = parameters[target].type;
      }
      final type = expression(argument.value);
      _expected = savedExpected;
      if (!compatible(type, parameters[target].type)) {
        fail(
            'Argument type $type is incompatible with ${parameters[target].type}',
            argument);
      }
      order[target] = i;
    }
    for (var i = 0; i < parameters.length; i++) {
      if (parameters[i].variadic || order[i] != -1) continue;
      final fallback = parameters[i].defaultValue;
      if (fallback == null) fail('Missing required argument', node);
      final type = model.types[fallback] ?? expression(fallback);
      if (!compatible(type, parameters[i].type)) {
        fail('Default type $type is incompatible with ${parameters[i].type}',
            fallback);
      }
    }
    model.argumentOrder[node] = order;
    model.variadicArguments[node] = rest;
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

  void checkExhaustive(Node node, String matched, Iterable<Pattern> patterns,
      Iterable<Expression?> guards,
      {bool expression = false}) {
    final declaration = _global.symbols[matched]?.classDeclaration;
    final finite = declaration != null &&
        (declaration.kind == 'sealedType' || declaration.kind == 'enum');
    final universe = matched.contains(' | ')
        ? matched.split(' | ').map((part) => part.trim()).toSet()
        : finite
            ? declaration.cases.map((item) => item.name).toSet()
            : null;
    if (universe == null || universe.isEmpty) return;
    final covered = <String>{};
    var closed = false;
    final guardList = guards.toList();
    var index = 0;
    for (final pattern in patterns) {
      if (closed) {
        error('E313', 'Unreachable match arm', pattern);
      }
      final names = _covered(pattern, universe);
      final guarded = index < guardList.length && guardList[index] != null;
      index++;
      if (guarded) continue;
      if (names == null) {
        covered.addAll(universe);
        closed = true;
      } else {
        covered.addAll(names);
        if (covered.containsAll(universe)) closed = true;
      }
    }
    if (!covered.containsAll(universe)) {
      if (expression) {
        error('E314', 'match expression does not cover every case', node);
      }
      warn('W001', 'match does not cover every case', node);
    }
  }

  String ifExpression(IfExpression node) {
    if (expression(node.condition) != 'bool') {
      fail('if condition must be bool', node.condition);
    }
    final thenType = expression(node.thenValue);
    final elseType = expression(node.elseValue);
    return joinTypes(thenType, elseType, node);
  }

  String matchExpression(MatchExpression node) {
    final matched = expression(node.value);
    if (node.arms.isEmpty) fail('match needs at least one arm', node);
    String? type;
    for (final arm in node.arms) {
      final saved = _scope;
      _scope = _Scope(saved);
      bindPattern(arm.pattern, matched);
      if (arm.guard != null && expression(arm.guard!) != 'bool') {
        fail('when guard must be bool', arm.guard!);
      }
      final armType = expression(arm.result);
      _scope = saved;
      type = type == null ? armType : joinTypes(type, armType, arm.result);
    }
    checkExhaustive(node, matched, node.arms.map((arm) => arm.pattern),
        node.arms.map((arm) => arm.guard),
        expression: true);
    return type!;
  }

  String thisExpression(ThisExpression node) {
    if (_thisType == null) fail('this is outside a type', node);
    return _thisType!;
  }

  String tryExpression(TryExpression node) {
    return joinTypes(expression(node.operand), expression(node.fallback), node);
  }

  String joinTypes(String left, String right, Node node) {
    if (left == right) return left;
    if (numeric(left) && numeric(right)) return 'num';
    if (left == '$right?') return left;
    if (right == '$left?') return right;
    fail('Branches must share a type', node);
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
