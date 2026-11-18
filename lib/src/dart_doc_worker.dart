import 'dart:convert';
import 'dart:io';
import 'dart_doc_preview.dart';

Future<void> main() async {
  stdout.writeln(jsonEncode({'ready': true}));
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    try {
      final request = jsonDecode(line) as Map;
      final markdown = request['markdown'] as String;
      stdout.writeln(jsonEncode(
          {'id': request['id'], 'markdown': presentDartExamples(markdown)}));
    } catch (_) {
      /* Malformed optional presentation input does not affect LSP. */
    }
  }
}
