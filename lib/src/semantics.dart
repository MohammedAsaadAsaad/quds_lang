import 'dart:io';

import 'ast.dart';
import 'constants.dart';
import 'dart_api.dart';
import 'libraries.dart';
import 'sdk.dart';
import 'source.dart';
import 'walk.dart';

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
      this.reactive = '',
      this.field = false,
      this.library = '',
      this.namespace,
      this.external = false,
      this.callable = false,
      this.optionalParameters = 0,
      this.documentation,
      this.signature,
      this.originFile,
      this.originLine = 0,
      this.originColumn = 0,
      this.originOffset = 0});
  final String name, dartName;
  String type;
  final bool mutable, constant, late, lateOpen, field;

  /// A name that comes from a Dart library. Calls keep the written arguments.
  final bool external;

  /// A Dart function or unnamed constructor read from an SDK source.
  final bool callable;

  /// How many trailing [parameterTypes] may be omitted.
  final int optionalParameters;

  /// Documentation comments from a Dart SDK source, or a builtin.
  final String? documentation;

  /// Signature shown when the pointer rests on this name.
  final String? signature;

  /// Absolute path of the Dart source that declares this name.
  final String? originFile;
  final int originLine;
  final int originColumn;
  final int originOffset;

  /// Names brought in by `use ... as prefix`. Null for every other symbol.
  final Map<String, Symbol>? namespace;

  /// Empty, `state`, or `computed`.
  final String reactive;
  final ConstValue? constantValue;
  final overloads = <FunctionDeclaration>[];
  final ClassDeclaration? classDeclaration;
  final ClassCase? classCase;
  final List<String> parameterTypes;
  final bool readonly;

  /// Empty means the compilation being checked.
  final String library;
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

class _LoopFrame {
  _LoopFrame(this.value);
  final bool value;
  String? breakType;
}

class SemanticModel {
  final references = <Node, Symbol>{};
  final declarations = <Node, Symbol>{};
  final assignments = <Binding>{};
  final rebinding = <Pattern>{};
  final types = <Expression, String>{};

  /// Parameter order expressed as indices into source-order arguments.
  final argumentOrder = <CallExpression, List<int>>{};

  /// Const expressions that were evaluated. Short-circuited operands are absent.
  final constants = <Expression, ConstValue>{};

  /// Const constructor calls. The value is the instantiated parameter list.
  final constCalls = <CallExpression, ConstConstructor>{};
  final imports = <ImportDeclaration>[];
  final warnings = <CompilerException>[];
  final enumNames = <String>{};
  final traces = <CatchClause, Symbol>{};
  final asyncLambdas = <Lambda>{};
  final variadicArguments = <CallExpression, List<int>>{};
  final implicitThis = <Identifier>{};

  /// The index binding of `for index, name in`, or the first field of a pair.
  final loopIndexes = <Node, Symbol>{};

  /// `for a, b in` walks a pair instead of an index.
  final loopPairs = <Node>{};
  final extensions = <ExtensionDeclaration>[];
  final aliases = <String, String>{};

  /// Alias name to the `quds:` library that declared it.
  final sdkAliases = <String, String>{};
  final classes = <String, ClassDeclaration>{};

  /// `quds:` libraries whose classes, functions, or extensions are used.
  final usedSdk = <String>{};

  /// Public names of a `quds:` library that exist in its generated Dart.
  ///
  /// Aliases are erased, so they are absent. Names re-exported from `dart:`
  /// are included.
  final sdkDartNames = <String, Set<String>>{};

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
  final annotations = <String>{};
  final annotationShapes = <String, AnnotationDeclaration>{};
  final reflectable = <ClassDeclaration>{};

  /// Classes keyed by the declaration, so a prefixed name still finds its library.
  final libraryOf = <ClassDeclaration, String>{};

  /// Prelude types removed by `use quds:core show` or `hide`.
  final hiddenTypes = <String>{};

  /// Module scope after a successful analysis, including imports and prelude.
  final moduleSymbols = <String, Symbol>{};

  /// Public members of Dart SDK classes read from the SDK sources.
  final dartShapes = <String, DartShape>{};

  /// Dart import URI for a `package:` or `generated:` library that was loaded.
  final resolvedImports = <ImportDeclaration, String>{};

  /// Emit `@protected` because this package depends on `package:meta`.
  var protectWithMeta = false;
}

/// A symbol for one name read from a Dart SDK library.
///
/// [library] is set when the name arrives through a `quds:` re-export, so
/// using it still loads that SDK library.
Symbol symbolForDart(DartTop top, [DartShape? shape, String library = '']) {
  if (top.isType) {
    final namespace = <String, Symbol>{};
    final constructors = shape?.constructors ?? const <String, DartMember>{};
    for (final entry in constructors.entries) {
      if (entry.key.isEmpty) continue;
      namespace[entry.key] = _dartMemberSymbol(entry.value, top.name);
    }
    final statics = shape?.statics ?? const <String, DartMember>{};
    for (final entry in statics.entries) {
      namespace.putIfAbsent(
          entry.key, () => _dartMemberSymbol(entry.value, entry.value.type));
    }
    final unnamed = constructors[''];
    return Symbol(
      top.name,
      top.name,
      top.name,
      external: true,
      callable: unnamed != null,
      parameterTypes: unnamed == null
          ? const []
          : [for (final parameter in unnamed.parameters) parameter.$2],
      optionalParameters: unnamed?.optional ?? 0,
      namespace: namespace.isEmpty ? null : namespace,
      library: library,
      documentation: top.documentation,
      signature: dartTopHead(top),
      originFile: top.file.isEmpty ? null : top.file,
      originLine: top.line,
      originColumn: top.column,
      originOffset: top.offset,
    );
  }
  ConstValue? value;
  if (top.number != null) value = ConstDouble(top.number!);
  if (top.integer != null) value = ConstInt(top.integer!);
  return Symbol(
    top.name,
    top.name,
    top.type,
    external: top.callable,
    callable: top.callable,
    constant: top.constant,
    constantValue: value,
    parameterTypes: [for (final parameter in top.parameters) parameter.$2],
    optionalParameters: top.optional,
    library: library,
    documentation: top.documentation,
    signature: dartTopHead(top),
    originFile: top.file.isEmpty ? null : top.file,
    originLine: top.line,
    originColumn: top.column,
    originOffset: top.offset,
  );
}

Symbol _dartMemberSymbol(DartMember member, String type) {
  return Symbol(
    member.name,
    member.name,
    member.getter ? member.type : type,
    external: true,
    callable: !member.getter,
    parameterTypes: [for (final parameter in member.parameters) parameter.$2],
    optionalParameters: member.optional,
    documentation: member.documentation,
    signature: dartMemberHead(member),
    originFile: member.file.isEmpty ? null : member.file,
    originLine: member.line,
    originColumn: member.column,
    originOffset: member.offset,
  );
}

const _stringMembers = [
  'length',
  'isEmpty',
  'isNotEmpty',
  'chars',
  'lines',
  'contains',
  'startsWith',
  'endsWith',
  'substring',
  'toUpperCase',
  'toLowerCase',
  'trim',
  'split',
  'indexOf',
  'replaceAll',
  'take',
  'drop',
  'takeLast',
  'dropLast',
  'padStart',
  'padEnd',
];

const _iterableMembers = [
  'length',
  'isEmpty',
  'isNotEmpty',
  'first',
  'last',
  'contains',
  'elementAt',
  'join',
  'toList',
  'toSet',
  'map',
  'fold',
  'reduce',
  'sum',
  'min',
  'max',
  'count',
  'find',
  'findLast',
  'take',
  'zip',
  'drop',
  'takeLast',
  'dropLast',
  'skip',
  'sorted',
  'unique',
  'flat',
  'group',
  'where',
  'any',
  'every',
  'forEach',
];

const _listMembers = [
  'add',
  'addAll',
  'insert',
  'removeAt',
  'removeLast',
  'remove',
  'clear',
  'sort',
  'sublist',
  'indexOf',
  'reversed',
];

const _setMembers = ['add', 'addAll', 'remove', 'clear'];

const _mapMembers = [
  'length',
  'isEmpty',
  'isNotEmpty',
  'keys',
  'values',
  'containsKey',
  'remove',
  'clear',
  'addAll',
  'putIfAbsent',
  'forEach',
];

const _numberMembers = [
  'abs',
  'round',
  'floor',
  'ceil',
  'plain',
  'clamp',
  'fixed',
];

/// True when generated Dart should import this `quds:` library.
///
/// A prelude-only `use quds:core` does not. An alias is erased, so using only
/// an alias does not either. An `export` does, because the names leave the file.
bool emitsSdkImport(ImportDeclaration node, SemanticModel model) {
  if (model.skipped.contains(node)) return false;
  if (sdkLibraryName(node.uri) == null) return false;
  final names = model.sdkDartNames[node.uri] ?? const <String>{};
  if (names.isEmpty) return false;
  if (node.show.isNotEmpty && !node.show.any(names.contains)) return false;
  if (node.export) return true;
  return model.usedSdk.contains(node.uri);
}

class Analyzer {
  Analyzer({this.library = '<input>', String? file}) : _file = file ?? library;
  final model = SemanticModel();

  /// Privacy scope. A part file uses its parent's path.
  final String library;

  /// Path of the source being checked. Imports and parts resolve from here.
  final String _file;
  Map<String, Program> _libraries = const {};
  final _global = _Scope();
  late _Scope _scope = _global;
  final _checked = <FunctionDeclaration>{};
  final _checking = <FunctionDeclaration>{};
  final _typeNames = <String>{};
  final _pendingClasses = <String>{};
  final _typeBounds = <String, String>{};
  FunctionDeclaration? _function;
  String? _returnType;
  var _lambdaDepth = 0;
  var _lambdaAwait = false;
  int _nextName = 0;
  late final _constants = ConstantEvaluator(
    constants: model.constants,
    constantValueOf: (node) => model.references[node]?.constantValue,
    typeOf: (node) => model.types[node],
    constConstructorOf: (node) => model.constCalls[node],
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
          String reactive = '',
          bool field = false}) =>
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
              reactive: reactive,
              field: field,
              documentation: function?.documentation)
          .withFunction(function);
  String? _expected;
  String? _thisType;
  final _promoted = <String, String>{};
  final _fieldSymbols = <Symbol>{};
  var _readonlyMethod = false;
  var _ffi = false;

  /// True while binding a `quds:` library, so its own signatures are not uses.
  var _suppressSdkUse = false;

  /// Plain type name to its prefixed key while a prefixed SDK library is bound.
  final _importedTypes = <String, String>{};

  /// A `package:` URI ending in `.dart` was imported. Unknown names pass to Dart.
  var _externalDart = false;
  String? _doType;
  int _doDepth = 0;
  Never error(String code, String message, Node node) =>
      throw CompilerException(code, message, node.span);
  void warn(String code, String message, Node node) {
    model.warnings.add(CompilerException(code, message, node.span));
  }

  SemanticModel analyze(Program program,
      {Map<String, Program> libraries = const {}}) {
    _libraries = libraries;
    _global.symbols['print'] = Symbol('print', 'print', 'void');
    _global.symbols['expect'] = Symbol(
      'expect',
      'expect',
      'void',
      signature: 'expect(condition: bool) -> void',
      documentation:
          'Stops the current test when the condition is false. quds test reports that test as FAIL.',
    );
    _global.symbols['range'] = Symbol(
      'range',
      'range',
      'Range<num>',
      callable: true,
      signature: 'range(start: num, end: num) -> Range<num>',
      documentation:
          'Integers from start through end, including both ends. range(end) is range(0, end).',
    );
    for (final name in ['min', 'max']) {
      _global.symbols[name] = Symbol(
        name,
        name,
        'num',
        callable: true,
        signature: '$name(a: num, b: num) -> num',
        documentation: name == 'min'
            ? 'The smaller of two numbers of the same type.'
            : 'The larger of two numbers of the same type.',
      );
    }
    _global.symbols['missing'] =
        Symbol('missing', 'missing', 'Optional<Never>', constant: true);
    _global.symbols['present'] =
        Symbol('present', 'present', 'Optional', parameterTypes: const ['*']);
    _global.symbols['Ok'] =
        Symbol('Ok', 'Ok', 'Result', parameterTypes: const ['*']);
    _global.symbols['Error'] =
        Symbol('Error', 'Error', 'Result', parameterTypes: const ['*']);
    _installLog();
    for (final statement in program.statements) {
      if (statement is AliasDeclaration) {
        model.aliases[statement.name] = statement.target;
      }
      if (statement is ClassDeclaration) _pendingClasses.add(statement.name);
    }
    _bindParts(program);
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
        case AnnotationDeclaration():
          registerAnnotation(statement);
        case ConfigDeclaration():
          registerConfig(statement);
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
    for (final statement in program.statements) {
      switch (statement) {
        case ClassDeclaration():
          _checkMetadata(statement.annotations);
          for (final method in statement.methods) {
            _checkMetadata(method.annotations);
          }
        case FunctionDeclaration():
          _checkMetadata(statement.annotations);
        case ExtensionDeclaration():
          for (final method in statement.methods) {
            _checkMetadata(method.annotations);
          }
        case AnnotationDeclaration():
          for (final parameter in statement.parameters) {
            final value = parameter.defaultValue;
            if (value == null) continue;
            final type = expression(value);
            if (!compatible(type, parameter.type)) {
              fail('Cannot initialize ${parameter.type} with $type', value);
            }
            _constants.ensureConstant(value);
          }
        default:
          break;
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
        for (final field in statement.fields) {
          if (field.lazyBody != null) analyzeLazy(statement, field);
        }
      }
      if (statement is ExtensionDeclaration) {
        for (final method in statement.methods) {
          analyzeExtension(statement, method);
        }
        for (final property in statement.properties) {
          analyzeExtensionProperty(statement, property);
        }
      }
    }
    if (model.parts.any((part) => part.of) &&
        model.parts.any((part) => !part.of)) {
      final mismatched = model.parts.firstWhere((part) => part.of);
      error('E903', 'part of does not match the library', mismatched);
    }
    _checkSingletonCycles();
    model.moduleSymbols.addAll(_global.symbols);
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
    final savedTypes = {..._typeNames};
    _typeNames.addAll(statement.typeParameters.map((item) => item.name));
    if (effective != '<infer>') validateType(effective, statement);
    for (final parameter in statement.typeParameters) {
      if (parameter.bound != null) {
        validateType(parameter.bound!, parameter, allowVoid: false);
      }
    }
    _typeNames
      ..clear()
      ..addAll(savedTypes);
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

  void registerClass(ClassDeclaration statement,
      {String? library, String? scopeName}) {
    final key = scopeName ?? statement.name;
    final owner = library ?? this.library;
    final existing = _global.symbols[key];
    if (existing?.classDeclaration == statement) {
      model.libraryOf[statement] = owner;
      return;
    }
    if (_global.lookup(key) != null) {
      fail('Duplicate name: $key', statement);
    }
    final symbol = Symbol(key, key, key,
        classDeclaration: statement,
        library: owner,
        documentation: statement.documentation);
    model.libraryOf[statement] = owner;
    if (statement.kind == 'enum') model.enumNames.add(key);
    _global.symbols[key] = symbol;
    model.declarations[statement] = symbol;
    model.classes[key] = statement;
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
    final savedTypes = {..._typeNames};
    _typeNames.addAll(statement.typeParameters.map((item) => item.name));
    for (final parameter in statement.typeParameters) {
      if (parameter.bound != null) {
        validateType(parameter.bound!, parameter, allowVoid: false);
      }
    }
    for (final field in statement.fields) {
      if (field.type == '<infer>') continue;
      validateType(field.type, field, allowVoid: false);
    }
    _checkVariance(statement);
    if (hasAnnotation(statement.annotations, 'Reflectable')) {
      model.reflectable.add(statement);
    }
    for (final field in statement.fields.where((item) => item.isStatic)) {
      if (field.lazyBody != null) continue;
      analyzeStaticField(field);
    }
    for (final method in statement.methods) {
      if (hasAnnotation(statement.annotations, 'macro') &&
          method.name == 'define') {
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
      final added = method.typeParameters
          .map((item) => item.name)
          .where((name) => !_typeNames.contains(name))
          .toList();
      _typeNames.addAll(added);
      if (effective != '<infer>') validateType(effective, method);
      _typeNames.removeAll(added);
      final dartName = method.isOperator
          ? method.name
          : method.visibility == 'private' && !method.name.startsWith('_')
              ? '_${method.name}'
              : method.name;
      final symbol = Symbol(method.name, dartName, effective, function: method)
          .withFunction(method);
      model.declarations[method] = symbol;
    }
    _typeNames
      ..clear()
      ..addAll(savedTypes);
  }

  void registerExtension(ExtensionDeclaration statement,
      {String library = ''}) {
    model.extensions.add(statement);
    final savedTypes = {..._typeNames};
    _typeNames.addAll(statement.typeParameters.map((item) => item.name));
    for (final method in statement.methods) {
      final type = method.returnType ??
          (method.expressionBody == null ? 'void' : '<infer>');
      if (type != '<infer>') validateType(type, method);
      final symbol = Symbol(method.name, method.name, type,
              function: method,
              library: library,
              documentation: method.documentation)
          .withFunction(method);
      model.declarations[method] = symbol;
    }
    _typeNames
      ..clear()
      ..addAll(savedTypes);
  }

  void checkShape(ClassDeclaration type) {
    if (type.modifiers.contains('singleton')) {
      for (final field in type.fields) {
        if (field.initializer == null && field.lazyBody == null) {
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
        if (field.mutable ||
            field.initializer != null ||
            field.lazyBody != null) {
          continue;
        }
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
    if (parent != null) _rejectSealedOutside(type, parent);
    for (final name in type.interfaces) {
      final face = _global.symbols[name]?.classDeclaration;
      if (face != null) _rejectSealedOutside(type, face);
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
    for (final constructor in type.constructors) {
      for (final parameter in constructor.parameters) {
        if (parameter.initializing != 'this') continue;
        final lazy = type.fields.where(
            (field) => field.name == parameter.name && field.lazyBody != null);
        if (lazy.isNotEmpty) {
          fail('by lazy is not a constructor parameter', parameter);
        }
      }
    }
    _checkMixinChain(type);
  }

  void _checkMixinChain(ClassDeclaration type) {
    if (type.mixins.isEmpty) return;
    final members = <String, (List<String>, String, String)>{};
    void add(String owner, String name, List<String> parameters, String returns,
        bool fromMixin) {
      final previous = members[name];
      if (fromMixin &&
          previous != null &&
          !_overrideFits(previous.$1, previous.$2, parameters, returns)) {
        error('E300', '$owner.$name does not override ${previous.$3}.$name',
            type);
      }
      members[name] = (parameters, returns, owner);
    }

    void take(ClassDeclaration source, bool fromMixin) {
      for (final field in source.fields) {
        if (field.isStatic) continue;
        add(source.name, field.name, const [], field.type, fromMixin);
      }
      for (final method in source.methods) {
        if (method.isStatic || method.isOperator) continue;
        final returns =
            model.declarations[method]?.type ?? method.returnType ?? 'void';
        add(
            source.name,
            method.name,
            [for (final parameter in method.parameters) parameter.type],
            returns,
            fromMixin);
      }
    }

    var parentName = type.superclass;
    final parents = <ClassDeclaration>[];
    while (parentName != null) {
      final parent = _global.symbols[parentName]?.classDeclaration;
      if (parent == null) break;
      parents.add(parent);
      parentName = parent.superclass;
    }
    for (final parent in parents.reversed) {
      take(parent, false);
    }
    for (final name in type.mixins) {
      final mixin = _global.symbols[name]?.classDeclaration;
      if (mixin != null) take(mixin, true);
    }
  }

  bool _overrideFits(List<String> baseParameters, String baseReturns,
      List<String> nextParameters, String nextReturns) {
    if (baseParameters.length != nextParameters.length) return false;
    if (baseReturns == '<infer>' || nextReturns == '<infer>') return true;
    if (baseReturns == 'void' || nextReturns == 'void') {
      if (baseReturns != nextReturns) return false;
    } else if (!compatible(nextReturns, baseReturns)) {
      return false;
    }
    for (var i = 0; i < baseParameters.length; i++) {
      if (!compatible(baseParameters[i], nextParameters[i])) return false;
    }
    return true;
  }

  void _checkSingletonCycles() {
    final nodes = <String, ClassDeclaration>{};
    final edges = <String, Set<String>>{};
    for (final type in model.classes.values) {
      if (!type.modifiers.contains('singleton')) continue;
      nodes[type.name] = type;
      final refs = <String>{};
      for (final field in type.fields) {
        final initial = field.initializer;
        if (initial == null) continue;
        walkAst(initial, (node) {
          if (node is MemberAccess &&
              node.name == 'instance' &&
              node.object is Identifier) {
            refs.add((node.object as Identifier).name);
          }
        });
      }
      edges[type.name] = refs;
    }
    final state = <String, int>{};
    void visit(String name) {
      final mark = state[name] ?? 0;
      if (mark == 1) {
        error('E707', 'Singleton initialization cycles', nodes[name]!);
      }
      if (mark != 0) return;
      state[name] = 1;
      for (final next in edges[name] ?? const <String>{}) {
        if (nodes.containsKey(next)) visit(next);
      }
      state[name] = 2;
    }

    for (final name in nodes.keys) {
      visit(name);
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
    final savedTypes = {..._typeNames};
    _typeNames.addAll(type.typeParameters.map((item) => item.name));
    analyzeFunction(method);
    _typeNames
      ..clear()
      ..addAll(savedTypes);
    _thisType = savedThis;
    _scope = saved;
  }

  void analyzeLazy(ClassDeclaration type, FieldDeclaration field) {
    if (type.kind == 'interface') fail('by lazy needs a class', field);
    final saved = _scope;
    final savedThis = _thisType;
    final savedDepth = _doDepth;
    final savedResult = _doType;
    _scope = _Scope(_global);
    _doDepth++;
    _doType = null;
    if (field.isStatic) {
      _thisType = null;
    } else {
      _thisType = type.name;
      _installFields(type);
    }
    String? produced;
    try {
      statements(field.lazyBody!);
      produced = _doType;
    } finally {
      _doDepth = savedDepth;
      _doType = savedResult;
      _thisType = savedThis;
      _scope = saved;
    }
    if (produced == null) {
      error('E109', 'by lazy must finish with result', field);
    }
    final declared = field.type == '<infer>' ? produced : field.type;
    if (field.type != '<infer>') {
      validateType(field.type, field, allowVoid: false);
      if (!compatible(produced, declared)) {
        fail('Cannot initialize $declared with $produced', field);
      }
    }
    final dart = field.visibility == 'private' && !field.name.startsWith('_')
        ? '_${field.name}'
        : field.name;
    model.declarations[field] =
        Symbol(field.name, dart, declared, field: !field.isStatic);
  }

  void analyzeExtensionProperty(
      ExtensionDeclaration type, PropertyDeclaration property) {
    final saved = _scope;
    final savedThis = _thisType;
    _scope = _Scope(_global);
    _thisType = type.target;
    final savedTypes = {..._typeNames};
    _typeNames.addAll(type.typeParameters.map((item) => item.name));
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
    _typeNames
      ..clear()
      ..addAll(savedTypes);
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
    if (hasAnnotation(type.annotations, 'macro') && method.name == 'define') {
      return;
    }
    final saved = _scope;
    final savedThis = _thisType;
    final savedReadonly = _readonlyMethod;
    _scope = _Scope(_global);
    _thisType = type.onType ?? type.name;
    final savedTypes = {..._typeNames};
    _typeNames
      ..addAll(type.typeParameters.map((item) => item.name))
      ..addAll(method.typeParameters.map((item) => item.name));
    final savedBounds = {..._typeBounds};
    for (final parameter in [
      ...type.typeParameters,
      ...method.typeParameters
    ]) {
      if (parameter.bound != null) {
        _typeBounds[parameter.name] = parameter.bound!;
      }
    }
    _readonlyMethod = method.readonlyMethod;
    _installFields(type);
    analyzeFunction(method);
    _checkOverride(type, method);
    _typeNames
      ..clear()
      ..addAll(savedTypes);
    _typeBounds
      ..clear()
      ..addAll(savedBounds);
    _readonlyMethod = savedReadonly;
    _thisType = savedThis;
    _scope = saved;
  }

  void analyzeConstructor(
      ClassDeclaration type, ConstructorDeclaration constructor) {
    if (constructor.constant && constructor.body != null) {
      error('E401', 'A const constructor cannot have a body', constructor);
    }
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
          mutable: assignable || field.mutable, field: true);
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
    if (node.uri.startsWith('quds:')) {
      _bindQuds(node);
      return;
    }
    if (node.uri == 'dart:ffi') _ffi = true;
    if (node.uri.startsWith('dart:')) {
      _bindDart(node);
      return;
    }
    if (node.uri.startsWith('package:') && node.uri.endsWith('.dart')) {
      final quds = resolveLibraryPath(_file, node.uri);
      if (quds != null && File(quds).existsSync()) {
        _bindPackage(node);
        return;
      }
      _externalDart = true;
      final library = packageDartFile(_file, node.uri);
      if (library != null) {
        try {
          final surface = readDartFile(library);
          if (surface != null) _bindSurface(node, surface);
        } catch (_) {
          // The file stays an external library. Unknown names remain dynamic.
        }
      }
      if (node.prefix != null) {
        final space = _space(node.prefix!, node);
        final current = _global.symbols[node.prefix!]!;
        if (!current.external) {
          _global.symbols[node.prefix!] = Symbol(
              current.name, current.dartName, current.type,
              namespace: space, external: true);
        }
      }
      return;
    }
    if (node.uri.startsWith('package:') || node.uri.startsWith('generated:')) {
      _bindPackage(node);
      return;
    }
    if (!node.uri.endsWith('.quds')) {
      fail('Unknown import: ${node.uri}', node);
    }
    if (_file == '<input>') return;
    final path = _resolveLibrary(_file, node.uri);
    if (path == _file) return;
    final imported = _libraries[path];
    if (imported == null) fail('Unknown import: ${node.uri}', node);
    final filter = node.show.isEmpty && node.hide.isEmpty ? null : node;
    if (node.export) {
      _importLibrary(imported, path, filter: node, bind: false);
      return;
    }
    _importLibrary(imported, path, filter: filter, qualify: node.prefix);
  }

  static const _preludeNames = [
    'Optional',
    'missing',
    'present',
    'Result',
    'Ok',
    'Error'
  ];

  void _bindQuds(ImportDeclaration node) {
    final libraryName = sdkLibraryName(node.uri);
    final prelude = node.uri == 'quds:core';
    final imported = libraryName == null ? null : _libraries[node.uri];
    if (libraryName == null || (imported == null && !prelude)) {
      fail('Unknown import: ${node.uri}', node);
    }
    final dartNames = imported == null ? <String>{} : _sdkDartNames(imported);
    final aliasNames = imported == null ? <String>{} : _sdkAliasNames(imported);
    if (node.show.isNotEmpty) {
      for (final name in node.show) {
        final inPrelude = prelude && _preludeNames.contains(name);
        if (!inPrelude &&
            !dartNames.contains(name) &&
            !aliasNames.contains(name)) {
          error('E200', 'Name $name is not defined', node);
        }
      }
    }
    if (prelude) _bindPrelude(node, allowOther: imported != null);
    if (imported == null) return;
    model.sdkDartNames[node.uri] = dartNames;
    model.resolvedImports[node] = sdkDartFileName(libraryName);
    if (node.show.isNotEmpty &&
        !node.show.any(
            (name) => dartNames.contains(name) || aliasNames.contains(name))) {
      return;
    }
    final filter = _sdkFilter(node, {...dartNames, ...aliasNames});
    final previous = _suppressSdkUse;
    _suppressSdkUse = true;
    if (node.prefix != null) {
      for (final name in dartNames) {
        _importedTypes[name] = '${node.prefix}.$name';
      }
    }
    try {
      if (node.export) {
        _importLibrary(imported, node.uri,
            filter: filter, bind: false, check: false);
        return;
      }
      _importLibrary(imported, node.uri,
          filter: filter, qualify: node.prefix, check: false);
    } finally {
      if (node.prefix != null) {
        for (final name in dartNames) {
          _importedTypes.remove(name);
        }
      }
      _suppressSdkUse = previous;
    }
  }

  Set<String> _sdkDartNames(Program program) {
    final names = <String>{};
    for (final statement in program.statements) {
      switch (statement) {
        case ClassDeclaration() when !statement.name.startsWith('_'):
          names.add(statement.name);
        case FunctionDeclaration()
            when statement.name != 'main' && !statement.name.startsWith('_'):
          names.add(statement.name);
        case ExtensionDeclaration()
            when statement.name != null && !statement.name!.startsWith('_'):
          names.add(statement.name!);
        case ImportDeclaration() when statement.export:
          names.addAll(_exportedDartNames(statement));
        default:
          break;
      }
    }
    return names;
  }

  /// Public names of a `dart:` library re-exported by [node], or empty when
  /// [node] exports something else.
  Set<String> _exportedDartNames(ImportDeclaration node) {
    if (!node.uri.startsWith('dart:')) return const {};
    final surface = readDartLibrary(node.uri);
    if (surface == null) fail('Unknown import: ${node.uri}', node);
    return {
      for (final name in surface.names.keys)
        if (_keeps(name, node)) name,
    };
  }

  /// Binds names from `export dart:...` into the library that imported the
  /// exporter. A name already in scope, such as prelude `min`, stays as it is.
  void _importDartExport(ImportDeclaration statement,
      {required String home, ImportDeclaration? filter, String? qualify}) {
    final surface = readDartLibrary(statement.uri);
    if (surface == null) fail('Unknown import: ${statement.uri}', statement);
    final restricted = _restrict(filter, statement);
    final target =
        qualify == null ? _global.symbols : _space(qualify, statement);
    for (final entry in surface.names.entries) {
      if (!_keeps(entry.key, restricted)) continue;
      if (target.containsKey(entry.key)) {
        if (qualify != null) {
          error('E204', 'Two imports define ${entry.key}', statement);
        }
        continue;
      }
      final shape = surface.types[entry.key];
      if (shape != null) model.dartShapes[entry.key] = shape;
      target[entry.key] = symbolForDart(entry.value, shape, home);
    }
  }

  Set<String> _sdkAliasNames(Program program) => {
        for (final statement in program.statements)
          if (statement is AliasDeclaration && !statement.name.startsWith('_'))
            statement.name,
      };

  ImportDeclaration? _sdkFilter(ImportDeclaration node, Set<String> names) {
    if (node.show.isNotEmpty) {
      final shown = [
        for (final name in node.show)
          if (names.contains(name)) name,
      ];
      if (shown.isEmpty) return node;
      return ImportDeclaration(node.uri, node.prefix, node.span, show: shown);
    }
    if (node.hide.isNotEmpty) return node;
    return null;
  }

  void _bindPrelude(ImportDeclaration node, {bool allowOther = false}) {
    if (node.show.isNotEmpty) {
      for (final name in node.show) {
        if (_preludeNames.contains(name)) continue;
        if (allowOther) continue;
        error('E200', 'Name $name is not defined', node);
      }
    }
    final selected = node.show.isNotEmpty
        ? node.show.toSet()
        : _preludeNames.where((name) => !node.hide.contains(name)).toSet();
    if (node.prefix == null) {
      for (final name in _preludeNames) {
        if (selected.contains(name)) continue;
        _global.symbols.remove(name);
        model.hiddenTypes.add(name);
      }
      return;
    }
    final space = _space(node.prefix!, node);
    for (final name in _preludeNames) {
      final symbol = _global.symbols.remove(name);
      if (!selected.contains(name)) {
        model.hiddenTypes.add(name);
        continue;
      }
      if (symbol != null) space[name] = symbol;
    }
  }

  void _bindDart(ImportDeclaration node) {
    DartSurface? surface;
    try {
      surface = readDartLibrary(node.uri);
    } catch (_) {
      surface = null;
    }
    if (surface == null) return;
    _bindSurface(node, surface);
  }

  void _bindSurface(ImportDeclaration node, DartSurface surface) {
    model.dartShapes.addAll(surface.types);
    if (node.show.isNotEmpty) {
      for (final name in node.show) {
        if (!surface.names.containsKey(name)) {
          error('E200', 'Name $name is not defined', node);
        }
      }
    }
    final selected = node.show.isNotEmpty
        ? node.show
        : surface.names.keys.where((name) => !node.hide.contains(name));
    final target =
        node.prefix == null ? _global.symbols : _space(node.prefix!, node);
    for (final name in selected) {
      if (node.prefix == null && target.containsKey(name)) continue;
      final top = surface.names[name];
      if (top == null) continue;
      target[name] = symbolForDart(top, surface.types[name]);
    }
  }

  Map<String, Symbol> _space(String prefix, Node node) {
    final existing = _global.symbols[prefix];
    if (existing?.namespace != null) return existing!.namespace!;
    if (existing != null) fail('Duplicate name: $prefix', node);
    final space = <String, Symbol>{};
    _global.symbols[prefix] =
        Symbol(prefix, prefix, 'prefix', namespace: space);
    return space;
  }

  void _bindPackage(ImportDeclaration node) {
    if (_file == '<input>') {
      if (node.uri.startsWith('generated:')) {
        fail('Unknown import: ${node.uri}', node);
      }
      return;
    }
    final path = resolveLibraryPath(_file, node.uri);
    if (path == null) {
      if (node.uri.startsWith('package:')) return;
      fail('Unknown import: ${node.uri}', node);
    }
    final imported = _libraries[path];
    if (imported == null) fail('Unknown import: ${node.uri}', node);
    final dartUri = dartLibraryUri(_file, node.uri);
    if (dartUri != null) model.resolvedImports[node] = dartUri;
    if (path == _file) return;
    final filter = node.show.isEmpty && node.hide.isEmpty ? null : node;
    if (node.export) {
      _importLibrary(imported, path, filter: node, bind: false);
      return;
    }
    _importLibrary(imported, path, filter: filter, qualify: node.prefix);
  }

  String _resolveLibrary(String from, String uri) {
    if (uri.startsWith('quds:')) return uri;
    final resolved = resolveLibraryPath(from, uri);
    if (resolved != null) return resolved;
    final target = Uri.file(from).resolve(uri);
    if (target.scheme != 'file' && target.scheme.isNotEmpty) return uri;
    return target.toFilePath();
  }

  bool _keeps(String name, ImportDeclaration? filter) {
    if (filter == null) return true;
    if (filter.show.isNotEmpty) return filter.show.contains(name);
    return !filter.hide.contains(name);
  }

  bool _importable(String name, String home) =>
      name == 'main' ? false : !name.startsWith('_') || home == library;

  ImportDeclaration _restrict(
      ImportDeclaration? outer, ImportDeclaration export) {
    if (outer == null || (outer.show.isEmpty && outer.hide.isEmpty)) {
      return export;
    }
    if (outer.show.isNotEmpty) {
      final names = [
        for (final name in outer.show)
          if ((export.show.isEmpty || export.show.contains(name)) &&
              !export.hide.contains(name))
            name,
      ];
      return ImportDeclaration(export.uri, export.prefix, export.span,
          export: true, show: names);
    }
    if (export.show.isNotEmpty) {
      final names = [
        for (final name in export.show)
          if (!outer.hide.contains(name) && !export.hide.contains(name)) name,
      ];
      return ImportDeclaration(export.uri, export.prefix, export.span,
          export: true, show: names);
    }
    return ImportDeclaration(export.uri, export.prefix, export.span,
        export: true, hide: [...outer.hide, ...export.hide]);
  }

  Set<String> _publicNames(Program program, String path, Set<String> seen) {
    if (!seen.add(path)) return {};
    final names = <String>{};
    for (final statement in program.statements) {
      switch (statement) {
        case ClassDeclaration() when !statement.name.startsWith('_'):
          names.add(statement.name);
        case FunctionDeclaration()
            when statement.name != 'main' && !statement.name.startsWith('_'):
          names.add(statement.name);
        case AliasDeclaration() when !statement.name.startsWith('_'):
          names.add(statement.name);
        case ExtensionDeclaration()
            when statement.name != null && !statement.name!.startsWith('_'):
          names.add(statement.name!);
        case ImportDeclaration() when statement.export:
          final dartNames = _exportedDartNames(statement);
          if (statement.uri.startsWith('dart:')) {
            names.addAll(dartNames);
            break;
          }
          final exportedPath = _resolveLibrary(path, statement.uri);
          final exported = _libraries[exportedPath];
          if (exported == null) {
            fail('Unknown import: ${statement.uri}', statement);
          }
          names.addAll(_publicNames(exported, exportedPath, seen)
              .where((name) => _keeps(name, statement)));
        case PartDirective() when !statement.of:
          final partPath = _resolveLibrary(path, statement.uri);
          final part = _libraries[partPath];
          if (part != null) names.addAll(_publicNames(part, partPath, seen));
        default:
          break;
      }
    }
    return names;
  }

  void _importLibrary(Program imported, String path,
      {Set<String>? seen,
      ImportDeclaration? filter,
      String? qualify,
      String? privacy,
      bool bind = true,
      bool check = true}) {
    final visited = seen ?? <String>{};
    if (!visited.add(path)) return;
    final home = privacy ?? path;
    if (check && filter != null && filter.show.isNotEmpty) {
      final available = _publicNames(imported, path, {});
      for (final name in filter.show) {
        if (!available.contains(name)) {
          error('E200', 'Name $name is not defined', filter);
        }
      }
    }
    if (!bind) return;
    for (final statement in imported.statements) {
      switch (statement) {
        case ClassDeclaration()
            when _importable(statement.name, home) &&
                _keeps(statement.name, filter):
          _importClass(statement, home: home, qualify: qualify);
        case FunctionDeclaration()
            when _importable(statement.name, home) &&
                _keeps(statement.name, filter):
          _importFunction(statement, qualify: qualify, library: home);
        case AliasDeclaration()
            when _importable(statement.name, home) &&
                _keeps(statement.name, filter):
          _importAlias(statement, home: home, qualify: qualify);
        case ExtensionDeclaration()
            when statement.name != null &&
                _importable(statement.name!, home) &&
                _keeps(statement.name!, filter):
          _importExtension(statement, home: home, qualify: qualify);
        case ImportDeclaration() when statement.export:
          if (statement.uri.startsWith('dart:')) {
            _importDartExport(statement,
                home: home, filter: filter, qualify: qualify);
            break;
          }
          final exportedPath = _resolveLibrary(path, statement.uri);
          final exported = _libraries[exportedPath];
          if (exported == null) {
            fail('Unknown import: ${statement.uri}', statement);
          }
          _importLibrary(exported, exportedPath,
              seen: visited,
              filter: _restrict(filter, statement),
              qualify: qualify,
              check: false);
        case PartDirective() when !statement.of:
          final partPath = _resolveLibrary(path, statement.uri);
          if (partPath == _file) break;
          final part = _libraries[partPath];
          if (part == null) break;
          _importLibrary(part, partPath,
              seen: visited,
              filter: filter,
              qualify: qualify,
              privacy: home,
              check: false);
        default:
          break;
      }
    }
  }

  void _importClass(ClassDeclaration statement,
      {required String home, String? qualify}) {
    final key = qualify == null ? statement.name : '$qualify.${statement.name}';
    final existing = qualify == null
        ? _global.symbols[statement.name]
        : _space(qualify, statement)[statement.name];
    if (existing?.classDeclaration == statement) {
      model.libraryOf[statement] = home;
      return;
    }
    if (existing != null) {
      error('E204', 'Two imports define ${statement.name}', statement);
    }
    registerClass(statement, library: home, scopeName: key);
    if (qualify != null) {
      _space(qualify, statement)[statement.name] = _global.symbols[key]!;
    }
  }

  void _importAlias(AliasDeclaration statement,
      {required String home, String? qualify}) {
    final key = qualify == null ? statement.name : '$qualify.${statement.name}';
    if (model.sdkAliases[key] == home) return;
    if (model.aliases.containsKey(key) ||
        (qualify == null && _global.lookup(statement.name) != null)) {
      error('E204', 'Two imports define ${statement.name}', statement);
    }
    model.aliases[key] = statement.target;
    model.sdkAliases[key] = home;
  }

  void _importExtension(ExtensionDeclaration statement,
      {required String home, String? qualify}) {
    if (model.extensions.contains(statement)) return;
    if (qualify != null) return;
    registerExtension(statement, library: home);
  }

  void _importFunction(FunctionDeclaration statement,
      {String? qualify, String library = ''}) {
    final existing = qualify == null
        ? _global.symbols[statement.name]
        : _space(qualify, statement)[statement.name];
    if (existing?.function == statement) return;
    if (existing != null) {
      error('E204', 'Two imports define ${statement.name}', statement);
    }
    final type =
        statement.returnType ?? (statement.isAsync ? 'Future<void>' : 'void');
    final effective = statement.isAsync &&
            statement.returnType != null &&
            !statement.returnType!.startsWith('Future<')
        ? 'Future<${statement.returnType}>'
        : type;
    final symbol = Symbol(statement.name, statement.name, effective,
            function: statement,
            library: library,
            documentation: statement.documentation)
        .withFunction(statement);
    model.declarations[statement] = symbol;
    for (final parameter in statement.parameters) {
      model.declarations[parameter] = Symbol(
          parameter.name, parameter.name, parameter.type,
          mutable: parameter.mutable);
    }
    if (qualify == null) {
      _global.symbols[statement.name] = symbol;
      return;
    }
    _space(qualify, statement)[statement.name] = symbol;
  }

  void _bindParts(Program program) {
    if (_file == '<input>') return;
    final directives = program.statements.whereType<PartDirective>().toList();
    final parts = directives.where((item) => !item.of).toList();
    final ofs = directives.where((item) => item.of).toList();
    if (parts.isNotEmpty && ofs.isNotEmpty) return;
    if (ofs.length > 1) {
      error('E903', 'part of does not match the library', ofs[1]);
    }
    if (ofs.length == 1) _bindPartOf(ofs.single);
    for (final part in parts) {
      _bindPart(part);
    }
  }

  void _bindPart(PartDirective node) {
    final path = _resolveLibrary(_file, node.uri);
    final program = _libraries[path];
    if (program == null) fail('Unknown import: ${node.uri}', node);
    final ofs = program.statements
        .whereType<PartDirective>()
        .where((item) => item.of)
        .toList();
    final nested =
        program.statements.whereType<PartDirective>().where((item) => !item.of);
    if (nested.isNotEmpty || ofs.length != 1) {
      error('E903', 'part of does not match the library', node);
    }
    final declared = _resolveLibrary(path, ofs.single.uri);
    if (declared != _file) {
      error('E903', 'part of does not match the library', node);
    }
    _importLibrary(program, path, privacy: library, check: false);
  }

  void _bindPartOf(PartDirective node) {
    final parent = _resolveLibrary(_file, node.uri);
    final program = _libraries[parent];
    if (program == null) {
      error('E903', 'part of does not match the library', node);
    }
    final listed = program.statements
        .whereType<PartDirective>()
        .where((item) => !item.of)
        .any((item) => _resolveLibrary(parent, item.uri) == _file);
    if (!listed) {
      error('E903', 'part of does not match the library', node);
    }
    _importLibrary(program, parent, privacy: library, check: false);
    for (final sibling in program.statements
        .whereType<PartDirective>()
        .where((item) => !item.of)) {
      final path = _resolveLibrary(parent, sibling.uri);
      if (path == _file) continue;
      final part = _libraries[path];
      if (part == null) continue;
      _importLibrary(part, path, privacy: library, check: false);
    }
  }

  void _checkMember(ClassDeclaration type, String name, Node node) {
    final owner = _declarer(type, name);
    if (owner == null) return;
    final visibility = _visibility(owner, name);
    if (visibility.isEmpty) return;
    final home =
        model.libraryOf[owner] ?? _global.symbols[owner.name]?.library ?? '';
    if (home.isEmpty || home == library) return;
    if (visibility == 'private') {
      error('E206', 'A private name is used outside its library', node);
    }
    if (visibility == 'protected' && !_insideSubtype(owner)) {
      error('E207', 'A protected name is used outside a subtype or its library',
          node);
    }
  }

  ClassDeclaration? _declarer(ClassDeclaration type, String name) {
    if (type.fields.any((field) => field.name == name) ||
        type.properties.any((property) => property.name == name) ||
        type.methods.any((method) => method.name == name)) {
      return type;
    }
    final parent = type.superclass == null
        ? null
        : _global.symbols[type.superclass!]?.classDeclaration;
    if (parent == null) return null;
    return _declarer(parent, name);
  }

  String _visibility(ClassDeclaration type, String name) {
    for (final field in type.fields) {
      if (field.name == name) return field.visibility;
    }
    for (final property in type.properties) {
      if (property.name == name) return property.visibility;
    }
    for (final method in type.methods) {
      if (method.name == name) return method.visibility;
    }
    return '';
  }

  bool _insideSubtype(ClassDeclaration type) {
    var name = _thisType;
    while (name != null) {
      final declaration = _global.symbols[name]?.classDeclaration;
      if (declaration == type || name == type.name) return true;
      final parent = declaration?.superclass;
      if (parent == null || parent == name) return false;
      name = parent;
    }
    return false;
  }

  void _touch(Symbol symbol) {
    if (_suppressSdkUse) return;
    if (symbol.library.startsWith('quds:')) model.usedSdk.add(symbol.library);
  }

  void validateType(String type, Node node, {bool allowVoid = true}) {
    if (_importedTypes.containsKey(type)) return;
    final resolved = model.resolve(type);
    if (resolved != type) {
      validateType(resolved, node, allowVoid: allowVoid);
      return;
    }
    if (type.startsWith('readonly ')) {
      validateType(type.substring(9), node, allowVoid: false);
      return;
    }
    if (_typeNames.contains(type) ||
        type == 'dynamic' ||
        type == 'Never' ||
        type == 'Invocation') {
      return;
    }
    if (type.contains(' & ')) {
      final parts = type.split(' & ').map((part) => part.trim()).toList();
      _checkIntersection(parts, node);
      for (final part in parts) {
        validateType(part, node, allowVoid: false);
      }
      return;
    }
    if (type.contains(' | ')) {
      for (final part in type.split(' | ')) {
        validateType(part.trim(), node, allowVoid: false);
      }
      return;
    }
    if (type.startsWith('(') && type.endsWith(')?')) {
      validateType(type.substring(1, type.length - 2), node, allowVoid: true);
      return;
    }
    if (type.startsWith('(') && type.contains('->')) {
      final (parameters, returns) = _functionParts(type);
      if (parameters.trim().isNotEmpty) {
        for (final part in _splitTypes(parameters)) {
          final declared =
              part.contains(':') ? part.split(':').last.trim() : part;
          validateType(declared, node, allowVoid: false);
        }
      }
      validateType(returns, node, allowVoid: true);
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
    if (_ffi && _ffiNative.contains(type)) return;
    if (_ffi && type.startsWith('Pointer<') && type.endsWith('>')) {
      validateType(type.substring(8, type.length - 1), node, allowVoid: false);
      return;
    }
    if (type.endsWith('?')) {
      validateType(type.substring(0, type.length - 1), node, allowVoid: false);
      return;
    }
    if (type.startsWith('Event<') && type.endsWith('>')) {
      validateType(type.substring(6, type.length - 1), node, allowVoid: true);
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
      final parts = _splitTypes(type.substring(4, type.length - 1));
      if (parts.length != 2) fail('Unsupported type: $type', node);
      validateType(parts[0], node, allowVoid: false);
      validateType(parts[1], node, allowVoid: false);
      return;
    }
    if (type.startsWith('Optional<') && type.endsWith('>')) {
      if (model.hiddenTypes.contains('Optional')) {
        fail('Name Optional is not defined', node);
      }
      validateType(type.substring(9, type.length - 1), node, allowVoid: false);
      return;
    }
    if (type.startsWith('Result<') && type.endsWith('>')) {
      if (model.hiddenTypes.contains('Result')) {
        fail('Name Result is not defined', node);
      }
      final parts = _splitTypes(type.substring(7, type.length - 1));
      if (parts.length != 2) fail('Unsupported type: $type', node);
      validateType(parts[0], node, allowVoid: false);
      validateType(parts[1], node, allowVoid: false);
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
    if (type.startsWith('(') && type.endsWith(')')) {
      final inner = type.substring(1, type.length - 1);
      if (inner.isEmpty) return;
      for (final part in inner.split(',')) {
        validateType(part.trim(), node, allowVoid: false);
      }
      return;
    }
    final named = _global.symbols[type];
    if (named?.classDeclaration != null ||
        named?.classCase != null ||
        _pendingClasses.contains(type)) {
      if (named != null) _touch(named);
      return;
    }
    final open = type.indexOf('<');
    if (open > 0 && type.endsWith('>')) {
      final head = type.substring(0, open);
      if (_global.symbols[head]?.classDeclaration != null) {
        final inner = type.substring(open + 1, type.length - 1);
        for (final part in _splitTypes(inner)) {
          validateType(part, node, allowVoid: false);
        }
        return;
      }
    }
    if (_externalDart) {
      final openExternal = type.indexOf('<');
      if (openExternal > 0 && type.endsWith('>')) {
        final inner = type.substring(openExternal + 1, type.length - 1);
        if (inner.trim().isNotEmpty) {
          for (final part in _splitTypes(inner)) {
            validateType(part, node, allowVoid: false);
          }
        }
      }
      return;
    }
    fail('Unsupported type: $type', node);
  }

  bool _declaredAtTopLevel(FunctionDeclaration function) {
    bool owns(Symbol? symbol) =>
        symbol != null && symbol.overloads.contains(function);
    if (owns(_global.symbols[function.name])) return true;
    for (final symbol in _global.symbols.values) {
      final space = symbol.namespace;
      if (space != null && owns(space[function.name])) return true;
    }
    return false;
  }

  void analyzeFunction(FunctionDeclaration function) {
    final savedTypes = {..._typeNames};
    final savedBounds = {..._typeBounds};
    _typeNames.addAll(function.typeParameters.map((item) => item.name));
    for (final parameter in function.typeParameters) {
      if (parameter.bound != null) {
        _typeBounds[parameter.name] = parameter.bound!;
      }
    }
    if (_checked.contains(function)) {
      _typeNames
        ..clear()
        ..addAll(savedTypes);
      _typeBounds
        ..clear()
        ..addAll(savedBounds);
      return;
    }
    if (!_checking.add(function)) {
      _typeNames
        ..clear()
        ..addAll(savedTypes);
      _typeBounds
        ..clear()
        ..addAll(savedBounds);
      if (model.declarations[function]!.type == '<infer>')
        fail('Recursive expression functions require a return annotation',
            function);
      return;
    }
    final savedScope = _scope,
        savedFunction = _function,
        savedReturn = _returnType;
    final savedPromoted = Map<String, String>.from(_promoted);
    _promoted.clear();
    // A top-level function does not close over the caller's locals. Calls
    // re-check a function that has defaults, and that call may sit inside
    // another function. Parent the body at the global scope in that case.
    _scope = _Scope(_declaredAtTopLevel(function) ? _global : savedScope);
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
    _promoted
      ..clear()
      ..addAll(savedPromoted);
    _checking.remove(function);
    _checked.add(function);
    _typeNames
      ..clear()
      ..addAll(savedTypes);
    _typeBounds
      ..clear()
      ..addAll(savedBounds);
  }

  bool returns(List<Statement> body) {
    for (final statement in body) {
      if (statement is ReturnStatement) return true;
      if (statement is GuardedStatement &&
          statement.alternate != null &&
          statement.statement is ReturnStatement) {
        return true;
      }
      if (statement is IfStatement &&
          returns(statement.thenBody) &&
          returns(statement.elseBody)) {
        return true;
      }
      if (statement is ForStatement &&
          !_mentionsBreak(statement.body) &&
          returns(statement.elseBody)) {
        return true;
      }
      if (statement is WhileStatement &&
          !_mentionsBreak(statement.body) &&
          returns(statement.elseBody)) {
        return true;
      }
      if (statement is RepeatStatement &&
          !_mentionsBreak(statement.body) &&
          returns(statement.elseBody)) {
        return true;
      }
      if (statement is CForStatement &&
          !_mentionsBreak(statement.body) &&
          returns(statement.elseBody)) {
        return true;
      }
    }
    return false;
  }

  bool _mentionsBreak(List<Statement> body) {
    for (final statement in body) {
      switch (statement) {
        case BreakStatement():
          return true;
        case IfStatement():
          if (_mentionsBreak(statement.thenBody) ||
              _mentionsBreak(statement.elseBody)) {
            return true;
          }
        case GuardedStatement():
          if (statement.statement is BreakStatement) return true;
        case LabelStatement():
          if (_mentionsBreak([statement.statement])) return true;
        default:
          break;
      }
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
          if (node.type != null) _expected = model.resolve(node.type!);
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
          _expected = model.resolve(node.type!);
        } else if (existing != null &&
            node.mode == BindingMode.inferred &&
            node.type == null) {
          _expected = model.resolve(existing.type);
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
          if (node.operator == '??=') {
            _checkIfNull(existing.type, type, node);
          } else {
            final result = node.operator == '='
                ? type
                : binaryType(existing.type, node.operator[0], type, node);
            if (!compatible(result, existing.type)) {
              fail('Cannot assign $result to ${existing.type}', node);
            }
          }
          model.references[node] = existing;
          model.assignments.add(node);
          _afterAssignment(node.name, existing.type, type, node.operator);
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
        _requireBool(node.condition, 'if condition must be bool');
        _withPromotions(_promotions(node.condition, whenTrue: true),
            () => statements(node.thenBody, nested: true));
        _withPromotions(_promotions(node.condition, whenTrue: false),
            () => statements(node.elseBody, nested: true));
      case ForStatement():
        final asValue = _armValueLoop;
        _armValueLoop = false;
        final type = expression(node.iterable);
        if (node.step != null) {
          if (!_rangeIterable(node.iterable)) {
            fail('step follows a range', node.step!);
          }
          final stepType = expression(node.step!);
          final integer = model.types[node.iterable] == 'Range<int>';
          if (integer) {
            if (stepType != 'int') fail('step must be int', node.step!);
          } else if (!numeric(stepType)) {
            fail('step must be numeric', node.step!);
          }
          if (_zeroStep(node.step!)) {
            error('E801', 'A loop step cannot be zero', node.step!);
          }
        }
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
        if (node.index != null) {
          if (node.index == node.name) {
            fail('Loop bindings must have different names', node);
          }
          if (_scope.lookup(node.index!) != null) {
            fail('Loop binding would shadow ${node.index}', node);
          }
        }
        final pair = node.index == null ? null : _pairFields(element);
        final symbol = create(node.name, pair == null ? element : pair[1]);
        model.declarations[node] = symbol;
        final saved = _scope;
        _scope = _Scope(saved);
        _scope.symbols[node.name] = symbol;
        if (node.index != null) {
          final index = create(node.index!, pair == null ? 'int' : pair[0]);
          model.loopIndexes[node] = index;
          _scope.symbols[node.index!] = index;
          if (pair != null) model.loopPairs.add(node);
        }
        final frame = _LoopFrame(asValue);
        _loops.add(frame);
        _loopDepth++;
        statements(node.body);
        _loopDepth--;
        _loops.removeLast();
        if (asValue) _valueBreakType = frame.breakType;
        _scope = saved;
        if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
      case WhileStatement():
        final asValue = _armValueLoop;
        _armValueLoop = false;
        if (node.letName != null) {
          final frame = _LoopFrame(asValue);
          _loops.add(frame);
          _loopDepth++;
          _withLet(node.letName!, node.condition, node, () {
            statements(node.body, nested: true);
          });
          _loopDepth--;
          _loops.removeLast();
          if (asValue) _valueBreakType = frame.breakType;
          if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
          break;
        }
        if (node.pattern != null) {
          final frame = _LoopFrame(asValue);
          _loops.add(frame);
          _loopDepth++;
          _withPattern(node.condition, node.pattern!, () {
            statements(node.body, nested: true);
          });
          _loopDepth--;
          _loops.removeLast();
          if (asValue) _valueBreakType = frame.breakType;
          if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
          break;
        }
        _requireBool(node.condition, 'while condition must be bool');
        final frame = _LoopFrame(asValue);
        _loops.add(frame);
        _loopDepth++;
        _withPromotions(_promotions(node.condition, whenTrue: true),
            () => statements(node.body, nested: true));
        _loopDepth--;
        _loops.removeLast();
        if (asValue) _valueBreakType = frame.breakType;
        if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
      case GuardedStatement():
        final elseType =
            node.alternate == null ? null : expression(node.alternate!);
        if (node.alternate != null && _slot(node.statement) == null) {
          fail('else needs a value', node.alternate!);
        }
        final outer = _scope;
        if (node.letName != null) {
          _withLet(node.letName!, node.condition, node, () {
            check(node.statement);
            if (node.alternate != null) _liftExcept(outer, {node.letName!});
          });
        } else if (node.pattern != null) {
          _withPattern(node.condition, node.pattern!, () {
            check(node.statement);
            if (node.alternate != null) {
              _liftExcept(outer, _patternNames(node.pattern!));
            }
          });
        } else {
          _requireBool(node.condition, 'if condition must be bool');
          _withPromotions(_promotions(node.condition, whenTrue: true),
              () => check(node.statement));
        }
        if (elseType != null) _joinGuarded(node, elseType);
      case ParallelAssignment():
        if (node.targets.isEmpty)
          fail('Parallel assignment needs a name', node);
        if (node.values.length == 1) {
          final type = expression(node.values.single);
          final parts = _recordParts(type) ?? _deconstructParts(type);
          if (parts == null) {
            fail('Parallel assignment needs a record', node.values.single);
          }
          if (parts.length != node.targets.length) {
            fail('Record has ${parts.length} fields', node.values.single);
          }
          _assignPattern = true;
          for (var i = 0; i < node.targets.length; i++) {
            bindPattern(node.targets[i], parts[i], declare: true);
          }
          _assignPattern = false;
          break;
        }
        if (node.values.length != node.targets.length) {
          fail('Parallel assignment needs ${node.targets.length} values', node);
        }
        final types = [for (final value in node.values) expression(value)];
        _assignPattern = true;
        for (var i = 0; i < node.targets.length; i++) {
          bindPattern(node.targets[i], types[i], declare: true);
        }
        _assignPattern = false;
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
        if (node is BreakStatement && node.value != null) {
          if (_loops.isEmpty || !_loops.last.value) {
            fail('break has a value outside a value loop', node);
          }
          final type = expression(node.value!);
          if (type == 'void') fail('break needs a value', node.value!);
          final frame = _loops.last;
          frame.breakType = frame.breakType == null
              ? type
              : joinTypes(frame.breakType!, type, node.value!);
        } else if (node is BreakStatement &&
            label == null &&
            _loops.isNotEmpty &&
            _loops.last.value) {
          fail('A value loop needs a break value', node);
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
        if (_refutable(node.pattern)) {
          error('E100', 'A refutable pattern cannot be assigned', node.pattern);
        }
        _assignPattern = true;
        bindPattern(node.pattern, type, declare: true);
        _assignPattern = false;
      case ReturnStatement():
        if (_function == null && _returnType != '<infer>') {
          fail('return is only valid inside a function', node);
        }
        final type = node.value == null ? 'void' : expression(node.value!);
        if (_returnType == '<infer>') break;
        if (!compatible(type, _returnType!))
          fail('Return type $type is incompatible with $_returnType', node);
      case ExpressionStatement():
        final valueType = expression(node.expression);
        if (node.expression is Identifier && valueType.contains('->')) {
          final name = (node.expression as Identifier).name;
          error('E110',
              'A zero-argument call has no parentheses; write $name()', node);
        }
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
        final asValue = _armValueLoop;
        _armValueLoop = false;
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
        final frame = _LoopFrame(asValue);
        _loops.add(frame);
        _loopDepth++;
        statements(node.body);
        _loopDepth--;
        _loops.removeLast();
        if (asValue) _valueBreakType = frame.breakType;
        _scope = savedFor;
        if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
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
        if (node.elseBody.isNotEmpty) {
          statements(node.elseBody, nested: true);
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
        if (_loops.any((frame) => frame.value)) {
          fail('yield is not valid in a value loop', node);
        }
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
        final asValue = _armValueLoop;
        _armValueLoop = false;
        if (node.body.isEmpty) fail('repeat needs a body', node);
        if (node.count != null) {
          if (expression(node.count!) != 'int') {
            fail('repeat count must be int', node.count!);
          }
          final frame = _LoopFrame(asValue);
          _loops.add(frame);
          _loopDepth++;
          statements(node.body, nested: true);
          _loopDepth--;
          _loops.removeLast();
          if (asValue) _valueBreakType = frame.breakType;
          if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
          break;
        }
        final frame = _LoopFrame(asValue);
        _loops.add(frame);
        _loopDepth++;
        statements(node.body, nested: true);
        _loopDepth--;
        _loops.removeLast();
        if (asValue) _valueBreakType = frame.breakType;
        if (expression(node.condition!) != 'bool') {
          fail('repeat condition must be bool', node.condition!);
        }
        if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
      case TestDeclaration():
        model.declarations[node] = create(node.title, 'void');
        statements(node.body, nested: true);
      case FunctionDeclaration():
        registerFunction(node, _scope);
        analyzeFunction(node);
      case WatchStatement():
        expression(node.value);
        statements(node.body, nested: true);
      case BatchStatement():
        statements(node.body, nested: true);
      case OnceStatement():
        statements(node.body, nested: true);
      case RequireStatement():
        final condition = expression(node.condition);
        if (condition != 'bool') {
          fail('require condition must be bool', node.condition);
        }
        if (node.message != null) expression(node.message!);
      case RaiseStatement():
        _raise(node);
      case IfCaseStatement():
        final matched = expression(node.scrutinee);
        final savedCase = _scope;
        _scope = _Scope(savedCase);
        bindPattern(node.pattern, matched, declare: true);
        final facts = <String, String>{};
        if (node.scrutinee is Identifier && node.pattern is TypedPattern) {
          facts[(node.scrutinee as Identifier).name] =
              (node.pattern as TypedPattern).type;
        }
        _withPromotions(facts, () => statements(node.body));
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
      case TaskGroupStatement():
        if (_function == null || !_function!.isAsync) {
          error('E803', 'task group is only valid inside async', node);
        }
        for (final child in node.children) {
          if (child is TaskGroupStatement) {
            check(child);
          } else {
            expression(child as Expression);
          }
        }
      case AnnotationDeclaration():
      case ConfigDeclaration():
        fail('Classes and imports belong at the top level', node);
    }
  }

  String _awaitedType(String type) =>
      type.startsWith('Future<') && type.endsWith('>')
          ? type.substring(7, type.length - 1)
          : type;

  String typeApplication(TypeApplication node) {
    fail('Type arguments belong to a call', node);
  }

  String awaitAll(AwaitAllExpression node) {
    if (_function == null || !_function!.isAsync) {
      error('E803', 'await is only valid inside async', node);
    }
    if (node.arms.isEmpty) fail('await all needs a child', node);
    final types = [for (final arm in node.arms) _awaitedType(expression(arm))];
    return '(${types.join(', ')})';
  }

  String awaitIsolate(AwaitIsolateExpression node) {
    if (_function == null || !_function!.isAsync) {
      error('E803', 'await is only valid inside async', node);
    }
    final call = node.call;
    if (call is! CallExpression) {
      error('E805', 'await isolate needs a top-level or static call', node);
    }
    final type = expression(call);
    final callee = call.callee;
    final topLevel =
        callee is Identifier && _global.symbols[callee.name]?.function != null;
    final staticMember = callee is MemberAccess &&
        _isTypeReference(callee.object) &&
        () {
          final owner = _global
              .symbols[(callee.object as Identifier).name]?.classDeclaration;
          final method = owner == null ? null : _method(owner, callee.name);
          return method != null && method.isStatic;
        }();
    if (!topLevel && !staticMember) {
      error('E805', 'await isolate needs a top-level or static call', node);
    }
    if (_capturesLocal(call)) {
      error('E805', 'An isolate call captures a local', node);
    }
    return type.startsWith('Future<') && type.endsWith('>')
        ? type.substring(7, type.length - 1)
        : type;
  }

  bool _capturesLocal(Expression node) {
    switch (node) {
      case Identifier():
        final symbol = _scope.lookup(node.name);
        return symbol != null &&
            !_global.symbols.containsKey(node.name) &&
            symbol.function == null &&
            symbol.classDeclaration == null;
      case CallExpression():
        return _capturesLocal(node.callee) ||
            node.arguments.any((argument) => _capturesLocal(argument.value));
      case MemberAccess():
        return _capturesLocal(node.object);
      case Literal():
        return false;
      case ListExpression():
        return node.elements.any(_capturesLocal);
      case SetExpression():
        return node.elements.any(_capturesLocal);
      case MapExpression():
        return node.keys.any(_capturesLocal) || node.values.any(_capturesLocal);
      case RecordExpression():
        return node.fields.any(_capturesLocal);
      case UnaryExpression():
        return _capturesLocal(node.operand);
      case BinaryExpression():
        return _capturesLocal(node.left) || _capturesLocal(node.right);
      case SliceExpression():
        return _capturesLocal(node.object) ||
            (node.start != null && _capturesLocal(node.start!)) ||
            (node.end != null && _capturesLocal(node.end!));
      case ChainComparison():
        return node.operands.any(_capturesLocal);
      case InterpolatedString():
        return node.parts.any(_capturesLocal);
      case ShownExpression():
        return _capturesLocal(node.value);
      default:
        return true;
    }
  }

  void _rejectSealedOutside(ClassDeclaration type, ClassDeclaration other) {
    final sealed = other.kind == 'sealed' || other.modifiers.contains('sealed');
    if (!sealed || other.kind == 'sealedType') return;
    final home = model.libraryOf[other] ?? '';
    final here = model.libraryOf[type] ?? library;
    if (home.isNotEmpty && home != here) {
      error('E703', 'A sealed type is extended outside its library', type);
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
    if (declaration == null) {
      fail(
          _hinted('No member ${node.name} on $raw', node.name,
              _memberCandidates(raw)),
          node);
    }
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
      _checkMember(declaration, node.name, node);
      model.references[node] = Symbol(
          property.name, _dartMember(type, property.name), property.type);
      return;
    }
    final fields =
        _fieldsOf(declaration).where((item) => item.name == node.name);
    if (fields.isEmpty || !fields.first.mutable) {
      fail('Cannot assign immutable field ${node.name}', node);
    }
    _checkMember(declaration, node.name, node);
    if (fields.first.isStatic != _isTypeReference(node.object)) {
      fail(
          fields.first.isStatic
              ? 'Static member ${node.name} is used on an instance'
              : 'Instance member ${node.name} is used on the type',
          node);
    }
    final value = expression(node.value);
    if (node.operator == '??=') {
      _checkIfNull(fields.first.type, value, node);
    } else if (!compatible(value, fields.first.type)) {
      fail('Cannot assign $value to ${fields.first.type}', node);
    }
    if (type == '_QudsLog' && fields.first.name == 'minimum') {
      final written = node.value;
      if (written is Literal &&
          written.value is String &&
          !const {'debug', 'info', 'warning', 'error'}
              .contains(written.value)) {
        error('E300', 'Unknown log level ${written.value}', written);
      }
    }
    model.references[node] = Symbol(fields.first.name,
        _dartMember(type, fields.first.name), fields.first.type);
  }

  void _installLog() {
    const span = SourceSpan(1, 1, 0);
    Parameter parameter(String name, {Expression? fallback}) =>
        Parameter(name, 'dynamic', false, span, defaultValue: fallback);
    final methods = <FunctionDeclaration>[
      for (final level in const ['debug', 'info', 'warning', 'error'])
        FunctionDeclaration(
            level,
            [
              parameter('message'),
              parameter('data', fallback: const Literal(null, span)),
            ],
            'void',
            const <Statement>[],
            null,
            span),
      FunctionDeclaration('sink', [parameter('writer')], 'void',
          const <Statement>[], null, span),
    ];
    final type = ClassDeclaration(
        '_QudsLog',
        'class',
        [
          const FieldDeclaration(
              'minimum', 'String', true, false, Literal('debug', span), span)
        ],
        methods,
        const <ClassCase>[],
        const <Metadata>[],
        span);
    final symbol =
        Symbol('_QudsLog', '_QudsLog', '_QudsLog', classDeclaration: type);
    _global.symbols['_QudsLog'] = symbol;
    model.declarations[type] = symbol;
    for (final method in methods) {
      model.declarations[method] =
          Symbol(method.name, method.name, 'void', function: method)
              .withFunction(method);
    }
    _global.symbols['log'] = Symbol('log', 'log', '_QudsLog');
  }

  final _labels = <String>[];
  var _loopDepth = 0;

  /// True for the next loop, which is the body of a [LoopExpression].
  var _armValueLoop = false;

  /// The break type of the value loop that just finished.
  String? _valueBreakType;
  final _loops = <_LoopFrame>[];
  var _catchDepth = 0;

  /// True while a pattern on the left of `=` is binding its names.
  var _assignPattern = false;

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
    if (type == 'String') return 'String';
    fail('for-in requires a List, Set, range, iterable, or String', node);
  }

  void _bindPatternName(String name, String type, Pattern node,
      {required bool declare, required bool shadow}) {
    final existing = _scope.lookup(name);
    if (shadow) {
      if (existing == null || _scope.symbols.containsKey(name)) {
        fail('shadow requires a binding in an outer scope', node);
      }
    } else if (declare &&
        existing != null &&
        (_scope.symbols.containsKey(name) || _assignPattern)) {
      if (existing.readonly || !existing.mutable) {
        error('E202', 'An immutable binding is assigned', node);
      }
      if (!compatible(type, existing.type)) {
        fail('Cannot assign $type to ${existing.type}', node);
      }
      model.declarations[node] = existing;
      model.rebinding.add(node);
      return;
    } else if (declare && existing != null) {
      fail('Binding would shadow $name; use shadow in an inner scope', node);
    }
    final symbol = create(name, type);
    _scope.symbols[name] = symbol;
    model.declarations[node] = symbol;
  }

  bool _refutable(Pattern pattern) => switch (pattern) {
        WildcardPattern() || BindingPattern() || RestPattern() => false,
        LiteralPattern() ||
        RelationalPattern() ||
        TypedPattern() ||
        OrPattern() ||
        NullCheckPattern() ||
        NullAssertPattern() =>
          true,
        AndPattern(:final left, :final right) =>
          _refutable(left) || _refutable(right),
        CastPattern(:final inner) => _refutable(inner),
        ListPattern(:final elements) => elements.any(_refutable),
        MapPattern(:final values) => values.any(_refutable),
        ConstructorPattern(:final typeName, :final fields) =>
          typeName.isNotEmpty || fields.any(_refutable),
      };

  void _withLet(
      String name, Expression value, Node owner, void Function() body) {
    if (_scope.lookup(name) != null) {
      fail('Binding would shadow $name; use shadow in an inner scope', owner);
    }
    final raw = expression(value);
    if (!raw.endsWith('?') && raw != 'Null') {
      fail('let requires a nullable value', value);
    }
    final saved = _scope;
    _scope = _Scope(saved);
    final bound = create(name, unwrap(raw));
    _scope.symbols[name] = bound;
    model.declarations[owner] = bound;
    body();
    _scope = saved;
  }

  void _withPattern(
      Expression scrutinee, Pattern pattern, void Function() body) {
    final matched = expression(scrutinee);
    final saved = _scope;
    _scope = _Scope(saved);
    bindPattern(pattern, matched, declare: true);
    final facts = <String, String>{};
    if (scrutinee is Identifier && pattern is TypedPattern) {
      facts[scrutinee.name] = pattern.type;
    }
    _withPromotions(facts, body);
    _scope = saved;
  }

  void bindPattern(Pattern pattern, String type, {bool declare = false}) {
    switch (pattern) {
      case WildcardPattern():
        return;
      case TypedPattern():
        if (pattern.name != null) {
          if (declare) {
            _bindPatternName(pattern.name!, pattern.type, pattern,
                declare: true, shadow: pattern.shadow);
          } else {
            final symbol = create(pattern.name!, pattern.type);
            _scope.symbols[pattern.name!] = symbol;
            model.declarations[pattern] = symbol;
          }
        }
      case BindingPattern():
        final existing = _scope.lookup(pattern.name);
        if (existing?.classCase != null ||
            (existing != null &&
                (existing.name == 'Ok' || existing.name == 'Error') &&
                existing.parameterTypes.isNotEmpty &&
                !pattern.shadow)) {
          model.references[pattern] = existing!;
          return;
        }
        _bindPatternName(pattern.name, type, pattern,
            declare: declare, shadow: pattern.shadow);
      case LiteralPattern():
        expression(pattern.literal);
      case ListPattern():
        if (_assignPattern) {
          if (!type.startsWith('List<') || !type.endsWith('>')) {
            fail('A list pattern requires a List', pattern);
          }
          if (pattern.elements.whereType<RestPattern>().length > 1) {
            fail('A list pattern has one rest', pattern);
          }
        }
        final element = elementType(type, pattern);
        for (final item in pattern.elements) {
          bindPattern(item, item is RestPattern ? type : element,
              declare: declare);
        }
      case ConstructorPattern():
        if (pattern.typeName == 'Ok' || pattern.typeName == 'Error') {
          if (!type.startsWith('Result<') || !type.endsWith('>')) {
            fail('${pattern.typeName} matches a Result', pattern);
          }
          final parts = _splitTypes(type.substring(7, type.length - 1));
          if (parts.length != 2) {
            fail('Result needs two type arguments', pattern);
          }
          final fieldType = pattern.typeName == 'Ok' ? parts[0] : parts[1];
          if (pattern.fields.length > 1) {
            fail('${pattern.typeName} has one field', pattern);
          }
          if (pattern.fields.length == 1) {
            bindPattern(pattern.fields.single, fieldType, declare: declare);
          }
          return;
        }
        if (pattern.typeName.isEmpty &&
            type.startsWith('(') &&
            type.endsWith(')')) {
          final parts = _splitTypes(type.substring(1, type.length - 1));
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
      case MapPattern():
        final valueType = type.startsWith('Map<') && type.endsWith('>')
            ? () {
                final inner = type.substring(4, type.length - 1);
                final splitAt = inner.indexOf(',');
                return splitAt < 0 ? type : inner.substring(splitAt + 1).trim();
              }()
            : type;
        for (var i = 0; i < pattern.keys.length; i++) {
          expression(pattern.keys[i]);
          bindPattern(pattern.values[i], valueType, declare: declare);
        }
      case RestPattern():
        if (pattern.name != null) {
          _bindPatternName(pattern.name!, type, pattern,
              declare: declare, shadow: pattern.shadow);
        }
      case OrPattern():
        bindPattern(pattern.left, type, declare: declare);
        bindPattern(pattern.right, type, declare: declare);
      case AndPattern():
        bindPattern(pattern.left, type, declare: declare);
        bindPattern(pattern.right, type, declare: declare);
      case RelationalPattern():
        expression(pattern.value);
      case CastPattern():
        validateType(pattern.type, pattern, allowVoid: false);
        bindPattern(pattern.inner, pattern.type, declare: declare);
      case NullCheckPattern():
      case NullAssertPattern():
        bindPattern(
            pattern is NullCheckPattern
                ? pattern.inner
                : (pattern as NullAssertPattern).inner,
            unwrap(type),
            declare: declare);
    }
  }

  bool compatible(String from, String to) {
    from = model.resolve(from);
    to = model.resolve(to);
    if (from == to || from == '*' || to == 'dynamic') return true;
    if (from == 'dynamic' && to != 'void') return true;
    if (to == 'Object' && from != 'void') return true;
    if (to.contains(' & ')) {
      return to.split(' & ').every((part) => compatible(from, part.trim()));
    }
    if (from.contains(' & ')) {
      return from.split(' & ').any((part) => compatible(part.trim(), to));
    }
    if (_implementsType(from, to)) return true;
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
    if (from.startsWith('(') &&
        to.startsWith('(') &&
        from.contains('->') &&
        to.contains('->')) {
      final (fromParams, fromReturn) = _functionParts(from);
      final (toParams, toReturn) = _functionParts(to);
      final fromList = _splitTypes(fromParams);
      final toList = _splitTypes(toParams);
      if (fromList.length == toList.length) {
        var paramsOk = true;
        for (var i = 0; i < fromList.length; i++) {
          if (!compatible(
              _parameterType(toList[i]), _parameterType(fromList[i]))) {
            paramsOk = false;
            break;
          }
        }
        if (paramsOk &&
            (toReturn == 'void' || compatible(fromReturn, toReturn))) {
          return true;
        }
      }
    }
    return false;
  }

  bool _implementsType(String from, String to) {
    final declaration = _global.symbols[unwrap(from)]?.classDeclaration;
    if (declaration == null) return false;
    if (declaration.interfaces.contains(to) || declaration.superclass == to) {
      return true;
    }
    if (declaration.superclass != null &&
        _implementsType(declaration.superclass!, to)) {
      return true;
    }
    for (final name in declaration.interfaces) {
      if (_implementsType(name, to)) return true;
    }
    return false;
  }

  void _checkIntersection(List<String> parts, Node node) {
    const concrete = {'int', 'double', 'num', 'bool', 'String', 'Null'};
    for (var i = 0; i < parts.length; i++) {
      for (var j = i + 1; j < parts.length; j++) {
        final left = parts[i];
        final right = parts[j];
        if (compatible(left, right) || compatible(right, left)) continue;
        if (concrete.contains(left) && concrete.contains(right)) {
          error('E306', 'An intersection cannot be satisfied', node);
        }
      }
    }
  }

  void _checkVariance(ClassDeclaration type) {
    for (final parameter in type.typeParameters) {
      if (parameter.variance.isEmpty) continue;
      final want = parameter.variance == 'out' ? 1 : -1;
      void visit(String raw, int polarity) {
        final current = raw.trim();
        if (current.isEmpty || current == 'dynamic') return;
        if (current.startsWith('readonly ')) {
          visit(current.substring(9), polarity);
          return;
        }
        if (current.endsWith('?')) {
          visit(current.substring(0, current.length - 1), polarity);
          return;
        }
        if (current.contains(' & ') || current.contains(' | ')) {
          for (final part in current.split(RegExp(' [&|] '))) {
            visit(part, polarity);
          }
          return;
        }
        if (current.startsWith('(') && current.contains('->')) {
          final arrow = current.lastIndexOf('->');
          final parameters = current.substring(1, current.indexOf(')'));
          if (parameters.trim().isNotEmpty) {
            for (final item in parameters.split(',')) {
              visit(item, -polarity);
            }
          }
          visit(current.substring(arrow + 3), polarity);
          return;
        }
        final open = current.indexOf('<');
        if (open > 0 && current.endsWith('>')) {
          final head = current.substring(0, open);
          final inner = current.substring(open + 1, current.length - 1);
          final covariant = {
            'List',
            'Set',
            'Iterable',
            'Future',
            'Stream',
            'Optional'
          }.contains(head);
          if (head == 'Map' || head == 'Result') {
            final parts = _splitTypes(inner);
            if (parts.length == 2) {
              visit(parts[0], 0);
              visit(parts[1], polarity);
            }
          } else {
            visit(inner, covariant ? polarity : 0);
          }
          return;
        }
        if (current == parameter.name && polarity != want) {
          error(
              'E304',
              'Variance ${parameter.variance} ${parameter.name} is not sound',
              parameter);
        }
      }

      for (final field in type.fields) {
        visit(field.type, field.mutable ? 0 : 1);
      }
      for (final method in type.methods) {
        if (method.returnType != null) visit(method.returnType!, 1);
        for (final item in method.parameters) {
          visit(item.type, -1);
        }
      }
    }
  }

  ClassDeclaration? _configType;

  void registerAnnotation(AnnotationDeclaration node) {
    if (model.annotations.contains(node.name)) {
      fail('Annotation ${node.name} is already defined', node);
    }
    for (final parameter in node.parameters) {
      validateType(parameter.type, parameter, allowVoid: false);
    }
    model.annotations.add(node.name);
    model.annotationShapes[node.name] = node;
  }

  void _checkMetadata(List<Metadata> notes) {
    for (final note in notes) {
      if (note.name == 'Reflectable' || note.name == 'macro') {
        if (note.arguments.isNotEmpty) {
          fail('${note.name} takes no arguments', note);
        }
        continue;
      }
      final shape = model.annotationShapes[note.name];
      if (shape == null) continue;
      final seen = <String>{};
      for (final argument in note.arguments) {
        final label = argument.name;
        if (label == null) {
          fail('Positional arguments are not allowed on annotations', argument);
        }
        if (!seen.add(label)) fail('Duplicate argument: $label', argument);
        final parameter =
            shape.parameters.where((item) => item.name == label).firstOrNull;
        if (parameter == null) fail('Unknown argument: $label', argument);
        final type = expression(argument.value);
        if (!compatible(type, parameter.type)) {
          fail('Argument type $type is incompatible with ${parameter.type}',
              argument);
        }
        _constants.ensureConstant(argument.value);
      }
      for (final parameter in shape.parameters) {
        if (parameter.defaultValue == null && !seen.contains(parameter.name)) {
          fail('Missing required argument ${parameter.name}', note);
        }
      }
    }
  }

  void registerConfig(ConfigDeclaration node) {
    validateType(node.type, node, allowVoid: false);
    final sourceValue = node.value;
    if (node.secret && sourceValue != null) {
      if (sourceValue is Literal) {
        error(
            'E908', 'A secret configuration has a source literal', sourceValue);
      }
      fail('A secret configuration has no source initializer', sourceValue);
    }
    const readable = {'int', 'double', 'bool', 'String'};
    if (!readable.contains(node.type)) {
      fail('Configuration ${node.name} must be int, double, bool, or String',
          node);
    }
    if (!node.secret && sourceValue != null) {
      final value = expression(sourceValue);
      if (!compatible(value, node.type)) {
        fail('Cannot initialize ${node.type} with $value', sourceValue);
      }
    }
    _configType ??= ClassDeclaration('config', 'class', <FieldDeclaration>[],
        const [], const [], const [], node.span);
    final parts = node.name.split('.');
    var type = _configType!;
    for (var i = 0; i < parts.length - 1; i++) {
      type = _configChild(type, parts[i], node.span);
    }
    final leaf = parts.last;
    if (type.fields.any((field) => field.name == leaf)) {
      fail('Configuration ${node.name} is already declared', node);
    }
    final field = FieldDeclaration(
        leaf, node.type, false, false, node.value, node.span,
        isStatic: identical(type, _configType));
    type.fields.add(field);
    model.declarations[field] = Symbol(leaf, leaf, node.type);
    _global.symbols['config'] ??=
        Symbol('config', 'config', 'config', classDeclaration: _configType);
  }

  ClassDeclaration _configChild(
      ClassDeclaration parent, String part, SourceSpan span) {
    final existing = parent.fields.where((field) => field.name == part);
    if (existing.isNotEmpty) {
      final nested = _global.symbols[existing.first.type]?.classDeclaration;
      if (nested == null) {
        fail('Configuration $part is not a group', existing.first);
      }
      return nested;
    }
    final childName =
        parent.name == 'config' ? '_QudsConfig_$part' : '${parent.name}_$part';
    final child = ClassDeclaration(childName, 'class', <FieldDeclaration>[],
        const [], const [], const [], span);
    _global.symbols[childName] =
        Symbol(childName, childName, childName, classDeclaration: child);
    final field = FieldDeclaration(part, childName, false, false, null, span,
        isStatic: identical(parent, _configType));
    parent.fields.add(field);
    model.declarations[field] = Symbol(part, part, childName);
    return child;
  }

  FunctionDeclaration? _instanceCall(Symbol symbol) {
    if (symbol.function != null || symbol.classDeclaration != null) {
      return null;
    }
    return _callOnType(symbol.type);
  }

  /// The instance method `call` on a class value, including an inherited one.
  FunctionDeclaration? _callOnType(String type) {
    if (type.endsWith('?') || type.contains('->')) return null;
    final declaration = model.classes[_classKey(type)];
    if (declaration == null) return null;
    final method = _method(declaration, 'call');
    if (method == null || method.isStatic) return null;
    return method;
  }

  String _applyCallMethod(
      CallExpression node, String type, FunctionDeclaration invoked) {
    final declaration = model.classes[_classKey(type)];
    final substitution = _genericSubstitution(type, declaration);
    final parameters = [
      for (final parameter in invoked.parameters)
        Parameter(parameter.name, _substitute(parameter.type, substitution),
            parameter.mutable, parameter.span,
            defaultValue: parameter.defaultValue,
            variadic: parameter.variadic,
            initializing: parameter.initializing)
    ];
    if (invoked.returnType == null &&
        model.declarations[invoked]?.type == '<infer>') {
      analyzeFunction(invoked);
    }
    return _substitute(applyArguments(node, parameters, invoked), substitution);
  }

  String _classKey(String type) {
    var name = type.startsWith('readonly ') ? type.substring(9) : type;
    if (name.endsWith('?')) name = name.substring(0, name.length - 1);
    final open = name.indexOf('<');
    return open < 0 ? name : name.substring(0, open);
  }

  String _substitute(String type, Map<String, String> substitution) {
    var result = type;
    for (final entry in substitution.entries) {
      result = result.replaceAll(
          RegExp('\\b${RegExp.escape(entry.key)}\\b'), entry.value);
    }
    return result;
  }

  String _genericHead(String type) {
    final open = type.indexOf('<');
    return open < 0 ? type : type.substring(0, open);
  }

  Map<String, String> _genericSubstitution(
      String type, ClassDeclaration? declaration) {
    if (declaration == null || declaration.typeParameters.isEmpty) {
      return const {};
    }
    final head = _genericHead(type);
    final named =
        head == declaration.name || head.endsWith('.${declaration.name}');
    if (!named || !type.startsWith('$head<') || !type.endsWith('>')) {
      return const {};
    }
    final inner = type.substring(head.length + 1, type.length - 1);
    final args = _splitTypes(inner);
    if (args.length != declaration.typeParameters.length) return const {};
    return {
      for (var i = 0; i < args.length; i++)
        declaration.typeParameters[i].name: args[i]
    };
  }

  List<String> _splitTypes(String inner) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    for (final char in inner.split('')) {
      if (char == '<' || char == '(') depth++;
      if (char == '>' || char == ')') depth--;
      if (char == ',' && depth == 0) {
        parts.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) parts.add(buffer.toString().trim());
    return parts;
  }

  Map<String, String>? _extensionMatch(
      ExtensionDeclaration extension, String type) {
    if (extension.typeParameters.isEmpty) {
      return extension.target == type ? const {} : null;
    }
    final names = extension.typeParameters.map((item) => item.name).toSet();
    return _templateMatch(extension.target, type, names);
  }

  Map<String, String>? _templateMatch(
      String template, String type, Set<String> names) {
    if (names.contains(template)) return {template: type};
    final templateOpen = template.indexOf('<');
    final typeOpen = type.indexOf('<');
    if (templateOpen < 0 || typeOpen < 0) {
      return template == type ? const {} : null;
    }
    if (template.substring(0, templateOpen) != type.substring(0, typeOpen)) {
      return null;
    }
    if (!template.endsWith('>') || !type.endsWith('>')) return null;
    final left =
        _splitTypes(template.substring(templateOpen + 1, template.length - 1));
    final right = _splitTypes(type.substring(typeOpen + 1, type.length - 1));
    if (left.length != right.length) return null;
    final found = <String, String>{};
    for (var i = 0; i < left.length; i++) {
      final nested = _templateMatch(left[i], right[i], names);
      if (nested == null) return null;
      found.addAll(nested);
    }
    return found;
  }

  String unwrap(String type) =>
      type.endsWith('?') ? type.substring(0, type.length - 1) : type;
  bool numeric(String type) => {'int', 'double', 'num'}.contains(type);

  /// `int`, `double`, `num`, or a type parameter bounded by one of them.
  bool _numericOperand(String type) {
    if (numeric(type)) return true;
    final bound = _typeBounds[type];
    return bound != null && numeric(bound);
  }

  String? _eventPayload(String type) {
    if (type.startsWith('Event<') && type.endsWith('>')) {
      return type.substring(6, type.length - 1);
    }
    return null;
  }

  List<String>? _recordParts(String type) {
    if (!type.startsWith('(') || !type.endsWith(')') || type.contains('->')) {
      return null;
    }
    return _splitTypes(type.substring(1, type.length - 1));
  }

  List<String>? _deconstructParts(String type) {
    final declaration = _global.symbols[unwrap(type)]?.classDeclaration;
    if (declaration == null) return null;
    final method = _method(declaration, 'deconstruct');
    if (method == null || method.parameters.isNotEmpty) return null;
    final returned = model.declarations[method]?.type ?? method.returnType;
    if (returned == null) return null;
    return _recordParts(returned);
  }

  String _nameof(NameofExpression node) {
    expression(node.target);
    return 'String';
  }

  void _raise(RaiseStatement node) {
    final owner = _thisType == null
        ? null
        : _global.symbols[_thisType!]?.classDeclaration;
    final field = owner?.fields
        .where((item) => item.isEvent && item.name == node.name)
        .firstOrNull;
    if (owner == null || field == null) {
      fail('raise ${node.name} is only valid in the class that declares it',
          node);
    }
    final payload = _eventPayload(field.type) ?? field.type;
    final (parameters, _) = _functionParts(payload);
    final expected =
        parameters.trim().isEmpty ? const <String>[] : _splitTypes(parameters);
    if (node.arguments.length != expected.length) {
      fail('raise ${node.name} expects ${expected.length} arguments', node);
    }
    for (var i = 0; i < expected.length; i++) {
      final argument = expression(node.arguments[i].value);
      final wanted = _parameterType(expected[i]);
      if (wanted.isNotEmpty && !compatible(argument, wanted)) {
        fail('Argument type $argument is incompatible with $wanted',
            node.arguments[i]);
      }
    }
    final symbol = _scope.lookup(node.name);
    model.references[node] =
        Symbol(node.name, symbol?.dartName ?? node.name, payload);
  }

  /// [element] `in` [collection]. A map matches its keys.
  bool _membership(String element, String collection) {
    var type = collection.startsWith('readonly ')
        ? collection.substring(9)
        : collection;
    if (type.endsWith('?')) return false;
    type = unwrap(type);
    if (type == 'String') return element == 'String';
    if (type.startsWith('Map<') && type.endsWith('>')) {
      final parts = _splitTypes(type.substring(4, type.length - 1));
      return parts.length == 2 && compatible(element, parts[0]);
    }
    final inner = _sequenceElement(type);
    return inner != null && compatible(element, inner);
  }

  /// The two positional fields of a record, when [type] is one.
  List<String>? _pairFields(String type) {
    if (!type.startsWith('(') || !type.endsWith(')') || type.contains('->')) {
      return null;
    }
    final parts = _splitTypes(type.substring(1, type.length - 1));
    if (parts.length != 2 || parts.any((part) => part.contains(':'))) {
      return null;
    }
    return parts;
  }

  String? _sequenceElement(String type) {
    if (type.startsWith('List<') && type.endsWith('>')) {
      return type.substring(5, type.length - 1);
    }
    if (type.startsWith('Set<') && type.endsWith('>')) {
      return type.substring(4, type.length - 1);
    }
    if (type.startsWith('Iterable<') && type.endsWith('>')) {
      return type.substring(9, type.length - 1);
    }
    if (type.startsWith('Range<') && type.endsWith('>')) {
      return type.substring(6, type.length - 1);
    }
    return null;
  }

  String lambda(Lambda node) {
    final expected = _expected;
    final expectedParams = expected != null &&
            expected.startsWith('(') &&
            expected.contains('->') &&
            !expected.endsWith(')?')
        ? _splitTypes(_functionParts(expected).$1)
        : const <String>[];
    for (var i = 0; i < node.parameters.length; i++) {
      final parameter = node.parameters[i];
      if (parameter.type == '<infer>') {
        final fromExpected =
            i < expectedParams.length ? _parameterType(expectedParams[i]) : '';
        if (fromExpected.isNotEmpty) {
          parameterType(parameter, fromExpected);
        } else if (_numericUse(node, parameter.name)) {
          parameterType(parameter, 'int');
        } else {
          error('E302', 'A type cannot be inferred', parameter);
        }
      } else {
        validateType(parameter.type, parameter, allowVoid: false);
        parameterType(parameter, parameter.type);
      }
    }
    final saved = _scope;
    final savedPromoted = Map<String, String>.from(_promoted);
    _promoted.clear();
    _scope = _Scope(saved);
    for (final parameter in node.parameters) {
      _scope.symbols[parameter.name] = model.declarations[parameter]!;
    }
    final savedDepth = _lambdaDepth;
    final savedAwait = _lambdaAwait;
    _lambdaDepth++;
    _lambdaAwait = false;
    String type;
    if (node.expressionBody case final value?) {
      type = expression(value);
    } else {
      final savedReturn = _returnType;
      _returnType = '<infer>';
      statements(node.body!);
      type = 'void';
      for (final statement in node.body!) {
        if (statement is ReturnStatement && statement.value != null) {
          type = model.types[statement.value!] ?? 'void';
          break;
        }
      }
      _returnType = savedReturn;
    }
    if (_lambdaAwait) {
      model.asyncLambdas.add(node);
      if (!type.startsWith('Future<')) type = 'Future<$type>';
    }
    _lambdaAwait = savedAwait;
    _lambdaDepth = savedDepth;
    _scope = saved;
    _promoted
      ..clear()
      ..addAll(savedPromoted);
    final parameters =
        node.parameters.map((p) => model.declarations[p]!.type).join(', ');
    return '($parameters) -> $type';
  }

  String _parameterType(String declared) {
    final trimmed = declared.trim();
    if (!trimmed.contains(':')) return trimmed;
    return trimmed.split(':').last.trim();
  }

  bool _numericUse(Node root, String name) {
    var found = false;
    walkAst(root, (node) {
      if (node is! BinaryExpression) return;
      if (!const {'+', '-', '*', '/', '~/', '%'}.contains(node.operator)) {
        return;
      }
      walkAst(node, (inner) {
        if (inner is Identifier && inner.name == name) found = true;
      });
    });
    return found;
  }

  void _checkOverride(ClassDeclaration type, FunctionDeclaration method) {
    final parentName = type.superclass;
    if (parentName == null) return;
    final parent = _global.symbols[parentName]?.classDeclaration;
    if (parent == null) return;
    final inherited = _method(parent, method.name);
    if (inherited == null || !sameSignature(method, inherited)) return;
    final inheritedType = model.declarations[inherited]?.type;
    final methodType = model.declarations[method]?.type;
    if (inheritedType == null ||
        methodType == null ||
        inheritedType == '<infer>' ||
        methodType == '<infer>') {
      return;
    }
    if (!compatible(methodType, inheritedType)) {
      error(
          'E300',
          'override return type $methodType is incompatible with $inheritedType',
          method);
    }
  }

  (String, String) _functionParts(String type) {
    var depth = 0;
    for (var i = 0; i < type.length; i++) {
      if (type[i] == '(') depth++;
      if (type[i] == ')') {
        depth--;
        if (depth == 0) {
          final arrow = type.indexOf('->', i);
          if (arrow < 0) break;
          return (type.substring(1, i), type.substring(arrow + 2).trim());
        }
      }
    }
    final arrow = type.lastIndexOf('->');
    return (
      type.substring(1, type.indexOf(')')),
      type.substring(arrow + 3).trim()
    );
  }

  void parameterType(Parameter parameter, String type) {
    final symbol = create(parameter.name, type, mutable: parameter.mutable);
    model.declarations[parameter] = symbol;
  }

  String member(MemberAccess node) {
    if (node.object is Identifier) {
      final owner = _scope.lookup((node.object as Identifier).name);
      if (owner != null && owner.namespace != null) {
        model.references[node.object] = owner;
        model.types[node.object] = 'prefix';
        final found = owner.namespace![node.name];
        if (found == null) {
          if (!owner.external) {
            fail(
                _hinted(
                    'Name ${node.name} is not defined',
                    node.name,
                    owner.namespace!.keys
                        .where((name) => !name.startsWith('_'))),
                node);
          }
          final created =
              Symbol(node.name, node.name, 'dynamic', external: true);
          owner.namespace![node.name] = created;
          model.references[node] = created;
          return 'dynamic';
        }
        model.references[node] = found;
        _touch(found);
        return found.type;
      }
    }
    final raw = expression(node.object);
    final nested = model.references[node.object]?.namespace?[node.name];
    final owner = model.references[node.object];
    if (nested != null && owner?.type != 'prefix') {
      model.references[node] = nested;
      return nested.type;
    }
    final type = raw.startsWith('readonly ') ? raw.substring(9) : raw;
    final nullableExtension = type.endsWith('?') &&
        !node.nullAware &&
        _extensions(type, node.name).isNotEmpty;
    if (type.endsWith('?') && !node.nullAware && !nullableExtension) {
      error('E308',
          'A nullable value is used where a non-null value is required', node);
    }
    final base = unwrap(type);
    final eventPayload = _eventPayload(base);
    if (eventPayload != null) {
      if (node.name != 'add') fail('No member ${node.name} on an event', node);
      final shown = '($eventPayload) -> void';
      model.references[node] = Symbol('add', 'add', shown);
      return node.nullAware || type.endsWith('?') ? '$shown?' : shown;
    }
    if (node.name == 'length' &&
        (base == 'String' ||
            base.startsWith('List<') ||
            base.startsWith('Set<') ||
            base.startsWith('Map<'))) {
      final lengthType = node.nullAware || type.endsWith('?') ? 'int?' : 'int';
      return _readonlyView(raw, lengthType);
    }
    if (base == 'dynamic') return 'dynamic';
    final look = nullableExtension ? type : (_typeBounds[base] ?? base);
    if (look.contains(' & ')) {
      for (final part in look.split(' & ')) {
        final found = memberType(part.trim(), node.name);
        if (found == null) continue;
        model.references[node] =
            Symbol(node.name, _dartMember(part.trim(), node.name), found);
        final foundType =
            node.nullAware || type.endsWith('?') ? '$found?' : found;
        return _readonlyView(raw, foundType);
      }
    }
    final declaration = _global.symbols[_genericHead(look)]?.classDeclaration;
    final substitution = _genericSubstitution(look, declaration);
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
    final found = memberType(look, node.name);
    if (found != null) {
      if (declaration != null) _checkMember(declaration, node.name, node);
      final substituted = _substitute(found, substitution);
      final classOwns = declaration != null &&
          (_method(declaration, node.name) != null ||
              _fieldsOf(declaration).any((item) => item.name == node.name));
      final extensions = classOwns
          ? const <FunctionDeclaration>[]
          : _extensions(look, node.name);
      final extensionSymbol =
          extensions.length == 1 ? model.declarations[extensions.single] : null;
      if (extensionSymbol != null) {
        model.references[node] = extensionSymbol;
        _touch(extensionSymbol);
      } else {
        final properties = classOwns
            ? const <PropertyDeclaration>[]
            : _extensionProperties(look, node.name);
        final property = properties.length == 1 ? properties.single : null;
        final dart = property == null
            ? _dartMember(_genericHead(look), node.name)
            : property.visibility == 'private' && !property.name.startsWith('_')
                ? '_${property.name}'
                : property.name;
        model.references[node] = Symbol(node.name, dart, substituted);
      }
      if (substituted.contains('->')) return substituted;
      final foundType =
          node.nullAware || type.endsWith('?') ? '$substituted?' : substituted;
      return _readonlyView(raw, foundType);
    }
    final numberGetter = _numberGetter(base, node.name);
    if (numberGetter != null) {
      model.references[node] = Symbol(node.name, node.name, numberGetter);
      final foundType = node.nullAware || type.endsWith('?')
          ? '$numberGetter?'
          : numberGetter;
      return _readonlyView(raw, foundType);
    }
    final builtin = _collectionGetter(base, node.name);
    if (builtin != null) {
      model.references[node] = Symbol(node.name, node.name, builtin);
      final foundType =
          node.nullAware || type.endsWith('?') ? '$builtin?' : builtin;
      return _readonlyView(raw, foundType);
    }
    final sdk = _sdkMember(base, node.name);
    if (sdk != null && sdk.getter) {
      model.references[node] = _dartMemberSymbol(sdk, sdk.type);
      final dartGetter = sdk.type;
      final foundType =
          node.nullAware || type.endsWith('?') ? '$dartGetter?' : dartGetter;
      return _readonlyView(raw, foundType);
    }
    fail(
        _hinted('No member ${node.name} on $type', node.name,
            _memberCandidates(type)),
        node);
  }

  bool _isTypeReference(Expression node) {
    if (node is! Identifier) return false;
    final symbol = model.references[node];
    return symbol?.classDeclaration != null && symbol!.classCase == null;
  }

  bool _containsAwait(Expression node) => switch (node) {
        AwaitExpression() ||
        AwaitAllExpression() ||
        AwaitIsolateExpression() =>
          true,
        UnaryExpression() => _containsAwait(node.operand),
        BinaryExpression() =>
          _containsAwait(node.left) || _containsAwait(node.right),
        CallExpression() => _containsAwait(node.callee) ||
            node.arguments.any((argument) => _containsAwait(argument.value)),
        MemberAccess() => _containsAwait(node.object),
        SliceExpression() => _containsAwait(node.object) ||
            (node.start != null && _containsAwait(node.start!)) ||
            (node.end != null && _containsAwait(node.end!)),
        ChainComparison() => node.operands.any(_containsAwait),
        _ => false,
      };

  String? memberType(String type, String name) {
    final declaration = _global.symbols[_genericHead(type)]?.classDeclaration;
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
    final properties = _extensionProperties(type, name);
    if (extensions.length + properties.length > 1) {
      error('E205', 'Two extensions define $name and neither is more specific',
          extensions.isEmpty ? properties.first : extensions.first);
    }
    if (properties.length == 1) return properties.single.type;
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

  List<PropertyDeclaration> _extensionProperties(String type, String name) => [
        for (final extension in model.extensions)
          if (_extensionMatch(extension, type) != null)
            for (final property in extension.properties)
              if (property.name == name) property
      ];

  List<FunctionDeclaration> _extensions(String type, String name) => [
        for (final extension in model.extensions)
          if (_extensionMatch(extension, type) != null)
            for (final method in extension.methods)
              if (method.name == name) method
      ];

  Map<String, String> _extensionSubstitution(
      String type, FunctionDeclaration method) {
    for (final extension in model.extensions) {
      if (!extension.methods.contains(method)) continue;
      return _extensionMatch(extension, type) ?? const {};
    }
    return const {};
  }

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
        case SliceExpression():
          return walk(node.object, stack) ||
              (node.start != null && walk(node.start!, stack)) ||
              (node.end != null && walk(node.end!, stack));
        case ChainComparison():
          return node.operands.any((operand) => walk(operand, stack));
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
    if (raw.endsWith('?')) {
      error('E308',
          'A nullable value is used where a non-null value is required', node);
    }
    final type = unwrap(raw.startsWith('readonly ') ? raw.substring(9) : raw);
    final indexType = expression(node.index);
    if (type.startsWith('List<')) {
      if (!compatible(indexType, 'int'))
        fail('List index must be int', node.index);
      return _readonlyView(raw, type.substring(5, type.length - 1));
    }
    if (type.startsWith('Map<')) {
      final inner = type.substring(4, type.length - 1);
      final splitAt = inner.indexOf(',');
      final key = inner.substring(0, splitAt).trim();
      final value = inner.substring(splitAt + 1).trim();
      if (!compatible(indexType, key)) fail('Map key type is $key', node.index);
      return _readonlyView(raw, value);
    }
    if (type == 'String') {
      if (!compatible(indexType, 'int'))
        fail('String index must be int', node.index);
      return 'String';
    }
    fail('Cannot index $type', node);
  }

  String slice(SliceExpression node) {
    final raw = expression(node.object);
    if (raw.endsWith('?')) {
      error('E308',
          'A nullable value is used where a non-null value is required', node);
    }
    final type = unwrap(raw.startsWith('readonly ') ? raw.substring(9) : raw);
    void bound(Expression? value) {
      if (value == null) return;
      final boundType = expression(value);
      if (!compatible(boundType, 'int')) fail('Slice bound must be int', value);
    }

    bound(node.start);
    bound(node.end);
    if (type == 'String') return 'String';
    if (type.startsWith('List<') && type.endsWith('>')) return type;
    fail('Cannot slice $type', node);
  }

  String chain(ChainComparison node) {
    final types = [for (final operand in node.operands) expression(operand)];
    final first = types.first;
    if (first == 'String') {
      if (types.any((type) => type != 'String')) {
        fail('A chained comparison needs strings', node);
      }
      return 'bool';
    }
    if (!types.every(numeric)) {
      fail('A chained comparison needs numbers or strings', node);
    }
    if (types.contains('int') && types.contains('double')) {
      fail('A chained comparison needs one numeric type', node);
    }
    return 'bool';
  }

  String mapLiteral(MapExpression node) {
    if (node.keys.isEmpty) {
      final expected = _expected;
      if (expected != null &&
          expected.startsWith('Map<') &&
          expected.endsWith('>')) {
        return expected;
      }
      error('E302', 'Empty maps require a type annotation', node);
    }
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
    final inferred = 'Map<$key, $value>';
    final expected = _expected;
    if (expected != null &&
        expected.startsWith('Map<') &&
        expected.endsWith('>')) {
      final parts = _splitTypes(expected.substring(4, expected.length - 1));
      if (parts.length == 2 &&
          compatible(key!, parts[0]) &&
          compatible(value!, parts[1])) {
        return expected;
      }
    }
    return inferred;
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
    if (node.elements.isEmpty) {
      final expected = _expected;
      if (expected != null &&
          expected.startsWith('Set<') &&
          expected.endsWith('>')) {
        return expected;
      }
      error('E302', 'Empty sets require a type annotation', node);
    }
    var type = elementTypeOf(node.elements.first, aware(node.nullAware, 0));
    for (var i = 1; i < node.elements.length; i++) {
      final next = elementTypeOf(node.elements[i], aware(node.nullAware, i));
      if (next != type)
        fail('Set elements must share a type', node.elements[i]);
    }
    return _widenCollection('Set<$type>', 'Set<');
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
    if (_lambdaDepth > 0) {
      _lambdaAwait = true;
    } else if (_function == null || !_function!.isAsync) {
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
    final parts = _splitTypes(type.substring(7, type.length - 1));
    if (parts.length != 2) fail('? expects a Result', node);
    final value = parts[0];
    final failure = parts[1];
    final returned = _resultReturn(_returnType ?? '');
    if (returned == null) {
      error('E600', 'Postfix ? has no compatible Result function', node);
    }
    final expectedParts =
        _splitTypes(returned.substring(7, returned.length - 1));
    final expectedError = expectedParts.length == 2 ? expectedParts[1] : '';
    if (expectedError != failure &&
        expectedError != 'Object' &&
        !compatible(failure, expectedError)) {
      error('E601', 'A Result error type does not fit the function', node);
    }
    return value;
  }

  String? _resultReturn(String type) {
    if (type.startsWith('Result<') && type.endsWith('>')) return type;
    if (type.startsWith('Future<Result<') && type.endsWith('>')) {
      return type.substring(7, type.length - 1);
    }
    return null;
  }

  void _requireBool(Expression condition, String message) {
    final type = expression(condition);
    if (type == 'bool?') {
      error(
          'E308',
          'A nullable value is used where a non-null value is required',
          condition);
    }
    if (type != 'bool') fail(message, condition);
  }

  void _withPromotions(Map<String, String> extra, void Function() body) {
    if (extra.isEmpty) {
      body();
      return;
    }
    final saved = Map<String, String>.from(_promoted);
    _promoted.addAll(extra);
    try {
      body();
    } finally {
      _promoted
        ..clear()
        ..addAll(saved);
    }
  }

  T _withPromoted<T>(Map<String, String> extra, T Function() body) {
    if (extra.isEmpty) return body();
    final saved = Map<String, String>.from(_promoted);
    _promoted.addAll(extra);
    try {
      return body();
    } finally {
      _promoted
        ..clear()
        ..addAll(saved);
    }
  }

  Map<String, String> _promotions(Expression node, {required bool whenTrue}) {
    if (node is UnaryExpression && node.operator == 'not') {
      return _promotions(node.operand, whenTrue: !whenTrue);
    }
    if (node is BinaryExpression && node.operator == 'and') {
      if (!whenTrue) return const {};
      return {
        ..._promotions(node.left, whenTrue: true),
        ..._promotions(node.right, whenTrue: true),
      };
    }
    if (node is BinaryExpression && node.operator == 'or') {
      if (whenTrue) return const {};
      return {
        ..._promotions(node.left, whenTrue: false),
        ..._promotions(node.right, whenTrue: false),
      };
    }
    if (node is BinaryExpression &&
        (node.operator == '==' || node.operator == '!=')) {
      final name = _comparedName(node);
      if (name == null) return const {};
      final symbol = _scope.lookup(name);
      if (symbol == null || symbol.field) return const {};
      final current = _promoted[name] ?? symbol.type;
      if (!current.endsWith('?')) return const {};
      final unequal = node.operator == '!=';
      if (unequal != whenTrue) return const {};
      return {name: unwrap(current)};
    }
    return const {};
  }

  String? _comparedName(BinaryExpression node) {
    final rightNull =
        node.right is Literal && (node.right as Literal).value == null;
    final leftNull =
        node.left is Literal && (node.left as Literal).value == null;
    if (rightNull && node.left is Identifier) {
      return (node.left as Identifier).name;
    }
    if (leftNull && node.right is Identifier) {
      return (node.right as Identifier).name;
    }
    return null;
  }

  void _checkIfNull(String target, String value, Node node) {
    if (!target.endsWith('?') && target != 'Null') {
      fail('??= requires a nullable binding', node);
    }
    final inner = unwrap(target);
    if (!compatible(value, inner)) {
      fail('Cannot assign $value to $inner', node);
    }
  }

  void _afterAssignment(
      String name, String target, String value, String operator) {
    if ((operator == '=' || operator == '??=') &&
        target.endsWith('?') &&
        !value.endsWith('?') &&
        value != 'Null') {
      _promoted[name] = value;
      return;
    }
    _promoted.remove(name);
  }

  String _readonlyView(String receiver, String memberType) {
    if (!receiver.startsWith('readonly ') ||
        memberType.startsWith('readonly ')) {
      return memberType;
    }
    if (memberType.endsWith('?')) {
      final inner = _readonlyView(receiver, unwrap(memberType));
      return inner == unwrap(memberType) ? memberType : '$inner?';
    }
    const plain = {'int', 'double', 'num', 'bool', 'String', 'void', 'Null'};
    if (plain.contains(memberType) || memberType.contains('->')) {
      return memberType;
    }
    if (memberType.startsWith('List<') ||
        memberType.startsWith('Map<') ||
        memberType.startsWith('Set<') ||
        memberType.startsWith('Iterable<') ||
        _global.symbols[_genericHead(memberType)]?.classDeclaration != null) {
      return 'readonly $memberType';
    }
    return memberType;
  }

  String typeTest(TypeTestExpression node) {
    final value = expression(node.operand);
    if (value == 'void') fail('Void expressions cannot be operands', node);
    validateType(node.type, node, allowVoid: false);
    if (node.operator == 'as') return node.type;
    return 'bool';
  }

  String binary(BinaryExpression node) {
    if (node.operator == 'and' || node.operator == 'or') {
      final left = expression(node.left);
      final facts = _promotions(node.left, whenTrue: node.operator == 'and');
      final right = _withPromoted(facts, () => expression(node.right));
      return binaryType(left, node.operator, right, node);
    }
    return binaryType(
        expression(node.left), node.operator, expression(node.right), node);
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
    if (op == 'in' || op == 'not in') {
      if (!_membership(left, right)) {
        fail('Operator $op is incompatible with $left and $right', node);
      }
      return 'bool';
    }
    if (op == 'and' || op == 'or') {
      if (left == 'bool?' || right == 'bool?') {
        error(
            'E308',
            'A nullable value is used where a non-null value is required',
            node);
      }
      if (left == 'bool' && right == 'bool') return 'bool';
    } else if (op == '+' && left == 'String' && right == 'String') {
      return 'String';
    } else if (op == '*' &&
        (left == 'String' && right == 'int' ||
            left == 'int' && right == 'String')) {
      return 'String';
    } else if (_numericOperand(left) && _numericOperand(right)) {
      if ({'<', '<=', '>', '>='}.contains(op)) return 'bool';
      if (op == '/') return 'double';
      if (left == right && _typeBounds.containsKey(left)) return left;
      if (left == 'num' || right == 'num') return 'num';
      if (_typeBounds.containsKey(left) || _typeBounds.containsKey(right)) {
        return 'num';
      }
      return left == 'double' || right == 'double' ? 'double' : 'int';
    }
    if (op == '+') {
      final joined = _joinedCollection(left, right);
      if (joined != null) return joined;
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
      BinaryExpression() => binary(node),
      TypeTestExpression() => typeTest(node),
      ListExpression() => list(node),
      CallExpression() => call(node),
      InterpolatedString() => interpolation(node),
      ShownExpression() => _shown(node),
      Lambda() => lambda(node),
      MemberAccess() => member(node),
      IndexExpression() => index(node),
      SliceExpression() => slice(node),
      ChainComparison() => chain(node),
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
      LoopExpression() => loopExpression(node),
      WhereExpression() => whereExpression(node),
      ThisExpression() => thisExpression(node),
      TypeApplication() => typeApplication(node),
      AwaitAllExpression() => awaitAll(node),
      AwaitIsolateExpression() => awaitIsolate(node),
      SymbolExpression() => 'Symbol',
      NameofExpression() => _nameof(node),
    };
    final resolved = model.resolve(type);
    model.types[node] = resolved;
    return resolved;
  }

  String _hinted(String message, String name, Iterable<String> candidates) {
    final suggestion = _nearestName(name, candidates);
    if (suggestion == null) return message;
    return '$message. Did you mean $suggestion?';
  }

  String? _nearestName(String name, Iterable<String> candidates) {
    final limit = name.length <= 3 ? 1 : 2;
    String? best;
    var ties = 0;
    var bestDistance = limit + 1;
    final seen = <String>{};
    for (final candidate in candidates) {
      if (candidate == name || candidate.isEmpty || !seen.add(candidate)) {
        continue;
      }
      final distance = _editDistance(name, candidate);
      if (distance == 0 || distance > limit) continue;
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
        ties = 1;
      } else if (distance == bestDistance) {
        ties++;
      }
    }
    if (ties != 1) return null;
    return best;
  }

  int _editDistance(String left, String right) {
    if (left == right) return 0;
    if (left.toLowerCase() == right.toLowerCase()) return 1;
    final rows = left.length + 1;
    final cols = right.length + 1;
    var previous = List<int>.generate(cols, (index) => index);
    var current = List<int>.filled(cols, 0);
    for (var i = 1; i < rows; i++) {
      current[0] = i;
      for (var j = 1; j < cols; j++) {
        final cost = left[i - 1] == right[j - 1] ? 0 : 1;
        final insert = current[j - 1] + 1;
        final delete = previous[j] + 1;
        final replace = previous[j - 1] + cost;
        var best = insert < delete ? insert : delete;
        if (replace < best) best = replace;
        current[j] = best;
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[cols - 1];
  }

  Iterable<String> _visibleNames() sync* {
    final seen = <String>{};
    _Scope? scope = _scope;
    while (scope != null) {
      for (final entry in scope.symbols.entries) {
        if (!seen.add(entry.key)) continue;
        if (entry.key.startsWith('_') && entry.value.library.isNotEmpty) {
          continue;
        }
        yield entry.key;
      }
      scope = scope.parent;
    }
  }

  Iterable<String> _memberCandidates(String type) sync* {
    var bare = type.startsWith('readonly ') ? type.substring(9) : type;
    bare = unwrap(bare);
    final head = _genericHead(bare);
    final declaration = _global.symbols[head]?.classDeclaration;
    if (declaration != null) yield* _classMembers(declaration, <String>{});
    if (head == 'String') yield* _stringMembers;
    if (head == 'List') yield* _listMembers;
    if (head == 'Set') yield* _setMembers;
    if (head == 'Map') yield* _mapMembers;
    if (head == 'Iterable' || head == 'List' || head == 'Set') {
      yield* _iterableMembers;
    }
    if (head == 'int') yield 'pad';
    if (head == 'int' || head == 'double' || head == 'num') {
      yield* _numberMembers;
    }
    for (final extension in model.extensions) {
      if (_extensionMatch(extension, bare) == null &&
          _extensionMatch(extension, head) == null) {
        continue;
      }
      for (final method in extension.methods) {
        yield method.name;
      }
      for (final property in extension.properties) {
        yield property.name;
      }
    }
  }

  Iterable<String> _classMembers(
      ClassDeclaration type, Set<String> seen) sync* {
    if (!seen.add(type.name)) return;
    final owner = model.libraryOf[type] ?? '';
    bool visible(String name) =>
        !name.startsWith('_') || owner.isEmpty || owner == library;
    for (final field in type.fields) {
      if (visible(field.name)) yield field.name;
    }
    for (final property in type.properties) {
      if (visible(property.name)) yield property.name;
    }
    for (final method in type.methods) {
      if (visible(method.name)) yield method.name;
    }
    for (final item in type.cases) {
      if (visible(item.name)) yield item.name;
    }
    for (final mixin in type.mixins) {
      final parent = _global.symbols[mixin]?.classDeclaration;
      if (parent != null) yield* _classMembers(parent, seen);
    }
    final superName = type.superclass;
    if (superName != null) {
      final parent = _global.symbols[superName]?.classDeclaration;
      if (parent != null) yield* _classMembers(parent, seen);
    }
  }

  String identifier(Identifier node) {
    final symbol = _scope.lookup(node.name);
    if (symbol == null && _thisType != null) {
      final current = _thisType!;
      if (node.name == 'length' &&
          (current == 'String' ||
              current.startsWith('List<') ||
              current.startsWith('Set<') ||
              current.startsWith('Map<'))) {
        model.implicitThis.add(node);
        model.references[node] = Symbol('length', 'length', 'int');
        return 'int';
      }
      final member = memberType(_thisType!, node.name);
      if (member != null) {
        final current = _global.symbols[_thisType!]?.classDeclaration;
        if (current != null) _checkMember(current, node.name, node);
        model.implicitThis.add(node);
        model.references[node] =
            Symbol(node.name, _dartMember(_thisType!, node.name), member);
        return member;
      }
    }
    if (symbol == null) {
      if (!_externalDart) {
        fail(
            _hinted(
                'Undefined symbol: ${node.name}', node.name, _visibleNames()),
            node);
      }
      model.references[node] =
          Symbol(node.name, node.name, 'dynamic', external: true);
      return 'dynamic';
    }
    if (symbol.namespace != null) fail('A prefix is not a value', node);
    if (symbol.field && _thisType != null) {
      final current = _global.symbols[_thisType!]?.classDeclaration;
      if (current != null) _checkMember(current, node.name, node);
    }
    if (symbol.overloads.length > 1) {
      fail('Choose one overload with a call or a typed context', node);
    }
    model.references[node] = symbol;
    _touch(symbol);
    if (symbol.function != null) return functionType(symbol.function!);
    if (symbol.parameterTypes.isNotEmpty) {
      return '(${symbol.parameterTypes.join(', ')}) -> ${symbol.type}';
    }
    final visible = _promoted[symbol.name] ?? symbol.type;
    return symbol.readonly ? 'readonly $visible' : visible;
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

  /// A Dart library type this file did not declare. Different ones can share a list.
  bool _externalNominal(String type) {
    if (type == 'dynamic') return true;
    if (type.endsWith('?')) return _externalNominal(unwrap(type));
    const known = {
      'int',
      'double',
      'num',
      'String',
      'bool',
      'Null',
      'Object',
      'Never',
      'void',
    };
    if (known.contains(type)) return false;
    if (type.startsWith('List<') ||
        type.startsWith('Set<') ||
        type.startsWith('Map<') ||
        type.startsWith('Iterable<') ||
        type.startsWith('Future<') ||
        type.startsWith('Stream<') ||
        type.startsWith('Range<') ||
        type.startsWith('Optional<') ||
        type.startsWith('Result<') ||
        type.contains('->') ||
        type.startsWith('(')) {
      return false;
    }
    final head = _genericHead(type);
    if (_global.symbols[head]?.classDeclaration != null) return false;
    return RegExp(r'^[A-Za-z_]').hasMatch(head);
  }

  String list(ListExpression node) {
    if (node.elements.isEmpty) {
      final expected = _expected;
      if (expected != null &&
          expected.startsWith('List<') &&
          expected.endsWith('>')) {
        return expected;
      }
      error('E302', 'Empty lists require contextual typing (not supported yet)',
          node);
    }
    var type = elementTypeOf(node.elements.first, aware(node.nullAware, 0));
    for (var i = 1; i < node.elements.length; i++) {
      final next = elementTypeOf(node.elements[i], aware(node.nullAware, i));
      if (numeric(type) && numeric(next) && type != next) {
        type = 'num';
      } else if (type != next &&
          _externalNominal(type) &&
          _externalNominal(next)) {
        type = 'dynamic';
      } else if (type != next) {
        fail('List elements must have a common supported static type',
            node.elements[i]);
      }
    }
    return _widenCollection('List<$type>', 'List<');
  }

  /// A non-empty collection keeps the expected type when every element fits it.
  String _widenCollection(String inferred, String prefix) {
    final expected = _expected;
    if (expected == null ||
        !expected.startsWith(prefix) ||
        !expected.endsWith('>')) {
      return inferred;
    }
    final wanted = expected.substring(prefix.length, expected.length - 1);
    final got = inferred.substring(prefix.length, inferred.length - 1);
    if (got == wanted || compatible(got, wanted)) return expected;
    return inferred;
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

  String _shown(ShownExpression node) {
    if (expression(node.value) == 'void') {
      fail('Cannot interpolate a void expression', node.value);
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

  String _qualifyType(String dartName, String returned, String className) {
    if (!dartName.contains('.')) return returned;
    if (returned == className) return dartName;
    if (returned.startsWith('$className<')) {
      return '$dartName${returned.substring(className.length)}';
    }
    return returned;
  }

  /// A call whose target is a Dart library. Arguments stay in source order.
  String _passExternal(CallExpression node, Symbol symbol) {
    model.references[node.callee] = symbol;
    _touch(symbol);
    for (final argument in node.arguments) {
      expression(argument.value);
    }
    if (symbol.type.isEmpty || symbol.type == 'dynamic') return 'dynamic';
    return symbol.type;
  }

  String _callPrefixed(CallExpression node, MemberAccess callee, Symbol owner) {
    final id = callee.object as Identifier;
    model.references[id] = owner;
    model.types[id] = 'prefix';
    final found = owner.namespace![callee.name];
    if (found == null) {
      if (!owner.external) {
        fail(
            _hinted('Name ${callee.name} is not defined', callee.name,
                owner.namespace!.keys.where((name) => !name.startsWith('_'))),
            callee);
      }
      return _passExternal(
          node, Symbol(callee.name, callee.name, 'dynamic', external: true));
    }
    _touch(found);
    if (found.classDeclaration != null) {
      final declaration = found.classDeclaration!;
      final returned = constructClass(node, declaration);
      final qualified =
          _qualifyType(found.dartName, returned, declaration.name);
      final previous = model.references[node.callee];
      if (previous == null || previous.classDeclaration != null) {
        model.references[node.callee] = Symbol(
            found.dartName, found.dartName, qualified,
            classDeclaration: previous?.classDeclaration ?? declaration);
      } else {
        final rebuilt = Symbol(declaration.name, declaration.name, qualified);
        if (previous.function != null) rebuilt.withFunction(previous.function);
        model.references[node.callee] = rebuilt;
      }
      return qualified;
    }
    if (found.function != null) {
      final type =
          applyArguments(node, found.function!.parameters, found.function);
      model.references[callee] =
          Symbol(found.name, found.dartName, type).withFunction(found.function);
      return type;
    }
    if (found.parameterTypes.isNotEmpty || found.callable) {
      model.references[callee] = found;
      return externalCall(node, found);
    }
    fail('${callee.name} is not callable', callee);
  }

  String call(CallExpression node) {
    if (node.callee is TypeApplication) {
      return callApplied(node, node.callee as TypeApplication);
    }
    final callee = node.callee;
    if (callee is MemberAccess && callee.object is Identifier) {
      final owner = _scope.lookup((callee.object as Identifier).name);
      if (owner?.namespace != null) {
        return _callPrefixed(node, callee, owner!);
      }
      final type = owner?.classDeclaration;
      final named = type?.constructors
          .where((constructor) => constructor.name == callee.name)
          .toList();
      if (type != null && named != null && named.isNotEmpty) {
        model.references[callee.object as Identifier] = owner!;
        final parameters = _ctorParameters(type, named.first);
        applyArguments(node, parameters, null);
        _rememberConstCall(node, named.first, parameters, type.name);
        model.references[callee] = Symbol(callee.name, callee.name, type.name,
            function: FunctionDeclaration(callee.name, parameters, type.name,
                null, null, named.first.span));
        return type.name;
      }
    }
    if (callee is MemberAccess) {
      final rawObject = expression(callee.object);
      final nested = model.references[callee.object]?.namespace?[callee.name];
      final owner = model.references[callee.object];
      if (nested != null && owner?.type != 'prefix') {
        model.references[callee] = nested;
        if (nested.parameterTypes.isNotEmpty || nested.callable) {
          return externalCall(node, nested);
        }
      }
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
      final objectTypeRaw = rawObject.startsWith('readonly ')
          ? rawObject.substring(9)
          : rawObject;
      final nullableExtension = objectTypeRaw.endsWith('?') &&
          !callee.nullAware &&
          _extensions(objectTypeRaw, callee.name).isNotEmpty;
      if (objectTypeRaw.endsWith('?') &&
          !callee.nullAware &&
          !nullableExtension) {
        error(
            'E308',
            'A nullable value is used where a non-null value is required',
            callee);
      }
      if (rawObject.startsWith('readonly ') &&
          _mutating.contains(callee.name)) {
        error('E307', 'A readonly reference cannot be mutated', callee);
      }
      final objectType =
          nullableExtension ? objectTypeRaw : unwrap(objectTypeRaw);
      final eventPayload = _eventPayload(objectType);
      if (eventPayload != null) {
        if (callee.name != 'add')
          fail('No method ${callee.name} on an event', callee);
        if (node.arguments.length != 1) fail('add expects one handler', node);
        final savedExpected = _expected;
        _expected = eventPayload;
        final argument = expression(node.arguments.single.value);
        _expected = savedExpected;
        if (!compatible(argument, eventPayload)) {
          fail('Argument type $argument is incompatible with $eventPayload',
              node.arguments.single);
        }
        model.references[callee] = Symbol('add', 'add', 'void');
        model.argumentOrder[node] = [0];
        return 'void';
      }
      if (objectType == 'dynamic') {
        return _passExternal(
            node, Symbol(callee.name, callee.name, 'dynamic', external: true));
      }
      final declaration =
          _global.symbols[_genericHead(objectType)]?.classDeclaration;
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
        final builtin = _collectionCall(objectType, callee.name, node);
        if (builtin != null) return builtin;
        final number = _numberCall(objectType, callee.name, node);
        if (number != null) return number;
        final dartCall = _dartCall(objectType, callee.name, node);
        if (dartCall != null) return dartCall;
        fail(
            _hinted('No method ${callee.name} on $objectType', callee.name,
                _memberCandidates(objectType)),
            callee);
      }
      if (function != null && declaration != null) {
        _checkMember(declaration, callee.name, callee);
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
      _touch(model.references[callee]!);
      final substitution = {
        ..._genericSubstitution(objectType, declaration),
        ..._extensionSubstitution(objectType, functionResolved)
      };
      final parameters = [
        for (final parameter in functionResolved.parameters)
          Parameter(parameter.name, _substitute(parameter.type, substitution),
              parameter.mutable, parameter.span,
              defaultValue: parameter.defaultValue,
              variadic: parameter.variadic,
              initializing: parameter.initializing)
      ];
      final returned = applyArguments(node, parameters, functionResolved);
      final declared = model.declarations[functionResolved]!.type == '<infer>'
          ? returned
          : model.declarations[functionResolved]!.type;
      return _substitute(declared, substitution);
    }
    if (callee is! Identifier) {
      final type = expression(callee);
      final invoked = _callOnType(type);
      if (invoked != null) return _applyCallMethod(node, type, invoked);
      if (type.endsWith('?')) {
        error(
            'E308',
            'A nullable value is used where a non-null value is required',
            callee);
      }
      if (!type.contains('->')) fail('Value is not callable', callee);
      final (parameters, returns) = _functionParts(type);
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
    if (symbol != null && symbol.external) return _passExternal(node, symbol);
    if (symbol == null && _externalDart) {
      return _passExternal(
          node, Symbol(callee.name, callee.name, 'dynamic', external: true));
    }
    if (symbol == null) {
      fail(
          _hinted('Undefined function: ${callee.name}', callee.name,
              _visibleNames()),
          callee);
    }
    model.references[callee] = symbol;
    _touch(symbol);
    if (symbol.type.startsWith('Event<')) {
      fail('An event is raised with raise, and listeners use add', callee);
    }
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
    if (symbol.dartName == 'expect' && symbol.function == null) {
      if (args.length != 1 || args.single.name != null) {
        fail('expect expects one positional argument', node);
      }
      final type = expression(args.single.value);
      if (type != 'bool') fail('expect needs a bool condition', node);
      return 'void';
    }
    if ((symbol.dartName == 'min' || symbol.dartName == 'max') &&
        !symbol.external &&
        symbol.function == null) {
      if (args.length != 2 || args.any((argument) => argument.name != null)) {
        fail('${symbol.name} expects two positional arguments', node);
      }
      final left = expression(args[0].value);
      final right = expression(args[1].value);
      if (!numeric(left) || !numeric(right)) {
        fail('${symbol.name} expects numbers', node);
      }
      if (left != right && left != 'num' && right != 'num') {
        fail('${symbol.name} needs a single numeric type', node);
      }
      return left == 'num' || right == 'num' ? 'num' : left;
    }
    if (symbol.dartName == 'range' && !symbol.external) {
      if (args.isEmpty ||
          args.length > 2 ||
          args.any((argument) => argument.name != null)) {
        fail('range expects one or two positional arguments', node);
      }
      final types = [for (final argument in args) expression(argument.value)];
      if (types.any((type) => !numeric(type))) {
        fail('range bounds must be numbers', node);
      }
      return types.every((type) => type == 'int') ? 'Range<int>' : 'Range<num>';
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
      final (parameters, returns) = _functionParts(symbol.type);
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
    final invoked = _instanceCall(symbol);
    if (invoked != null) {
      return _applyCallMethod(node, symbol.type, invoked);
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
      if (argumentsMatch(node, candidate.parameters,
          commit: false, function: candidate)) {
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
    if (symbol.external &&
        node.arguments.any((argument) => argument.name != null)) {
      for (final argument in node.arguments) {
        expression(argument.value);
      }
      model.argumentOrder[node] =
          List.generate(node.arguments.length, (index) => index);
      return symbol.type;
    }
    final max = symbol.parameterTypes.length;
    final min = (max - symbol.optionalParameters).clamp(0, max);
    if (node.arguments.length < min || node.arguments.length > max) {
      fail(
          min == max
              ? '${symbol.name} expects $max arguments'
              : '${symbol.name} expects $min to $max arguments',
          node);
    }
    for (var i = 0; i < node.arguments.length; i++) {
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

  Symbol _appliedSymbol(CallExpression node, TypeApplication applied) {
    if (applied.callee is Identifier) {
      final name = (applied.callee as Identifier).name;
      final symbol = _scope.lookup(name);
      if (symbol == null) {
        fail(_hinted('Undefined function: $name', name, _visibleNames()), node);
      }
      model.references[applied.callee as Identifier] = symbol;
      model.references[node.callee] = symbol;
      _touch(symbol);
      return symbol;
    }
    if (applied.callee is MemberAccess) {
      final member = applied.callee as MemberAccess;
      if (member.object is Identifier) {
        final owner = _scope.lookup((member.object as Identifier).name);
        if (owner != null && owner.namespace != null) {
          model.references[member.object] = owner;
          model.types[member.object] = 'prefix';
          final found = owner.namespace![member.name];
          if (found == null) {
            fail(
                _hinted(
                    'Name ${member.name} is not defined',
                    member.name,
                    owner.namespace!.keys
                        .where((item) => !item.startsWith('_'))),
                member);
          }
          model.references[member] = found;
          model.references[node.callee] = found;
          _touch(found);
          return found;
        }
      }
    }
    fail('Type arguments need a name', applied);
  }

  String callApplied(CallExpression node, TypeApplication applied) {
    final symbol = _appliedSymbol(node, applied);
    final name = symbol.name;
    if (symbol.classDeclaration != null && symbol.classCase == null) {
      final returned =
          constructClass(node, symbol.classDeclaration!, applied.arguments);
      if (!symbol.dartName.contains('.')) return returned;
      final qualified = _qualifyType(
          symbol.dartName, returned, symbol.classDeclaration!.name);
      model.references[node.callee] = Symbol(
          symbol.dartName, symbol.dartName, qualified,
          classDeclaration: symbol.classDeclaration);
      return qualified;
    }
    final candidates = symbol.overloads.isEmpty && symbol.function != null
        ? [symbol.function!]
        : symbol.overloads;
    if (candidates.isEmpty) fail('$name is not callable', node);
    if (candidates.length != 1) {
      fail('Choose one overload with a call or a typed context', node);
    }
    final selected = candidates.single;
    if (applied.arguments.length != selected.typeParameters.length) {
      fail('Type arguments do not match ${selected.name}', node);
    }
    final substitution = {
      for (var i = 0; i < selected.typeParameters.length; i++)
        selected.typeParameters[i].name: applied.arguments[i]
    };
    for (var i = 0; i < selected.typeParameters.length; i++) {
      final bound = selected.typeParameters[i].bound;
      if (bound != null && !compatible(applied.arguments[i], bound)) {
        fail('Type ${applied.arguments[i]} is not a $bound', node);
      }
    }
    final parameters = [
      for (final parameter in selected.parameters)
        Parameter(parameter.name, _substitute(parameter.type, substitution),
            parameter.mutable, parameter.span,
            defaultValue: parameter.defaultValue, variadic: parameter.variadic)
    ];
    final returned = applyArguments(node, parameters, selected);
    final declared = model.declarations[selected]!.type;
    return declared == '<infer>'
        ? returned
        : _substitute(declared, substitution);
  }

  String constructClass(CallExpression node, ClassDeclaration type,
      [List<String> explicit = const []]) {
    if (type.modifiers.contains('singleton')) {
      fail(
          'Singleton ${type.name} is available as ${type.name}.instance', node);
    }
    if (type.modifiers.contains('abstract') || type.kind == 'interface') {
      error('E700', 'An abstract type cannot be constructed', node);
    }
    if (type.kind == 'extensionType') {
      final field = type.fields.single;
      final parameters = [
        Parameter(field.name, model.resolve(field.type), false, field.span)
      ];
      applyArguments(node, parameters, null);
      model.constCalls[node] = ConstConstructor(type.name, parameters,
          requirements: type.requirements);
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
      return _finishConstruct(node, type, parameters, explicit, constructor);
    }
    final parameters = <Parameter>[
      for (final field in _fieldsOf(type).where((field) =>
          !field.isStatic && !field.isEvent && field.lazyBody == null))
        Parameter(field.name, field.type, false, field.span,
            defaultValue: field.requiredField ? null : field.initializer)
    ];
    return _finishConstruct(node, type, parameters, explicit, null);
  }

  String _finishConstruct(
      CallExpression node,
      ClassDeclaration type,
      List<Parameter> parameters,
      List<String> explicit,
      ConstructorDeclaration? constructor) {
    final substitution =
        _constructorSubstitution(node, type, parameters, explicit);
    final instantiated = [
      for (final parameter in parameters)
        Parameter(parameter.name, _substitute(parameter.type, substitution),
            parameter.mutable, parameter.span,
            defaultValue: parameter.defaultValue,
            variadic: parameter.variadic,
            initializing: parameter.initializing)
    ];
    applyArguments(node, instantiated, null);
    model.references[node.callee] = type.constructors.isEmpty
        ? Symbol(type.name, type.name, type.name, classDeclaration: type)
        : Symbol(type.name, type.name, type.name,
            function: FunctionDeclaration(
                type.name, instantiated, type.name, null, null, type.span));
    final returned = type.typeParameters.isEmpty
        ? type.name
        : '${type.name}<${type.typeParameters.map((parameter) => substitution[parameter.name]!).join(', ')}>';
    if (constructor != null) {
      _rememberConstCall(node, constructor, instantiated, returned);
    }
    return returned;
  }

  void _rememberConstCall(
      CallExpression node,
      ConstructorDeclaration constructor,
      List<Parameter> parameters,
      String type) {
    if (!constructor.constant ||
        constructor.factory ||
        constructor.body != null ||
        constructor.expressionBody != null ||
        parameters.any((parameter) => parameter.variadic)) {
      return;
    }
    model.constCalls[node] = ConstConstructor(
      type,
      [
        for (final parameter in parameters)
          Parameter(
              parameter.name, parameter.type, parameter.mutable, parameter.span,
              defaultValue: constructor.parameters
                  .where((item) => item.name == parameter.name)
                  .firstOrNull
                  ?.defaultValue,
              variadic: parameter.variadic,
              initializing: parameter.initializing)
      ],
    );
  }

  Map<String, String> _constructorSubstitution(
      CallExpression node,
      ClassDeclaration type,
      List<Parameter> parameters,
      List<String> explicit) {
    if (type.typeParameters.isEmpty) return const {};
    if (explicit.isNotEmpty) {
      if (explicit.length != type.typeParameters.length) {
        fail('Type arguments do not match ${type.name}', node);
      }
      for (var i = 0; i < explicit.length; i++) {
        final bound = type.typeParameters[i].bound;
        if (bound != null && !compatible(explicit[i], bound)) {
          fail('Type ${explicit[i]} is not a $bound', node);
        }
      }
      return {
        for (var i = 0; i < explicit.length; i++)
          type.typeParameters[i].name: explicit[i]
      };
    }
    final found = <String, String>{};
    for (final argument in node.arguments) {
      final parameter = argument.name == null
          ? null
          : parameters.where((item) => item.name == argument.name).firstOrNull;
      if (parameter == null) continue;
      _inferType(parameter.type, expression(argument.value), found,
          type.typeParameters);
    }
    for (final parameter in type.typeParameters) {
      final inferred = found[parameter.name];
      if (inferred == null) {
        error('E302', 'A type cannot be inferred', node);
      }
      final bound = parameter.bound;
      if (bound != null && !compatible(inferred, bound)) {
        fail('Type $inferred is not a $bound', node);
      }
    }
    return found;
  }

  void _inferType(String parameterType, String argumentType,
      Map<String, String> found, List<TypeParameter> parameters) {
    if (parameters.any((parameter) => parameter.name == parameterType)) {
      found[parameterType] = argumentType;
      return;
    }
    for (final prefix in ['List<', 'Set<', 'Future<', 'Iterable<']) {
      if (parameterType.startsWith(prefix) &&
          parameterType.endsWith('>') &&
          argumentType.startsWith(prefix) &&
          argumentType.endsWith('>')) {
        _inferType(
            parameterType.substring(prefix.length, parameterType.length - 1),
            argumentType.substring(prefix.length, argumentType.length - 1),
            found,
            parameters);
      }
    }
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

  bool _accepts(String from, String to, FunctionDeclaration? function) {
    if (function != null &&
        function.typeParameters.any(
            (parameter) => RegExp('\\b${parameter.name}\\b').hasMatch(to))) {
      return _matchGeneric(to, from, function, <String, String>{});
    }
    if (compatible(from, to)) return true;
    if (function == null) return false;
    return _matchGeneric(to, from, function, <String, String>{});
  }

  /// `List<int>` matches `List<T>` when [function] declares `T`.
  bool _matchGeneric(String parameterType, String argumentType,
      FunctionDeclaration function, Map<String, String> found) {
    for (final parameter in function.typeParameters) {
      if (parameter.name != parameterType) continue;
      if (parameter.bound != null &&
          !compatible(argumentType, parameter.bound!)) {
        return false;
      }
      final previous = found[parameter.name];
      if (previous != null &&
          previous != argumentType &&
          !compatible(argumentType, previous) &&
          !compatible(previous, argumentType)) {
        return false;
      }
      found[parameter.name] = previous ?? argumentType;
      return true;
    }
    for (final prefix in ['List<', 'Set<', 'Iterable<', 'Future<']) {
      if (parameterType.startsWith(prefix) &&
          parameterType.endsWith('>') &&
          argumentType.startsWith(prefix) &&
          argumentType.endsWith('>')) {
        return _matchGeneric(
            parameterType.substring(prefix.length, parameterType.length - 1),
            argumentType.substring(prefix.length, argumentType.length - 1),
            function,
            found);
      }
    }
    return false;
  }

  bool argumentsMatch(CallExpression node, List<Parameter> parameters,
      {required bool commit, FunctionDeclaration? function}) {
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
      if (!_accepts(type, parameters[target].type, function)) return false;
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
      case SliceExpression():
        restrictDefault(node.object, earlier, all);
        if (node.start != null) restrictDefault(node.start!, earlier, all);
        if (node.end != null) restrictDefault(node.end!, earlier, all);
      case ChainComparison():
        for (final operand in node.operands) {
          restrictDefault(operand, earlier, all);
        }
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
    if (!argumentsMatch(node, parameters, commit: true, function: function)) {
      fail('No overload matches this call', node);
    }
    final inferred = <String, String>{};
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
      if (!_accepts(type, parameters[target].type, function)) {
        fail(
            'Argument type $type is incompatible with ${parameters[target].type}',
            argument);
      }
      _rememberInference(function, parameters[target].type, type, inferred);
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
      return '($types) -> ${_substitute(returned, inferred)}';
    }
    if (function != null && model.declarations[function]!.type == '<infer>') {
      analyzeFunction(function);
    }
    final returned =
        function == null ? 'void' : model.declarations[function]!.type;
    if (function != null) {
      for (final parameter in function.typeParameters) {
        if (inferred.containsKey(parameter.name)) continue;
        if (RegExp('\\b${parameter.name}\\b').hasMatch(returned)) {
          error('E302', 'A type cannot be inferred', node);
        }
      }
    }
    return _substitute(returned, inferred);
  }

  void _rememberInference(FunctionDeclaration? function, String parameter,
      String argument, Map<String, String> inferred) {
    if (function == null) return;
    final found = <String, String>{};
    if (!_matchGeneric(parameter, argument, function, found)) return;
    for (final entry in found.entries) {
      final previous = inferred[entry.key];
      if (previous != null &&
          previous != entry.value &&
          !compatible(entry.value, previous) &&
          !compatible(previous, entry.value)) {
        fail('Type argument ${entry.value} conflicts with $previous', function);
      }
      inferred[entry.key] ??= entry.value;
    }
  }

  static const _ffiNative = {
    'Int8',
    'Int16',
    'Int32',
    'Int64',
    'Uint8',
    'Uint16',
    'Uint32',
    'Uint64',
    'Float',
    'Double',
    'Void',
    'Abi',
    'Pointer',
  };

  (String, Map<String, String>)? _collectionVars(String type) {
    if (type.startsWith('List<') && type.endsWith('>')) {
      return ('List', {'T': type.substring(5, type.length - 1)});
    }
    if (type.startsWith('Set<') && type.endsWith('>')) {
      return ('Set', {'T': type.substring(4, type.length - 1)});
    }
    if (type.startsWith('Iterable<') && type.endsWith('>')) {
      return ('Iterable', {'T': type.substring(9, type.length - 1)});
    }
    if (type.startsWith('Range<') && type.endsWith('>')) {
      return ('Iterable', {'T': type.substring(6, type.length - 1)});
    }
    if (type.startsWith('Map<') && type.endsWith('>')) {
      final parts = _splitTypes(type.substring(4, type.length - 1));
      if (parts.length != 2) return null;
      return ('Map', {'K': parts[0], 'V': parts[1]});
    }
    if (type == 'String') return ('String', const {});
    return null;
  }

  String _subst(String pattern, Map<String, String> vars) {
    final buffer = StringBuffer();
    final name = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');
    var start = 0;
    for (final match in name.allMatches(pattern)) {
      buffer.write(pattern.substring(start, match.start));
      final word = match.group(0)!;
      buffer.write(vars[word] ?? word);
      start = match.end;
    }
    buffer.write(pattern.substring(start));
    return buffer.toString();
  }

  (List<(String, String)>, String)? _methodShape(String family, String name) {
    return switch ((family, name)) {
      ('List', 'add') => ([('value', 'T')], 'void'),
      ('List', 'addAll') => ([('values', 'Iterable<T>')], 'void'),
      ('List', 'insert') => ([('index', 'int'), ('value', 'T')], 'void'),
      ('List', 'insertAll') => (
          [('index', 'int'), ('values', 'Iterable<T>')],
          'void'
        ),
      ('List', 'removeAt') => ([('index', 'int')], 'T'),
      ('List', 'removeLast') => (<(String, String)>[], 'T'),
      ('List', 'sort') => (<(String, String)>[], 'void'),
      ('List', 'sublist') => ([('start', 'int')], 'List<T>'),
      ('List', 'getRange') => (
          [('start', 'int'), ('end', 'int')],
          'Iterable<T>'
        ),
      ('List', 'indexOf') => ([('value', 'Object')], 'int'),
      ('Set', 'add') => ([('value', 'T')], 'bool'),
      ('Set', 'addAll') => ([('values', 'Iterable<T>')], 'void'),
      ('Set' || 'List', 'remove') => ([('value', 'Object')], 'bool'),
      ('Set' || 'List', 'clear') => (<(String, String)>[], 'void'),
      ('Iterable', 'contains') => ([('value', 'Object')], 'bool'),
      ('Iterable', 'elementAt') => ([('index', 'int')], 'T'),
      ('Iterable', 'toList') => (<(String, String)>[], 'List<T>'),
      ('Iterable', 'toSet') => (<(String, String)>[], 'Set<T>'),
      ('Iterable', 'any' || 'every' || 'where') => (
          [('test', '(T) -> bool')],
          name == 'where' ? 'Iterable<T>' : 'bool'
        ),
      ('Iterable', 'forEach') => ([('action', '(T) -> void')], 'void'),
      ('Map', 'containsKey') => ([('key', 'Object')], 'bool'),
      ('Map', 'remove') => ([('key', 'Object')], 'V?'),
      ('Map', 'clear') => (<(String, String)>[], 'void'),
      ('Map', 'addAll') => ([('other', 'Map<K, V>')], 'void'),
      ('Map', 'putIfAbsent') => ([('key', 'K'), ('ifAbsent', '() -> V')], 'V'),
      ('Map', 'forEach') => ([('action', '(K, V) -> void')], 'void'),
      ('String', 'contains' || 'startsWith' || 'endsWith') => (
          [('other', 'String')],
          'bool'
        ),
      ('String', 'substring') => ([('start', 'int')], 'String'),
      ('String', 'toUpperCase' || 'toLowerCase' || 'trim') => (
          <(String, String)>[],
          'String'
        ),
      ('String', 'split') => ([('pattern', 'String')], 'List<String>'),
      ('String', 'indexOf') => ([('pattern', 'String')], 'int'),
      ('String', 'replaceAll') => (
          [('from', 'String'), ('to', 'String')],
          'String'
        ),
      _ => null,
    };
  }

  String? _getterShape(String family, String name) {
    return switch ((family, name)) {
      ('String', 'chars' || 'lines') => 'List<String>',
      ('Iterable' || 'List' || 'Set' || 'Map' || 'String', 'isEmpty') => 'bool',
      ('Iterable' || 'List' || 'Set' || 'Map' || 'String', 'isNotEmpty') =>
        'bool',
      ('Iterable', 'length') => 'int',
      ('Iterable' || 'List' || 'Set', 'first' || 'last') => 'T',
      ('List', 'reversed') => 'Iterable<T>',
      ('Map', 'keys') => 'Iterable<K>',
      ('Map', 'values') => 'Iterable<V>',
      _ => null,
    };
  }

  String _dartHead(String type) {
    var bare = type.startsWith('readonly ') ? type.substring(9) : type;
    if (bare.endsWith('?')) bare = bare.substring(0, bare.length - 1);
    return _genericHead(bare);
  }

  DartMember? _sdkMember(String type, String name) {
    return model.dartShapes[_dartHead(type)]?.members[name];
  }

  String? _dartCall(String type, String name, CallExpression node) {
    final member = _sdkMember(type, name);
    if (member == null || member.getter) return null;
    final symbol = _dartMemberSymbol(member, member.type);
    model.references[node.callee] = symbol;
    return externalCall(node, symbol);
  }

  String? _collectionGetter(String type, String name) {
    final found = _collectionVars(type);
    if (found == null) return null;
    final (family, vars) = found;
    final shape = _getterShape(family, name) ??
        ((family == 'List' || family == 'Set')
            ? _getterShape('Iterable', name)
            : null);
    if (shape == null) return null;
    return _subst(shape, vars);
  }

  String? _collectionCall(String type, String name, CallExpression node) {
    final found = _collectionVars(type);
    if (found == null) return null;
    final (family, vars) = found;
    if (family == 'String') {
      final text = _textCall(name, node);
      if (text != null) return text;
    }
    final element = vars['T'];
    if (element != null &&
        (family == 'List' || family == 'Set' || family == 'Iterable')) {
      final eager = _eagerCollection(element, name, node);
      if (eager != null) return eager;
    }
    final shape = _methodShape(family, name) ??
        ((family == 'List' || family == 'Set')
            ? _methodShape('Iterable', name)
            : null);
    if (shape == null) return null;
    final parameters = [
      for (final (parameter, parameterType) in shape.$1)
        Parameter(parameter, _subst(parameterType, vars), false, node.span),
    ];
    final returns = _subst(shape.$2, vars);
    final function =
        FunctionDeclaration(name, parameters, returns, null, null, node.span);
    final symbol = Symbol(name, name, returns).withFunction(function);
    model.declarations[function] = symbol;
    model.references[node.callee] = symbol;
    applyArguments(node, parameters, function);
    return returns;
  }

  static const _collectionDocs = {
    'map': 'Builds a new list by applying transform to each element.',
    'fold': 'Combines every element into one value, starting from initial.',
    'reduce':
        'Combines every element into one value. An empty collection fails.',
    'sum': 'Adds numeric elements. An empty collection sums to zero.',
    'min': 'The smallest number, or null when the collection is empty.',
    'max': 'The largest number, or null when the collection is empty.',
    'count': 'How many elements there are, or how many match test.',
    'find': 'The first matching element, or null.',
    'findLast': 'The last matching element, or null.',
    'take': 'A new list of the first count elements.',
    'drop': 'Everything after the first count elements.',
    'takeLast': 'The last count elements.',
    'dropLast': 'Everything except the last count elements.',
    'skip': 'A new list without the first count elements.',
    'pad':
        'The number written with zeros on the left until it is width characters. A minus sign stays in front of the zeros.',
    'padStart':
        'The text with fill on the left until it is width characters. The fill defaults to a space.',
    'padEnd':
        'The text with fill on the right until it is width characters. The fill defaults to a space.',
    'zip':
        'Pairs each element with the element at the same position. Stops at the shorter collection.',
    'lines':
        'The text split into lines. Line endings are removed and empty lines stay.',
    'clamp': 'The number limited to the inclusive bounds.',
    'sorted':
        'A new list in order. Numbers and strings compare themselves. Anything else needs a comparison.',
    'unique': 'A new list keeping the first occurrence of each element.',
    'flat': 'A new list of the elements inside each nested collection.',
    'group': 'A map from each key to the elements that produced it.',
    'join': 'Joins the elements. The separator defaults to empty.',
    'substring': 'The slice from start, through the character before end.',
  };

  String? _eagerCollection(String element, String name, CallExpression node) {
    final span = node.span;
    Parameter param(String parameterName, String type) =>
        Parameter(parameterName, type, false, span);
    switch (name) {
      case 'map':
        final transform = _argumentValue(node, 'transform', 0);
        if (node.arguments.length != 1 || transform == null) {
          fail('map expects one argument', node);
        }
        final saved = _expected;
        _expected = '($element) -> Object';
        final callback = expression(transform);
        _expected = saved;
        if (!compatible(callback, '($element) -> Object')) {
          fail(
              'Argument type $callback is incompatible with ($element) -> Object',
              node);
        }
        final result = _functionParts(callback).$2;
        if (result == 'void') fail('map transform must not be void', node);
        return _bindCollection(
            name,
            '_qmap',
            [param('transform', '($element) -> Object')],
            'List<$result>',
            node,
            'map(transform: $callback) -> List<$result>');
      case 'fold':
        final initial = _argumentValue(node, 'initial', 0);
        final combine = _argumentValue(node, 'combine', 1);
        if (node.arguments.length != 2 || initial == null || combine == null) {
          fail('fold expects two arguments', node);
        }
        final seed = expression(initial);
        if (seed == 'void') fail('fold initial must not be void', node);
        return _bindCollection(
            name,
            '_qfold',
            [
              param('initial', seed),
              param('combine', '($seed, $element) -> $seed'),
            ],
            seed,
            node,
            'fold(initial: $seed, combine: ($seed, $element) -> $seed) -> $seed');
      case 'reduce':
        return _bindCollection(
            name,
            '_qreduce',
            [param('combine', '($element, $element) -> $element')],
            element,
            node,
            'reduce(combine: ($element, $element) -> $element) -> $element');
      case 'sum':
        if (node.arguments.isNotEmpty) fail('sum expects no arguments', node);
        if (element != 'int' && element != 'double' && element != 'num') {
          fail('sum must be numeric', node);
        }
        return _bindCollection(
            name, '_qsum', const [], element, node, 'sum() -> $element');
      case 'min' || 'max':
        if (node.arguments.isNotEmpty) {
          fail('$name expects no arguments', node);
        }
        if (element != 'int' && element != 'double' && element != 'num') {
          fail('$name must be numeric', node);
        }
        return _bindCollection(name, name == 'min' ? '_qmin' : '_qmax',
            const [], '$element?', node, '$name() -> $element?');
      case 'count':
        if (node.arguments.isEmpty) {
          return _bindCollection(
              name, '_qcount', const [], 'int', node, 'count() -> int');
        }
        return _bindCollection(
            name,
            '_qcountWhere',
            [param('test', '($element) -> bool')],
            'int',
            node,
            'count(test: ($element) -> bool) -> int');
      case 'find' || 'findLast':
        final dart = name == 'find' ? '_qfind' : '_qfindLast';
        return _bindCollection(
            name,
            dart,
            [param('test', '($element) -> bool')],
            '$element?',
            node,
            '$name(test: ($element) -> bool) -> $element?');
      case 'zip':
        final other = _argumentValue(node, 'other', 0);
        if (node.arguments.length != 1 || other == null) {
          fail('zip expects one argument', node);
        }
        final otherType = expression(other);
        var stored = otherType.startsWith('readonly ')
            ? otherType.substring(9)
            : otherType;
        if (stored.endsWith('?')) fail('zip expects an iterable', other);
        stored = unwrap(stored);
        final otherElement = _sequenceElement(stored);
        if (otherElement == null) fail('zip expects an iterable', other);
        return _bindCollection(
            name,
            '_qzip',
            [param('other', stored)],
            'List<($element, $otherElement)>',
            node,
            'zip(other: $stored) -> List<($element, $otherElement)>');
      case 'take' || 'skip' || 'drop':
        final dart = switch (name) {
          'take' => '_qtake',
          'drop' => '_qdrop',
          _ => '_qskip',
        };
        return _bindCollection(name, dart, [param('count', 'int')],
            'List<$element>', node, '$name(count: int) -> List<$element>');
      case 'takeLast' || 'dropLast':
        return _bindCollection(
            name,
            name == 'takeLast' ? '_qtakeLast' : '_qdropLast',
            [param('count', 'int')],
            'List<$element>',
            node,
            '$name(count: int) -> List<$element>');
      case 'sorted':
        if (node.arguments.isEmpty) {
          if (element != 'int' &&
              element != 'double' &&
              element != 'num' &&
              element != 'String') {
            fail(
                'sorted must be numeric or String, or pass a comparison', node);
          }
          return _bindCollection(name, '_qsorted', const [], 'List<$element>',
              node, 'sorted() -> List<$element>');
        }
        return _bindCollection(
            name,
            '_qsortedBy',
            [param('compare', '($element, $element) -> int')],
            'List<$element>',
            node,
            'sorted(compare: ($element, $element) -> int) -> List<$element>');
      case 'unique':
        if (node.arguments.isNotEmpty) {
          fail('unique expects no arguments', node);
        }
        return _bindCollection(name, '_qunique', const [], 'List<$element>',
            node, 'unique() -> List<$element>');
      case 'flat':
        if (node.arguments.isNotEmpty) fail('flat expects no arguments', node);
        final inner = _collectionElement(element);
        if (inner == null)
          fail('flat must be a collection of collections', node);
        return _bindCollection(name, '_qflat', const [], 'List<$inner>', node,
            'flat() -> List<$inner>');
      case 'group':
        final keyOf = _argumentValue(node, 'key', 0);
        if (node.arguments.length != 1 || keyOf == null) {
          fail('group expects one argument', node);
        }
        final saved = _expected;
        _expected = '($element) -> Object';
        final callback = expression(keyOf);
        _expected = saved;
        if (!compatible(callback, '($element) -> Object')) {
          fail(
              'Argument type $callback is incompatible with ($element) -> Object',
              node);
        }
        final key = _functionParts(callback).$2;
        if (key == 'void') fail('group key must not be void', node);
        return _bindCollection(
            name,
            '_qgroup',
            [param('key', '($element) -> $key')],
            'Map<$key, List<$element>>',
            node,
            'group(key: $callback) -> Map<$key, List<$element>>');
      case 'join':
        if (node.arguments.isEmpty) {
          return _bindCollection(
              name, '_qjoin', const [], 'String', node, 'join() -> String');
        }
        return _bindCollection(
            name,
            '_qjoinSep',
            [param('separator', 'String')],
            'String',
            node,
            'join(separator: String) -> String');
      default:
        return null;
    }
  }

  String? _textCall(String name, CallExpression node) {
    switch (name) {
      case 'substring':
        return _substringCall(node);
      case 'take' || 'drop' || 'takeLast' || 'dropLast':
        return _bindCollection(
            name,
            '_q${name}Text',
            [Parameter('count', 'int', false, node.span)],
            'String',
            node,
            '$name(count: int) -> String');
      case 'padStart' || 'padEnd':
        final width = _argumentValue(node, 'width', 0);
        final fill = _argumentValue(node, 'fill', 1);
        if (width == null || (fill == null && node.arguments.length != 1)) {
          fail('$name expects a width and an optional fill', node);
        }
        final parameters = [
          Parameter('width', 'int', false, node.span),
          if (fill != null) Parameter('fill', 'String', false, node.span),
        ];
        return _bindCollection(name, '_q$name', parameters, 'String', node,
            '$name(width: int, fill: String) -> String');
      default:
        return null;
    }
  }

  String? _numberCall(String type, String name, CallExpression node) {
    if (!numeric(type)) return null;
    if (name == 'clamp') {
      final bound = type == 'num' ? 'num' : type;
      return _bindCollection(
          name,
          '_qclamp',
          [
            Parameter('lower', bound, false, node.span),
            Parameter('upper', bound, false, node.span),
          ],
          type,
          node,
          'clamp(lower: $bound, upper: $bound) -> $type');
    }
    if (name == 'pad' && type == 'int') {
      return _bindCollection(
          name,
          '_qpad',
          [Parameter('width', 'int', false, node.span)],
          'String',
          node,
          'pad(width: int) -> String');
    }
    if (name == 'fixed') {
      return _bindCollection(
          name,
          '_qfixed',
          [Parameter('digits', 'int', false, node.span)],
          'String',
          node,
          'fixed(digits: int) -> String');
    }
    return null;
  }

  String? _numberGetter(String type, String name) {
    if (!numeric(type)) return null;
    return switch (name) {
      'abs' => type,
      'round' || 'floor' || 'ceil' => 'int',
      'plain' => 'String',
      _ => null,
    };
  }

  String? _substringCall(CallExpression node) {
    if (node.arguments.isEmpty || node.arguments.length > 2) {
      fail('substring expects one or two arguments', node);
    }
    final parameters = [
      Parameter('start', 'int', false, node.span),
      if (node.arguments.length == 2) Parameter('end', 'int', false, node.span),
    ];
    final signature = node.arguments.length == 1
        ? 'substring(start: int) -> String'
        : 'substring(start: int, end: int) -> String';
    return _bindCollection(
        'substring', '_qsubstring', parameters, 'String', node, signature);
  }

  String _bindCollection(
    String name,
    String dartName,
    List<Parameter> parameters,
    String returns,
    CallExpression node,
    String signature,
  ) {
    final function =
        FunctionDeclaration(name, parameters, returns, null, null, node.span);
    final symbol = Symbol(name, dartName, returns,
            documentation: _collectionDocs[name], signature: signature)
        .withFunction(function);
    model.declarations[function] = symbol;
    model.references[node.callee] = symbol;
    applyArguments(node, parameters, function);
    return returns;
  }

  Expression? _argumentValue(CallExpression node, String name, int index) {
    for (final argument in node.arguments) {
      if (argument.name == name) return argument.value;
    }
    final positional = [
      for (final argument in node.arguments)
        if (argument.name == null) argument,
    ];
    if (index < positional.length) return positional[index].value;
    return null;
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
      if (outer == null) {
        fail(_hinted('Undefined symbol: $name', name, _visibleNames()), node);
      }
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
    if (symbol == null) {
      fail(
          _hinted('Undefined symbol: ${node.name}', node.name, _visibleNames()),
          node);
    }
    if (symbol.readonly) {
      error('E307', 'A readonly reference cannot be mutated', node);
    }
    if (!symbol.mutable) {
      fail('Cannot assign immutable binding ${node.name}', node);
    }
    model.references[node] = symbol;
    final type = expression(node.value);
    if (node.operator == '??=') {
      _checkIfNull(symbol.type, type, node);
    } else {
      final result = node.operator == '='
          ? type
          : binaryType(symbol.type, node.operator[0], type, node);
      if (!compatible(result, symbol.type)) {
        fail('Cannot assign $result to ${symbol.type}', node);
      }
    }
    _afterAssignment(node.name, symbol.type, type, node.operator);
    return _promoted[node.name] ?? symbol.type;
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
    if (node.index != null) {
      if (node.index == node.name) {
        fail('Loop bindings must have different names', node);
      }
      if (_scope.lookup(node.index!) != null) {
        fail('Loop binding would shadow ${node.index}', node);
      }
    }
    if (node.body.isEmpty) fail('collection for needs an element', node);
    final pair = node.index == null ? null : _pairFields(element);
    final symbol = create(node.name, pair == null ? element : pair[1]);
    model.declarations[node] = symbol;
    final saved = _scope;
    _scope = _Scope(saved);
    _scope.symbols[node.name] = symbol;
    if (node.index != null) {
      final index = create(node.index!, pair == null ? 'int' : pair[0]);
      model.loopIndexes[node] = index;
      _scope.symbols[node.index!] = index;
      if (pair != null) model.loopPairs.add(node);
    }
    if (node.filter != null && expression(node.filter!) != 'bool') {
      fail('collection filter must be bool', node.filter!);
    }
    final type = groupElementType(node.body);
    _scope = saved;
    return type;
  }

  bool _rangeIterable(Expression node) {
    if (node is RangeExpression) return true;
    if (node is! CallExpression || node.callee is! Identifier) return false;
    final symbol = model.references[node.callee];
    return symbol != null &&
        symbol.name == 'range' &&
        symbol.function == null &&
        !symbol.external;
  }

  String? _joinedCollection(String left, String right) {
    final a = _plainCollection(left);
    final b = _plainCollection(right);
    if (a == null || b == null) return null;
    if (a.startsWith('List<') && b.startsWith('List<')) {
      final element = _joinTypes(
          a.substring(5, a.length - 1), b.substring(5, b.length - 1));
      if (element == null) return null;
      return 'List<$element>';
    }
    if (a.startsWith('Map<') && b.startsWith('Map<')) {
      final leftParts = _mapArgs(a);
      final rightParts = _mapArgs(b);
      if (leftParts == null || rightParts == null) return null;
      final keys = leftParts.$1 == rightParts.$1 ||
          (compatible(leftParts.$1, rightParts.$1) &&
              compatible(rightParts.$1, leftParts.$1));
      if (!keys) return null;
      final value = _joinTypes(leftParts.$2, rightParts.$2);
      if (value == null) return null;
      return 'Map<${leftParts.$1}, $value>';
    }
    return null;
  }

  String? _plainCollection(String type) {
    final bare = type.startsWith('readonly ') ? type.substring(9) : type;
    if (bare.endsWith('?')) return null;
    if (bare.startsWith('List<') && bare.endsWith('>')) return bare;
    if (bare.startsWith('Map<') && bare.endsWith('>')) return bare;
    return null;
  }

  (String, String)? _mapArgs(String type) {
    final parts = _splitTypes(type.substring(4, type.length - 1));
    if (parts.length != 2) return null;
    return (parts[0], parts[1]);
  }

  String? _joinTypes(String left, String right) {
    if (left == right) return left;
    if (numeric(left) && numeric(right)) return 'num';
    if (compatible(left, right)) return right;
    if (compatible(right, left)) return left;
    return null;
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
    if (step is Literal && (step.value == 0 || step.value == 0.0)) return true;
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
    final declaration =
        _global.symbols[_genericHead(matched)]?.classDeclaration;
    final finite = declaration != null &&
        (declaration.kind == 'sealedType' || declaration.kind == 'enum');
    final result = matched.startsWith('Result<') && matched.endsWith('>');
    final universe = matched.contains(' | ')
        ? matched.split(' | ').map((part) => part.trim()).toSet()
        : result
            ? {'Ok', 'Error'}
            : finite
                ? declaration.cases.map((item) => item.name).toSet()
                : _sealedSubtypes(declaration);
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

  Expression? _slot(Statement statement) => switch (statement) {
        ReturnStatement(:final value) => value,
        Binding(:final value) => value,
        MemberAssignment(:final value) => value,
        ThrowStatement(:final value) => value,
        YieldStatement(:final value) => value,
        ResultStatement(:final value) => value,
        ExpressionStatement(:final expression) => _callSlot(expression),
        _ => null,
      };

  Expression? _callSlot(Expression expression) {
    if (expression is! CallExpression || expression.arguments.length != 1) {
      return null;
    }
    final argument = expression.arguments.single;
    if (argument.name != null || argument.value is SpreadElement) return null;
    return argument.value;
  }

  void _liftExcept(_Scope outer, Set<String> local) {
    for (final entry in _scope.symbols.entries) {
      if (local.contains(entry.key)) continue;
      outer.symbols[entry.key] = entry.value;
    }
  }

  Set<String> _patternNames(Pattern pattern) {
    final names = <String>{};
    void walk(Pattern node) {
      switch (node) {
        case BindingPattern():
          names.add(node.name);
        case TypedPattern():
          if (node.name != null) names.add(node.name!);
        case RestPattern():
          if (node.name != null) names.add(node.name!);
        case ListPattern():
          for (final element in node.elements) {
            walk(element);
          }
        case ConstructorPattern():
          for (final field in node.fields) {
            walk(field);
          }
        case MapPattern():
          for (final value in node.values) {
            walk(value);
          }
        case OrPattern():
          walk(node.left);
          walk(node.right);
        case AndPattern():
          walk(node.left);
          walk(node.right);
        case CastPattern(:final inner):
        case NullCheckPattern(:final inner):
        case NullAssertPattern(:final inner):
          walk(inner);
        default:
          break;
      }
    }

    walk(pattern);
    return names;
  }

  void _joinGuarded(GuardedStatement node, String elseType) {
    final slot = _slot(node.statement);
    final slotType = slot == null ? null : model.types[slot];
    if (slot == null || slotType == null) {
      fail('else needs a value', node.alternate!);
    }
    final joined = joinTypes(slotType, elseType, node.alternate!);
    if (node.statement case Binding binding) {
      if (binding.mode == BindingMode.constant) {
        fail('A const binding cannot use else', node.alternate!);
      }
      final declared = model.declarations[binding];
      if (declared != null) declared.type = joined;
      final existing = model.references[binding];
      if (existing != null && !compatible(elseType, existing.type)) {
        fail('Cannot assign $elseType to ${existing.type}', node.alternate!);
      }
    }
    if (node.statement is ReturnStatement &&
        _returnType != null &&
        _returnType != '<infer>' &&
        !compatible(elseType, _returnType!)) {
      fail('Return type $elseType is incompatible with $_returnType',
          node.alternate!);
    }
  }

  String _nullable(String type) {
    if (type == 'Null' || type.endsWith('?')) return type;
    return '$type?';
  }

  String loopExpression(LoopExpression node) {
    _armValueLoop = true;
    _valueBreakType = null;
    check(node.loop);
    final breakType = _valueBreakType;
    if (breakType == null) fail('A value loop needs a break value', node);
    final fallback = node.fallback;
    if (fallback == null) return _nullable(breakType);
    final elseType = expression(fallback);
    if (elseType == 'Null') return _nullable(breakType);
    if (elseType == breakType || elseType == '$breakType?') return elseType;
    if (breakType == '$elseType?') return breakType;
    return joinTypes(breakType, elseType, fallback);
  }

  String whereExpression(WhereExpression node) {
    if (node.bindings.isEmpty) fail('where needs a binding', node);
    final saved = _scope;
    _scope = _Scope(saved);
    for (final binding in node.bindings) {
      check(binding);
    }
    final type = expression(node.value);
    _scope = saved;
    return type;
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

  Set<String>? _sealedSubtypes(ClassDeclaration? declaration) {
    if (declaration == null) return null;
    final sealed = declaration.kind == 'sealed' ||
        declaration.modifiers.contains('sealed');
    if (!sealed || declaration.kind == 'sealedType') return null;
    final home = model.libraryOf[declaration] ?? '';
    final names = <String>{};
    for (final type in model.classes.values) {
      if (type.superclass != declaration.name) continue;
      final here = model.libraryOf[type] ?? '';
      if (home.isNotEmpty && here != home) continue;
      names.add(type.name);
    }
    return names;
  }

  Set<String>? _covered(Pattern pattern, Set<String> universe) {
    return switch (pattern) {
      WildcardPattern() => null,
      TypedPattern() => {pattern.type},
      BindingPattern() =>
        model.references[pattern]?.classCase == null ? null : {pattern.name},
      ConstructorPattern() =>
        pattern.typeName.isEmpty ? null : {pattern.typeName},
      LiteralPattern() ||
      ListPattern() ||
      MapPattern() ||
      RestPattern() ||
      RelationalPattern() ||
      CastPattern() ||
      NullCheckPattern() ||
      NullAssertPattern() =>
        <String>{},
      OrPattern() => _unionCovered(pattern.left, pattern.right, universe),
      AndPattern() => _intersectCovered(pattern.left, pattern.right, universe),
    };
  }

  Set<String>? _unionCovered(
      Pattern left, Pattern right, Set<String> universe) {
    final first = _covered(left, universe);
    final second = _covered(right, universe);
    if (first == null || second == null) return null;
    return {...first, ...second};
  }

  Set<String>? _intersectCovered(
      Pattern left, Pattern right, Set<String> universe) {
    final first = _covered(left, universe);
    final second = _covered(right, universe);
    if (first == null) return second;
    if (second == null) return first;
    return first.intersection(second);
  }
}
