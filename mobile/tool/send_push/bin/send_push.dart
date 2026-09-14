import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Sends the contract's FCM message (api-contract.md §3.3) to one device
/// token through the FCM HTTP v1 API, authenticated with the Firebase
/// service-account key. With `--stub`, first creates a real Push Request on
/// the stub server so tapping the notification lands on a live request.
Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('token', abbr: 't', help: 'FCM registration token (required)')
    ..addOption(
      'key',
      help: 'Service-account JSON',
      defaultsTo:
          Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'] ??
          '${Platform.environment['HOME']}/.config/auth-levels/firebase-adminsdk.json',
    )
    ..addOption(
      'stub',
      help: 'Stub server base URL; creates the request there (POST /__push)',
    )
    ..addOption('request-id', help: 'requestId to send (default: random)')
    ..addOption('browser', defaultsTo: 'Chrome')
    ..addOption('os', defaultsTo: 'Mac OS X')
    ..addOption('device', defaultsTo: 'Other')
    ..addOption('address', defaultsTo: '127.0.0.1')
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(argv);
  if (args['help'] as bool || args['token'] == null) {
    stdout.writeln(
      'dart run bin/send_push.dart --token <fcm token> [--stub http://localhost:8002]\n'
      '${parser.usage}',
    );
    exitCode = args['token'] == null ? 64 : 0;
    return;
  }

  final keyFile = File(args['key'] as String);
  if (!keyFile.existsSync()) {
    stderr.writeln('service-account key not found: ${keyFile.path}');
    exitCode = 66;
    return;
  }
  final key = jsonDecode(keyFile.readAsStringSync()) as Map<String, Object?>;
  final projectId = key['project_id'] as String;

  var requestId = args['request-id'] as String? ?? const Uuid().v4();
  final now = DateTime.now().toUtc();
  var expiresAt = now.add(const Duration(minutes: 2));
  if (args['stub'] case final stub?) {
    final created = await http.post(Uri.parse('$stub/__push'));
    if (created.statusCode != 200) {
      stderr.writeln('stub $stub/__push: HTTP ${created.statusCode}');
      exitCode = 69;
      return;
    }
    final data =
        (jsonDecode(created.body) as Map<String, Object?>)['data']
            as Map<String, Object?>;
    requestId = data['requestId'] as String;
    expiresAt = DateTime.parse(data['expiresAt'] as String);
    stdout.writeln('stub request $requestId, code ${data['otp']}');
  }

  final message = {
    'message': {
      'token': args['token'],
      'notification': {
        'title': 'Login request',
        'body': '${args['browser']} on ${args['os']} · ${args['address']}',
      },
      'data': {
        'type': 'push_request',
        'requestId': requestId,
        'createdAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'userAgentFamily': args['browser'],
        'osFamily': args['os'],
        'deviceFamily': args['device'],
        'remoteAddress': args['address'],
      },
      'android': {
        'priority': 'HIGH',
        'ttl': '120s',
        'notification': {'tag': requestId, 'channel_id': 'push_requests'},
      },
    },
  };

  final client = await clientViaServiceAccount(
    ServiceAccountCredentials.fromJson(key),
    ['https://www.googleapis.com/auth/firebase.messaging'],
  );
  try {
    final response = await client.post(
      Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
      ),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(message),
    );
    if (response.statusCode >= 300) {
      stderr.writeln('FCM ${response.statusCode}: ${response.body}');
      exitCode = 1;
    } else {
      stdout.writeln('sent: ${response.body}');
    }
  } finally {
    client.close();
  }
}
