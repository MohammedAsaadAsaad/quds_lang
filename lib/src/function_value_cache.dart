/// Generated function-value canonicalization. Only live returned closures own a
/// slot (and its receiver); buckets and finalizer tokens never own either one.
const functionValueCacheHelpers = r'''
class $QudsValueSlot {
  $QudsValueSlot(this.receiver, this.key, this.types, this.functionKey);
  final Object? receiver;
  final String key;
  final List<Type> types;
  final bool functionKey;
  Object? target;
  late Object? value;
}
final $QudsValueCache = <int, List<WeakReference<$QudsValueSlot>>>{};
final $QudsValueFinalizer = Finalizer<(int, WeakReference<$QudsValueSlot>)>((token) {
  final bucket = $QudsValueCache[token.$1];
  if (bucket == null) return;
  bucket.remove(token.$2);
  if (bucket.isEmpty) $QudsValueCache.remove(token.$1);
});
Type $QudsValueType<T>() => T;
Object? $QudsCachedValue(Object? receiver, String key, List<Type> types,
    Object? Function($QudsValueSlot) create, {bool functionKey = false}) {
  final hash = functionKey ? receiver.hashCode : identityHashCode(receiver);
  final bucket = $QudsValueCache[hash];
  if (bucket != null) {
    for (var i = bucket.length - 1; i >= 0; i--) {
      final slot = bucket[i].target;
      if (slot == null) { bucket.removeAt(i); continue; }
      final sameReceiver = functionKey
          ? slot.receiver == receiver : identical(slot.receiver, receiver);
      if (slot.functionKey != functionKey || !sameReceiver || slot.key != key ||
          slot.types.length != types.length) continue;
      var same = true;
      for (var j = 0; j < types.length; j++) {
        if (slot.types[j] != types[j]) { same = false; break; }
      }
      if (same) return slot.value;
    }
    if (bucket.isEmpty) $QudsValueCache.remove(hash);
  }
  final slot = $QudsValueSlot(receiver, key, types, functionKey);
  final value = create(slot);
  slot.value = value;
  final reference = WeakReference(slot);
  ($QudsValueCache[hash] ??= []).add(reference);
  $QudsValueFinalizer.attach(slot, (hash, reference));
  return value;
}
''';
