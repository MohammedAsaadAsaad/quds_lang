/// Declarative host module bridge (`QudsHostModule`) allowing host applications
/// to expose domain-specific APIs (hardware sensors, app state, scoped filesystem,
/// HTTP clients, CAD commands, etc.) to interpreted Quds scripts under
/// capability governance and with rich metadata for editor autocomplete.
library;

import 'values.dart';

/// Metadata describing one symbol exported by a [QudsHostModule].
class QudsHostSymbolDoc {
  const QudsHostSymbolDoc({
    required this.name,
    required this.kind,
    this.signature,
    this.documentation,
    this.requiredCapability,
  });

  final String name;
  final String kind; // 'function' | 'constant' | 'object'
  final String? signature;
  final String? documentation;
  final String? requiredCapability;
}

/// A named virtual module registered by the host application.
///
/// Importable from Quds via `use <uri>` (for example `use host:sensors`) and
/// automatically visible to the embedded editor engine for autocomplete/hover.
class QudsHostModule {
  QudsHostModule({
    required this.uri,
    this.description,
    Map<String, Object?> exports = const {},
    List<QudsHostSymbolDoc> docs = const [],
  })  : exports = Map.unmodifiable(exports),
        docs = List.unmodifiable(docs);

  static QudsHostModuleBuilder builder(String uri, {String? description}) =>
      QudsHostModuleBuilder(uri, description: description);

  final String uri;
  final String? description;
  final Map<String, Object?> exports;
  final List<QudsHostSymbolDoc> docs;
}

/// Fluent builder for constructing a [QudsHostModule].
class QudsHostModuleBuilder {
  QudsHostModuleBuilder(this.uri, {this.description});

  final String uri;
  final String? description;
  final Map<String, Object?> _exports = {};
  final List<QudsHostSymbolDoc> _docs = [];

  /// Exposes a host function, optionally requiring a named [capability].
  QudsHostModuleBuilder function(
    String name,
    QudsHostCallback callback, {
    String? capability,
    String? signature,
    String? documentation,
  }) {
    _exports[name] = QudsNativeFunction(
      '$uri::$name',
      callback,
      requiredCapability: capability,
      signature: signature,
      documentation: documentation,
    );
    _docs.add(QudsHostSymbolDoc(
      name: name,
      kind: 'function',
      signature: signature,
      documentation: documentation,
      requiredCapability: capability,
    ));
    return this;
  }

  /// Exposes a constant value (number, string, list, map, or namespace).
  QudsHostModuleBuilder constant(
    String name,
    Object? value, {
    String? documentation,
  }) {
    _exports[name] = value;
    _docs.add(QudsHostSymbolDoc(
      name: name,
      kind: 'constant',
      documentation: documentation,
    ));
    return this;
  }

  /// Exposes a structured object namespace with nested methods/properties.
  QudsHostModuleBuilder namespace(
    String name,
    Map<String, Object?> members, {
    String? documentation,
  }) {
    _exports[name] = QudsNamespace(name, members);
    _docs.add(QudsHostSymbolDoc(
      name: name,
      kind: 'object',
      documentation: documentation,
    ));
    return this;
  }

  QudsHostModule build() => QudsHostModule(
        uri: uri,
        description: description,
        exports: _exports,
        docs: _docs,
      );
}
