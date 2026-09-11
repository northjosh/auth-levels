import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:stub_server/stub_server.dart';

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8002', help: 'Port to listen on')
    ..addOption('skew', defaultsTo: '0', help: 'Seconds added to the Date header')
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(argv);
  if (args['help'] as bool) {
    stdout.writeln('dart run bin/server.dart [--port 8002] [--skew 0]\n${parser.usage}');
    return;
  }

  final port = int.parse(args['port'] as String);
  final skew = Duration(seconds: int.parse(args['skew'] as String));
  final stub = StubServer(skew: skew);

  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(stub.handler);
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);

  String link(String host) => Uri(
        scheme: 'authlevels',
        host: 'pair',
        queryParameters: {'token': 'ok-1', 'api': 'http://$host:$port', 'email': StubServer.user['email']},
      ).toString();

  stdout.writeln('''
auth-levels stub backend on port ${server.port}
  Android emulator pairing link:  ${link('10.0.2.2')}
  iOS simulator pairing link:     ${link('localhost')}
  Seeded Push Request code:       ${stub.seededOtp}
  New request:   curl -X POST localhost:$port/__push
  Revoke device: curl -X POST localhost:$port/__revoke
  Date skew:     ${skew.inSeconds}s
''');
}
