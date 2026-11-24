import 'type_syntax.dart';
import 'dart:io';
import 'dart:convert';

import 'hash.dart';

import 'ast.dart';
import 'checks.dart';
import 'constants.dart';
import 'dart_api.dart';
import 'libraries.dart';
import 'sdk.dart';
import 'source.dart';
import 'walk.dart';

/// Stable provider ABI for the supported top-level computed-default slice.
bool supportsProviderDefaults(FunctionDeclaration function) =>
    function.visibility != 'private' &&
    !function.name.startsWith('_') &&
    !function.span.file.startsWith('quds:') &&
    (function.returnType != null || function.expressionBody != null) &&
    function.generator.isEmpty &&
    function.parameters.any((p) => p.needsAdapter) &&
    _providerDefaultsAreSynchronous(function) &&
    !function.parameters.any((p) => p.variadic || p.type.contains(' & ')) &&
    portableParameterLayout(function.parameters);

bool portableParameterLayout(List<Parameter> parameters) {
  var optional = false;
  var positionalOptional = false;
  var named = false;
  for (final parameter in parameters) {
    positionalOptional |= parameter.kind == ParameterKind.optionalPositional;
    named |= parameter.isNamed;
    if (parameter.defaultValue != null) {
      optional = true;
    } else if (optional && parameter.kind != ParameterKind.requiredNamed) {
      return false;
    }
  }
  return !(positionalOptional && named);
}

/// A stored value whose groups cannot be one Dart function. Calls pass
/// `(List<Object?>, List<bool>)` in signature order and the provider applies
/// defaults. A named default followed by a required positional parameter stays
/// a reordered Dart signature.
bool packetValueLayout(List<Parameter> parameters) {
  final positionalOptional = parameters
      .any((parameter) => parameter.kind == ParameterKind.optionalPositional);
  final named = parameters.any((parameter) => parameter.isNamed);
  if (positionalOptional && named) return true;
  if (!parameters.any((parameter) => parameter.variadic)) return false;
  return parameters.any((parameter) =>
      parameter.defaultValue != null ||
      parameter.kind == ParameterKind.optionalPositional ||
      parameter.isNamed);
}

/// Positional and variadic slots, then named slots. Matches [_callableSignature].
List<Parameter> packetSlots(List<Parameter> parameters) {
  final positional = <Parameter>[];
  final named = <Parameter>[];
  for (final parameter in parameters) {
    final namedSlot = parameter.kind == ParameterKind.requiredNamed ||
        (parameter.defaultValue != null &&
            parameter.kind != ParameterKind.optionalPositional &&
            !parameter.variadic);
    if (namedSlot) {
      named.add(parameter);
    } else {
      positional.add(parameter);
    }
  }
  return [...positional, ...named];
}

bool packetSignature(List<FunctionParameterShape> parameters) {
  final positionalOptional = parameters.any((parameter) =>
      parameter.optional && !parameter.named && !parameter.variadic);
  final named = parameters.any((parameter) => parameter.named);
  if (positionalOptional && named) return true;
  if (!parameters.any((parameter) => parameter.variadic)) return false;
  return parameters.any((parameter) => parameter.optional || parameter.named);
}

bool _providerDefaultsAreSynchronous(FunctionDeclaration function) {
  var synchronous = true;
  for (final parameter in function.parameters) {
    final value = parameter.defaultValue;
    if (value == null) continue;
    walkAst(value, (node) {
      if (node is AwaitExpression) synchronous = false;
    });
  }
  return synchronous;
}

String providerDefaultBridgeName(FunctionDeclaration function) =>
    r'$QudsDefault' +
    sha256Hex(utf8.encode(jsonEncode([
      function.name,
      function.returnType,
      function.isAsync,
      for (final p in function.typeParameters) [p.name, p.bound],
      for (final p in function.parameters)
        [p.name, p.type, p.defaultValue != null, p.kind.name],
    ]))).substring(0, 20);

/// Direct unions have a checked payload ABI at top-level library boundaries.
/// Nested/generic unions require a separate representation contract.
bool directUnionType(String type) =>
    type.contains(' | ') &&
    functionTypeParts(type) == null &&
    !type.contains('<') &&
    !type.contains('(') &&
    !type.startsWith('readonly ');

bool supportsUnionBoundary(FunctionDeclaration function) =>
    function.visibility != 'private' &&
    !function.name.startsWith('_') &&
    function.typeParameters.isEmpty &&
    function.generator.isEmpty &&
    !function.isAsync &&
    !function.parameters.any((p) => p.variadic) &&
    !packetValueLayout(function.parameters) &&
    _providerDefaultsAreSynchronous(function) &&
    [function.returnType ?? '', ...function.parameters.map((p) => p.type)]
        .any(directUnionType) &&
    [function.returnType ?? '', ...function.parameters.map((p) => p.type)]
        .every((type) =>
            !type.contains(' & ') &&
            (!type.contains(' | ') || directUnionType(type)));

String providerUnionBridgeName(FunctionDeclaration function) =>
    providerDefaultBridgeName(function)
        .replaceFirst(r'$QudsDefault', r'$QudsUnionCall');

/// Unions/intersections need their own portable boundary conformance.
bool supportsInterfaceDefaults(
        ClassDeclaration owner, FunctionDeclaration method) =>
    !method.isStatic &&
    !method.isOperator &&
    supportsProviderDefaults(method) &&
    [
      if (method.returnType != null) method.returnType!,
      ...method.parameters.map((p) => p.type),
      for (final p in method.typeParameters)
        if (p.bound != null) p.bound!
    ].every((type) => !type.contains(' & ') && !type.contains(' | '));

String substituteBridgeType(String type, Map<String, String> substitution) {
  if (substitution.isEmpty) return type;
  final names = substitution.keys.map(RegExp.escape).join('|');
  return type.replaceAllMapped(
      RegExp('(?<![\\w.])($names)\\b(?!\\s*:)(\\?)?'),
      (match) => match.group(2) == null
          ? substitution[match.group(1)]!
          : nullableType(substitution[match.group(1)]!));
}

class InterfaceForwardingPlan {
  const InterfaceForwardingPlan(this.owner, this.method, this.ownerArguments,
      this.parameterTypes, this.returnType, this.typeParameters);
  final ClassDeclaration owner;
  final FunctionDeclaration method;
  final List<String> ownerArguments;
  final List<String> parameterTypes;
  final String returnType;
  final List<TypeParameter> typeParameters;
}

String providerInterfaceDefaultsName(
        ClassDeclaration owner, FunctionDeclaration method) =>
    providerMethodDefaultBridgeName(owner, method)
        .replaceFirst(r'$QudsMethodDefault', r'$QudsInterfaceDefaults');

String providerMethodDefaultBridgeName(
        ClassDeclaration owner, FunctionDeclaration function) =>
    r'$QudsMethodDefault' +
    sha256Hex(utf8.encode(jsonEncode([
      owner.name,
      for (final p in owner.typeParameters) [p.name, p.bound],
      providerDefaultBridgeName(function),
    ]))).substring(0, 20);

String providerGapBridgeName(FunctionDeclaration function) =>
    providerDefaultBridgeName(function)
        .replaceFirst(r'$QudsDefault', r'$QudsGap');

String providerPacketBridgeName(FunctionDeclaration function) =>
    providerDefaultBridgeName(function)
        .replaceFirst(r'$QudsDefault', r'$QudsPacket');

String providerMethodPacketBridgeName(
        ClassDeclaration owner, FunctionDeclaration function) =>
    providerMethodDefaultBridgeName(owner, function)
        .replaceFirst(r'$QudsMethodDefault', r'$QudsMethodPacket');

String providerMethodGapBridgeName(
        ClassDeclaration owner, FunctionDeclaration function) =>
    providerMethodDefaultBridgeName(owner, function)
        .replaceFirst(r'$QudsMethodDefault', r'$QudsMethodGap');

String providerConstructorBridgeName(
        ClassDeclaration type, ConstructorDeclaration constructor) =>
    r'$QudsCtor' +
    sha256Hex(utf8.encode(jsonEncode([
      type.name,
      constructor.name,
      for (final parameter in constructor.parameters)
        [
          parameter.name,
          parameter.type,
          parameter.defaultValue != null,
          parameter.kind.name
        ],
    ]))).substring(0, 20);

String providerConstructorSlotsName(
        ClassDeclaration type, ConstructorDeclaration constructor) =>
    providerConstructorBridgeName(type, constructor)
        .replaceFirst(r'$QudsCtor', r'$QudsCtorSlots');

String providerSynthesizedConstructorBridgeName(ClassDeclaration type) =>
    r'$QudsCtor' +
    sha256Hex(utf8.encode(jsonEncode([
      type.name,
      'synthesized',
      type.superclass,
      for (final field in type.fields)
        if (!field.isStatic && !field.isEvent) [field.name, field.type],
    ]))).substring(0, 20);

/// An earlier optional positional slot can be omitted while a later slot is
/// supplied. One Dart positional closure cannot represent that gap.
bool positionalGapPossible(List<Parameter> parameters) {
  for (var i = 0; i < parameters.length; i++) {
    if (parameters[i].kind != ParameterKind.optionalPositional) continue;
    if (parameters.skip(i + 1).any((parameter) => !parameter.variadic)) {
      return true;
    }
  }
  return false;
}

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
      this.nativeTop,
      this.nativeMember,
      this.nativeClass,
      this.nativeConstructor = false,
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
  final DartTop? nativeTop;
  final DartMember? nativeMember;
  final DartShape? nativeClass;
  final bool nativeConstructor;

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
  final typeBindings = <String, String>{};
  Map<String, String> get lexicalTypes => typeBindings.isEmpty
      ? parent?.lexicalTypes ?? const {}
      : {...?parent?.lexicalTypes, ...typeBindings};
  Symbol? lookup(String name) => symbols[name] ?? parent?.lookup(name);
}

class _LoopFrame {
  _LoopFrame(this.value);
  final bool value;
  String? breakType;
}

class ConversionPlan {
  const ConversionPlan(
      this.function, this.library, this.typeArguments, this.resultType);
  final FunctionDeclaration function;
  final String library;
  final List<String> typeArguments;
  final String resultType;
}

class SemanticModel {
  String library = '';
  String targetPlatform = 'vm';
  bool flutter = false;
  bool testing = false;
  final implicitConversions = <Expression, ConversionPlan>{};
  final explicitConversions = <ConversionExpression, ConversionPlan>{};
  final references = <Node, Symbol>{};
  final declarations = <Node, Symbol>{};
  final assignments = <Binding>{};
  final rebinding = <Pattern>{};
  final types = <Expression, String>{};

  /// Stable field views specialized in each declaring class’s formal parameters.
  final classFields = <ClassDeclaration, List<FieldDeclaration>>{};

  /// Parameter order expressed as indices into source-order arguments.
  final argumentOrder = <CallExpression, List<int>>{};
  final inferredTypeArguments = <CallExpression, List<String>>{};
  final instantiatedParameterTypes = <CallExpression, List<String>>{};
  final contextualFunctionArguments = <Expression, List<String>>{};
  final validatedQudsFunctionValues = <Expression>{};
  final instantiatedFunctionValues = <TypeApplication>{};
  final functionValueCalls = <CallExpression>{};
  final nativeArguments = <CallExpression, List<(String?, int)>>{};

  /// Closures that restore Quds defaults or hide intersection type parameters.
  final providerUnionFunctions = <FunctionDeclaration>{};
  final providerUnionImports = <ImportDeclaration, Set<FunctionDeclaration>>{};
  final reboxAs = <Expression, String>{};
  final providerDefaultImports =
      <ImportDeclaration, Set<FunctionDeclaration>>{};
  final interfaceForwardingPlans =
      <ClassDeclaration, List<InterfaceForwardingPlan>>{};
  final interfaceDefaultPrefixes = <String, String>{};
  final providerDefaultMethods = <FunctionDeclaration, ClassDeclaration>{};
  final providerDefaultFunctions = <FunctionDeclaration>{};

  /// SDK functions whose generated bridge must be imported by this library.
  final providerBridgeImports = <FunctionDeclaration>{};
  final qudsValueLowerings = <Expression, QudsValueLowering>{};

  /// Imported calls that omit an earlier optional positional slot.
  final providerGapCalls = <CallExpression>{};

  /// Stored Quds values whose closure was bound to a gap packet.
  final gapValues = <Symbol>{};
  final functionValueGapCalls = <CallExpression>{};

  /// Imported constructor calls whose omitted defaults stay in the provider.
  final constructorGapTargets = <CallExpression, ClassDeclaration>{};
  final constructorGapDeclarations = <CallExpression, ConstructorDeclaration>{};

  /// Class type arguments for a constructor call, used when a default
  /// expression mentions those parameters.
  final constructorSubstitutions = <CallExpression, Map<String, String>>{};

  /// Calls whose callee is a packet value rather than a Dart function.
  final packetValueCalls = <CallExpression>{};

  /// Index of the variadic slot in a function-value call, in signature order.
  final functionValueVariadicIndex = <CallExpression, int>{};

  /// Element type packed into the list argument of a variadic function value.
  final functionValueVariadicElements = <CallExpression, String>{};

  /// Declaring type used when an inherited static method is torn off.
  final staticValueOwners = <Expression, String>{};

  /// Return type whose readonly view must wrap a torn-off method.
  final qudsValueResultGuards = <Expression, String>{};

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
  final loopContextIndexes = <Node, Symbol>{};
  final loopContextBodyIndexes = <Node>{};
  final loopContextMembers = <MemberAccess, (Symbol, String)>{};

  /// `for a, b in` walks a pair instead of an index.
  final loopPairs = <Node>{};
  final extensions = <ExtensionDeclaration>[];
  final aliases = <String, String>{};

  /// Alias name to the `quds:` library that declared it.
  final sdkAliases = <String, String>{};
  final classes = <String, ClassDeclaration>{};

  /// `quds:` libraries whose classes, functions, or extensions are used.
  final usedSdk = <String>{};

  /// Names touched from each `quds:` import. A section import shows these.
  final usedSdkNames = <String, Set<String>>{};

  /// Public names of a `quds:` library that exist in its generated Dart.
  ///
  /// Aliases are erased, so they are absent. Names re-exported from `dart:`
  /// are included.
  final sdkDartNames = <String, Set<String>>{};

  String resolve(String type,
      {Set<String> boundNames = const {},
      Map<String, String> lexicalTypes = const {}}) {
    final protected = {
      for (var i = 0; i < boundNames.length; i++)
        boundNames.elementAt(i): '@#bound$i#'
    };
    var current = substituteBridgeType(type, protected);
    final bindings = {
      for (final entry in aliases.entries)
        if (!activeAliasShadows.contains(entry.key)) entry.key: entry.value,
      ...lexicalTypes
    };
    final seen = <String>{};
    while (seen.add(current)) {
      final next = substituteBridgeType(current, bindings);
      if (next == current) break;
      current = next;
    }
    for (final entry in protected.entries)
      current = current.replaceAll(entry.value, entry.key);
    return current;
  }

  /// Internal native identity keys are never part of user-facing type text.
  String displayType(String text) {
    var result = text;
    for (final entry in backendTypes.entries) {
      if (!entry.key.startsWith('@')) continue;
      final visible = aliases.entries
          .where(
              (alias) => !alias.key.startsWith('@') && alias.value == entry.key)
          .firstOrNull;
      final name = visible?.key ?? entry.value.split('.').last;
      result =
          result.replaceAll(RegExp('${RegExp.escape(entry.key)}\\b'), name);
    }
    return result;
  }

  final wrapAs = <Expression, String>{};

  /// Dart prefix, including the dot, for a binding whose union lives in an
  /// imported library. An empty string is an unprefixed import.
  final unionPrefixes = <Symbol, String>{};

  /// Same prefix for one expression that must be wrapped as that library's
  /// sealed union. Absent means the union class is emitted in this library.
  final unionWrapPrefixes = <Expression, String>{};

  /// Tear-off whose function type mentions a union owned by the import prefix.
  final unionExpressionPrefixes = <Expression, String>{};
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
  // Non-source-spellable nominal identities for types in imported signatures.
  final internalTypes = <String, Symbol>{};
  final activeAliasShadows = <String>{};
  final backendTypes = <String, String>{};
  final backendTypeImports = <String, String>{};

  /// Dart import URI for a `package:` or `generated:` library that was loaded.
  final resolvedImports = <ImportDeclaration, String>{};
  final resolvedParts = <PartDirective, String>{};

  /// Public names selected by a `::section` import, in source order.
  final sectionImports = <ImportDeclaration, List<String>>{};

  /// Library key whose touched names belong to [sectionImports].
  final importHomes = <ImportDeclaration, String>{};

  /// Emit `@protected` because this package depends on `package:meta`.
  var protectWithMeta = false;

  /// Resolved cleanup method (`dispose` or `close`) and whether to `await` it.
  final usingCleanup = <UsingStatement, ({String method, bool awaitCleanup})>{};
}

class _FilteredImport {
  const _FilteredImport(this.filter, this.empty);
  final ImportDeclaration? filter;

  /// True when the section selects no names, so nothing is bound.
  final bool empty;
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
      namespace[entry.key] = _dartMemberSymbol(entry.value, top.type,
          owner: shape, constructor: true);
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
      top.type,
      external: true,
      nativeTop: top,
      nativeClass: shape,
      nativeConstructor: true,
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
    nativeTop: top,
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

Symbol _dartMemberSymbol(DartMember member, String type,
    {DartShape? owner, bool constructor = false}) {
  return Symbol(
    member.name,
    member.name,
    member.getter ? member.type : type,
    external: true,
    callable: !member.getter,
    nativeMember: member,
    nativeClass: owner,
    nativeConstructor: constructor,
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
  'codeUnitAt',
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

bool isReadonlyMethod(FunctionDeclaration method) =>
    method.readonlyMethod ||
    method.name == 'toString' ||
    method.isOperator && method.name == '==';

ClassDeclaration? readonlyClassFor(SemanticModel model, String type) {
  type = stripReadonlyType(model.resolve(type));
  type = nonNullableType(type);
  final bracket = type.indexOf('<');
  final head = bracket < 0 ? type : type.substring(0, bracket);
  return model.classes[head] ??
      model.internalTypes[head]?.classDeclaration ??
      model.moduleSymbols[head]?.classDeclaration;
}

bool supportsReadonlyClass(SemanticModel model, ClassDeclaration node,
    [Set<ClassDeclaration> seen = const {}]) {
  if (seen.contains(node) ||
      node.kind == 'sealed' ||
      node.modifiers.contains('sealed')) return false;
  if (!const {
        'class',
        'value',
        'abstract',
        'base',
        'final',
        'sealed',
        'interface',
        'mixinClass'
      }.contains(node.kind) ||
      node.mixins.isNotEmpty) return false;
  if (node.superclass case final parentType?) {
    final parent = readonlyClassFor(model, parentType);
    if (parent == null ||
        (node.kind != 'interface' && parent.kind == 'interface')) return false;
    return supportsReadonlyClass(model, parent, {...seen, node});
  }
  return true;
}

class Analyzer {
  Analyzer(
      {this.library = '<input>',
      String? file,
      this.targetPlatform = 'vm',
      this.flutter = false,
      String? packageConfigFrom,
      this.testing = false})
      : _file = file ?? library,
        _packageConfigFrom = packageConfigFrom {
    model.targetPlatform = targetPlatform;
    model.flutter = flutter;
    model.testing = testing;
  }
  final String targetPlatform;
  final bool flutter;
  final bool testing;
  bool? compileTimeCondition(Expression node) => _constBool(node);
  final model = SemanticModel();
  final _conversionDefinitions = <FunctionDeclaration, String>{};

  /// Privacy scope. A part file uses its parent's path.
  final String library;

  /// Path of the source being checked. Imports and parts resolve from here.
  final String _file;

  /// Consumer file whose `.dart_tool/package_config.json` resolves external packages.
  final String? _packageConfigFrom;
  late final _namePrefix = library == _file
      ? '_q'
      : '_qp_${sha256Hex(utf8.encode(_file)).substring(0, 12)}_';
  Map<String, Program> _libraries = const {};
  final _sdkDefaultFiles = <String>{};

  /// Symbols of an imported library, including its private names and prefixes.
  ///
  /// A call re-checks a function that has defaults. That check used to run in
  /// the importer's scope, which cannot see `_names` or `use dart:math as math`.
  final _libraryScopes = <String, _Scope>{};
  final _libraryTypes = <String, Map<String, String>>{};
  final _blockedInternalNames = <String>{};
  final _blockedInternalByPrefix = <String, Set<String>>{};
  final _core = _Scope();
  late final _global = _Scope(_core);
  late _Scope _scope = _global;
  final _checked = <FunctionDeclaration>{};
  final _checking = <FunctionDeclaration>{};
  final _typedConstructorDefaults = <ConstructorDeclaration>{};
  final _typeNames = <String>{};
  final _pendingClasses = <String>{};
  final _typeBounds = <String, String>{};
  final _checkingBounds = <(String, String)>{};
  final _methodOwners = <FunctionDeclaration, ClassDeclaration>{};
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
  String _resolveType(String type) => model.resolve(type,
      boundNames: _typeNames, lexicalTypes: _scope.lexicalTypes);

  Never fail(String message, Node node) => throw CompilerException(
      registryCode(message), model.displayType(message), node.span);
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
              name == 'main' && function != null
                  ? 'main'
                  : '$_namePrefix${_nextName++}',
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
  String? _methodLibrary;
  final _promoted = <String, String>{};
  final _consumed = <Symbol, SourceSpan>{};
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
      throw CompilerException(code, model.displayType(message), node.span);
  void warn(String code, String message, Node node) {
    model.warnings.add(CompilerException(code, message, node.span));
  }

  Set<FunctionDeclaration> _exportedDefaultFunctions(
      Program program, String home, Set<Program> seen,
      {bool unions = false}) {
    if (seen.contains(program) || _sdkDefaultFiles.contains(program.span.file))
      return {};
    final next = {...seen, program};
    final result = program.statements
        .whereType<FunctionDeclaration>()
        .where(unions ? supportsUnionBoundary : supportsProviderDefaults)
        .toSet();
    for (final node in program.statements) {
      if (node is ImportDeclaration && node.export) {
        if (node.uri.startsWith('dart:')) continue;
        final path = _resolveLibrary(home, node.uri);
        final target = _libraries[path];
        if (target == null) continue;
        result.addAll(
            _exportedDefaultFunctions(target, path, next, unions: unions).where(
                (fn) =>
                    (node.show.isEmpty || node.show.contains(fn.name)) &&
                    !node.hide.contains(fn.name)));
      } else if (node is PartDirective && !node.of) {
        final path = _resolveLibrary(home, node.uri);
        final target = _libraries[path];
        if (target != null)
          result.addAll(
              _exportedDefaultFunctions(target, path, next, unions: unions));
      }
    }
    return result;
  }

  SemanticModel analyze(Program program,
      {Map<String, Program> libraries = const {}}) {
    model.library = library;
    _libraries = libraries;
    _sdkDefaultFiles.addAll(libraries.entries
        .where((entry) => entry.key.startsWith('quds:'))
        .map((entry) => entry.value.span.file));
    for (final source in [program, ...libraries.values]) {
      final sdk = _sdkDefaultFiles.contains(source.span.file);
      if (!sdk) {
        model.providerUnionFunctions.addAll(source.statements
            .whereType<FunctionDeclaration>()
            .where(supportsUnionBoundary));
      }
      model.providerDefaultFunctions.addAll(source.statements
          .whereType<FunctionDeclaration>()
          .where(supportsProviderDefaults));
      if (sdk) continue;
      for (final owner in source.statements.whereType<ClassDeclaration>()) {
        const bridgeOwners = {
          'class',
          'interface',
          'value',
          'mixin',
          'mixinClass',
        };
        if (!bridgeOwners.contains(owner.kind) || owner.name.startsWith('_'))
          continue;
        for (final method in owner.methods) {
          if (method.visibility == 'private' ||
              method.name.startsWith('_') ||
              !supportsProviderDefaults(method)) continue;
          if (owner.kind == 'interface' &&
              !supportsInterfaceDefaults(owner, method)) continue;
          if (owner.methods
                  .where((other) => other.name == method.name)
                  .length !=
              1) continue;
          model.providerDefaultMethods[method] = owner;
        }
      }
    }
    for (final source in [program, ...libraries.values]) {
      for (final directive
          in source.statements.whereType<ImportDeclaration>()) {
        if (directive.show.isEmpty && directive.hide.isEmpty) continue;
        if (directive.uri.startsWith('dart:')) continue;
        final path = _resolveLibrary(
            identical(source, program) ? _file : source.span.file,
            directive.uri);
        final target = libraries[path];
        if (target != null) {
          model.providerDefaultImports[directive] =
              _exportedDefaultFunctions(target, path, {});
          model.providerUnionImports[directive] =
              _exportedDefaultFunctions(target, path, {}, unions: true);
        }
      }
    }
    _installDartCore();
    _global.symbols['print'] = Symbol('print', 'print', 'void');
    _installChecks();
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
    _global.symbols['ConversionError'] = Symbol(
        'ConversionError', 'ConversionError', 'ConversionError',
        parameterTypes: const ['String']);
    _installLog();
    final topLevel = _flattenTopLevel(program.statements);
    for (final f in topLevel.whereType<FunctionDeclaration>()) {
      if (f.conversionKind.isNotEmpty) _conversionDefinitions[f] = library;
    }
    for (final statement in topLevel) {
      if (statement is AliasDeclaration) {
        model.aliases[statement.name] = statement.target;
      }
      if (statement is ClassDeclaration) _pendingClasses.add(statement.name);
    }
    _bindParts(program);
    final functions = <FunctionDeclaration>[];
    final tests = <TestDeclaration>[];
    for (final statement in topLevel) {
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
        case SectionDeclaration():
          break;
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
    for (final statement in topLevel) {
      if (statement is Binding && statement.mode == BindingMode.constant) {
        check(statement);
      }
    }
    for (final statement in topLevel) {
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
            _rejectConstantConversion(value);
            _constants.ensureConstant(value);
          }
        default:
          break;
      }
    }
    _validateConversionDefinitions();
    _assignAllMethodOverloadNames();
    for (final statement in functions) {
      analyzeFunction(statement);
    }
    for (final statement in tests) {
      check(statement);
    }
    for (final statement in topLevel) {
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
          if (!field.isStatic && field.initializer != null) {
            analyzeInstanceField(statement, field);
          }
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
    if (model.providerDefaultMethods.values
        .any((owner) => owner.kind == 'interface')) {
      for (final implementation in model.classes.values.toSet()) {
        if (_sdkDefaultFiles.contains(implementation.span.file) ||
            implementation.kind == 'interface') continue;
        final saved = _scope;
        final home = model.libraryOf[implementation] ?? '';
        try {
          _scope =
              home.isEmpty || home == library ? _global : _libraryScope(home);
          final plans = <FunctionDeclaration, InterfaceForwardingPlan>{};
          final seen = <ClassDeclaration, String>{};
          void collect(String type, Set<ClassDeclaration> path) {
            final owner = _typeSymbol(_genericHead(type))?.classDeclaration;
            if (owner == null || path.contains(owner)) return;
            final previous = seen[owner];
            if (previous != null) {
              if (previous != type)
                error(
                    'E300',
                    'Conflicting interface instantiations: $previous and $type',
                    implementation);
              return;
            }
            seen[owner] = type;
            final substitution = _genericSubstitution(type, owner);
            for (final method in owner.methods) {
              if (model.providerDefaultMethods[method] != owner ||
                  owner.kind != 'interface') continue;
              final methodSub = {...substitution};
              for (var i = 0; i < method.typeParameters.length; i++) {
                methodSub[method.typeParameters[i].name] =
                    r'$qInterfaceMethod' + '$i';
              }
              String specialize(String value) => _substitute(
                  _qualifiedMethodType(value, owner, method), methodSub);
              plans[method] = InterfaceForwardingPlan(
                  owner,
                  method,
                  [
                    for (final p in owner.typeParameters)
                      substitution[p.name] ?? p.name
                  ],
                  [for (final p in method.parameters) specialize(p.type)],
                  specialize(model.declarations[method]!.type),
                  [
                    for (final p in method.typeParameters)
                      TypeParameter(methodSub[p.name]!, p.span,
                          bound: p.bound == null ? null : specialize(p.bound!),
                          variance: p.variance)
                  ]);
            }
            for (final edge in [
              ...owner.interfaces,
              if (owner.kind == 'interface' && owner.superclass != null)
                owner.superclass!
            ]) {
              collect(_substitute(_classMemberType(edge, owner), substitution),
                  {...path, owner});
            }
          }

          for (final edge in implementation.interfaces)
            collect(_classMemberType(edge, implementation), {});
          model.interfaceForwardingPlans[implementation] =
              plans.values.toList();
        } finally {
          _scope = saved;
        }
      }
    }
    model.moduleSymbols
      ..addAll(_core.symbols)
      ..addAll(_global.symbols);
    _checkEntryPoint();
    return model;
  }

  void _installDartCore() {
    DartSurface? surface;
    try {
      surface = readDartLibrary('dart:core');
    } catch (_) {
      surface = null;
    }
    if (surface == null) return;
    model.dartShapes.addAll(surface.types);
    for (final entry in surface.names.entries) {
      _core.symbols[entry.key] =
          symbolForDart(entry.value, surface.types[entry.key]);
    }
  }

  Symbol? _lookupNonCore(String name) {
    final found = _scope.lookup(name);
    if (found != null && identical(found, _core.symbols[name])) return null;
    return found;
  }

  /// Dart launches `main()` or `main(List<String> args)`.
  void _checkEntryPoint() {
    final entry = _global.symbols['main'];
    final functions = entry?.overloads ?? const <FunctionDeclaration>[];
    if (functions.isEmpty) return;
    final main = functions.length == 1 ? functions.single : null;
    final returned = main == null ? '' : model.declarations[main]!.type;
    final parameter = main != null && main.parameters.length == 1
        ? main.parameters.single
        : null;
    final parameterType = parameter == null
        ? ''
        : _resolveType(model.declarations[parameter]?.type ??
            (parameter.variadic ? 'List<${parameter.type}>' : parameter.type));
    final arguments = main != null &&
        main.typeParameters.isEmpty &&
        (main.parameters.isEmpty || parameterType == 'List<String>');
    if (main == null ||
        !arguments ||
        !{'void', 'Future<void>'}.contains(returned)) {
      fail(
          'main returns void or Future<void> and takes no arguments or one List<String> argument',
          main ?? functions.first);
    }
  }

  bool sameSignature(FunctionDeclaration a, FunctionDeclaration b) {
    if (a.parameters.length != b.parameters.length) return false;
    for (var i = 0; i < a.parameters.length; i++) {
      if (a.parameters[i].kind != b.parameters[i].kind ||
          a.parameters[i].isNamed &&
              a.parameters[i].name != b.parameters[i].name ||
          a.parameters[i].variadic != b.parameters[i].variadic) return false;
      if (a.parameters[i].type != b.parameters[i].type) return false;
    }
    return true;
  }

  void _checkBoundCycles(List<TypeParameter> parameters, Node node) {
    final names = parameters.map((p) => p.name).toSet();
    final edges = {
      for (final p in parameters)
        if (p.bound != null && names.contains(unwrap(p.bound!)))
          p.name: unwrap(p.bound!)
    };
    for (final name in names) {
      final visited = <String>{};
      String? current = name;
      while (current != null) {
        if (!visited.add(current))
          error('E300', 'Cyclic type parameter bounds', node);
        current = edges[current];
      }
    }
  }

  void registerFunction(FunctionDeclaration statement, _Scope scope,
      [List<FunctionDeclaration>? functions]) {
    _checkBoundCycles(statement.typeParameters, statement);
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
                    !stripReadonlyType(statement.returnType!)
                        .startsWith('Future<')
                ? 'Future<${statement.returnType}>'
                : type;
    final savedTypes = {..._typeNames};
    final savedBounds = {..._typeBounds};
    for (final parameter in statement.typeParameters) {
      _typeBounds.remove(parameter.name);
      if (parameter.bound != null)
        _typeBounds[parameter.name] = parameter.bound!;
    }
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
    _typeBounds
      ..clear()
      ..addAll(savedBounds);
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
    _checkBoundCycles(statement.typeParameters, statement);
    final key = scopeName ?? statement.name;
    final owner = library ?? this.library;
    final existing = _global.symbols[key];
    if (existing?.classDeclaration == statement) {
      model.libraryOf[statement] = owner;
      return;
    }
    if (_global.symbols.containsKey(key)) {
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
      final dartName =
          statement.kind == 'enum' ? '$key.${item.name}' : item.name;
      final caseSymbol = Symbol(item.name, dartName, key,
          classDeclaration: statement, classCase: item);
      if (statement.kind != 'enum') {
        if (_global.symbols.containsKey(item.name)) {
          fail('Duplicate case: ${item.name}', item);
        }
        _global.symbols[item.name] = caseSymbol;
      }
      model.declarations[item] = caseSymbol;
    }
    final savedTypes = {..._typeNames};
    final savedBounds = {..._typeBounds};
    for (final parameter in statement.typeParameters) {
      _typeBounds.remove(parameter.name);
      if (parameter.bound != null)
        _typeBounds[parameter.name] = parameter.bound!;
    }
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
      _methodOwners[method] = statement;
      _checkBoundCycles(method.typeParameters, method);
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
      final effective = method.generator == 'sync'
          ? (method.returnType == null
              ? '<infer>'
              : 'Iterable<${method.returnType}>')
          : method.generator == 'async'
              ? (method.returnType == null
                  ? '<infer>'
                  : 'Stream<${method.returnType}>')
              : method.isAsync &&
                      method.returnType != null &&
                      !stripReadonlyType(method.returnType!)
                          .startsWith('Future<')
                  ? 'Future<${method.returnType}>'
                  : type;
      final added = method.typeParameters
          .map((item) => item.name)
          .where((name) => !_typeNames.contains(name))
          .toList();
      _typeNames.addAll(added);
      final savedMethodBounds = {..._typeBounds};
      for (final parameter in method.typeParameters) {
        _typeBounds.remove(parameter.name);
        if (parameter.bound != null)
          _typeBounds[parameter.name] = parameter.bound!;
      }
      if (effective != '<infer>') validateType(effective, method);
      _typeBounds
        ..clear()
        ..addAll(savedMethodBounds);
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
    _typeBounds
      ..clear()
      ..addAll(savedBounds);
  }

  void registerExtension(ExtensionDeclaration statement,
      {String library = ''}) {
    model.extensions.add(statement);
    final savedTypes = {..._typeNames};
    _typeNames.addAll(statement.typeParameters.map((item) => item.name));
    for (final method in statement.methods) {
      final added = method.typeParameters.map((item) => item.name).toList();
      _typeNames.addAll(added);
      final type = method.returnType ??
          (method.expressionBody == null ? 'void' : '<infer>');
      if (type != '<infer>') validateType(type, method);
      for (final parameter in method.parameters) {
        validateType(
            parameter.variadic ? 'List<${parameter.type}>' : parameter.type,
            parameter,
            allowVoid: false);
      }
      _typeNames.removeAll(added);
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
    final names = {..._typeNames};
    final bounds = {..._typeBounds};
    _typeNames.addAll(type.typeParameters.map((p) => p.name));
    for (final p in type.typeParameters) {
      _typeBounds.remove(p.name);
      if (p.bound != null) _typeBounds[p.name] = p.bound!;
    }
    try {
      _checkShape(type);
    } finally {
      _typeNames
        ..clear()
        ..addAll(names);
      _typeBounds
        ..clear()
        ..addAll(bounds);
    }
  }

  void _checkShape(ClassDeclaration type) {
    _fieldsOf(type);
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
        : _typeSymbol(_genericHead(parentName))?.classDeclaration;
    if (parentName != null) validateType(parentName, type, allowVoid: false);
    if (parent != null &&
        parent.typeParameters.isNotEmpty &&
        _genericHead(parentName!) == parentName) {
      error(
          'E910',
          'A generic superclass needs explicit type arguments in this subset',
          type);
    }
    if (parent != null && parent.kind != 'interface') {
      if (type.constructors.isEmpty &&
          parent.constructors.isNotEmpty &&
          _synthesizedParentConstructor(type) == null) {
        error(
            'E910',
            'Synthesizing a constructor over explicit parent constructors needs further conformance',
            type);
      }
      for (final constructor in type.constructors.where((c) => !c.factory)) {
        final unnamed =
            parent.constructors.where((c) => c.name == null && !c.factory);
        if (parent.constructors.isNotEmpty && unnamed.isEmpty) {
          error('E700', 'A superclass needs an unnamed generative constructor',
              constructor);
        }
        final required = parent.constructors.isEmpty
            ? _fieldsOf(parent)
                .where((f) =>
                    f.requiredField &&
                    f.initializer == null &&
                    !f.isStatic &&
                    f.lazyBody == null)
                .map((f) => f.name)
            : unnamed.first.parameters
                .where((p) => p.defaultValue == null)
                .map((p) => p.name);
        for (final name in required) {
          if (!constructor.parameters
              .any((p) => p.initializing == 'super' && p.name == name)) {
            error('E704', 'Superclass parameter $name is not initialized',
                constructor);
          }
        }
      }
    }
    if (parent != null &&
        (parent.modifiers.contains('final') || parent.kind == 'final')) {
      error('E720', 'A final class cannot be extended', type);
    }
    if (parent != null) _rejectSealedOutside(type, parent);
    for (final name in type.interfaces) {
      final face = _typeSymbol(_genericHead(name))?.classDeclaration;
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
      _checkInterface(type, name, {});
    }
    if (type.kind == 'interface') {
      final seen = <ClassDeclaration>{};
      ClassDeclaration? current = type;
      while (current != null) {
        if (!seen.add(current))
          error('E700', 'Cyclic interface inheritance', type);
        final edge = current.superclass;
        if (edge == null) break;
        final next = _typeSymbol(_genericHead(edge))?.classDeclaration;
        if (next?.kind != 'interface')
          error('E700', 'An interface extends an interface', type);
        current = next;
      }
      if (type.superclass != null)
        validateType(type.superclass!, type, allowVoid: false);
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
    final savedReadonly = _readonlyMethod;
    final home = model.libraryOf[type] ?? '';
    _readonlyMethod = isReadonlyMethod(method);
    _scope = _Scope(
        home.isNotEmpty && home != library ? _libraryScope(home) : _global);
    _thisType = type.target;
    final savedTypes = {..._typeNames};
    _typeNames.addAll(type.typeParameters.map((item) => item.name));
    analyzeFunction(method);
    _typeNames
      ..clear()
      ..addAll(savedTypes);
    _readonlyMethod = savedReadonly;
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
      final savedExpected = _expected;
      _expected = property.type;
      final String returned;
      try {
        returned = expression(getter);
      } finally {
        _expected = savedExpected;
      }
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
          Symbol(field.name, field.name, _resolveType(field.type));
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
    final home = model.libraryOf[type] ?? '';
    final savedMethodLibrary = _methodLibrary;
    _methodLibrary = home.isEmpty ? library : home;
    _scope = _Scope(
        home.isNotEmpty && home != library ? _libraryScope(home) : _global);
    _thisType = method.isStatic ? null : (type.onType ?? type.name);
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
    try {
      _readonlyMethod = isReadonlyMethod(method);
      if (!method.isStatic) _installFields(type);
      analyzeFunction(method);
      _checkOverride(type, method);
    } finally {
      _typeNames
        ..clear()
        ..addAll(savedTypes);
      _typeBounds
        ..clear()
        ..addAll(savedBounds);
      _readonlyMethod = savedReadonly;
      _thisType = savedThis;
      _scope = saved;
      _methodLibrary = savedMethodLibrary;
    }
  }

  /// Default expressions are checked in the class scope, including `T` in
  /// `Box<T>`. A later call substitutes the constructed type arguments.
  void _typeConstructorDefaults(
      ClassDeclaration type, ConstructorDeclaration constructor) {
    if (!_typedConstructorDefaults.add(constructor)) return;
    final savedTypes = {..._typeNames};
    final savedBounds = {..._typeBounds};
    final savedExpected = _expected;
    final savedScope = _scope;
    final home = model.libraryOf[type] ?? library;
    _typeNames.addAll(type.typeParameters.map((parameter) => parameter.name));
    for (final parameter in type.typeParameters) {
      _typeBounds.remove(parameter.name);
      if (parameter.bound != null)
        _typeBounds[parameter.name] = parameter.bound!;
    }
    _scope = _Scope(home.isEmpty ? _global : _libraryScope(home));
    try {
      for (final parameter in constructor.parameters) {
        final declared = model.declarations[parameter]?.type ?? parameter.type;
        final symbol = Symbol(parameter.name, parameter.name, declared);
        _scope.symbols[parameter.name] = symbol;
        final value = parameter.defaultValue;
        if (value == null || model.types.containsKey(value)) continue;
        _expected = declared;
        expression(value);
      }
    } finally {
      _expected = savedExpected;
      _scope = savedScope;
      _typeNames
        ..clear()
        ..addAll(savedTypes);
      _typeBounds
        ..clear()
        ..addAll(savedBounds);
    }
  }

  void analyzeConstructor(
      ClassDeclaration type, ConstructorDeclaration constructor) {
    if (constructor.constant && constructor.body != null) {
      error('E401', 'A const constructor cannot have a body', constructor);
    }
    final savedTypes = {..._typeNames};
    final savedBounds = {..._typeBounds};
    _typeNames.addAll(type.typeParameters.map((p) => p.name));
    for (final p in type.typeParameters) {
      _typeBounds.remove(p.name);
      if (p.bound != null) _typeBounds[p.name] = p.bound!;
    }
    final saved = _scope;
    final savedThis = _thisType;
    _scope = _Scope(_global);
    _thisType = type.name;
    _installFields(type, assignable: true);
    for (final parameter in _ctorParameters(type, constructor)) {
      final symbol =
          Symbol(parameter.name, parameter.name, _resolveType(parameter.type));
      _scope.symbols[parameter.name] = symbol;
      model.declarations[parameter] = symbol;
      final original = constructor.parameters
          .where((item) => item.name == parameter.name)
          .firstOrNull;
      if (original != null) model.declarations[original] = symbol;
    }
    final parameterNames = <String>[];
    for (final parameter in constructor.parameters) {
      if (parameter.defaultValue case final value?) {
        restrictDefault(value, parameterNames.toSet(),
            constructor.parameters.map((item) => item.name).toSet());
        final savedExpected = _expected;
        final expectedType =
            model.declarations[parameter]?.type ?? parameter.type;
        _expected = expectedType;
        final String actual;
        try {
          actual = expression(value);
        } finally {
          _expected = savedExpected;
        }
        if (!_acceptExpected(value, actual, expectedType)) {
          error('E200',
              'Default type $actual is incompatible with $expectedType', value);
        }
      }
      parameterNames.add(parameter.name);
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
    _typeNames
      ..clear()
      ..addAll(savedTypes);
    _typeBounds
      ..clear()
      ..addAll(savedBounds);
  }

  void analyzeProperty(ClassDeclaration type, PropertyDeclaration property) {
    final savedTypes = {..._typeNames};
    final savedBounds = {..._typeBounds};
    _typeNames.addAll(type.typeParameters.map((p) => p.name));
    for (final p in type.typeParameters) {
      _typeBounds.remove(p.name);
      if (p.bound != null) _typeBounds[p.name] = p.bound!;
    }
    final saved = _scope;
    final savedThis = _thisType;
    final savedFunction = _function;
    final savedReturn = _returnType;
    _function = FunctionDeclaration(property.name, const [], property.type,
        property.getterBody, property.getter, property.span);
    _returnType = property.type;
    _scope = _Scope(_global);
    _thisType = type.name;
    _installFields(type);
    if (property.getter case final getter?) {
      final savedExpected = _expected;
      _expected = property.type;
      final String returned;
      try {
        returned = expression(getter);
      } finally {
        _expected = savedExpected;
      }
      if (!compatible(returned, property.type)) {
        fail('Getter type $returned is incompatible with ${property.type}',
            getter);
      }
    } else if (property.getterBody case final body?) {
      statements(body);
      if (!returns(body))
        fail('A getter must explicitly return on every path', property);
    }
    if (property.setterBody case final body?) {
      _returnType = 'void';
      final nested = _scope;
      _scope = _Scope(nested);
      final param = property.setter ?? 'value';
      _scope.symbols[param] = Symbol(param, param, property.type);
      statements(body);
      _scope = nested;
    }
    _thisType = savedThis;
    _scope = saved;
    _function = savedFunction;
    _returnType = savedReturn;
    _typeNames
      ..clear()
      ..addAll(savedTypes);
    _typeBounds
      ..clear()
      ..addAll(savedBounds);
  }

  void analyzeStaticField(FieldDeclaration field) {
    final value = field.initializer;
    if (value == null) fail('A static field needs an initializer', field);
    final String type;
    if (field.isConst) {
      _rejectConstantConversion(value);
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

  void analyzeInstanceField(ClassDeclaration owner, FieldDeclaration field) {
    final value = field.initializer;
    if (value == null || model.types.containsKey(value)) return;
    final savedTypes = {..._typeNames};
    final savedBounds = {..._typeBounds};
    final savedExpected = _expected;
    final savedScope = _scope;
    final home = model.libraryOf[owner] ?? library;
    for (final parameter in owner.typeParameters) {
      _typeBounds.remove(parameter.name);
      if (parameter.bound != null)
        _typeBounds[parameter.name] = parameter.bound!;
    }
    _typeNames.addAll(owner.typeParameters.map((item) => item.name));
    _scope = _Scope(
        home.isEmpty || home == _activeLibrary ? _global : _libraryScope(home));
    try {
      final declared =
          field.type == '<infer>' ? null : _resolveType(field.type);
      _expected = declared;
      final actual = expression(value);
      if (declared != null && !compatible(actual, declared)) {
        fail('Cannot initialize $declared with $actual', value);
      }
    } finally {
      _expected = savedExpected;
      _scope = savedScope;
      _typeNames
        ..clear()
        ..addAll(savedTypes);
      _typeBounds
        ..clear()
        ..addAll(savedBounds);
    }
  }

  void _installFields(ClassDeclaration type, {bool assignable = false}) {
    for (final field in _fieldsOf(type)) {
      if (field.isStatic) continue;
      final dart = field.visibility == 'private' && !field.name.startsWith('_')
          ? '_${field.name}'
          : field.name;
      final symbol = Symbol(field.name, dart, _resolveType(field.type),
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
    final result = <Parameter>[];
    for (final parameter in constructor.parameters) {
      if (parameter.initializing.isEmpty) {
        result.add(parameter);
        continue;
      }
      if (parameter.initializing == 'this' &&
          !type.fields.any((f) => f.name == parameter.name)) {
        error(
            'E704',
            'this.${parameter.name} must initialize a field declared by ${type.name}',
            parameter);
      }
      if (parameter.initializing == 'super' &&
          (type.superclass == null ||
              type.fields.any((f) => f.name == parameter.name))) {
        error(
            'E200',
            'super.${parameter.name} must refer to a superclass field',
            parameter);
      }
      result.add(Parameter(
          parameter.name,
          _fieldType(type, parameter.name, parameter.span),
          parameter.mutable,
          parameter.span,
          initializing: parameter.initializing,
          kind: parameter.kind,
          defaultValue: parameter.defaultValue,
          variadic: parameter.variadic));
    }
    return result;
  }

  String _fieldType(ClassDeclaration type, String name, SourceSpan span) {
    final found = _fieldsOf(type).where((field) => field.name == name);
    if (found.isEmpty) {
      throw CompilerException(
          'E200', 'No field $name for an initializing formal', span);
    }
    return _resolveType(found.first.type);
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

  List<Statement> _flattenTopLevel(List<Statement> statements) {
    final result = <Statement>[];
    for (final statement in statements) {
      if (statement is WhenStatement) {
        final selected = _constBool(statement.condition);
        if (selected == null) {
          error('E902', 'A when condition is not a constant boolean',
              statement.condition);
        }
        if (!selected) {
          model.skipped.add(statement);
          continue;
        }
        result.addAll(_flattenTopLevel(statement.body));
      } else {
        result.add(statement);
      }
    }
    return result;
  }

  bool? _constBool(Expression node) {
    if (node is Literal && node.value is bool) return node.value as bool;
    if (node is Identifier && node.name == 'test') return testing;
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
    if (node is Identifier && node.name == 'platform') return targetPlatform;
    return null;
  }

  bool? _libraryFlag(Expression node) {
    final path = _memberPath(node);
    if (path == null || !path.startsWith('dart.library.')) return null;
    const enabled = {
      'dart.library.core',
      'dart.library.async',
      'dart.library.collection',
      'dart.library.convert',
      'dart.library.typed_data',
    };
    if (path == 'dart.library.io') return targetPlatform != 'web';
    if (path == 'dart.library.html' || path == 'dart.library.js_interop')
      return targetPlatform == 'web';
    if (path == 'dart.library.ui')
      return flutter || targetPlatform == 'flutter';
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
    if (_isLocalDart(node)) {
      final surface = _localDartSurface(node);
      if (surface == null) fail('Unknown import: ${node.uri}', node);
      _bindSurface(node, surface);
      return;
    }
    if (node.uri == 'dart:ffi') _ffi = true;
    if (node.uri.startsWith('dart:')) {
      _bindDart(node);
      return;
    }
    if (node.uri.startsWith('package:') && node.uri.endsWith('.dart')) {
      final quds = resolveLibraryPath(_file, node.uri,
          packageConfigFrom: _packageConfigFrom);
      if (quds != null && File(quds).existsSync()) {
        _bindPackage(node);
        return;
      }
      _bindExternalDartPackage(node, node.uri);
      return;
    }
    if (node.uri.startsWith('package:') || node.uri.startsWith('generated:')) {
      _bindPackage(node);
      return;
    }
    if (!libraryTarget(node.uri).endsWith('.quds')) {
      fail('Unknown import: ${node.uri}', node);
    }
    if (_file == '<input>') return;
    final path = _resolveLibrary(_file, node.uri);
    if (path == _file) return;
    final imported = _libraries[path];
    if (imported == null) fail('Unknown import: ${node.uri}', node);
    _checkInternalLibraryAccess(_file, path, node);
    final filtered = _filteredImport(node, imported, path);
    if (filtered.empty) return;
    if (node.export) {
      _importLibrary(imported, path,
          filter: filtered.filter ?? node, bind: false);
      return;
    }
    _importLibrary(imported, path,
        filter: filtered.filter, qualify: node.prefix);
  }

  void _bindExternalDartPackage(ImportDeclaration node, String dartUri) {
    _externalDart = true;
    final library =
        packageDartFile(_file, dartUri, packageConfigFrom: _packageConfigFrom);
    if (library != null) {
      try {
        final surface = readDartFile(library, from: _file);
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
  }

  static const _preludeNames = [
    'Optional',
    'missing',
    'present',
    'Result',
    'Ok',
    'Error',
    'ConversionError'
  ];

  void _bindQuds(ImportDeclaration node) {
    final libraryName = sdkLibraryName(node.uri);
    final prelude = node.uri == 'quds:core';
    final imported = libraryName == null ? null : _libraries[node.uri];
    if (libraryName == null || (imported == null && !prelude)) {
      fail('Unknown import: ${node.uri}', node);
    }
    var dartNames = imported == null ? <String>{} : _sdkDartNames(imported);
    var aliasNames = imported == null ? <String>{} : _sdkAliasNames(imported);
    final section = sdkImport(node.uri)?.section;
    if (section != null) {
      if (imported == null) fail('Unknown import: ${node.uri}', node);
      final selected = _namesInSection(imported, section);
      if (selected == null) fail('Unknown import: ${node.uri}', node);
      dartNames = selected.$1;
      aliasNames = selected.$2;
    }
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
    model.resolvedImports[node] = sdkDartFileName(libraryName);
    var filter = _sdkFilter(node, {...dartNames, ...aliasNames});
    if (section != null) {
      final visible = <String>[
        ...dartNames,
        for (final name in aliasNames)
          if (!dartNames.contains(name)) name,
      ];
      final shown = node.show.isNotEmpty
          ? [
              for (final name in node.show)
                if (visible.contains(name)) name,
            ]
          : [
              for (final name in visible)
                if (!node.hide.contains(name)) name,
            ];
      model.sdkDartNames[node.uri] = shown.toSet();
      if (shown.isEmpty) return;
      filter = ImportDeclaration(node.uri, node.prefix, node.span,
          export: node.export, show: shown);
    } else {
      model.sdkDartNames[node.uri] = dartNames;
    }
    if (node.show.isNotEmpty &&
        !node.show.any(
            (name) => dartNames.contains(name) || aliasNames.contains(name))) {
      return;
    }
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

  /// Public names whose section is [section] or a section under it.
  ///
  /// Null when the library has no such header. A parent section includes
  /// `section::child` because that child is part of the parent.
  (Set<String>, Set<String>)? _namesInSection(Program program, String section) {
    var current = '';
    var exists = false;
    final dartNames = <String>{};
    final aliases = <String>{};
    for (final statement in program.statements) {
      if (statement is SectionDeclaration) {
        current = statement.path;
        if (current == section || current.startsWith('$section::')) {
          exists = true;
        }
        continue;
      }
      if (current != section && !current.startsWith('$section::')) continue;
      switch (statement) {
        case ClassDeclaration() when !statement.name.startsWith('_'):
          dartNames.add(statement.name);
        case FunctionDeclaration()
            when statement.name != 'main' && !statement.name.startsWith('_'):
          dartNames.add(statement.name);
        case ExtensionDeclaration()
            when statement.name != null && !statement.name!.startsWith('_'):
          dartNames.add(statement.name!);
        case AliasDeclaration() when !statement.name.startsWith('_'):
          aliases.add(statement.name);
        case ImportDeclaration() when statement.export:
          dartNames.addAll(_exportedDartNames(statement));
        default:
          break;
      }
    }
    if (!exists) return null;
    return (dartNames, aliases);
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
    final rawSurface = readDartLibrary(statement.uri);
    if (rawSurface == null) fail('Unknown import: ${statement.uri}', statement);
    final surface = _nativeSurface(statement.uri, rawSurface);
    model.dartShapes.addAll(surface.types);
    final target =
        qualify == null ? _global.symbols : _space(qualify, statement);
    for (final entry in surface.names.entries) {
      if (!_keeps(entry.key, statement) || !_keeps(entry.key, filter)) continue;
      if (target.containsKey(entry.key)) {
        if (qualify != null) {
          error('E204', 'Two imports define ${entry.key}', statement);
        }
        continue;
      }
      final shape = surface.types[entry.key];
      if (shape != null) model.dartShapes[entry.key] = shape;
      _bindNativeAlias(entry.key, entry.value, qualify);
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

  bool _isLocalDart(ImportDeclaration node) =>
      node.uri.endsWith('.dart') && !Uri.parse(node.uri).hasScheme;

  DartSurface? _localDartSurface(ImportDeclaration node) {
    final source = node.span.file == '<input>' ? _file : node.span.file;
    if (source == '<input>') return null;
    return readDartFile(
        File(File(source).absolute.uri.resolve(node.uri).toFilePath()));
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

  DartSurface? _typedSurface;
  final _typedTypeNames = <String, String>{};

  DartSurface _nativeSurface(String uri, DartSurface surface) {
    if (!uri.startsWith('dart:')) {
      if (_typedSurface == null) {
        final typed = readDartLibrary('dart:typed_data');
        if (typed != null) _nativeSurface('dart:typed_data', typed);
      }
      final names = <String, String>{};
      for (final name in surface.types.keys) {
        final top = surface.names[name];
        if (top == null || top.file.isEmpty) continue;
        final origin = File(top.file).absolute.uri.normalizePath();
        if (_typedTypeNames.containsKey(name) &&
            origin.path.contains('/typed_data/')) {
          names[name] = _typedTypeNames[name]!;
          continue;
        }
        final package = packageRoot(top.file);
        final packageUri =
            package == null ? null : Directory(package.directory).absolute.uri;
        final identity = packageUri != null &&
                origin.toString().startsWith(packageUri.toString())
            ? '${package!.name}:${origin.toString().substring(packageUri.toString().length)}'
            : origin.toString();
        final digest = sha256Hex(utf8.encode(identity)).substring(0, 12);
        final prefix = '_qNative$digest';
        final key = '@dart.native.$digest.$name';
        names[name] = key;
        model.backendTypes[key] = '$prefix.$name';
        final declaredLibrary =
            surface.declarationLibraries[origin.toFilePath()] ?? top.file;
        final importFile = File(declaredLibrary).absolute.uri.normalizePath();
        var importUri = surface.libraryUris[importFile.toFilePath()] ??
            importFile.toString();
        for (final library in packageLibraries(_file)) {
          final directory = Directory(library.libDirectory).absolute.uri;
          if (!importUri.startsWith('dart:') &&
              importFile.toString().startsWith(directory.toString())) {
            importUri =
                'package:${library.name}/${importFile.toString().substring(directory.toString().length)}';
            break;
          }
        }
        model.backendTypeImports[prefix] = importUri;
        model.internalTypes[key] =
            Symbol(key, '$prefix.$name', key, external: true);
      }
      String canonical(String source) => source.replaceAllMapped(
          RegExp(r'[A-Za-z_][A-Za-z0-9_]*'),
          (m) => names[m[0]] ?? _typedTypeNames[m[0]] ?? m[0]!);
      final mapped = mapDartSurfaceTypes(surface, canonical);
      for (final name in names.keys)
        model.dartShapes[names[name]!] = mapped.types[name]!;
      return mapped;
    }
    if (uri != 'dart:typed_data') return surface;
    final cached = _typedSurface;
    if (cached != null) return cached;
    const prefix = '_qNativeTyped';
    model.backendTypeImports[prefix] = uri;
    for (final entry in surface.types.entries) {
      final key = '@dart.typed.${entry.key}';
      _typedTypeNames[entry.key] = key;
      model.backendTypes[key] = '$prefix.${entry.key}';
      model.internalTypes[key] =
          Symbol(key, '$prefix.${entry.key}', key, external: true);
    }
    String canonical(String source) {
      var mapped = source;
      for (final entry in _typedTypeNames.entries) {
        mapped = mapped.replaceAll(
            RegExp('(?<![\\w.])${RegExp.escape(entry.key)}\\b'), entry.value);
      }
      return mapped;
    }

    final mapped = mapDartSurfaceTypes(surface, canonical);
    for (final entry in mapped.types.entries) {
      model.dartShapes[_typedTypeNames[entry.key]!] = entry.value;
    }
    _typedSurface = mapped;
    return mapped;
  }

  void _bindNativeAlias(String name, DartTop top, String? prefix) {
    if (!top.isType || !top.type.startsWith('@dart.')) return;
    model.aliases[prefix == null ? name : '$prefix.$name'] = top.type;
  }

  void _bindSurface(ImportDeclaration node, DartSurface surface) {
    surface = _nativeSurface(node.uri, surface);

    model.dartShapes.addAll(surface.types);
    if (node.show.isNotEmpty) {
      for (final name in node.show) {
        if (!surface.names.containsKey(name)) {
          error('E200', 'Name $name is not defined', node);
        }
      }
    }
    if (node.uri == 'dart:core' &&
        node.prefix == null &&
        node.hide.isNotEmpty) {
      for (final name in node.hide) {
        _core.symbols.remove(name);
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
      _bindNativeAlias(name, top, node.prefix);
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

  void _checkInternalLibraryAccess(
      String from, String targetPath, ImportDeclaration node) {
    final owner = externalInternalPackageOwner(from, targetPath);
    if (owner == null) return;
    final verb = node.export ? 'export' : 'import';
    error(
      'E208',
      'Cannot $verb internal library ${node.uri} from outside package $owner',
      node,
    );
  }

  void _bindPackage(ImportDeclaration node) {
    if (_file == '<input>') {
      if (node.uri.startsWith('generated:')) {
        fail('Unknown import: ${node.uri}', node);
      }
      return;
    }
    final path = resolveLibraryPath(_file, node.uri,
        packageConfigFrom: _packageConfigFrom);
    if (path == null) {
      if (node.uri.startsWith('package:') && packageRoot(_file) == null) return;
      fail('Unknown import: ${node.uri}', node);
    }
    final imported = _libraries[path];
    final dartUri = dartLibraryUri(_file, node.uri);
    if (imported == null) {
      if (node.uri.startsWith('package:') &&
          librarySection(node.uri) == null &&
          dartUri != null) {
        final dartFile = packageDartFile(_file, dartUri,
            packageConfigFrom: _packageConfigFrom);
        if (dartFile != null) {
          model.resolvedImports[node] = dartUri;
          _bindExternalDartPackage(node, dartUri);
          return;
        }
      }
      fail('Unknown import: ${node.uri}', node);
    }
    _checkInternalLibraryAccess(_file, path, node);
    if (dartUri != null) model.resolvedImports[node] = dartUri;
    if (path == _file) return;
    final filtered = _filteredImport(node, imported, path);
    if (filtered.empty) return;
    if (node.export) {
      _importLibrary(imported, path,
          filter: filtered.filter ?? node, bind: false);
      return;
    }
    _importLibrary(imported, path,
        filter: filtered.filter, qualify: node.prefix);
  }

  String _resolveLibrary(String from, String uri) {
    if (uri.startsWith('quds:')) return uri;
    final resolved =
        resolveLibraryPath(from, uri, packageConfigFrom: _packageConfigFrom);
    if (resolved != null) return resolved;
    final target = Uri.file(from).resolve(uri);
    if (target.scheme != 'file' && target.scheme.isNotEmpty) return uri;
    return target.toFilePath();
  }

  /// A section import keeps that section and every section under it.
  ///
  /// [home] is the library key stored on the imported symbols.
  _FilteredImport _filteredImport(
      ImportDeclaration node, Program imported, String home) {
    final section = librarySection(node.uri);
    if (section == null) {
      return _FilteredImport(
          node.show.isEmpty && node.hide.isEmpty ? null : node, false);
    }
    if (!librarySectionPattern.hasMatch(section)) {
      fail('Unknown import: ${node.uri}', node);
    }
    final selected = _namesInSection(imported, section);
    if (selected == null) fail('Unknown import: ${node.uri}', node);
    final visible = <String>[
      ...selected.$1,
      for (final name in selected.$2)
        if (!selected.$1.contains(name)) name,
    ];
    for (final name in node.show) {
      if (!visible.contains(name)) {
        error('E200', 'Name $name is not defined', node);
      }
    }
    final shown = node.show.isNotEmpty
        ? [
            for (final name in node.show)
              if (visible.contains(name)) name,
          ]
        : [
            for (final name in visible)
              if (!node.hide.contains(name)) name,
          ];
    model.sectionImports[node] = shown;
    model.importHomes[node] = home;
    if (shown.isEmpty) return const _FilteredImport(null, true);
    return _FilteredImport(
        ImportDeclaration(node.uri, node.prefix, node.span,
            export: node.export, show: shown),
        false);
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

  Set<String> _internalNames(Program program, String path, Set<String> seen) {
    if (!seen.add(path)) return {};
    final names = <String>{};
    for (final statement in program.statements) {
      switch (statement) {
        case ClassDeclaration()
            when statement.visibility == 'internal' &&
                !statement.name.startsWith('_'):
          names.add(statement.name);
        case FunctionDeclaration()
            when statement.visibility == 'internal' &&
                statement.name != 'main' &&
                !statement.name.startsWith('_'):
          names.add(statement.name);
        case AliasDeclaration()
            when statement.visibility == 'internal' &&
                !statement.name.startsWith('_'):
          names.add(statement.name);
        case ExtensionDeclaration()
            when statement.visibility == 'internal' &&
                statement.name != null &&
                !statement.name!.startsWith('_'):
          names.add(statement.name!);
        case ImportDeclaration()
            when statement.export && !statement.uri.startsWith('dart:'):
          final exportedPath = _resolveLibrary(path, statement.uri);
          final exported = _libraries[exportedPath];
          if (exported != null) {
            names.addAll(_internalNames(exported, exportedPath, seen)
                .where((name) => _keeps(name, statement)));
          }
        case PartDirective() when !statement.of:
          final partPath = _resolveLibrary(path, statement.uri);
          final part = _libraries[partPath];
          if (part != null) names.addAll(_internalNames(part, partPath, seen));
        default:
          break;
      }
    }
    return names;
  }

  void _recordBlockedInternal(String name, String? qualify) {
    if (qualify == null) {
      _blockedInternalNames.add(name);
    } else {
      _blockedInternalByPrefix.putIfAbsent(qualify, () => <String>{}).add(name);
    }
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
    final inSamePackage = samePackage(_file, home);
    if (check && filter != null && filter.show.isNotEmpty) {
      final available = _publicNames(imported, path, {});
      final internals =
          inSamePackage ? const <String>{} : _internalNames(imported, path, {});
      for (final name in filter.show) {
        if (internals.contains(name)) {
          error(
            'E209',
            'An internal name $name is used outside its package',
            filter,
          );
        }
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
          if (statement.visibility == 'internal' && !inSamePackage) {
            _recordBlockedInternal(statement.name, qualify);
            break;
          }
          _importClass(statement, home: home, qualify: qualify);
        case FunctionDeclaration() when statement.conversionKind.isNotEmpty:
          if (statement.visibility == 'internal' && !inSamePackage) break;
          if (_keeps(statement.conversionOwner.split('<').first, filter)) {
            _conversionDefinitions[statement] = home;
            _importFunction(statement, library: home);
          }
        case FunctionDeclaration()
            when _importable(statement.name, home) &&
                _keeps(statement.name, filter):
          if (statement.visibility == 'internal' && !inSamePackage) {
            _recordBlockedInternal(statement.name, qualify);
            break;
          }
          _importFunction(statement, qualify: qualify, library: home);
        case AliasDeclaration()
            when _importable(statement.name, home) &&
                _keeps(statement.name, filter):
          if (statement.visibility == 'internal' && !inSamePackage) {
            _recordBlockedInternal(statement.name, qualify);
            break;
          }
          _importAlias(statement, home: home, qualify: qualify);
        case ExtensionDeclaration()
            when statement.name != null &&
                _importable(statement.name!, home) &&
                _keeps(statement.name!, filter):
          if (statement.visibility == 'internal' && !inSamePackage) {
            _recordBlockedInternal(statement.name!, qualify);
            break;
          }
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
          _checkInternalLibraryAccess(path, exportedPath, statement);
          final restricted = _restrict(filter, statement);
          if (((filter?.show.isNotEmpty ?? false) ||
                  statement.show.isNotEmpty) &&
              restricted.show.isEmpty) break;
          _importLibrary(exported, exportedPath,
              seen: visited,
              filter: restricted,
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
    // Validate the imported class's fields and methods in its own library,
    // where sibling types remain visible even if a section/show hides them.
    final saved = _scope;
    final savedAliasShadows = {...model.activeAliasShadows};
    _scope = _libraryScope(home);
    model.activeAliasShadows.addAll(_scope.symbols.keys);
    try {
      registerClass(statement, library: home, scopeName: key);
    } finally {
      _scope = saved;
      model.activeAliasShadows
        ..clear()
        ..addAll(savedAliasShadows);
    }
    if (qualify != null) {
      _space(qualify, statement)[statement.name] = _global.symbols[key]!;
    }
  }

  void _importAlias(AliasDeclaration statement,
      {required String home, String? qualify}) {
    final key = qualify == null ? statement.name : '$qualify.${statement.name}';
    if (model.sdkAliases[key] == home) return;
    if (model.aliases.containsKey(key) ||
        (qualify == null && _global.symbols.containsKey(statement.name))) {
      error('E204', 'Two imports define ${statement.name}', statement);
    }
    _libraryScope(home);
    model.aliases[key] = _libraryType(statement.target, home);
    model.sdkAliases[key] = home;
  }

  void _importExtension(ExtensionDeclaration statement,
      {required String home, String? qualify}) {
    if (model.extensions.contains(statement)) return;
    if (qualify != null &&
        !(statement.name?.startsWith(r'$QudsAugment') ?? false)) return;
    final saved = _scope;
    final savedAliasShadows = {...model.activeAliasShadows};
    _scope = _libraryScope(home);
    model.activeAliasShadows.addAll(_scope.symbols.keys);
    try {
      registerExtension(statement, library: home);
    } finally {
      _scope = saved;
      model.activeAliasShadows
        ..clear()
        ..addAll(savedAliasShadows);
    }
  }

  void _importFunction(FunctionDeclaration statement,
      {String? qualify, String library = '', Map<String, Symbol>? target}) {
    final existing = target != null
        ? target[statement.name]
        : qualify == null
            ? _global.symbols[statement.name]
            : _space(qualify, statement)[statement.name];
    if (existing?.function == statement) return;
    final type = statement.returnType ??
        (statement.expressionBody != null
            ? '<infer>'
            : statement.isAsync
                ? 'Future<void>'
                : 'void');
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
                    !stripReadonlyType(statement.returnType!)
                        .startsWith('Future<')
                ? 'Future<${statement.returnType}>'
                : type;
    if (existing != null &&
        existing.classDeclaration == null &&
        existing.overloads.isNotEmpty &&
        existing.overloads.every((other) => !sameSignature(other, statement))) {
      if (existing.overloads.length == 1) {
        final first = existing.overloads.single;
        final previous = model.declarations[first]!;
        model.declarations[first] = Symbol(
                first.name, _importedOverloadName(first.name, 1), previous.type,
                function: first,
                library: previous.library,
                documentation: previous.documentation)
            .withFunction(first);
      }
      final symbol = Symbol(
              statement.name,
              _importedOverloadName(
                  statement.name, existing.overloads.length + 1),
              effective,
              function: statement,
              library: library,
              documentation: statement.documentation)
          .withFunction(statement);
      model.declarations[statement] = symbol;
      existing.overloads.add(statement);
      for (final parameter in statement.parameters) {
        model.declarations[parameter] = Symbol(
            parameter.name, parameter.name, parameter.type,
            mutable: parameter.mutable);
      }
      return;
    }
    if (existing != null) {
      error('E204', 'Two imports define ${statement.name}', statement);
    }
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
      (target ?? _global.symbols)[statement.name] = symbol;
      return;
    }
    _space(qualify, statement)[statement.name] = symbol;
  }

  /// Stable public name of an imported overload, in source order.
  String _importedOverloadName(String name, int index) => '$name\$$index';

  bool _deferredPrefix(String name) => model.imports
      .any((directive) => directive.deferred && directive.prefix == name);

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
    if (home.isEmpty || home == _activeLibrary) return;
    if (visibility == 'private') {
      error('E206', 'A private name is used outside its library', node);
    }
    if (visibility == 'protected' && !_insideSubtype(owner)) {
      error('E207', 'A protected name is used outside a subtype or its library',
          node);
    }
    if (visibility == 'internal' && !samePackage(_file, home)) {
      error(
          'E209', 'An internal member $name is used outside its package', node);
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
        : _typeSymbol(_genericHead(_classMemberType(type.superclass!, type)))
            ?.classDeclaration;
    if (parent == null) return null;
    return _declarer(parent, name);
  }

  String _visibility(ClassDeclaration type, String name) {
    if (name.startsWith('_')) return 'private';
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
      final declaration = _typeSymbol(_genericHead(name))?.classDeclaration;
      if (declaration == type || _genericHead(name) == type.name) return true;
      final parent = declaration?.superclass;
      if (parent == null || parent == name) return false;
      name = parent;
    }
    return false;
  }

  void _touch(Symbol symbol) {
    if (_suppressSdkUse) return;
    if (symbol.library.isEmpty) return;
    if (symbol.library.startsWith('quds:')) model.usedSdk.add(symbol.library);
    // A prefixed class symbol is keyed as prefix.Type, but import `show`
    // combinators name the declaration in the library, without that prefix.
    final name = symbol.classDeclaration != null && symbol.classCase == null
        ? symbol.classDeclaration!.name
        : symbol.name;
    (model.usedSdkNames[symbol.library] ??= <String>{}).add(name);
  }

  void validateType(String type, Node node, {bool allowVoid = true}) {
    if (_importedTypes.containsKey(type)) return;
    final resolved = _resolveType(type);
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
    if (type.contains(' & ') && functionTypeParts(type) == null) {
      final parts = type.split(' & ').map((part) => part.trim()).toList();
      _checkIntersection(parts, node);
      for (final part in parts) {
        validateType(part, node, allowVoid: false);
      }
      return;
    }
    if (type.contains(' | ') && functionTypeParts(type) == null) {
      for (final part in type.split(' | ')) {
        validateType(part.trim(), node, allowVoid: false);
      }
      return;
    }
    if (type.startsWith('(') && isNullableType(type)) {
      validateType(nonNullableType(type), node, allowVoid: false);
      return;
    }
    if (functionTypeParts(type) != null) {
      final (parameters, returns) = _functionParts(type);
      if (parameters.trim().isNotEmpty) {
        final names = <String>{};
        var optionalPosition = false, namedPosition = false;
        final shapes = functionParameters(parameters);
        for (var i = 0; i < shapes.length; i++) {
          final part = shapes[i];
          if (part.name != null && !names.add(part.name!))
            error('E503', 'Duplicate function-type parameter: ${part.name}',
                node);
          if (part.variadic) {
            validateType(part.type, node, allowVoid: false);
            continue;
          }
          if (part.named) {
            namedPosition = true;
          } else {
            if (namedPosition || optionalPosition && !part.optional)
              error(
                  'E503',
                  'Required positional parameters must precede optional/named parameters',
                  node);
            optionalPosition |= part.optional;
          }
          validateType(part.type, node, allowVoid: false);
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
      'StackTrace',
      'ConversionError'
    }.contains(type)) {
      return;
    }
    if (allowVoid && type == 'void') return;
    if (_ffi && _ffiNative.contains(type)) return;
    if (_ffi && type.startsWith('Pointer<') && type.endsWith('>')) {
      validateType(type.substring(8, type.length - 1), node, allowVoid: false);
      return;
    }
    if (isNullableType(type)) {
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
      for (final part in _splitTypes(inner)) {
        validateType(part.trim(), node, allowVoid: false);
      }
      return;
    }
    final named = _typeSymbol(type);
    if (named?.classDeclaration != null ||
        named?.classCase != null ||
        _pendingClasses.contains(type)) {
      if (named != null) _touch(named);
      return;
    }
    // A class brought in from dart:math or another re-exported Dart library.
    // Its symbol is external, so it has no Quds class declaration.
    if (named != null && model.dartShapes.containsKey(type)) {
      _touch(named);
      return;
    }
    final open = type.indexOf('<');
    if (open > 0 && type.endsWith('>')) {
      final head = type.substring(0, open);
      final symbol = _typeSymbol(head);
      final declaration = symbol?.classDeclaration;
      final native = _nativeShape(head);
      if (native != null) {
        final args = _splitTypes(type.substring(open + 1, type.length - 1));
        _checkTypeArguments(
            head,
            [
              for (final p in native.typeParameters.entries)
                TypeParameter(p.key, node.span, bound: p.value)
            ],
            args,
            node);
        if (symbol != null) _touch(symbol);
        return;
      }
      if (declaration != null) {
        _touch(symbol!);
        final args = _splitTypes(type.substring(open + 1, type.length - 1));
        _checkTypeArguments(head, declaration.typeParameters, args, node);
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

  /// Scope for [home], parented at the importer's globals.
  ///
  /// Public names are already in the global scope. Private functions stay in
  /// this scope only. A `use dart:x as prefix` inside the library is bound
  /// here so bodies can write `math.log` without leaking the prefix.
  _Scope _libraryScope(String home) {
    final cached = _libraryScopes[home];
    if (cached != null) return cached;
    final scope = _Scope(_global);
    _libraryScopes[home] = scope;
    final program = _libraries[home];
    if (program == null) return scope;
    final names = <String, String>{};
    _libraryTypes[home] = names;
    final prefix = '_qImportedType${_libraryTypes.length - 1}';
    final sdk = sdkLibraryName(home);
    model.backendTypeImports[prefix] =
        sdk == null ? qudsBackendLibraryUri(_file, home) : sdkDartFileName(sdk);
    for (final declaration
        in program.statements.whereType<ClassDeclaration>()) {
      scope.symbols[declaration.name] = Symbol(
          declaration.name, declaration.name, declaration.name,
          classDeclaration: declaration, library: home);
      // Private metadata also needs a library-specific key: registering it
      // under its bare name would collide with the caller's private classes.
      final key = '@${_libraryTypes.length - 1}.${declaration.name}';
      names[declaration.name] = key;
      model.backendTypes[key] = '$prefix.${declaration.name}';
    }
    for (final alias in program.statements.whereType<AliasDeclaration>()) {
      names[alias.name] = '@${_libraryTypes.length - 1}.${alias.name}';
    }
    // Signatures in this library keep their lexical imported type identities,
    // even when the caller uses a different prefix or imports no such type.
    for (final directive in program.statements.whereType<ImportDeclaration>()) {
      if (directive.export ||
          directive.uri.startsWith('dart:') ||
          _isLocalDart(directive)) continue;
      final target = _resolveLibrary(home, directive.uri);
      if (!_libraries.containsKey(target) || target == home) continue;
      _libraryScope(target);
      for (final entry
          in (_libraryTypes[target] ?? <String, String>{}).entries.toList()) {
        if (entry.key.contains('.') ||
            entry.key.startsWith('_') ||
            !_keeps(entry.key, directive)) continue;
        final local = directive.prefix == null
            ? entry.key
            : '${directive.prefix}.${entry.key}';
        names.putIfAbsent(local, () => entry.value);
      }
    }
    final saved = _scope;
    final savedAliasShadows = {...model.activeAliasShadows};
    model.activeAliasShadows.addAll(scope.symbols.keys);
    _scope = scope;
    try {
      for (final directive
          in program.statements.whereType<ImportDeclaration>()) {
        if (!directive.export &&
            (directive.uri.startsWith('dart:') ||
                directive.uri.startsWith('package:') &&
                    directive.uri.endsWith('.dart') ||
                _isLocalDart(directive))) {
          _bindDartScope(scope, directive, home: home);
        }
      }
      scope.typeBindings.addAll(names);
      for (final alias in program.statements.whereType<AliasDeclaration>()) {
        model.aliases[names[alias.name]!] = _libraryType(alias.target, home);
      }
      for (final statement in program.statements) {
        switch (statement) {
          case FunctionDeclaration():
            final known = model.declarations[statement];
            if (known != null) {
              scope.symbols[statement.name] = known;
              continue;
            }
            _importFunction(statement, library: home, target: scope.symbols);
          case ClassDeclaration():
            if (model.declarations[statement] == null) {
              final key = names[statement.name];
              registerClass(statement, library: home, scopeName: key);
              if (key != null) {
                model.internalTypes[key] = _global.symbols.remove(key)!;
              }
            }
            final key = names[statement.name];
            if (key != null && !model.internalTypes.containsKey(key)) {
              model.internalTypes[key] = Symbol(key, key, key,
                  classDeclaration: statement, library: home);
              model.classes[key] = statement;
            }
          case ImportDeclaration()
              when !statement.export &&
                  (statement.uri.startsWith('dart:') ||
                      statement.uri.startsWith('package:') &&
                          statement.uri.endsWith('.dart') ||
                      _isLocalDart(statement)):
            _bindDartScope(scope, statement, home: home);
          default:
            break;
        }
      }
    } finally {
      _scope = saved;
      model.activeAliasShadows
        ..clear()
        ..addAll(savedAliasShadows);
    }
    return scope;
  }

  Symbol? _typeSymbol(String name) {
    final scoped = _scope.lookup(name);
    if (scoped?.classDeclaration != null) return scoped;
    return _global.symbols[name] ?? scoped ?? model.internalTypes[name];
  }

  String _libraryType(String type, String home,
      {Set<String> shadows = const {}}) {
    final names = _libraryTypes[home];
    if (names == null) return type;
    return substituteBridgeType(type, {
      for (final entry in names.entries)
        if (!shadows.contains(entry.key)) entry.key: entry.value
    });
  }

  String _selfType(String type, ClassDeclaration? owner, String receiver) {
    if (owner == null) return type;
    return type.replaceAll(RegExp('(?<![\\w.])${RegExp.escape(owner.name)}\\b'),
        _genericHead(receiver));
  }

  String get _activeLibrary {
    final home =
        _function == null ? null : model.declarations[_function]?.library;
    return home == null || home.isEmpty ? (_methodLibrary ?? library) : home;
  }

  List<Parameter> _callParameters(
      List<Parameter> parameters, FunctionDeclaration? function) {
    final home =
        function == null ? null : model.declarations[function]?.library;
    if (home == null || home.isEmpty || home == _activeLibrary)
      return parameters;
    _libraryScope(home);
    return [
      for (final parameter in parameters)
        Parameter(parameter.name, _libraryType(parameter.type, home),
            parameter.mutable, parameter.span,
            kind: parameter.kind,
            defaultValue: parameter.defaultValue,
            variadic: parameter.variadic,
            initializing: parameter.initializing)
    ];
  }

  String _callResult(String type, FunctionDeclaration? function) {
    final home =
        function == null ? null : model.declarations[function]?.library;
    if (home == null || home.isEmpty || home == _activeLibrary) return type;
    return _libraryType(type, home);
  }

  void _bindDartScope(_Scope scope, ImportDeclaration node, {String? home}) {
    final prefix = node.prefix;
    if (prefix != null && scope.symbols.containsKey(prefix)) return;
    DartSurface? surface;
    try {
      surface = _isLocalDart(node)
          ? _localDartSurface(node)
          : node.uri.startsWith('package:')
              ? (() {
                  final from =
                      node.span.file == '<input>' ? _file : node.span.file;
                  final file = packageDartFile(from, node.uri,
                      packageConfigFrom: _packageConfigFrom);
                  return file == null ? null : readDartFile(file, from: from);
                })()
              : readDartLibrary(node.uri);
    } catch (_) {
      surface = null;
    }
    if (surface == null) return;
    surface = _nativeSurface(node.uri, surface);
    final space = prefix == null ? scope.symbols : <String, Symbol>{};
    for (final name in surface.names.keys) {
      if (!_keeps(name, node) || space.containsKey(name)) continue;
      final top = surface.names[name];
      if (top == null) continue;
      if (top.isType) {
        model.activeAliasShadows.add(prefix ?? name);
        if (home != null && top.type.startsWith('@dart.')) {
          _libraryTypes[home]?[prefix == null ? name : '$prefix.$name'] =
              top.type;
        }
      }
      final shape = surface.types[name];
      if (shape != null) model.dartShapes[name] = shape;
      space[name] = symbolForDart(top, shape);
    }
    if (prefix != null) {
      scope.symbols[prefix] =
          Symbol(prefix, prefix, 'prefix', namespace: space);
    }
  }

  void analyzeFunction(FunctionDeclaration function) {
    final savedTypes = {..._typeNames};
    final savedBounds = {..._typeBounds};
    _typeNames.addAll(function.typeParameters.map((item) => item.name));
    for (final parameter in function.typeParameters) {
      _typeBounds.remove(parameter.name);
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
    final savedConsumed = Map<Symbol, SourceSpan>.from(_consumed);
    _promoted.clear();
    _consumed.clear();
    // A top-level function does not close over the caller's locals. Calls
    // re-check a function that has defaults, and that call may sit inside
    // another function. Parent the body at the global scope in that case.
    // An imported function is parented at its own library so private helpers
    // and that library's prefixes stay visible.
    final home = model.declarations[function]?.library ?? '';
    final _Scope parent;
    if (_methodOwners.containsKey(function)) {
      parent = savedScope;
    } else if (home.isNotEmpty && home != library) {
      parent = _libraryScope(home);
    } else if (_declaredAtTopLevel(function)) {
      parent = _global;
    } else {
      parent = savedScope;
    }
    final savedAliasShadows = {...model.activeAliasShadows};
    if (home.isNotEmpty && home != library) {
      model.activeAliasShadows.addAll(parent.symbols.keys);
    }
    _scope = _Scope(parent);
    _function = function;
    final declared = model.declarations[function]!.type;
    final bareReturn =
        declared.startsWith('readonly ') ? declared.substring(9) : declared;
    final container = function.generator == 'sync'
        ? 'Iterable<'
        : function.generator == 'async'
            ? 'Stream<'
            : function.isAsync
                ? 'Future<'
                : '';
    _returnType = container.isNotEmpty &&
            bareReturn.startsWith(container) &&
            bareReturn.endsWith('>')
        ? _readonlyView(declared,
            bareReturn.substring(container.length, bareReturn.length - 1))
        : declared;
    final parameterNames = <String>[];
    for (final parameter in function.parameters) {
      final stored =
          parameter.variadic ? 'List<${parameter.type}>' : parameter.type;
      validateType(stored, parameter, allowVoid: false);
      if (_lookupNonCore(parameter.name) != null)
        fail('Parameter would shadow an existing symbol: ${parameter.name}',
            parameter);
      final symbol = create(parameter.name, stored, mutable: parameter.mutable);
      _scope.symbols[parameter.name] = symbol;
      model.declarations[parameter] = symbol;
      if (parameter.defaultValue case final value?) {
        restrictDefault(value, parameterNames.toSet(),
            function.parameters.map((item) => item.name).toSet());
        final savedDefaultExpected = _expected;
        _expected = parameter.type;
        final String type;
        try {
          type = expression(value);
        } finally {
          _expected = savedDefaultExpected;
        }
        if (!_acceptExpected(value, type, parameter.type)) {
          fail('Default type $type is incompatible with ${parameter.type}',
              value);
        }
      }
      parameterNames.add(parameter.name);
    }
    if (function.expressionBody case final value?) {
      final savedExpected = _expected;
      _expected = _returnType == '<infer>' ? null : _returnType;
      final String type;
      try {
        type = expression(value);
      } finally {
        _expected = savedExpected;
      }
      if (_returnType == '<infer>') {
        model.declarations[function]!.type = function.generator == 'sync'
            ? 'Iterable<$type>'
            : function.generator == 'async'
                ? 'Stream<$type>'
                : function.isAsync
                    ? 'Future<$type>'
                    : type;
      } else if (!_acceptExpected(value, type, _returnType!)) {
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
    model.activeAliasShadows
      ..clear()
      ..addAll(savedAliasShadows);
    _promoted
      ..clear()
      ..addAll(savedPromoted);
    _consumed
      ..clear()
      ..addAll(savedConsumed);
    _checking.remove(function);
    _checked.add(function);
    _typeNames
      ..clear()
      ..addAll(savedTypes);
    _typeBounds
      ..clear()
      ..addAll(savedBounds);
  }

  void _checkLoopConsumed(
      List<Statement> body, _Scope outerScope, Map<Symbol, SourceSpan> before) {
    if (_alwaysExits(body)) return;
    for (final entry in _consumed.entries) {
      if (before.containsKey(entry.key)) continue;
      if (outerScope.lookup(entry.key.name) == entry.key) {
        throw CompilerException(
            'E315',
            'Value ${entry.key.name} cannot be consumed inside a loop that may run more than once',
            entry.value);
      }
    }
  }

  bool returns(List<Statement> body) {
    for (final statement in body) {
      // Throwing paths cannot fall through to a missing return value.
      if (statement is ReturnStatement ||
          statement is ThrowStatement ||
          statement is RethrowStatement) return true;
      if (statement is GuardedStatement &&
          statement.alternate != null &&
          statement.statement is ReturnStatement) {
        return true;
      }
      if (statement is UsingStatement && returns(statement.body)) {
        return true;
      }
      if (statement is WhenStatement &&
          !model.skipped.contains(statement) &&
          returns(statement.body)) {
        return true;
      }
      if (statement is TryStatement &&
          (returns(statement.finallyBody) ||
              (returns([...statement.body, ...statement.elseBody]) &&
                  statement.catches.every((clause) => returns(clause.body))))) {
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
        case UsingStatement():
          if (_mentionsBreak(statement.body)) return true;
        case WhenStatement():
          if (!model.skipped.contains(statement) &&
              _mentionsBreak(statement.body)) {
            return true;
          }
        case DestructureStatement():
          if (statement.elseBody != null &&
              _mentionsBreak(statement.elseBody!)) {
            return true;
          }
        case GuardStatement():
          if (_mentionsBreak(statement.elseBody)) {
            return true;
          }
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
    final savedPromoted = Map<String, String>.from(_promoted);
    final local = <String>[];
    for (final statement in body) {
      check(statement);
      final extra = _exitPromotion(statement);
      if (extra == null) continue;
      for (final entry in extra.entries) {
        _promoted[entry.key] = entry.value;
        local.add(entry.key);
      }
    }
    for (final name in local) {
      if (savedPromoted.containsKey(name)) {
        _promoted[name] = savedPromoted[name]!;
      } else {
        _promoted.remove(name);
      }
    }
    _scope = saved;
  }

  /// After `if name is Arm: return`, a two-arm union leaves the other arm.
  /// After `guard cond else: return`, the condition holds for the rest of the block.
  /// The fact belongs to this statement list, so a nested block cannot leak it.
  Map<String, String>? _exitPromotion(Statement node) {
    if (node is GuardStatement && _alwaysExits(node.elseBody)) {
      final promoted = _promotions(node.condition, whenTrue: true);
      return promoted.isEmpty ? null : promoted;
    }
    if (node is! IfCaseStatement || !_alwaysExits(node.body)) return null;
    final scrutinee = node.scrutinee;
    final pattern = node.pattern;
    if (scrutinee is! Identifier || pattern is! TypedPattern) return null;
    final symbol = model.references[scrutinee];
    if (symbol == null) return null;
    final visible = _resolveType(_promoted[scrutinee.name] ?? symbol.type);
    final arm = _resolveType(pattern.type);
    if (!visible.contains(' | ') || functionTypeParts(visible) != null) {
      return null;
    }
    final parts = [for (final part in visible.split(' | ')) part.trim()];
    if (!parts.contains(arm)) return null;
    final rest = [
      for (final part in parts)
        if (part != arm) part
    ];
    if (rest.length != 1) return null;
    return {scrutinee.name: rest.single};
  }

  bool _alwaysExits(List<Statement> body) {
    for (final statement in body) {
      if (_statementExits(statement)) return true;
    }
    return false;
  }

  bool _statementExits(Statement node) => switch (node) {
        ReturnStatement() ||
        ThrowStatement() ||
        RethrowStatement() ||
        BreakStatement() ||
        ContinueStatement() =>
          true,
        UsingStatement() => _alwaysExits(node.body),
        WhenStatement() =>
          !model.skipped.contains(node) && _alwaysExits(node.body),
        IfStatement() => node.elseBody.isNotEmpty &&
            _alwaysExits(node.thenBody) &&
            _alwaysExits(node.elseBody),
        IfLetStatement() => node.elseBody.isNotEmpty &&
            _alwaysExits(node.thenBody) &&
            _alwaysExits(node.elseBody),
        _ => false,
      };

  void check(Statement node) {
    switch (node) {
      case Binding():
        if (node.mode == BindingMode.state ||
            node.mode == BindingMode.computed) {
          if (_lookupNonCore(node.name) != null) {
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
          if (node.type != null) _expected = _resolveType(node.type!);
          final type = expression(node.value);
          _expected = savedExpected;
          if (type == 'void') {
            fail('A void expression cannot initialize a binding', node);
          }
          final target = node.type ?? type;
          validateType(target, node, allowVoid: false);
          if (!_acceptExpected(node.value, type, target)) {
            fail('Cannot initialize $target with $type', node);
          }
          symbol.type = target;
          _rememberGapValue(symbol, node.value);
          if (reactive == 'computed' && computedCycle(node.name, node.value)) {
            warn('W007', 'computed dependency cycle', node);
          }
          return;
        }
        final existing = _lookupNonCore(node.name);
        final savedExpected = _expected;
        if (node.type != null) {
          _expected = _resolveType(node.type!);
        } else if (existing != null &&
            node.mode == BindingMode.inferred &&
            node.type == null) {
          _expected = _resolveType(existing.type);
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
        var type = expression(node.value);
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
            if (node.operator != '=' && node.operator != '??=') {
              final owner =
                  _typeSymbol(_genericHead(existing.type))?.classDeclaration;
              final method = owner == null
                  ? null
                  : _method(owner, node.operator[0], arity: 1);
              if (method != null &&
                  method.isOperator &&
                  method.parameters.isNotEmpty) {
                final expected = _qualifyType(_genericHead(existing.type),
                    method.parameters.first.type, owner!.name);
                if (_acceptExpected(node.value, type, expected))
                  type =
                      model.implicitConversions[node.value]?.resultType ?? type;
              }
            }
            final result = node.operator == '='
                ? type
                : binaryType(existing.type, node.operator[0], type, node);
            if (!(node.operator == '='
                ? _acceptExpected(node.value, result, existing.type)
                : compatible(result, existing.type))) {
              fail('Cannot assign $result to ${existing.type}', node);
            }
          }
          if (node.operator != '=') {
            final consumedAt = _consumed[existing];
            if (consumedAt != null) {
              error(
                  'E315',
                  'Value ${existing.name} was already consumed at line ${consumedAt.line}',
                  node);
            }
          } else {
            _consumed.remove(existing);
          }
          model.references[node] = existing;
          model.assignments.add(node);
          if (_valueHasGap(node.value)) {
            model.gapValues.add(existing);
          } else {
            model.gapValues.remove(existing);
          }
          _afterAssignment(
              node.name,
              existing.type,
              model.implicitConversions[node.value]?.resultType ?? type,
              node.operator);
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
        if (!_acceptExpected(node.value, type, target))
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
          _rejectConstantConversion(node.value);
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
        _rememberUnionHome(symbol, node.value);
        _rememberGapValue(symbol, node.value);
      case IfStatement():
        _requireBool(node.condition, 'if condition must be bool');
        final beforeIf = Map<Symbol, SourceSpan>.from(_consumed);
        _withPromotions(_promotions(node.condition, whenTrue: true),
            () => statements(node.thenBody, nested: true));
        final afterThen = Map<Symbol, SourceSpan>.from(_consumed);
        final thenExits = _alwaysExits(node.thenBody);
        _consumed
          ..clear()
          ..addAll(beforeIf);
        _withPromotions(_promotions(node.condition, whenTrue: false),
            () => statements(node.elseBody, nested: true));
        final afterElse = Map<Symbol, SourceSpan>.from(_consumed);
        final elseExits =
            node.elseBody.isNotEmpty && _alwaysExits(node.elseBody);
        _consumed.clear();
        if (thenExits && elseExits) {
          _consumed.addAll(beforeIf);
        } else if (thenExits) {
          _consumed.addAll(afterElse);
        } else if (elseExits) {
          _consumed.addAll(afterThen);
        } else {
          _consumed
            ..addAll(afterThen)
            ..addAll(afterElse);
        }
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
            ? (stripReadonlyType(type).startsWith('Stream<') &&
                    type.endsWith('>')
                ? _readonlyView(
                    type,
                    stripReadonlyType(type)
                        .substring(7, stripReadonlyType(type).length - 1))
                : fail('await for requires a Stream', node.iterable))
            : elementType(type, node.iterable);
        if (_lookupNonCore(node.name) != null)
          fail('Loop binding would shadow ${node.name}', node);
        if (node.index != null) {
          if (node.index == node.name) {
            fail('Loop bindings must have different names', node);
          }
          if (_lookupNonCore(node.index!) != null) {
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
        final beforeFor = Map<Symbol, SourceSpan>.from(_consumed);
        final frame = _LoopFrame(asValue);
        _loops.add(frame);
        _loopDepth++;
        _withIteration(node, symbol, () => statements(node.body));
        _loopDepth--;
        _loops.removeLast();
        if (asValue) _valueBreakType = frame.breakType;
        _scope = saved;
        _checkLoopConsumed(node.body, saved, beforeFor);
        if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
      case WhileStatement():
        final asValue = _armValueLoop;
        _armValueLoop = false;
        final beforeWhile = Map<Symbol, SourceSpan>.from(_consumed);
        final outerWhileScope = _scope;
        if (node.letName != null) {
          final frame = _LoopFrame(asValue);
          _loops.add(frame);
          _loopDepth++;
          _withLet(node.letName!, node.condition, node, () {
            _withIteration(
                node, null, () => statements(node.body, nested: true));
          });
          _loopDepth--;
          _loops.removeLast();
          if (asValue) _valueBreakType = frame.breakType;
          _checkLoopConsumed(node.body, outerWhileScope, beforeWhile);
          if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
          break;
        }
        if (node.pattern != null) {
          final frame = _LoopFrame(asValue);
          _loops.add(frame);
          _loopDepth++;
          _withPattern(node.condition, node.pattern!, () {
            _withIteration(
                node, null, () => statements(node.body, nested: true));
          });
          _loopDepth--;
          _loops.removeLast();
          if (asValue) _valueBreakType = frame.breakType;
          _checkLoopConsumed(node.body, outerWhileScope, beforeWhile);
          if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
          break;
        }
        _requireBool(node.condition, 'while condition must be bool');
        final frame = _LoopFrame(asValue);
        _loops.add(frame);
        _loopDepth++;
        _withPromotions(
            _promotions(node.condition, whenTrue: true),
            () => _withIteration(
                node, null, () => statements(node.body, nested: true)));
        _loopDepth--;
        _loops.removeLast();
        if (asValue) _valueBreakType = frame.breakType;
        _checkLoopConsumed(node.body, outerWhileScope, beforeWhile);
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
        final beforeMatch = Map<Symbol, SourceSpan>.from(_consumed);
        final mergedMatch = <Symbol, SourceSpan>{};
        var anyFallthrough = false;
        for (final arm in node.arms) {
          _consumed
            ..clear()
            ..addAll(beforeMatch);
          final saved = _scope;
          _scope = _Scope(saved);
          bindPattern(arm.pattern, matched);
          if (arm.guard != null && expression(arm.guard!) != 'bool') {
            fail('when guard must be bool', arm.guard!);
          }
          statements(arm.body);
          _scope = saved;
          if (!_alwaysExits(arm.body)) {
            anyFallthrough = true;
            mergedMatch.addAll(_consumed);
          }
        }
        _consumed.clear();
        if (anyFallthrough) {
          _consumed.addAll(mergedMatch);
        } else {
          _consumed.addAll(beforeMatch);
        }
        checkExhaustive(node, matched, node.arms.map((arm) => arm.pattern),
            node.arms.map((arm) => arm.guard));
      case DestructureStatement():
        final type = expression(node.value);
        if (node.elseBody == null) {
          if (_refutable(node.pattern)) {
            error(
                'E100', 'A refutable pattern cannot be assigned', node.pattern);
          }
          _assignPattern = true;
          bindPattern(node.pattern, type, declare: true);
          _assignPattern = false;
        } else {
          final beforeElse = Map<Symbol, SourceSpan>.from(_consumed);
          statements(node.elseBody!, nested: true);
          if (!_alwaysExits(node.elseBody!)) {
            error(
                'E316',
                'Guard destructuring else branch must exit the enclosing scope (return, throw, break, or continue)',
                node);
          }
          // elseBody always exits, so any consumption inside it never reaches
          // the happy path after the guard destructuring statement.
          _consumed
            ..clear()
            ..addAll(beforeElse);
          bindPattern(node.pattern, type, declare: true);
        }
      case GuardStatement():
        _requireBool(node.condition, 'guard condition must be bool');
        final beforeGuard = Map<Symbol, SourceSpan>.from(_consumed);
        _withPromotions(_promotions(node.condition, whenTrue: false),
            () => statements(node.elseBody, nested: true));
        if (!_alwaysExits(node.elseBody)) {
          error(
              'E316',
              'guard else branch must exit the enclosing scope (return, throw, break, or continue)',
              node);
        }
        _consumed
          ..clear()
          ..addAll(beforeGuard);
      case ReturnStatement():
        if (_function == null && _returnType != '<infer>') {
          fail('return is only valid inside a function', node);
        }
        final savedExpected = _expected;
        _expected = _returnType == '<infer>' ? null : _returnType;
        final String type;
        try {
          type = node.value == null ? 'void' : expression(node.value!);
        } finally {
          _expected = savedExpected;
        }
        if (_returnType == '<infer>') break;
        if (!(node.value == null
            ? compatible(type, _returnType!)
            : _acceptExpected(node.value!, type, _returnType!)))
          fail('Return type $type is incompatible with $_returnType', node);
      case ExpressionStatement():
        final valueType = expression(node.expression);
        if (node.expression is Identifier && valueType.contains('->')) {
          final name = (node.expression as Identifier).name;
          error('E110',
              'A zero-argument call has no parentheses; write $name()', node);
        }
        if (node.expression is! CallExpression &&
            node.expression is! AwaitExpression &&
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
        final beforeCFor = Map<Symbol, SourceSpan>.from(_consumed);
        final frame = _LoopFrame(asValue);
        _loops.add(frame);
        _loopDepth++;
        _withIteration(node, null, () => statements(node.body));
        _loopDepth--;
        _loops.removeLast();
        if (asValue) _valueBreakType = frame.breakType;
        _scope = savedFor;
        _checkLoopConsumed(node.body, savedFor, beforeCFor);
        if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
      case TryStatement():
        final beforeTry = Map<Symbol, SourceSpan>.from(_consumed);
        statements(node.body, nested: true);
        final mergedTry = Map<Symbol, SourceSpan>.from(_consumed);
        for (final clause in node.catches) {
          _consumed
            ..clear()
            ..addAll(beforeTry);
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
          if (!_alwaysExits(clause.body)) {
            mergedTry.addAll(_consumed);
          }
        }
        _consumed
          ..clear()
          ..addAll(mergedTry);
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
        final beforeRepeat = Map<Symbol, SourceSpan>.from(_consumed);
        final outerRepeatScope = _scope;
        if (node.count != null) {
          if (expression(node.count!) != 'int') {
            fail('repeat count must be int', node.count!);
          }
          final frame = _LoopFrame(asValue);
          _loops.add(frame);
          _loopDepth++;
          _withIteration(node, null, () => statements(node.body, nested: true));
          _loopDepth--;
          _loops.removeLast();
          if (asValue) _valueBreakType = frame.breakType;
          _checkLoopConsumed(node.body, outerRepeatScope, beforeRepeat);
          if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
          break;
        }
        final frame = _LoopFrame(asValue);
        _loops.add(frame);
        _loopDepth++;
        _withIteration(node, null, () => statements(node.body, nested: true));
        _loopDepth--;
        _loops.removeLast();
        if (asValue) _valueBreakType = frame.breakType;
        _checkLoopConsumed(node.body, outerRepeatScope, beforeRepeat);
        if (_withIteration(node, null, () => expression(node.condition!)) !=
            'bool') {
          fail('repeat condition must be bool', node.condition!);
        }
        if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
      case TestDeclaration():
        model.declarations[node] =
            create(node.title, node.isAsync ? 'Future<void>' : 'void');
        final savedFunction = _function;
        final savedPromoted = Map<String, String>.from(_promoted);
        final savedConsumed = Map<Symbol, SourceSpan>.from(_consumed);
        _promoted.clear();
        _consumed.clear();
        if (node.isAsync) {
          _function = FunctionDeclaration(
              node.title, const [], 'void', node.body, null, node.span,
              isAsync: true);
        }
        statements(node.body, nested: true);
        _function = savedFunction;
        _promoted
          ..clear()
          ..addAll(savedPromoted);
        _consumed
          ..clear()
          ..addAll(savedConsumed);
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
        final beforeCase = Map<Symbol, SourceSpan>.from(_consumed);
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
        if (_alwaysExits(node.body)) {
          _consumed
            ..clear()
            ..addAll(beforeCase);
        } else {
          _consumed.addAll(beforeCase);
        }
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
        if (!isNullableType(raw) && raw != 'Null') {
          fail('if let requires a nullable value', node.value);
        }
        if (_lookupNonCore(node.name) != null) {
          fail(
              'Binding would shadow ${node.name}; use shadow in an inner scope',
              node);
        }
        final beforeLet = Map<Symbol, SourceSpan>.from(_consumed);
        final savedLet = _scope;
        _scope = _Scope(savedLet);
        final bound = create(node.name, unwrap(raw));
        _scope.symbols[node.name] = bound;
        model.declarations[node] = bound;
        statements(node.thenBody);
        _scope = savedLet;
        final afterLetThen = Map<Symbol, SourceSpan>.from(_consumed);
        final letThenExits = _alwaysExits(node.thenBody);
        _consumed
          ..clear()
          ..addAll(beforeLet);
        if (node.elseBody.isNotEmpty) statements(node.elseBody, nested: true);
        final afterLetElse = Map<Symbol, SourceSpan>.from(_consumed);
        final letElseExits =
            node.elseBody.isNotEmpty && _alwaysExits(node.elseBody);
        _consumed.clear();
        if (letThenExits && letElseExits) {
          _consumed.addAll(beforeLet);
        } else if (letThenExits) {
          _consumed.addAll(afterLetElse);
        } else if (letElseExits) {
          _consumed.addAll(afterLetThen);
        } else {
          _consumed
            ..addAll(afterLetThen)
            ..addAll(afterLetElse);
        }
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
        final cleanup = _resolveUsingCleanup(used, asyncUsing: node.async);
        if (cleanup == null) {
          fail('using requires a value with dispose or close', node.value);
        }
        model.usingCleanup[node] = cleanup;
        final savedUsing = _scope;
        _scope = _Scope(savedUsing);
        final resource = create(node.name, usedType);
        _scope.symbols[node.name] = resource;
        model.declarations[node] = resource;
        statements(node.body);
        _scope = savedUsing;
      case IndexAssignment():
        _assignIndex(node);
      case MemberAssignment():
        _assignMember(node);
      case PartDirective():
        fail('part belongs at the top level', node);
      case SectionDeclaration():
        fail('A section header belongs at the top level', node);
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

  Node? _nativeInstantiationTarget;
  List<String>? _nativeInstantiationArguments;

  String typeApplication(TypeApplication node) {
    final previousTarget = _nativeInstantiationTarget;
    final previousArguments = _nativeInstantiationArguments;
    _nativeInstantiationTarget = node.callee;
    _nativeInstantiationArguments = node.arguments;
    late String type;
    try {
      type = expression(node.callee);
    } finally {
      _nativeInstantiationTarget = previousTarget;
      _nativeInstantiationArguments = previousArguments;
    }
    final symbol = model.references[node.callee];
    final top = symbol?.nativeTop;
    final method = symbol?.nativeMember;
    final nativeCallable = top != null && top.callable && !top.isType ||
        method != null && !method.getter;
    if ((!nativeCallable &&
            !model.validatedQudsFunctionValues.contains(node.callee)) ||
        functionTypeParts(nonNullableType(type)) == null) {
      error(
          'E910',
          'Explicit function values require a supported function or method',
          node);
    }
    model.references[node] = symbol!;
    model.instantiatedFunctionValues.add(node);
    return type;
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
          final owner = model.references[callee.object]?.classDeclaration;
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

  void _assignIndex(IndexAssignment node) {
    final readType = expression(node.target);
    final raw = model.types[node.target.object]!;
    if (raw.startsWith('readonly ')) {
      error('E307', 'A readonly reference cannot be mutated', node.target);
    }
    final isMap = raw.startsWith('Map<');
    if (!isMap && _listElement(raw) == null) {
      error('E300', 'Indexed assignment needs a List or Map', node.target);
    }
    final target = isMap
        ? _splitTypes(raw.substring(4, raw.length - 1))[1]
        : _listElement(raw)!;
    final saved = _expected;
    _expected = target;
    final value = expression(node.value);
    _expected = saved;
    if (node.operator == '??=') {
      if (isMap) {
        if (!_acceptExpected(node.value, value, target))
          fail('Cannot assign $value to $target', node.value);
      } else {
        if (!isNullableType(target) && target != 'Null')
          fail('??= requires a nullable binding', node);
        if (!_acceptExpected(node.value, value, target))
          fail('Cannot assign $value to $target', node.value);
      }
      return;
    }
    final written = node.operator == '='
        ? value
        : binaryType(readType,
            node.operator.substring(0, node.operator.length - 1), value, node);
    if (!(node.operator == '='
        ? _acceptExpected(node.value, written, target)
        : compatible(written, target))) {
      fail('Cannot assign $written to $target', node.value);
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
    final declaration = _typeSymbol(_genericHead(type))?.classDeclaration;
    if (declaration == null) {
      fail(
          _hinted('No member ${node.name} on $raw', node.name,
              _memberCandidates(raw)),
          node);
    }
    final targetType = memberType(type, node.name) ??
        fail('No member ${node.name} on $raw', node);
    final properties =
        _propertiesOf(declaration).where((item) => item.name == node.name);
    if (properties.isNotEmpty) {
      final property = properties.first;
      if (property.setter == null && property.setterBody == null) {
        fail('Property ${node.name} is read-only', node);
      }
      final value = expression(node.value);
      final written = node.operator == '=' || node.operator == '??='
          ? value
          : binaryType(
              targetType,
              node.operator.substring(0, node.operator.length - 1),
              value,
              node);
      if (node.operator == '??=') _checkIfNull(targetType, value, node);
      if (!(node.operator == '=' || node.operator == '??='
          ? _acceptExpected(node.value, written, targetType)
          : compatible(written, targetType))) {
        fail('Cannot assign $value to ${targetType}', node);
      }
      _checkMember(declaration, node.name, node);
      model.references[node] =
          Symbol(property.name, _dartMember(type, property.name), targetType);
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
      _checkIfNull(targetType, value, node);
    } else if (node.operator == '='
        ? !_acceptExpected(node.value, value, targetType)
        : !compatible(
            node.operator == '='
                ? value
                : binaryType(
                    targetType,
                    node.operator.substring(0, node.operator.length - 1),
                    value,
                    node),
            targetType)) {
      fail('Cannot assign $value to ${targetType}', node);
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
    model.references[node] = Symbol(
        fields.first.name, _dartMember(type, fields.first.name), targetType);
  }

  void _installChecks() {
    const docs =
        'Same checker as Dart package:test. A value that is not a matcher is compared with equals.';
    void bind(String name, String dartName, String type,
        {List<String> parameters = const [],
        int optional = 0,
        String? signature}) {
      _global.symbols[name] = Symbol(
        name,
        dartName,
        type,
        library: 'check',
        parameterTypes: parameters,
        optionalParameters: optional,
        signature: signature,
        documentation: docs,
      );
    }

    bind(
      'expect',
      '_qrun.qExpect',
      'void',
      signature:
          'expect(actual: Object?, matcher: Object?, reason: String?, skip: Object?) -> void',
    );
    bind(
      'expectLater',
      '_qrun.qExpectLater',
      'Future<void>',
      signature:
          'expectLater(actual: Object?, matcher: Object?, reason: String?, skip: Object?) -> Future<void>',
    );
    bind('fail', '_qrun.qFail', 'void',
        parameters: const ['String'],
        signature: 'fail(message: String) -> void');
    for (final check in checks) {
      bind(check.name, '_qmatch.${check.name}', 'dynamic',
          parameters: check.parameters,
          optional: check.optional,
          signature: check.signature);
    }
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
    if (type.startsWith('readonly ')) {
      return _readonlyView(type, elementType(type.substring(9), node));
    }
    final typed = _nativeShape(type)?.listElement;
    if (typed != null) {
      if (isNullableType(type))
        error(
            'E308',
            'A nullable value is used where a non-null value is required',
            node);
      return typed;
    }
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
    final existing = _lookupNonCore(name);
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
    if (_lookupNonCore(name) != null) {
      fail('Binding would shadow $name; use shadow in an inner scope', owner);
    }
    final raw = expression(value);
    if (!isNullableType(raw) && raw != 'Null') {
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
        final enumType = nonNullableType(type);
        final enumDecl = _typeSymbol(_genericHead(enumType))?.classDeclaration;
        if (enumDecl != null && enumDecl.kind == 'enum' && !pattern.shadow) {
          final enumCase =
              enumDecl.cases.where((c) => c.name == pattern.name).firstOrNull;
          if (enumCase != null) {
            model.references[pattern] = model.declarations[enumCase] ??
                Symbol(enumCase.name, '$enumType.${enumCase.name}', enumType,
                    classDeclaration: enumDecl, classCase: enumCase);
            return;
          }
        }
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
        if (declaration != null) model.references[pattern] = declaration;
        final fields = declaration?.classCase?.fields ??
            declaration?.classDeclaration?.fields ??
            const <FieldDeclaration>[];
        for (var i = 0; i < pattern.fields.length; i++) {
          final explicitName =
              i < pattern.names.length ? pattern.names[i] : null;
          FieldDeclaration? matchedField;
          if (explicitName != null) {
            matchedField =
                fields.where((f) => f.name == explicitName).firstOrNull;
          } else if (i < fields.length) {
            matchedField = fields[i];
          }
          final fieldType = matchedField?.type ?? type;
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

  bool _sameType(String from, String to) {
    from = _resolveType(from);
    to = _resolveType(to);
    if (from == to) return true;
    final source = _typeSymbol(from)?.classDeclaration;
    final target = _typeSymbol(to)?.classDeclaration;
    if (source != null && identical(source, target)) return true;
    if (isNullableType(from) && isNullableType(to))
      return _sameType(unwrap(from), unwrap(to));
    final left = _genericHead(from);
    final right = _genericHead(to);
    if ((left == right ||
            (_typeSymbol(left)?.classDeclaration != null &&
                identical(_typeSymbol(left)?.classDeclaration,
                    _typeSymbol(right)?.classDeclaration))) &&
        left != from &&
        right != to &&
        from.endsWith('>') &&
        to.endsWith('>')) {
      final a = _splitTypes(from.substring(left.length + 1, from.length - 1));
      final b = _splitTypes(to.substring(right.length + 1, to.length - 1));
      return a.length == b.length &&
          List.generate(a.length, (index) => _sameType(a[index], b[index]))
              .every((value) => value);
    }
    return false;
  }

  bool compatible(String from, String to) {
    from = _resolveType(from);
    to = _resolveType(to);
    if (from == to || from == '*') return true;
    if ((to == 'dynamic' || to == 'Object' || to == 'Object?') &&
        from.startsWith('readonly ') &&
        !_readonlyBoundarySafe(from)) return false;
    if (to == 'dynamic') return true;
    if (to == 'Object?' && from != 'void') return true;
    final variable = unwrap(from);
    if (_typeNames.contains(variable) &&
        !to.contains(' | ') &&
        !to.contains(' & ') &&
        !to.startsWith('readonly ')) {
      if (isNullableType(from) && !isNullableType(to)) return false;
      final pair = (from, to);
      if (!_checkingBounds.add(pair)) return false;
      try {
        final bound = _typeBounds[variable] ?? 'Object?';
        if (isNullableType(to)) {
          if (variable == unwrap(to)) return true;
          return compatible(unwrap(bound), unwrap(to));
        }
        return compatible(bound, to);
      } finally {
        _checkingBounds.remove(pair);
      }
    }
    if (from.startsWith('readonly ') && !to.startsWith('readonly '))
      return false;
    final fromClass = _typeSymbol(from)?.classDeclaration;
    final toClass = _typeSymbol(to)?.classDeclaration;
    if (fromClass != null && identical(fromClass, toClass)) return true;
    if (from == 'dynamic' && to != 'void') return true;
    if (to == 'Object' &&
        from != 'void' &&
        from != 'Null' &&
        !isNullableType(from)) return true;
    if (to.contains(' & ')) {
      return to.split(' & ').every((part) => compatible(from, part.trim()));
    }
    if (from.contains(' & ')) {
      return from.split(' & ').any((part) => compatible(part.trim(), to));
    }
    if (to.startsWith('FutureOr<') && to.endsWith('>')) {
      final inner = to.substring(9, to.length - 1);
      return compatible(from, inner) || compatible(from, 'Future<$inner>');
    }
    if (_implementsType(from, to)) return true;
    if (to.startsWith('readonly ')) {
      final source = from.startsWith('readonly ') ? from.substring(9) : from;
      return compatible(source, to.substring(9));
    }
    if (from.startsWith('readonly ')) return false;
    final fromHead = _genericHead(from);
    final toHead = _genericHead(to);
    final sourceOwner = _typeSymbol(fromHead)?.classDeclaration;
    final targetOwner = _typeSymbol(toHead)?.classDeclaration;
    if (sourceOwner != null &&
        identical(sourceOwner, targetOwner) &&
        from.endsWith('>') &&
        to.endsWith('>')) {
      final sourceArgs =
          splitTypeList(from.substring(fromHead.length + 1, from.length - 1));
      final targetArgs =
          splitTypeList(to.substring(toHead.length + 1, to.length - 1));
      return sourceArgs.length == targetArgs.length &&
          List.generate(sourceArgs.length,
              (i) => _sameType(sourceArgs[i], targetArgs[i])).every((v) => v);
    }
    if ((fromHead == toHead ||
            toHead == 'Iterable' && const {'List', 'Set'}.contains(fromHead)) &&
        const {'List', 'Set', 'Iterable', 'Map', 'Future', 'Stream'}
            .contains(fromHead) &&
        from.endsWith('>') &&
        to.endsWith('>')) {
      final source =
          _splitTypes(from.substring(fromHead.length + 1, from.length - 1));
      final target =
          _splitTypes(to.substring(toHead.length + 1, to.length - 1));
      if (source.length == target.length) {
        return List.generate(
                source.length,
                (index) => toHead == 'Iterable'
                    ? compatible(source[index], target[index])
                    : _sameType(source[index], target[index]))
            .every((value) => value);
      }
    }
    if (directUnionType(from)) {
      return from.split(' | ').every((arm) => compatible(arm.trim(), to));
    }
    if (directUnionType(to)) {
      return to.split(' | ').any((arm) => compatible(from, arm.trim()));
    }
    if (isNullableType(to)) {
      return from == 'Null' || compatible(unwrap(from), unwrap(to));
    }
    if (isNullableType(from) || from == 'Null') return false;
    if (functionTypeParts(from) != null || functionTypeParts(to) != null) {
      if (functionTypeParts(from) != null && functionTypeParts(to) != null) {
        final (fromParams, fromReturn) = _functionParts(from);
        final (toParams, toReturn) = _functionParts(to);
        return functionParametersCompatible(fromParams, toParams, compatible) &&
            (toReturn == 'void' || compatible(fromReturn, toReturn));
      }
      return false;
    }
    final native = _nativeShape(from);
    if (native != null &&
        !from.startsWith('readonly ') &&
        !isNullableType(from)) {
      if (native.instantiatedSupertypes.any((parent) => compatible(parent, to)))
        return true;
      if (!to.contains('<') && native.supertypes.contains(to)) return true;
      final element = native.listElement;
      for (final prefix in ['List<', 'Iterable<']) {
        if (element != null &&
            to.startsWith(prefix) &&
            to.endsWith('>') &&
            _sameType(element, to.substring(prefix.length, to.length - 1)))
          return true;
      }
    }
    if (to == 'num' && (from == 'int' || from == 'double')) return true;

    return false;
  }

  bool _implementsType(String from, String to,
      [Set<String> visited = const {}]) {
    if (isNullableType(from) ||
        isNullableType(to) ||
        visited.contains(_genericHead(from))) return false;
    final declaration = _typeSymbol(_genericHead(from))?.classDeclaration;
    if (declaration == null) return false;
    final substitution = _genericSubstitution(from, declaration);
    for (final edge in [
      if (declaration.superclass != null) declaration.superclass!,
      ...declaration.interfaces
    ]) {
      final parent =
          _substitute(_classMemberType(edge, declaration), substitution);
      if (_sameType(parent, to) ||
          (_nativeShape(parent) != null && compatible(parent, to)) ||
          _implementsType(parent, to, {...visited, _genericHead(from)}))
        return true;
    }
    return false;
  }

  void _checkInterface(
      ClassDeclaration implementation, String type, Set<String> visited) {
    final head = _genericHead(type);
    if (!visited.add(head))
      error('E700', 'Cyclic interface inheritance', implementation);
    validateType(type, implementation, allowVoid: false);
    final face = _typeSymbol(head)?.classDeclaration;
    if (face == null || face.kind != 'interface')
      error('E700', 'implements expects an interface', implementation);
    final substitution = _genericSubstitution(type, face);
    void requireMember(String name, String expected, {bool getter = true}) {
      if (getter) {
        final field =
            _fieldsOf(implementation).where((f) => f.name == name).lastOrNull;
        final property = _propertiesOf(implementation)
            .where((p) => p.name == name)
            .lastOrNull;
        if (field == null &&
            (property == null ||
                property.getter == null && property.getterBody == null)) {
          error('E700', 'interface getter $name is not implemented',
              implementation);
        }
      }
      final field =
          _fieldsOf(implementation).where((f) => f.name == name).lastOrNull;
      if (field?.isStatic == true)
        error('E700', 'interface member $name is static', implementation);
      final actual = memberType(implementation.name, name);
      if (actual == null ||
          !compatible(actual,
              _substitute(_classMemberType(expected, face), substitution))) {
        error('E700', 'interface member $name is not implemented',
            implementation);
      }
    }

    for (final field in face.fields) {
      requireMember(field.name, field.type);
    }
    for (final property in face.properties) {
      requireMember(property.name, property.type,
          getter: property.getter != null || property.getterBody != null);
      if (property.setterBody != null) {
        final field = _fieldsOf(implementation)
            .where((f) => f.name == property.name)
            .firstOrNull;
        final actual = _propertiesOf(implementation)
            .where((p) => p.name == property.name)
            .firstOrNull;
        if ((field?.mutable != true && actual?.setterBody == null) ||
            !_sameType(memberType(implementation.name, property.name)!,
                _substitute(property.type, substitution))) {
          error('E700', 'interface setter ${property.name} is not implemented',
              implementation);
        }
      }
    }
    for (final method in face.methods) {
      final candidates = method.isOperator
          ? [
              if (_method(implementation, method.name) case final actual?)
                actual
            ]
          : _methods(implementation, method.name);
      final matched = candidates.where((candidate) {
        final owner = _methodReceiver(implementation.name, candidate);
        return owner != null &&
            _methodContractCompatible(
                candidate,
                owner.$2,
                _genericSubstitution(owner.$1, owner.$2),
                method,
                face,
                substitution);
      });
      if (matched.isEmpty) {
        error('E700', 'interface method ${method.name} is not implemented',
            implementation);
      }
    }
    if (face.superclass != null) {
      _checkInterface(
          implementation,
          _substitute(_classMemberType(face.superclass!, face), substitution),
          visited);
    }
  }

  String _qualifiedMethodType(
      String type, ClassDeclaration? owner, FunctionDeclaration method) {
    if (owner == null) return type;
    final home = model.libraryOf[owner];
    if (home == null || home.isEmpty || home == _activeLibrary) return type;
    _libraryScope(home);
    return _libraryType(type, home, shadows: {
      ...owner.typeParameters.map((p) => p.name),
      ...method.typeParameters.map((p) => p.name)
    });
  }

  bool _methodContractCompatible(
      FunctionDeclaration actual,
      ClassDeclaration actualOwner,
      Map<String, String> actualClass,
      FunctionDeclaration expected,
      ClassDeclaration expectedOwner,
      Map<String, String> expectedClass,
      {bool ignoreReturn = false}) {
    if (actual.typeParameters.length != expected.typeParameters.length ||
        actual.isStatic != expected.isStatic ||
        isReadonlyMethod(expected) && !isReadonlyMethod(actual) ||
        actual.parameters.length != expected.parameters.length) return false;
    final actualMap = {...actualClass};
    final expectedMap = {...expectedClass};
    final bounds = <String, String>{};
    for (var i = 0; i < actual.typeParameters.length; i++) {
      var name = '_QMethodType$i';
      while (_scope.lookup(name) != null ||
          model.aliases.containsKey(name) ||
          _typeNames.contains(name) ||
          bounds.containsKey(name)) {
        name += '_';
      }
      actualMap[actual.typeParameters[i].name] = name;
      expectedMap[expected.typeParameters[i].name] = name;
      bounds[name] = 'Object?';
    }
    String normalize(String type, ClassDeclaration owner,
            FunctionDeclaration method, Map<String, String> map) =>
        _substitute(_qualifiedMethodType(type, owner, method), map);
    for (var i = 0; i < actual.typeParameters.length; i++) {
      final left = normalize(actual.typeParameters[i].bound ?? 'Object?',
          actualOwner, actual, actualMap);
      final right = normalize(expected.typeParameters[i].bound ?? 'Object?',
          expectedOwner, expected, expectedMap);
      if (!_sameType(left, right)) return false;
      bounds[actualMap[actual.typeParameters[i].name]!] = right;
    }
    for (var i = 0; i < actual.parameters.length; i++) {
      if (!_parameterKindFits(expected.parameters[i], actual.parameters[i]) ||
          expected.parameters[i].isNamed &&
              actual.parameters[i].name != expected.parameters[i].name ||
          actual.parameters[i].variadic != expected.parameters[i].variadic ||
          expected.parameters[i].defaultValue != null &&
              actual.parameters[i].defaultValue == null) return false;
    }
    String signature(FunctionDeclaration method) => ignoreReturn
        ? _callableSignature(method.parameters,
            method.parameters.map((p) => p.type).toList(), 'void')
        : functionType(method);
    return _contractTypeCompatible(
        normalize(signature(actual), actualOwner, actual, actualMap),
        normalize(signature(expected), expectedOwner, expected, expectedMap),
        bounds);
  }

  bool _contractTypeCompatible(
      String from, String to, Map<String, String> bounds,
      [Set<String> visited = const {}]) {
    if (from == to || to == 'dynamic' || to == 'Object?' && from != 'void')
      return true;
    final key = '$from -> $to';
    if (visited.contains(key)) return false;
    final next = {...visited, key};
    if (isNullableType(to)) {
      if (from == 'Null') return true;
      var source = unwrap(from);
      if (source == unwrap(to)) return true;
      if (bounds[source] case final bound?) source = unwrap(bound);
      return _contractTypeCompatible(source, unwrap(to), bounds, next);
    }
    if (isNullableType(from) || from == 'Null') return false;
    if (bounds[from] case final bound?)
      return _contractTypeCompatible(bound, to, bounds, next);
    if (bounds.containsKey(to)) return false;
    final left = functionTypeParts(from);
    final right = functionTypeParts(to);
    if (left != null && right != null) {
      if (!functionParametersCompatible(left.$1, right.$1,
          (a, b) => _contractTypeCompatible(a, b, bounds, next))) return false;
      return right.$2 == 'void' ||
          _contractTypeCompatible(left.$2, right.$2, bounds, next);
    }
    return compatible(from, to);
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
        if (isNullableType(current)) {
          visit(current.substring(0, current.length - 1), polarity);
          return;
        }
        if (current.contains(' & ') || current.contains(' | ')) {
          for (final part in current.split(RegExp(' [&|] '))) {
            visit(part, polarity);
          }
          return;
        }
        if (functionTypeParts(current) != null) {
          final (parameters, returns) = _functionParts(current);
          for (final item in _splitTypes(parameters)) {
            visit(functionParameterType(item), -polarity);
          }
          visit(returns, polarity);
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
      if (note.name == 'Reflectable' ||
          note.name == 'macro' ||
          note.name == 'consumes') {
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
        _rejectConstantConversion(argument.value);
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
    if (isNullableType(type) || type.contains('->')) return null;
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
            kind: parameter.kind,
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

  String _substitute(String type, Map<String, String> substitution) =>
      substituteBridgeType(type, substitution);

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

  List<String> _splitTypes(String inner) => splitTypeList(inner);

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

  String unwrap(String type) => nonNullableType(type);
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
    if (!type.startsWith('(') ||
        !type.endsWith(')') ||
        functionTypeParts(type) != null) {
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
    if (isNullableType(type)) return false;
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
    if (!type.startsWith('(') ||
        !type.endsWith(')') ||
        functionTypeParts(type) != null) {
      return null;
    }
    final parts = _splitTypes(type.substring(1, type.length - 1));
    if (parts.length != 2 || parts.any((part) => part.contains(':'))) {
      return null;
    }
    return parts;
  }

  String? _sequenceElement(String type) {
    final native = _nativeShape(type)?.listElement;
    if (native != null) return native;
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
    final savedConsumed = Map<Symbol, SourceSpan>.from(_consumed);
    _promoted.clear();
    _scope = _Scope(saved);
    final parameterNames = <String>[];
    for (final parameter in node.parameters) {
      if (parameter.defaultValue case final value?) {
        restrictDefault(value, parameterNames.toSet(),
            node.parameters.map((item) => item.name).toSet());
        final savedDefaultExpected = _expected;
        _expected = model.declarations[parameter]!.type;
        final String actual;
        try {
          actual = expression(value);
        } finally {
          _expected = savedDefaultExpected;
        }
        if (!_acceptExpected(
            value, actual, model.declarations[parameter]!.type)) {
          error(
              'E200',
              'Default type $actual is incompatible with ${model.declarations[parameter]!.type}',
              value);
        }
      }
      _scope.symbols[parameter.name] = model.declarations[parameter]!;
      parameterNames.add(parameter.name);
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
    _consumed
      ..clear()
      ..addAll(savedConsumed);
    final parts = <String>[];
    final named = <String>[];
    for (final parameter in node.parameters) {
      final declared = model.declarations[parameter]!.type;
      if (parameter.kind == ParameterKind.requiredNamed) {
        named.add('${parameter.name}: $declared required');
      } else if (parameter.kind == ParameterKind.optionalPositional) {
        parts.add('[${parameter.name}: $declared]');
      } else if (parameter.defaultValue != null) {
        named.add('${parameter.name}: $declared = missing');
      } else if (parameter.name == '_') {
        parts.add(declared);
      } else {
        parts.add('${parameter.name}: $declared');
      }
    }
    return '(${[...parts, ...named].join(', ')}) -> $type';
  }

  String _parameterType(String declared) => functionParameterType(declared);

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
    if (method.isOperator) return;
    final candidates = _superclassMethods(type, method.name);
    if (candidates.isEmpty) return;
    for (final candidate in candidates) {
      final owner = _methodOwners[candidate];
      if (owner != null && model.declarations[candidate]?.type == '<infer>') {
        analyzeMethod(owner, candidate);
      }
    }
    if (_overrideMatch(type, method, candidates) == null) {
      error(
          'E300',
          'override method ${method.name} is incompatible with its superclass',
          method);
    }
  }

  List<FunctionDeclaration> _superclassMethods(
      ClassDeclaration type, String name) {
    final found = <FunctionDeclaration>[];
    void walk(String? raw, ClassDeclaration from) {
      if (raw == null) return;
      final declaration = _typeSymbol(_genericHead(_classMemberType(raw, from)))
          ?.classDeclaration;
      if (declaration == null) return;
      found.addAll([
        for (final method in declaration.methods)
          if (method.name == name && !method.isOperator) method
      ]);
      for (final mixin in declaration.mixins.reversed) {
        walk(mixin, declaration);
      }
      walk(declaration.superclass, declaration);
    }

    for (final mixin in type.mixins.reversed) {
      walk(mixin, type);
    }
    walk(type.superclass, type);
    return found;
  }

  String? _edgeTo(ClassDeclaration type, ClassDeclaration owner,
      [Set<ClassDeclaration>? seen]) {
    final visited = seen ?? <ClassDeclaration>{};
    if (!visited.add(type)) return null;
    String? step(String raw) {
      final declaration = _typeSymbol(_genericHead(_classMemberType(raw, type)))
          ?.classDeclaration;
      if (declaration == null) return null;
      if (identical(declaration, owner)) return raw;
      final nested = _edgeTo(declaration, owner, visited);
      if (nested == null) return null;
      return _substitute(nested, _genericSubstitution(raw, declaration));
    }

    for (final mixin in type.mixins.reversed) {
      final found = step(mixin);
      if (found != null) return found;
    }
    for (final face in type.interfaces) {
      final found = step(face);
      if (found != null) return found;
    }
    final parent = type.superclass;
    if (parent == null) return null;
    return step(parent);
  }

  FunctionDeclaration? _overrideMatch(ClassDeclaration type,
      FunctionDeclaration method, List<FunctionDeclaration> inherited,
      {bool ignoreReturn = false}) {
    for (final candidate in inherited) {
      final owner = _methodOwners[candidate];
      if (owner == null) continue;
      final edge = _edgeTo(type, owner);
      if (edge == null) continue;
      final receiver = _methodReceiver(_classMemberType(edge, type), candidate);
      if (receiver == null) continue;
      if (_methodContractCompatible(method, type, const {}, candidate,
          receiver.$2, _genericSubstitution(receiver.$1, receiver.$2),
          ignoreReturn: ignoreReturn &&
              (model.declarations[method]?.type == '<infer>' ||
                  model.declarations[candidate]?.type == '<infer>'))) {
        return candidate;
      }
    }
    return null;
  }

  (String, String) _functionParts(String type) =>
      functionTypeParts(unwrap(_resolveType(type)))!;

  void parameterType(Parameter parameter, String type) {
    final symbol = create(parameter.name, type, mutable: parameter.mutable);
    model.declarations[parameter] = symbol;
  }

  final _iterationContexts = <(Node, Symbol?)>[];

  T _withIteration<T>(Node owner, Symbol? item, T Function() body) {
    _iterationContexts.add((owner, item));
    try {
      return body();
    } finally {
      _iterationContexts.removeLast();
    }
  }

  String _iterationMember(MemberAccess node) {
    final context = _iterationContexts.reversed.where((entry) {
      final span = entry.$1.span;
      return span.file == node.span.file &&
          node.span.offset >= span.offset &&
          node.span.offset < span.offset + span.length;
    }).firstOrNull;
    if (context == null)
      error('E300', 'Loop context requires an enclosing loop body', node);
    if (!{'index', 'iteration', 'item', 'isFirst'}.contains(node.name)) {
      error('E300', 'Unknown loop context property: ${node.name}', node);
    }
    final Symbol symbol;
    if (node.name == 'item') {
      if (context.$2 == null)
        error('E300', 'This loop has no item; item requires for-in', node);
      symbol = context.$2!;
    } else {
      symbol = model.loopContextIndexes
          .putIfAbsent(context.$1, () => create(r'$loopIndex', 'int'));
    }
    final owner = context.$1;
    if (node.name != 'item' &&
        !(owner is RepeatStatement &&
            owner.condition != null &&
            node.span.offset >= owner.condition!.span.offset &&
            node.span.offset <
                owner.condition!.span.offset + owner.condition!.span.length)) {
      model.loopContextBodyIndexes.add(owner);
    }
    model.loopContextMembers[node] = (symbol, node.name);
    // A contextual property is always read-only, even when its item is mutable.
    model.references[node] = Symbol(node.name, symbol.dartName,
        node.name == 'isFirst' ? 'bool' : symbol.type);
    return node.name == 'isFirst' ? 'bool' : symbol.type;
  }

  String member(MemberAccess node) {
    if (node.object is Identifier && (node.object as Identifier).name == r'$') {
      return _iterationMember(node);
    }
    if (node.object is Identifier) {
      final owner = _scope.lookup((node.object as Identifier).name);
      if (owner != null && owner.namespace != null) {
        _touch(owner);
        model.references[node.object] = owner;
        model.types[node.object] =
            owner.type == 'prefix' ? 'prefix' : owner.type;
        if (node.name == 'loadLibrary') {
          if (!_deferredPrefix((node.object as Identifier).name))
            error('E300', 'loadLibrary requires a deferred import', node);
          final symbol = Symbol('loadLibrary', 'loadLibrary', 'Future<void>');
          model.references[node] = symbol;
          return '() -> Future<void>';
        }
        final found = owner.namespace![node.name];
        if (found == null) {
          if (owner.type == 'prefix' &&
              _blockedInternalByPrefix[owner.name]?.contains(node.name) ==
                  true) {
            error(
                'E209',
                'An internal name ${node.name} is used outside its package',
                node);
          }
          if (owner.nativeTop?.isType == true &&
              _nativeShape(owner.type)?.members.containsKey(node.name) ==
                  true) {
            fail('Instance member ${node.name} is used on the type', node);
          }
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
        final signature = _qudsFunctionValue(found, node) ??
            _nativeFunctionValue(found, node) ??
            found.type;
        if (signature.contains(' | ') &&
            node.object is Identifier &&
            !model.providerUnionFunctions.contains(found.function)) {
          model.unionExpressionPrefixes[node] =
              '${(node.object as Identifier).name}.';
        }
        return signature;
      }
    }
    final raw = expression(node.object);
    final nested = model.references[node.object]?.namespace?[node.name];
    final owner = model.references[node.object];
    if (nested != null && owner?.type != 'prefix') {
      if (owner != null) _touch(owner);
      model.references[node] = nested;
      return _qudsFunctionValue(nested, node) ??
          _nativeFunctionValue(nested, node) ??
          nested.type;
    }
    final type = raw.startsWith('readonly ') ? raw.substring(9) : raw;
    final nullableExtension = isNullableType(type) &&
        !node.nullAware &&
        _extensions(type, node.name).isNotEmpty;
    if (isNullableType(type) && !node.nullAware && !nullableExtension) {
      error('E308',
          'A nullable value is used where a non-null value is required', node);
    }
    final base = unwrap(type);
    final eventPayload = _eventPayload(base);
    if (eventPayload != null) {
      if (node.name != 'add') fail('No member ${node.name} on an event', node);
      final shown = '($eventPayload) -> void';
      model.references[node] = Symbol('add', 'add', shown);
      return node.nullAware || isNullableType(type)
          ? nullableType(shown)
          : shown;
    }
    if (node.name == 'length' &&
        (base == 'String' ||
            base.startsWith('List<') ||
            base.startsWith('Set<') ||
            base.startsWith('Map<'))) {
      final lengthType =
          node.nullAware || isNullableType(type) ? 'int?' : 'int';
      return _readonlyView(raw, lengthType);
    }
    if (base == 'dynamic') return _readonlyView(raw, 'dynamic');
    final look = nullableExtension ? type : (_typeBounds[base] ?? base);
    if (look.contains(' & ')) {
      for (final part in look.split(' & ')) {
        final found = memberType(part.trim(), node.name);
        if (found == null) continue;
        model.references[node] =
            Symbol(node.name, _dartMember(part.trim(), node.name), found);
        final foundType = node.nullAware || isNullableType(type)
            ? nullableType(found)
            : found;
        return _readonlyView(raw, foundType);
      }
    }
    final declaration = _typeSymbol(_genericHead(look))?.classDeclaration;
    if (node.name == 'instance' &&
        declaration != null &&
        declaration.modifiers.contains('singleton')) {
      return declaration.name;
    }
    final onType = _isTypeReference(node.object);
    if (declaration != null && declaration.kind == 'enum') {
      if (onType) {
        if (node.name == 'values') {
          model.references[node] = Symbol('values', 'values', 'List<$look>');
          return 'List<$look>';
        }
        final matched =
            declaration.cases.where((item) => item.name == node.name).toList();
        if (matched.isNotEmpty) {
          final item = matched.single;
          model.references[node] = Symbol(item.name, item.name, look,
              classDeclaration: declaration, classCase: item);
          return look;
        }
      } else {
        if (node.name == 'name') {
          model.references[node] = Symbol('name', 'name', 'String');
          return node.nullAware || isNullableType(type) ? 'String?' : 'String';
        }
        if (node.name == 'index') {
          model.references[node] = Symbol('index', 'index', 'int');
          return node.nullAware || isNullableType(type) ? 'int?' : 'int';
        }
      }
    }
    if (declaration != null) {
      final field =
          _fieldsOf(declaration).where((item) => item.name == node.name);
      final namedMethods = field.isNotEmpty
          ? const <FunctionDeclaration>[]
          : _methods(declaration, node.name);
      final matching =
          namedMethods.where((method) => method.isStatic == onType).toList();
      if ((field.isNotEmpty || namedMethods.isNotEmpty) &&
          (field.isNotEmpty
              ? field.first.isStatic != onType
              : matching.isEmpty)) {
        final isStatic = field.isNotEmpty
            ? field.first.isStatic
            : namedMethods.first.isStatic;
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
      final substituted = _selfType(found, declaration, look);
      final classOwns = declaration != null &&
          (_method(declaration, node.name) != null ||
              _fieldsOf(declaration).any((item) => item.name == node.name));
      final extensions = classOwns
          ? const <FunctionDeclaration>[]
          : _extensions(look, node.name);
      final accessedMethods = declaration == null
          ? const <FunctionDeclaration>[]
          : _methods(declaration, node.name)
              .where((method) => method.isStatic == onType)
              .toList();
      final accessedMethod = accessedMethods.length > 1
          ? _selectMethodValue(node, accessedMethods)
          : (accessedMethods.length == 1 ? accessedMethods.single : null);
      final accessedExtension =
          extensions.length == 1 ? extensions.single : null;
      final readMethod = accessedMethod ?? accessedExtension;
      if (raw.startsWith('readonly ') &&
          readMethod != null &&
          !isReadonlyMethod(readMethod)) {
        error('E307', 'A readonly reference cannot expose a mutating method',
            node);
      }
      if (accessedMethod != null && declaration != null) {
        final methodValue =
            _qudsMethodValue(node, raw, look, declaration, accessedMethod);
        if (methodValue != null) return methodValue;
      }
      if (accessedExtension != null &&
          (accessedExtension.typeParameters.isNotEmpty ||
              _valueNeedsLowering(accessedExtension) ||
              identical(node, _nativeInstantiationTarget))) {
        final extensionValue =
            _qudsExtensionValue(node, raw, look, accessedExtension);
        if (extensionValue != null) return extensionValue;
      }
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
      final foundType = node.nullAware || isNullableType(type)
          ? nullableType(substituted)
          : substituted;
      return _readonlyView(raw, foundType);
    }
    final numberGetter = _numberGetter(base, node.name);
    if (numberGetter != null) {
      model.references[node] = Symbol(node.name, node.name, numberGetter);
      final foundType = node.nullAware || isNullableType(type)
          ? nullableType(numberGetter)
          : numberGetter;
      return _readonlyView(raw, foundType);
    }
    final builtin = _collectionGetter(base, node.name);
    if (builtin != null) {
      model.references[node] = Symbol(node.name, node.name, builtin);
      final foundType = node.nullAware || isNullableType(type)
          ? nullableType(builtin)
          : builtin;
      return _readonlyView(raw, foundType);
    }
    final sdk = _sdkMember(base, node.name);
    if (sdk != null && model.references[node.object]?.nativeTop?.isType == true)
      fail('Instance member ${node.name} is used on the type', node);
    if (sdk != null && !sdk.getter) {
      if (raw.startsWith('readonly ')) {
        error(
            'E307',
            'A readonly reference cannot expose an unchecked native method',
            node);
      }
      final symbol = _dartMemberSymbol(sdk, sdk.type);
      model.references[node] = symbol;
      final value = _nativeFunctionValue(symbol, node)!;
      return node.nullAware ? nullableType(value) : value;
    }
    if (sdk != null && sdk.getter) {
      model.references[node] = _dartMemberSymbol(sdk, sdk.type);
      final dartGetter = sdk.type;
      final foundType = node.nullAware || isNullableType(type)
          ? nullableType(dartGetter)
          : dartGetter;
      return _readonlyView(raw, foundType);
    }
    if (node.name == 'hashCode' && type != 'void') {
      model.references[node] = Symbol('hashCode', 'hashCode', 'int');
      return node.nullAware ? 'int?' : 'int';
    }
    fail(
        _hinted('No member ${node.name} on $type', node.name,
            _memberCandidates(type)),
        node);
  }

  String? _qudsMethodValue(Expression node, String raw, String receiverType,
      ClassDeclaration declaration, FunctionDeclaration method) {
    final explicit = identical(node, _nativeInstantiationTarget)
        ? _nativeInstantiationArguments
        : null;
    final owner = _methodReceiver(receiverType, method);
    if (owner == null || !owner.$2.methods.contains(method))
      error('E910', 'This method value needs unambiguous owner metadata', node);
    final ownerDeclaration = owner.$2;
    if (method.isStatic && ownerDeclaration != declaration)
      model.staticValueOwners[node] = _genericHead(owner.$1);
    final classArguments = {
      ..._genericSubstitution(owner.$1, ownerDeclaration)
    }..removeWhere((key, _) => method.typeParameters.any((p) => p.name == key));
    final declared = model.declarations[method]!;
    if (declared.type == '<infer>' && !_checking.contains(method))
      analyzeMethod(ownerDeclaration, method);
    if (declared.type == '<infer>')
      error('E302', 'A method value needs an inferred or declared result type',
          node);
    String specialize(String type) => _selfType(
        _substitute(_qualifiedMethodType(type, ownerDeclaration, method),
            classArguments),
        declaration,
        receiverType);
    final parameterTypes = [
      for (final p in method.parameters) specialize(p.type)
    ];
    final returned = specialize(declared.type);
    final bounds = {
      for (final p in method.typeParameters)
        if (p.bound != null) p.name: specialize(p.bound!)
    };
    final expected =
        _expected == null ? null : nonNullableType(_resolveType(_expected!));
    final contextual = expected != null && functionTypeParts(expected) != null;
    List<String> arguments;
    if (explicit != null) {
      arguments = explicit;
    } else if (method.typeParameters.isEmpty) {
      arguments = const [];
    } else {
      if (!contextual)
        error(
            'E302',
            'A generic method value needs type arguments or a function context',
            node);
      arguments = _inferNativeFunctionValue(
          Symbol(method.name, declared.dartName, returned), node, [
        for (var i = 0; i < method.parameters.length; i++)
          (
            method.parameters[i].name,
            method.parameters[i].variadic
                ? '...${parameterTypes[i]}'
                : parameterTypes[i]
          )
      ], {
        for (final parameter in method.parameters)
          if (parameter.isNamed) parameter.name
      }, {
        for (final parameter in method.parameters)
          if (parameter.isNamed) parameter.name
      }, {
        for (final p in method.typeParameters)
          p.name: bounds[p.name] ?? 'Object?'
      });
    }
    final substitution = _checkTypeArguments(
        method.name, method.typeParameters, arguments, node,
        bounds: bounds);
    final result = _substitute(returned, substitution);
    final specialized = [
      for (final type in parameterTypes) _substitute(type, substitution)
    ];
    final viewed = _readonlyView(raw, result);
    if (viewed != result) model.qudsValueResultGuards[node] = viewed;
    final exposed = viewed;
    final signature =
        _callableSignature(method.parameters, specialized, exposed);
    if (contextual && !compatible(signature, expected))
      fail('Method value $signature is incompatible with $expected', node);
    model.references[node] = Symbol(method.name, declared.dartName, exposed,
            library: declared.library, documentation: method.documentation)
        .withFunction(method);
    model.validatedQudsFunctionValues.add(node);
    _rememberValueLowering(node, method, arguments, specialized,
        staticOwner: model.staticValueOwners[node]);
    if (explicit == null && arguments.isNotEmpty)
      model.contextualFunctionArguments[node] = arguments;
    if (method.parameters.any((p) => p.defaultValue != null) &&
        !_checking.contains(method)) analyzeMethod(ownerDeclaration, method);
    return node is MemberAccess && node.nullAware
        ? nullableType(signature)
        : signature;
  }

  String? _qudsExtensionValue(MemberAccess node, String raw,
      String receiverType, FunctionDeclaration method) {
    final explicit = identical(node, _nativeInstantiationTarget)
        ? _nativeInstantiationArguments
        : null;
    ExtensionDeclaration? extension;
    for (final item in model.extensions) {
      if (item.methods.contains(method)) extension = item;
    }
    if (extension != null &&
        method.parameters.any((parameter) => parameter.defaultValue != null) &&
        !_checking.contains(method)) analyzeExtension(extension, method);
    final declared = model.declarations[method]!;
    if (declared.type == '<infer>')
      error('E302', 'A method value needs an inferred or declared result type',
          node);
    final classArguments = _extensionSubstitution(receiverType, method);
    String specialize(String type) => _substitute(type, classArguments);
    final parameterTypes = [
      for (final parameter in method.parameters) specialize(parameter.type)
    ];
    final returned = specialize(declared.type);
    final bounds = {
      for (final parameter in method.typeParameters)
        if (parameter.bound != null)
          parameter.name: specialize(parameter.bound!)
    };
    final expected =
        _expected == null ? null : nonNullableType(_resolveType(_expected!));
    final contextual = expected != null && functionTypeParts(expected) != null;
    List<String> arguments;
    if (explicit != null) {
      arguments = explicit;
    } else if (method.typeParameters.isEmpty) {
      arguments = const [];
    } else {
      if (!contextual)
        error(
            'E302',
            'A generic method value needs type arguments or a function context',
            node);
      arguments = _inferNativeFunctionValue(
          Symbol(method.name, declared.dartName, returned), node, [
        for (var i = 0; i < method.parameters.length; i++)
          (
            method.parameters[i].name,
            method.parameters[i].variadic
                ? '...${parameterTypes[i]}'
                : parameterTypes[i]
          )
      ], {
        for (final parameter in method.parameters)
          if (parameter.isNamed) parameter.name
      }, {
        for (final parameter in method.parameters)
          if (parameter.isNamed) parameter.name
      }, {
        for (final parameter in method.typeParameters)
          parameter.name: bounds[parameter.name] ?? 'Object?'
      });
    }
    final substitution = _checkTypeArguments(
        method.name, method.typeParameters, arguments, node,
        bounds: bounds);
    final actualResult = _substitute(returned, substitution);
    final result = _readonlyView(raw, actualResult);
    if (result != actualResult) model.qudsValueResultGuards[node] = result;
    final specialized = [
      for (final type in parameterTypes) _substitute(type, substitution)
    ];
    final signature =
        _callableSignature(method.parameters, specialized, result);
    if (contextual && !compatible(signature, expected))
      fail('Method value $signature is incompatible with $expected', node);
    if (raw.startsWith('readonly ') && !isReadonlyMethod(method))
      error(
          'E307', 'A readonly reference cannot expose a mutating method', node);
    model.references[node] = Symbol(method.name, declared.dartName, result,
            library: declared.library, documentation: method.documentation)
        .withFunction(method);
    model.validatedQudsFunctionValues.add(node);
    _rememberValueLowering(node, method, arguments, specialized);
    if (explicit == null && arguments.isNotEmpty)
      model.contextualFunctionArguments[node] = arguments;
    return node.nullAware ? nullableType(signature) : signature;
  }

  bool _isTypeReference(Expression node) {
    if (node is! Identifier && node is! MemberAccess) return false;
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

  String _classMemberType(String type, ClassDeclaration owner) {
    final home = model.libraryOf[owner];
    if (home == null || home.isEmpty || home == _activeLibrary) return type;
    _libraryScope(home);
    return _libraryType(type, home,
        shadows: owner.typeParameters.map((item) => item.name).toSet());
  }

  String? memberType(String type, String name,
      [Set<String> visited = const {}, bool inheritedNative = false]) {
    if (type == 'ConversionError' && name == 'message') return 'String';
    final head = _genericHead(type);
    if (visited.contains(head)) return null;
    final nextVisited = {...visited, head};
    final declaration = _typeSymbol(_genericHead(type))?.classDeclaration;
    if (declaration != null) {
      final substitution = _genericSubstitution(type, declaration);
      String instantiate(String raw) =>
          _substitute(_classMemberType(raw, declaration), substitution);
      for (final field in declaration.fields) {
        if (field.name == name)
          return instantiate(model.declarations[field]?.type ?? field.type);
      }
      for (final property in declaration.properties) {
        if (property.name == name) return instantiate(property.type);
      }
      for (final method in declaration.methods) {
        if (method.name == name) return instantiate(functionType(method));
      }
      for (final mixin in declaration.mixins.reversed) {
        final inherited =
            memberType(instantiate(mixin), name, nextVisited, true);
        if (inherited != null) return inherited;
      }
      if (declaration.superclass != null) {
        final inherited = memberType(
            instantiate(declaration.superclass!), name, nextVisited, true);
        if (inherited != null) return inherited;
      }
    }
    final native = inheritedNative ? _nativeShape(type)?.members[name] : null;
    if (native != null) {
      if (native.getter) return native.type;
      return '(${native.parameters.map((p) => p.$2).join(', ')}) -> ${native.type}';
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
    final visited = <ClassDeclaration>{type};
    var name = type.superclass;
    while (name != null) {
      final parent = _typeSymbol(_genericHead(name))?.classDeclaration;
      if (parent == null || !visited.add(parent)) break;
      inherited.insertAll(0, parent.properties);
      name = parent.superclass;
    }
    return [...inherited, ...type.properties];
  }

  String _dartMember(String type, String name) {
    final declaration = _typeSymbol(_genericHead(type))?.classDeclaration;
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

  List<FieldDeclaration> _fieldsOf(ClassDeclaration type,
      [Set<ClassDeclaration> visited = const {}]) {
    final cached = model.classFields[type];
    if (cached != null) return cached;
    if (visited.contains(type)) error('E700', 'Cyclic class inheritance', type);
    final inherited = <FieldDeclaration>[];
    final edge = type.superclass;
    if (edge != null) {
      final parent = _typeSymbol(_genericHead(_classMemberType(edge, type)))
          ?.classDeclaration;
      if (parent != null) {
        final substitution = _genericSubstitution(edge, parent);
        for (final field in _fieldsOf(parent, {...visited, type})) {
          inherited.add(FieldDeclaration(
              field.name,
              _substitute(_classMemberType(field.type, parent), substitution),
              field.mutable,
              field.requiredField,
              field.initializer,
              field.span,
              visibility: field.visibility,
              isStatic: field.isStatic,
              isConst: field.isConst,
              isEvent: field.isEvent,
              lazyBody: field.lazyBody));
        }
      }
    }
    return model.classFields[type] = [...inherited, ...type.fields];
  }

  FunctionDeclaration? _method(ClassDeclaration type, String name,
      {int? arity, Set<ClassDeclaration> visited = const {}}) {
    if (arity != null) {
      if (visited.contains(type)) return null;
      final nextVisited = {...visited, type};
      for (final method in type.methods) {
        if (method.name == name && method.parameters.length == arity) {
          return method;
        }
      }
      for (final mixin in type.mixins.reversed) {
        final declaration =
            _typeSymbol(_genericHead(_classMemberType(mixin, type)))
                ?.classDeclaration;
        if (declaration == null) continue;
        final found =
            _method(declaration, name, arity: arity, visited: nextVisited);
        if (found != null) return found;
      }
      final parent = type.superclass == null
          ? null
          : _typeSymbol(_genericHead(_classMemberType(type.superclass!, type)))
              ?.classDeclaration;
      if (parent != null) {
        return _method(parent, name, arity: arity, visited: nextVisited);
      }
      return null;
    }
    return _methods(type, name, visited: visited).firstOrNull;
  }

  ({String method, bool awaitCleanup})? _resolveUsingCleanup(
    String rawType, {
    required bool asyncUsing,
    Set<String>? visited,
  }) {
    var type = rawType.trim();
    if (type.startsWith('readonly ')) type = type.substring(9).trim();
    if (type.endsWith('?')) return null;
    type = unwrap(type);
    final seen = visited ?? <String>{};
    if (type.endsWith('?') || !seen.add(type)) return null;
    final head = _genericHead(type);
    if (_typeBounds.containsKey(head)) {
      return _resolveUsingCleanup(_typeBounds[head]!,
          asyncUsing: asyncUsing, visited: seen);
    }
    final symbol = _typeSymbol(head);
    final declaration = symbol?.classDeclaration;
    if (declaration != null) {
      final found = _findQudsCleanup(declaration);
      if (found != null) {
        final canAwait = asyncUsing &&
            (found.isAsync ||
                (found.returnType != null &&
                    _isAwaitableType(found.returnType!)));
        return (method: found.name, awaitCleanup: canAwait);
      }
    }
    final shape = symbol?.nativeClass ?? model.dartShapes[head];
    if (shape != null) {
      final found = _findDartCleanup(shape);
      if (found != null) {
        final canAwait = asyncUsing && _isAwaitableType(found.member.type);
        return (method: found.name, awaitCleanup: canAwait);
      }
    }
    return null;
  }

  FunctionDeclaration? _findQudsCleanup(ClassDeclaration type) {
    for (final name in const ['dispose', 'close']) {
      final found = _findQudsZeroArgMethod(type, name, <ClassDeclaration>{});
      if (found != null) return found;
    }
    return null;
  }

  FunctionDeclaration? _findQudsZeroArgMethod(
    ClassDeclaration type,
    String name,
    Set<ClassDeclaration> visited,
  ) {
    if (!visited.add(type)) return null;
    for (final method in type.methods) {
      if (method.name == name &&
          !method.isOperator &&
          method.parameters.isEmpty) {
        return method;
      }
    }
    for (final mixin in type.mixins.reversed) {
      final decl = _typeSymbol(_genericHead(_classMemberType(mixin, type)))
          ?.classDeclaration;
      if (decl != null) {
        final found = _findQudsZeroArgMethod(decl, name, visited);
        if (found != null) return found;
      }
    }
    if (type.superclass != null) {
      final parent =
          _typeSymbol(_genericHead(_classMemberType(type.superclass!, type)))
              ?.classDeclaration;
      if (parent != null) {
        final found = _findQudsZeroArgMethod(parent, name, visited);
        if (found != null) return found;
      }
    }
    for (final iface in type.interfaces) {
      final decl = _typeSymbol(_genericHead(_classMemberType(iface, type)))
          ?.classDeclaration;
      if (decl != null) {
        final found = _findQudsZeroArgMethod(decl, name, visited);
        if (found != null) return found;
      }
    }
    return null;
  }

  ({String name, DartMember member})? _findDartCleanup(DartShape shape) {
    for (final name in const ['dispose', 'close']) {
      final found = _findDartZeroArgMember(shape, name, <String>{});
      if (found != null) return (name: name, member: found);
    }
    return null;
  }

  DartMember? _findDartZeroArgMember(
    DartShape shape,
    String name,
    Set<String> visited,
  ) {
    final key = shape.name.isEmpty ? '${identityHashCode(shape)}' : shape.name;
    if (!visited.add(key)) return null;
    final direct = shape.members[name];
    if (direct != null && _dartCallableWithZeroArgs(direct)) {
      return direct;
    }
    for (final supertype in shape.supertypes) {
      final superHead = _genericHead(supertype);
      final superShape =
          model.dartShapes[superHead] ?? _typeSymbol(superHead)?.nativeClass;
      if (superShape != null) {
        final found = _findDartZeroArgMember(superShape, name, visited);
        if (found != null) return found;
      }
    }
    return null;
  }

  bool _dartCallableWithZeroArgs(DartMember member) {
    if (member.getter) return false;
    final positional = member.parameters
        .where((p) => !member.namedParameters.contains(p.$1))
        .length;
    final requiredNamed = member.namedParameters
        .where((n) => !member.optionalNames.contains(n))
        .length;
    return (positional - member.optional) <= 0 && requiredNamed == 0;
  }

  bool _isAwaitableType(String raw) {
    final type = raw.trim();
    return type == 'Future' ||
        type.startsWith('Future<') ||
        type == 'FutureOr' ||
        type.startsWith('FutureOr<') ||
        type == 'dynamic';
  }

  /// Visible methods of [name], with a same-signature child replacing a parent.
  List<FunctionDeclaration> _methods(ClassDeclaration type, String name,
      {Set<ClassDeclaration> visited = const {}}) {
    if (visited.contains(type)) return const [];
    final nextVisited = {...visited, type};
    final own = [
      for (final method in type.methods)
        if (method.name == name && !method.isOperator) method
    ];
    final inherited = <FunctionDeclaration>[];
    for (final mixin in type.mixins.reversed) {
      final declaration =
          _typeSymbol(_genericHead(_classMemberType(mixin, type)))
              ?.classDeclaration;
      if (declaration == null) continue;
      inherited.addAll(_methods(declaration, name, visited: nextVisited));
    }
    for (final face in type.interfaces) {
      final declaration =
          _typeSymbol(_genericHead(_classMemberType(face, type)))
              ?.classDeclaration;
      if (declaration == null) continue;
      inherited.addAll(_methods(declaration, name, visited: nextVisited));
    }
    final parent = type.superclass == null
        ? null
        : _typeSymbol(_genericHead(_classMemberType(type.superclass!, type)))
            ?.classDeclaration;
    if (parent != null) {
      inherited.addAll(_methods(parent, name, visited: nextVisited));
    }
    final visible = <FunctionDeclaration>[];
    for (final method in inherited) {
      if (own.any((item) =>
          sameSignature(item, method) ||
          _overrideMatch(type, item, [method]) != null)) {
        continue;
      }
      visible.removeWhere((item) =>
          _methodOwners[item]?.kind == 'interface' &&
          _overrideMatch(type, method, [item]) != null);
      if (visible.any((item) => sameSignature(item, method))) continue;
      visible.add(method);
    }
    visible.addAll(own);
    return visible;
  }

  void _assignAllMethodOverloadNames() {
    final pending = model.classes.values.toList();
    final done = <ClassDeclaration>{};
    void visit(ClassDeclaration type) {
      if (!done.add(type)) return;
      final parent = type.superclass == null
          ? null
          : _typeSymbol(_genericHead(type.superclass!))?.classDeclaration;
      if (parent != null) visit(parent);
      for (final face in type.interfaces) {
        final declaration = _typeSymbol(_genericHead(face))?.classDeclaration;
        if (declaration != null) visit(declaration);
      }
      for (final mixin in type.mixins) {
        final declaration = _typeSymbol(_genericHead(mixin))?.classDeclaration;
        if (declaration != null) visit(declaration);
      }
      _assignMethodOverloadNames(type);
    }

    for (final type in pending) {
      visit(type);
    }
  }

  List<FunctionDeclaration> _ancestorMethods(ClassDeclaration type, String name,
      [Set<ClassDeclaration>? visited]) {
    final seen = visited ?? <ClassDeclaration>{};
    if (!seen.add(type)) return const [];
    final found = <FunctionDeclaration>[];
    void walk(String raw) {
      final declaration = _typeSymbol(_genericHead(_classMemberType(raw, type)))
          ?.classDeclaration;
      if (declaration == null) return;
      found.addAll([
        for (final method in declaration.methods)
          if (method.name == name && !method.isOperator) method
      ]);
      found.addAll(_ancestorMethods(declaration, name, seen));
    }

    for (final mixin in type.mixins.reversed) {
      walk(mixin);
    }
    for (final face in type.interfaces) {
      walk(face);
    }
    final parent = type.superclass;
    if (parent != null) walk(parent);
    return found;
  }

  void _assignMethodOverloadNames(ClassDeclaration type) {
    final groups = <String, List<FunctionDeclaration>>{};
    for (final method in type.methods) {
      if (method.isOperator) continue;
      groups.putIfAbsent(method.name, () => []).add(method);
    }
    for (final entry in groups.entries) {
      final own = entry.value;
      for (var i = 0; i < own.length; i++) {
        for (var j = i + 1; j < own.length; j++) {
          if (sameSignature(own[i], own[j])) {
            fail('Duplicate function or unsupported overload: ${entry.key}',
                own[j]);
          }
        }
      }
      final inherited = _ancestorMethods(type, entry.key);
      final taken = <String>{
        for (final method in inherited) model.declarations[method]!.dartName,
      };
      final fresh = <FunctionDeclaration>[];
      for (final method in own) {
        // Backend names depend on parameter contracts. Resolve/check inferred
        // results after names are stable, so body references keep those names.
        final match =
            _overrideMatch(type, method, inherited, ignoreReturn: true);
        if (match != null) {
          final name = model.declarations[match]!.dartName;
          _setMethodDartName(method, name);
          taken.add(name);
          continue;
        }
        if (_superclassMethods(type, entry.key).isNotEmpty) {
          error(
              'E300',
              'override method ${method.name} is incompatible with its superclass',
              method);
        }
        fresh.add(method);
      }
      if (fresh.isEmpty) continue;
      if (fresh.length == 1 && own.length == 1 && inherited.isEmpty) continue;
      for (final method in fresh) {
        final base =
            method.visibility == 'private' && !method.name.startsWith('_')
                ? '_${method.name}'
                : method.name;
        if (fresh.length == 1 && own.length == 1 && !taken.contains(base)) {
          continue;
        }
        var index = 1;
        while (taken.contains('$base\$$index')) {
          index++;
        }
        final name = '$base\$$index';
        taken.add(name);
        _setMethodDartName(method, name);
      }
    }
  }

  void _setMethodDartName(FunctionDeclaration method, String dartName) {
    final previous = model.declarations[method]!;
    if (previous.dartName == dartName) return;
    model.declarations[method] = Symbol(method.name, dartName, previous.type,
            function: method,
            library: previous.library,
            documentation: previous.documentation)
        .withFunction(method);
  }

  List<Parameter> _substitutedParameters(
          FunctionDeclaration method, Map<String, String> substitution) =>
      [
        for (final parameter in method.parameters)
          Parameter(parameter.name, _substitute(parameter.type, substitution),
              parameter.mutable, parameter.span,
              kind: parameter.kind,
              defaultValue: parameter.defaultValue,
              variadic: parameter.variadic,
              initializing: parameter.initializing)
      ];

  FunctionDeclaration _selectOverload(
      CallExpression node, List<FunctionDeclaration> candidates, String name,
      {Map<String, String> Function(FunctionDeclaration method)?
          substitutionFor}) {
    List<Parameter> parametersOf(FunctionDeclaration method) {
      final substitution = substitutionFor?.call(method) ?? const {};
      return substitution.isEmpty
          ? method.parameters
          : _substitutedParameters(method, substitution);
    }

    FunctionDeclaration? selected;
    for (final candidate in candidates) {
      if (!argumentsMatch(node, parametersOf(candidate),
          commit: false, function: candidate)) {
        continue;
      }
      final selectedVariadic =
          selected != null && selected.parameters.any((p) => p.variadic);
      final candidateVariadic =
          candidate.parameters.any((parameter) => parameter.variadic);
      if (selected != null && selectedVariadic == candidateVariadic) {
        fail('Ambiguous overload: $name', node);
      }
      if (selected == null || (selectedVariadic && !candidateVariadic)) {
        selected = candidate;
      }
    }
    if (selected == null) {
      for (final candidate in candidates) {
        if (!argumentsMatch(node, parametersOf(candidate),
            commit: false, allowConversions: true, function: candidate)) {
          continue;
        }
        if (selected != null) fail('Ambiguous overload: $name', node);
        selected = candidate;
      }
    }
    if (selected == null) fail('No overload matches this call', node);
    return selected;
  }

  FunctionDeclaration _selectMethodValue(
      Expression node, List<FunctionDeclaration> methods) {
    final expected =
        _expected == null ? null : nonNullableType(_resolveType(_expected!));
    if (expected == null || functionTypeParts(expected) == null) {
      error('E311', 'An overload value needs one expected function signature',
          node);
    }
    final matches = <FunctionDeclaration>[];
    for (final method in methods) {
      final owner = _methodOwners[method];
      final declared = model.declarations[method];
      if (declared != null &&
          declared.type == '<infer>' &&
          owner != null &&
          !_checking.contains(method)) {
        analyzeMethod(owner, method);
      }
      final returned =
          model.declarations[method]?.type ?? method.returnType ?? 'void';
      final signature = _callableSignature(
          method.parameters,
          [for (final parameter in method.parameters) parameter.type],
          returned);
      if (compatible(signature, expected)) matches.add(method);
    }
    if (matches.length != 1) {
      error('E311', 'The function context does not select exactly one overload',
          node);
    }
    return matches.single;
  }

  Map<String, String> _methodClassSubstitution(String objectType,
      FunctionDeclaration method, ClassDeclaration fallback) {
    final owner = _methodReceiver(objectType, method);
    final ownerDeclaration = owner?.$2 ?? fallback;
    return {..._genericSubstitution(owner?.$1 ?? objectType, ownerDeclaration)}
      ..removeWhere((key, _) =>
          method.typeParameters.any((parameter) => parameter.name == key));
  }

  (String, ClassDeclaration)? _methodReceiver(
      String type, FunctionDeclaration method,
      [Set<String> visited = const {}]) {
    final head = _genericHead(type);
    if (visited.contains(head)) return null;
    final declaration = _typeSymbol(head)?.classDeclaration;
    if (declaration == null) return null;
    if (declaration.methods.contains(method)) return (type, declaration);
    final substitution = _genericSubstitution(type, declaration);
    for (final edge in [
      ...declaration.mixins.reversed,
      if (declaration.superclass != null) declaration.superclass!
    ]) {
      final found = _methodReceiver(
          _substitute(_classMemberType(edge, declaration), substitution),
          method,
          {...visited, head});
      if (found != null) return found;
    }
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
    if (isNullableType(raw)) {
      error('E308',
          'A nullable value is used where a non-null value is required', node);
    }
    final type = unwrap(raw.startsWith('readonly ') ? raw.substring(9) : raw);
    final indexType = expression(node.index);
    final listElement = _listElement(type);
    if (listElement != null) {
      if (!compatible(indexType, 'int'))
        fail('List index must be int', node.index);
      return _readonlyView(raw, listElement);
    }
    if (type.startsWith('Map<')) {
      final inner = type.substring(4, type.length - 1);
      final parts = _splitTypes(inner);
      final key = parts[0];
      final value = parts[1];
      if (!compatible(indexType, key) &&
          !(indexType.startsWith('readonly ') &&
              compatible(indexType, 'readonly $key')))
        fail('Map key type is $key', node.index);
      final lookup = nullableType(value);
      return _readonlyView(raw, lookup);
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
    if (isNullableType(raw)) {
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
    final native = _nativeShape(type);
    if (native?.listElement != null)
      return native!.members['sublist']?.type ?? 'List<${native.listElement}>';
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
    final context = _expected;
    final wanted =
        context != null && context.startsWith('Map<') && context.endsWith('>')
            ? _splitTypes(context.substring(4, context.length - 1))
            : null;
    String infer(Expression expressionNode, String? expected) {
      final saved = _expected;
      _expected = expected;
      try {
        return expression(expressionNode);
      } finally {
        _expected = saved;
      }
    }

    String? key;
    String? value;
    void unify(String nextKey, String nextValue, Node at) {
      if (wanted != null && wanted.length == 2) {
        if (compatible(nextKey, wanted[0])) nextKey = wanted[0];
        if (compatible(nextValue, wanted[1])) nextValue = wanted[1];
      }
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
          if (!isNullableType(spread)) {
            fail('...? requires a nullable map', entry);
          }
          spread = unwrap(spread);
        }
        if (!spread.startsWith('Map<') || !spread.endsWith('>')) {
          fail('A map spread requires a map', entry);
        }
        final inner = spread.substring(4, spread.length - 1);
        final pair = _splitTypes(inner);
        unify(pair[0], pair[1], entry);
      } else if (entry is MapComprehension) {
        final shaped = mapControl(entry);
        unify(shaped.$1, shaped.$2, entry);
      } else {
        unify(infer(entry, wanted?[0]), infer(node.values[i], wanted?[1]),
            node.values[i]);
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
      if (_lookupNonCore(node.name!) != null) {
        fail('Loop binding would shadow ${node.name}', node);
      }
      final symbol = create(node.name!, element);
      model.declarations[node] = symbol;
      final saved = _scope;
      _scope = _Scope(saved);
      _scope.symbols[node.name!] = symbol;
      final shaped =
          _withIteration(node, symbol, () => mapLiteral(node.thenMap));
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
      if (!isNullableType(type)) {
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
    final raw = expression(node.operand);
    final type = stripReadonlyType(raw);
    if (type.startsWith('Future<') && type.endsWith('>')) {
      return _readonlyView(raw, type.substring(7, type.length - 1));
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
      final current = _resolveType(_promoted[name] ?? symbol.type);
      if (!isNullableType(current)) return const {};
      final unequal = node.operator == '!=';
      if (unequal != whenTrue) return const {};
      return {name: unwrap(current)};
    }
    if (node is TypeTestExpression &&
        (node.operator == 'is' || node.operator == 'is!') &&
        node.operand is Identifier) {
      final isPositive = node.operator == 'is';
      if (isPositive != whenTrue) return const {};
      final name = (node.operand as Identifier).name;
      final symbol = _scope.lookup(name);
      if (symbol == null || symbol.field) return const {};
      return {name: _resolveType(node.type)};
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
    target = _resolveType(target);
    if (!isNullableType(target) && target != 'Null') {
      fail('??= requires a nullable binding', node);
    }
    final inner = unwrap(target);
    final expression = switch (node) {
      Binding() => node.value,
      MemberAssignment() => node.value,
      IndexAssignment() => node.value,
      AssignExpression() => node.value,
      _ => null,
    };
    if (!(expression == null
        ? compatible(value, inner)
        : _acceptExpected(expression, value, inner))) {
      fail('Cannot assign $value to $inner', node);
    }
  }

  void _afterAssignment(
      String name, String target, String value, String operator) {
    target = _resolveType(target);
    if ((operator == '=' || operator == '??=') &&
        isNullableType(target) &&
        !isNullableType(value) &&
        value != 'Null') {
      _promoted[name] = value;
      return;
    }
    _promoted.remove(name);
  }

  // Only these shapes have a runtime view that can cross an erased boundary.
  bool _readonlyBoundarySafe(String type) {
    type = stripReadonlyType(_resolveType(type));
    if (isNullableType(type)) return _readonlyBoundarySafe(unwrap(type));
    if (const {
      'int',
      'double',
      'num',
      'bool',
      'String',
      'Null',
      'Never',
      'BigInt',
      'DateTime',
      'Duration',
      'Uri',
      'RegExp',
      'Type',
      'Symbol'
    }.contains(type)) return true;
    if (_typedStorage(type)) return true;
    final declaration = readonlyClassFor(model, type);
    if (declaration != null)
      return declaration.kind == 'enum' ||
          supportsReadonlyClass(model, declaration);
    final head = _genericHead(type);
    if (head == type || !type.endsWith('>')) return false;
    final args = _splitTypes(type.substring(head.length + 1, type.length - 1));
    if (head == 'List' ||
        head == 'Iterable' ||
        head == 'Future' ||
        head == 'Stream')
      return args.length == 1 && _readonlyBoundarySafe(args[0]);
    if (head == 'Set')
      return args.length == 1 && _readonlyBoundarySafe(args[0]);
    if (head == 'Map')
      return args.length == 2 &&
          _readonlyBoundarySafe(args[0]) &&
          _readonlyBoundarySafe(args[1]);
    return false;
  }

  void _checkReadonlyEscape(String type, Node node) {
    if (type.startsWith('readonly ') && !_readonlyBoundarySafe(type)) {
      error(
          'E910',
          'This readonly shape has no runtime guard for an erased or Dart boundary',
          node);
    }
  }

  String _readonlyView(String receiver, String memberType) {
    if (!receiver.startsWith('readonly ') ||
        memberType.startsWith('readonly ')) {
      return memberType;
    }
    if (isNullableType(memberType)) {
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
        _global.symbols[_genericHead(memberType)]?.classDeclaration != null ||
        _typedStorage(memberType)) {
      return 'readonly $memberType';
    }
    return 'readonly $memberType';
  }

  String typeTest(TypeTestExpression node) {
    final value = expression(node.operand);
    if (value == 'void') fail('Void expressions cannot be operands', node);
    validateType(node.type, node, allowVoid: false);
    if (node.operator == 'as') return _readonlyView(value, node.type);
    return 'bool';
  }

  String binary(BinaryExpression node) {
    if (node.operator == 'and' || node.operator == 'or') {
      final left = expression(node.left);
      final facts = _promotions(node.left, whenTrue: node.operator == 'and');
      final right = _withPromoted(facts, () => expression(node.right));
      return binaryType(left, node.operator, right, node);
    }
    final clearExpected = const {
      '==',
      '!=',
      '<',
      '<=',
      '>',
      '>=',
      'in',
      'not in',
    }.contains(node.operator);
    final savedExpected = _expected;
    if (clearExpected) _expected = null;
    final String left, right;
    try {
      left = expression(node.left);
      right = expression(node.right);
    } finally {
      _expected = savedExpected;
    }
    try {
      return binaryType(left, node.operator, right, node);
    } on CompilerException catch (failure) {
      if (failure.code != 'E300' ||
          !const {
            '+',
            '-',
            '*',
            '/',
            '~/',
            '%',
            '<',
            '<=',
            '>',
            '>=',
            '&',
            '|',
            '^',
            '<<',
            '>>',
            '>>>'
          }.contains(node.operator)) rethrow;
      final options = <(Expression, ConversionPlan, String)>[];
      final owner = _typeSymbol(_genericHead(unwrap(left)))?.classDeclaration;
      final method =
          owner == null ? null : _method(owner, node.operator, arity: 1);
      final native = _sdkMember(left, node.operator);
      final expected =
          method != null && method.isOperator && method.parameters.length == 1
              ? _qualifyType(_genericHead(unwrap(left)),
                  method.parameters.single.type, owner!.name)
              : numeric(left)
                  ? 'num'
                  : native?.parameters.length == 1
                      ? native!.parameters.single.$2
                      : null;
      if (expected != null) {
        final plan = _customConversion(right, expected, node.right);
        if (plan != null) {
          try {
            options.add((
              node.right,
              plan,
              binaryType(left, node.operator, plan.resultType, node)
            ));
          } on CompilerException catch (e) {
            if (e.code != 'E300') rethrow;
          }
        }
      }
      final other = _typeSymbol(_genericHead(unwrap(right)))?.classDeclaration;
      final otherMethod =
          other == null ? null : _method(other, node.operator, arity: 1);
      if (numeric(right) || otherMethod?.isOperator == true) {
        final plan =
            _customConversion(left, numeric(right) ? 'num' : right, node.left);
        if (plan != null) {
          try {
            options.add((
              node.left,
              plan,
              binaryType(plan.resultType, node.operator, right, node)
            ));
          } on CompilerException catch (e) {
            if (e.code != 'E300') rethrow;
          }
        }
      }
      if (options.isEmpty) rethrow;
      if (options.length != 1)
        error('E310', 'Ambiguous implicit operator conversion', node);
      model.implicitConversions[options.single.$1] = options.single.$2;
      return options.single.$3;
    }
  }

  String binaryType(String left, String op, String right, Node node) {
    final bitwise = {'&', '|', '^', '<<', '>>', '>>>'}.contains(op);
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
    } else if (bitwise && left == 'int' && right == 'int') {
      return 'int';
    } else if ({'&', '|', '^'}.contains(op) &&
        left == 'bool' &&
        right == 'bool') {
      return 'bool';
    } else if (!bitwise && _numericOperand(left) && _numericOperand(right)) {
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
    if (isNullableType(left) && op != '??') {
      error('E308',
          'A nullable value is used where a non-null value is required', node);
    }
    final owner = _typeSymbol(_genericHead(unwrap(left)))?.classDeclaration;
    final method = owner == null ? null : _method(owner, op, arity: 1);
    if (owner != null && method != null && method.isOperator) {
      if (method.parameters.isNotEmpty) {
        final expected = _qualifyType(_genericHead(unwrap(left)),
            method.parameters.first.type, owner.name);
        if (expected != '<field>' && !compatible(right, expected)) {
          error(
              'E300', 'Operator $op is not defined for $left and $right', node);
        }
      }
      final returned =
          model.declarations[method]?.type ?? method.returnType ?? owner.name;
      return _qualifyType(_genericHead(unwrap(left)), returned, owner.name);
    }
    final native = _sdkMember(left, op);
    if (native != null &&
        !native.getter &&
        native.parameters.length == 1 &&
        compatible(right, native.parameters.single.$2)) {
      return native.type;
    }
    error('E300', 'Operator $op is not defined for $left and $right', node);
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
      DurationLiteral() => 'Duration',
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
    final resolved = _resolveType(type);
    model.types[node] = resolved;
    if (node is CallExpression) _markConsumedCall(node);
    return resolved;
  }

  void _markConsumedCall(CallExpression node) {
    final callee = node.callee is TypeApplication
        ? (node.callee as TypeApplication).callee
        : node.callee;
    if (callee is! MemberAccess || callee.object is! Identifier) return;
    final target = callee.object as Identifier;
    final symbol = model.references[target];
    if (symbol == null ||
        symbol.classDeclaration != null ||
        symbol.namespace != null ||
        symbol.function != null) {
      return;
    }
    final resolvedMethod = model.references[callee]?.function ??
        model.references[node.callee]?.function;
    final targetType = model.types[target];
    if ((resolvedMethod != null &&
            hasAnnotation(resolvedMethod.annotations, 'consumes')) ||
        (targetType != null && _isConsumingMethod(targetType, callee.name))) {
      final already = _consumed[symbol];
      if (already != null) {
        error(
            'E315',
            'Value ${symbol.name} was already consumed at line ${already.line}',
            node);
      }
      _consumed[symbol] = node.span;
    }
  }

  bool _isConsumingMethod(String rawType, String methodName,
      {Set<String>? visited}) {
    final seen = visited ?? <String>{};
    final unwrapped = unwrap(stripReadonlyType(rawType));
    final head = _genericHead(unwrapped);
    if (!seen.add(head)) return false;
    final bound = _typeBounds[head];
    if (bound != null && _isConsumingMethod(bound, methodName, visited: seen)) {
      return true;
    }
    final cls = _typeSymbol(head)?.classDeclaration;
    if (cls != null) {
      for (final method in cls.methods) {
        if (!method.isStatic &&
            method.name == methodName &&
            hasAnnotation(method.annotations, 'consumes')) {
          return true;
        }
      }
      if (cls.superclass != null &&
          _isConsumingMethod(cls.superclass!, methodName, visited: seen)) {
        return true;
      }
      for (final iface in cls.interfaces) {
        if (_isConsumingMethod(iface, methodName, visited: seen)) return true;
      }
      for (final mixin in cls.mixins) {
        if (_isConsumingMethod(mixin, methodName, visited: seen)) return true;
      }
    }
    for (final extension in model.extensions) {
      if (_extensionMatch(extension, unwrapped) == null &&
          _extensionMatch(extension, head) == null) {
        continue;
      }
      for (final extMethod in extension.methods) {
        if (extMethod.name == methodName &&
            hasAnnotation(extMethod.annotations, 'consumes')) {
          return true;
        }
      }
    }
    return false;
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
        if (!seen.add(entry.key) ||
            entry.value.function?.conversionKind.isNotEmpty == true) continue;
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
      final parent = _typeSymbol(_genericHead(superName))?.classDeclaration;
      if (parent != null) yield* _classMembers(parent, seen);
    }
  }

  String identifier(Identifier node) {
    if (node.name == r'$')
      error('E300', 'Use a loop context property such as \$.index', node);
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
        final current = _typeSymbol(_genericHead(_thisType!))?.classDeclaration;
        if (current != null) _checkMember(current, node.name, node);
        final methods = current == null
            ? const <FunctionDeclaration>[]
            : _methods(current, node.name)
                .where((method) => !method.isStatic)
                .toList();
        if (methods.length == 1 &&
            current != null &&
            (_valueNeedsLowering(methods.single) ||
                methods.single.typeParameters.isNotEmpty)) {
          model.implicitThis.add(node);
          final raw = _readonlyMethod ? 'readonly $_thisType' : _thisType!;
          return _qudsMethodValue(
              node, raw, _thisType!, current, methods.single)!;
        }
        if (methods.length > 1) {
          final selected = _selectMethodValue(node, methods);
          model.implicitThis.add(node);
          model.references[node] = model.declarations[selected]!;
          return _readonlyMethod
              ? _readonlyView('readonly this', functionType(selected))
              : functionType(selected);
        }
        model.implicitThis.add(node);
        model.references[node] =
            Symbol(node.name, _dartMember(_thisType!, node.name), member);
        return _readonlyMethod
            ? _readonlyView('readonly this', member)
            : member;
      }
    }
    if (symbol == null) {
      if (_blockedInternalNames.contains(node.name)) {
        error('E209',
            'An internal name ${node.name} is used outside its package', node);
      }
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
    if (symbol.namespace != null && symbol.type == 'prefix') {
      fail('A prefix is not a value', node);
    }
    if (symbol.field && _thisType != null) {
      final current = _typeSymbol(_genericHead(_thisType!))?.classDeclaration;
      if (current != null) _checkMember(current, node.name, node);
    }
    final consumedAt = _consumed[symbol];
    if (consumedAt != null) {
      error(
          'E315',
          'Value ${symbol.name} was already consumed at line ${consumedAt.line}',
          node);
    }
    final qudsValue = _qudsFunctionValue(symbol, node);
    if (qudsValue != null) return qudsValue;
    model.references[node] = symbol;
    _touch(symbol);
    if (symbol.function != null) return functionType(symbol.function!);
    final nativeValue = _nativeFunctionValue(symbol, node);
    if (nativeValue != null) return nativeValue;
    if (symbol.parameterTypes.isNotEmpty) {
      return '(${symbol.parameterTypes.join(', ')}) -> ${symbol.type}';
    }
    final visible = _promoted[symbol.name] ?? symbol.type;
    if (_readonlyMethod && symbol.field)
      return _readonlyView('readonly this', visible);
    return symbol.readonly ? 'readonly $visible' : visible;
  }

  String? _qudsFunctionValue(Symbol symbol, Expression node) {
    final candidates = symbol.overloads;
    if (candidates.isEmpty) return null;
    final explicit = identical(node, _nativeInstantiationTarget)
        ? _nativeInstantiationArguments
        : null;
    if (candidates.length == 1 &&
        candidates.single.typeParameters.isEmpty &&
        explicit == null &&
        symbol.library.isEmpty &&
        !_valueNeedsLowering(candidates.single)) return null;
    if (candidates.any(_methodOwners.containsKey))
      error(
          'E910',
          'These Quds function values need a method/default/variadic adapter',
          node);
    final expected =
        _expected == null ? null : nonNullableType(_resolveType(_expected!));
    final contextual = expected != null && functionTypeParts(expected) != null;
    if (candidates.length > 1 && explicit == null && !contextual)
      error('E311', 'An overload value needs one expected function signature',
          node);
    final matches = <(Symbol, String, List<String>, List<String>)>[];
    for (final candidate in candidates) {
      if (explicit != null &&
          candidate.typeParameters.length != explicit.length &&
          candidates.length > 1) continue;
      final home = (model.declarations[candidate] ?? symbol).library;
      if (home.isNotEmpty && home != _activeLibrary) _libraryScope(home);
      if (model.declarations[candidate]?.type == '<infer>')
        analyzeFunction(candidate);
      final declaration = model.declarations[candidate] ?? symbol;
      final binders = candidate.typeParameters.map((p) => p.name).toSet();
      String lexical(String type) => home.isEmpty || home == _activeLibrary
          ? type
          : _libraryType(type, home, shadows: binders);
      final returned = lexical(declaration.type);
      List<String> arguments;
      try {
        if (explicit != null) {
          arguments = explicit;
        } else if (candidate.typeParameters.isEmpty) {
          arguments = const [];
        } else {
          if (!contextual)
            error(
                'E302',
                'A generic Quds function value needs type arguments or a function context',
                node);
          arguments = _inferNativeFunctionValue(
              Symbol(candidate.name, declaration.dartName, returned), node, [
            for (final p in candidate.parameters)
              (p.name, p.variadic ? '...${lexical(p.type)}' : lexical(p.type))
          ], {
            for (final p in candidate.parameters)
              if (p.isNamed) p.name
          }, {
            for (final p in candidate.parameters)
              if (p.defaultValue != null) p.name
          }, {
            for (final p in candidate.typeParameters)
              p.name: lexical(p.bound ?? 'Object?')
          });
        }
        final substitution = _checkTypeArguments(
            candidate.name, candidate.typeParameters, arguments, node);
        final specialized = [
          for (final parameter in candidate.parameters)
            _substitute(lexical(parameter.type), substitution)
        ];
        final signature = _callableSignature(candidate.parameters, specialized,
            _substitute(returned, substitution));
        if (contextual && !compatible(signature, expected)) {
          if (candidates.length == 1)
            fail('Function value $signature is incompatible with $expected',
                node);
          continue;
        }
        final selected = Symbol(
                symbol.name,
                symbol.library.isEmpty
                    ? declaration.dartName
                    : model.declarations[candidate]?.dartName ??
                        symbol.dartName,
                returned,
                function: candidate,
                library: symbol.library,
                documentation: candidate.documentation)
            .withFunction(candidate);
        matches.add((selected, signature, arguments, specialized));
      } on CompilerException {
        if (candidates.length == 1) rethrow;
      }
    }
    if (matches.length != 1)
      error('E311', 'The function context does not select exactly one overload',
          node);
    final selected = matches.single;
    model.references[node] = selected.$1;
    model.validatedQudsFunctionValues.add(node);
    _touch(selected.$1);
    _rememberValueLowering(
        node, selected.$1.function!, selected.$3, selected.$4);
    if (selected.$1.function!.parameters.any((p) => p.defaultValue != null) &&
        !_checking.contains(selected.$1.function))
      analyzeFunction(selected.$1.function!);
    if (explicit == null && selected.$3.isNotEmpty)
      model.contextualFunctionArguments[node] = selected.$3;
    return selected.$2;
  }

  bool _valueNeedsLowering(FunctionDeclaration function) =>
      function.parameters.any((parameter) =>
          parameter.needsAdapter ||
          parameter.variadic ||
          parameter.type.contains(' & '));

  String _callableSignature(
      List<Parameter> parameters, List<String> types, String returned) {
    final parts = <String>[];
    final named = <String>[];
    for (var i = 0; i < parameters.length; i++) {
      final parameter = parameters[i];
      final type = types[i];
      if (parameter.variadic) {
        parts.add('...${parameter.name}: $type');
      } else if (parameter.kind == ParameterKind.requiredNamed) {
        named.add('${parameter.name}: $type required');
      } else if (parameter.kind == ParameterKind.optionalPositional) {
        parts.add('[${parameter.name}: $type]');
      } else if (parameter.defaultValue != null) {
        named.add('${parameter.name}: $type = missing');
      } else {
        parts.add('${parameter.name}: $type');
      }
    }
    return '(${[...parts, ...named].join(', ')}) -> $returned';
  }

  void _rememberValueLowering(Expression node, FunctionDeclaration function,
      List<String> typeArguments, List<String> parameterTypes,
      {String? staticOwner}) {
    _checkUnionBoundary(function, node);
    final adapt = model.providerUnionFunctions.contains(function) ||
        function.parameters.any((parameter) =>
            parameter.needsAdapter || parameter.type.contains(' & ')) ||
        model.qudsValueResultGuards.containsKey(node);
    if (!adapt) return;
    if (model.providerDefaultFunctions.contains(function)) {
      model.providerBridgeImports.add(function);
    }
    model.qudsValueLowerings[node] = QudsValueLowering(
        function, typeArguments, parameterTypes,
        staticOwner: staticOwner);
  }

  String? _nativeFunctionValue(Symbol symbol, Node node) {
    final top = symbol.nativeTop;
    final method = symbol.nativeMember;
    if (top != null && (!top.callable || top.isType)) return null;
    if (method != null && method.getter) return null;
    if (top == null && method == null) return null;
    final formals = top?.typeParameters ?? method!.typeParameters;
    final named = top?.namedParameters ?? method!.namedParameters;
    final optional = top?.optionalNames ?? method!.optionalNames;
    final parameters = top?.parameters ?? method!.parameters;
    var explicit = identical(node, _nativeInstantiationTarget)
        ? _nativeInstantiationArguments
        : null;
    if (symbol.type.contains('@unsupported.') ||
        parameters.any((p) => p.$2.contains('@unsupported.')))
      error('E910', 'This native function value needs additional conformance',
          node);
    final contextual = explicit == null &&
        formals.isNotEmpty &&
        _expected != null &&
        functionTypeParts(nonNullableType(_resolveType(_expected!))) != null;
    if (contextual) {
      explicit = _inferNativeFunctionValue(
          symbol, node, parameters, named, optional, formals);
    }
    if (formals.isNotEmpty && explicit == null) {
      error('E910', 'This native function value needs additional conformance',
          node);
    }
    final substitution = explicit == null
        ? <String, String>{}
        : _checkTypeArguments(
            symbol.name,
            [
              for (final p in formals.entries)
                TypeParameter(p.key, node.span, bound: p.value)
            ],
            explicit,
            node);
    final specialized = [
      for (final p in parameters) (p.$1, _substitute(p.$2, substitution))
    ];
    final type =
        '(${nativeFunctionParameters(specialized, named, optional)}) -> ${_substitute(symbol.type, substitution)}';
    if (contextual) {
      final expected = nonNullableType(_resolveType(_expected!));
      if (!compatible(type, expected))
        fail('Inferred function type $type is incompatible with $expected',
            node);
      model.contextualFunctionArguments[node as Expression] = explicit!;
    }
    return type;
  }

  List<String> _inferNativeFunctionValue(
      Symbol symbol,
      Node node,
      List<(String, String)> parameters,
      Set<String> named,
      Set<String> optional,
      Map<String, String> formals) {
    final expected =
        functionTypeParts(nonNullableType(_resolveType(_expected!)))!;
    final encoded = nativeFunctionParameters(parameters, named, optional);
    if (!functionParametersCompatible(
        encoded, expected.$1, (_source, _target) => true))
      fail(
          'Function parameter forms do not match the expected signature', node);
    final source = functionParameters(encoded);
    final target = functionParameters(expected.$1);
    final positions = source.where((p) => !p.named).toList();
    final labels = {for (final p in source.where((p) => p.named)) p.name: p};
    final fresh = <String, String>{};
    var freshIndex = 0;
    for (final name in formals.keys) {
      String key;
      do {
        key = '_QudsContext${freshIndex++}';
      } while (model.aliases.containsKey(key) ||
          _scope.lookup(key) != null ||
          formals.containsKey(key));
      fresh[name] = key;
    }
    final typeParameters = [
      for (final name in fresh.values) TypeParameter(name, node.span)
    ];
    final inferred = <String, String>{};
    var position = 0;
    void infer(String pattern, String actual, {bool fromReturn = false}) {
      pattern = _substitute(pattern, fresh);
      // Parameter positions supply lower constraints. A wider result context
      // must not widen an already inferred input type; it is checked afterward.
      if (fromReturn) pattern = _substitute(pattern, inferred);
      if (!fresh.values.any(
          (name) => RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(pattern)))
        return;
      if (!_inferGeneric(pattern, actual, inferred, typeParameters))
        fail('Conflicting contextual types for ${symbol.name}', node);
    }

    for (final parameter in target) {
      final original =
          parameter.named ? labels[parameter.name]! : positions[position++];
      infer(original.type, parameter.type);
    }
    if (expected.$2 != 'void')
      infer(symbol.type, expected.$2, fromReturn: true);
    if (fresh.values.any((name) => !inferred.containsKey(name)))
      error(
          'E302',
          'The expected signature does not determine every type argument',
          node);
    return [for (final name in formals.keys) inferred[fresh[name]]!];
  }

  String functionType(FunctionDeclaration function) {
    final returns =
        model.declarations[function]?.type ?? function.returnType ?? 'void';
    if (!function.parameters.any((p) => p.needsAdapter)) {
      return '(${function.parameters.map((p) => p.type).join(', ')}) -> $returns';
    }
    return _callableSignature(function.parameters,
        function.parameters.map((p) => p.type).toList(), returns);
  }

  String unary(UnaryExpression node) {
    final type = expression(node.operand);
    if (node.operator == '-' || node.operator == '~') {
      if (isNullableType(type)) {
        error(
            'E308',
            'A nullable value is used where a non-null value is required',
            node);
      }
      final owner = _typeSymbol(unwrap(type))?.classDeclaration;
      final method =
          owner == null ? null : _method(owner, node.operator, arity: 0);
      if (method != null && method.isOperator) {
        final returned = model.declarations[method]?.type ??
            method.returnType ??
            owner!.name;
        return _qualifyType(_genericHead(unwrap(type)), returned, owner!.name);
      }
      final native =
          _sdkMember(type, node.operator == '-' ? 'unary-' : node.operator);
      if (native != null && !native.getter && native.parameters.isEmpty) {
        return native.type;
      }
    }
    if (node.operator == '~') {
      if (type == 'int') return 'int';
      fail('Invalid unary operator ~ for $type', node);
    }
    if (node.operator == '!' && isNullableType(type)) return unwrap(type);
    if (node.operator == 'not' && type == 'bool') return 'bool';
    if (node.operator != 'not' && node.operator != '!' && numeric(type)) {
      return type;
    }
    fail('Invalid unary operator ${node.operator} for $type', node);
  }

  /// A Dart library type this file did not declare. Different ones can share a list.
  bool _externalNominal(String type) {
    if (type == 'dynamic') return true;
    if (isNullableType(type)) return _externalNominal(unwrap(type));
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
      error('E302', 'Empty lists require a contextual List<T> type', node);
    }
    final expected = _expected;
    final wanted = expected != null &&
            expected.startsWith('List<') &&
            expected.endsWith('>')
        ? expected.substring(5, expected.length - 1)
        : null;
    final elements = <String>[];
    for (var i = 0; i < node.elements.length; i++) {
      final saved = _expected;
      _expected = node.elements[i] is SpreadElement ? expected : wanted;
      try {
        elements.add(elementTypeOf(node.elements[i], aware(node.nullAware, i)));
      } finally {
        _expected = saved;
      }
    }
    if (wanted != null && elements.every((type) => compatible(type, wanted))) {
      return expected!;
    }
    var type = elements.first;
    for (var i = 1; i < elements.length; i++) {
      final next = elements[i];
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
    return isNullableType(type) ? unwrap(type) : type;
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
      if (spread.nullAware && !isNullableType(type)) return false;
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

  void _qualifyConstConstructor(CallExpression node, String type) {
    final constructor = model.constCalls[node];
    if (constructor != null && constructor.type != type) {
      model.constCalls[node] = ConstConstructor(type, constructor.parameters,
          requirements: constructor.requirements);
    }
  }

  /// A call whose target is a Dart library. Arguments stay in source order.
  String _passExternal(CallExpression node, Symbol symbol) {
    model.references[node.callee] = symbol;
    _touch(symbol);
    if (symbol.nativeTop != null || symbol.nativeMember != null)
      return _nativeCall(node, symbol);
    for (final argument in node.arguments) {
      _checkReadonlyEscape(expression(argument.value), argument);
    }
    if (symbol.type.isEmpty || symbol.type == 'dynamic') return 'dynamic';
    return symbol.type;
  }

  String _callPrefixed(CallExpression node, MemberAccess callee, Symbol owner) {
    _touch(owner);
    final id = callee.object as Identifier;
    model.references[id] = owner;
    model.types[id] = owner.type == 'prefix' ? 'prefix' : owner.type;
    if (callee.name == 'loadLibrary') {
      if (!_deferredPrefix(owner.name))
        error('E300', 'loadLibrary requires a deferred import', callee);
      if (node.arguments.isNotEmpty)
        fail('loadLibrary takes no arguments', node);
      model.references[callee] =
          Symbol('loadLibrary', 'loadLibrary', 'Future<void>');
      model.types[callee] = '() -> Future<void>';
      model.functionValueCalls.add(node);
      model.nativeArguments[node] = const [];
      model.argumentOrder[node] = const [];
      return 'Future<void>';
    }
    final found = owner.namespace![callee.name];
    if (found == null) {
      if (owner.type == 'prefix' &&
          _blockedInternalByPrefix[owner.name]?.contains(callee.name) == true) {
        error(
            'E209',
            'An internal name ${callee.name} is used outside its package',
            callee);
      }
      if (owner.nativeTop?.isType == true &&
          _nativeShape(owner.type)?.members.containsKey(callee.name) == true) {
        fail('Instance member ${callee.name} is used on the type', callee);
      }
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
    if (found.overloads.length > 1) {
      FunctionDeclaration? selected;
      var selectedVariadic = false;
      for (final candidate in found.overloads) {
        if (!argumentsMatch(node, candidate.parameters,
            commit: false, function: candidate)) continue;
        final variadic =
            candidate.parameters.any((parameter) => parameter.variadic);
        if (selected != null && selectedVariadic == variadic)
          fail('Ambiguous overload: ${callee.name}', node);
        if (selected == null || (selectedVariadic && !variadic)) {
          selected = candidate;
          selectedVariadic = variadic;
        }
      }
      if (selected == null) {
        for (final candidate in found.overloads) {
          final trial = _CheckedArguments();
          if (!argumentsMatch(node, candidate.parameters,
              commit: false,
              allowConversions: true,
              function: candidate,
              checked: trial)) continue;
          if (selected != null)
            fail('Ambiguous overload: ${callee.name}', node);
          selected = candidate;
        }
      }
      if (selected == null) fail('No overload matches this call', node);
      final symbol = model.declarations[selected]!;
      model.references[callee] = symbol;
      return applyArguments(node, selected.parameters, selected);
    }
    if (found.classDeclaration != null) {
      final declaration = found.classDeclaration!;
      final returned = constructClass(node, declaration);
      final qualified =
          _qualifyType(found.dartName, returned, declaration.name);
      _qualifyConstConstructor(node, qualified);
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
      final home = found.library;
      if (home.isNotEmpty) _libraryScope(home);
      final parameters = [
        for (final parameter in found.function!.parameters)
          Parameter(parameter.name, _libraryType(parameter.type, home),
              parameter.mutable, parameter.span,
              kind: parameter.kind,
              defaultValue: parameter.defaultValue,
              variadic: parameter.variadic,
              initializing: parameter.initializing)
      ];
      final type =
          _libraryType(applyArguments(node, parameters, found.function), home);
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

  String call(CallExpression node,
      {Expression? calleeOverride, List<String>? explicitMethodTypes}) {
    final callee = calleeOverride ?? node.callee;
    if (callee is TypeApplication) return callApplied(node, callee);
    if (callee is MemberAccess && callee.object is Identifier) {
      final owner = _scope.lookup((callee.object as Identifier).name);
      if (owner?.namespace != null) {
        return _callPrefixed(node, callee, owner!);
      }
      if (owner?.nativeTop?.isType == true &&
          _nativeShape(owner!.type)?.members.containsKey(callee.name) == true) {
        model.references[callee.object] = owner;
        fail('Instance member ${callee.name} is used on the type', callee);
      }
      final type = owner?.classDeclaration;
      final named = type?.constructors
          .where((constructor) => constructor.name == callee.name)
          .toList();
      if (type != null && named != null && named.isNotEmpty) {
        model.references[callee.object as Identifier] = owner!;
        model.types[callee.object] = owner.type;
        final home = model.libraryOf[type] ?? '';
        if (callee.name.startsWith('_') &&
            home.isNotEmpty &&
            home != _activeLibrary)
          error('E204', 'Private constructor is not accessible', callee);
        final returned = _finishConstruct(node, type,
            _ctorParameters(type, named.first), const [], named.first);
        final function = model.references[node.callee]?.function;
        model.references[callee] =
            Symbol(callee.name, callee.name, returned).withFunction(function);
        return returned;
      }
    }
    if (callee is MemberAccess && callee.object is TypeApplication) {
      final applied = callee.object as TypeApplication;
      Symbol? owner;
      if (applied.callee is Identifier) {
        owner = _scope.lookup((applied.callee as Identifier).name);
      } else if (applied.callee is MemberAccess &&
          (applied.callee as MemberAccess).object is Identifier) {
        final member = applied.callee as MemberAccess;
        final prefix = _scope.lookup((member.object as Identifier).name);
        if (prefix?.namespace != null) {
          model.references[member.object] = prefix!;
          model.types[member.object] = 'prefix';
          owner = prefix.namespace![member.name];
        }
      }
      if (owner != null && owner.nativeTop?.isType == true) {
        _touch(owner);
        model.references[applied.callee] = owner;
        model.references[applied] = owner;
        model.types[applied] = owner.type;
        final nested = owner.namespace?[callee.name];
        if (nested != null &&
            (nested.callable || nested.parameterTypes.isNotEmpty)) {
          model.references[callee] = nested;
          return _nativeCall(node, nested, explicitTypes: applied.arguments);
        }
        if (_nativeShape(owner.type)?.members.containsKey(callee.name) ==
            true) {
          fail('Instance member ${callee.name} is used on the type', callee);
        }
      }
      if (owner?.classDeclaration != null) {
        final type = owner!.classDeclaration!;
        final named = type.constructors
            .where((constructor) => constructor.name == callee.name)
            .toList();
        if (named.isNotEmpty) {
          _touch(owner);
          model.references[applied.callee] = owner;
          model.references[applied] = owner;
          model.types[applied] = owner.type;
          final home = model.libraryOf[type] ?? '';
          if (callee.name.startsWith('_') &&
              home.isNotEmpty &&
              home != _activeLibrary) {
            error('E204', 'Private constructor is not accessible', callee);
          }
          final returned = _finishConstruct(
              node,
              type,
              _ctorParameters(type, named.first),
              applied.arguments,
              named.first);
          final function = model.references[node.callee]?.function;
          final qualified = _qualifyType(owner.dartName, returned, type.name);
          model.references[callee] = Symbol(callee.name, callee.name, qualified)
              .withFunction(function);
          return qualified;
        }
      }
    }
    if (callee is MemberAccess) {
      final rawObject = expression(callee.object);
      final nested = model.references[callee.object]?.namespace?[callee.name];
      final owner = model.references[callee.object];
      final constructorOwner = owner?.classDeclaration;
      final namedConstructor = constructorOwner?.constructors
          .where((c) => c.name == callee.name)
          .firstOrNull;
      if (constructorOwner != null && namedConstructor != null) {
        final home = model.libraryOf[constructorOwner] ?? '';
        if (callee.name.startsWith('_') &&
            home.isNotEmpty &&
            home != _activeLibrary)
          error('E204', 'Private constructor is not accessible', callee);
        final returned = _finishConstruct(
            node,
            constructorOwner,
            _ctorParameters(constructorOwner, namedConstructor),
            const [],
            namedConstructor);
        final function = model.references[node.callee]?.function;
        final qualified =
            _qualifyType(owner!.dartName, returned, constructorOwner.name);
        model.references[callee] =
            Symbol(callee.name, callee.name, qualified).withFunction(function);
        return qualified;
      }
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
        final declaration = _typeSymbol(objectType)?.classDeclaration;
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
          return _readonlyView(rawObject, objectType);
        }
      }
      final objectTypeRaw = rawObject.startsWith('readonly ')
          ? rawObject.substring(9)
          : rawObject;
      final nullableExtension = isNullableType(objectTypeRaw) &&
          !callee.nullAware &&
          _extensions(objectTypeRaw, callee.name).isNotEmpty;
      if (isNullableType(objectTypeRaw) &&
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
      if (rawObject.startsWith('readonly ') && _typedStorage(objectType)) {
        final name = callee.name;
        final shape = _nativeShape(objectType)!;
        final safe = shape.listElement != null
            ? !_mutating.contains(name) &&
                !const {'setRange', 'setInt8', 'setUint8'}.contains(name)
            : name.startsWith('get') || name.startsWith('as');
        if (!safe)
          error('E307', 'A readonly reference cannot be mutated', callee);
      }

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
        if (rawObject.startsWith('readonly ') && callee.name != 'toString')
          error(
              'E307',
              'A readonly dynamic reference cannot call an unclassified method',
              callee);
        return _passExternal(
            node, Symbol(callee.name, callee.name, 'dynamic', external: true));
      }
      final declaration =
          _typeSymbol(_genericHead(objectType))?.classDeclaration;
      final onType = _isTypeReference(callee.object);
      final visible = declaration == null
          ? const <FunctionDeclaration>[]
          : _methods(declaration, callee.name);
      if (visible.isNotEmpty &&
          visible.every((method) => method.isStatic != onType)) {
        fail(
            visible.first.isStatic
                ? 'Static member ${callee.name} is used on an instance'
                : 'Instance member ${callee.name} is used on the type',
            callee);
      }
      final candidates =
          visible.where((method) => method.isStatic == onType).toList();
      final function = candidates.length > 1
          ? _selectOverload(node, candidates, callee.name,
              substitutionFor: (method) =>
                  _methodClassSubstitution(objectType, method, declaration!))
          : (candidates.isEmpty ? null : candidates.single);
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
        if (explicitMethodTypes != null) {
          final native = _dartCall(objectType, callee.name, node,
              explicitTypes: explicitMethodTypes);
          if (native != null) {
            if (rawObject.startsWith('readonly '))
              error(
                  'E307',
                  'A readonly reference cannot call an unclassified Dart method',
                  callee);
            return native;
          }
          error(
              'E910',
              'No supported generic native signature for ${callee.name}',
              callee);
        }
        if (_typedStorage(objectType) &&
            _sdkMember(objectType, callee.name) != null) {
          final result = _dartCall(objectType, callee.name, node);
          if (result != null) {
            return rawObject.startsWith('readonly ') &&
                    callee.name.startsWith('as')
                ? _readonlyView(rawObject, result)
                : result;
          }
        }
        final builtin = _collectionCall(objectType, callee.name, node,
            readonly: rawObject.startsWith('readonly '));
        if (builtin != null) return builtin;
        final number = _numberCall(objectType, callee.name, node);
        if (number != null) return number;
        if (rawObject.startsWith('readonly ') &&
            !_typedStorage(objectType) &&
            callee.name != 'toString') {
          error(
              'E307',
              'A readonly reference cannot call an unclassified Dart method',
              callee);
        }
        final dartCall = _dartCall(objectType, callee.name, node);
        if (dartCall != null) {
          if (rawObject.startsWith('readonly ') &&
              _typedStorage(objectType) &&
              (callee.name.startsWith('as') || callee.name == 'sublistView')) {
            return _readonlyView(rawObject, dartCall);
          }
          return dartCall;
        }
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
      if (rawObject.startsWith('readonly ') && !isReadonlyMethod(resolved)) {
        error('E307', 'A readonly reference may only call readonly methods',
            callee);
      }
      final functionResolved = resolved;
      model.references[callee] = model.declarations[functionResolved]!;
      _touch(model.references[callee]!);
      final methodOwner = _methodReceiver(objectType, functionResolved);
      final ownerDeclaration = methodOwner?.$2 ?? declaration;
      if (functionResolved.isStatic &&
          declaration != null &&
          ownerDeclaration != null &&
          ownerDeclaration != declaration)
        model.staticValueOwners[callee] = _genericHead(methodOwner!.$1);
      final classArguments = {
        ..._genericSubstitution(
            methodOwner?.$1 ?? objectType, ownerDeclaration),
        ..._extensionSubstitution(objectType, functionResolved)
      }..removeWhere((key, _) =>
          functionResolved.typeParameters.any((p) => p.name == key));
      if (model.declarations[functionResolved]!.type == '<infer>' &&
          ownerDeclaration != null &&
          !_checking.contains(functionResolved))
        analyzeMethod(ownerDeclaration, functionResolved);
      String specialize(String type) => _selfType(
          _substitute(
              _qualifiedMethodType(type, ownerDeclaration, functionResolved),
              classArguments),
          declaration,
          objectType);
      final methodBounds = {
        for (final parameter in functionResolved.typeParameters)
          if (parameter.bound != null)
            parameter.name: specialize(parameter.bound!)
      };
      final methodArguments = explicitMethodTypes == null
          ? const <String, String>{}
          : _checkTypeArguments(functionResolved.name,
              functionResolved.typeParameters, explicitMethodTypes, node,
              bounds: methodBounds);
      final parameters = [
        for (final parameter in functionResolved.parameters)
          Parameter(
              parameter.name,
              _substitute(specialize(parameter.type), methodArguments),
              parameter.mutable,
              parameter.span,
              kind: parameter.kind,
              defaultValue: parameter.defaultValue,
              variadic: parameter.variadic,
              initializing: parameter.initializing)
      ];
      model.references[node.callee] = model.references[callee]!;
      final result = applyArguments(node, parameters, functionResolved,
          typeArguments: methodArguments,
          defaultSubstitution: {...classArguments, ...methodArguments},
          parameterBounds: methodBounds,
          declaredReturnType:
              specialize(model.declarations[functionResolved]!.type));
      return callee.nullAware && result != 'void'
          ? nullableType(result)
          : result;
    }
    if (callee is! Identifier) {
      final type = expression(callee);
      final invoked = _callOnType(type);
      if (invoked != null) return _applyCallMethod(node, type, invoked);
      if (isNullableType(type)) {
        error(
            'E308',
            'A nullable value is used where a non-null value is required',
            callee);
      }
      if (functionTypeParts(type) == null)
        fail('Value is not callable', callee);
      return _functionValueCall(node, type);
    }
    final symbol = _scope.lookup(callee.name);
    if (symbol == null && _thisType != null) {
      final declaration = _global.symbols[_thisType!]?.classDeclaration;
      final candidates = declaration == null
          ? const <FunctionDeclaration>[]
          : _methods(declaration, callee.name)
              .where((method) => !method.isStatic)
              .toList();
      final method = candidates.length > 1
          ? _selectOverload(node, candidates, callee.name,
              substitutionFor: (item) =>
                  _methodClassSubstitution(_thisType!, item, declaration!))
          : (candidates.isEmpty ? null : candidates.single);
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
        if (_readonlyMethod && !isReadonlyMethod(resolved)) {
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
      if (_blockedInternalNames.contains(callee.name)) {
        error(
            'E209',
            'An internal name ${callee.name} is used outside its package',
            callee);
      }
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
    if (symbol.library == 'check' &&
        (symbol.name == 'expect' || symbol.name == 'expectLater')) {
      return _checkExpect(node, symbol);
    }
    if (symbol.library == 'check' && symbol.name == 'isA') {
      if (args.isNotEmpty) fail('isA expects no arguments', node);
      return 'dynamic';
    }
    if (symbol.library == 'check' && symbol.name == 'isSorted') {
      fail('isSorted expects one type argument', node);
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
        functionTypeParts(unwrap(_resolveType(symbol.type))) != null) {
      final callable = _resolveType(_promoted[symbol.name] ?? symbol.type);
      if (isNullableType(callable))
        error(
            'E308',
            'A nullable value is used where a non-null value is required',
            callee);
      return _functionValueCall(node, callable);
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
    // A single signature has no competing contextual inference. Reuse its
    // checked arguments instead of recursively analyzing the same tree again.
    final checked = candidates.length == 1 ? _CheckedArguments() : null;
    for (final candidate in candidates) {
      if (candidate.returnType == null &&
          model.declarations[candidate]?.type == '<infer>') {
        analyzeFunction(candidate);
      }
      if (argumentsMatch(node, candidate.parameters,
          commit: false, function: candidate, checked: checked)) {
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
    if (selected == null) {
      for (final candidate in candidates) {
        final trial = _CheckedArguments();
        if (!argumentsMatch(node, candidate.parameters,
            commit: false,
            allowConversions: true,
            function: candidate,
            checked: trial)) continue;
        if (selected != null) fail('Ambiguous overload: ${callee.name}', node);
        selected = candidate;
      }
      if (selected != null) {
        model.references[callee] = model.declarations[selected]!;
        return applyArguments(node, selected.parameters, selected);
      }
    }
    if (selected == null) fail('No overload matches this call', node);
    model.references[callee] = model.declarations[selected]!;
    return applyArguments(node, selected.parameters, selected,
        checked: checked);
  }

  String _checkExpect(CallExpression node, Symbol symbol) {
    final positional = <Argument>[];
    for (final argument in node.arguments) {
      final name = argument.name;
      if (name == null) {
        positional.add(argument);
        continue;
      }
      if (name == 'reason') {
        final type = expression(argument.value);
        if (!compatible(type, 'String')) {
          fail('reason must be a String', argument);
        }
        continue;
      }
      if (name == 'skip') {
        final type = expression(argument.value);
        if (type != 'bool' &&
            type != 'String' &&
            type != 'dynamic' &&
            type != 'Object' &&
            type != 'Object?') {
          fail('skip must be a bool or a String', argument);
        }
        continue;
      }
      fail('${symbol.name} has no parameter $name', argument);
    }
    if (positional.length != 2) {
      fail('${symbol.name} expects the value and the matcher', node);
    }
    for (final argument in positional) {
      if (expression(argument.value) == 'void') {
        fail('${symbol.name} cannot check a void expression', argument);
      }
    }
    return symbol.type;
  }

  String _functionValueCall(CallExpression node, String type) {
    final (text, returns) = _functionParts(type);
    final parameters = functionParameters(text);
    final variadicAt = parameters.indexWhere((p) => p.variadic);
    final order = List<int>.filled(parameters.length, -1);
    final positional = [
      for (var i = 0; i < parameters.length; i++)
        if (!parameters[i].named && !parameters[i].variadic) i
    ];
    final variadicArgs = <int>[];
    var position = 0;
    var sawNamed = false;
    for (var i = 0; i < node.arguments.length; i++) {
      final argument = node.arguments[i];
      if (argument.value is SpreadElement) {
        if (variadicAt < 0 || position < positional.length)
          fail('A spread belongs in the variadic argument', argument);
        final spread = argument.value as SpreadElement;
        final collection = expression(spread.operand);
        final element = _collectionElement(
            spread.nullAware ? unwrap(collection) : collection);
        if (element == null ||
            !compatible(element, parameters[variadicAt].type))
          fail(
              'Spread element is incompatible with ${parameters[variadicAt].type}',
              argument);
        variadicArgs.add(i);
        continue;
      }
      int target;
      if (argument.name == null) {
        if (sawNamed)
          fail('Positional arguments must precede named arguments', argument);
        if (position >= positional.length) {
          if (variadicAt < 0) fail('Too many positional arguments', argument);
          final saved = _expected;
          _expected = parameters[variadicAt].type;
          final actual = expression(argument.value);
          _expected = saved;
          if (!_acceptExpected(
              argument.value, actual, parameters[variadicAt].type))
            fail(
                'Argument type $actual is incompatible with ${parameters[variadicAt].type}',
                argument);
          variadicArgs.add(i);
          continue;
        }
        target = positional[position++];
      } else {
        sawNamed = true;
        target = parameters
            .indexWhere((p) => p.name == argument.name && !p.variadic);
        if (target < 0) fail('Unknown argument: ${argument.name}', argument);
      }
      if (order[target] >= 0) fail('Duplicate argument', argument);
      final expected = parameters[target].type;
      final saved = _expected;
      _expected = expected;
      final actual = expression(argument.value);
      _expected = saved;
      if (!_acceptExpected(argument.value, actual, expected))
        fail('Argument type $actual is incompatible with $expected', argument);
      _noteUnionWrap(
          argument.value, actual, expected, _calleeUnionPrefix(node.callee));
      order[target] = i;
    }
    var omitted = false;
    final layout = <(String?, int)>[];
    for (var i = 0; i < parameters.length; i++) {
      final p = parameters[i];
      if (p.variadic) continue;
      if (order[i] < 0) {
        if (!p.optional)
          fail('Missing required argument: ${p.name ?? i + 1}', node);
        if (!p.named) omitted = true;
        continue;
      }
      if (!p.named && omitted) {
        final callee = node.callee;
        final capable = callee is Identifier &&
            model.gapValues.contains(model.references[callee]);
        if (!capable) {
          error(
              'E910',
              'A later optional positional argument requires earlier values explicitly',
              node);
        } else {
          model.functionValueGapCalls.add(node);
        }
      }
      layout.add((p.named ? p.name : null, order[i]));
    }
    model.types[node.callee] = type;
    model.functionValueCalls.add(node);
    model.nativeArguments[node] = layout;
    model.argumentOrder[node] = order;
    if (variadicAt >= 0) {
      model.functionValueVariadicElements[node] = parameters[variadicAt].type;
      model.functionValueVariadicIndex[node] = variadicAt;
      model.variadicArguments[node] = variadicArgs;
    }
    if (packetSignature(parameters)) model.packetValueCalls.add(node);
    return returns;
  }

  String _nativeCall(CallExpression node, Symbol symbol,
      {List<String>? explicitTypes}) {
    final top = symbol.nativeTop;
    final member = symbol.nativeMember;
    if (top?.isType == true && !top!.callable)
      fail('Class ${symbol.name} has no accessible unnamed constructor', node);
    final parameters = top?.parameters ?? member!.parameters;
    if (symbol.type.contains('@unsupported.') ||
        parameters.any((p) => p.$2.contains('@unsupported.')))
      error('E910', 'This Dart callback signature needs additional conformance',
          node);
    final named = top?.namedParameters ?? member!.namedParameters;
    final optional = top?.optionalNames ?? member!.optionalNames;
    final formals = symbol.nativeConstructor
        ? symbol.nativeClass?.typeParameters ??
            top?.typeParameters ??
            const <String, String>{}
        : top?.typeParameters ?? member!.typeParameters;
    final typeParameters = [
      for (final p in formals.entries)
        TypeParameter(p.key, node.span, bound: p.value)
    ];
    final inferred = <String, String>{};
    if (explicitTypes != null) {
      inferred.addAll(_checkTypeArguments(
          symbol.name, typeParameters, explicitTypes, node));
    } else if (_expected != null && formals.isNotEmpty) {
      final resultPattern = symbol.nativeConstructor
          ? '${symbol.type}<${formals.keys.join(', ')}>'
          : symbol.type;
      _inferGeneric(resultPattern, _expected!, inferred, typeParameters);
    }
    final order = List<int>.filled(parameters.length, -1);
    var positional = 0;
    var sawNamed = false;
    final actual = <int, String>{};
    for (var i = 0; i < node.arguments.length; i++) {
      final argument = node.arguments[i];
      final int target;
      if (argument.name == null) {
        if (sawNamed)
          fail('Positional arguments must precede named arguments', argument);
        target = positional++;
      } else {
        sawNamed = true;
        target = parameters.indexWhere((p) => p.$1 == argument.name);
        if (target < 0) fail('Unknown argument: ${argument.name}', argument);
      }
      if (target >= parameters.length)
        fail('Too many arguments for ${symbol.name}', argument);
      if (order[target] >= 0)
        fail('Duplicate argument: ${parameters[target].$1}', argument);
      final pattern = parameters[target].$2;
      final saved = _expected;
      final expected = _substitute(pattern, inferred);
      _expected = formals.keys.any((key) =>
              !inferred.containsKey(key) &&
              RegExp('\\b${RegExp.escape(key)}\\b').hasMatch(expected))
          ? null
          : expected;
      String type;
      try {
        type = expression(argument.value);
      } finally {
        _expected = saved;
      }
      if (!compatible(type, expected) &&
          _acceptExpected(argument.value, type, expected)) {
        type = model.implicitConversions[argument.value]?.resultType ?? type;
      }
      _checkReadonlyEscape(type, argument);
      if (explicitTypes == null &&
          !_inferGeneric(pattern, type, inferred, typeParameters)) {
        fail('Argument type $type is incompatible with $pattern', argument);
      }
      actual[target] = type;
      order[target] = i;
    }
    for (var i = 0; i < parameters.length; i++) {
      if (order[i] < 0 && !optional.contains(parameters[i].$1))
        fail('Missing required argument: ${parameters[i].$1}', node);
    }
    for (final formal in formals.entries) {
      inferred.putIfAbsent(
          formal.key, () => _substitute(formal.value, inferred));
    }
    if (formals.isNotEmpty) {
      final arguments = [for (final key in formals.keys) inferred[key]!];
      _checkTypeArguments(symbol.name, typeParameters, arguments, node);
      model.inferredTypeArguments[node] = arguments;
    }
    for (final entry in actual.entries) {
      final expected = _substitute(parameters[entry.key].$2, inferred);
      if (!compatible(entry.value, expected))
        fail('Argument type ${entry.value} is incompatible with $expected',
            node.arguments[order[entry.key]]);
    }
    var omittedPositional = false;
    final layout = <(String?, int)>[];
    for (var i = 0; i < parameters.length; i++) {
      final name = parameters[i].$1;
      if (order[i] < 0) {
        if (!named.contains(name)) omittedPositional = true;
        continue;
      }
      if (!named.contains(name) && omittedPositional)
        error(
            'E910',
            'A later optional Dart positional argument requires earlier values explicitly',
            node);
      layout.add((named.contains(name) ? name : null, order[i]));
    }
    model.nativeArguments[node] = layout;
    model.argumentOrder[node] = order;
    model.references[node.callee] = symbol;
    _touch(symbol);
    final returned = _substitute(symbol.type, inferred);
    return symbol.nativeConstructor &&
            formals.isNotEmpty &&
            !returned.contains('<')
        ? '$returned<${formals.keys.map((key) => inferred[key]).join(', ')}>'
        : returned;
  }

  String externalCall(CallExpression node, Symbol symbol) {
    if (symbol.nativeTop != null || symbol.nativeMember != null)
      return _nativeCall(node, symbol);

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
      final expected = symbol.parameterTypes[i];
      final saved = _expected;
      if (symbol.library == 'check' && expected != '*') _expected = expected;
      final type = expression(node.arguments[i].value);
      _expected = saved;
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
        if (_blockedInternalNames.contains(name)) {
          error('E209', 'An internal name $name is used outside its package',
              node);
        }
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
    if (applied.callee case MemberAccess member) {
      final prefix = member.object is Identifier
          ? _scope.lookup((member.object as Identifier).name)?.namespace
          : null;
      if (prefix == null)
        return call(node,
            calleeOverride: member, explicitMethodTypes: applied.arguments);
    }
    final symbol = _appliedSymbol(node, applied);
    final name = symbol.name;
    if (symbol.library == 'check' && (name == 'isA' || name == 'isSorted')) {
      if (node.arguments.isNotEmpty) fail('$name expects no arguments', node);
      if (applied.arguments.length != 1) {
        fail('$name expects one type argument', node);
      }
      validateType(applied.arguments.single, node, allowVoid: false);
      return 'dynamic';
    }
    if (symbol.classDeclaration != null && symbol.classCase == null) {
      final returned =
          constructClass(node, symbol.classDeclaration!, applied.arguments);
      if (!symbol.dartName.contains('.')) return returned;
      final qualified = _qualifyType(
          symbol.dartName, returned, symbol.classDeclaration!.name);
      _qualifyConstConstructor(node, qualified);
      final previous = model.references[node.callee];
      model.references[node.callee] = previous?.function == null
          ? Symbol(symbol.dartName, symbol.dartName, qualified,
              classDeclaration: symbol.classDeclaration)
          : Symbol(symbol.dartName, symbol.dartName, qualified)
              .withFunction(previous!.function);
      return qualified;
    }
    if (symbol.external &&
        (symbol.nativeTop != null || symbol.nativeMember != null)) {
      return _nativeCall(node, symbol, explicitTypes: applied.arguments);
    }
    final candidates = symbol.overloads.isEmpty && symbol.function != null
        ? [symbol.function!]
        : symbol.overloads;
    if (candidates.isEmpty) fail('$name is not callable', node);
    if (candidates.length != 1) {
      fail('Choose one overload with a call or a typed context', node);
    }
    final selected = candidates.single;
    final substitution = _checkTypeArguments(
        selected.name, selected.typeParameters, applied.arguments, node);
    return applyArguments(node, selected.parameters, selected,
        typeArguments: substitution, defaultSubstitution: substitution);
  }

  void _rememberGapValue(Symbol symbol, Expression value) {
    if (_valueHasGap(value)) model.gapValues.add(symbol);
  }

  bool _valueHasGap(Expression value) {
    final lowering = model.qudsValueLowerings[value]?.function;
    if (lowering != null && positionalGapPossible(lowering.parameters)) {
      return true;
    }
    if (value is Identifier) {
      final origin = model.references[value] ?? _scope.lookup(value.name);
      return origin != null && model.gapValues.contains(origin);
    }
    return false;
  }

  /// A required named slot may be implemented by an optional named slot.
  bool _parameterKindFits(Parameter expected, Parameter actual) =>
      expected.kind == actual.kind ||
      expected.kind == ParameterKind.requiredNamed &&
          actual.kind == ParameterKind.optionalNamed &&
          actual.defaultValue != null &&
          expected.name == actual.name;

  /// The one unnamed generative parent constructor a child can forward to.
  /// Several constructors, a factory, a variadic, or a name clash stay out.
  ConstructorDeclaration? _synthesizedParentConstructor(ClassDeclaration type) {
    final parentName = type.superclass;
    if (parentName == null || type.constructors.isNotEmpty) return null;
    final parent = _typeSymbol(_genericHead(parentName))?.classDeclaration;
    if (parent == null || parent.kind == 'interface') return null;
    final unnamed = parent.constructors
        .where(
            (constructor) => constructor.name == null && !constructor.factory)
        .toList();
    if (unnamed.length != 1) return null;
    final constructor = unnamed.single;
    if (constructor.parameters.any((parameter) => parameter.variadic)) {
      return null;
    }
    final names =
        constructor.parameters.map((parameter) => parameter.name).toSet();
    if (type.fields.any((field) =>
        !field.isStatic && !field.isEvent && names.contains(field.name))) {
      return null;
    }
    return constructor;
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
        Parameter(field.name, _resolveType(field.type), false, field.span)
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
    final parentConstructor = _synthesizedParentConstructor(type);
    if (parentConstructor != null) {
      final parent =
          _typeSymbol(_genericHead(type.superclass!))!.classDeclaration!;
      final substitution = _genericSubstitution(type.superclass!, parent);
      final parameters = [
        for (final parameter in parentConstructor.parameters)
          Parameter(
              parameter.name,
              _substitute(
                  parameter.initializing.isEmpty
                      ? model.declarations[parameter]?.type ?? parameter.type
                      : _fieldType(parent, parameter.name, parameter.span),
                  substitution),
              parameter.mutable,
              parameter.span,
              kind: parameter.kind,
              defaultValue: parameter.defaultValue,
              variadic: parameter.variadic,
              initializing: parameter.initializing),
        for (final field in type.fields.where((field) =>
            !field.isStatic && !field.isEvent && field.lazyBody == null))
          Parameter(field.name, field.type, false, field.span,
              defaultValue: field.requiredField ? null : field.initializer)
      ];
      return _finishConstruct(node, type, parameters, explicit, null);
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
    final owned = [
      for (final parameter in parameters)
        Parameter(parameter.name, _classMemberType(parameter.type, type),
            parameter.mutable, parameter.span,
            kind: parameter.kind,
            defaultValue: parameter.defaultValue,
            variadic: parameter.variadic,
            initializing: parameter.initializing)
    ];
    final substitution = _constructorSubstitution(node, type, owned, explicit);
    final instantiated = [
      for (final parameter in owned)
        Parameter(parameter.name, _substitute(parameter.type, substitution),
            parameter.mutable, parameter.span,
            kind: parameter.kind,
            defaultValue: parameter.defaultValue,
            variadic: parameter.variadic,
            initializing: parameter.initializing)
    ];
    for (final parameter in instantiated) {
      model.declarations[parameter] =
          Symbol(parameter.name, parameter.name, parameter.type);
    }
    final synthesizedForeign =
        constructor == null && _synthesizedForeignParentDefault(type);
    final hasPacket = constructor != null &&
        !constructor.factory &&
        constructor.parameters
            .any((p) => p.defaultValue != null && p.defaultValue is! Literal);
    if (hasPacket ||
        synthesizedForeign && _omitsForeignDefault(node, instantiated)) {
      model.constructorGapTargets[node] = type;
      if (constructor != null)
        model.constructorGapDeclarations[node] = constructor;
    }
    if (constructor != null) {
      _typeConstructorDefaults(type, constructor);
    } else {
      for (final field in _fieldsOf(type)) {
        if (!field.isStatic && !field.isEvent && field.initializer != null) {
          analyzeInstanceField(type, field);
        }
      }
    }
    if (substitution.isNotEmpty) {
      model.constructorSubstitutions[node] = substitution;
    }
    applyArguments(node, instantiated, null, defaultSubstitution: substitution);
    model.references[node.callee] = type.constructors.isEmpty
        ? Symbol(type.name, type.name, type.name, classDeclaration: type)
        : Symbol(type.name, type.name, type.name).withFunction(
            FunctionDeclaration(
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
              kind: parameter.kind,
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
    if (type.typeParameters.isEmpty && explicit.isEmpty) return const {};
    if (explicit.isNotEmpty) {
      return _checkTypeArguments(
          type.name, type.typeParameters, explicit, node);
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
    }
    _checkTypeArguments(
        type.name,
        type.typeParameters,
        [for (final parameter in type.typeParameters) found[parameter.name]!],
        node);
    return found;
  }

  Map<String, String> _checkTypeArguments(String name,
      List<TypeParameter> parameters, List<String> arguments, Node node,
      {Map<String, String> bounds = const {}}) {
    if (parameters.length != arguments.length) {
      fail('Type arguments do not match $name', node);
    }
    for (final argument in arguments) {
      validateType(argument, node, allowVoid: false);
    }
    final substitution = {
      for (var i = 0; i < parameters.length; i++)
        parameters[i].name: arguments[i]
    };
    for (var i = 0; i < parameters.length; i++) {
      final declared = bounds[parameters[i].name] ?? parameters[i].bound;
      if (declared == null) continue;
      final bound = _substitute(declared, substitution);
      if (!_satisfiesTypeBound(arguments[i], bound)) {
        fail('Type ${arguments[i]} is not a $bound', node);
      }
    }
    return substitution;
  }

  bool _satisfiesTypeBound(String argument, String bound,
      [Set<String> visited = const {}]) {
    if (compatible(argument, bound)) return true;
    if (visited.contains(argument)) return false;
    final evidence = _typeBounds[argument];
    return evidence != null &&
        _satisfiesTypeBound(evidence, bound, {...visited, argument});
  }

  void _inferType(String pattern, String actual, Map<String, String> found,
      List<TypeParameter> parameters) {
    _inferGeneric(pattern, actual, found, parameters);
  }

  bool _inferGeneric(String pattern, String actual, Map<String, String> found,
      List<TypeParameter> parameters) {
    pattern = model.resolve(pattern,
        boundNames: {..._typeNames, for (final p in parameters) p.name},
        lexicalTypes: _scope.lexicalTypes);
    actual = _resolveType(actual);
    // A concrete nullable parameter accepts the whole source type, including
    // an unbounded type variable. Only peel nullable shells for inference.
    if (!parameters.any((parameter) =>
        RegExp('\\b${RegExp.escape(parameter.name)}\\b').hasMatch(pattern))) {
      return compatible(actual, pattern);
    }
    if (parameters.any((p) => p.name == pattern)) {
      final previous = found[pattern];
      if (previous == null || previous == actual) {
        found[pattern] = actual;
        return true;
      }
      if (compatible(previous, actual)) {
        found[pattern] = actual;
        return true;
      }
      if (compatible(actual, previous)) return true;
      if (previous == 'Null' || actual == 'Null') {
        found[pattern] = nullableType(previous == 'Null' ? actual : previous);
        return true;
      }
      if (numeric(unwrap(previous)) && numeric(unwrap(actual))) {
        found[pattern] =
            isNullableType(previous) || isNullableType(actual) ? 'num?' : 'num';
        return true;
      }
      return false;
    }
    if (isNullableType(pattern)) {
      // Null satisfies the nullable shell but supplies no evidence for its inner type.
      if (actual == 'Null') return true;
      return _inferGeneric(unwrap(pattern), unwrap(actual), found, parameters);
    }
    if (pattern.startsWith('FutureOr<') && pattern.endsWith('>')) {
      final inner = pattern.substring(9, pattern.length - 1);
      if (actual.startsWith('Future<') && actual.endsWith('>')) {
        return _inferGeneric(
            inner, actual.substring(7, actual.length - 1), found, parameters);
      }
      return _inferGeneric(inner, actual, found, parameters);
    }
    if (isNullableType(actual)) return compatible(actual, pattern);
    final expectedFunction = functionTypeParts(pattern);
    final actualFunction = functionTypeParts(actual);
    if (expectedFunction != null && actualFunction != null) {
      if (parameters.isEmpty) return compatible(actual, pattern);
      final left = _splitTypes(expectedFunction.$1);
      final right = _splitTypes(actualFunction.$1);
      if (left.length != right.length) return false;
      for (var i = 0; i < left.length; i++) {
        if (!_inferGeneric(functionParameterType(left[i]),
            functionParameterType(right[i]), found, parameters)) return false;
      }
      return _inferGeneric(
          expectedFunction.$2, actualFunction.$2, found, parameters);
    }
    final head = _genericHead(pattern);
    if (pattern.endsWith('>') && head != pattern) {
      var source = actual;
      final sourceHead = _genericHead(source);
      if (head == 'Iterable' && const {'List', 'Set'}.contains(sourceHead)) {
        source = 'Iterable${source.substring(sourceHead.length)}';
      } else if (head == 'Iterable' || head == 'List') {
        final element = _nativeShape(source)?.listElement;
        if (element != null) source = '$head<$element>';
      }
      if ((_genericHead(source) == head ||
              (_typeSymbol(head)?.classDeclaration != null &&
                  identical(_typeSymbol(head)?.classDeclaration,
                      _typeSymbol(_genericHead(source))?.classDeclaration))) &&
          source.endsWith('>')) {
        final left =
            _splitTypes(pattern.substring(head.length + 1, pattern.length - 1));
        final right = _splitTypes(source.substring(
            _genericHead(source).length + 1, source.length - 1));
        if (left.length != right.length) return false;
        for (var i = 0; i < left.length; i++) {
          if (!_inferGeneric(left[i], right[i], found, parameters))
            return false;
        }
        return true;
      }
    }
    return compatible(actual, pattern);
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
  bool _matchGeneric(String pattern, String actual,
          FunctionDeclaration function, Map<String, String> found) =>
      _inferGeneric(pattern, actual, found, function.typeParameters);

  bool _omitsForeignDefault(CallExpression node, List<Parameter> parameters) {
    final seen = List<bool>.filled(parameters.length, false);
    var positional = 0;
    var named = false;
    for (final argument in node.arguments) {
      final int target;
      if (argument.name == null) {
        if (named) return false;
        while (positional < parameters.length &&
            _skipsPositional(parameters[positional])) {
          positional++;
        }
        if (parameters.isNotEmpty &&
            parameters.last.variadic &&
            positional >= parameters.length - 1) {
          continue;
        }
        target = positional++;
      } else {
        named = true;
        target = parameters
            .indexWhere((parameter) => parameter.name == argument.name);
      }
      if (target < 0 || target >= parameters.length || seen[target]) {
        return false;
      }
      seen[target] = true;
    }
    for (var i = 0; i < parameters.length; i++) {
      final value = parameters[i].defaultValue;
      if (!seen[i] && value != null && value is! Literal) return true;
    }
    return false;
  }

  /// A synthesized child in another library cannot inline a private parent default.
  bool _synthesizedForeignParentDefault(ClassDeclaration type) {
    final constructor = _synthesizedParentConstructor(type);
    if (constructor == null) return false;
    final parent =
        _typeSymbol(_genericHead(type.superclass!))?.classDeclaration;
    final parentHome = parent == null ? '' : model.libraryOf[parent] ?? '';
    if (parentHome.isEmpty || parentHome == _activeLibrary) return false;
    return constructor.parameters.any((parameter) =>
        parameter.defaultValue != null && parameter.defaultValue is! Literal);
  }

  /// `name: Type required` and `name: Type = expr` are named-only.
  bool _skipsPositional(Parameter parameter) =>
      parameter.kind == ParameterKind.requiredNamed ||
      parameter.kind == ParameterKind.optionalNamed;

  bool argumentsMatch(CallExpression node, List<Parameter> parameters,
      {required bool commit,
      bool allowConversions = false,
      FunctionDeclaration? function,
      _CheckedArguments? checked,
      Map<String, String> typeArguments = const {},
      Map<String, String> parameterBounds = const {},
      String? declaredReturnType}) {
    if (commit) _checkUnionBoundary(function, node);
    parameters = _callParameters(parameters, function);
    final inferred = {...typeArguments};
    final types = <int, String>{};
    if (function != null &&
        typeArguments.isEmpty &&
        _expected != null &&
        (declaredReturnType ?? function.returnType) != null) {
      _inferGeneric((declaredReturnType ?? function.returnType)!, _expected!,
          inferred, function.typeParameters);
    }
    final order = List<int>.filled(parameters.length, -1);
    var positional = 0;
    var named = false;
    for (var i = 0; i < node.arguments.length; i++) {
      final argument = node.arguments[i];
      int target;
      if (argument.name == null) {
        if (named) return false;
        while (positional < parameters.length &&
            _skipsPositional(parameters[positional])) {
          positional++;
        }
        if (parameters.isNotEmpty &&
            parameters.last.variadic &&
            positional >= parameters.length - 1) {
          if (!variadicArgument(argument, parameters.last)) return false;
          checked?.variadics.add(argument);
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
        _expected = _substitute(parameters[target].type, inferred);
        if (function != null &&
            function.typeParameters.any((p) =>
                !inferred.containsKey(p.name) &&
                !_typeNames.contains(p.name) &&
                RegExp('\\b${RegExp.escape(p.name)}\\b')
                    .hasMatch(_expected!))) {
          _expected = null;
        }
      }
      var type = expression(argument.value);
      _expected = savedExpected;
      final natural = function == null
          ? compatible(type, parameters[target].type)
          : _inferGeneric(
              parameters[target].type, type, inferred, function.typeParameters);
      if (!natural) {
        if (!allowConversions) return false;
        final expected = _substitute(parameters[target].type, inferred);
        final plan = _customConversion(type, expected, argument.value);
        if (plan == null) return false;
        checked?.conversions[argument.value] = plan;
        type = plan.resultType;
        if (function != null &&
            !_inferGeneric(parameters[target].type, type, inferred,
                function.typeParameters)) return false;
      }
      types[target] = type;
      if (checked != null) checked.types[argument.value] = type;
      order[target] = i;
    }
    for (var i = 0; i < parameters.length; i++) {
      if (parameters[i].variadic) continue;
      if (order[i] == -1 && parameters[i].defaultValue == null) {
        final hole = node.arguments.any((a) => isHole(a.value));
        if (!hole) return false;
      }
    }
    for (final entry in types.entries) {
      if (!compatible(
          entry.value, _substitute(parameters[entry.key].type, inferred)))
        return false;
    }
    if (function != null) {
      for (final parameter in function.typeParameters) {
        final argument = inferred[parameter.name];
        if (argument != null &&
            (parameterBounds[parameter.name] ?? parameter.bound) != null &&
            !_satisfiesTypeBound(
                argument,
                _substitute(parameterBounds[parameter.name] ?? parameter.bound!,
                    inferred))) return false;
      }
    }
    checked?.inferred.addAll(inferred);
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

  void _rememberUnionHome(Symbol symbol, Expression value) {
    final prefix = model.unionExpressionPrefixes[value];
    if (prefix == null || !symbol.type.contains(' | ')) return;
    model.unionPrefixes[symbol] = prefix;
  }

  /// Null when the union class belongs to this library. An empty string is an
  /// unprefixed import; `api.` is that import's Dart prefix.
  String? _importedUnionPrefix(FunctionDeclaration? function) {
    final home =
        function == null ? '' : model.declarations[function]?.library ?? '';
    if (home.isEmpty ||
        home == _activeLibrary ||
        model.providerUnionFunctions.contains(function)) return null;
    for (final node in model.imports) {
      if (node.export) continue;
      if (_resolveLibrary(_file, node.uri) != home) continue;
      final name = node.prefix;
      return name == null || name.isEmpty ? '' : '$name.';
    }
    return '';
  }

  String? _calleeUnionPrefix(Expression callee) {
    if (callee is Identifier) {
      final symbol = model.references[callee];
      if (symbol != null && model.unionPrefixes.containsKey(symbol)) {
        return model.unionPrefixes[symbol];
      }
      return _importedUnionPrefix(symbol?.function);
    }
    if (callee is MemberAccess && callee.object is Identifier) {
      final owner = model.references[callee.object];
      if (owner?.namespace != null &&
          !model.providerUnionFunctions
              .contains(model.references[callee]?.function)) {
        return '${(callee.object as Identifier).name}.';
      }
    }
    return null;
  }

  void _noteUnionWrap(
      Expression value, String actual, String expected, String? prefix) {
    final wanted = _resolveType(expected);
    final got = _resolveType(actual);
    if (!directUnionType(wanted)) return;
    if (got == wanted) return;
    if (directUnionType(got)) {
      model.reboxAs[value] = wanted;
      return;
    }
    model.wrapAs[value] = wanted;
    if (prefix != null) model.unionWrapPrefixes[value] = prefix;
  }

  void _checkUnionBoundary(FunctionDeclaration? function, Node node) {
    if (function == null) return;
    final home = model.declarations[function]?.library ?? '';
    if (home.isEmpty || home == _activeLibrary) return;
    if (model.providerUnionFunctions.contains(function)) {
      if (node is CallExpression &&
          node.arguments.any((a) => isHole(a.value))) {
        error(
            'E910',
            'Imported union partial application needs additional boundary conformance',
            node);
      }
      return;
    }
    final types = [
      model.declarations[function]!.type,
      ...function.parameters.map((p) => p.type)
    ];
    if (types.any((type) => _conversionSignatureType(
            type, home, function.typeParameters.map((p) => p.name).toSet())
        .contains(' | '))) {
      error(
          'E910',
          'This imported union signature needs additional boundary conformance',
          node);
    }
  }

  String applyArguments(CallExpression node, List<Parameter> parameters,
      FunctionDeclaration? function,
      {_CheckedArguments? checked,
      Map<String, String> typeArguments = const {},
      Map<String, String> parameterBounds = const {},
      Map<String, String> defaultSubstitution = const {},
      String? declaredReturnType}) {
    parameters = _callParameters(parameters, function);
    if (function != null &&
        (model.declarations[function]?.type == '<infer>' ||
            parameters.any((parameter) => parameter.needsAdapter) ||
            node.arguments.any((argument) => argument.name != null))) {
      final owner = _methodOwners[function];
      if (owner != null) {
        analyzeMethod(owner, function);
      } else {
        final extOwner = model.extensions
            .where((item) => item.methods.contains(function))
            .firstOrNull;
        if (extOwner != null) {
          analyzeExtension(extOwner, function);
        } else {
          analyzeFunction(function);
        }
      }
    }
    final verified = checked ?? _CheckedArguments();
    if (checked == null &&
        !argumentsMatch(node, parameters,
            commit: true,
            allowConversions: true,
            function: function,
            checked: verified,
            typeArguments: typeArguments,
            parameterBounds: parameterBounds,
            declaredReturnType: declaredReturnType)) {
      fail('No overload matches this call', node);
    }
    model.implicitConversions.addAll(verified.conversions);
    final inferred = {...verified.inferred, ...typeArguments};
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
        while (positional < parameters.length &&
            _skipsPositional(parameters[positional])) {
          positional++;
        }
        if (parameters.isNotEmpty &&
            parameters.last.variadic &&
            positional >= parameters.length - 1) {
          if (!verified.variadics.contains(argument) &&
              !variadicArgument(argument, parameters.last)) {
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
      final type = verified.types[argument.value] ?? expression(argument.value);
      _expected = savedExpected;
      if (!_accepts(type, parameters[target].type, function)) {
        fail(
            'Argument type $type is incompatible with ${parameters[target].type}',
            argument);
      }
      _rememberInference(function, parameters[target].type, type, inferred);
      order[target] = i;
    }
    final providerOwner = model.providerDefaultMethods[function];
    final providerHome = providerOwner == null
        ? model.declarations[function]?.library ?? ''
        : model.libraryOf[providerOwner] ?? '';
    if (function != null &&
        model.providerDefaultFunctions.contains(function) &&
        order.contains(-1)) {
      model.providerBridgeImports.add(function);
    }
    if (function != null &&
        providerHome.isNotEmpty &&
        providerHome != _activeLibrary &&
        (model.providerDefaultFunctions.contains(function) ||
            model.providerDefaultMethods.containsKey(function))) {
      for (var i = 0; i < parameters.length; i++) {
        if (parameters[i].kind == ParameterKind.optionalPositional &&
            order[i] == -1 &&
            order.skip(i + 1).any((index) => index >= 0)) {
          model.providerGapCalls.add(node);
          break;
        }
      }
    }
    for (var i = 0; i < parameters.length; i++) {
      if (parameters[i].variadic || order[i] != -1) continue;
      final fallback = parameters[i].defaultValue;
      if (fallback == null) fail('Missing required argument', node);
      if (model.constructorGapTargets.containsKey(node) &&
          fallback is! Literal) {
        continue;
      }
      final savedDefaultExpected = _expected;
      _expected = parameters[i].type;
      final String fallbackType;
      try {
        fallbackType = model.implicitConversions[fallback]?.resultType ??
            model.types[fallback] ??
            expression(fallback);
      } finally {
        _expected = savedDefaultExpected;
      }
      final type =
          _substitute(_callResult(fallbackType, function), defaultSubstitution);
      if (!compatible(type, parameters[i].type)) {
        fail('Default type $type is incompatible with ${parameters[i].type}',
            fallback);
      }
    }
    for (var i = 0; i < parameters.length; i++) {
      if (parameters[i].variadic || order[i] < 0) continue;
      final argument = node.arguments[order[i]];
      if (isHole(argument.value)) continue;
      final actual =
          verified.types[argument.value] ?? model.types[argument.value]!;
      final expected = _substitute(parameters[i].type, inferred);
      if (!compatible(actual, expected)) {
        fail('Inferred type does not accept argument $actual', argument);
      }
      _noteUnionWrap(
          argument.value, actual, expected, _importedUnionPrefix(function));
    }
    if (function != null &&
        function.typeParameters.isNotEmpty &&
        function.typeParameters.every((p) => inferred.containsKey(p.name))) {
      final arguments = [
        for (final p in function.typeParameters) inferred[p.name]!
      ];
      _checkTypeArguments(
          function.name, function.typeParameters, arguments, node,
          bounds: parameterBounds);
      model.inferredTypeArguments[node] = arguments;
    }
    model.instantiatedParameterTypes[node] = [
      for (final parameter in parameters) _substitute(parameter.type, inferred)
    ];
    model.argumentOrder[node] = order;
    model.variadicArguments[node] = rest;
    if (holes.isNotEmpty) {
      final types = holes
          .map((index) => _substitute(parameters[index].type, inferred))
          .join(', ');
      final returned = declaredReturnType ??
          (function == null
              ? 'void'
              : (model.declarations[function]?.type ??
                  function.returnType ??
                  'void'));
      return '($types) -> ${_callResult(_substitute(returned, inferred), function)}';
    }
    if (function != null && model.declarations[function]!.type == '<infer>') {
      analyzeFunction(function);
    }
    final returned = declaredReturnType ??
        (function == null ? 'void' : model.declarations[function]!.type);
    if (function != null) {
      for (final parameter in function.typeParameters) {
        if (inferred.containsKey(parameter.name)) continue;
        if (RegExp('\\b${parameter.name}\\b').hasMatch(returned)) {
          error('E302', 'A type cannot be inferred', node);
        }
      }
    }
    _checkUnionBoundary(function, node);
    return _callResult(_substitute(returned, inferred), function);
  }

  void _rememberInference(FunctionDeclaration? function, String parameter,
      String argument, Map<String, String> inferred) {
    if (function == null) return;
    if (!_inferGeneric(
        parameter, argument, inferred, function.typeParameters)) {
      fail('Conflicting generic argument $argument', function);
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

  final _nativeInstantiations = <String, DartShape>{};
  DartShape? _nativeShape(String type) {
    final instance = nonNullableType(stripReadonlyType(_resolveType(type)));
    final head = _dartHead(instance);
    if (_typeSymbol(head)?.classDeclaration != null) return null;
    final shape = model.dartShapes[head];
    if (shape == null || shape.typeParameters.isEmpty) return shape;
    return _nativeInstantiations.putIfAbsent(
        instance, () => instantiateDartShape(shape, instance));
  }

  bool _typedStorage(String type) {
    final resolved = _resolveType(type);
    if (!_dartHead(resolved).startsWith('@dart.typed.')) return false;
    final shape = _nativeShape(resolved);
    return shape?.typedStorage ?? false;
  }

  String? _listElement(String type) {
    if (type.startsWith('List<') && type.endsWith('>'))
      return type.substring(5, type.length - 1);
    return _nativeShape(type)?.listElement;
  }

  (String, Map<String, String>)? _collectionVars(String type) {
    final typedElement = _nativeShape(type)?.listElement;
    if (typedElement != null) return ('List', {'T': typedElement});

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
      ('List', 'setAll') => (
          [('index', 'int'), ('values', 'Iterable<T>')],
          'void'
        ),
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
      ('List', 'indexOf') => ([('value', 'T')], 'int'),
      ('Set', 'lookup') => ([('value', 'Object?')], 'T?'),
      ('Set', 'add') => ([('value', 'T')], 'bool'),
      ('Set', 'addAll') => ([('values', 'Iterable<T>')], 'void'),
      ('Set' || 'List', 'remove') => ([('value', 'Object?')], 'bool'),
      ('Set' || 'List', 'clear') => (<(String, String)>[], 'void'),
      ('Iterable', 'contains') => ([('value', 'Object?')], 'bool'),
      ('Iterable', 'elementAt') => ([('index', 'int')], 'T'),
      ('Iterable', 'toList') => (<(String, String)>[], 'List<T>'),
      ('Iterable', 'toSet') => (<(String, String)>[], 'Set<T>'),
      ('Iterable', 'any' || 'every' || 'where') => (
          [('test', '(T) -> bool')],
          name == 'where' ? 'Iterable<T>' : 'bool'
        ),
      ('Iterable', 'forEach') => ([('action', '(T) -> void')], 'void'),
      ('Map', 'containsKey') => ([('key', 'Object?')], 'bool'),
      ('Map', 'remove') => ([('key', 'Object?')], 'V?'),
      ('Map', 'clear') => (<(String, String)>[], 'void'),
      ('Map', 'addAll') => ([('other', 'Map<K, V>')], 'void'),
      ('Map', 'putIfAbsent') => ([('key', 'K'), ('ifAbsent', '() -> V')], 'V'),
      ('Map', 'forEach') => ([('action', '(K, V) -> void')], 'void'),
      ('String', 'contains' || 'startsWith' || 'endsWith') => (
          [('other', 'String')],
          'bool'
        ),
      ('String', 'substring') => ([('start', 'int')], 'String'),
      ('String', 'codeUnitAt') => ([('index', 'int')], 'int'),
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
      ('Iterable' || 'List' || 'Set', 'first' || 'last' || 'single') => 'T',
      ('List', 'reversed') => 'Iterable<T>',
      ('Map', 'keys') => 'Iterable<K>',
      ('Map', 'values') => 'Iterable<V>',
      _ => null,
    };
  }

  String _dartHead(String type) {
    var bare = type.startsWith('readonly ') ? type.substring(9) : type;
    if (isNullableType(bare)) bare = bare.substring(0, bare.length - 1);
    return _genericHead(bare);
  }

  DartMember? _sdkMember(String type, String name) {
    return _nativeShape(type)?.members[name];
  }

  String? _dartCall(String type, String name, CallExpression node,
      {List<String>? explicitTypes}) {
    final member = _sdkMember(type, name);
    if (member == null || member.getter) return null;
    final callee = node.callee is TypeApplication
        ? (node.callee as TypeApplication).callee
        : node.callee;
    if (callee is MemberAccess &&
        model.references[callee.object]?.nativeTop?.isType == true)
      fail('Instance member $name is used on the type', callee);
    final symbol = _dartMemberSymbol(member, member.type);
    model.references[node.callee] = symbol;
    return _nativeCall(node, symbol, explicitTypes: explicitTypes);
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

  String? _collectionCall(String type, String name, CallExpression node,
      {bool readonly = false}) {
    final found = _collectionVars(type);
    if (found == null) return null;
    final family = found.$1;
    final vars = {
      for (final entry in found.$2.entries)
        entry.key:
            readonly ? _readonlyView('readonly this', entry.value) : entry.value
    };
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
        if (isNullableType(stored)) fail('zip expects an iterable', other);
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
      case 'indexOf' || 'lastIndexOf':
        if (node.arguments.isEmpty || node.arguments.length > 2) {
          fail('$name expects one or two arguments', node);
        }
        final parameters = [
          Parameter('pattern', 'String', false, node.span),
          if (node.arguments.length == 2)
            Parameter('start', 'int', false, node.span),
        ];
        final signature = node.arguments.length == 1
            ? '$name(pattern: String) -> int'
            : '$name(pattern: String, start: int) -> int';
        return _bindCollection(name, name, parameters, 'int', node, signature);
      case 'startsWith':
        if (node.arguments.isEmpty || node.arguments.length > 2) {
          fail('startsWith expects one or two arguments', node);
        }
        final parameters = [
          Parameter('pattern', 'String', false, node.span),
          if (node.arguments.length == 2)
            Parameter('index', 'int', false, node.span),
        ];
        final signature = node.arguments.length == 1
            ? 'startsWith(pattern: String) -> bool'
            : 'startsWith(pattern: String, index: int) -> bool';
        return _bindCollection(
            'startsWith', 'startsWith', parameters, 'bool', node, signature);
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
      'isFinite' || 'isInfinite' || 'isNaN' || 'isNegative' => 'bool',
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
    'setRange',
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
      final copy = create(name, outer.type, readonly: outer.readonly);
      _scope.symbols[name] = copy;
      copies.add((outer, copy));
    }
    model.captures[node] = copies;
    final type = expression(node.body);
    _scope = saved;
    return '() -> $type';
  }

  void _validateConversionDefinitions() {
    final signatures = <String>{};
    for (final entry in _conversionDefinitions.entries) {
      final f = entry.key;
      var signature = '${f.parameters.single.type} -> ${f.returnType}';
      for (var i = 0; i < f.typeParameters.length; i++) {
        signature = signature.replaceAll(
            RegExp(
                '(?<![a-zA-Z0-9_])${RegExp.escape(f.typeParameters[i].name)}(?![a-zA-Z0-9_])'),
            '@$i');
      }
      if (!signatures.add('${entry.value}:$signature')) {
        error('E201', 'Duplicate conversion declaration: $signature', f);
      }
    }
  }

  void _rejectConstantConversion(Expression value) {
    walkAst(value, (node) {
      if (model.implicitConversions.containsKey(node) ||
          model.explicitConversions.containsKey(node)) {
        error(
            'E401', 'Custom conversions are not compile-time constants', node);
      }
    });
  }

  String _conversionSignatureType(
      String raw, String home, Set<String> shadows) {
    final saved = {...model.activeAliasShadows};
    model.activeAliasShadows.addAll(shadows);
    try {
      if (home == library || home.isEmpty) return _resolveType(raw);
      _libraryScope(home);
      final aliases =
          _libraries[home]?.statements.whereType<AliasDeclaration>().toList() ??
              <AliasDeclaration>[];
      for (var pass = 0; pass <= aliases.length; pass++) {
        final previous = raw;
        for (final alias in aliases) {
          if (shadows.contains(alias.name)) continue;
          raw = raw.replaceAll(
              RegExp('(?<![\\w.])${RegExp.escape(alias.name)}\\b'),
              alias.target);
        }
        if (raw == previous) break;
      }
      // Resolve the provider's lexical names before caller aliases. Otherwise
      // a caller's `type Ticket = String` can steal an imported Ticket cast.
      return _resolveType(_libraryType(raw, home, shadows: shadows));
    } finally {
      model.activeAliasShadows
        ..clear()
        ..addAll(saved);
    }
  }

  ConversionPlan? _customConversion(String from, String to, Node at,
      {bool implicitOnly = true}) {
    final candidates = <(ConversionPlan, int)>[];
    for (final entry in _conversionDefinitions.entries.toList()) {
      final f = entry.key;
      if (implicitOnly && f.conversionKind != 'implicit') continue;
      final home = entry.value;
      if (home != library && home.isNotEmpty) _libraryScope(home);
      final shadows = f.typeParameters.map((p) => p.name).toSet();
      final source =
          _conversionSignatureType(f.parameters.single.type, home, shadows);
      final result = _conversionSignatureType(f.returnType!, home, shadows);
      final inferred = <String, String>{};
      if (!_inferGeneric(source, from, inferred, f.typeParameters)) continue;
      if (f.typeParameters.any((p) => !inferred.containsKey(p.name))) {
        if (!_inferGeneric(result, to, inferred, f.typeParameters)) continue;
      }
      if (f.typeParameters.any((p) => !inferred.containsKey(p.name))) continue;
      final instantiatedSource = _substitute(source, inferred);
      final instantiatedResult = _substitute(result, inferred);
      if (!compatible(from, instantiatedSource) ||
          !compatible(instantiatedResult, to)) continue;
      if (f.typeParameters.any((p) =>
          p.bound != null &&
          !_satisfiesTypeBound(
              inferred[p.name]!,
              _substitute(_conversionSignatureType(p.bound!, home, shadows),
                  inferred)))) continue;
      final score = (compatible(instantiatedSource, from) ? 2 : 0) +
          (compatible(to, instantiatedResult) ? 2 : 0) +
          (f.typeParameters.isEmpty ? 1 : 0);
      candidates.add((
        ConversionPlan(
            f,
            home,
            [for (final p in f.typeParameters) inferred[p.name]!],
            instantiatedResult),
        score
      ));
    }
    if (candidates.isEmpty) return null;
    final best = candidates.map((c) => c.$2).reduce((a, b) => a > b ? a : b);
    final winners = candidates.where((c) => c.$2 == best).toList();
    if (winners.length != 1)
      error('E310', 'Ambiguous conversion from $from to $to', at);
    final plan = winners.single.$1;
    if (plan.library.isNotEmpty && plan.library != library) {
      final prefix =
          '_qCast${sha256Hex(utf8.encode(plan.library)).substring(0, 10)}';
      final sdk = sdkLibraryName(plan.library);
      model.backendTypeImports[prefix] = sdk == null
          ? qudsBackendLibraryUri(_file, plan.library)
          : sdkDartFileName(sdk);
    }
    if (sdkLibraryName(plan.library) != null) {
      model.usedSdk.add(plan.library);
      model.usedSdkNames
          .putIfAbsent(plan.library, () => <String>{})
          .add(plan.function.name);
    }
    return plan;
  }

  bool _acceptExpected(Expression value, String actual, String expected) {
    if (compatible(actual, expected)) {
      _noteUnionWrap(value, actual, expected, null);
      return true;
    }
    final plan = _customConversion(actual, expected, value);
    if (plan == null) return false;
    model.implicitConversions[value] = plan;
    return true;
  }

  String conversion(ConversionExpression node) {
    final raw = expression(node.operand);
    final source = unwrap(stripReadonlyType(raw));
    final target = isNullableType(node.type)
        ? node.type.substring(0, node.type.length - 1)
        : node.type;
    validateType(target, node, allowVoid: false);
    if (source != target && !_convertible(source, target)) {
      final plan = _customConversion(raw, node.type, node, implicitOnly: false);
      if (plan == null)
        error('E300', 'Cannot convert $source to $target', node);
      model.explicitConversions[node] = plan;
    }
    final result = node.safe ? nullableType(node.type) : node.type;
    return source == target ? _readonlyView(raw, result) : result;
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
      if (!_acceptExpected(node.values[i], value, fields.single.type)) {
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
    if (isNullableType(bare)) bare = bare.substring(0, bare.length - 1);
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
      if (!(node.operator == '='
          ? _acceptExpected(node.value, result, symbol.type)
          : compatible(result, symbol.type))) {
        fail('Cannot assign $result to ${symbol.type}', node);
      }
    }
    _afterAssignment(
        node.name,
        symbol.type,
        model.implicitConversions[node.value]?.resultType ?? type,
        node.operator);
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
    if (_lookupNonCore(node.name) != null) {
      fail('Loop binding would shadow ${node.name}', node);
    }
    if (node.index != null) {
      if (node.index == node.name) {
        fail('Loop bindings must have different names', node);
      }
      if (_lookupNonCore(node.index!) != null) {
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
    final type = _withIteration(node, symbol, () {
      if (node.filter != null && expression(node.filter!) != 'bool') {
        fail('collection filter must be bool', node.filter!);
      }
      return groupElementType(node.body);
    });
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
    if (isNullableType(bare)) return null;
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
        IndexAssignment(:final value) => value,
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

  String _nullable(String type) => nullableType(type);

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
    return _readonlyMethod
        ? _readonlyView('readonly this', _thisType!)
        : _thisType!;
  }

  String tryExpression(TryExpression node) {
    return joinTypes(expression(node.operand), expression(node.fallback), node);
  }

  String joinTypes(String left, String right, Node node) {
    left = _resolveType(left);
    right = _resolveType(right);
    if (left == 'dynamic' || right == 'dynamic') return 'dynamic';
    if (left == 'Null') return nullableType(right);
    if (right == 'Null') return nullableType(left);
    if (left == right) return left;
    if (numeric(left) && numeric(right)) return 'num';
    if (left == '$right?') return left;
    if (right == '$left?') return right;
    if (compatible(left, right)) return right;
    if (compatible(right, left)) return left;
    final expected = _expected;
    if (expected != null &&
        compatible(left, expected) &&
        compatible(right, expected)) return expected;
    final pending = <String>[left];
    final seen = <String>{};
    while (pending.isNotEmpty) {
      final current = pending.removeAt(0);
      if (!seen.add(current)) continue;
      final declaration = _typeSymbol(_genericHead(current))?.classDeclaration;
      final parents = declaration == null
          ? (_nativeShape(current)?.instantiatedSupertypes ?? const <String>{})
          : <String>[
              if (declaration.superclass != null) declaration.superclass!,
              ...declaration.interfaces,
            ].map((parent) => _substitute(_classMemberType(parent, declaration),
              _genericSubstitution(current, declaration)));
      for (final parent in parents) {
        final candidate = _resolveType(parent);
        if (const {'Object', 'Object?', 'dynamic'}.contains(candidate))
          continue;
        if (compatible(left, candidate) && compatible(right, candidate))
          return candidate;
        pending.add(candidate);
      }
    }
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

// Local to one successful argument check; never reused between overload trials.
/// A Quds callable stored as a value when its Dart tear-off is not the Quds signature.
class QudsValueLowering {
  const QudsValueLowering(
      this.function, this.typeArguments, this.parameterTypes,
      {this.staticOwner});
  final FunctionDeclaration function;
  final List<String> typeArguments;

  /// Parameter types after class and method specialization, in source order.
  final List<String> parameterTypes;

  /// Declaring type of an inherited static method. Null for instance tear-offs.
  final String? staticOwner;
}

class _CheckedArguments {
  final inferred = <String, String>{};
  final types = <Expression, String>{};
  final variadics = <Argument>{};
  final conversions = <Expression, ConversionPlan>{};
}
