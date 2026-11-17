// Runtime snippets emitted from typed readonly metadata, not source rewrites.
const readonlyGraphHelpers = r'''
mixin _QudsReadonlyView {
  bool get $qudsReadonly => true;
  bool $qudsReadonlyMatches(Object? candidate);
}
final _qReadonlyViews = Expando<Map<Type, Object>>();
final _qReadonlySources = Expando<Object>();
Object? _qReadonlyUnwrap(Object? value) {
  if (value == null || value is num || value is bool || value is String) return value;
  return _qReadonlySources[value] ?? value;
}
bool _qReadonlyMatches(Object? source, Object? candidate) {
  if (source == _qReadonlyUnwrap(candidate)) return true;
  if (candidate == null) return false;
  try { return (candidate as dynamic).$qudsReadonlyMatches(source) == true; }
  on NoSuchMethodError { return false; }
}
T _qReadonlyCached<T extends Object>(Object source, T Function() create) {
  if (source is _QudsReadonlyView) return source as T;
  try { if ((source as dynamic).$qudsReadonly == true) return source as T; }
  on NoSuchMethodError { /* An ordinary mutable source. */ }
  final types = _qReadonlyViews[source] ??= <Type, Object>{};
  final found = types[T];
  if (found != null) return found as T;
  final result = create();
  types[T] = result;
  _qReadonlySources[result] = source;
  return result;
}
''';
const readonlyListHelpers = r'''
List<E> _qReadonlyList<E>(List<E> source, E Function(E) read) =>
    _qReadonlyCached<List<E>>(source, () => _QudsReadonlyList<E>(source, read));
class _QudsReadonlyList<E> extends ListBase<E> with _QudsReadonlyView {
  _QudsReadonlyList(this._source, this._read);
  final List<E> _source;
  final E Function(E) _read;
  bool $qudsReadonlyMatches(Object? candidate) => _source == _qReadonlyUnwrap(candidate);
  int get length => _source.length;
  set length(int value) => throw UnsupportedError('readonly list');
  E operator [](int index) => _read(_source[index]);
  void operator []=(int index, E value) => throw UnsupportedError('readonly list');
  bool contains(Object? value) => _source.any((item) => _qReadonlyMatches(item, value));
}
''';
const readonlyMapHelpers = r'''
Map<K, V> _qReadonlyMap<K, V>(Map<K, V> source, K Function(K) readKey, V Function(V) readValue) =>
    _qReadonlyCached<Map<K, V>>(source, () => _QudsReadonlyMap<K, V>(source, readKey, readValue));
class _QudsReadonlyMap<K, V> extends MapBase<K, V> with _QudsReadonlyView {
  _QudsReadonlyMap(this._source, this._readKey, this._readValue);
  final Map<K, V> _source;
  final K Function(K) _readKey;
  final V Function(V) _readValue;
  bool $qudsReadonlyMatches(Object? candidate) => _source == _qReadonlyUnwrap(candidate);
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
  bool containsValue(Object? value) => _source.values.any((item) => _qReadonlyMatches(item, value));
  V? operator [](Object? key) {
    final value = _source[_key(key)];
    return value == null ? null : _readValue(value);
  }
  void operator []=(K key, V value) => throw UnsupportedError('readonly map');
  V? remove(Object? key) => throw UnsupportedError('readonly map');
  void clear() => throw UnsupportedError('readonly map');
}
''';
const readonlySetHelpers = r'''
Set<E> _qReadonlySet<E>(Set<E> source, E Function(E) read) =>
    _qReadonlyCached<Set<E>>(source, () => _QudsReadonlySet<E>(source, read));
class _QudsReadonlySet<E> extends SetBase<E> with _QudsReadonlyView {
  _QudsReadonlySet(this._source, this._read);
  final Set<E> _source;
  final E Function(E) _read;
  bool $qudsReadonlyMatches(Object? candidate) => _source == _qReadonlyUnwrap(candidate);
  int get length => _source.length;
  Iterator<E> get iterator => _source.map(_read).iterator;
  bool contains(Object? value) => _source.any((item) => _qReadonlyMatches(item, value));
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
''';
