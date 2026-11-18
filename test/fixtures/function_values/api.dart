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
  int Function(int) get callback => increment;
  T identity<T>(T value) => value;
  static T staticIdentity<T>(T value) => value;
  int add(int other) => base + other;
  int optionalAdd([int other = 5]) => base + other;
  int namedAdd({required int other, int extra = 2}) => base + other + extra;
  static int twice(int value) => value * 2;
}

class Box<T> {
  Box(this.value);
  final T value;
  T read() => value;
  U select<U extends T>(U selected) => selected;
}

int optional([int value = 5]) => value;
int named({required int value}) => value;
T identity<T>(T value) => value;

int? nullableOptional([int? value = 9]) => value;
String combine(int first,
        {required int last, int middle = 7, int? nullable = 9}) =>
    '$first:$middle:$last:$nullable';
int invokeOptional(int Function([int]) callback) => callback() + callback(3);
int invokeNamed(int Function({required int value}) callback) =>
    callback(value: 4);
String invokeCombined(
        String Function(int, {required int last, int middle, int? nullable})
            callback) =>
    callback(1, last: 3);
String _trace = '';
void resetTrace() {
  _trace = '';
}

String trace() => _trace;
int tick(String label, int value) {
  _trace += label;
  return value;
}

String Function(int, {required int last, int middle, int? nullable})
    makeNamed() {
  _trace += 'C';
  return combine;
}

T bounded<T extends num>(T value) => value;
T? genericOptional<T>([T? value]) => value;
T genericNamed<T>({required T value}) => value;
