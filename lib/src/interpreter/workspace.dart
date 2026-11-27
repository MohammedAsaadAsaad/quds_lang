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

import '../ast.dart';
import '../lexer.dart';
import '../library_uri.dart';
import '../parser.dart';

/// Hierarchical tree node representing either a folder or a file inside [QudsWorkspace].
class QudsWorkspaceNode {
  const QudsWorkspaceNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children = const [],
  });

  final String name;
  final String path;
  final bool isDirectory;
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

/// Callback invoked whenever a file in [QudsWorkspace] is created, edited,
/// renamed, or deleted.
typedef QudsWorkspaceChangeListener = void Function(String normalizedPath);

/// In-memory multi-file, nested-folder project workspace attachable to
/// [QudsSession] and [QudsEditorEngine].
class QudsWorkspace {
  QudsWorkspace({
    this.name = 'quds_project',
    this.packageName,
    this.entryPoint = 'main.quds',
    Map<String, String>? files,
    Iterable<String> folders = const [],
  }) {
    for (final folder in folders) {
      createFolder(folder);
    }
    if (files != null) {
      for (final entry in files.entries) {
        writeFile(entry.key, entry.value);
      }
    }
  }

  String name;
  String? packageName;
  String entryPoint;

  final Map<String, String> _files = {};
  final Set<String> _folders = {};
  final List<QudsWorkspaceChangeListener> _listeners = [];

  /// Registers a listener notified when any file changes.
  void addChangeListener(QudsWorkspaceChangeListener listener) =>
      _listeners.add(listener);

  /// Removes a previously registered change listener.
  void removeChangeListener(QudsWorkspaceChangeListener listener) =>
      _listeners.remove(listener);

  void _notifyChanged(String path) {
    for (final listener in List<QudsWorkspaceChangeListener>.from(_listeners)) {
      listener(path);
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

  /// Returns all files as an unmodifiable map of `normalizedPath -> content`.
  Map<String, String> get files => Map.unmodifiable(_files);

  /// Number of files in this workspace.
  int get fileCount => _files.length;

  /// Creates a folder (and all its parent folders) inside the workspace.
  void createFolder(String folderPath) {
    final norm = normalizePath(folderPath);
    if (norm.isEmpty) return;
    final segments = norm.split('/');
    for (var i = 1; i <= segments.length; i++) {
      _folders.add(segments.sublist(0, i).join('/'));
    }
  }

  /// Creates or updates a file at [path] (automatically creating parent folders).
  void writeFile(String path, String content) {
    final norm = normalizePath(path);
    if (norm.isEmpty) {
      throw ArgumentError('File path cannot be empty.');
    }
    final dir = dirname(norm);
    if (dir.isNotEmpty) createFolder(dir);
    _files[norm] = content;
    _notifyChanged(norm);
  }

  /// Reads the content of [path], or returns `null` if not found.
  String? readFile(String path) {
    final norm = normalizePath(path);
    return _files[norm];
  }

  /// Returns true if a file exists at [path].
  bool hasFile(String path) => _files.containsKey(normalizePath(path));

  /// Deletes the file at [path].
  bool deleteFile(String path) {
    final norm = normalizePath(path);
    final removed = _files.remove(norm) != null;
    if (removed) _notifyChanged(norm);
    return removed;
  }

  /// Renames or moves a file from [oldPath] to [newPath].
  bool renameFile(String oldPath, String newPath) {
    final oldNorm = normalizePath(oldPath);
    final newNorm = normalizePath(newPath);
    if (!_files.containsKey(oldNorm) || oldNorm == newNorm) return false;
    final content = _files.remove(oldNorm)!;
    final dir = dirname(newNorm);
    if (dir.isNotEmpty) createFolder(dir);
    _files[newNorm] = content;
    if (entryPoint == oldNorm) entryPoint = newNorm;
    _notifyChanged(oldNorm);
    _notifyChanged(newNorm);
    return true;
  }

  /// Recursively deletes [folderPath] and all nested files/subfolders inside it.
  int deleteFolder(String folderPath) {
    final norm = normalizePath(folderPath);
    if (norm.isEmpty) return 0;
    final prefix = '$norm/';
    final toDelete = [
      for (final f in _files.keys)
        if (f.startsWith(prefix)) f,
    ];
    for (final f in toDelete) {
      _files.remove(f);
      _notifyChanged(f);
    }
    _folders.removeWhere((d) => d == norm || d.startsWith(prefix));
    return toDelete.length;
  }

  /// Lists sorted file paths, optionally filtered to [inFolder] or [extension].
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

  /// Lists all sorted folder paths in the workspace.
  List<String> listFolders() => _folders.toList()..sort();

  /// Builds a sorted hierarchical directory/file tree rooted at `''`.
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

    QudsWorkspaceNode buildNode(String path, bool isDir) {
      final base = path.isEmpty
          ? name
          : (path.contains('/')
              ? path.substring(path.lastIndexOf('/') + 1)
              : path);
      if (!isDir) {
        return QudsWorkspaceNode(name: base, path: path, isDirectory: false);
      }
      final rawChildren = (dirChildren[path] ?? const <String>{}).toList();
      final childDirs = <String>[];
      final childFiles = <String>[];
      for (final child in rawChildren) {
        if (_files.containsKey(child)) {
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

  /// Serializes the entire multi-file workspace to a portable `.qproj` JSON map.
  Map<String, Object?> toJson() => {
        'format': 'quds-workspace',
        'version': 1,
        'name': name,
        if (packageName != null) 'packageName': packageName,
        'entryPoint': entryPoint,
        'folders': listFolders(),
        'files': Map<String, String>.fromEntries(
          listFiles().map((p) => MapEntry(p, _files[p]!)),
        ),
      };

  /// Encodes this workspace as a formatted `.qproj` JSON string.
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Restores a [QudsWorkspace] from a `.qproj` JSON map.
  static QudsWorkspace fromJson(Map<String, Object?> json) {
    final rawFiles = (json['files'] as Map? ?? const {});
    final rawFolders = (json['folders'] as List? ?? const []);
    return QudsWorkspace(
      name: (json['name'] as String?) ?? 'quds_project',
      packageName: json['packageName'] as String?,
      entryPoint: (json['entryPoint'] as String?) ?? 'main.quds',
      folders: [for (final f in rawFolders) '$f'],
      files: {for (final e in rawFiles.entries) '${e.key}': '${e.value}'},
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
