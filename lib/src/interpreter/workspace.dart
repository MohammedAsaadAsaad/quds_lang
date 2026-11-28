/// Pure-Dart multi-file, nested-folder Virtual Project Workspace
/// (`QudsWorkspace`) for building large, modular Quds projects (such as
/// MATLAB-style scientific toolboxes, multi-module libraries, and studios).
///
/// Supports:
/// - Arbitrary nested folders (`core/constants.quds`, `math/ode/rk4.quds`, ...)
/// - Official Quds relative imports (`use util`, `use math.ode.rk4`,
///   `use ^.core.constants`, `use ^^.shared.types`), `package:<name>` imports,
///   barrel `export` re-exports, and `::section` imports across files
/// - Static project dependency graph, unresolved import diagnostics, and
///   circular import detection
/// - Surgical transitive cache invalidation when any nested file is edited
/// - Portable `.qproj` JSON serialization/deserialization
///
/// 100% pure Dart (zero `dart:io` or Flutter dependencies) — runs identically
/// on Flutter Mobile, Desktop, Web, and Dart VM/CLI.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../ast.dart';
import '../lexer.dart';
import '../library_uri.dart';
import '../parser.dart';

/// Hierarchical tree node representing a folder, text file, or binary asset inside [QudsWorkspace].
class QudsWorkspaceNode {
  const QudsWorkspaceNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isBinary = false,
    this.byteSize = 0,
    this.children = const [],
  });

  final String name;
  final String path;
  final bool isDirectory;
  final bool isBinary;
  final int byteSize;
  final List<QudsWorkspaceNode> children;
}

/// Static dependency analysis report for an entire [QudsWorkspace].
class QudsWorkspaceDependencyReport {
  const QudsWorkspaceDependencyReport({
    required this.importsByFile,
    required this.importedByFile,
    required this.unresolvedImports,
    required this.cycles,
  });

  /// Direct workspace dependencies (`file -> {importedWorkspaceFiles}`).
  final Map<String, Set<String>> importsByFile;

  /// Reverse dependencies (`file -> {filesImportingIt}`).
  final Map<String, Set<String>> importedByFile;

  /// Workspace-relative imports that could not be resolved to any file.
  final Map<String, List<String>> unresolvedImports;

  /// Detected circular import chains (e.g. `['a.quds', 'b.quds', 'a.quds']`).
  final List<List<String>> cycles;

  bool get hasCycles => cycles.isNotEmpty;
  bool get hasUnresolvedImports => unresolvedImports.isNotEmpty;
}

/// Pure-Dart deterministic 64-bit content fingerprint (dual 32-bit FNV-1a + length)
/// used to detect file changes across nested workspaces without `dart:io`.
String qudsContentFingerprint(String content) {
  var h1 = 0x811c9dc5;
  var h2 = 0x9e3779b1;
  final len = content.length;
  for (var i = 0; i < len; i++) {
    final c = content.codeUnitAt(i);
    h1 ^= c;
    h1 = (h1 * 0x01000193) & 0xffffffff;
    h2 ^= (c + i) & 0xffff;
    h2 = (h2 * 0x85ebca6b) & 0xffffffff;
  }
  final s1 = h1.toRadixString(16).padLeft(8, '0');
  final s2 = h2.toRadixString(16).padLeft(8, '0');
  return '$len:$s1$s2';
}

/// Callback invoked whenever a file in [QudsWorkspace] is created, edited,
/// renamed, or deleted.
typedef QudsWorkspaceChangeListener = void Function(String normalizedPath);

/// Summary of an atomic single-file or multi-file CodePush update in
/// [QudsWorkspace], including all transitively invalidated dependents.
class QudsWorkspaceBatchChange {
  const QudsWorkspaceBatchChange({
    required this.changedFiles,
    required this.deletedFiles,
    required this.invalidatedFiles,
    required this.unchangedFiles,
    required this.revision,
    this.bundleVersion,
  });

  /// Files created or modified with different content (need bytecode recompile).
  final Set<String> changedFiles;

  /// Files removed from the workspace (bytecode & runtime caches evicted).
  final Set<String> deletedFiles;

  /// Union of [changedFiles], [deletedFiles], and every file that directly or
  /// transitively imports them (runtime module cache must be re-evaluated).
  final Set<String> invalidatedFiles;

  /// Files included in a patch whose content matched the existing file (skipped).
  final Set<String> unchangedFiles;

  /// New monotonic workspace revision after this change.
  final int revision;

  /// Optional bundle / CodePush version tag associated with this change.
  final String? bundleVersion;

  bool get hasChanges => changedFiles.isNotEmpty || deletedFiles.isNotEmpty;
}

/// Callback invoked once per atomic file/bundle mutation with full transitive
/// dependency invalidation metadata.
typedef QudsWorkspaceBatchChangeListener = void Function(
  QudsWorkspaceBatchChange change,
);

/// Serializable CodePush-style delta or full bundle patch targeting nested
/// files, folders, and binary assets inside a [QudsWorkspace].
class QudsWorkspacePatch {
  const QudsWorkspacePatch({
    this.upsertFiles = const {},
    this.upsertBinaryAssets = const {},
    this.deleteFiles = const [],
    this.deleteFolders = const [],
    this.newEntryPoint,
    this.bundleVersion,
  });

  /// Text/Quds files to create or update (supports arbitrarily nested paths).
  final Map<String, String> upsertFiles;

  /// Binary assets to create or update (supports arbitrarily nested paths).
  final Map<String, Uint8List> upsertBinaryAssets;

  /// Specific file or asset paths to delete.
  final List<String> deleteFiles;

  /// Folder paths to delete recursively along with all nested contents.
  final List<String> deleteFolders;

  /// Optional updated workspace entry point (e.g. `'app/main.quds'`).
  final String? newEntryPoint;

  /// Optional OTA / CodePush release identifier (e.g. `'1.4.2-hotfix.1'`).
  final String? bundleVersion;

  Map<String, Object?> toJson() => {
        'format': 'quds-workspace-patch',
        'version': 1,
        if (bundleVersion != null) 'bundleVersion': bundleVersion,
        if (newEntryPoint != null) 'newEntryPoint': newEntryPoint,
        if (upsertFiles.isNotEmpty) 'upsertFiles': upsertFiles,
        if (upsertBinaryAssets.isNotEmpty)
          'upsertBinaryAssets': {
            for (final e in upsertBinaryAssets.entries)
              e.key: base64Encode(e.value),
          },
        if (deleteFiles.isNotEmpty) 'deleteFiles': deleteFiles,
        if (deleteFolders.isNotEmpty) 'deleteFolders': deleteFolders,
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  static QudsWorkspacePatch fromJson(Map<String, Object?> json) {
    final rawUpsert = (json['upsertFiles'] as Map?) ?? const {};
    final rawBin = (json['upsertBinaryAssets'] as Map?) ?? const {};
    final rawDelFiles = (json['deleteFiles'] as List?) ?? const [];
    final rawDelFolders = (json['deleteFolders'] as List?) ?? const [];
    return QudsWorkspacePatch(
      upsertFiles: {
        for (final e in rawUpsert.entries) '${e.key}': '${e.value}'
      },
      upsertBinaryAssets: {
        for (final e in rawBin.entries)
          '${e.key}': Uint8List.fromList(base64Decode('${e.value}')),
      },
      deleteFiles: [for (final f in rawDelFiles) '$f'],
      deleteFolders: [for (final d in rawDelFolders) '$d'],
      newEntryPoint: json['newEntryPoint'] as String?,
      bundleVersion: json['bundleVersion'] as String?,
    );
  }

  static QudsWorkspacePatch fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'Expected a JSON object for QudsWorkspacePatch.',
      );
    }
    return fromJson(decoded);
  }
}

/// Immutable point-in-time snapshot of a [QudsWorkspace] for instant rollback
/// after a CodePush update.
class QudsWorkspaceSnapshot {
  const QudsWorkspaceSnapshot({
    required this.name,
    required this.packageName,
    required this.entryPoint,
    required this.revision,
    required this.bundleVersion,
    required this.files,
    required this.binaryAssets,
    required this.folders,
  });

  final String name;
  final String? packageName;
  final String entryPoint;
  final int revision;
  final String? bundleVersion;
  final Map<String, String> files;
  final Map<String, Uint8List> binaryAssets;
  final Set<String> folders;
}

/// Outcome of applying a [QudsWorkspacePatch] or restoring a
/// [QudsWorkspaceSnapshot].
class QudsCodePushResult {
  const QudsCodePushResult({
    required this.applied,
    required this.revision,
    this.bundleVersion,
    this.changedFiles = const [],
    this.deletedFiles = const [],
    this.unchangedFiles = const [],
    this.invalidatedModules = const [],
    this.recompiledFiles = const [],
    this.errors = const [],
    this.previousSnapshot,
  });

  final bool applied;
  final int revision;
  final String? bundleVersion;
  final List<String> changedFiles;
  final List<String> deletedFiles;
  final List<String> unchangedFiles;
  final List<String> invalidatedModules;
  final List<String> recompiledFiles;
  final List<String> errors;
  final QudsWorkspaceSnapshot? previousSnapshot;

  QudsCodePushResult copyWith({
    List<String>? recompiledFiles,
  }) =>
      QudsCodePushResult(
        applied: applied,
        revision: revision,
        bundleVersion: bundleVersion,
        changedFiles: changedFiles,
        deletedFiles: deletedFiles,
        unchangedFiles: unchangedFiles,
        invalidatedModules: invalidatedModules,
        recompiledFiles: recompiledFiles ?? this.recompiledFiles,
        errors: errors,
        previousSnapshot: previousSnapshot,
      );
}

/// In-memory multi-file, nested-folder project workspace attachable to
/// [QudsSession] and [QudsEditorEngine], supporting both `.quds` source files
/// and arbitrary text/binary project assets (`assets/*.json`, `.csv`, `.bmp`, `.png`, ...).
class QudsWorkspace {
  QudsWorkspace({
    this.name = 'quds_project',
    this.packageName,
    this.entryPoint = 'main.quds',
    String? bundleVersion,
    Map<String, String>? files,
    Map<String, Uint8List>? binaryAssets,
    Iterable<String> folders = const [],
  }) : _bundleVersion = bundleVersion {
    for (final folder in folders) {
      createFolder(folder);
    }
    if (files != null) {
      for (final entry in files.entries) {
        writeFile(entry.key, entry.value);
      }
    }
    if (binaryAssets != null) {
      for (final entry in binaryAssets.entries) {
        writeAssetBytes(entry.key, entry.value);
      }
    }
  }

  String name;
  String? packageName;
  String entryPoint;

  int _revision = 0;
  String? _bundleVersion;
  final Map<String, String> _files = {};
  final Map<String, String> _fileFingerprints = {};
  final Map<String, Uint8List> _binaryAssets = {};
  final Set<String> _folders = {};
  final List<QudsWorkspaceChangeListener> _listeners = [];
  final List<QudsWorkspaceBatchChangeListener> _batchListeners = [];

  /// Monotonically increasing revision counter incremented on every mutation.
  int get revision => _revision;

  /// Optional CodePush / bundle version label for this workspace.
  String? get bundleVersion => _bundleVersion;

  /// Returns the deterministic content fingerprint for [path], or `null` if absent.
  String? fileFingerprint(String path) =>
      _fileFingerprints[normalizePath(path)];

  /// Deterministic fingerprint covering every text file path & content in the workspace.
  String get workspaceFingerprint {
    final sorted = _files.keys.toList()..sort();
    final buf = StringBuffer();
    for (final p in sorted) {
      buf.write(p);
      buf.write('=');
      buf.write(_fileFingerprints[p] ?? '');
      buf.write(';');
    }
    return qudsContentFingerprint(buf.toString());
  }

  /// Registers a listener notified when any file changes.
  void addChangeListener(QudsWorkspaceChangeListener listener) =>
      _listeners.add(listener);

  /// Removes a previously registered change listener.
  void removeChangeListener(QudsWorkspaceChangeListener listener) =>
      _listeners.remove(listener);

  /// Registers a listener notified once per atomic file or CodePush batch change.
  void addBatchChangeListener(QudsWorkspaceBatchChangeListener listener) =>
      _batchListeners.add(listener);

  /// Removes a previously registered batch change listener.
  void removeBatchChangeListener(QudsWorkspaceBatchChangeListener listener) =>
      _batchListeners.remove(listener);

  void _emitBatchChange(QudsWorkspaceBatchChange change) {
    for (final listener
        in List<QudsWorkspaceBatchChangeListener>.from(_batchListeners)) {
      listener(change);
    }
    if (_listeners.isNotEmpty) {
      final allPaths = <String>{...change.changedFiles, ...change.deletedFiles};
      for (final p in allPaths) {
        for (final listener
            in List<QudsWorkspaceChangeListener>.from(_listeners)) {
          listener(p);
        }
      }
    }
  }

  /// Normalizes a workspace-relative POSIX path and rejects escaping above root.
  static String normalizePath(String rawPath) {
    final cleaned = rawPath.replaceAll('\\', '/').trim();
    final parts = cleaned.split('/');
    final stack = <String>[];
    for (final part in parts) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (stack.isEmpty) {
          throw ArgumentError(
            'Workspace path `$rawPath` escapes above the workspace root.',
          );
        }
        stack.removeLast();
      } else {
        stack.add(part);
      }
    }
    return stack.join('/');
  }

  /// Returns the parent directory path of [filePath], or `''` for root files.
  static String dirname(String filePath) {
    final norm = normalizePath(filePath);
    final idx = norm.lastIndexOf('/');
    return idx < 0 ? '' : norm.substring(0, idx);
  }

  /// Best-effort MIME type inferred from file extension.
  static String mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.txt') || lower.endsWith('.quds')) return 'text/plain';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  /// Returns all text files as an unmodifiable map of `normalizedPath -> content`.
  Map<String, String> get files => Map.unmodifiable(_files);

  /// Returns all binary assets as an unmodifiable map of `normalizedPath -> bytes`.
  Map<String, Uint8List> get binaryAssets => Map.unmodifiable(_binaryAssets);

  /// Number of text files in this workspace.
  int get fileCount => _files.length;

  /// Total number of non-`.quds` assets (text + binary) in this workspace.
  int get assetCount =>
      _binaryAssets.length +
      _files.keys.where((p) => !p.endsWith('.quds')).length;

  /// Creates a folder (and all its parent folders) inside the workspace.
  void createFolder(String folderPath) {
    final norm = normalizePath(folderPath);
    if (norm.isEmpty) return;
    final segments = norm.split('/');
    for (var i = 1; i <= segments.length; i++) {
      _folders.add(segments.sublist(0, i).join('/'));
    }
  }

  /// Creates or updates a text file at [path] (automatically creating parent folders).
  ///
  /// When the existing file already has byte-identical content, no revision bump
  /// or cache invalidation is emitted.
  void writeFile(String path, String content) {
    final norm = normalizePath(path);
    if (norm.isEmpty) {
      throw ArgumentError('File path cannot be empty.');
    }
    if (_files[norm] == content && !_binaryAssets.containsKey(norm)) {
      return;
    }
    final preInvalidated = _hasListeners
        ? <String>{norm, ...transitiveDependentsOf(norm)}
        : <String>{norm};
    final dir = dirname(norm);
    if (dir.isNotEmpty) createFolder(dir);
    _binaryAssets.remove(norm);
    _files[norm] = content;
    _fileFingerprints[norm] = qudsContentFingerprint(content);
    _revision++;
    if (_hasListeners) {
      preInvalidated.addAll(transitiveDependentsOf(norm));
      _emitBatchChange(
        QudsWorkspaceBatchChange(
          changedFiles: {norm},
          deletedFiles: const {},
          invalidatedFiles: preInvalidated,
          unchangedFiles: const {},
          revision: _revision,
          bundleVersion: _bundleVersion,
        ),
      );
    }
  }

  /// Creates or updates a binary asset at [path] (automatically creating parent folders).
  void writeAssetBytes(String path, Uint8List bytes) {
    final norm = normalizePath(path);
    if (norm.isEmpty) {
      throw ArgumentError('Asset path cannot be empty.');
    }
    final dir = dirname(norm);
    if (dir.isNotEmpty) createFolder(dir);
    _files.remove(norm);
    _fileFingerprints.remove(norm);
    _binaryAssets[norm] = Uint8List.fromList(bytes);
    _revision++;
    if (_hasListeners) {
      _emitBatchChange(
        QudsWorkspaceBatchChange(
          changedFiles: {norm},
          deletedFiles: const {},
          invalidatedFiles: {norm},
          unchangedFiles: const {},
          revision: _revision,
          bundleVersion: _bundleVersion,
        ),
      );
    }
  }

  bool get _hasListeners => _listeners.isNotEmpty || _batchListeners.isNotEmpty;

  /// Reads the text content of [path], or returns `null` if not found.
  String? readFile(String path) {
    final norm = normalizePath(path);
    return _files[norm];
  }

  /// Reads raw bytes of [path] (works for both binary assets and UTF-8 text files).
  Uint8List? readAssetBytes(String path) {
    final norm = normalizePath(path);
    final bin = _binaryAssets[norm];
    if (bin != null) return Uint8List.fromList(bin);
    final txt = _files[norm];
    if (txt != null) return Uint8List.fromList(utf8.encode(txt));
    return null;
  }

  /// Returns true if [path] is stored as a binary asset.
  bool isBinaryFile(String path) =>
      _binaryAssets.containsKey(normalizePath(path));

  /// Returns true if a text file exists at [path].
  bool hasFile(String path) => _files.containsKey(normalizePath(path));

  /// Returns true if either a text file or binary asset exists at [path].
  bool hasAnyFile(String path) {
    final norm = normalizePath(path);
    return _files.containsKey(norm) || _binaryAssets.containsKey(norm);
  }

  /// Deletes the text file or binary asset at [path].
  bool deleteFile(String path) {
    final norm = normalizePath(path);
    final preInvalidated = _hasListeners
        ? <String>{norm, ...transitiveDependentsOf(norm)}
        : <String>{norm};
    final removedText = _files.remove(norm) != null;
    _fileFingerprints.remove(norm);
    final removedBin = _binaryAssets.remove(norm) != null;
    final removed = removedText || removedBin;
    if (removed) {
      _revision++;
      if (_hasListeners) {
        _emitBatchChange(
          QudsWorkspaceBatchChange(
            changedFiles: const {},
            deletedFiles: {norm},
            invalidatedFiles: preInvalidated,
            unchangedFiles: const {},
            revision: _revision,
            bundleVersion: _bundleVersion,
          ),
        );
      }
    }
    return removed;
  }

  /// Renames or moves a file or binary asset from [oldPath] to [newPath].
  bool renameFile(String oldPath, String newPath) {
    final oldNorm = normalizePath(oldPath);
    final newNorm = normalizePath(newPath);
    if (oldNorm == newNorm) return false;
    final preInvalidated = _hasListeners
        ? <String>{
            oldNorm,
            newNorm,
            ...transitiveDependentsOf(oldNorm),
            ...transitiveDependentsOf(newNorm),
          }
        : <String>{oldNorm, newNorm};
    if (_files.containsKey(oldNorm)) {
      final content = _files.remove(oldNorm)!;
      final fp =
          _fileFingerprints.remove(oldNorm) ?? qudsContentFingerprint(content);
      final dir = dirname(newNorm);
      if (dir.isNotEmpty) createFolder(dir);
      _files[newNorm] = content;
      _fileFingerprints[newNorm] = fp;
      if (entryPoint == oldNorm) entryPoint = newNorm;
      _revision++;
      if (_hasListeners) {
        preInvalidated.addAll(transitiveDependentsOf(newNorm));
        _emitBatchChange(
          QudsWorkspaceBatchChange(
            changedFiles: {newNorm},
            deletedFiles: {oldNorm},
            invalidatedFiles: preInvalidated,
            unchangedFiles: const {},
            revision: _revision,
            bundleVersion: _bundleVersion,
          ),
        );
      }
      return true;
    }
    if (_binaryAssets.containsKey(oldNorm)) {
      final bytes = _binaryAssets.remove(oldNorm)!;
      final dir = dirname(newNorm);
      if (dir.isNotEmpty) createFolder(dir);
      _binaryAssets[newNorm] = bytes;
      _revision++;
      if (_hasListeners) {
        _emitBatchChange(
          QudsWorkspaceBatchChange(
            changedFiles: {newNorm},
            deletedFiles: {oldNorm},
            invalidatedFiles: {oldNorm, newNorm},
            unchangedFiles: const {},
            revision: _revision,
            bundleVersion: _bundleVersion,
          ),
        );
      }
      return true;
    }
    return false;
  }

  /// Recursively deletes [folderPath] and all nested files/assets/subfolders inside it.
  int deleteFolder(String folderPath) {
    final norm = normalizePath(folderPath);
    if (norm.isEmpty) return 0;
    final prefix = '$norm/';
    final toDelete = [
      for (final f in _files.keys)
        if (f.startsWith(prefix)) f,
      for (final b in _binaryAssets.keys)
        if (b.startsWith(prefix)) b,
    ];
    final invalidated = <String>{...toDelete};
    if (_hasListeners && toDelete.isNotEmpty) {
      for (final f in toDelete) {
        invalidated.addAll(transitiveDependentsOf(f));
      }
    }
    for (final f in toDelete) {
      _files.remove(f);
      _fileFingerprints.remove(f);
      _binaryAssets.remove(f);
    }
    _folders.removeWhere((d) => d == norm || d.startsWith(prefix));
    if (toDelete.isNotEmpty) {
      _revision++;
      if (_hasListeners) {
        _emitBatchChange(
          QudsWorkspaceBatchChange(
            changedFiles: const {},
            deletedFiles: toDelete.toSet(),
            invalidatedFiles: invalidated,
            unchangedFiles: const {},
            revision: _revision,
            bundleVersion: _bundleVersion,
          ),
        );
      }
    }
    return toDelete.length;
  }

  /// Captures an immutable snapshot of the entire workspace (all nested files,
  /// binary assets, folders, entry point, revision, and bundle version) so a
  /// host app can roll back cleanly after a CodePush update.
  QudsWorkspaceSnapshot takeSnapshot() => QudsWorkspaceSnapshot(
        name: name,
        packageName: packageName,
        entryPoint: entryPoint,
        revision: _revision,
        bundleVersion: _bundleVersion,
        files: Map<String, String>.from(_files),
        binaryAssets: {
          for (final e in _binaryAssets.entries)
            e.key: Uint8List.fromList(e.value),
        },
        folders: Set<String>.from(_folders),
      );

  /// Restores a previously captured [snapshot] and notifies listeners of the
  /// exact diff (changed, deleted, and transitively invalidated files).
  QudsCodePushResult restoreSnapshot(QudsWorkspaceSnapshot snapshot) {
    final prevSnapshot = takeSnapshot();
    final changed = <String>{};
    final deleted = <String>{};
    final unchanged = <String>{};

    for (final p in _files.keys) {
      if (!snapshot.files.containsKey(p)) {
        deleted.add(p);
      }
    }
    for (final p in _binaryAssets.keys) {
      if (!snapshot.binaryAssets.containsKey(p)) {
        deleted.add(p);
      }
    }
    for (final entry in snapshot.files.entries) {
      if (_files[entry.key] == entry.value) {
        unchanged.add(entry.key);
      } else {
        changed.add(entry.key);
      }
    }
    for (final entry in snapshot.binaryAssets.entries) {
      changed.add(entry.key);
    }

    final invalidated = <String>{...changed, ...deleted};
    if (changed.isNotEmpty || deleted.isNotEmpty) {
      for (final f in [...changed, ...deleted]) {
        invalidated.addAll(transitiveDependentsOf(f));
      }
    }

    name = snapshot.name;
    packageName = snapshot.packageName;
    entryPoint = snapshot.entryPoint;
    _bundleVersion = snapshot.bundleVersion;
    _files
      ..clear()
      ..addAll(snapshot.files);
    _fileFingerprints
      ..clear()
      ..addEntries(
        snapshot.files.entries.map(
          (e) => MapEntry(e.key, qudsContentFingerprint(e.value)),
        ),
      );
    _binaryAssets
      ..clear()
      ..addEntries(
        snapshot.binaryAssets.entries.map(
          (e) => MapEntry(e.key, Uint8List.fromList(e.value)),
        ),
      );
    _folders
      ..clear()
      ..addAll(snapshot.folders);
    _revision++;

    if (changed.isNotEmpty || deleted.isNotEmpty) {
      for (final f in changed) {
        invalidated.addAll(transitiveDependentsOf(f));
      }
      _emitBatchChange(
        QudsWorkspaceBatchChange(
          changedFiles: changed,
          deletedFiles: deleted,
          invalidatedFiles: invalidated,
          unchangedFiles: unchanged,
          revision: _revision,
          bundleVersion: _bundleVersion,
        ),
      );
    }

    return QudsCodePushResult(
      applied: true,
      revision: _revision,
      bundleVersion: _bundleVersion,
      changedFiles: changed.toList()..sort(),
      deletedFiles: deleted.toList()..sort(),
      unchangedFiles: unchanged.toList()..sort(),
      invalidatedModules: invalidated.toList()..sort(),
      previousSnapshot: prevSnapshot,
    );
  }

  /// Applies a CodePush-style atomic [patch] across arbitrarily nested files
  /// and folders in this workspace.
  ///
  /// - Byte-identical files in [patch.upsertFiles] are automatically skipped so
  ///   their compiled bytecode & runtime modules stay warm.
  /// - When [validateSyntax] is true (default), every new/modified `.quds` file
  ///   is lexed & parsed before mutating the workspace; if any file has a syntax
  ///   error and [atomicRollback] is true, the workspace remains completely
  ///   untouched and [QudsCodePushResult.applied] is `false`.
  /// - Transitive dependents are computed both before and after the patch so
  ///   changed imports, barrel `export`s, and deleted nested modules always
  ///   invalidate every affected dependent cleanly.
  QudsCodePushResult applyPatch(
    QudsWorkspacePatch patch, {
    bool validateSyntax = true,
    bool atomicRollback = true,
  }) {
    final normalizedUpserts = <String, String>{};
    final normalizedBinary = <String, Uint8List>{};
    final normalizedDeleteFiles = <String>{};
    final normalizedDeleteFolders = <String>{};
    final errors = <String>[];

    try {
      for (final entry in patch.upsertFiles.entries) {
        final norm = normalizePath(entry.key);
        if (norm.isEmpty) {
          throw ArgumentError('File path cannot be empty.');
        }
        normalizedUpserts[norm] = entry.value;
      }
      for (final entry in patch.upsertBinaryAssets.entries) {
        final norm = normalizePath(entry.key);
        if (norm.isEmpty) {
          throw ArgumentError('Asset path cannot be empty.');
        }
        normalizedBinary[norm] = entry.value;
      }
      for (final f in patch.deleteFiles) {
        final norm = normalizePath(f);
        if (norm.isNotEmpty) normalizedDeleteFiles.add(norm);
      }
      for (final d in patch.deleteFolders) {
        final norm = normalizePath(d);
        if (norm.isNotEmpty) normalizedDeleteFolders.add(norm);
      }
    } catch (e) {
      return QudsCodePushResult(
        applied: false,
        revision: _revision,
        bundleVersion: _bundleVersion,
        errors: ['$e'],
      );
    }

    // Expand folder deletions to concrete existing paths.
    final expandedDeletes = <String>{};
    for (final f in normalizedDeleteFiles) {
      if (_files.containsKey(f) || _binaryAssets.containsKey(f)) {
        expandedDeletes.add(f);
      }
    }
    for (final dir in normalizedDeleteFolders) {
      final prefix = '$dir/';
      for (final f in _files.keys) {
        if (f.startsWith(prefix)) expandedDeletes.add(f);
      }
      for (final b in _binaryAssets.keys) {
        if (b.startsWith(prefix)) expandedDeletes.add(b);
      }
    }
    // An explicit upsert in the same patch takes precedence over a folder delete.
    expandedDeletes.removeAll(normalizedUpserts.keys);
    expandedDeletes.removeAll(normalizedBinary.keys);

    // Partition upserts into genuinely changed vs byte-identical unchanged files.
    final changed = <String>{};
    final unchanged = <String>{};
    for (final entry in normalizedUpserts.entries) {
      if (_files[entry.key] == entry.value &&
          !_binaryAssets.containsKey(entry.key)) {
        unchanged.add(entry.key);
      } else {
        changed.add(entry.key);
      }
    }
    for (final p in normalizedBinary.keys) {
      changed.add(p);
    }

    // Pre-validate every changed `.quds` file before mutating anything.
    if (validateSyntax) {
      for (final path in changed) {
        if (!path.endsWith('.quds')) continue;
        final src = normalizedUpserts[path];
        if (src == null) continue;
        try {
          final tokens = const Lexer().tokenize(src, file: path);
          Parser(tokens).parse();
        } catch (err) {
          errors.add('$path: $err');
        }
      }
      if (errors.isNotEmpty && atomicRollback) {
        return QudsCodePushResult(
          applied: false,
          revision: _revision,
          bundleVersion: _bundleVersion,
          unchangedFiles: unchanged.toList()..sort(),
          errors: errors,
        );
      }
    }

    final prevSnapshot = takeSnapshot();

    // Compute pre-patch transitive dependents (catches deleted files & removed exports).
    final invalidated = <String>{...changed, ...expandedDeletes};
    if (changed.isNotEmpty || expandedDeletes.isNotEmpty) {
      final preReport = analyzeDependencies();
      final queue = <String>[...changed, ...expandedDeletes];
      final visited = <String>{...queue};
      while (queue.isNotEmpty) {
        final cur = queue.removeAt(0);
        for (final dep in (preReport.importedByFile[cur] ?? const <String>{})) {
          if (visited.add(dep)) {
            invalidated.add(dep);
            queue.add(dep);
          }
        }
      }
    }

    // Apply deletions.
    for (final f in expandedDeletes) {
      _files.remove(f);
      _fileFingerprints.remove(f);
      _binaryAssets.remove(f);
    }
    for (final dir in normalizedDeleteFolders) {
      final prefix = '$dir/';
      _folders.removeWhere((d) => d == dir || d.startsWith(prefix));
    }

    // Apply upserts (creating any new nested parent folders automatically).
    for (final path in changed) {
      final dir = dirname(path);
      if (dir.isNotEmpty) createFolder(dir);
      if (normalizedUpserts.containsKey(path)) {
        final content = normalizedUpserts[path]!;
        _binaryAssets.remove(path);
        _files[path] = content;
        _fileFingerprints[path] = qudsContentFingerprint(content);
      } else if (normalizedBinary.containsKey(path)) {
        _files.remove(path);
        _fileFingerprints.remove(path);
        _binaryAssets[path] = Uint8List.fromList(normalizedBinary[path]!);
      }
    }

    if (patch.newEntryPoint != null && patch.newEntryPoint!.trim().isNotEmpty) {
      entryPoint = normalizePath(patch.newEntryPoint!);
    }
    if (patch.bundleVersion != null) {
      _bundleVersion = patch.bundleVersion;
    }

    final hasDiff = changed.isNotEmpty ||
        expandedDeletes.isNotEmpty ||
        patch.newEntryPoint != null ||
        patch.bundleVersion != null;
    if (hasDiff) {
      _revision++;
    }

    // Compute post-patch transitive dependents (catches newly wired imports).
    if (changed.isNotEmpty || expandedDeletes.isNotEmpty) {
      final postReport = analyzeDependencies();
      final queue = <String>[...changed, ...expandedDeletes];
      final visited = <String>{...queue};
      while (queue.isNotEmpty) {
        final cur = queue.removeAt(0);
        for (final dep
            in (postReport.importedByFile[cur] ?? const <String>{})) {
          if (visited.add(dep)) {
            invalidated.add(dep);
            queue.add(dep);
          }
        }
      }
      _emitBatchChange(
        QudsWorkspaceBatchChange(
          changedFiles: changed,
          deletedFiles: expandedDeletes,
          invalidatedFiles: invalidated,
          unchangedFiles: unchanged,
          revision: _revision,
          bundleVersion: _bundleVersion,
        ),
      );
    }

    return QudsCodePushResult(
      applied: true,
      revision: _revision,
      bundleVersion: _bundleVersion,
      changedFiles: changed.toList()..sort(),
      deletedFiles: expandedDeletes.toList()..sort(),
      unchangedFiles: unchanged.toList()..sort(),
      invalidatedModules: invalidated.toList()..sort(),
      errors: errors,
      previousSnapshot: prevSnapshot,
    );
  }

  /// Lists sorted text file paths, optionally filtered to [inFolder] or [extension].
  List<String> listFiles({String? inFolder, String? extension}) {
    final folderNorm = inFolder == null ? '' : normalizePath(inFolder);
    final prefix = folderNorm.isEmpty ? '' : '$folderNorm/';
    final out = <String>[
      for (final path in _files.keys)
        if ((prefix.isEmpty || path.startsWith(prefix)) &&
            (extension == null || path.endsWith(extension)))
          path,
    ]..sort();
    return out;
  }

  /// Lists all sorted paths (text files AND binary assets), optionally filtered.
  List<String> listAllEntries({String? inFolder, String? extension}) {
    final folderNorm = inFolder == null ? '' : normalizePath(inFolder);
    final prefix = folderNorm.isEmpty ? '' : '$folderNorm/';
    final all = <String>{..._files.keys, ..._binaryAssets.keys};
    final out = <String>[
      for (final path in all)
        if ((prefix.isEmpty || path.startsWith(prefix)) &&
            (extension == null || path.endsWith(extension)))
          path,
    ]..sort();
    return out;
  }

  /// Lists all sorted folder paths in the workspace.
  List<String> listFolders() => _folders.toList()..sort();

  /// Builds a sorted hierarchical directory/file/asset tree rooted at `''`.
  QudsWorkspaceNode buildTree() {
    final dirChildren = <String, Set<String>>{'': <String>{}};
    for (final folder in _folders) {
      dirChildren.putIfAbsent(folder, () => <String>{});
      final parent = dirname(folder);
      dirChildren.putIfAbsent(parent, () => <String>{}).add(folder);
    }
    for (final file in _files.keys) {
      final parent = dirname(file);
      dirChildren.putIfAbsent(parent, () => <String>{}).add(file);
    }
    for (final asset in _binaryAssets.keys) {
      final parent = dirname(asset);
      dirChildren.putIfAbsent(parent, () => <String>{}).add(asset);
    }

    QudsWorkspaceNode buildNode(String path, bool isDir) {
      final base = path.isEmpty
          ? name
          : (path.contains('/')
              ? path.substring(path.lastIndexOf('/') + 1)
              : path);
      if (!isDir) {
        final bin = _binaryAssets[path];
        final isBin = bin != null;
        final size =
            isBin ? bin.length : utf8.encode(_files[path] ?? '').length;
        return QudsWorkspaceNode(
          name: base,
          path: path,
          isDirectory: false,
          isBinary: isBin,
          byteSize: size,
        );
      }
      final rawChildren = (dirChildren[path] ?? const <String>{}).toList();
      final childDirs = <String>[];
      final childFiles = <String>[];
      for (final child in rawChildren) {
        if (_files.containsKey(child) || _binaryAssets.containsKey(child)) {
          childFiles.add(child);
        } else {
          childDirs.add(child);
        }
      }
      childDirs.sort();
      childFiles.sort();
      return QudsWorkspaceNode(
        name: base,
        path: path,
        isDirectory: true,
        children: [
          for (final d in childDirs) buildNode(d, true),
          for (final f in childFiles) buildNode(f, false),
        ],
      );
    }

    return buildNode('', true);
  }

  /// Returns true if [uri] uses an external/builtin scheme rather than a
  /// workspace file import.
  static bool isExternalScheme(String uri) {
    final target = libraryTarget(uri);
    return target.startsWith('quds:') ||
        target.startsWith('dart:') ||
        target.startsWith('host:') ||
        target.startsWith('generated:');
  }

  /// Resolves a Quds import URI (such as `util`, `math.ode.rk4`,
  /// `^.core.constants`, `^^.shared.types`, or `package:<pkg>/src/solver`)
  /// from [fromFile] to a normalized workspace file path, or `null` if not found.
  String? resolveImportPath(String uri, {String? fromFile}) {
    final target = libraryTarget(uri).trim();
    if (target.isEmpty || isExternalScheme(target)) return null;

    // 1. `package:<pkg>` or `package:<pkg>/...` or `package:<pkg>.a.b`
    if (target.startsWith('package:')) {
      final rest = target.substring('package:'.length);
      final slashIdx = rest.indexOf('/');
      final dotIdx = rest.indexOf('.');
      String pkg;
      String subPath = '';
      if (slashIdx >= 0 && (dotIdx < 0 || slashIdx < dotIdx)) {
        pkg = rest.substring(0, slashIdx);
        subPath = rest.substring(slashIdx + 1);
      } else if (dotIdx >= 0) {
        pkg = rest.substring(0, dotIdx);
        subPath = rest.substring(dotIdx + 1).replaceAll('.', '/');
      } else {
        pkg = rest;
      }
      if (packageName != null && pkg != packageName) {
        return null;
      }
      final candidates = <String>[
        if (subPath.isEmpty) ...[
          'lib/$pkg.quds',
          '$pkg.quds',
          'lib/index.quds',
        ] else ...[
          if (subPath.endsWith('.quds'))
            'lib/$subPath'
          else
            'lib/$subPath.quds',
          if (subPath.endsWith('.quds')) subPath else '$subPath.quds',
          'lib/$subPath/index.quds',
          '$subPath/index.quds',
        ],
      ];
      for (final c in candidates) {
        final norm = normalizePath(c);
        if (_files.containsKey(norm)) return norm;
      }
      return null;
    }

    // 2. Relative Quds import (`util`, `src.sum`, `^.common`, `^^^.root_util`)
    final baseDir =
        (fromFile == null || fromFile.isEmpty || fromFile.startsWith('<'))
            ? ''
            : dirname(fromFile);
    final baseSegments = baseDir.isEmpty ? <String>[] : baseDir.split('/');

    var upCount = 0;
    var remainder = target;
    while (remainder.startsWith('^')) {
      upCount++;
      remainder = remainder.substring(1);
    }
    if (upCount > 0) {
      if (remainder.startsWith('.')) {
        remainder = remainder.substring(1);
      } else if (remainder.startsWith('/')) {
        remainder = remainder.substring(1);
      }
      if (upCount > baseSegments.length) {
        return null; // Cannot climb above workspace root
      }
      baseSegments.removeRange(
          baseSegments.length - upCount, baseSegments.length);
    }

    // Support both dot-separated (`a.b.c`) and slash-separated (`a/b/c.quds`)
    final relSegments = remainder.endsWith('.quds')
        ? remainder.substring(0, remainder.length - 5).split('/')
        : remainder.contains('/')
            ? remainder.split('/')
            : remainder.split('.');
    final combined = <String>[
      ...baseSegments,
      for (final s in relSegments)
        if (s.isNotEmpty && s != '.') s,
    ];
    if (combined.isEmpty) return null;

    final directPath = '${combined.join('/')}.quds';
    final normDirect = normalizePath(directPath);
    if (_files.containsKey(normDirect)) return normDirect;

    final indexPath = normalizePath('${combined.join('/')}/index.quds');
    if (_files.containsKey(indexPath)) return indexPath;

    return null;
  }

  /// Computes the Quds dot-import URI needed to import [targetFile] from [fromFile].
  String importUriFor(String targetFile, {String? fromFile}) {
    final targetNorm = normalizePath(targetFile);
    final targetNoExt = targetNorm.endsWith('.quds')
        ? targetNorm.substring(0, targetNorm.length - 5)
        : targetNorm;
    final fromDir =
        (fromFile == null || fromFile.isEmpty || fromFile.startsWith('<'))
            ? ''
            : dirname(fromFile);
    final fromSegs = fromDir.isEmpty ? <String>[] : fromDir.split('/');
    final targetSegs = targetNoExt.split('/');

    var common = 0;
    while (common < fromSegs.length &&
        common < targetSegs.length - 1 &&
        fromSegs[common] == targetSegs[common]) {
      common++;
    }
    final up = fromSegs.length - common;
    final down = targetSegs.sublist(common);
    if (up == 0) {
      return down.join('.');
    }
    return '${'^' * up}.${down.join('.')}';
  }

  /// Statically analyzes imports across every `.quds` file in the workspace,
  /// returning direct/reverse dependencies, unresolved imports, and cycles.
  QudsWorkspaceDependencyReport analyzeDependencies() {
    final importsByFile = <String, Set<String>>{};
    final importedByFile = <String, Set<String>>{};
    final unresolved = <String, List<String>>{};

    for (final path in listFiles(extension: '.quds')) {
      importsByFile[path] = <String>{};
      importedByFile.putIfAbsent(path, () => <String>{});
      final src = _files[path]!;
      try {
        final tokens = const Lexer().tokenize(src, file: path);
        final program = Parser(tokens).parse(partial: true);
        for (final stmt in program.statements) {
          if (stmt is ImportDeclaration) {
            final uri = stmt.uri;
            if (isExternalScheme(uri)) continue;
            final resolved = resolveImportPath(uri, fromFile: path);
            if (resolved != null) {
              importsByFile[path]!.add(resolved);
              importedByFile.putIfAbsent(resolved, () => <String>{}).add(path);
            } else {
              unresolved.putIfAbsent(path, () => []).add(uri);
            }
          }
        }
      } catch (_) {
        // Tolerate syntax errors while editing files in the workspace.
      }
    }

    // Detect cycles using 3-color DFS
    final state = <String, int>{}; // 0=unvisited, 1=visiting, 2=done
    final stack = <String>[];
    final cycles = <List<String>>[];

    void dfs(String node) {
      state[node] = 1;
      stack.add(node);
      for (final next in (importsByFile[node] ?? const <String>{})) {
        final st = state[next] ?? 0;
        if (st == 1) {
          final startIdx = stack.indexOf(next);
          if (startIdx >= 0) {
            cycles.add([...stack.sublist(startIdx), next]);
          }
        } else if (st == 0) {
          dfs(next);
        }
      }
      stack.removeLast();
      state[node] = 2;
    }

    for (final node in importsByFile.keys) {
      if ((state[node] ?? 0) == 0) dfs(node);
    }

    return QudsWorkspaceDependencyReport(
      importsByFile: importsByFile,
      importedByFile: importedByFile,
      unresolvedImports: unresolved,
      cycles: cycles,
    );
  }

  /// Returns all files that directly or transitively import [filePath].
  Set<String> transitiveDependentsOf(String filePath) {
    final norm = normalizePath(filePath);
    final report = analyzeDependencies();
    final visited = <String>{};
    final queue = <String>[...(report.importedByFile[norm] ?? const {})];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (visited.add(cur)) {
        for (final next in (report.importedByFile[cur] ?? const {})) {
          if (!visited.contains(next)) queue.add(next);
        }
      }
    }
    return visited;
  }

  /// Serializes the entire multi-file workspace (including binary assets via
  /// Base64) to a portable `.qproj` JSON map.
  Map<String, Object?> toJson() {
    final sortedBinaryKeys = _binaryAssets.keys.toList()..sort();
    return {
      'format': 'quds-workspace',
      'version': 2,
      'name': name,
      if (packageName != null) 'packageName': packageName,
      if (_bundleVersion != null) 'bundleVersion': _bundleVersion,
      'entryPoint': entryPoint,
      'folders': listFolders(),
      'files': Map<String, String>.fromEntries(
        listFiles().map((p) => MapEntry(p, _files[p]!)),
      ),
      if (sortedBinaryKeys.isNotEmpty)
        'binaryAssets': Map<String, String>.fromEntries(
          sortedBinaryKeys.map(
            (p) => MapEntry(p, base64Encode(_binaryAssets[p]!)),
          ),
        ),
    };
  }

  /// Encodes this workspace as a formatted `.qproj` JSON string.
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Restores a [QudsWorkspace] from a `.qproj` JSON map.
  static QudsWorkspace fromJson(Map<String, Object?> json) {
    final rawFiles = (json['files'] as Map? ?? const {});
    final rawBinary = (json['binaryAssets'] as Map? ?? const {});
    final rawFolders = (json['folders'] as List? ?? const []);
    final decodedBinary = <String, Uint8List>{};
    for (final entry in rawBinary.entries) {
      decodedBinary['${entry.key}'] =
          Uint8List.fromList(base64Decode('${entry.value}'));
    }
    return QudsWorkspace(
      name: (json['name'] as String?) ?? 'quds_project',
      packageName: json['packageName'] as String?,
      entryPoint: (json['entryPoint'] as String?) ?? 'main.quds',
      bundleVersion: json['bundleVersion'] as String?,
      folders: [for (final f in rawFolders) '$f'],
      files: {for (final e in rawFiles.entries) '${e.key}': '${e.value}'},
      binaryAssets: decodedBinary,
    );
  }

  /// Restores a [QudsWorkspace] from a `.qproj` JSON string.
  static QudsWorkspace fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object for QudsWorkspace.');
    }
    return fromJson(decoded);
  }

  /// Creates a ready-to-run MATLAB-style multi-folder scientific project template
  /// demonstrating nested folders, parent `^.` imports, barrel `export`s, and `quds:viz`.
  static QudsWorkspace scientificProjectTemplate() => QudsWorkspace(
        name: 'orbital_lab',
        packageName: 'orbital_lab',
        entryPoint: 'main.quds',
        files: {
          'core/constants.quds': '''# الثوابت الفيزيائية للمشروع
GRAVITY = 9.81
PI = 3.141592653589793
DEFAULT_DT = 0.05
''',
          'math/vec.quds': '''# عمليات المتجهات ثنائية الأبعاد
use dart:math as m

value class BodyState:
  x: double required
  y: double required
  vx: double required
  vy: double required

speed(s: BodyState) -> double:
  return m.sqrt(s.vx * s.vx + s.vy * s.vy)
''',
          'physics/integrator.quds':
              '''# تكامل عددي (Semi-Implicit Euler) يستورد من مجلدات مجاورة عبر ^.
use ^.core.constants show GRAVITY
use ^.math.vec show BodyState

stepProjectile(s: BodyState, dt: double, drag: double = 0.02) -> BodyState:
  ax = -drag * s.vx
  ay = -GRAVITY - drag * s.vy
  nvx = s.vx + ax * dt
  nvy = s.vy + ay * dt
  return BodyState(s.x + nvx * dt, s.y + nvy * dt, nvx, nvy)
''',
          'physics/index.quds': '''# ملف تجميع (Barrel Export) للمحرك الفيزيائي
export integrator show stepProjectile
export ^.math.vec show BodyState, speed
export ^.core.constants show GRAVITY, DEFAULT_DT
''',
          'main.quds': '''# نقطة الدخول الرئيسية للمشروع العلمي متعدد الملفات
use dart:math as m
use quds:viz as viz
use physics.index as phys

v0 = viz.slider("v0", min: 10.0, max: 40.0, value: 22.0, step: 1.0, label: "السرعة الابتدائية")
drag = viz.slider("drag", min: 0.0, max: 0.25, value: 0.03, step: 0.01, label: "مقاومة الهواء")

angle = 0.85
var body = phys.BodyState(0.0, 0.0, v0 * m.cos(angle), v0 * m.sin(angle))
var xs: List<double> = [body.x]
var ys: List<double> = [body.y]
var max_y = 0.0

for k in 1..120:
  body = phys.stepProjectile(body, phys.DEFAULT_DT, drag)
  if body.y < 0.0:
    break
  if body.y > max_y:
    max_y = body.y
  xs.add(body.x)
  ys.add(body.y)

range_x = body.x
final_speed = phys.speed(body)

viz.plot(xs, ys, title: "مسار المقذوف (مشروع متعدد الملفات)", xLabel: "المسافة x (م)", yLabel: "الارتفاع y (م)", color: "#38BDF8")
viz.table(["المقياس", "القيمة"], [["المدى الأفقي (م)", range_x.toStringAsFixed(2)], ["أقصى ارتفاع (م)", max_y.toStringAsFixed(2)], ["السرعة النهائية (م/ث)", final_speed.toStringAsFixed(2)]], title: "ملخص المحاكاة")
print "تمت المحاكاة عبر 4 ملفات متفرعة | المدى = {range_x.toStringAsFixed(2)}م | السرعة النهائية = {final_speed.toStringAsFixed(2)}م/ث"
''',
        },
      );
}
