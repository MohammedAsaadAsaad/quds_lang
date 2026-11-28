/// Built-in `quds:assets` module for loading, parsing, mutating, generating,
/// and rendering project assets (`assets/*.json`, `.csv`, `.txt`, `.md`, `.bmp`,
/// `.png`, etc.) inside an attached [QudsWorkspace].
///
/// 100% pure Dart (zero `dart:io` imports) — works identically on Flutter
/// Mobile, Desktop, Web, and Dart CLI.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'exceptions.dart';
import 'host_bridge.dart';
import 'outputs.dart';
import 'workspace.dart';

/// Builds the `quds:assets` [QudsHostModule] backed dynamically by the active
/// [QudsWorkspace] attached to the session.
QudsHostModule buildQudsAssetsModule({
  required QudsWorkspace? Function() getWorkspace,
  bool Function()? allowMutation,
}) {
  QudsWorkspace requireWorkspace(dynamic span) {
    final ws = getWorkspace();
    if (ws == null) {
      throw QudsRuntimeException(
        'No QudsWorkspace is attached to this session. Open or attach a project workspace to use `quds:assets`.',
        span,
      );
    }
    return ws;
  }

  void checkMutable(dynamic span) {
    if (allowMutation != null && !allowMutation()) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.featureDisabled,
        'Writing workspace assets is disabled by the active execution policy.',
        span,
      );
    }
  }

  final builder = QudsHostModule.builder(
    'quds:assets',
    description:
        'Load, parse (JSON/CSV/Text/Bytes/Base64), update, and render workspace assets (including binary BMP/PNG images and procedural pixel grids).',
  );

  builder.function(
    'exists',
    (pos, named, ctx) {
      final ws = getWorkspace();
      if (ws == null) return false;
      final path = '${pos[0]}';
      return ws.hasAnyFile(path);
    },
    signature: 'exists(path: String) -> bool',
    documentation: 'Returns true if the asset path exists in the workspace.',
  );

  builder.function(
    'list',
    (pos, named, ctx) {
      final ws = getWorkspace();
      if (ws == null) return <String>[];
      final folder =
          pos.isNotEmpty ? '${pos[0]}' : (named['folder'] as String?) ?? '';
      final ext = named['extension'] as String?;
      return ws.listAllEntries(
        inFolder: folder.isEmpty ? null : folder,
        extension: ext,
      );
    },
    signature:
        'list(folder: String = "", extension: String? = null) -> List<String>',
    documentation:
        'Lists all files and assets in the workspace (optionally under a folder).',
  );

  builder.function(
    'info',
    (pos, named, ctx) {
      final ws = requireWorkspace(ctx.span);
      final raw = '${pos[0]}';
      final norm = QudsWorkspace.normalizePath(raw);
      if (!ws.hasAnyFile(norm)) {
        throw QudsRuntimeException(
            'Asset `$raw` not found in workspace.', ctx.span);
      }
      final bytes = ws.readAssetBytes(norm)!;
      final name =
          norm.contains('/') ? norm.substring(norm.lastIndexOf('/') + 1) : norm;
      return <String, Object?>{
        'path': norm,
        'name': name,
        'mimeType': QudsWorkspace.mimeTypeForPath(norm),
        'bytes': bytes.length,
        'isBinary': ws.isBinaryFile(norm),
      };
    },
    signature: 'info(path: String) -> Map<String, Object?>',
    documentation:
        'Returns metadata (path, name, mimeType, bytes, isBinary) for an asset.',
  );

  builder.function(
    'readText',
    (pos, named, ctx) {
      final ws = requireWorkspace(ctx.span);
      final raw = '${pos[0]}';
      final text = ws.readFile(raw);
      if (text != null) return text;
      final bytes = ws.readAssetBytes(raw);
      if (bytes != null) return utf8.decode(bytes, allowMalformed: true);
      throw QudsRuntimeException(
          'Asset `$raw` not found in workspace.', ctx.span);
    },
    signature: 'readText(path: String) -> String',
    documentation: 'Reads a workspace asset as UTF-8 text.',
  );

  builder.function(
    'readJson',
    (pos, named, ctx) {
      final ws = requireWorkspace(ctx.span);
      final raw = '${pos[0]}';
      final text = ws.readFile(raw);
      if (text == null) {
        throw QudsRuntimeException(
            'JSON asset `$raw` not found in workspace.', ctx.span);
      }
      try {
        return _deepCloneJson(jsonDecode(text));
      } catch (e) {
        throw QudsRuntimeException(
            'Invalid JSON in asset `$raw`: $e', ctx.span);
      }
    },
    signature: 'readJson(path: String) -> Object?',
    documentation:
        'Reads and parses a JSON workspace asset into a Quds Map or List.',
  );

  builder.function(
    'readCsv',
    (pos, named, ctx) {
      final ws = requireWorkspace(ctx.span);
      final raw = '${pos[0]}';
      final text = ws.readFile(raw);
      if (text == null) {
        throw QudsRuntimeException(
            'CSV asset `$raw` not found in workspace.', ctx.span);
      }
      final hasHeader = (named['hasHeader'] as bool?) ?? true;
      final delim = (named['delimiter'] as String?) ?? ',';
      final lines = text
          .replaceAll('\r\n', '\n')
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty) return <Object?>[];
      final parsed = [for (final line in lines) _parseCsvLine(line, delim)];
      if (!hasHeader) return parsed;
      final headers = parsed.first;
      final rows = <Map<String, Object?>>[];
      for (var i = 1; i < parsed.length; i++) {
        final cells = parsed[i];
        final row = <String, Object?>{};
        for (var c = 0; c < headers.length; c++) {
          final key = headers[c].trim();
          final val = c < cells.length ? cells[c].trim() : '';
          row[key] = _coerceCsvCell(val);
        }
        rows.add(row);
      }
      return rows;
    },
    signature:
        'readCsv(path: String, hasHeader: bool = true, delimiter: String = ",") -> List<Object?>',
    documentation:
        'Parses a CSV asset into a list of maps (auto-converting numbers/booleans) or raw rows.',
  );

  builder.function(
    'readBytes',
    (pos, named, ctx) {
      final ws = requireWorkspace(ctx.span);
      final raw = '${pos[0]}';
      final bytes = ws.readAssetBytes(raw);
      if (bytes == null) {
        throw QudsRuntimeException(
            'Asset `$raw` not found in workspace.', ctx.span);
      }
      return bytes.toList();
    },
    signature: 'readBytes(path: String) -> List<int>',
    documentation: 'Reads raw byte values (0..255) of a workspace asset.',
  );

  builder.function(
    'readBase64',
    (pos, named, ctx) {
      final ws = requireWorkspace(ctx.span);
      final raw = '${pos[0]}';
      final bytes = ws.readAssetBytes(raw);
      if (bytes == null) {
        throw QudsRuntimeException(
            'Asset `$raw` not found in workspace.', ctx.span);
      }
      return base64Encode(bytes);
    },
    signature: 'readBase64(path: String) -> String',
    documentation: 'Reads a workspace asset encoded as Base64.',
  );

  builder.function(
    'writeText',
    (pos, named, ctx) {
      checkMutable(ctx.span);
      final ws = requireWorkspace(ctx.span);
      final raw = '${pos[0]}';
      final content = '${pos[1]}';
      ws.writeFile(raw, content);
      return QudsWorkspace.normalizePath(raw);
    },
    signature: 'writeText(path: String, content: String) -> String',
    documentation:
        'Creates or updates a text asset inside the active workspace.',
  );

  builder.function(
    'writeJson',
    (pos, named, ctx) {
      checkMutable(ctx.span);
      final ws = requireWorkspace(ctx.span);
      final raw = '${pos[0]}';
      final value = pos[1];
      final pretty = (named['pretty'] as bool?) ?? true;
      final encoded = pretty
          ? const JsonEncoder.withIndent('  ').convert(value)
          : jsonEncode(value);
      ws.writeFile(raw, encoded);
      return QudsWorkspace.normalizePath(raw);
    },
    signature:
        'writeJson(path: String, data: Object?, pretty: bool = true) -> String',
    documentation:
        'Serializes a Quds Map/List to JSON and saves it inside the workspace.',
  );

  builder.function(
    'writeBytes',
    (pos, named, ctx) {
      checkMutable(ctx.span);
      final ws = requireWorkspace(ctx.span);
      final raw = '${pos[0]}';
      final list = pos[1] as Iterable;
      final bytes = Uint8List.fromList([
        for (final b in list) ((b as num).toInt() & 0xFF),
      ]);
      ws.writeAssetBytes(raw, bytes);
      return bytes.length;
    },
    signature: 'writeBytes(path: String, bytes: List<int>) -> int',
    documentation: 'Writes binary bytes to a workspace asset.',
  );

  builder.function(
    'renderImage',
    (pos, named, ctx) {
      final ws = requireWorkspace(ctx.span);
      final raw = '${pos[0]}';
      final norm = QudsWorkspace.normalizePath(raw);
      final bytes = ws.readAssetBytes(norm);
      if (bytes == null) {
        throw QudsRuntimeException(
            'Image asset `$raw` not found in workspace.', ctx.span);
      }
      final title = named['title'] as String? ?? norm;
      final caption = named['caption'] as String?;
      final dims = _peekImageDimensions(bytes);
      final out = QudsImageOutput(
        bytes: bytes,
        mimeType: QudsWorkspace.mimeTypeForPath(norm),
        title: title,
        caption: caption,
        assetPath: norm,
        width: dims?.$1,
        height: dims?.$2,
      );
      ctx.emitOutput(out);
      return out;
    },
    signature:
        'renderImage(path: String, title: String? = null, caption: String? = null)',
    documentation:
        'Renders a binary image asset (BMP/PNG/JPEG) directly to the visual stage.',
  );

  builder.function(
    'renderPixelGrid',
    (pos, named, ctx) {
      final rows = (pos[0] as Iterable).toList();
      if (rows.isEmpty) {
        throw QudsRuntimeException('Pixel grid cannot be empty.', ctx.span);
      }
      final height = rows.length;
      final firstRow = (rows.first as Iterable).toList();
      final width = firstRow.length;
      if (width == 0) {
        throw QudsRuntimeException(
            'Pixel grid width cannot be zero.', ctx.span);
      }
      final rgbRows = <List<List<int>>>[];
      for (final r in rows) {
        final rowPixels = <List<int>>[];
        for (final px in (r as Iterable)) {
          rowPixels.add(_parsePixelRgb(px));
        }
        rgbRows.add(rowPixels);
      }
      final scale = ((named['scale'] as num?)?.toInt() ?? 1).clamp(1, 16);
      final bmp = encodeQudsBmp24(rgbRows, scale: scale);
      final savePath = named['saveAs'] as String?;
      if (savePath != null && savePath.isNotEmpty) {
        final ws = getWorkspace();
        if (ws != null) {
          checkMutable(ctx.span);
          ws.writeAssetBytes(savePath, bmp);
        }
      }
      final out = QudsImageOutput(
        bytes: bmp,
        mimeType: 'image/bmp',
        title: named['title'] as String? ?? 'Generated Image',
        caption: named['caption'] as String?,
        assetPath: savePath,
        width: width * scale,
        height: height * scale,
      );
      ctx.emitOutput(out);
      return out;
    },
    signature:
        'renderPixelGrid(grid: List<List<Object>>, scale: int = 1, title: String? = null, caption: String? = null, saveAs: String? = null)',
    documentation:
        'Encodes a 2D pixel grid ([r,g,b] or "#RRGGBB") into a real 24-bit BMP image, optionally saving it to workspace assets, and displays it.',
  );

  return builder.build();
}

/// Encodes a 2D list of `[r, g, b]` pixels (top-to-bottom) as a standard 24-bit
/// uncompressed BMP image (pure Dart, zero external codecs).
Uint8List encodeQudsBmp24(List<List<List<int>>> rows, {int scale = 1}) {
  final srcH = rows.length;
  final srcW = rows.first.length;
  final width = srcW * scale;
  final height = srcH * scale;
  final rowStride = ((width * 3 + 3) ~/ 4) * 4;
  final pixelBytes = rowStride * height;
  final fileSize = 54 + pixelBytes;
  final data = ByteData(fileSize);

  // BMP File Header (14 bytes)
  data.setUint8(0, 0x42); // 'B'
  data.setUint8(1, 0x4D); // 'M'
  data.setUint32(2, fileSize, Endian.little);
  data.setUint32(10, 54, Endian.little);

  // DIB Header (BITMAPINFOHEADER, 40 bytes)
  data.setUint32(14, 40, Endian.little);
  data.setInt32(18, width, Endian.little);
  data.setInt32(22, height, Endian.little); // bottom-up rows
  data.setUint16(26, 1, Endian.little); // planes
  data.setUint16(28, 24, Endian.little); // 24-bit RGB
  data.setUint32(34, pixelBytes, Endian.little);

  final out = data.buffer.asUint8List();
  for (var y = 0; y < height; y++) {
    final srcY = (height - 1 - y) ~/ scale;
    final srcRow = rows[srcY];
    final rowOffset = 54 + y * rowStride;
    for (var x = 0; x < width; x++) {
      final px = srcRow[x ~/ scale];
      final off = rowOffset + x * 3;
      out[off] = px[2].clamp(0, 255); // B
      out[off + 1] = px[1].clamp(0, 255); // G
      out[off + 2] = px[0].clamp(0, 255); // R
    }
  }
  return out;
}

List<int> _parsePixelRgb(Object? raw) {
  if (raw is List && raw.length >= 3) {
    return [
      (raw[0] as num).toInt().clamp(0, 255),
      (raw[1] as num).toInt().clamp(0, 255),
      (raw[2] as num).toInt().clamp(0, 255),
    ];
  }
  if (raw is String) {
    var hex = raw.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) {
      final v = int.tryParse(hex, radix: 16);
      if (v != null) {
        return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
      }
    }
  }
  return const [15, 23, 42];
}

(int, int)? _peekImageDimensions(Uint8List bytes) {
  // BMP header
  if (bytes.length >= 26 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
    final bd = ByteData.sublistView(bytes);
    final w = bd.getInt32(18, Endian.little).abs();
    final h = bd.getInt32(22, Endian.little).abs();
    return (w, h);
  }
  // PNG header
  if (bytes.length >= 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    final bd = ByteData.sublistView(bytes);
    return (bd.getUint32(16, Endian.big), bd.getUint32(20, Endian.big));
  }
  return null;
}

Object? _deepCloneJson(Object? v) {
  if (v is Map) {
    return <String, Object?>{
      for (final e in v.entries) '${e.key}': _deepCloneJson(e.value),
    };
  }
  if (v is List) {
    return <Object?>[for (final item in v) _deepCloneJson(item)];
  }
  return v;
}

List<String> _parseCsvLine(String line, String delim) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (!inQuotes && ch == delim) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  out.add(buf.toString());
  return out;
}

Object _coerceCsvCell(String raw) {
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  final asInt = int.tryParse(raw);
  if (asInt != null) return asInt;
  final asDouble = double.tryParse(raw);
  if (asDouble != null) return asDouble;
  return raw;
}
