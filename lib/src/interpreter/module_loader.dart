/// Module & embedded SDK loader for the Quds interpreter (`use quds:*`,
/// `use quds:math::geometry`, `use dart:*`, and virtual host modules).
///
/// Pure Dart (zero `dart:io` imports). Caches parsed SDK ASTs across sessions
/// so `use quds:math` is fast even across repeated interactive runs.
library;

import '../ast.dart';
import '../lexer.dart';
import '../library_uri.dart';
import '../parser.dart';
import '../sdk_sources.dart';
import 'dart_stdlib_bridge.dart';
import 'environment.dart';
import 'evaluator.dart';
import 'exceptions.dart';
import 'values.dart';

/// Decision returned by a custom import resolver / policy check.
sealed class QudsImportResolution {
  const QudsImportResolution();
}

/// Allow default resolution (embedded `quds:*`, safe `dart:*`, or registered host module).
class QudsImportAllow extends QudsImportResolution {
  const QudsImportAllow();
}

/// Deny importing this URI with a human-readable reason.
class QudsImportDeny extends QudsImportResolution {
  const QudsImportDeny(this.reason);
  final String reason;
}

/// Provide Quds source code dynamically for this URI (virtual file / notebook module).
class QudsImportProvideSource extends QudsImportResolution {
  const QudsImportProvideSource(this.source, {this.fileName});
  final String source;
  final String? fileName;
}

/// Provide a pre-built map of host symbols directly.
class QudsImportProvideSymbols extends QudsImportResolution {
  const QudsImportProvideSymbols(this.symbols);
  final Map<String, Object?> symbols;
}

typedef QudsImportResolver = QudsImportResolution Function(String uri);

/// Cached evaluated module with section-level symbol mapping.
class _LoadedModule {
  _LoadedModule({
    required this.uri,
    required this.publicExports,
    required this.sectionExports,
  });

  final String uri;
  final Map<String, Object?> publicExports;
  final Map<String, Map<String, Object?>> sectionExports;

  Map<String, Object?> select({
    String? section,
    List<String> show = const [],
    List<String> hide = const [],
    required SourceSpan span,
  }) {
    Map<String, Object?> source;
    if (section == null || section.isEmpty) {
      source = publicExports;
    } else {
      final filtered = <String, Object?>{};
      for (final entry in sectionExports.entries) {
        if (entry.key == section || entry.key.startsWith('$section::')) {
          filtered.addAll(entry.value);
        }
      }
      if (filtered.isEmpty) {
        throw QudsRuntimeException(
          'Library `$uri` has no section `::$section`.',
          span,
          code: 'E900',
        );
      }
      source = filtered;
    }

    final result = <String, Object?>{};
    if (show.isNotEmpty) {
      for (final name in show) {
        if (!source.containsKey(name)) {
          throw QudsRuntimeException(
            'Library `$uri` does not export `$name`.',
            span,
            code: 'E900',
          );
        }
        result[name] = source[name];
      }
    } else {
      result.addAll(source);
    }
    for (final name in hide) {
      result.remove(name);
    }
    return result;
  }
}

/// Loads `quds:*`, pure `dart:*`, and virtual host modules into an interpreter
/// session with AST caching and section filtering.
class QudsModuleLoader {
  QudsModuleLoader({
    required this.createBaseEnvironment,
    required this.createModuleEvaluator,
    this.virtualModules = const {},
    this.allowedLibraries,
    this.deniedLibraries = const {},
    this.importResolver,
  });

  /// Shared parsed-AST cache across sessions for embedded SDK libraries.
  static final Map<String, Program> _parsedSdkCache = {};

  final QudsEnvironment Function() createBaseEnvironment;
  final QudsEvaluator Function(QudsEnvironment env, ImportHook onImport)
      createModuleEvaluator;
  final Map<String, Map<String, Object?>> virtualModules;
  final Set<String>? allowedLibraries;
  final Set<String> deniedLibraries;
  final QudsImportResolver? importResolver;

  final Map<String, _LoadedModule> _sessionCache = {};

  /// Registers or updates a virtual host module (e.g. `quds:viz` or `host:sensors`).
  void registerVirtualModule(String uri, Map<String, Object?> symbols) {
    _sessionCache[uri] = _LoadedModule(
      uri: uri,
      publicExports: Map<String, Object?>.from(symbols),
      sectionExports: const {},
    );
  }

  /// Clears per-session loaded module instances (keeps static parsed AST cache).
  void clearSessionCache() {
    _sessionCache.clear();
  }

  /// Handles an `ImportDeclaration` (`use ...` or `export ...`).
  Future<Map<String, Object?>> resolveImport(
    ImportDeclaration decl,
    QudsEnvironment targetEnv, {
    bool isInternalSdk = false,
  }) async {
    final fullUri = decl.uri;
    final targetUri = libraryTarget(fullUri);
    final section = librarySection(fullUri);

    // Check policy allow/deny lists for user imports (SDK internal `use dart:math`
    // is permitted when the SDK itself was allowed!).
    if (!isInternalSdk) {
      _checkImportPolicy(fullUri, targetUri, decl.span);
    }

    QudsImportResolution resolution = const QudsImportAllow();
    if (!isInternalSdk && importResolver != null) {
      resolution = importResolver!(fullUri);
    }

    _LoadedModule module;
    switch (resolution) {
      case QudsImportDeny(:final reason):
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.libraryDenied,
          'Import `$fullUri` denied: $reason',
          decl.span,
        );
      case QudsImportProvideSymbols(:final symbols):
        module = _LoadedModule(
          uri: targetUri,
          publicExports: Map<String, Object?>.from(symbols),
          sectionExports: const {},
        );
      case QudsImportProvideSource(:final source, :final fileName):
        module = await _loadFromSource(
          targetUri,
          source,
          fileName: fileName ?? targetUri,
          cacheable: false,
        );
      case QudsImportAllow():
        module = await _loadDefault(targetUri, decl.span);
    }

    final selected = module.select(
      section: section,
      show: decl.show,
      hide: decl.hide,
      span: decl.span,
    );

    if (!decl.export) {
      if (decl.prefix != null) {
        targetEnv.define(decl.prefix!, QudsNamespace(decl.prefix!, selected));
      } else {
        for (final entry in selected.entries) {
          targetEnv.define(entry.key, entry.value);
        }
      }
    }
    return selected;
  }

  void _checkImportPolicy(String fullUri, String targetUri, SourceSpan span) {
    if (deniedLibraries.contains(fullUri) ||
        deniedLibraries.contains(targetUri)) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.libraryDenied,
        'Library `$fullUri` is denied by the active execution policy.',
        span,
      );
    }
    if (allowedLibraries != null) {
      final allowed = allowedLibraries!.contains(fullUri) ||
          allowedLibraries!.contains(targetUri) ||
          allowedLibraries!.contains('*');
      if (!allowed) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.libraryDenied,
          'Library `$fullUri` is not in the allowed libraries list (${allowedLibraries!.join(', ')}).',
          span,
        );
      }
    }
  }

  Future<_LoadedModule> _loadDefault(String targetUri, SourceSpan span) async {
    final cached = _sessionCache[targetUri];
    if (cached != null) return cached;

    if (virtualModules.containsKey(targetUri)) {
      final mod = _LoadedModule(
        uri: targetUri,
        publicExports: Map<String, Object?>.from(virtualModules[targetUri]!),
        sectionExports: const {},
      );
      _sessionCache[targetUri] = mod;
      return mod;
    }

    final dartLib = resolveDartStdlib(targetUri);
    if (dartLib != null) {
      final mod = _LoadedModule(
        uri: targetUri,
        publicExports: dartLib,
        sectionExports: const {},
      );
      _sessionCache[targetUri] = mod;
      return mod;
    }

    final sdkName = sdkLibraryName(targetUri);
    if (sdkName != null && embeddedSdk.containsKey(sdkName)) {
      final mod = await _loadFromSource(
        targetUri,
        embeddedSdk[sdkName]!,
        fileName: 'quds:$sdkName',
        cacheable: true,
        isSdk: true,
      );
      _sessionCache[targetUri] = mod;
      return mod;
    }

    throw QudsRuntimeException(
      'Unknown import `$targetUri`.',
      span,
      code: 'E900',
    );
  }

  Future<_LoadedModule> _loadFromSource(
    String targetUri,
    String source, {
    required String fileName,
    required bool cacheable,
    bool isSdk = false,
  }) async {
    final program = cacheable
        ? _parsedSdkCache.putIfAbsent(
            targetUri,
            () => Parser(Lexer().tokenize(source, file: fileName)).parse(),
          )
        : Parser(Lexer().tokenize(source, file: fileName)).parse();

    final modEnv = createBaseEnvironment();
    final reExports = <String, Object?>{};
    final sectionSymbolNames = <String, Set<String>>{};
    final declaredPublicNames = <String>{};

    // Track which top-level declarations live under each `:: section`.
    var currentSection = '';
    for (final stmt in program.statements) {
      if (stmt is SectionDeclaration) {
        currentSection = stmt.path;
        continue;
      }
      String? declName;
      if (stmt is FunctionDeclaration && stmt.visibility != 'internal') {
        declName = stmt.name;
      } else if (stmt is ClassDeclaration && stmt.visibility != 'internal') {
        declName = stmt.name;
      } else if (stmt is Binding) {
        declName = stmt.name;
      }
      if (declName != null && !declName.startsWith('_')) {
        declaredPublicNames.add(declName);
        if (currentSection.isNotEmpty) {
          sectionSymbolNames
              .putIfAbsent(currentSection, () => {})
              .add(declName);
        }
      }
    }

    final evaluator = createModuleEvaluator(
      modEnv,
      (imp, env) async {
        final exported = await resolveImport(
          imp,
          env,
          isInternalSdk: isSdk,
        );
        if (imp.export) {
          reExports.addAll(exported);
        }
      },
    );

    await evaluator.executeProgram(program, env: modEnv, resetBudget: false);

    final publicExports = <String, Object?>{...reExports};
    for (final name in declaredPublicNames) {
      final slot = modEnv.localSlots[name];
      if (slot != null) publicExports[name] = slot.value;
    }

    // Also include sealed-case subclasses exported by public sealed classes.
    for (final stmt in program.statements) {
      if (stmt is ClassDeclaration &&
          !stmt.name.startsWith('_') &&
          stmt.cases.isNotEmpty &&
          stmt.kind != 'enum') {
        for (final c in stmt.cases) {
          final slot = modEnv.localSlots[c.name];
          if (slot != null && !c.name.startsWith('_')) {
            publicExports[c.name] = slot.value;
          }
        }
      }
    }

    final sectionExports = <String, Map<String, Object?>>{};
    for (final entry in sectionSymbolNames.entries) {
      final map = <String, Object?>{};
      for (final name in entry.value) {
        if (publicExports.containsKey(name)) {
          map[name] = publicExports[name];
        }
      }
      sectionExports[entry.key] = map;
    }

    return _LoadedModule(
      uri: targetUri,
      publicExports: publicExports,
      sectionExports: sectionExports,
    );
  }
}
