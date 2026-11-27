/// General-purpose Reactive Scientific Notebook Engine (`QudsNotebook`).
///
/// Splits a Quds document into interactive Markdown and Code cells with:
/// - Static AST/token dependency graph (`definedSymbols` -> `referencedSymbols`)
/// - Automatic reactive downstream re-execution in topological order
/// - Cycle detection across cells
/// - Portable `.qnb` JSON serialization/deserialization
/// - Standalone Markdown & HTML report export with embedded SVGs and tables
///
/// 100% pure Dart (zero `dart:io` or Flutter dependencies).
library;

import 'dart:convert';

import '../ast.dart';
import '../lexer.dart';
import '../parser.dart';
import 'host_bridge.dart';
import 'outputs.dart';
import 'policy.dart';
import 'session.dart';
import 'values.dart';

/// Kind of cell inside a [QudsNotebook].
enum QudsNotebookCellKind { code, markdown }

/// One Markdown or executable Quds code cell inside a [QudsNotebook].
class QudsNotebookCell {
  QudsNotebookCell({
    required this.id,
    required this.kind,
    required this.source,
    Set<String>? definedSymbols,
    Set<String>? referencedSymbols,
    this.lastResult,
    this.executionCount = 0,
    this.dirty = true,
  })  : definedSymbols = definedSymbols ?? <String>{},
        referencedSymbols = referencedSymbols ?? <String>{};

  final String id;
  final QudsNotebookCellKind kind;
  String source;
  Set<String> definedSymbols;
  Set<String> referencedSymbols;
  QudsRunResult? lastResult;
  int executionCount;
  bool dirty;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'source': source,
        'executionCount': executionCount,
      };

  static QudsNotebookCell fromJson(Map<String, Object?> json) =>
      QudsNotebookCell(
        id: json['id'] as String,
        kind: (json['kind'] as String?) == 'markdown'
            ? QudsNotebookCellKind.markdown
            : QudsNotebookCellKind.code,
        source: (json['source'] as String?) ?? '',
        executionCount: (json['executionCount'] as num?)?.toInt() ?? 0,
      );
}

/// Summary of running one cell (with reactive downstream cascade) or the entire notebook.
class QudsNotebookRunSummary {
  const QudsNotebookRunSummary({
    required this.executedCellIds,
    required this.results,
    this.cycleCellIds = const [],
  });

  final List<String> executedCellIds;
  final Map<String, QudsRunResult> results;
  final List<String> cycleCellIds;

  bool get hasCycle => cycleCellIds.isNotEmpty;
  bool get allSucceeded =>
      !hasCycle && results.values.every((r) => r.succeeded);
}

/// Reactive multi-cell Quds notebook powered by [QudsSession].
class QudsNotebook {
  QudsNotebook({
    this.title = 'Untitled Quds Notebook',
    QudsExecutionPolicy? policy,
    List<QudsHostModule> hostModules = const [],
    List<QudsNotebookCell>? cells,
  }) : session = QudsSession(
          policy: policy ?? QudsExecutionPolicy.standard(),
          allowTopLevelRebind: true,
          hostModules: hostModules,
        ) {
    if (cells != null) {
      for (final c in cells) {
        _analyzeCell(c);
        _cells.add(c);
      }
    }
  }

  String title;
  final QudsSession session;
  final List<QudsNotebookCell> _cells = [];
  int _nextId = 1;

  List<QudsNotebookCell> get cells => List.unmodifiable(_cells);

  /// Finds a cell by [id], or returns `null`.
  QudsNotebookCell? cellById(String id) {
    for (final c in _cells) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Adds a new cell to the notebook and analyzes its symbol dependencies.
  QudsNotebookCell addCell(
    QudsNotebookCellKind kind,
    String source, {
    String? id,
    int? index,
  }) {
    final cellId = id ?? 'cell_${_nextId++}';
    final cell = QudsNotebookCell(id: cellId, kind: kind, source: source);
    _analyzeCell(cell);
    if (index != null && index >= 0 && index <= _cells.length) {
      _cells.insert(index, cell);
    } else {
      _cells.add(cell);
    }
    return cell;
  }

  /// Updates [source] of [cellId] and marks it + downstream dependents dirty.
  void updateCell(String cellId, String source) {
    final cell = cellById(cellId);
    if (cell == null) return;
    cell.source = source;
    cell.dirty = true;
    _analyzeCell(cell);
    for (final depId in _downstreamClosure(cellId)) {
      cellById(depId)?.dirty = true;
    }
  }

  /// Removes a cell by [cellId].
  bool removeCell(String cellId) {
    final idx = _cells.indexWhere((c) => c.id == cellId);
    if (idx < 0) return false;
    _cells.removeAt(idx);
    return true;
  }

  /// Reorders a cell from [oldIndex] to [newIndex].
  void moveCell(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _cells.length ||
        newIndex < 0 ||
        newIndex >= _cells.length) {
      return;
    }
    final item = _cells.removeAt(oldIndex);
    _cells.insert(newIndex, item);
  }

  /// Returns the IDs of upstream cells that [cellId] directly depends on.
  Set<String> dependenciesOf(String cellId) {
    final target = cellById(cellId);
    if (target == null || target.kind != QudsNotebookCellKind.code) {
      return const {};
    }
    final deps = <String>{};
    for (final other in _cells) {
      if (other.id == cellId || other.kind != QudsNotebookCellKind.code) {
        continue;
      }
      if (other.definedSymbols.any(target.referencedSymbols.contains)) {
        deps.add(other.id);
      }
    }
    return deps;
  }

  /// Returns the IDs of downstream cells that directly depend on [cellId].
  Set<String> dependentsOf(String cellId) {
    final src = cellById(cellId);
    if (src == null || src.kind != QudsNotebookCellKind.code) {
      return const {};
    }
    final outs = <String>{};
    for (final other in _cells) {
      if (other.id == cellId || other.kind != QudsNotebookCellKind.code) {
        continue;
      }
      if (src.definedSymbols.any(other.referencedSymbols.contains)) {
        outs.add(other.id);
      }
    }
    return outs;
  }

  /// Returns all directed dependency edges `(upstreamCellId, downstreamCellId)`.
  List<(String, String)> dependencyEdges() {
    final edges = <(String, String)>[];
    for (final c in _cells) {
      if (c.kind != QudsNotebookCellKind.code) continue;
      for (final dep in dependentsOf(c.id)) {
        edges.add((c.id, dep));
      }
    }
    return edges;
  }

  /// Runs [cellId] and, when [reactive] is true, automatically re-runs all
  /// transitively dependent downstream cells in topological order.
  Future<QudsNotebookRunSummary> runCell(
    String cellId, {
    bool reactive = true,
  }) async {
    final root = cellById(cellId);
    if (root == null || root.kind != QudsNotebookCellKind.code) {
      return const QudsNotebookRunSummary(executedCellIds: [], results: {});
    }

    final targets = <String>{cellId};
    if (reactive) {
      targets.addAll(_downstreamClosure(cellId));
    }
    return _executeSubset(targets);
  }

  /// Resets the workspace and runs all code cells in dependency order.
  Future<QudsNotebookRunSummary> runAll({bool clearWorkspace = true}) async {
    if (clearWorkspace) {
      session.clear();
    }
    final allCode = {
      for (final c in _cells)
        if (c.kind == QudsNotebookCellKind.code) c.id,
    };
    return _executeSubset(allCode);
  }

  Future<QudsNotebookRunSummary> _executeSubset(Set<String> subset) async {
    final (order, cycle) = _topologicalSort(subset);
    if (cycle.isNotEmpty) {
      return QudsNotebookRunSummary(
        executedCellIds: const [],
        results: const {},
        cycleCellIds: cycle,
      );
    }

    final executed = <String>[];
    final results = <String, QudsRunResult>{};

    for (final id in order) {
      final cell = cellById(id)!;
      final res = await session.run(
        cell.source,
        file: '$id.quds',
        resetVizQuota: true,
      );
      cell.lastResult = res;
      cell.executionCount++;
      cell.dirty = false;
      executed.add(id);
      results[id] = res;
      if (!res.succeeded) {
        // Stop cascading downstream if an upstream cell failed.
        break;
      }
    }

    return QudsNotebookRunSummary(
      executedCellIds: executed,
      results: results,
    );
  }

  Set<String> _downstreamClosure(String startId) {
    final visited = <String>{};
    final queue = <String>[...dependentsOf(startId)];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (visited.add(cur)) {
        for (final next in dependentsOf(cur)) {
          if (!visited.contains(next)) queue.add(next);
        }
      }
    }
    return visited;
  }

  (List<String>, List<String>) _topologicalSort(Set<String> subset) {
    final docOrder = {
      for (var i = 0; i < _cells.length; i++) _cells[i].id: i,
    };
    final inDegree = <String, int>{for (final id in subset) id: 0};
    final adj = <String, List<String>>{for (final id in subset) id: []};

    for (final id in subset) {
      for (final dep in dependenciesOf(id)) {
        if (subset.contains(dep)) {
          adj[dep]!.add(id);
          inDegree[id] = inDegree[id]! + 1;
        }
      }
    }

    final ready = <String>[
      for (final id in subset)
        if (inDegree[id] == 0) id,
    ]..sort((a, b) => (docOrder[a] ?? 0).compareTo(docOrder[b] ?? 0));

    final sorted = <String>[];
    while (ready.isNotEmpty) {
      final cur = ready.removeAt(0);
      sorted.add(cur);
      for (final next in adj[cur]!) {
        final d = inDegree[next]! - 1;
        inDegree[next] = d;
        if (d == 0) {
          ready.add(next);
          ready.sort((a, b) => (docOrder[a] ?? 0).compareTo(docOrder[b] ?? 0));
        }
      }
    }

    if (sorted.length != subset.length) {
      final cycle = [
        for (final id in subset)
          if (!sorted.contains(id)) id,
      ];
      return (const [], cycle);
    }
    return (sorted, const []);
  }

  void _analyzeCell(QudsNotebookCell cell) {
    cell.definedSymbols.clear();
    cell.referencedSymbols.clear();
    if (cell.kind != QudsNotebookCellKind.code || cell.source.trim().isEmpty) {
      return;
    }

    try {
      final tokens =
          const Lexer().tokenize(cell.source, file: '${cell.id}.quds');
      final program = Parser(tokens).parse(partial: true);

      for (final stmt in program.statements) {
        if (stmt is Binding) {
          cell.definedSymbols.add(stmt.name);
        } else if (stmt is FunctionDeclaration) {
          cell.definedSymbols.add(stmt.name);
        } else if (stmt is ClassDeclaration) {
          cell.definedSymbols.add(stmt.name);
        } else if (stmt is ImportDeclaration && stmt.prefix != null) {
          cell.definedSymbols.add(stmt.prefix!);
        }
      }

      // Collect identifier references excluding member accesses (preceded by `.`)
      // and top-level symbols defined within this same cell.
      for (var i = 0; i < tokens.length; i++) {
        final tok = tokens[i];
        if (tok.kind == TokenKind.identifier) {
          final prevKind = i > 0 ? tokens[i - 1].kind : null;
          if (prevKind == TokenKind.dot) continue;
          if (!cell.definedSymbols.contains(tok.lexeme)) {
            cell.referencedSymbols.add(tok.lexeme);
          }
        } else if (tok.kind == TokenKind.string && tok.lexeme.contains('{')) {
          // Capture identifiers inside string interpolations like "val={x + y}"
          final interpRe = RegExp(r'\{([^}]+)\}');
          for (final m in interpRe.allMatches(tok.lexeme)) {
            final inner = m.group(1) ?? '';
            for (final idMatch
                in RegExp(r'\b([A-Za-z_][A-Za-z0-9_]*)\b').allMatches(inner)) {
              final name = idMatch.group(1)!;
              if (!cell.definedSymbols.contains(name)) {
                cell.referencedSymbols.add(name);
              }
            }
          }
        }
      }
    } catch (_) {
      // Incomplete syntax while editing is tolerated gracefully.
    }
  }

  /// Serializes this notebook to portable `.qnb` JSON.
  Map<String, Object?> toJson() => {
        'format': 'quds-notebook',
        'version': 1,
        'title': title,
        'cells': [for (final c in _cells) c.toJson()],
      };

  /// Encodes this notebook as a pretty JSON string (`.qnb`).
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Restores a [QudsNotebook] from `.qnb` JSON map.
  static QudsNotebook fromJson(
    Map<String, Object?> json, {
    QudsExecutionPolicy? policy,
    List<QudsHostModule> hostModules = const [],
  }) {
    final cells = [
      for (final raw in (json['cells'] as List? ?? const []))
        QudsNotebookCell.fromJson((raw as Map).cast<String, Object?>()),
    ];
    return QudsNotebook(
      title: (json['title'] as String?) ?? 'Untitled Quds Notebook',
      policy: policy,
      hostModules: hostModules,
      cells: cells,
    );
  }

  /// Exports this notebook and its latest execution outputs as clean Markdown.
  String exportMarkdown() {
    final buf = StringBuffer()..writeln('# $title\n');
    for (final c in _cells) {
      if (c.kind == QudsNotebookCellKind.markdown) {
        buf.writeln(c.source);
        buf.writeln();
      } else {
        buf.writeln('```quds');
        buf.writeln(c.source.trimRight());
        buf.writeln('```');
        final res = c.lastResult;
        if (res != null) {
          if (res.printedLines.isNotEmpty) {
            buf.writeln('\n```text');
            buf.writeln(res.stdout);
            buf.writeln('```');
          }
          if (!res.succeeded && res.error != null) {
            buf.writeln('\n> **Error:** `${res.error}`');
          }
        }
        buf.writeln();
      }
    }
    return buf.toString();
  }

  /// Exports a self-contained standalone HTML scientific report with embedded
  /// SVGs for geometry scenes, plots, 3D surfaces, vector fields, and graphs.
  String exportHtml() {
    final buf = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en"><head><meta charset="utf-8"/>')
      ..writeln('<title>${_htmlEsc(title)}</title>')
      ..writeln(
          '<style>body{font-family:system-ui,sans-serif;max-width:900px;margin:24px auto;padding:0 16px;background:#0b1220;color:#e2e8f0;line-height:1.6}pre{background:#111c33;padding:12px;border-radius:10px;overflow-x:auto;border:1px solid #1e293b}table{border-collapse:collapse;width:100%;margin:12px 0}th,td{border:1px solid #334155;padding:6px 10px;text-align:left}th{background:#1e293b}.cell{margin:18px 0;padding:14px;border-radius:12px;background:#0f172a;border:1px solid #1e293b}.out{margin-top:10px}.err{color:#f87171}</style>')
      ..writeln('</head><body>')
      ..writeln('<h1>${_htmlEsc(title)}</h1>');

    for (final c in _cells) {
      buf.writeln('<div class="cell" data-cell="${_htmlEsc(c.id)}">');
      if (c.kind == QudsNotebookCellKind.markdown) {
        buf.writeln('<p>${_htmlEsc(c.source).replaceAll('\n', '<br/>')}</p>');
      } else {
        buf.writeln('<pre><code>${_htmlEsc(c.source)}</code></pre>');
        final res = c.lastResult;
        if (res != null) {
          if (res.printedLines.isNotEmpty) {
            buf.writeln(
                '<div class="out"><pre>${_htmlEsc(res.stdout)}</pre></div>');
          }
          for (final out in res.outputs) {
            buf.writeln('<div class="out">');
            if (out is QudsGeometrySceneOutput) {
              buf.writeln(out.toSvg());
            } else if (out is QudsPlot2DOutput) {
              buf.writeln(out.toSvg());
            } else if (out is QudsSurface3DOutput) {
              buf.writeln(out.toSvg());
            } else if (out is QudsVectorFieldOutput) {
              buf.writeln(out.toSvg());
            } else if (out is QudsGraphOutput) {
              buf.writeln(out.toSvg());
            } else if (out is QudsTableOutput) {
              buf.writeln('<table><thead><tr>');
              for (final col in out.columns) {
                buf.writeln('<th>${_htmlEsc(col)}</th>');
              }
              buf.writeln('</tr></thead><tbody>');
              for (final row in out.rows) {
                buf.writeln('<tr>');
                for (final v in row) {
                  buf.writeln('<td>${_htmlEsc(qudsFormatValue(v))}</td>');
                }
                buf.writeln('</tr>');
              }
              buf.writeln('</tbody></table>');
            } else if (out is QudsTextOutput) {
              buf.writeln('<pre>${_htmlEsc(out.text)}</pre>');
            }
            buf.writeln('</div>');
          }
          if (!res.succeeded && res.error != null) {
            buf.writeln('<p class="err">${_htmlEsc('${res.error}')}</p>');
          }
        }
      }
      buf.writeln('</div>');
    }
    buf.writeln('</body></html>');
    return buf.toString();
  }

  Future<void> dispose() => session.dispose();
}

String _htmlEsc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
