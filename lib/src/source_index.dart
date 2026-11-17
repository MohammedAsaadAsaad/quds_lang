import 'dart:typed_data';

/// One linear pass for UTF-8 AST offsets and UTF-16 editor coordinates.
/// Reuse this index for a batch, rather than rescanning the file per token.
class SourceIndex {
  SourceIndex(this.source) : _bytes = Uint32List(source.length + 1) {
    var byte = 0;
    for (var i = 0; i < source.length; i++) {
      final unit = source.codeUnitAt(i);
      if (unit == 13) {
        if (i + 1 == source.length || source.codeUnitAt(i + 1) != 10) {
          _lines.add(i + 1);
        }
      } else if (unit == 10) {
        _lines.add(i + 1);
      }
      if (unit >= 0xd800 &&
          unit <= 0xdbff &&
          i + 1 < source.length &&
          source.codeUnitAt(i + 1) >= 0xdc00 &&
          source.codeUnitAt(i + 1) <= 0xdfff) {
        _bytes[i + 1] = byte + 3; // A prefix ending at an unpaired surrogate.
        byte += 4;
        _bytes[++i + 1] = byte;
      } else {
        byte += unit < 0x80
            ? 1
            : unit < 0x800
                ? 2
                : 3;
        _bytes[i + 1] = byte;
      }
    }
  }
  final String source;
  final Uint32List _bytes;
  final _lines = <int>[0];

  int byteOffset(int utf16) => _bytes[utf16.clamp(0, source.length)];
  int stringIndex(int byteOffset) {
    var lo = 0, hi = source.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_bytes[mid] < byteOffset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  (int, int) position(int utf16) {
    utf16 = utf16.clamp(0, source.length);
    var lo = 0, hi = _lines.length;
    while (lo + 1 < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_lines[mid] <= utf16) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo, utf16 - _lines[lo]);
  }
}
