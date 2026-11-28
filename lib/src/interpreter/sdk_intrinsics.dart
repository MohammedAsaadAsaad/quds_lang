/// Native Dart AOT-speed intrinsics for read-only built-in `quds:*` SDK
/// libraries when executed inside the Quds interpreter / Register VM.
///
/// Pure Dart (zero `dart:io` imports). Preserves exact SDK validation, thrown
/// values/errors, Unicode/UAX #29 semantics, and return types while executing
/// hot numerical, JSON, collection, and text kernels at native Dart speed.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../source.dart';
import 'environment.dart';
import 'exceptions.dart';
import 'values.dart';

/// Installs native Dart intrinsics for supported read-only `quds:*` SDK
/// libraries into [modEnv], [publicExports], and [sectionExports].
void installQudsSdkIntrinsics(
  String targetUri,
  QudsEnvironment modEnv,
  Map<String, Object?> publicExports,
  Map<String, Map<String, Object?>> sectionExports,
) {
  switch (targetUri) {
    case 'quds:math':
      installQudsMathIntrinsics(modEnv, publicExports, sectionExports);
    case 'quds:json':
      installQudsJsonIntrinsics(modEnv, publicExports, sectionExports);
    case 'quds:collection':
      installQudsCollectionIntrinsics(modEnv, publicExports, sectionExports);
    case 'quds:text':
      installQudsTextIntrinsics(modEnv, publicExports, sectionExports);
  }
}

void _patchExports(
  QudsEnvironment modEnv,
  Map<String, Object?> publicExports,
  Map<String, Map<String, Object?>> sectionExports,
  Map<String, QudsNativeFunction> intrinsics,
) {
  for (final entry in intrinsics.entries) {
    final name = entry.key;
    final fn = entry.value;
    if (modEnv.localSlots.containsKey(name)) {
      modEnv.localSlots[name]!.value = fn;
    }
    if (publicExports.containsKey(name)) {
      publicExports[name] = fn;
    }
    for (final sec in sectionExports.values) {
      if (sec.containsKey(name)) {
        sec[name] = fn;
      }
    }
  }
}

T _optArg<T>(
  List<Object?> positional,
  Map<String, Object?> named,
  int posIndex,
  String name,
  T defaultValue,
) {
  if (named.containsKey(name)) return named[name] as T;
  if (posIndex < positional.length) return positional[posIndex] as T;
  return defaultValue;
}

// ============================================================================
// quds:math intrinsics (Linear Algebra, Tensor, Sparse, Number, Stats, FFT)
// ============================================================================

final BigInt _bigMaxInt64 = BigInt.parse('7fffffffffffffff', radix: 16);

/// Replaces hot read-only `quds:math` functions with equivalent native Dart
/// implementations in [modEnv], [publicExports], and [sectionExports].
///
/// Because `Matrices`, `Tensor`, and `SparseMatrix` operators close over
/// [modEnv], installing these intrinsics automatically accelerates `~A`,
/// `A * B`, `A * v`, `A * s`, `A - B`, `T1 + T2`, `T1 * T2`, and `S * v` too.
void installQudsMathIntrinsics(
  QudsEnvironment modEnv,
  Map<String, Object?> publicExports,
  Map<String, Map<String, Object?>> sectionExports,
) {
  final tensorClass = modEnv.localSlots['Tensor']?.value as QudsClass?;
  final complexClass = modEnv.localSlots['Complex']?.value as QudsClass?;

  final intrinsics = <String, QudsNativeFunction>{
    // --- Linear Algebra ---
    'transpose': QudsNativeFunction('transpose', (p, n, c) {
      final rows = _asMatrix(p[0], c.span, allowEmpty: true);
      if (rows.isEmpty) return <List<double>>[];
      final width = rows[0].length;
      for (var i = 1; i < rows.length; i++) {
        if (rows[i].length != width) {
          throw _qudsThrow('transpose needs a rectangular matrix', c.span);
        }
      }
      final height = rows.length;
      return List<List<double>>.generate(
        width,
        (col) => List<double>.generate(
          height,
          (r) => rows[r][col],
          growable: true,
        ),
        growable: true,
      );
    }, isSync: true),
    'matmul': QudsNativeFunction('matmul', (p, n, c) {
      final left = _asMatrix(p[0], c.span, allowEmpty: true);
      final right = _asMatrix(p[1], c.span, allowEmpty: true);
      if (left.isEmpty || right.isEmpty) {
        throw _qudsThrow('matmul needs non-empty matrices', c.span);
      }
      final shared = left[0].length;
      if (right.length != shared) {
        throw _qudsThrow(
          'matmul columns of the left must match rows of the right',
          c.span,
        );
      }
      final outWidth = right[0].length;
      for (var r = 0; r < left.length; r++) {
        if (left[r].length != shared) {
          throw _qudsThrow('matmul needs rectangular matrices', c.span);
        }
      }
      for (var k = 0; k < shared; k++) {
        if (right[k].length != outWidth) {
          throw _qudsThrow('matmul needs rectangular matrices', c.span);
        }
      }
      final outRows = left.length;
      final made = List<List<double>>.generate(
        outRows,
        (_) => List<double>.filled(outWidth, 0.0, growable: true),
        growable: true,
      );
      for (var i = 0; i < outRows; i++) {
        final aRow = left[i];
        final cRow = made[i];
        for (var k = 0; k < shared; k++) {
          final aik = aRow[k];
          if (aik == 0.0) continue;
          final bRow = right[k];
          for (var j = 0; j < outWidth; j++) {
            cRow[j] += aik * bRow[j];
          }
        }
      }
      return made;
    }, isSync: true),
    'matvec': QudsNativeFunction('matvec', (p, n, c) {
      final grid = _rectCopy(p[0], c.span);
      final values = _asVector(p[1], c.span);
      final width = grid[0].length;
      if (values.length != width) {
        throw _qudsThrow('matvec columns must match the vector', c.span);
      }
      return List<double>.generate(grid.length, (i) {
        final row = grid[i];
        var sum = 0.0;
        for (var j = 0; j < width; j++) {
          sum += row[j] * values[j];
        }
        return sum;
      }, growable: true);
    }, isSync: true),
    'addMatrices': QudsNativeFunction('addMatrices', (p, n, c) {
      return _blendMatrices(p[0], p[1], 1.0, c.span);
    }, isSync: true),
    'subtractMatrices': QudsNativeFunction('subtractMatrices', (p, n, c) {
      return _blendMatrices(p[0], p[1], -1.0, c.span);
    }, isSync: true),
    'scaleMatrix': QudsNativeFunction('scaleMatrix', (p, n, c) {
      final grid = _rectCopy(p[0], c.span);
      final factor = (p[1] as num).toDouble();
      return List<List<double>>.generate(
        grid.length,
        (i) {
          final row = grid[i];
          return List<double>.generate(
            row.length,
            (j) => row[j] * factor,
            growable: true,
          );
        },
        growable: true,
      );
    }, isSync: true),
    'hadamard': QudsNativeFunction('hadamard', (p, n, c) {
      final left = _rectCopy(p[0], c.span);
      final right = _rectCopy(p[1], c.span);
      final width = _sameShape(left, right, c.span);
      return List<List<double>>.generate(
        left.length,
        (r) => List<double>.generate(
          width,
          (col) => left[r][col] * right[r][col],
          growable: true,
        ),
        growable: true,
      );
    }, isSync: true),
    'dot': QudsNativeFunction('dot', (p, n, c) {
      final left = _asVector(p[0], c.span);
      final right = _asVector(p[1], c.span);
      if (left.length != right.length || left.isEmpty) {
        throw _qudsThrow(
          'dot needs two vectors of the same length',
          c.span,
        );
      }
      var sum = 0.0;
      for (var i = 0; i < left.length; i++) {
        sum += left[i] * right[i];
      }
      return sum;
    }, isSync: true),
    'outer': QudsNativeFunction('outer', (p, n, c) {
      final left = _asVector(p[0], c.span);
      final right = _asVector(p[1], c.span);
      if (left.isEmpty || right.isEmpty) {
        throw _qudsThrow('outer needs non-empty vectors', c.span);
      }
      return List<List<double>>.generate(
        left.length,
        (i) {
          final a = left[i];
          return List<double>.generate(
            right.length,
            (j) => a * right[j],
            growable: true,
          );
        },
        growable: true,
      );
    }, isSync: true),
    'trace': QudsNativeFunction('trace', (p, n, c) {
      final grid = _squareCopy(p[0], c.span);
      var total = 0.0;
      for (var i = 0; i < grid.length; i++) {
        total += grid[i][i];
      }
      return total;
    }, isSync: true),
    'vectorLength': QudsNativeFunction('vectorLength', (p, n, c) {
      final values = _asVector(p[0], c.span);
      if (values.isEmpty) {
        throw _qudsThrow('vectorLength needs a vector', c.span);
      }
      var total = 0.0;
      for (var i = 0; i < values.length; i++) {
        total = _hypot(total, values[i]);
      }
      return total;
    }, isSync: true),
    'frobenius': QudsNativeFunction('frobenius', (p, n, c) {
      final grid = _rectCopy(p[0], c.span);
      var total = 0.0;
      for (final row in grid) {
        var rowNorm = 0.0;
        for (final v in row) {
          rowNorm = _hypot(rowNorm, v);
        }
        total = _hypot(total, rowNorm);
      }
      return total;
    }, isSync: true),
    'rowSums': QudsNativeFunction('rowSums', (p, n, c) {
      final grid = _rectCopy(p[0], c.span);
      return List<double>.generate(grid.length, (i) {
        var sum = 0.0;
        for (final v in grid[i]) {
          sum += v;
        }
        return sum;
      }, growable: true);
    }, isSync: true),
    'columnSums': QudsNativeFunction('columnSums', (p, n, c) {
      final grid = _rectCopy(p[0], c.span);
      final width = grid[0].length;
      final out = List<double>.filled(width, 0.0, growable: true);
      for (final row in grid) {
        for (var j = 0; j < width; j++) {
          out[j] += row[j];
        }
      }
      return out;
    }, isSync: true),
    'identity': QudsNativeFunction('identity', (p, n, c) {
      final size = (p[0] as num).toInt();
      if (size < 1) {
        throw _qudsThrow('identity needs a positive size', c.span);
      }
      return List<List<double>>.generate(size, (i) {
        final row = List<double>.filled(size, 0.0, growable: true);
        row[i] = 1.0;
        return row;
      }, growable: true);
    }, isSync: true),
    'norm1': QudsNativeFunction('norm1', (p, n, c) {
      final grid = _rectCopy(p[0], c.span);
      final width = grid[0].length;
      var best = 0.0;
      for (var col = 0; col < width; col++) {
        var total = 0.0;
        for (var r = 0; r < grid.length; r++) {
          total += grid[r][col].abs();
        }
        if (total > best) best = total;
      }
      return best;
    }, isSync: true),
    'normInf': QudsNativeFunction('normInf', (p, n, c) {
      final grid = _rectCopy(p[0], c.span);
      var best = 0.0;
      for (final row in grid) {
        var total = 0.0;
        for (final v in row) {
          total += v.abs();
        }
        if (total > best) best = total;
      }
      return best;
    }, isSync: true),
    'determinant': QudsNativeFunction('determinant', (p, n, c) {
      final grid = _squareCopy(p[0], c.span);
      final size = grid.length;
      var sign = 1.0;
      for (var col = 0; col < size; col++) {
        var pivot = col;
        var best = grid[col][col].abs();
        for (var r = col + 1; r < size; r++) {
          final mag = grid[r][col].abs();
          if (mag > best) {
            best = mag;
            pivot = r;
          }
        }
        if (grid[pivot][col] == 0.0) return 0.0;
        if (pivot != col) {
          final tmp = grid[col];
          grid[col] = grid[pivot];
          grid[pivot] = tmp;
          sign = -sign;
        }
        final pivotRow = grid[col];
        final pivotVal = pivotRow[col];
        for (var below = col + 1; below < size; below++) {
          final row = grid[below];
          final factor = row[col] / pivotVal;
          row[col] = 0.0;
          for (var j = col + 1; j < size; j++) {
            row[j] -= factor * pivotRow[j];
          }
        }
      }
      var diag = sign;
      for (var i = 0; i < size; i++) {
        diag *= grid[i][i];
      }
      return diag;
    }, isSync: true),
    'solveLinear': QudsNativeFunction('solveLinear', (p, n, c) {
      final grid = _squareCopy(p[0], c.span);
      final rhs = _asVector(p[1], c.span, copy: true);
      final size = grid.length;
      if (rhs.length != size) {
        throw _qudsThrow('solveLinear needs a square system', c.span);
      }
      for (var col = 0; col < size; col++) {
        var pivot = col;
        var best = grid[col][col].abs();
        for (var r = col + 1; r < size; r++) {
          final mag = grid[r][col].abs();
          if (mag > best) {
            best = mag;
            pivot = r;
          }
        }
        if (grid[pivot][col] == 0.0) {
          throw _qudsThrow(
            'solveLinear needs an invertible matrix',
            c.span,
          );
        }
        if (pivot != col) {
          final tmpRow = grid[col];
          grid[col] = grid[pivot];
          grid[pivot] = tmpRow;
          final tmpRhs = rhs[col];
          rhs[col] = rhs[pivot];
          rhs[pivot] = tmpRhs;
        }
        final pivotRow = grid[col];
        final pivotVal = pivotRow[col];
        for (var other = 0; other < size; other++) {
          if (other == col) continue;
          final row = grid[other];
          final factor = row[col] / pivotVal;
          row[col] = 0.0;
          for (var j = col + 1; j < size; j++) {
            row[j] -= factor * pivotRow[j];
          }
          rhs[other] -= factor * rhs[col];
        }
      }
      return List<double>.generate(
        size,
        (i) => rhs[i] / grid[i][i],
        growable: true,
      );
    }, isSync: true),
    'inverse': QudsNativeFunction('inverse', (p, n, c) {
      final grid = _squareCopy(p[0], c.span);
      final size = grid.length;
      final inv = List<List<double>>.generate(size, (i) {
        final row = List<double>.filled(size, 0.0, growable: true);
        row[i] = 1.0;
        return row;
      }, growable: true);
      for (var col = 0; col < size; col++) {
        var pivot = col;
        var best = grid[col][col].abs();
        for (var r = col + 1; r < size; r++) {
          final mag = grid[r][col].abs();
          if (mag > best) {
            best = mag;
            pivot = r;
          }
        }
        if (grid[pivot][col] == 0.0) {
          throw _qudsThrow('inverse needs an invertible matrix', c.span);
        }
        if (pivot != col) {
          final tmpG = grid[col];
          grid[col] = grid[pivot];
          grid[pivot] = tmpG;
          final tmpI = inv[col];
          inv[col] = inv[pivot];
          inv[pivot] = tmpI;
        }
        final pivotVal = grid[col][col];
        final pG = grid[col];
        final pI = inv[col];
        for (var j = 0; j < size; j++) {
          pG[j] /= pivotVal;
          pI[j] /= pivotVal;
        }
        for (var other = 0; other < size; other++) {
          if (other == col) continue;
          final factor = grid[other][col];
          if (factor == 0.0) continue;
          final rG = grid[other];
          final rI = inv[other];
          for (var j = 0; j < size; j++) {
            rG[j] -= factor * pG[j];
            rI[j] -= factor * pI[j];
          }
        }
      }
      return inv;
    }, isSync: true),
    'sparseMultiply': QudsNativeFunction('sparseMultiply', (p, n, c) {
      final mat = p[0] as QudsInstance;
      final vec = _asVector(p[1], c.span);
      final size = (mat.fields['size'] as num).toInt();
      if (vec.length != size) {
        throw _qudsThrow(
          'sparseMultiply needs one value per row',
          c.span,
        );
      }
      final rowStart = mat.fields['rowStart'] as List;
      final columns = mat.fields['columns'] as List;
      final entries = mat.fields['entries'] as List;
      final out = List<double>.filled(size, 0.0, growable: true);
      for (var row = 0; row < size; row++) {
        final start = (rowStart[row] as num).toInt();
        final stop = (rowStart[row + 1] as num).toInt();
        var sum = 0.0;
        for (var cursor = start; cursor < stop; cursor++) {
          sum += (entries[cursor] as num).toDouble() *
              vec[(columns[cursor] as num).toInt()];
        }
        out[row] = sum;
      }
      return out;
    }, isSync: true),

    // --- Number Theory ---
    'gcd': QudsNativeFunction('gcd', (p, n, c) {
      final a = (p[0] as num).toInt();
      final b = (p[1] as num).toInt();
      final g = _gcdInt(a, b, c.span);
      return g;
    }, isSync: true),
    'lcm': QudsNativeFunction('lcm', (p, n, c) {
      final a = (p[0] as num).toInt();
      final b = (p[1] as num).toInt();
      if (a == 0 || b == 0) return 0;
      final g = _gcdInt(a, b, c.span);
      final prod = (BigInt.from(a) ~/ BigInt.from(g)) * BigInt.from(b);
      final absProd = prod.abs();
      if (absProd > _bigMaxInt64) {
        throw _qudsThrow('lcm result is outside int range', c.span);
      }
      return absProd.toInt();
    }, isSync: true),
    'modPow': QudsNativeFunction('modPow', (p, n, c) {
      final base = (p[0] as num).toInt();
      final exp = (p[1] as num).toInt();
      final mod = (p[2] as num).toInt();
      if (mod <= 0) throw _qudsThrow('modPow needs a positive modulus', c.span);
      if (exp < 0) {
        throw _qudsThrow('modPow needs a non-negative exponent', c.span);
      }
      if (mod == 1) return 0;
      return _modPowInt(base, exp, mod);
    }, isSync: true),
    'isPrime': QudsNativeFunction('isPrime', (p, n, c) {
      return _isProbablePrimeInt((p[0] as num).toInt());
    }, isSync: true),
    'isProbablePrime': QudsNativeFunction('isProbablePrime', (p, n, c) {
      return _isProbablePrimeInt((p[0] as num).toInt());
    }, isSync: true),
    'primesUpTo': QudsNativeFunction('primesUpTo', (p, n, c) {
      final limit = (p[0] as num).toInt();
      if (limit < 2) return <int>[];
      final marks = Uint8List(limit + 1);
      marks.fillRange(2, limit + 1, 1);
      for (var k = 2; k * k <= limit; k++) {
        if (marks[k] == 1) {
          for (var m = k * k; m <= limit; m += k) {
            marks[m] = 0;
          }
        }
      }
      final out = <int>[];
      for (var i = 2; i <= limit; i++) {
        if (marks[i] == 1) out.add(i);
      }
      return out;
    }, isSync: true),

    // --- Statistics ---
    'kahanSum': QudsNativeFunction('kahanSum', (p, n, c) {
      final values = _asVector(p[0], c.span);
      return _kahanSumDoubles(values);
    }, isSync: true),
    'mean': QudsNativeFunction('mean', (p, n, c) {
      final values = _asVector(p[0], c.span);
      if (values.isEmpty) throw _qudsThrow('mean of an empty list', c.span);
      return _meanDoubles(values);
    }, isSync: true),
    'median': QudsNativeFunction('median', (p, n, c) {
      final values = _asFloat64Copy(p[0], c.span);
      if (values.isEmpty) throw _qudsThrow('median of an empty list', c.span);
      final mid = values.length ~/ 2;
      final hiVal = _selectFloat64(values, mid);
      if (values.length.isOdd) return hiVal;
      var loVal = values[0];
      for (var i = 1; i < mid; i++) {
        if (values[i] > loVal) loVal = values[i];
      }
      return loVal / 2.0 + hiVal / 2.0;
    }, isSync: true),
    'minimum': QudsNativeFunction('minimum', (p, n, c) {
      final values = _asVector(p[0], c.span);
      if (values.isEmpty) throw _qudsThrow('minimum of an empty list', c.span);
      var best = values[0];
      for (var i = 1; i < values.length; i++) {
        if (values[i] < best) best = values[i];
      }
      return best;
    }, isSync: true),
    'maximum': QudsNativeFunction('maximum', (p, n, c) {
      final values = _asVector(p[0], c.span);
      if (values.isEmpty) throw _qudsThrow('maximum of an empty list', c.span);
      var best = values[0];
      for (var i = 1; i < values.length; i++) {
        if (values[i] > best) best = values[i];
      }
      return best;
    }, isSync: true),
    'variance': QudsNativeFunction('variance', (p, n, c) {
      final values = _asVector(p[0], c.span);
      if (values.length < 2) {
        throw _qudsThrow('variance needs at least two values', c.span);
      }
      return _varianceDoubles(values, (values.length - 1).toDouble());
    }, isSync: true),
    'populationVariance': QudsNativeFunction('populationVariance', (p, n, c) {
      final values = _asVector(p[0], c.span);
      if (values.isEmpty) {
        throw _qudsThrow('populationVariance of an empty list', c.span);
      }
      return _varianceDoubles(values, values.length.toDouble());
    }, isSync: true),
    'stddev': QudsNativeFunction('stddev', (p, n, c) {
      final values = _asVector(p[0], c.span);
      if (values.length < 2) {
        throw _qudsThrow('stddev needs at least two values', c.span);
      }
      return _spreadDoubles(values, (values.length - 1).toDouble());
    }, isSync: true),
    'populationStddev': QudsNativeFunction('populationStddev', (p, n, c) {
      final values = _asVector(p[0], c.span);
      if (values.isEmpty) {
        throw _qudsThrow('populationStddev of an empty list', c.span);
      }
      return _spreadDoubles(values, values.length.toDouble());
    }, isSync: true),
    'percentile': QudsNativeFunction('percentile', (p, n, c) {
      final values = _asFloat64Copy(p[0], c.span);
      final percent = (p[1] as num).toDouble();
      if (values.isEmpty) {
        throw _qudsThrow('percentile of an empty list', c.span);
      }
      if (percent < 0.0 || percent > 100.0) {
        throw _qudsThrow('percent must be from 0 through 100', c.span);
      }
      if (values.length == 1) return values[0];
      final place = percent / 100.0 * (values.length - 1).toDouble();
      final lo = place.floor();
      final hi = place.ceil();
      final hiVal = _selectFloat64(values, hi);
      if (lo == hi) return hiVal;
      var loVal = values[0];
      for (var i = 1; i < hi; i++) {
        if (values[i] > loVal) loVal = values[i];
      }
      final frac = place - lo.toDouble();
      return loVal * (1.0 - frac) + hiVal * frac;
    }, isSync: true),
    'covariance': QudsNativeFunction('covariance', (p, n, c) {
      final xs = _asVector(p[0], c.span);
      final ys = _asVector(p[1], c.span);
      if (xs.length != ys.length) {
        throw _qudsThrow('covariance needs lists of the same length', c.span);
      }
      if (xs.length < 2) {
        throw _qudsThrow('covariance needs at least two pairs', c.span);
      }
      final mx = _meanDoubles(xs);
      final my = _meanDoubles(ys);
      var total = 0.0;
      for (var i = 0; i < xs.length; i++) {
        total += (xs[i] - mx) * (ys[i] - my);
      }
      return total / (xs.length - 1).toDouble();
    }, isSync: true),
    'correlation': QudsNativeFunction('correlation', (p, n, c) {
      final xs = _asVector(p[0], c.span);
      final ys = _asVector(p[1], c.span);
      if (xs.length != ys.length) {
        throw _qudsThrow('correlation needs matching lists', c.span);
      }
      if (xs.length < 2) {
        throw _qudsThrow('stddev needs at least two values', c.span);
      }
      final denom = (xs.length - 1).toDouble();
      final sx = _spreadDoubles(xs, denom);
      final sy = _spreadDoubles(ys, denom);
      if (sx == 0.0 || sy == 0.0) {
        throw _qudsThrow(
          'correlation is undefined for a constant list',
          c.span,
        );
      }
      final mx = _meanDoubles(xs);
      final my = _meanDoubles(ys);
      var sum = 0.0;
      var comp = 0.0;
      for (var i = 0; i < xs.length; i++) {
        final term =
            _diffRatio(xs[i], mx, sx) * _diffRatio(ys[i], my, sy) / denom;
        final t = sum + term;
        if (!t.isFinite) {
          sum = t;
          comp = 0.0;
        } else {
          if (sum.abs() >= term.abs()) {
            comp += (sum - t) + term;
          } else {
            comp += (term - t) + sum;
          }
          sum = t;
        }
      }
      final r = sum + comp;
      if (r < -1.0) return -1.0;
      if (r > 1.0) return 1.0;
      return r;
    }, isSync: true),
    'softmax': QudsNativeFunction('softmax', (p, n, c) {
      final values = _asVector(p[0], c.span);
      if (values.isEmpty) throw _qudsThrow('softmax of an empty list', c.span);
      var peak = values[0];
      for (var i = 1; i < values.length; i++) {
        if (values[i] > peak) peak = values[i];
      }
      final weights = List<double>.filled(values.length, 0.0, growable: true);
      var total = 0.0;
      for (var i = 0; i < values.length; i++) {
        final w = math.exp(values[i] - peak);
        weights[i] = w;
        total += w;
      }
      for (var i = 0; i < weights.length; i++) {
        weights[i] /= total;
      }
      return weights;
    }, isSync: true),

    // --- Polynomials ---
    'polyEval': QudsNativeFunction('polyEval', (p, n, c) {
      final coeffs = _asVector(p[0], c.span);
      final x = (p[1] as num).toDouble();
      if (coeffs.isEmpty) return 0.0;
      var total = 0.0;
      for (var i = coeffs.length - 1; i >= 0; i--) {
        total = total * x + coeffs[i];
      }
      return total;
    }, isSync: true),

    // --- Signal Processing ---
    'convolve': QudsNativeFunction('convolve', (p, n, c) {
      final left = _asVector(p[0], c.span);
      final right = _asVector(p[1], c.span);
      if (left.isEmpty || right.isEmpty) {
        throw _qudsThrow('convolve needs non-empty lists', c.span);
      }
      final outLen = left.length + right.length - 1;
      final out = List<double>.filled(outLen, 0.0, growable: true);
      for (var i = 0; i < left.length; i++) {
        final lv = left[i];
        if (lv == 0.0) continue;
        for (var j = 0; j < right.length; j++) {
          out[i + j] += lv * right[j];
        }
      }
      return out;
    }, isSync: true),
    'fftConvolve': QudsNativeFunction('fftConvolve', (p, n, c) {
      final left = _asVector(p[0], c.span);
      final right = _asVector(p[1], c.span);
      if (left.isEmpty || right.isEmpty) {
        throw _qudsThrow('fftConvolve needs non-empty lists', c.span);
      }
      final outLen = left.length + right.length - 1;
      var m = 1;
      while (m < outLen) {
        m <<= 1;
      }
      final aRe = Float64List(m);
      final aIm = Float64List(m);
      final bRe = Float64List(m);
      final bIm = Float64List(m);
      for (var i = 0; i < left.length; i++) {
        aRe[i] = left[i];
      }
      for (var i = 0; i < right.length; i++) {
        bRe[i] = right[i];
      }
      _fftInPlace(aRe, aIm, -1.0);
      _fftInPlace(bRe, bIm, -1.0);
      for (var i = 0; i < m; i++) {
        final ar = aRe[i];
        final ai = aIm[i];
        final br = bRe[i];
        final bi = bIm[i];
        aRe[i] = ar * br - ai * bi;
        aIm[i] = ar * bi + ai * br;
      }
      _fftInPlace(aRe, aIm, 1.0);
      return List<double>.generate(outLen, (i) => aRe[i], growable: true);
    }, isSync: true),
  };

  if (complexClass != null) {
    intrinsics['fft'] = QudsNativeFunction('fft', (p, n, c) {
      return _fftComplexList(p[0], -1.0, complexClass, c.span);
    }, isSync: true);
    intrinsics['ifft'] = QudsNativeFunction('ifft', (p, n, c) {
      return _fftComplexList(p[0], 1.0, complexClass, c.span);
    }, isSync: true);
    intrinsics['fftReal'] = QudsNativeFunction('fftReal', (p, n, c) {
      final values = _asVector(p[0], c.span);
      final len = values.length;
      if (len < 1 || (len & (len - 1)) != 0) {
        throw _qudsThrow('fft needs a positive power of two', c.span);
      }
      final re = Float64List.fromList(values);
      final im = Float64List(len);
      _fftInPlace(re, im, -1.0);
      return List<QudsInstance>.generate(
        len,
        (i) => QudsInstance(complexClass, {'real': re[i], 'imag': im[i]}),
        growable: true,
      );
    }, isSync: true);
  }

  if (tensorClass != null) {
    intrinsics['tensorAdd'] = QudsNativeFunction('tensorAdd', (p, n, c) {
      final left = p[0] as QudsInstance;
      final right = p[1] as QudsInstance;
      final lShape = left.fields['shape'] as List;
      final rShape = right.fields['shape'] as List;
      if (lShape.length != rShape.length) {
        throw _qudsThrow('tensor add needs the same shape', c.span);
      }
      for (var i = 0; i < lShape.length; i++) {
        if (lShape[i] != rShape[i]) {
          throw _qudsThrow('tensor add needs the same shape', c.span);
        }
      }
      final lVals = left.fields['values'] as List;
      final rVals = right.fields['values'] as List;
      final made = List<double>.generate(
        lVals.length,
        (i) => (lVals[i] as num).toDouble() + (rVals[i] as num).toDouble(),
        growable: true,
      );
      final shapeCopy =
          List<int>.generate(lShape.length, (i) => (lShape[i] as num).toInt());
      return QudsInstance(
        tensorClass,
        {'shape': shapeCopy, 'values': made},
      );
    }, isSync: true);

    intrinsics['tensorMatmul'] = QudsNativeFunction('tensorMatmul', (p, n, c) {
      final left = p[0] as QudsInstance;
      final right = p[1] as QudsInstance;
      final lShape = left.fields['shape'] as List;
      final rShape = right.fields['shape'] as List;
      if (lShape.length != 2 || rShape.length != 2) {
        throw _qudsThrow('tensor matmul needs rank 2', c.span);
      }
      final rows = (lShape[0] as num).toInt();
      final inner = (lShape[1] as num).toInt();
      final rRows = (rShape[0] as num).toInt();
      final cols = (rShape[1] as num).toInt();
      if (inner != rRows) {
        throw _qudsThrow('tensor matmul needs compatible shapes', c.span);
      }
      if (rows * cols > 4096) {
        throw _qudsThrow('tensor exceeds the work limit', c.span);
      }
      final lVals = left.fields['values'] as List;
      final rVals = right.fields['values'] as List;
      final made = List<double>.filled(rows * cols, 0.0, growable: true);
      for (var r = 0; r < rows; r++) {
        final rBase = r * inner;
        final oBase = r * cols;
        for (var k = 0; k < inner; k++) {
          final a = (lVals[rBase + k] as num).toDouble();
          if (a == 0.0) continue;
          final kBase = k * cols;
          for (var col = 0; col < cols; col++) {
            made[oBase + col] += a * (rVals[kBase + col] as num).toDouble();
          }
        }
      }
      for (final v in made) {
        if (!v.isFinite) {
          throw _qudsThrow('tensor values must be finite', c.span);
        }
      }
      return QudsInstance(
        tensorClass,
        {
          'shape': <int>[rows, cols],
          'values': made,
        },
      );
    }, isSync: true);
  }

  _patchExports(modEnv, publicExports, sectionExports, intrinsics);
}

// ============================================================================
// quds:json intrinsics
// ============================================================================

/// Replaces hot read-only `quds:json` functions with native Dart `dart:convert`
/// implementations while preserving exact `JsonError` and `Result` contracts.
void installQudsJsonIntrinsics(
  QudsEnvironment modEnv,
  Map<String, Object?> publicExports,
  Map<String, Map<String, Object?>> sectionExports,
) {
  final jsonErrorClass = modEnv.localSlots['JsonError']?.value as QudsClass?;
  if (jsonErrorClass == null) return;

  QudsResult jsonErr(String message, [String path = '']) => QudsResult.error(
        QudsInstance(jsonErrorClass, {'message': message, 'path': path}),
      );

  QudsResult asObject(Object? value, String path) {
    if (value is! Map) {
      return jsonErr('Expected JSON object', path);
    }
    final out = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        return jsonErr('JSON object key must be String', path);
      }
      out[key] = entry.value;
    }
    return QudsResult.ok(out);
  }

  QudsResult asList(Object? value, String path) {
    if (value is! List) {
      return jsonErr('Expected JSON array', path);
    }
    return QudsResult.ok(List<Object?>.from(value));
  }

  String encode(Object? value, bool pretty, String indent) {
    if (pretty) {
      return JsonEncoder.withIndent(indent).convert(value);
    }
    return jsonEncode(value);
  }

  final intrinsics = <String, QudsNativeFunction>{
    'jsonAsObject': QudsNativeFunction('jsonAsObject', (p, n, c) {
      final path = _optArg<String>(p, n, 1, 'path', '');
      return asObject(p[0], path);
    }, isSync: true),
    'jsonAsList': QudsNativeFunction('jsonAsList', (p, n, c) {
      final path = _optArg<String>(p, n, 1, 'path', '');
      return asList(p[0], path);
    }, isSync: true),
    'parseJson': QudsNativeFunction('parseJson', (p, n, c) {
      final source = p[0] as String;
      try {
        return QudsResult.ok(jsonDecode(source));
      } catch (e) {
        return jsonErr('$e');
      }
    }, isSync: true),
    'parseJsonObject': QudsNativeFunction('parseJsonObject', (p, n, c) {
      final source = p[0] as String;
      try {
        return asObject(jsonDecode(source), '');
      } catch (e) {
        return jsonErr('$e');
      }
    }, isSync: true),
    'parseJsonList': QudsNativeFunction('parseJsonList', (p, n, c) {
      final source = p[0] as String;
      try {
        return asList(jsonDecode(source), '');
      } catch (e) {
        return jsonErr('$e');
      }
    }, isSync: true),
    'encodeJson': QudsNativeFunction('encodeJson', (p, n, c) {
      final pretty = _optArg<bool>(p, n, 1, 'pretty', false);
      final indent = _optArg<String>(p, n, 2, 'indent', '  ');
      return encode(p[0], pretty, indent);
    }, isSync: true),
    'jsonPretty': QudsNativeFunction('jsonPretty', (p, n, c) {
      final indent = _optArg<String>(p, n, 1, 'indent', '  ');
      return encode(p[0], true, indent);
    }, isSync: true),
    'tryEncodeJson': QudsNativeFunction('tryEncodeJson', (p, n, c) {
      final pretty = _optArg<bool>(p, n, 1, 'pretty', false);
      final indent = _optArg<String>(p, n, 2, 'indent', '  ');
      try {
        return QudsResult.ok(encode(p[0], pretty, indent));
      } catch (e) {
        return jsonErr('$e');
      }
    }, isSync: true),
    'jsonPath': QudsNativeFunction('jsonPath', (p, n, c) {
      var current = p[0];
      final path = p[1] as String;
      if (path.isEmpty) return current;
      for (final segment in path.split('.')) {
        if (current == null) return null;
        if (current is Map) {
          if (!current.containsKey(segment)) return null;
          current = current[segment];
        } else if (current is List) {
          final idx = int.tryParse(segment);
          if (idx == null || idx < 0 || idx >= current.length) return null;
          current = current[idx];
        } else {
          return null;
        }
      }
      return current;
    }, isSync: true),
    'jsonMerge': QudsNativeFunction('jsonMerge', (p, n, c) {
      final base = p[0] as Map;
      final overlay = p[1] as Map;
      final deep = _optArg<bool>(p, n, 2, 'deep', true);
      return _jsonMergeNative(base, overlay, deep);
    }, isSync: true),
    'jsonEquals': QudsNativeFunction('jsonEquals', (p, n, c) {
      return _jsonEqualsNative(p[0], p[1]);
    }, isSync: true),
  };

  _patchExports(modEnv, publicExports, sectionExports, intrinsics);
}

Object? _cloneJsonNative(Object? value) {
  if (value is Map) {
    final out = <String, Object?>{};
    for (final entry in value.entries) {
      out['${entry.key}'] = _cloneJsonNative(entry.value);
    }
    return out;
  }
  if (value is List) {
    return List<Object?>.generate(
      value.length,
      (i) => _cloneJsonNative(value[i]),
      growable: true,
    );
  }
  return value;
}

Map<String, Object?> _jsonMergeNative(
  Map<Object?, Object?> base,
  Map<Object?, Object?> overlay,
  bool deep,
) {
  final out = <String, Object?>{};
  for (final entry in base.entries) {
    out['${entry.key}'] = _cloneJsonNative(entry.value);
  }
  for (final entry in overlay.entries) {
    final key = '${entry.key}';
    final overVal = entry.value;
    if (deep && out.containsKey(key)) {
      final baseVal = out[key];
      if (baseVal is Map &&
          overVal is Map &&
          baseVal.keys.every((k) => k is String) &&
          overVal.keys.every((k) => k is String)) {
        out[key] = _jsonMergeNative(baseVal, overVal, true);
        continue;
      }
    }
    out[key] = _cloneJsonNative(overVal);
  }
  return out;
}

bool _jsonEqualsNative(Object? a, Object? b) {
  if (a == null || b == null) return a == null && b == null;
  if (a is num && b is num) return a.toDouble() == b.toDouble();
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonEqualsNative(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!_jsonEqualsNative(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  return a == b;
}

// ============================================================================
// quds:collection intrinsics
// ============================================================================

/// Replaces hot read-only `quds:collection` functions with native Dart
/// implementations while preserving exact `CollectionError` contracts.
void installQudsCollectionIntrinsics(
  QudsEnvironment modEnv,
  Map<String, Object?> publicExports,
  Map<String, Map<String, Object?>> sectionExports,
) {
  final collectionErrorClass =
      modEnv.localSlots['CollectionError']?.value as QudsClass?;

  Object collectionErr(String op, String message, SourceSpan span) {
    if (collectionErrorClass != null) {
      return QudsThrownValue(
        QudsInstance(
          collectionErrorClass,
          {'operation': op, 'message': message},
        ),
        span,
        const [],
      );
    }
    return _qudsThrow('CollectionError($op): $message', span);
  }

  final intrinsics = <String, QudsNativeFunction>{
    'chunkList': QudsNativeFunction('chunkList', (p, n, c) {
      final items = p[0] as List;
      final size = (p[1] as num).toInt();
      if (size < 1) {
        throw collectionErr(
          'chunkList',
          'Chunk size must be at least 1, got $size',
          c.span,
        );
      }
      final out = <List<Object?>>[];
      for (var i = 0; i < items.length; i += size) {
        final end = (i + size > items.length) ? items.length : i + size;
        out.add(items.sublist(i, end));
      }
      return out;
    }, isSync: true),
    'windowList': QudsNativeFunction('windowList', (p, n, c) {
      final items = p[0] as List;
      final size = (p[1] as num).toInt();
      final step = (_optArg<num>(p, n, 2, 'step', 1)).toInt();
      final partial = _optArg<bool>(p, n, 3, 'partial', false);
      if (size < 1) {
        throw collectionErr(
          'windowList',
          'Window size must be at least 1, got $size',
          c.span,
        );
      }
      if (step < 1) {
        throw collectionErr(
          'windowList',
          'Window step must be at least 1, got $step',
          c.span,
        );
      }
      final out = <List<Object?>>[];
      for (var i = 0; i < items.length; i += step) {
        var end = i + size;
        if (end > items.length) {
          if (!partial) break;
          end = items.length;
        }
        out.add(items.sublist(i, end));
      }
      return out;
    }, isSync: true),
    'flattenOnce': QudsNativeFunction('flattenOnce', (p, n, c) {
      final nested = p[0] as Iterable;
      final out = <Object?>[];
      for (final inner in nested) {
        out.addAll(inner as Iterable);
      }
      return out;
    }, isSync: true),
    'interleave': QudsNativeFunction('interleave', (p, n, c) {
      final left = p[0] as List;
      final right = p[1] as List;
      final out = <Object?>[];
      final maxLen = left.length > right.length ? left.length : right.length;
      for (var i = 0; i < maxLen; i++) {
        if (i < left.length) out.add(left[i]);
        if (i < right.length) out.add(right[i]);
      }
      return out;
    }, isSync: true),
    'intersperse': QudsNativeFunction('intersperse', (p, n, c) {
      final items = p[0] as Iterable;
      final sep = p[1];
      final out = <Object?>[];
      var first = true;
      for (final item in items) {
        if (!first) out.add(sep);
        first = false;
        out.add(item);
      }
      return out;
    }, isSync: true),
    'frequencies': QudsNativeFunction('frequencies', (p, n, c) {
      final items = p[0] as Iterable;
      final counts = <Object?, int>{};
      for (final item in items) {
        counts[item] = (counts[item] ?? 0) + 1;
      }
      return counts;
    }, isSync: true),
    'symmetricDifference': QudsNativeFunction('symmetricDifference', (p, n, c) {
      final first = p[0] as Set;
      final second = p[1] as Set;
      final out = <Object?>{};
      for (final item in first) {
        if (!second.contains(item)) out.add(item);
      }
      for (final item in second) {
        if (!first.contains(item)) out.add(item);
      }
      return out;
    }, isSync: true),
    'isSubsetOf': QudsNativeFunction('isSubsetOf', (p, n, c) {
      final subset = p[0] as Set;
      final superset = p[1] as Set;
      if (subset.length > superset.length) return false;
      for (final item in subset) {
        if (!superset.contains(item)) return false;
      }
      return true;
    }, isSync: true),
    'isSupersetOf': QudsNativeFunction('isSupersetOf', (p, n, c) {
      final superset = p[0] as Set;
      final subset = p[1] as Set;
      if (subset.length > superset.length) return false;
      for (final item in subset) {
        if (!superset.contains(item)) return false;
      }
      return true;
    }, isSync: true),
    'isDisjoint': QudsNativeFunction('isDisjoint', (p, n, c) {
      final first = p[0] as Set;
      final second = p[1] as Set;
      if (first.length <= second.length) {
        for (final item in first) {
          if (second.contains(item)) return false;
        }
      } else {
        for (final item in second) {
          if (first.contains(item)) return false;
        }
      }
      return true;
    }, isSync: true),
    'pickKeys': QudsNativeFunction('pickKeys', (p, n, c) {
      final source = p[0] as Map;
      final keys = p[1] as Iterable;
      final out = <Object?, Object?>{};
      for (final key in keys) {
        if (source.containsKey(key)) out[key] = source[key];
      }
      return out;
    }, isSync: true),
    'omitKeys': QudsNativeFunction('omitKeys', (p, n, c) {
      final source = p[0] as Map;
      final keys = p[1] as Iterable;
      final excluded = Set<Object?>.from(keys);
      final out = <Object?, Object?>{};
      for (final entry in source.entries) {
        if (!excluded.contains(entry.key)) out[entry.key] = entry.value;
      }
      return out;
    }, isSync: true),
  };

  _patchExports(modEnv, publicExports, sectionExports, intrinsics);
}

// ============================================================================
// quds:text intrinsics (with exact UAX #29 fallback for non-ASCII / CRLF)
// ============================================================================

/// Replaces hot read-only `quds:text` functions with native Dart
/// implementations while preserving exact UAX #29 grapheme cluster semantics
/// (falling back seamlessly to the original Quds implementation for non-ASCII
/// or CRLF strings).
void installQudsTextIntrinsics(
  QudsEnvironment modEnv,
  Map<String, Object?> publicExports,
  Map<String, Map<String, Object?>> sectionExports,
) {
  final origEditDistance = modEnv.localSlots['editDistance']?.value;
  final origBoundedEditDistance =
      modEnv.localSlots['boundedEditDistance']?.value;
  final origTextSimilarity = modEnv.localSlots['textSimilarity']?.value;
  final origCommonPrefix = modEnv.localSlots['commonTextPrefix']?.value;
  final origCommonSuffix = modEnv.localSlots['commonTextSuffix']?.value;

  final intrinsics = <String, QudsNativeFunction>{
    'isBlankText': QudsNativeFunction('isBlankText', (p, n, c) {
      final text = p[0] as String;
      for (var i = 0; i < text.length; i++) {
        if (!_isUnicodeWhitespaceUnit(text.codeUnitAt(i))) return false;
      }
      return true;
    }, isSync: true),
    'splitText': QudsNativeFunction('splitText', (p, n, c) {
      final text = p[0] as String;
      final separator = p[1] as String;
      final keepEmpty = _optArg<bool>(p, n, 2, 'keepEmpty', true);
      final maxSplitsRaw = _optArg<num?>(p, n, 3, 'maxSplits', null);
      final maxSplits = maxSplitsRaw?.toInt();
      final keepSeparators = _optArg<bool>(p, n, 4, 'keepSeparators', false);
      if (separator.isEmpty) {
        throw ArgumentError.value(
          separator,
          'separator',
          'separator must not be empty',
        );
      }
      if (maxSplits != null && maxSplits < 0) {
        throw ArgumentError.value(
          maxSplits,
          'maxSplits',
          'maxSplits must be non-negative',
        );
      }
      final out = <String>[];
      if (maxSplits == 0) {
        if (keepEmpty || text.isNotEmpty) out.add(text);
        return out;
      }
      var start = 0;
      var splits = 0;
      final sepLen = separator.length;
      while (true) {
        if (maxSplits != null && splits >= maxSplits) break;
        final found = text.indexOf(separator, start);
        if (found < 0) break;
        final piece = text.substring(start, found);
        if (keepEmpty || piece.isNotEmpty) out.add(piece);
        if (keepSeparators) out.add(separator);
        start = found + sepLen;
        splits++;
      }
      final tail = text.substring(start);
      if (keepEmpty || tail.isNotEmpty) out.add(tail);
      return out;
    }, isSync: true),
    'splitTextLines': QudsNativeFunction('splitTextLines', (p, n, c) {
      final text = p[0] as String;
      final keepTrailingEmpty =
          _optArg<bool>(p, n, 1, 'keepTrailingEmpty', false);
      final out = <String>[];
      final len = text.length;
      if (len == 0) return out;
      var start = 0;
      var i = 0;
      var endedWithBreak = false;
      while (i < len) {
        final unit = text.codeUnitAt(i);
        if (unit == 13) {
          out.add(text.substring(start, i));
          i = (i + 1 < len && text.codeUnitAt(i + 1) == 10) ? i + 2 : i + 1;
          start = i;
          endedWithBreak = true;
        } else if (unit == 10) {
          out.add(text.substring(start, i));
          i++;
          start = i;
          endedWithBreak = true;
        } else {
          i++;
          endedWithBreak = false;
        }
      }
      if (start < len || (endedWithBreak && keepTrailingEmpty)) {
        out.add(text.substring(start, len));
      }
      return out;
    }, isSync: true),
    'joinText': QudsNativeFunction('joinText', (p, n, c) {
      final parts = p[0] as Iterable;
      final separator = _optArg<String>(p, n, 1, 'separator', '');
      final buffer = StringBuffer();
      var first = true;
      for (final part in parts) {
        if (!first && separator.isNotEmpty) buffer.write(separator);
        buffer.write(part as String);
        first = false;
      }
      return buffer.toString();
    }, isSync: true),
    'repeatText': QudsNativeFunction('repeatText', (p, n, c) {
      final text = p[0] as String;
      final count = (p[1] as num).toInt();
      final separator = _optArg<String>(p, n, 2, 'separator', '');
      if (count < 0) {
        throw RangeError.value(count, 'count', 'count must be non-negative');
      }
      if (count == 0) return '';
      if (count == 1) return text;
      if (separator.isEmpty) return text * count;
      final buffer = StringBuffer();
      for (var i = 0; i < count; i++) {
        if (i > 0) buffer.write(separator);
        buffer.write(text);
      }
      return buffer.toString();
    }, isSync: true),
    'escapeTextLiteral': QudsNativeFunction('escapeTextLiteral', (p, n, c) {
      final text = p[0] as String;
      const hex = '0123456789abcdef';
      final buffer = StringBuffer();
      for (var i = 0; i < text.length; i++) {
        final u = text.codeUnitAt(i);
        if (u == 92) {
          buffer.write(r'\\');
        } else if (u == 34) {
          buffer.write(r'\"');
        } else if (u == 39) {
          buffer.write(r"\'");
        } else if (u == 10) {
          buffer.write(r'\n');
        } else if (u == 13) {
          buffer.write(r'\r');
        } else if (u == 9) {
          buffer.write(r'\t');
        } else if (u < 32 || u == 127) {
          buffer.write(r'\x');
          buffer.write(hex[(u >> 4) & 0xF]);
          buffer.write(hex[u & 0xF]);
        } else {
          buffer.writeCharCode(u);
        }
      }
      return buffer.toString();
    }, isSync: true),
  };

  if (origCommonPrefix != null) {
    intrinsics['commonTextPrefix'] = QudsNativeFunction(
      'commonTextPrefix',
      (p, n, c) {
        final left = p[0] as String;
        final right = p[1] as String;
        if (_isFastAsciiGrapheme(left) && _isFastAsciiGrapheme(right)) {
          final limit = left.length < right.length ? left.length : right.length;
          var i = 0;
          while (i < limit && left.codeUnitAt(i) == right.codeUnitAt(i)) {
            i++;
          }
          return left.substring(0, i);
        }
        return c.invokeCallable(origCommonPrefix, p, n, c.span);
      },
    );
  }

  if (origCommonSuffix != null) {
    intrinsics['commonTextSuffix'] = QudsNativeFunction(
      'commonTextSuffix',
      (p, n, c) {
        final left = p[0] as String;
        final right = p[1] as String;
        if (_isFastAsciiGrapheme(left) && _isFastAsciiGrapheme(right)) {
          final limit = left.length < right.length ? left.length : right.length;
          var i = 0;
          while (i < limit &&
              left.codeUnitAt(left.length - 1 - i) ==
                  right.codeUnitAt(right.length - 1 - i)) {
            i++;
          }
          return left.substring(left.length - i);
        }
        return c.invokeCallable(origCommonSuffix, p, n, c.span);
      },
    );
  }

  if (origEditDistance != null) {
    intrinsics['editDistance'] = QudsNativeFunction(
      'editDistance',
      (p, n, c) {
        final left = p[0] as String;
        final right = p[1] as String;
        if (_isFastAsciiGrapheme(left) && _isFastAsciiGrapheme(right)) {
          return _asciiEditDistance(left, right);
        }
        return c.invokeCallable(origEditDistance, p, n, c.span);
      },
    );
  }

  if (origBoundedEditDistance != null) {
    intrinsics['boundedEditDistance'] = QudsNativeFunction(
      'boundedEditDistance',
      (p, n, c) {
        final left = p[0] as String;
        final right = p[1] as String;
        final maxDist = (p[2] as num).toInt();
        if (maxDist < 0) {
          throw RangeError.value(
            maxDist,
            'maxDistance',
            'maxDistance must be non-negative',
          );
        }
        if (_isFastAsciiGrapheme(left) && _isFastAsciiGrapheme(right)) {
          return _asciiBoundedEditDistance(left, right, maxDist);
        }
        return c.invokeCallable(origBoundedEditDistance, p, n, c.span);
      },
    );
  }

  if (origTextSimilarity != null) {
    intrinsics['textSimilarity'] = QudsNativeFunction(
      'textSimilarity',
      (p, n, c) {
        final left = p[0] as String;
        final right = p[1] as String;
        if (_isFastAsciiGrapheme(left) && _isFastAsciiGrapheme(right)) {
          final denom = left.length > right.length ? left.length : right.length;
          if (denom == 0) return 1.0;
          final dist = _asciiEditDistance(left, right);
          return 1.0 - (dist.toDouble() / denom.toDouble());
        }
        return c.invokeCallable(origTextSimilarity, p, n, c.span);
      },
    );
  }

  _patchExports(modEnv, publicExports, sectionExports, intrinsics);
}

// ============================================================================
// Internal native math / text helpers
// ============================================================================

int _gcdInt(int a, int b, SourceSpan span) {
  var x = a;
  var y = b;
  while (y != 0) {
    final next = x % y;
    x = y;
    y = next;
  }
  if (x < 0 && -x == x) {
    throw _qudsThrow('gcd result is outside int range', span);
  }
  return x < 0 ? -x : x;
}

int _modPowInt(int base, int exp, int mod) {
  if (mod <= 3037000499) {
    var result = 1 % mod;
    var factor = base % mod;
    if (factor < 0) factor += mod;
    var left = exp;
    while (left > 0) {
      if ((left & 1) == 1) result = (result * factor) % mod;
      left >>= 1;
      if (left > 0) factor = (factor * factor) % mod;
    }
    return result;
  }
  return BigInt.from(base).modPow(BigInt.from(exp), BigInt.from(mod)).toInt();
}

const List<int> _millerRabinBases = [
  2,
  3,
  5,
  7,
  11,
  13,
  17,
  19,
  23,
  29,
  31,
  37
];

bool _isProbablePrimeInt(int n) {
  if (n < 2) return false;
  if (n == 2 || n == 3) return true;
  if (n.isEven) return false;
  for (final p in _millerRabinBases) {
    if (n == p) return true;
    if (n % p == 0) return false;
  }
  var d = n - 1;
  var s = 0;
  while (d.isEven) {
    d >>= 1;
    s++;
  }
  if (n <= 3037000499) {
    for (final base in _millerRabinBases) {
      if (base >= n) break;
      var x = _modPowInt(base, d, n);
      if (x == 1 || x == n - 1) continue;
      var witness = false;
      for (var r = 1; r < s; r++) {
        x = (x * x) % n;
        if (x == n - 1) {
          witness = true;
          break;
        }
      }
      if (!witness) return false;
    }
    return true;
  }
  final bn = BigInt.from(n);
  final bd = BigInt.from(d);
  final bnMinus1 = bn - BigInt.one;
  for (final base in _millerRabinBases) {
    var x = BigInt.from(base).modPow(bd, bn);
    if (x == BigInt.one || x == bnMinus1) continue;
    var witness = false;
    for (var r = 1; r < s; r++) {
      x = (x * x) % bn;
      if (x == bnMinus1) {
        witness = true;
        break;
      }
    }
    if (!witness) return false;
  }
  return true;
}

double _kahanSumDoubles(List<double> values) {
  var sum = 0.0;
  var comp = 0.0;
  for (var i = 0; i < values.length; i++) {
    final value = values[i];
    final t = sum + value;
    if (!t.isFinite) {
      sum = t;
      comp = 0.0;
    } else {
      if (sum.abs() >= value.abs()) {
        comp += (sum - t) + value;
      } else {
        comp += (value - t) + sum;
      }
      sum = t;
    }
  }
  return sum + comp;
}

double _meanDoubles(List<double> values) {
  final n = values.length.toDouble();
  var sum = 0.0;
  var comp = 0.0;
  for (var i = 0; i < values.length; i++) {
    final value = values[i] / n;
    final t = sum + value;
    if (!t.isFinite) {
      sum = t;
      comp = 0.0;
    } else {
      if (sum.abs() >= value.abs()) {
        comp += (sum - t) + value;
      } else {
        comp += (value - t) + sum;
      }
      sum = t;
    }
  }
  return sum + comp;
}

double _varianceDoubles(List<double> values, double denominator) {
  final center = _meanDoubles(values);
  var sum = 0.0;
  var comp = 0.0;
  for (var i = 0; i < values.length; i++) {
    final delta = values[i] - center;
    final term = (delta / denominator) * delta;
    final t = sum + term;
    if (!t.isFinite) {
      sum = t;
      comp = 0.0;
    } else {
      if (sum.abs() >= term.abs()) {
        comp += (sum - t) + term;
      } else {
        comp += (term - t) + sum;
      }
      sum = t;
    }
  }
  return sum + comp;
}

double _diffRatio(double left, double right, double scale) {
  final delta = left - right;
  if (delta.isFinite) return delta / scale;
  return left / scale - right / scale;
}

double _spreadDoubles(List<double> values, double denominator) {
  final center = _meanDoubles(values);
  final scale = math.sqrt(denominator);
  var total = 0.0;
  for (var i = 0; i < values.length; i++) {
    total = _hypot(total, _diffRatio(values[i], center, scale));
  }
  return total;
}

List<QudsInstance> _fftComplexList(
  Object? raw,
  double sign,
  QudsClass complexClass,
  SourceSpan span,
) {
  if (raw is! List) {
    throw QudsRuntimeException('Expected List<Complex>.', span);
  }
  final len = raw.length;
  if (len < 1 || (len & (len - 1)) != 0) {
    throw _qudsThrow('fft needs a positive power of two', span);
  }
  final re = Float64List(len);
  final im = Float64List(len);
  for (var i = 0; i < len; i++) {
    final inst = raw[i] as QudsInstance;
    re[i] = (inst.fields['real'] as num).toDouble();
    im[i] = (inst.fields['imag'] as num).toDouble();
  }
  _fftInPlace(re, im, sign);
  return List<QudsInstance>.generate(
    len,
    (i) => QudsInstance(complexClass, {'real': re[i], 'imag': im[i]}),
    growable: true,
  );
}

void _fftInPlace(Float64List re, Float64List im, double sign) {
  final n = re.length;
  // Bit-reversal permutation
  var j = 0;
  for (var i = 1; i < n; i++) {
    var bit = n >> 1;
    while ((j & bit) != 0) {
      j ^= bit;
      bit >>= 1;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
  // Iterative radix-2 Cooley-Tukey butterflies
  for (var len = 2; len <= n; len <<= 1) {
    final half = len >> 1;
    final angle = sign * 2.0 * math.pi / len;
    final wLenRe = math.cos(angle);
    final wLenIm = math.sin(angle);
    for (var start = 0; start < n; start += len) {
      var wRe = 1.0;
      var wIm = 0.0;
      for (var k = 0; k < half; k++) {
        final idx1 = start + k;
        final idx2 = idx1 + half;
        final uRe = re[idx1];
        final uIm = im[idx1];
        final xRe = re[idx2];
        final xIm = im[idx2];
        final vRe = xRe * wRe - xIm * wIm;
        final vIm = xRe * wIm + xIm * wRe;
        re[idx1] = uRe + vRe;
        im[idx1] = uIm + vIm;
        re[idx2] = uRe - vRe;
        im[idx2] = uIm - vIm;
        final nextWRe = wRe * wLenRe - wIm * wLenIm;
        wIm = wRe * wLenIm + wIm * wLenRe;
        wRe = nextWRe;
      }
    }
  }
  if (sign > 0.0) {
    final scale = 1.0 / n;
    for (var i = 0; i < n; i++) {
      re[i] *= scale;
      im[i] *= scale;
    }
  }
}

bool _isUnicodeWhitespaceUnit(int u) {
  if (u == 0x20 || (u >= 0x09 && u <= 0x0D)) return true;
  if (u < 0x85) return false;
  if (u == 0x85 || u == 0xA0 || u == 0x1680) return true;
  if (u >= 0x2000 && u <= 0x200A) return true;
  return u == 0x2028 ||
      u == 0x2029 ||
      u == 0x202F ||
      u == 0x205F ||
      u == 0x3000;
}

/// True iff every UTF-16 code unit in [s] is strictly ASCII (< 128) and
/// contains no CRLF (`\r\n`) sequence, guaranteeing 1 code unit == 1 UAX #29
/// Extended Grapheme Cluster.
bool _isFastAsciiGrapheme(String s) {
  final len = s.length;
  for (var i = 0; i < len; i++) {
    final u = s.codeUnitAt(i);
    if (u >= 128) return false;
    if (u == 13 && i + 1 < len && s.codeUnitAt(i + 1) == 10) return false;
  }
  return true;
}

int _asciiEditDistance(String left, String right) {
  final m = left.length;
  final n = right.length;
  if (m == 0) return n;
  if (n == 0) return m;
  if (m * n > 2000000) {
    throw ArgumentError(
      'editDistance input exceeds the 2,000,000 cell work limit',
    );
  }
  var prev = Int32List(n + 1);
  var curr = Int32List(n + 1);
  for (var j = 0; j <= n; j++) {
    prev[j] = j;
  }
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    final ai = left.codeUnitAt(i - 1);
    for (var j = 1; j <= n; j++) {
      final cost = ai == right.codeUnitAt(j - 1) ? 0 : 1;
      final delCost = prev[j] + 1;
      final insCost = curr[j - 1] + 1;
      final subCost = prev[j - 1] + cost;
      var best = delCost < insCost ? delCost : insCost;
      if (subCost < best) best = subCost;
      curr[j] = best;
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

int? _asciiBoundedEditDistance(String left, String right, int maxDistance) {
  final m = left.length;
  final n = right.length;
  final diff = m > n ? m - n : n - m;
  if (diff > maxDistance) return null;
  if (m == 0) return n;
  if (n == 0) return m;
  if (m * n > 2000000) {
    throw ArgumentError(
      'boundedEditDistance input exceeds the 2,000,000 cell work limit',
    );
  }
  var prev = Int32List(n + 1);
  var curr = Int32List(n + 1);
  for (var j = 0; j <= n; j++) {
    prev[j] = j;
  }
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    var rowMin = i;
    final ai = left.codeUnitAt(i - 1);
    for (var j = 1; j <= n; j++) {
      final cost = ai == right.codeUnitAt(j - 1) ? 0 : 1;
      final delCost = prev[j] + 1;
      final insCost = curr[j - 1] + 1;
      final subCost = prev[j - 1] + cost;
      var best = delCost < insCost ? delCost : insCost;
      if (subCost < best) best = subCost;
      curr[j] = best;
      if (best < rowMin) rowMin = best;
    }
    if (rowMin > maxDistance) return null;
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  final dist = prev[n];
  return dist > maxDistance ? null : dist;
}

Float64List _asFloat64Copy(Object? raw, SourceSpan span) {
  if (raw is! List) {
    throw QudsRuntimeException('Expected List<double>.', span);
  }
  final len = raw.length;
  final out = Float64List(len);
  if (raw is List<double>) {
    out.setAll(0, raw);
  } else {
    for (var i = 0; i < len; i++) {
      out[i] = (raw[i] as num).toDouble();
    }
  }
  return out;
}

/// Linear-time O(N) quickselect with median-of-3 pivoting and sort fallback.
/// After returning `a[k]`, all elements `a[0..k-1]` are `<= a[k]`.
double _selectFloat64(Float64List a, int k) {
  for (var i = 0; i < a.length; i++) {
    if (a[i].isNaN) {
      a.sort();
      return a[k];
    }
  }
  var left = 0;
  var right = a.length - 1;
  var budget = a.length * 4 + 64;
  while (left < right) {
    if (budget <= 0) {
      a.sort();
      return a[k];
    }
    final mid = (left + right) >> 1;
    // Median-of-3 pivot placed at `mid`
    if (a[mid] < a[left]) {
      final t = a[left];
      a[left] = a[mid];
      a[mid] = t;
    }
    if (a[right] < a[left]) {
      final t = a[left];
      a[left] = a[right];
      a[right] = t;
    }
    if (a[right] < a[mid]) {
      final t = a[mid];
      a[mid] = a[right];
      a[right] = t;
    }
    final pivot = a[mid];
    var i = left;
    var j = right;
    while (i <= j) {
      while (a[i] < pivot) {
        i++;
      }
      while (a[j] > pivot) {
        j--;
      }
      if (i <= j) {
        final t = a[i];
        a[i] = a[j];
        a[j] = t;
        i++;
        j--;
      }
    }
    budget -= (right - left + 1);
    if (k <= j) {
      right = j;
    } else if (k >= i) {
      left = i;
    } else {
      return a[k];
    }
  }
  return a[k];
}

List<double> _asVector(Object? raw, SourceSpan span, {bool copy = false}) {
  if (raw is! List) {
    throw QudsRuntimeException('Expected List<double>.', span);
  }
  if (!copy && raw is List<double>) return raw;
  return List<double>.generate(
    raw.length,
    (i) => (raw[i] as num).toDouble(),
    growable: true,
  );
}

List<List<double>> _asMatrix(
  Object? raw,
  SourceSpan span, {
  bool allowEmpty = false,
  bool copy = false,
}) {
  if (raw is! List) {
    throw QudsRuntimeException('Expected List<List<double>>.', span);
  }
  if (!allowEmpty && raw.isEmpty) {
    throw _qudsThrow('matrix must not be empty', span);
  }
  if (!copy && raw is List<List<double>>) return raw;
  return List<List<double>>.generate(
    raw.length,
    (i) => _asVector(raw[i], span, copy: copy),
    growable: true,
  );
}

List<List<double>> _rectCopy(
  Object? raw,
  SourceSpan span, {
  bool copy = false,
}) {
  final rows = _asMatrix(raw, span, allowEmpty: true, copy: copy);
  if (rows.isEmpty || rows[0].isEmpty) {
    throw _qudsThrow('matrix must not be empty', span);
  }
  final width = rows[0].length;
  for (var i = 1; i < rows.length; i++) {
    if (rows[i].length != width) {
      throw _qudsThrow('matrix rows must have the same length', span);
    }
  }
  return rows;
}

List<List<double>> _squareCopy(Object? raw, SourceSpan span) {
  final grid = _rectCopy(raw, span, copy: true);
  if (grid.length != grid[0].length) {
    throw _qudsThrow('matrix must be square', span);
  }
  return grid;
}

int _sameShape(
  List<List<double>> left,
  List<List<double>> right,
  SourceSpan span,
) {
  final width = left[0].length;
  if (left.length != right.length || right[0].length != width) {
    throw _qudsThrow('matrices must have the same shape', span);
  }
  return width;
}

List<List<double>> _blendMatrices(
  Object? rawLeft,
  Object? rawRight,
  double sign,
  SourceSpan span,
) {
  final left = _rectCopy(rawLeft, span);
  final right = _rectCopy(rawRight, span);
  final width = _sameShape(left, right, span);
  return List<List<double>>.generate(
    left.length,
    (r) => List<double>.generate(
      width,
      (col) => left[r][col] + sign * right[r][col],
      growable: true,
    ),
    growable: true,
  );
}

double _hypot(double a, double b) {
  final aa = a.abs();
  final bb = b.abs();
  if (aa == 0.0) return bb;
  if (bb == 0.0) return aa;
  if (aa >= bb) {
    final r = bb / aa;
    return aa * math.sqrt(1.0 + r * r);
  }
  final r = aa / bb;
  return bb * math.sqrt(1.0 + r * r);
}

QudsThrownValue _qudsThrow(String message, SourceSpan span) =>
    QudsThrownValue(message, span, const []);
