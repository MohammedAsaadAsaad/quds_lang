import 'package:quds/quds.dart';

void main() {
  const source = '''
square(n: int) -> int = n * n

main():
  name = "Quds"
  print "Hello {name}: {square(6)}"
''';

  final result = compile(source, file: 'example/hello.quds');
  print(result.dart);
}
