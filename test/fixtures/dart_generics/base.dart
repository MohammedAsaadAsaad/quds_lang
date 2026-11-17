class NativeParent<T> {
  NativeParent(T value) : value = value;
  final T value;
  T read() => value;
  List<R> mapped<R>(R Function(T) convert) => [convert(value)];
  String pair<R>(R first, R second) => '$first,$second';
  R identity<R>(R input) => input;
  R bounded<R extends num>(R input) => input;
}

class NativeNumbers<T extends num> {
  NativeNumbers(T input) : value = input;
  final T value;
}

class NativeField<T> {
  NativeField(this.value);
  final T value;
}

class NativeWide {
  num narrow(num input) => input;
}

mixin NativeNarrow {
  int narrow(num input) => input.toInt();
}

class NativeMixed extends NativeWide with NativeNarrow {
  NativeMixed();
}

class NativeEmpty<T> {
  List<T> get values => <T>[];
}

abstract class NativeAbstract<T> {}
