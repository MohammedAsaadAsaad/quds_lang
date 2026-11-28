/// Native Dart AOT-speed intrinsics for read-only built-in `quds:*` SDK
/// libraries when executed inside the Quds interpreter / Register VM.
///
/// Pure Dart (zero `dart:io` imports). Preserves exact `math.quds` validation,
/// thrown Quds string messages, and return types while executing hot linear
/// algebra, tensor, and sparse-matrix kernels at native Dart speed.
library;

import 'dart:math' as math;

import '../source.dart';
import 'environment.dart';
import 'exceptions.dart';
import 'values.dart';

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

  final intrinsics = <String, QudsNativeFunction>{
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
      // Cache-friendly i-k-j accumulation with pre-extracted row references.
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
      final rhs = _asVector(p[1], c.span);
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
  };

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

List<double> _asVector(Object? raw, SourceSpan span) {
  if (raw is! List) {
    throw QudsRuntimeException('Expected List<double>.', span);
  }
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
}) {
  if (raw is! List) {
    throw QudsRuntimeException('Expected List<List<double>>.', span);
  }
  if (!allowEmpty && raw.isEmpty) {
    throw _qudsThrow('matrix must not be empty', span);
  }
  return List<List<double>>.generate(
    raw.length,
    (i) => _asVector(raw[i], span),
    growable: true,
  );
}

List<List<double>> _rectCopy(Object? raw, SourceSpan span) {
  final rows = _asMatrix(raw, span, allowEmpty: true);
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
  final grid = _rectCopy(raw, span);
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
