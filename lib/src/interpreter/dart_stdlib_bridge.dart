/// Pure-Dart standard library bridge (`dart:math`, `dart:convert`, `dart:async`,
/// `dart:typed_data`, `dart:core`) for interpreted Quds code and embedded SDKs.
///
/// Zero `dart:io` imports.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../source.dart';
import 'exceptions.dart';
import 'values.dart';

/// Resolves safe, pure-Dart standard libraries imported by `quds:*` SDKs or user code.
Map<String, Object?>? resolveDartStdlib(String uri) => switch (uri) {
      'dart:math' => _dartMath(),
      'dart:convert' => _dartConvert(),
      'dart:async' => _dartAsync(),
      'dart:typed_data' => _dartTypedData(),
      'dart:core' => _dartCore(),
      _ => null,
    };

/// Member lookup for wrapped Dart stdlib instances (`Random`, `JsonEncoder`,
/// `Utf8Codec`, `Base64Codec`, `ByteData`, `Point`, `Rectangle`).
Object? lookupStdlibInstanceMember(
  Object receiver,
  String name,
  SourceSpan span,
  Future<Object?> Function(
    Object? callee,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) invokeCallable,
) {
  if (receiver is math.Random) {
    return switch (name) {
      'nextInt' => QudsNativeFunction(
          'Random.nextInt', (p, n, c) => receiver.nextInt(p[0] as int)),
      'nextDouble' => QudsNativeFunction(
          'Random.nextDouble', (p, n, c) => receiver.nextDouble()),
      'nextBool' =>
        QudsNativeFunction('Random.nextBool', (p, n, c) => receiver.nextBool()),
      _ => null,
    };
  }
  if (receiver is math.Point) {
    return switch (name) {
      'x' => receiver.x,
      'y' => receiver.y,
      'magnitude' => receiver.magnitude,
      'distanceTo' => QudsNativeFunction('Point.distanceTo',
          (p, n, c) => receiver.distanceTo(p[0] as math.Point<num>)),
      'squaredDistanceTo' => QudsNativeFunction('Point.squaredDistanceTo',
          (p, n, c) => receiver.squaredDistanceTo(p[0] as math.Point<num>)),
      _ => null,
    };
  }
  if (receiver is JsonEncoder) {
    return switch (name) {
      'convert' => QudsNativeFunction(
          'JsonEncoder.convert', (p, n, c) => receiver.convert(p[0])),
      _ => null,
    };
  }
  if (receiver is Codec) {
    return switch (name) {
      'encode' =>
        QudsNativeFunction('Codec.encode', (p, n, c) => receiver.encode(p[0])),
      'decode' =>
        QudsNativeFunction('Codec.decode', (p, n, c) => receiver.decode(p[0])),
      _ => null,
    };
  }
  if (receiver is ByteData) {
    return switch (name) {
      'lengthInBytes' => receiver.lengthInBytes,
      'offsetInBytes' => receiver.offsetInBytes,
      'buffer' => receiver.buffer,
      'getInt8' => QudsNativeFunction(
          'ByteData.getInt8', (p, n, c) => receiver.getInt8(p[0] as int)),
      'setInt8' => QudsNativeFunction('ByteData.setInt8', (p, n, c) {
          receiver.setInt8(p[0] as int, p[1] as int);
          return null;
        }),
      'getUint8' => QudsNativeFunction(
          'ByteData.getUint8', (p, n, c) => receiver.getUint8(p[0] as int)),
      'setUint8' => QudsNativeFunction('ByteData.setUint8', (p, n, c) {
          receiver.setUint8(p[0] as int, p[1] as int);
          return null;
        }),
      'getInt32' => QudsNativeFunction(
          'ByteData.getInt32',
          (p, n, c) => receiver.getInt32(
              p[0] as int, p.length > 1 ? p[1] as Endian : Endian.big)),
      'setInt32' => QudsNativeFunction('ByteData.setInt32', (p, n, c) {
          receiver.setInt32(p[0] as int, p[1] as int,
              p.length > 2 ? p[2] as Endian : Endian.big);
          return null;
        }),
      'getFloat64' => QudsNativeFunction(
          'ByteData.getFloat64',
          (p, n, c) => receiver.getFloat64(
              p[0] as int, p.length > 1 ? p[1] as Endian : Endian.big)),
      'setFloat64' => QudsNativeFunction('ByteData.setFloat64', (p, n, c) {
          receiver.setFloat64(p[0] as int, (p[1] as num).toDouble(),
              p.length > 2 ? p[2] as Endian : Endian.big);
          return null;
        }),
      _ => null,
    };
  }
  if (receiver is TypedData) {
    return switch (name) {
      'lengthInBytes' => receiver.lengthInBytes,
      'offsetInBytes' => receiver.offsetInBytes,
      'elementSizeInBytes' => receiver.elementSizeInBytes,
      'buffer' => receiver.buffer,
      _ => null,
    };
  }
  return null;
}

Map<String, Object?> _dartMath() => {
      'pi': math.pi,
      'e': math.e,
      'ln2': math.ln2,
      'ln10': math.ln10,
      'log2e': math.log2e,
      'log10e': math.log10e,
      'sqrt2': math.sqrt2,
      'sqrt1_2': math.sqrt1_2,
      'sin': QudsNativeFunction('sin', (p, n, c) => math.sin(p[0] as num),
          isSync: true),
      'cos': QudsNativeFunction('cos', (p, n, c) => math.cos(p[0] as num),
          isSync: true),
      'tan': QudsNativeFunction('tan', (p, n, c) => math.tan(p[0] as num),
          isSync: true),
      'asin': QudsNativeFunction('asin', (p, n, c) => math.asin(p[0] as num),
          isSync: true),
      'acos': QudsNativeFunction('acos', (p, n, c) => math.acos(p[0] as num),
          isSync: true),
      'atan': QudsNativeFunction('atan', (p, n, c) => math.atan(p[0] as num),
          isSync: true),
      'atan2': QudsNativeFunction(
          'atan2', (p, n, c) => math.atan2(p[0] as num, p[1] as num),
          isSync: true),
      'sqrt': QudsNativeFunction('sqrt', (p, n, c) => math.sqrt(p[0] as num),
          isSync: true),
      'exp': QudsNativeFunction('exp', (p, n, c) => math.exp(p[0] as num),
          isSync: true),
      'log': QudsNativeFunction('log', (p, n, c) => math.log(p[0] as num),
          isSync: true),
      'pow': QudsNativeFunction(
          'pow', (p, n, c) => math.pow(p[0] as num, p[1] as num),
          isSync: true),
      'min': QudsNativeFunction(
          'min', (p, n, c) => math.min(p[0] as num, p[1] as num),
          isSync: true),
      'max': QudsNativeFunction(
          'max', (p, n, c) => math.max(p[0] as num, p[1] as num),
          isSync: true),
      'Random': _callableNamespace(
        'Random',
        (p, n, c) => math.Random(p.isEmpty ? null : p[0] as int?),
        {
          'secure': QudsNativeFunction(
              'Random.secure', (p, n, c) => math.Random.secure(),
              isSync: true),
        },
      ),
      'Point': QudsNativeFunction(
          'Point', (p, n, c) => math.Point<num>(p[0] as num, p[1] as num),
          isSync: true),
      'Rectangle': QudsNativeFunction(
          'Rectangle',
          (p, n, c) => math.Rectangle<num>(
              p[0] as num, p[1] as num, p[2] as num, p[3] as num),
          isSync: true),
    };

Map<String, Object?> _dartConvert() => {
      'jsonDecode':
          QudsNativeFunction('jsonDecode', (p, n, c) => jsonDecode('${p[0]}')),
      'jsonEncode':
          QudsNativeFunction('jsonEncode', (p, n, c) => jsonEncode(p[0])),
      'JsonEncoder': _callableNamespace(
        'JsonEncoder',
        (p, n, c) => const JsonEncoder(),
        {
          'withIndent': QudsNativeFunction(
            'JsonEncoder.withIndent',
            (p, n, c) => JsonEncoder.withIndent(p[0] as String?),
          ),
        },
      ),
      'utf8': utf8,
      'base64': base64,
      'base64Url': base64Url,
      'ascii': ascii,
      'latin1': latin1,
      'base64Encode': QudsNativeFunction('base64Encode',
          (p, n, c) => base64Encode((p[0] as List).cast<int>())),
      'base64Decode': QudsNativeFunction(
          'base64Decode', (p, n, c) => base64Decode('${p[0]}')),
    };

Map<String, Object?> _dartAsync() => {
      'Completer':
          QudsNativeFunction('Completer', (p, n, c) => Completer<Object?>()),
      'Timer': _callableNamespace(
        'Timer',
        (p, n, c) {
          final dur = p[0] as Duration;
          final cb = p[1];
          return Timer(dur, () {
            c.invokeCallable(cb, const [], const {}, c.span);
          });
        },
        {
          'periodic': QudsNativeFunction('Timer.periodic', (p, n, c) {
            final dur = p[0] as Duration;
            final cb = p[1];
            return Timer.periodic(dur, (t) {
              c.invokeCallable(cb, [t], const {}, c.span);
            });
          }),
          'run': QudsNativeFunction('Timer.run', (p, n, c) {
            final cb = p[0];
            Timer.run(() {
              c.invokeCallable(cb, const [], const {}, c.span);
            });
            return null;
          }),
        },
      ),
      'Future': _callableNamespace(
        'Future',
        (p, n, c) => QudsFuture(Future<Object?>(
            () => c.invokeCallable(p[0], const [], const {}, c.span))),
        {
          'value': QudsNativeFunction(
              'Future.value',
              (p, n, c) =>
                  QudsFuture(Future<Object?>.value(p.isEmpty ? null : p[0]))),
          'error': QudsNativeFunction('Future.error',
              (p, n, c) => QudsFuture(Future<Object?>.error(p[0]!))),
          'delayed': QudsNativeFunction('Future.delayed', (p, n, c) {
            final dur = p[0] as Duration;
            if (p.length > 1 && p[1] != null) {
              final cb = p[1];
              return QudsFuture(Future<Object?>.delayed(
                  dur, () => c.invokeCallable(cb, const [], const {}, c.span)));
            }
            return QudsFuture(Future<void>.delayed(dur));
          }),
          'microtask': QudsNativeFunction('Future.microtask', (p, n, c) {
            final cb = p[0];
            return QudsFuture(Future<Object?>.microtask(
                () => c.invokeCallable(cb, const [], const {}, c.span)));
          }),
          'wait': QudsNativeFunction('Future.wait', (p, n, c) {
            final raw = p[0] as Iterable;
            final futures = [
              for (final item in raw)
                item is QudsFuture
                    ? item.future
                    : item is Future
                        ? item
                        : Future<Object?>.value(item)
            ];
            return QudsFuture(Future.wait<Object?>(futures));
          }),
        },
      ),
      'TimeoutException': QudsNativeFunction('TimeoutException',
          (p, n, c) => TimeoutException(p.isEmpty ? null : '${p[0]}')),
    };

Map<String, Object?> _dartTypedData() => {
      'Float32List': _typedListNamespace(
        'Float32List',
        (len) => Float32List(len),
        (items) => Float32List.fromList(
            items.map((e) => (e as num).toDouble()).toList()),
      ),
      'Float64List': _typedListNamespace(
        'Float64List',
        (len) => Float64List(len),
        (items) => Float64List.fromList(
            items.map((e) => (e as num).toDouble()).toList()),
      ),
      'Int8List': _typedListNamespace(
        'Int8List',
        (len) => Int8List(len),
        (items) => Int8List.fromList(items.cast<int>().toList()),
      ),
      'Uint8List': _typedListNamespace(
        'Uint8List',
        (len) => Uint8List(len),
        (items) => Uint8List.fromList(items.cast<int>().toList()),
      ),
      'Uint8ClampedList': _typedListNamespace(
        'Uint8ClampedList',
        (len) => Uint8ClampedList(len),
        (items) => Uint8ClampedList.fromList(items.cast<int>().toList()),
      ),
      'Int16List': _typedListNamespace(
        'Int16List',
        (len) => Int16List(len),
        (items) => Int16List.fromList(items.cast<int>().toList()),
      ),
      'Uint16List': _typedListNamespace(
        'Uint16List',
        (len) => Uint16List(len),
        (items) => Uint16List.fromList(items.cast<int>().toList()),
      ),
      'Int32List': _typedListNamespace(
        'Int32List',
        (len) => Int32List(len),
        (items) => Int32List.fromList(items.cast<int>().toList()),
      ),
      'Uint32List': _typedListNamespace(
        'Uint32List',
        (len) => Uint32List(len),
        (items) => Uint32List.fromList(items.cast<int>().toList()),
      ),
      'ByteData': _callableNamespace(
        'ByteData',
        (p, n, c) => ByteData(p[0] as int),
        {
          'view': QudsNativeFunction(
              'ByteData.view', (p, n, c) => ByteData.view(p[0] as ByteBuffer)),
          'sublistView': QudsNativeFunction('ByteData.sublistView',
              (p, n, c) => ByteData.sublistView(p[0] as TypedData)),
        },
      ),
      'Endian': QudsNamespace('Endian', {
        'big': Endian.big,
        'little': Endian.little,
        'host': Endian.host,
      }),
      'ByteBuffer': QudsNamespace('ByteBuffer', const {}),
      'TypedData': QudsNamespace('TypedData', const {}),
    };

Map<String, Object?> _dartCore() => {
      'BigInt': QudsNamespace('BigInt', {
        'zero': BigInt.zero,
        'one': BigInt.one,
        'two': BigInt.two,
        'from': QudsNativeFunction(
            'BigInt.from', (p, n, c) => BigInt.from(p[0] as num),
            isSync: true),
        'parse': QudsNativeFunction('BigInt.parse',
            (p, n, c) => BigInt.parse('${p[0]}', radix: n['radix'] as int?),
            isSync: true),
        'tryParse': QudsNativeFunction('BigInt.tryParse',
            (p, n, c) => BigInt.tryParse('${p[0]}', radix: n['radix'] as int?),
            isSync: true),
      }),
    };

/// Callable namespace: supports both `Type(args)` AND `Type.namedCtor(args)`.
class QudsCallableNamespace extends QudsNativeFunction {
  QudsCallableNamespace(
    super.name,
    super.callback,
    this.members,
  );

  final Map<String, Object?> members;

  Object? getMember(String memberName, SourceSpan span) {
    if (members.containsKey(memberName)) return members[memberName];
    throw QudsRuntimeException(
        '`$name` has no static member `$memberName`.', span);
  }
}

QudsCallableNamespace _callableNamespace(
  String name,
  QudsHostCallback ctor,
  Map<String, Object?> members,
) =>
    QudsCallableNamespace(name, ctor, members);

QudsCallableNamespace _typedListNamespace(
  String name,
  Object Function(int length) allocate,
  Object Function(Iterable<Object?> items) fromList,
) =>
    QudsCallableNamespace(
      name,
      (p, n, c) => allocate(p[0] as int),
      {
        'fromList': QudsNativeFunction(
            '$name.fromList', (p, n, c) => fromList(p[0] as Iterable<Object?>)),
      },
    );
