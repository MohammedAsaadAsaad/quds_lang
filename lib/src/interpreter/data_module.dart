/// Built-in `quds:data` general-purpose tabular DataFrame, CSV/JSON,
/// statistical summary, linear regression, and FFT signal processing module.
///
/// 100% pure Dart (zero `dart:io` or Flutter dependencies).
library;

import 'dart:convert';
import 'dart:math' as math;

import '../source.dart';
import 'exceptions.dart';
import 'host_bridge.dart';
import 'outputs.dart';
import 'values.dart';

/// Builds the built-in `quds:data` [QudsHostModule].
QudsHostModule buildQudsDataModule() {
  final builder = QudsHostModule.builder(
    'quds:data',
    description:
        'Tabular DataFrame (CSV/JSON, filter, sort, groupBy, describe, regression) and FFT signal processing.',
  );

  builder.function(
    'table',
    (pos, named, ctx) {
      final cols = [for (final c in (pos[0] as Iterable)) '$c'];
      final rows = [
        for (final r in (pos[1] as Iterable)) (r as Iterable).toList(),
      ];
      return _buildTableNamespace(cols, rows);
    },
    signature: 'table(columns: List<String>, rows: List<List<Object?>>)',
    documentation: 'Creates a structured DataTable from column names and rows.',
  );

  builder.function(
    'fromMaps',
    (pos, named, ctx) {
      final raw = (pos[0] as Iterable).toList();
      final colSet = <String>{};
      final maps = <Map<String, Object?>>[];
      for (final item in raw) {
        if (item is Map) {
          final m = {for (final e in item.entries) '${e.key}': e.value};
          colSet.addAll(m.keys);
          maps.add(m);
        }
      }
      final cols = colSet.toList();
      final rows = [
        for (final m in maps) [for (final c in cols) m[c]],
      ];
      return _buildTableNamespace(cols, rows);
    },
    signature: 'fromMaps(records: List<Map<String, Object?>>)',
    documentation: 'Builds a DataTable from a list of key-value maps.',
  );

  builder.function(
    'parseCsv',
    (pos, named, ctx) {
      final text = '${pos[0]}';
      final delimiter = (named['delimiter'] as String?) ?? ',';
      final hasHeader = (named['hasHeader'] as bool?) ?? true;
      final autoParseNumbers = (named['parseNumbers'] as bool?) ?? true;
      final parsed = _parseCsvRows(text, delimiter);
      if (parsed.isEmpty) return _buildTableNamespace(const [], const []);
      final cols = hasHeader
          ? parsed.first.map((c) => c.trim()).toList()
          : [for (var i = 0; i < parsed.first.length; i++) 'col_$i'];
      final startIdx = hasHeader ? 1 : 0;
      final rows = <List<Object?>>[];
      for (var i = startIdx; i < parsed.length; i++) {
        final rawRow = parsed[i];
        if (rawRow.length == 1 && rawRow.first.trim().isEmpty) continue;
        rows.add([
          for (var c = 0; c < cols.length; c++)
            c < rawRow.length
                ? _parseCell(rawRow[c].trim(), autoParseNumbers)
                : null,
        ]);
      }
      return _buildTableNamespace(cols, rows);
    },
    signature:
        'parseCsv(csv: String, delimiter: String = ",", hasHeader: bool = true)',
    documentation:
        'Parses CSV text into a DataTable with automatic numeric type detection.',
  );

  builder.function(
    'fromJson',
    (pos, named, ctx) {
      final decoded = jsonDecode('${pos[0]}');
      if (decoded is List) {
        final colSet = <String>{};
        final maps = <Map<String, Object?>>[];
        for (final item in decoded) {
          if (item is Map) {
            final m = {for (final e in item.entries) '${e.key}': e.value};
            colSet.addAll(m.keys);
            maps.add(m);
          }
        }
        final cols = colSet.toList();
        final rows = [
          for (final m in maps) [for (final c in cols) m[c]],
        ];
        return _buildTableNamespace(cols, rows);
      }
      throw QudsRuntimeException(
        'data.fromJson expects a JSON array of objects.',
        ctx.span,
      );
    },
    signature: 'fromJson(jsonString: String)',
    documentation: 'Parses a JSON array of objects into a DataTable.',
  );

  // Pure-Dart Signal Processing: FFT magnitude spectrum (Cooley-Tukey radix-2 + DFT fallback)
  builder.function(
    'fftMagnitude',
    (pos, named, ctx) {
      final samples = [
        for (final v in (pos[0] as Iterable)) (v as num).toDouble(),
      ];
      final sampleRate =
          ((named['sampleRate'] ?? (pos.length > 1 ? pos[1] : 1.0)) as num)
              .toDouble();
      final n = samples.length;
      if (n == 0) {
        return <String, Object?>{
          'freqs': <double>[],
          'magnitudes': <double>[],
          'peakFreq': 0.0,
          'peakMagnitude': 0.0,
        };
      }
      final half = n ~/ 2;
      final (re, im) = _computeSpectrum(samples);
      final freqs = <double>[];
      final mags = <double>[];
      var peakFreq = 0.0;
      var peakMag = -1.0;
      for (var k = 0; k <= half; k++) {
        final f = k * sampleRate / n;
        final scale = (k == 0 || k == half) ? (1.0 / n) : (2.0 / n);
        final mag = math.sqrt(re[k] * re[k] + im[k] * im[k]) * scale;
        freqs.add(f);
        mags.add(mag);
        if (k > 0 && mag > peakMag) {
          peakMag = mag;
          peakFreq = f;
        }
      }
      if (peakMag < 0 && mags.isNotEmpty) {
        peakMag = mags.first;
        peakFreq = freqs.first;
      }
      return <String, Object?>{
        'freqs': freqs,
        'magnitudes': mags,
        'peakFreq': peakFreq,
        'peakMagnitude': peakMag,
      };
    },
    signature:
        'fftMagnitude(samples: List<num>, sampleRate: double = 1.0) -> Map',
    documentation:
        'Computes the single-sided FFT magnitude spectrum returning {freqs, magnitudes, peakFreq, peakMagnitude}.',
  );

  builder.function(
    'convolve',
    (pos, named, ctx) {
      final a = [for (final v in (pos[0] as Iterable)) (v as num).toDouble()];
      final b = [for (final v in (pos[1] as Iterable)) (v as num).toDouble()];
      if (a.isEmpty || b.isEmpty) return <double>[];
      final out = List<double>.filled(a.length + b.length - 1, 0.0);
      for (var i = 0; i < a.length; i++) {
        for (var j = 0; j < b.length; j++) {
          out[i + j] += a[i] * b[j];
        }
      }
      return out;
    },
    signature: 'convolve(a: List<num>, b: List<num>) -> List<double>',
    documentation: 'Computes the discrete linear convolution of two signals.',
  );

  builder.function(
    'normalize',
    (pos, named, ctx) {
      final vals = [
        for (final v in (pos[0] as Iterable)) (v as num).toDouble()
      ];
      if (vals.isEmpty) return <double>[];
      var minV = vals.first;
      var maxV = vals.first;
      for (final v in vals) {
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
      final span = maxV - minV;
      if (span.abs() < 1e-12) return List<double>.filled(vals.length, 0.0);
      return [for (final v in vals) (v - minV) / span];
    },
    signature: 'normalize(values: List<num>) -> List<double>',
    documentation: 'Min-max normalizes a numeric series into [0.0, 1.0].',
  );

  return builder.build();
}

QudsNamespace _buildTableNamespace(
    List<String> columns, List<List<Object?>> rows) {
  int colIndex(String name, SourceSpan span) {
    final idx = columns.indexOf(name);
    if (idx < 0) {
      throw QudsRuntimeException(
        'Column `$name` not found in DataTable (available: ${columns.join(', ')}).',
        span,
      );
    }
    return idx;
  }

  List<double> numericCol(String name, SourceSpan span) {
    final idx = colIndex(name, span);
    final out = <double>[];
    for (final r in rows) {
      final v = r[idx];
      if (v is num) {
        out.add(v.toDouble());
      } else if (v is String) {
        final p = double.tryParse(v);
        if (p != null) out.add(p);
      }
    }
    return out;
  }

  Map<String, Object?> rowAsMap(List<Object?> row) => {
        for (var i = 0; i < columns.length; i++) columns[i]: row[i],
      };

  return QudsNamespace('DataTable', {
    'columns': List<String>.unmodifiable(columns),
    'rows': List<List<Object?>>.unmodifiable(rows),
    'rowCount': rows.length,
    'colCount': columns.length,
    'column': QudsNativeFunction('DataTable.column', (p, n, c) {
      final idx = colIndex('${p[0]}', c.span);
      return [for (final r in rows) r[idx]];
    }),
    'select': QudsNativeFunction('DataTable.select', (p, n, c) {
      final names = [for (final col in (p[0] as Iterable)) '$col'];
      final indices = [for (final name in names) colIndex(name, c.span)];
      final newRows = [
        for (final r in rows) [for (final idx in indices) r[idx]],
      ];
      return _buildTableNamespace(names, newRows);
    }),
    'head': QudsNativeFunction('DataTable.head', (p, n, c) {
      final count =
          (p.isNotEmpty ? (p[0] as num).toInt() : 5).clamp(0, rows.length);
      return _buildTableNamespace(columns, rows.sublist(0, count));
    }),
    'tail': QudsNativeFunction('DataTable.tail', (p, n, c) {
      final count =
          (p.isNotEmpty ? (p[0] as num).toInt() : 5).clamp(0, rows.length);
      return _buildTableNamespace(columns, rows.sublist(rows.length - count));
    }),
    'filter': QudsNativeFunction('DataTable.filter', (p, n, c) async {
      final pred = p[0];
      if (pred is! QudsCallable) {
        throw QudsRuntimeException(
          'DataTable.filter expects a predicate function (row) -> bool.',
          c.span,
        );
      }
      final kept = <List<Object?>>[];
      for (final r in rows) {
        final keep = await c.invokeCallable(pred, [rowAsMap(r)], {}, c.span);
        if (keep == true) kept.add(r);
      }
      return _buildTableNamespace(columns, kept);
    }),
    'sortBy': QudsNativeFunction('DataTable.sortBy', (p, n, c) {
      final idx = colIndex('${p[0]}', c.span);
      final desc = (n['desc'] as bool?) ?? false;
      final copy = List<List<Object?>>.from(rows);
      copy.sort((a, b) {
        final va = a[idx];
        final vb = b[idx];
        int cmp;
        if (va is num && vb is num) {
          cmp = va.compareTo(vb);
        } else {
          cmp = '$va'.compareTo('$vb');
        }
        return desc ? -cmp : cmp;
      });
      return _buildTableNamespace(columns, copy);
    }),
    'groupBy': QudsNativeFunction('DataTable.groupBy', (p, n, c) {
      final gIdx = colIndex('${p[0]}', c.span);
      final aIdx = colIndex('${p[1]}', c.span);
      final op = (n['op'] as String?) ?? (p.length > 2 ? '${p[2]}' : 'mean');
      final groups = <Object?, List<double>>{};
      for (final r in rows) {
        final key = r[gIdx];
        final v = r[aIdx];
        final list = groups.putIfAbsent(key, () => []);
        if (v is num) list.add(v.toDouble());
      }
      final outRows = <List<Object?>>[];
      for (final entry in groups.entries) {
        final vals = entry.value;
        double agg;
        if (op == 'count') {
          agg = vals.length.toDouble();
        } else if (vals.isEmpty) {
          agg = 0.0;
        } else if (op == 'sum') {
          agg = vals.reduce((a, b) => a + b);
        } else if (op == 'min') {
          agg = vals.reduce(math.min);
        } else if (op == 'max') {
          agg = vals.reduce(math.max);
        } else {
          agg = vals.reduce((a, b) => a + b) / vals.length;
        }
        outRows.add([entry.key, agg]);
      }
      return _buildTableNamespace(['${p[0]}', '${op}_${p[1]}'], outRows);
    }),
    'describe': QudsNativeFunction('DataTable.describe', (p, n, c) {
      final vals = numericCol('${p[0]}', c.span);
      if (vals.isEmpty) {
        return <String, Object?>{
          'count': 0,
          'mean': 0.0,
          'std': 0.0,
          'min': 0.0,
          'max': 0.0,
          'median': 0.0,
        };
      }
      vals.sort();
      final count = vals.length;
      final sum = vals.reduce((a, b) => a + b);
      final mean = sum / count;
      var variance = 0.0;
      for (final v in vals) {
        final d = v - mean;
        variance += d * d;
      }
      final std = math.sqrt(variance / count);
      final median = count.isOdd
          ? vals[count ~/ 2]
          : (vals[count ~/ 2 - 1] + vals[count ~/ 2]) / 2.0;
      return <String, Object?>{
        'count': count,
        'mean': mean,
        'std': std,
        'min': vals.first,
        'max': vals.last,
        'median': median,
      };
    }),
    'linearRegression':
        QudsNativeFunction('DataTable.linearRegression', (p, n, c) {
      final xs = numericCol('${p[0]}', c.span);
      final ys = numericCol('${p[1]}', c.span);
      final len = math.min(xs.length, ys.length);
      if (len < 2) {
        return <String, Object?>{'slope': 0.0, 'intercept': 0.0, 'r2': 0.0};
      }
      var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
      for (var i = 0; i < len; i++) {
        sx += xs[i];
        sy += ys[i];
        sxx += xs[i] * xs[i];
        sxy += xs[i] * ys[i];
      }
      final denom = len * sxx - sx * sx;
      final slope = denom.abs() < 1e-12 ? 0.0 : (len * sxy - sx * sy) / denom;
      final intercept = (sy - slope * sx) / len;
      final meanY = sy / len;
      var ssTot = 0.0, ssRes = 0.0;
      for (var i = 0; i < len; i++) {
        final pred = slope * xs[i] + intercept;
        ssRes += (ys[i] - pred) * (ys[i] - pred);
        ssTot += (ys[i] - meanY) * (ys[i] - meanY);
      }
      final r2 = ssTot.abs() < 1e-12 ? 1.0 : 1.0 - (ssRes / ssTot);
      return <String, Object?>{
        'slope': slope,
        'intercept': intercept,
        'r2': r2,
      };
    }),
    'movingAverage': QudsNativeFunction('DataTable.movingAverage', (p, n, c) {
      final vals = numericCol('${p[0]}', c.span);
      final w = (p.length > 1 ? (p[1] as num).toInt() : 3).clamp(1, 10000);
      final out = <double>[];
      var running = 0.0;
      for (var i = 0; i < vals.length; i++) {
        running += vals[i];
        if (i >= w) running -= vals[i - w];
        final denom = i + 1 < w ? i + 1 : w;
        out.add(running / denom);
      }
      return out;
    }),
    'toCsv': QudsNativeFunction('DataTable.toCsv', (p, n, c) {
      final buf = StringBuffer()..writeln(columns.join(','));
      for (final r in rows) {
        buf.writeln(r.map((v) => v == null ? '' : '$v').join(','));
      }
      return buf.toString();
    }),
    'toJson': QudsNativeFunction('DataTable.toJson', (p, n, c) {
      return jsonEncode([for (final r in rows) rowAsMap(r)]);
    }),
    'toVizTable': QudsNativeFunction('DataTable.toVizTable', (p, n, c) {
      final out = QudsTableOutput(
        columns: columns,
        rows: rows,
        title: (n['title'] as String?) ?? (p.isNotEmpty ? '${p[0]}' : null),
      );
      c.emitOutput(out);
      return out;
    }),
    'toVizPlot': QudsNativeFunction('DataTable.toVizPlot', (p, n, c) {
      final xName = '${p[0]}';
      final yName = '${p[1]}';
      final xs = numericCol(xName, c.span);
      final ys = numericCol(yName, c.span);
      final out = QudsPlot2DOutput(
        title: n['title'] as String?,
        xLabel: (n['xLabel'] as String?) ?? xName,
        yLabel: (n['yLabel'] as String?) ?? yName,
        series: [
          QudsPlotSeries(
            xs: xs,
            ys: ys,
            name: yName,
            kind: (n['kind'] as String?) ?? 'line',
            color: (n['color'] as String?) ?? '#10B981',
          ),
        ],
      );
      c.emitOutput(out);
      return out;
    }),
  });
}

Object? _parseCell(String raw, bool autoNumbers) {
  if (raw.isEmpty) return '';
  if (autoNumbers) {
    final asInt = int.tryParse(raw);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(raw);
    if (asDouble != null) return asDouble;
  }
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  return raw;
}

List<List<String>> _parseCsvRows(String text, String delimiter) {
  final sep = delimiter.isEmpty ? ',' : delimiter[0];
  final rows = <List<String>>[];
  final currentRow = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == sep) {
      currentRow.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      currentRow.add(cell.toString());
      cell.clear();
      rows.add(List<String>.from(currentRow));
      currentRow.clear();
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || currentRow.isNotEmpty) {
    currentRow.add(cell.toString());
    rows.add(currentRow);
  }
  return rows;
}

(List<double>, List<double>) _computeSpectrum(List<double> samples) {
  final n = samples.length;
  final isPow2 = n > 0 && (n & (n - 1)) == 0;
  if (isPow2) {
    final re = List<double>.from(samples);
    final im = List<double>.filled(n, 0.0);
    // Bit-reversal permutation
    var j = 0;
    for (var i = 1; i < n; i++) {
      var bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
      }
    }
    for (var len = 2; len <= n; len <<= 1) {
      final ang = -2.0 * math.pi / len;
      final wlenR = math.cos(ang);
      final wlenI = math.sin(ang);
      for (var i = 0; i < n; i += len) {
        var wr = 1.0;
        var wi = 0.0;
        for (var k = 0; k < len ~/ 2; k++) {
          final ur = re[i + k];
          final ui = im[i + k];
          final vr = re[i + k + len ~/ 2] * wr - im[i + k + len ~/ 2] * wi;
          final vi = re[i + k + len ~/ 2] * wi + im[i + k + len ~/ 2] * wr;
          re[i + k] = ur + vr;
          im[i + k] = ui + vi;
          re[i + k + len ~/ 2] = ur - vr;
          im[i + k + len ~/ 2] = ui - vi;
          final nextWr = wr * wlenR - wi * wlenI;
          wi = wr * wlenI + wi * wlenR;
          wr = nextWr;
        }
      }
    }
    return (re, im);
  }

  // Exact DFT fallback for arbitrary sample lengths
  final re = List<double>.filled(n, 0.0);
  final im = List<double>.filled(n, 0.0);
  for (var k = 0; k < n; k++) {
    var sr = 0.0;
    var si = 0.0;
    for (var t = 0; t < n; t++) {
      final angle = -2.0 * math.pi * k * t / n;
      sr += samples[t] * math.cos(angle);
      si += samples[t] * math.sin(angle);
    }
    re[k] = sr;
    im[k] = si;
  }
  return (re, im);
}
