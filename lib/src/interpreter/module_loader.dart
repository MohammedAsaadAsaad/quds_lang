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
import 'sdk_intrinsics.dart';
import 'universal_vm.dart';
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

/// Telemetry counters tracking workspace compilation, bytecode cache hits, and
/// CodePush-style incremental invalidations.
class QudsCompilationStats {
  const QudsCompilationStats({
    required this.compiledModules,
    required this.recompiledModules,
    required this.bytecodeCacheHits,
    required this.runtimeCacheHits,
    required this.invalidatedRuntimeModules,
    required this.evictedCompiledModules,
    required this.cachedCompiledCount,
  });

  /// Total number of workspace modules compiled to AST + Universal Bytecode.
  final int compiledModules;

  /// Number of workspace modules recompiled after their file contents changed.
  final int recompiledModules;

  /// Times a module load reused an already-compiled bytecode artifact.
  final int bytecodeCacheHits;

  /// Times a module import was served directly from the evaluated module cache.
  final int runtimeCacheHits;

  /// Runtime module entries invalidated due to direct or transitive file edits.
  final int invalidatedRuntimeModules;

  /// Compiled bytecode artifacts evicted due to file edits or deletions.
  final int evictedCompiledModules;

  /// Current number of compiled workspace modules stored in cache.
  final int cachedCompiledCount;
}

class _CompiledWorkspaceArtifact {
  const _CompiledWorkspaceArtifact({
    required this.path,
    required this.fingerprint,
    required this.source,
    required this.program,
    required this.chunk,
  });

  final String path;
  final String fingerprint;
  final String source;
  final Program program;
  final QudsUniversalChunk chunk;
}

/// Cached evaluated module with section-level symbol mapping.
class _LoadedModule {
  _LoadedModule({
    required this.uri,
    required this.publicExports,
    required this.sectionExports,
    this.extensions = const [],
    this.fingerprint,
  });

  final String uri;
  final Map<String, Object?> publicExports;
  final Map<String, Map<String, Object?>> sectionExports;
  final List<(ExtensionDeclaration, QudsEnvironment, String)> extensions;
  final String? fingerprint;

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
/// virtual host modules into an interpreter session with content-hashed
/// bytecode caching, automatic Tier-1 promotion, surgical CodePush
/// invalidation, singleton diamond resolution, cycle detection, and section
/// filtering.
class QudsModuleLoader {
  QudsModuleLoader({
    required this.createBaseEnvironment,
    required this.createModuleEvaluator,
    this.virtualModules = const {},
    this.allowedLibraries,
    this.deniedLibraries = const {},
    this.importResolver,
    this.workspace,
    this.preferBytecodeModules = true,
    this.enableTier1Promotion = true,
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

  /// When true, workspace modules execute via compiled [QudsUniversalChunk]
  /// bytecode (with optional Tier-1 Register VM promotion for hot functions).
  bool preferBytecodeModules;

  /// When true, pure-compute functions inside imported workspace modules are
  /// automatically promoted to Tier-1 unboxed register bytecode.
  bool enableTier1Promotion;

  final Map<String, _LoadedModule> _sessionCache = {};
  final Map<String, _CompiledWorkspaceArtifact> _compiledWorkspaceCache = {};
  final Set<String> _compiledHistory = {};
  final List<String> _loadingStack = [];

  int _compiledModules = 0;
  int _recompiledModules = 0;
  int _bytecodeCacheHits = 0;
  int _runtimeCacheHits = 0;
  int _invalidatedRuntimeModules = 0;
  int _evictedCompiledModules = 0;

  /// Current compilation & cache hit/miss telemetry snapshot.
  QudsCompilationStats get stats => QudsCompilationStats(
        compiledModules: _compiledModules,
        recompiledModules: _recompiledModules,
        bytecodeCacheHits: _bytecodeCacheHits,
        runtimeCacheHits: _runtimeCacheHits,
        invalidatedRuntimeModules: _invalidatedRuntimeModules,
        evictedCompiledModules: _evictedCompiledModules,
        cachedCompiledCount: _compiledWorkspaceCache.length,
      );

  /// Returns whether [path] currently has an up-to-date compiled bytecode
  /// artifact cached for its latest workspace content.
  bool hasCompiledArtifact(String path) {
    final norm = QudsWorkspace.normalizePath(path);
    final cached = _compiledWorkspaceCache[norm];
    if (cached == null) return false;
    final currentFp = workspace?.fileFingerprint(norm);
    return currentFp != null && cached.fingerprint == currentFp;
  }

  /// Registers or updates a virtual host module (e.g. `quds:viz` or `host:sensors`).
  void registerVirtualModule(String uri, Map<String, Object?> symbols) {
    _sessionCache[uri] = _LoadedModule(
      uri: uri,
      publicExports: Map<String, Object?>.from(symbols),
      sectionExports: const {},
    );
  }

  /// Compiles (or returns the cached compiled bytecode artifact for) a
  /// workspace `.quds` file at [path].
  _CompiledWorkspaceArtifact _getOrCompileWorkspaceArtifact(
    String normPath,
    String source,
  ) {
    final fp =
        workspace?.fileFingerprint(normPath) ?? qudsContentFingerprint(source);
    final existing = _compiledWorkspaceCache[normPath];
    if (existing != null &&
        existing.fingerprint == fp &&
        existing.source == source) {
      _bytecodeCacheHits++;
      return existing;
    }
    final isRecompile = _compiledHistory.contains(normPath);
    final tokens = const Lexer().tokenize(source, file: normPath);
    final program = Parser(tokens).parse();
    final chunk = QudsUniversalCompiler.compile(program, name: normPath);
    final artifact = _CompiledWorkspaceArtifact(
      path: normPath,
      fingerprint: fp,
      source: source,
      program: program,
      chunk: chunk,
    );
    _compiledWorkspaceCache[normPath] = artifact;
    _compiledHistory.add(normPath);
    _compiledModules++;
    if (isRecompile) _recompiledModules++;
    return artifact;
  }

  /// Eagerly pre-compiles the specified workspace `.quds` files into the
  /// content-hashed bytecode cache, returning the list of files compiled or
  /// recompiled (unchanged already-cached files are skipped).
  List<String> precompileWorkspaceFiles(Iterable<String> paths) {
    final ws = workspace;
    if (ws == null) return const [];
    final recompiled = <String>[];
    for (final rawPath in paths) {
      final norm = QudsWorkspace.normalizePath(rawPath);
      if (!norm.endsWith('.quds')) continue;
      final src = ws.readFile(norm);
      if (src == null) continue;
      final before = _compiledModules;
      _getOrCompileWorkspaceArtifact(norm, src);
      if (_compiledModules > before) {
        recompiled.add(norm);
      }
    }
    return recompiled;
  }

  /// Surgically applies a CodePush / workspace [change] to both the compiled
  /// bytecode cache and the evaluated runtime module cache:
  /// - Deleted files are evicted from both caches.
  /// - Changed files are evicted from both caches (so they recompile cleanly).
  /// - Transitive dependents whose own source did NOT change have ONLY their
  ///   runtime evaluated exports invalidated while keeping their compiled
  ///   bytecode artifact warm!
  void applyWorkspaceBatchChange(QudsWorkspaceBatchChange change) {
    for (final path in change.deletedFiles) {
      if (_compiledWorkspaceCache.remove(path) != null) {
        _evictedCompiledModules++;
      }
      if (_sessionCache.remove('workspace:$path') != null) {
        _invalidatedRuntimeModules++;
      }
    }
    for (final path in change.changedFiles) {
      if (_compiledWorkspaceCache.remove(path) != null) {
        _evictedCompiledModules++;
      }
      if (_sessionCache.remove('workspace:$path') != null) {
        _invalidatedRuntimeModules++;
      }
    }
    for (final path in change.invalidatedFiles) {
      if (change.changedFiles.contains(path) ||
          change.deletedFiles.contains(path)) {
        continue;
      }
      if (_sessionCache.remove('workspace:$path') != null) {
        _invalidatedRuntimeModules++;
      }
    }
  }

  /// Invalidates a cached workspace module and its transitive dependents.
  void invalidateWorkspaceFile(String path) {
    final norm = QudsWorkspace.normalizePath(path);
    if (_compiledWorkspaceCache.remove(norm) != null) {
      _evictedCompiledModules++;
    }
    if (_sessionCache.remove('workspace:$norm') != null) {
      _invalidatedRuntimeModules++;
    }
    if (workspace != null) {
      for (final dep in workspace!.transitiveDependentsOf(norm)) {
        if (_sessionCache.remove('workspace:$dep') != null) {
          _invalidatedRuntimeModules++;
        }
      }
    }
  }

  /// Clears all cached workspace runtime modules (preserving built-in host
  /// modules and, unless [clearCompiledBytecode] is true, compiled bytecode
  /// artifacts whose content fingerprints still match).
  void clearWorkspaceCache({bool clearCompiledBytecode = false}) {
    _sessionCache.removeWhere((key, _) => key.startsWith('workspace:'));
    if (clearCompiledBytecode) {
      _compiledWorkspaceCache.clear();
    }
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
    final source = workspace?.readFile(workspacePath);
    if (source == null) {
      _sessionCache.remove('workspace:$workspacePath');
      _compiledWorkspaceCache.remove(workspacePath);
      throw QudsRuntimeException(
        'Workspace file `$workspacePath` not found.',
        span,
        code: 'E900',
      );
    }

    final currentFp = workspace?.fileFingerprint(workspacePath) ??
        qudsContentFingerprint(source);
    final cacheKey = 'workspace:$workspacePath';
    final cached = _sessionCache[cacheKey];
    if (cached != null && cached.fingerprint == currentFp) {
      _runtimeCacheHits++;
      return cached;
    }

    if (_loadingStack.contains(workspacePath)) {
      final startIdx = _loadingStack.indexOf(workspacePath);
      final chain = [..._loadingStack.sublist(startIdx), workspacePath];
      throw QudsRuntimeException(
        'Circular import detected: ${chain.join(' -> ')}.',
        span,
        code: 'E210',
      );
    }

    _loadingStack.add(workspacePath);
    try {
      final artifact = _getOrCompileWorkspaceArtifact(workspacePath, source);
      final mod = await _loadFromSource(
        workspacePath,
        source,
        fileName: workspacePath,
        cacheable: false,
        isSdk: false,
        precompiledProgram: artifact.program,
        precompiledChunk: artifact.chunk,
        fingerprint: artifact.fingerprint,
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
    Program? precompiledProgram,
    QudsUniversalChunk? precompiledChunk,
    String? fingerprint,
  }) async {
    final program = precompiledProgram ??
        (cacheable
            ? _parsedSdkCache.putIfAbsent(
                targetUri,
                () => Parser(Lexer().tokenize(source, file: fileName)).parse(),
              )
            : Parser(Lexer().tokenize(source, file: fileName)).parse());

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

    if (!isSdk && preferBytecodeModules && precompiledChunk != null) {
      await QudsUniversalVm.execute(
        precompiledChunk,
        evaluator,
        modEnv,
        resetBudget: false,
        enableTier1Promotion: enableTier1Promotion,
      );
    } else {
      await evaluator.executeProgram(program, env: modEnv, resetBudget: false);
    }

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

    if (isSdk) {
      installQudsSdkIntrinsics(
        targetUri,
        modEnv,
        publicExports,
        sectionExports,
      );
    }

    return _LoadedModule(
      uri: targetUri,
      publicExports: publicExports,
      sectionExports: sectionExports,
      extensions: moduleExtensions,
      fingerprint: fingerprint,
    );
  }
}
