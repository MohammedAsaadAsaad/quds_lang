import 'dart:convert';
import 'dart:io';

int sequence = 1;
void send(Map<String, dynamic> message) {
  final body = jsonEncode({'seq': sequence++, ...message});
  stdout.write('Content-Length: ${utf8.encode(body).length}\r\n\r\n$body');
}

Future<void> main(List<String> args) async {
  File('adapter-args').writeAsStringSync(jsonEncode(args));
  final buffer = <int>[];
  await for (final chunk in stdin) {
    buffer.addAll(chunk);
    while (true) {
      var boundary = -1;
      for (var i = 0; i + 3 < buffer.length; i++) {
        if (buffer[i] == 13 &&
            buffer[i + 1] == 10 &&
            buffer[i + 2] == 13 &&
            buffer[i + 3] == 10) {
          boundary = i;
          break;
        }
      }
      if (boundary < 0) break;
      final header = ascii.decode(buffer.sublist(0, boundary));
      final length =
          int.parse(RegExp(r'Content-Length: (\d+)').firstMatch(header)![1]!);
      final start = boundary + 4;
      if (buffer.length < start + length) break;
      final request =
          jsonDecode(utf8.decode(buffer.sublist(start, start + length)))
              as Map<String, dynamic>;
      buffer.removeRange(0, start + length);
      if (request['type'] != 'request')
        throw StateError('A proxy response reached Flutter');
      final command = request['command'];
      final record = <String, dynamic>{...request};
      if (File('lib/quds_gen/main.dart').existsSync())
        record['main'] = File('lib/quds_gen/main.dart').readAsStringSync();
      if (File('lib/quds_gen/helper.dart').existsSync())
        record['helper'] = File('lib/quds_gen/helper.dart').readAsStringSync();
      File('dap-calls').writeAsStringSync('${jsonEncode(record)}\n',
          mode: FileMode.append, flush: true);
      send({
        'type': 'response',
        'request_seq': request['seq'],
        'command': command,
        'success': true
      });
      if (command == 'launch')
        send({
          'type': 'event',
          'event': 'flutter.appStarted',
          'body': <String, dynamic>{}
        });
      if (command == 'disconnect') {
        await stdout.flush();
        return;
      }
    }
  }
}
