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
import 'workspace.dart';

/// Decision returned by a custom import resolver / policy check.
sealed class QudsImportResolution {
  const QudsImportResolution();
}

/// Allow default resolution (embedded `quds:*`, safe `dart:*`, workspace files,
/// or registered host module).
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
    this.extensions = const [],
  });

  final String uri;
  final Map<String, Object?> publicExports;
  final Map<String, Map<String, Object?>> sectionExports;
  final List<(ExtensionDeclaration, QudsEnvironment, String)> extensions;

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

/// Loads `quds:*`, pure `dart:*`, nested [QudsWorkspace] project files, and
/// virtual host modules into an interpreter session with AST caching,
/// singleton diamond resolution, cycle detection, and section filtering.
class QudsModuleLoader {
  QudsModuleLoader({
    required this.createBaseEnvironment,
    required this.createModuleEvaluator,
    this.virtualModules = const {},
    this.allowedLibraries,
    this.deniedLibraries = const {},
    this.importResolver,
    this.workspace,
  });

  /// Shared parsed-AST cache across sessions for embedded SDK libraries.
  static final Map<String, Program> _parsedSdkCache = {};

  final QudsEnvironment Function() createBaseEnvironment;
  final QudsEvaluator Function(
    QudsEnvironment env,
    ImportHook onImport, {
    required bool isSdk,
  }) createModuleEvaluator;
  final Map<String, Map<String, Object?>> virtualModules;
  final Set<String>? allowedLibraries;
  final Set<String> deniedLibraries;
  final QudsImportResolver? importResolver;
  QudsWorkspace? workspace;

  final Map<String, _LoadedModule> _sessionCache = {};
  final List<String> _loadingStack = [];

  /// Registers or updates a virtual host module (e.g. `quds:viz` or `host:sensors`).
  void registerVirtualModule(String uri, Map<String, Object?> symbols) {
    _sessionCache[uri] = _LoadedModule(
      uri: uri,
      publicExports: Map<String, Object?>.from(symbols),
      sectionExports: const {},
    );
  }

  /// Invalidates a cached workspace module and its transitive dependents.
  void invalidateWorkspaceFile(String path) {
    final norm = QudsWorkspace.normalizePath(path);
    _sessionCache.remove('workspace:$norm');
    if (workspace != null) {
      for (final dep in workspace!.transitiveDependentsOf(norm)) {
        _sessionCache.remove('workspace:$dep');
      }
    }
  }

  /// Clears all cached workspace modules (preserving built-in host modules).
  void clearWorkspaceCache() {
    _sessionCache.removeWhere((key, _) => key.startsWith('workspace:'));
  }

  /// Runs [action] with [workspacePath] recorded on the active loading stack so
  /// cycles back to the entry-point file (`main.quds -> a.quds -> main.quds`)
  /// are caught immediately with `E210`.
  Future<T> runWithEntryFile<T>(
    String workspacePath,
    Future<T> Function() action,
  ) async {
    final norm = QudsWorkspace.normalizePath(workspacePath);
    _loadingStack.add(norm);
    try {
      return await action();
    } finally {
      if (_loadingStack.isNotEmpty && _loadingStack.last == norm) {
        _loadingStack.removeLast();
      } else {
        _loadingStack.remove(norm);
      }
    }
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
    String? fromFile,
    void Function(ExtensionDeclaration ext, QudsEnvironment env)? onExtension,
  }) async {
    final fullUri = decl.uri;
    final targetUri = libraryTarget(fullUri);
    final section = librarySection(fullUri);
    final effectiveFrom = fromFile ?? decl.span.file;

    // Check if this URI resolves to a file inside the attached QudsWorkspace.
    final workspacePath = (!isInternalSdk && workspace != null)
        ? workspace!.resolveImportPath(fullUri, fromFile: effectiveFrom)
        : null;

    // Check policy allow/deny lists for user imports (workspace project files
    // are allowed unless explicitly denied in `deniedLibraries`).
    if (!isInternalSdk) {
      _checkImportPolicy(
        fullUri,
        targetUri,
        decl.span,
        workspacePath: workspacePath,
      );
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
        if (workspacePath != null) {
          module = await _loadWorkspaceModule(workspacePath, decl.span);
        } else {
          module = await _loadDefault(targetUri, decl.span);
        }
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
    if (onExtension != null && decl.prefix == null) {
      for (final (ext, extEnv, extSec) in module.extensions) {
        if (section != null &&
            section.isNotEmpty &&
            extSec != section &&
            !extSec.startsWith('$section::')) {
          continue;
        }
        onExtension(ext, extEnv);
      }
    }
    return selected;
  }

  void _checkImportPolicy(
    String fullUri,
    String targetUri,
    SourceSpan span, {
    String? workspacePath,
  }) {
    final workspaceDot = workspacePath == null
        ? null
        : (workspacePath.endsWith('.quds')
                ? workspacePath.substring(0, workspacePath.length - 5)
                : workspacePath)
            .replaceAll('/', '.');
    if (deniedLibraries.contains(fullUri) ||
        deniedLibraries.contains(targetUri) ||
        (workspacePath != null && deniedLibraries.contains(workspacePath)) ||
        (workspaceDot != null && deniedLibraries.contains(workspaceDot))) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.libraryDenied,
        'Library `$fullUri` is denied by the active execution policy.',
        span,
      );
    }
    if (workspacePath != null) {
      // Attached project workspace files are trusted local project modules.
      return;
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

  Future<_LoadedModule> _loadWorkspaceModule(
    String workspacePath,
    SourceSpan span,
  ) async {
    final cacheKey = 'workspace:$workspacePath';
    final cached = _sessionCache[cacheKey];
    if (cached != null) return cached;

    if (_loadingStack.contains(workspacePath)) {
      final startIdx = _loadingStack.indexOf(workspacePath);
      final chain = [..._loadingStack.sublist(startIdx), workspacePath];
      throw QudsRuntimeException(
        'Circular import detected: ${chain.join(' -> ')}.',
        span,
        code: 'E210',
      );
    }

    final source = workspace?.readFile(workspacePath);
    if (source == null) {
      throw QudsRuntimeException(
        'Workspace file `$workspacePath` not found.',
        span,
        code: 'E900',
      );
    }

    _loadingStack.add(workspacePath);
    try {
      final mod = await _loadFromSource(
        workspacePath,
        source,
        fileName: workspacePath,
        cacheable: false,
        isSdk: false,
      );
      _sessionCache[cacheKey] = mod;
      return mod;
    } finally {
      _loadingStack.removeLast();
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
    final exportSectionByDecl = <ImportDeclaration, String>{};
    final moduleExtensions =
        <(ExtensionDeclaration, QudsEnvironment, String)>[];

    // Track which top-level declarations and re-exports live under each `:: section`.
    var currentSection = '';
    for (final stmt in program.statements) {
      if (stmt is SectionDeclaration) {
        currentSection = stmt.path;
        continue;
      }
      if (stmt is ExtensionDeclaration) {
        moduleExtensions.add((stmt, modEnv, currentSection));
        continue;
      }
      if (stmt is ImportDeclaration && stmt.export) {
        if (currentSection.isNotEmpty) {
          exportSectionByDecl[stmt] = currentSection;
        }
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

    late QudsEvaluator evaluator;
    evaluator = createModuleEvaluator(
      modEnv,
      (imp, env) async {
        final exported = await resolveImport(
          imp,
          env,
          isInternalSdk: isSdk,
          fromFile: fileName,
          onExtension: (ext, extEnv) {
            evaluator.registerExtension(ext, extEnv);
            if (imp.export) {
              moduleExtensions
                  .add((ext, extEnv, exportSectionByDecl[imp] ?? ''));
            }
          },
        );
        if (imp.export) {
          reExports.addAll(exported);
          final sec = exportSectionByDecl[imp];
          if (sec != null && sec.isNotEmpty) {
            sectionSymbolNames.putIfAbsent(sec, () => {}).addAll(exported.keys);
          }
        }
      },
      isSdk: isSdk,
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
      extensions: moduleExtensions,
    );
  }
}
