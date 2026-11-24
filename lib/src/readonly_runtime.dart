import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

/// Shared identity across generated libraries, including conversion providers.
class ConversionError implements Exception {
  ConversionError(this.message);
  final String message;
  @override
  String toString() => 'ConversionError: $message';
}

/// Shared Result<T, E> identity across generated Quds libraries.
sealed class Result<T, E> {
  const Result();
}

class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);
  @override
  bool operator ==(Object other) => other is Ok && other.value == value;
  @override
  int get hashCode => Object.hash(Ok, value);
  @override
  String toString() => 'Ok($value)';
}

class Error<T, E> extends Result<T, E> {
  final E error;
  const Error(this.error);
  @override
  bool operator ==(Object other) => other is Error && other.error == error;
  @override
  int get hashCode => Object.hash(Error, error);
  @override
  String toString() => 'Error($error)';
}

T? safeConvert<S, T>(S value, T Function(S) conversion) {
  try {
    return conversion(value);
  } on ConversionError {
    return null;
  }
}

mixin ReadonlyView {
  bool get $qudsReadonly => true;
  bool $qudsReadonlyMatches(Object? candidate);
}
final _qReadonlyViews = Expando<Map<Type, Object>>();
final _qReadonlySources = Expando<Object>();
Object? _qReadonlyUnwrap(Object? value) {
  if (value == null ||
      value is num ||
      value is bool ||
      value is String ||
      value is Record) return value;
  return _qReadonlySources[value] ?? value;
}

bool _qReadonlyMatches(Object? source, Object? candidate) {
  if (source == _qReadonlyUnwrap(candidate)) return true;
  if (candidate == null) return false;
  try {
    return (candidate as dynamic).$qudsReadonlyMatches(source) == true;
  } on NoSuchMethodError {
    return false;
  }
}

T cachedView<T extends Object>(Object source, T Function() create) {
  if (source is ReadonlyView || _qReadonlySources[source] != null)
    return source as T;
  try {
    if ((source as dynamic).$qudsReadonly == true) return source as T;
  } on NoSuchMethodError {/* An ordinary mutable source. */}
  final types = _qReadonlyViews[source] ??= <Type, Object>{};
  final found = types[T];
  if (found != null) return found as T;
  final result = create();
  types[T] = result;
  _qReadonlySources[result] = source;
  return result;
}

List<E> _qReadonlyList<E>(List<E> source, E Function(E) read) =>
    cachedView<List<E>>(source, () => _QudsReadonlyList<E>(source, read));

class _QudsReadonlyList<E> extends ListBase<E> with ReadonlyView {
  _QudsReadonlyList(this._source, this._read);
  final List<E> _source;
  final E Function(E) _read;
  bool $qudsReadonlyMatches(Object? candidate) =>
      _source == _qReadonlyUnwrap(candidate);
  int get length => _source.length;
  set length(int value) => throw UnsupportedError('readonly list');
  E operator [](int index) => _read(_source[index]);
  void operator []=(int index, E value) =>
      throw UnsupportedError('readonly list');
  bool contains(Object? value) =>
      _source.any((item) => _qReadonlyMatches(item, value));
}

Map<K, V> _qReadonlyMap<K, V>(
        Map<K, V> source, K Function(K) readKey, V Function(V) readValue) =>
    cachedView<Map<K, V>>(
        source, () => _QudsReadonlyMap<K, V>(source, readKey, readValue));

class _QudsReadonlyMap<K, V> extends MapBase<K, V> with ReadonlyView {
  _QudsReadonlyMap(this._source, this._readKey, this._readValue);
  final Map<K, V> _source;
  final K Function(K) _readKey;
  final V Function(V) _readValue;
  bool $qudsReadonlyMatches(Object? candidate) =>
      _source == _qReadonlyUnwrap(candidate);
  Object? _key(Object? key) {
    final direct = _qReadonlyUnwrap(key);
    if (_source.containsKey(direct)) return direct;
    for (final candidate in _source.keys) {
      if (_qReadonlyMatches(candidate, key)) return candidate;
    }
    return key;
  }

  Iterable<K> get keys => _source.keys.map(_readKey);
  bool containsKey(Object? key) => _source.containsKey(_key(key));
  bool containsValue(Object? value) =>
      _source.values.any((item) => _qReadonlyMatches(item, value));
  V? operator [](Object? key) {
    final value = _source[_key(key)];
    return value == null ? null : _readValue(value);
  }

  void operator []=(K key, V value) => throw UnsupportedError('readonly map');
  V? remove(Object? key) => throw UnsupportedError('readonly map');
  void clear() => throw UnsupportedError('readonly map');
}

Set<E> _qReadonlySet<E>(Set<E> source, E Function(E) read) =>
    cachedView<Set<E>>(source, () => _QudsReadonlySet<E>(source, read));

class _QudsReadonlySet<E> extends SetBase<E> with ReadonlyView {
  _QudsReadonlySet(this._source, this._read);
  final Set<E> _source;
  final E Function(E) _read;
  bool $qudsReadonlyMatches(Object? candidate) =>
      _source == _qReadonlyUnwrap(candidate);
  int get length => _source.length;
  Iterator<E> get iterator => _source.map(_read).iterator;
  bool contains(Object? value) =>
      _source.any((item) => _qReadonlyMatches(item, value));
  E? lookup(Object? value) {
    for (final item in _source) {
      if (_qReadonlyMatches(item, value)) return _read(item);
    }
    return null;
  }

  bool add(E value) => throw UnsupportedError('readonly set');
  bool remove(Object? value) => throw UnsupportedError('readonly set');
  void clear() => throw UnsupportedError('readonly set');
  Set<E> toSet() => <E>{...this};
}

sealed class ReadonlyGuard<T> {
  const ReadonlyGuard();
  T protect(T value);
  void install(Map<Type, ReadonlyGuard<dynamic>> guards) {
    guards.putIfAbsent(T, () => this);
  }
}

final _objectGuards = Expando<Map<Type, ReadonlyGuard<dynamic>>>();
Map<Type, ReadonlyGuard<dynamic>> guardsOf(
    Iterable<ReadonlyGuard<dynamic>> descriptors) {
  final result = <Type, ReadonlyGuard<dynamic>>{};
  for (final descriptor in descriptors) {
    descriptor.install(result);
  }
  return result;
}

Map<Type, ReadonlyGuard<dynamic>> guardsFor(Object source) =>
    source is num || source is bool || source is String
        ? const {}
        : _objectGuards[source] ?? const {};
T registerGuards<T extends Object>(
    T source, Iterable<ReadonlyGuard<dynamic>> descriptors) {
  final guards = _objectGuards[source] ??= {};
  for (final descriptor in descriptors) {
    descriptor.install(guards);
  }
  return source;
}

ReadonlyGuard<T> guardFor<T>(Map<Type, ReadonlyGuard<dynamic>> guards) =>
    guards[T] as ReadonlyGuard<T>? ?? AutoGuard<T>();

final class AutoGuard<T> extends ReadonlyGuard<T> {
  const AutoGuard();
  @override
  T protect(T value) {
    if (value == null ||
        value is num ||
        value is bool ||
        value is String ||
        value is BigInt ||
        value is Enum ||
        value is Function ||
        value is Symbol ||
        value is Type ||
        value is DateTime ||
        value is Duration ||
        value is Uri ||
        value is RegExp) return value;
    if (value is ByteBuffer)
      return value.asUint8List().asUnmodifiableView().buffer as T;
    if (value is TypedData) return (value as dynamic).asUnmodifiableView() as T;
    if (value is ReadonlyView || _qReadonlySources[value as Object] != null)
      return value;
    try {
      if ((value as dynamic).$qudsReadonly == true) return value;
      final protected = (value as dynamic)
          .$qudsReadonlyView(const <Type, ReadonlyGuard<dynamic>>{});
      if (protected is T && protected is ReadonlyView) return protected;
    } on NoSuchMethodError {/* Not a generated Quds class. */}
    throw UnsupportedError('No sound readonly guard metadata for $T');
  }
}

final class NullableGuard<E> extends ReadonlyGuard<E?> {
  const NullableGuard(this.element);
  final ReadonlyGuard<E> element;
  @override
  E? protect(E? value) => value == null ? null : element.protect(value);
  @override
  void install(Map<Type, ReadonlyGuard<dynamic>> guards) {
    super.install(guards);
    element.install(guards);
  }
}

final class ListGuard<E> extends ReadonlyGuard<List<E>> {
  const ListGuard(this.element);
  final ReadonlyGuard<E> element;
  @override
  List<E> protect(List<E> value) => _qReadonlyList<E>(value, element.protect);
  @override
  void install(Map<Type, ReadonlyGuard<dynamic>> guards) {
    guards[List<E>] = this;
    element.install(guards);
  }
}

final class SetGuard<E> extends ReadonlyGuard<Set<E>> {
  const SetGuard(this.element);
  final ReadonlyGuard<E> element;
  @override
  Set<E> protect(Set<E> value) => _qReadonlySet<E>(value, element.protect);
  @override
  void install(Map<Type, ReadonlyGuard<dynamic>> guards) {
    guards[Set<E>] = this;
    element.install(guards);
  }
}

final class MapGuard<K, V> extends ReadonlyGuard<Map<K, V>> {
  const MapGuard(this.key, this.value);
  final ReadonlyGuard<K> key;
  final ReadonlyGuard<V> value;
  @override
  Map<K, V> protect(Map<K, V> source) =>
      _qReadonlyMap<K, V>(source, key.protect, value.protect);
  @override
  void install(Map<Type, ReadonlyGuard<dynamic>> guards) {
    guards[Map<K, V>] = this;
    key.install(guards);
    value.install(guards);
  }
}

final class IterableGuard<E> extends ReadonlyGuard<Iterable<E>> {
  const IterableGuard(this.element);
  final ReadonlyGuard<E> element;
  @override
  Iterable<E> protect(Iterable<E> value) => value.map(element.protect);
  @override
  void install(Map<Type, ReadonlyGuard<dynamic>> guards) {
    guards[Iterable<E>] = this;
    element.install(guards);
  }
}

final class ModelGuard<T> extends ReadonlyGuard<T> {
  ModelGuard(Map<Type, ReadonlyGuard<dynamic>> guards)
      : guards = Map.unmodifiable(guards);
  final Map<Type, ReadonlyGuard<dynamic>> guards;
  @override
  T protect(T value) {
    if (value is ReadonlyView) return value;
    try {
      final source = value as Object;
      final merged = {...guardsFor(source), ...guards};
      final result = (value as dynamic).$qudsReadonlyView(merged);
      if (result is T && result is ReadonlyView) return result;
    } on NoSuchMethodError {/* Unknown/foreign runtime implementation. */}
    throw UnsupportedError('No generated readonly class implementation for $T');
  }

  @override
  void install(Map<Type, ReadonlyGuard<dynamic>> target) {
    target[T] = this;
    target.addAll(guards);
  }
}

// A Boolean comparison preserves source identity without exposing the source.
bool sameSourceEquals(Object? left, Object? right) =>
    _qReadonlyUnwrap(left) == _qReadonlyUnwrap(right);
bool readonlyEquals(Object? left, Object? right) {
  final originalLeft = _qReadonlyUnwrap(left);
  final originalRight = _qReadonlyUnwrap(right);
  if (!identical(left, originalLeft) || !identical(right, originalRight))
    return originalLeft == originalRight;
  if (left == null || left is num || left is bool || left is String)
    return left == right;
  try {
    if ((left as dynamic).$qudsReadonly == true)
      return (left as dynamic).$qudsReadonlyMatches(right) == true;
  } on NoSuchMethodError {/* An ordinary source object. */}
  if (right != null && right is! num && right is! bool && right is! String) {
    try {
      if ((right as dynamic).$qudsReadonly == true)
        return (right as dynamic).$qudsReadonlyMatches(left) == true;
    } on NoSuchMethodError {/* An ordinary source object. */}
  }
  return left == right;
}

class _LazyComputation {
  _LazyComputation(this.slot);
  final Object slot;
  final origins = Map<Object?, Object?>.identity();
}

_LazyComputation? _activeLazyComputation;
void recordLazyOrigin(Object owner, Object? protected, Object? original) {
  final context = _activeLazyComputation;
  if (context == null) return;
  try {
    if ((owner as dynamic).$qudsIsLazySlot(context.slot) == true)
      context.origins[protected] = original;
  } on NoSuchMethodError {/* Not the declaring Quds owner. */}
}

T protectResult<T>(Object owner, T value, T Function(T) protect) {
  final result = protect(value);
  recordLazyOrigin(owner, result, value);
  return result;
}

final class LazySlot<T> {
  bool _ready = false;
  late T _value;
  T mutableValue(T Function() compute) {
    if (!_ready) {
      _value = compute();
      _ready = true;
    }
    return _value;
  }

  T readonlyValue(T Function() compute, ReadonlyGuard<T> guard) {
    if (!_ready) {
      final previous = _activeLazyComputation;
      final context = _LazyComputation(this);
      _activeLazyComputation = context;
      try {
        final result = compute();
        _value = (context.origins.containsKey(result)
            ? context.origins[result]
            : result) as T;
        _ready = true;
      } finally {
        _activeLazyComputation = previous;
      }
    }
    return guard.protect(_value);
  }
}

class QudsEvent<T extends Function> {
  final List<T> handlers = <T>[];
  void add(T handler) => handlers.add(handler);
}

final class EventGuard<T extends Function> extends ReadonlyGuard<QudsEvent<T>> {
  const EventGuard();
  @override
  QudsEvent<T> protect(QudsEvent<T> value) =>
      cachedView<QudsEvent<T>>(value, () => _ReadonlyEvent<T>(value));
}

class _ReadonlyEvent<T extends Function>
    with ReadonlyView
    implements QudsEvent<T> {
  _ReadonlyEvent(this._source);
  final QudsEvent<T> _source;
  @override
  bool $qudsReadonlyMatches(Object? candidate) =>
      sameSourceEquals(_source, candidate);
  @override
  List<T> get handlers => _qReadonlyList<T>(_source.handlers, (value) => value);
  @override
  void add(T handler) => throw UnsupportedError('readonly event');
}

final class FutureGuard<E> extends ReadonlyGuard<Future<E>> {
  const FutureGuard(this.element);
  final ReadonlyGuard<E> element;
  @override
  Future<E> protect(Future<E> value) =>
      cachedView<Future<E>>(value, () => value.then<E>(element.protect));
  @override
  void install(Map<Type, ReadonlyGuard<dynamic>> guards) {
    guards[Future<E>] = this;
    element.install(guards);
  }
}

final class StreamGuard<E> extends ReadonlyGuard<Stream<E>> {
  const StreamGuard(this.element);
  final ReadonlyGuard<E> element;
  @override
  Stream<E> protect(Stream<E> value) =>
      cachedView<Stream<E>>(value, () => value.map(element.protect));
  @override
  void install(Map<Type, ReadonlyGuard<dynamic>> guards) {
    guards[Stream<E>] = this;
    element.install(guards);
  }
}

class _ValueEquality {
  final active = Map<Object, Set<Object>>.identity();
  bool compare(Object? left, Object? right) {
    if (readonlyEquals(left, right)) return true;
    if (left == null || right == null) return false;
    final pairs = active.putIfAbsent(left, () => Set<Object>.identity());
    if (!pairs.add(right)) return true;
    try {
      if (left is List && right is List) {
        if (left.length != right.length) return false;
        for (var index = 0; index < left.length; index++) {
          if (!compare(left[index], right[index])) return false;
        }
        return true;
      }
      if (left is Map && right is Map) {
        if (left.length != right.length) return false;
        for (final entry in left.entries) {
          var found = false;
          for (final other in right.entries) {
            if (readonlyEquals(entry.key, other.key)) {
              if (!compare(entry.value, other.value)) return false;
              found = true;
              break;
            }
          }
          if (!found) return false;
        }
        return true;
      }
      if (left is Set && right is Set) {
        if (left.length != right.length) return false;
        final remaining = right.toList();
        for (final value in left) {
          final index = remaining.indexWhere((other) => compare(value, other));
          if (index < 0) return false;
          remaining.removeAt(index);
        }
        return true;
      }
      return false;
    } finally {
      pairs.remove(right);
      if (pairs.isEmpty) active.remove(left);
    }
  }
}

_ValueEquality? _valueEquality;
bool valueEquals(Object left, Object right, List<Object?> leftFields,
    List<Object?> rightFields) {
  final top = _valueEquality == null;
  final context = _valueEquality ??= _ValueEquality();
  final originalLeft = _qReadonlyUnwrap(left) as Object;
  final originalRight = _qReadonlyUnwrap(right) as Object;
  final pairs =
      context.active.putIfAbsent(originalLeft, () => Set<Object>.identity());
  if (!pairs.add(originalRight)) return true;
  try {
    return context.compare(leftFields, rightFields);
  } finally {
    pairs.remove(originalRight);
    if (pairs.isEmpty) context.active.remove(originalLeft);
    if (top) _valueEquality = null;
  }
}

class _ValueHash {
  final active = Set<Object>.identity();
  var cyclic = false;
  int hash(Object? value) {
    if (value == null) return 0;
    if (value is List || value is Set || value is Map) {
      final original = _qReadonlyUnwrap(value) as Object;
      if (!active.add(original)) {
        cyclic = true;
        return 0;
      }
      try {
        if (value is List) return Object.hashAll(value.map(hash));
        if (value is Set) {
          var sum = 0;
          for (final item in value) {
            sum = (sum + hash(item)) & 0x1fffffff;
          }
          return Object.hash(value.length, sum);
        }
        var sum = 0;
        final map = value as Map;
        for (final entry in map.entries) {
          final key = _qReadonlyUnwrap(entry.key);
          sum = (sum + Object.hash(key?.hashCode ?? 0, hash(entry.value))) &
              0x1fffffff;
        }
        return Object.hash(map.length, sum);
      } finally {
        active.remove(original);
      }
    }
    return value.hashCode;
  }
}

_ValueHash? _valueHash;
int valueHash(Object owner, List<Object?> fields) {
  final top = _valueHash == null;
  final context = _valueHash ??= _ValueHash();
  final original = _qReadonlyUnwrap(owner) as Object;
  if (!context.active.add(original)) {
    context.cyclic = true;
    return 0;
  }
  try {
    final result = Object.hashAll(fields.map(context.hash));
    return context.cyclic ? 0 : result;
  } finally {
    context.active.remove(original);
    if (top) _valueHash = null;
  }
}
