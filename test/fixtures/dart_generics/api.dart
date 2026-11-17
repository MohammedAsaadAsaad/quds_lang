export 'base.dart';
import 'base.dart';

class NativeChild<U> extends NativeParent<List<U>> {
  NativeChild(List<U> value) : super(value);
}

T nativeIdentity<T>(T value) => value;
T nativeBounded<T extends num>(T value) => value;
T nativeNamed<T>({required T value, T? fallback}) => value;
String nativePair<T>(T first, T second, {String suffix = '!'}) =>
    '$first,$second$suffix';
const _missing = Object();
bool nativeOmitted<T>({Object? value = _missing}) => identical(value, _missing);
Future<String> nativeFuturePair<T>(T first, T second) async => '$first,$second';
(int, int) nativeRecord() => (1, 2);
int nativeGenericCallback(T Function<T>(T) action) => 0;
int nativeOptionalCallback(int Function([int]) action) => 0;

int nativeFieldValue(NativeField<int> value) => value.value;
