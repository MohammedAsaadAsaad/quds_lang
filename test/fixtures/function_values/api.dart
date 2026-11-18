int _receivers = 0;
int increment(int value) => value + 1;
int zero() => 7;
int receiverCount() => _receivers;
Counter makeCounter() {
  _receivers++;
  return Counter(10);
}

class Counter {
  Counter(this.base);
  final int base;
  int add(int other) => base + other;
  static int twice(int value) => value * 2;
}

class Box<T> {
  Box(this.value);
  final T value;
  T read() => value;
}

int optional([int value = 5]) => value;
int named({required int value}) => value;
T identity<T>(T value) => value;
