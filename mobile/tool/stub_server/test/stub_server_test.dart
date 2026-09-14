import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:stub_server/stub_server.dart';
import 'package:test/test.dart';

Request req(
  String method,
  String path, {
  Map<String, Object?>? body,
  String? token,
}) {
  return Request(
    method,
    Uri.parse('http://stub$path'),
    headers: {
      if (body != null) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    },
    body: body == null ? null : jsonEncode(body),
  );
}

Future<Map<String, dynamic>> bodyOf(Response r) async =>
    jsonDecode(await r.readAsString()) as Map<String, dynamic>;

Future<String> pair(StubServer s) async {
  final r = await s.handler(req('POST', '/devices/pair', body: {
    'enrollmentToken': 'ok-1',
    'fcmToken': null,
    'name': 'Test phone',
    'platform': 'android',
    'appVersion': '0.1.0',
  }));
  return (await bodyOf(r))['data']['deviceToken'] as String;
}

void main() {
  late StubServer s;
  setUp(() => s = StubServer(seed: 1));

  group('envelope', () {
    test('success wraps data with code 0', () async {
      final r = await s.handler(req('POST', '/devices/pair', body: {
        'enrollmentToken': 'ok-1',
        'name': 'p',
        'platform': 'ios',
        'appVersion': '0',
      }));
      expect(r.statusCode, 200);
      final b = await bodyOf(r);
      expect(b['code'], 0);
      expect(b['message'], 'Success');
      expect(b['data']['deviceToken'], isNotEmpty);
      expect(b['data']['deviceId'], isNotEmpty);
      expect(b['data']['user']['email'], contains('@'));
      expect(b['url'], contains('/devices/pair'));
    });

    test('failure carries BaseError with machine code', () async {
      final r = await s.handler(req('POST', '/devices/pair', body: {
        'enrollmentToken': 'expired-1',
        'name': 'p',
        'platform': 'ios',
        'appVersion': '0',
      }));
      expect(r.statusCode, 410);
      final b = await bodyOf(r);
      expect(b['code'], -1);
      expect(b['data']['error'], 'enrollment_expired');
      expect(b['data']['errorCode'], 410);
    });

    test('every response has a Date header, offset by skew', () async {
      final skewed = StubServer(seed: 1, skew: const Duration(seconds: 90));
      final r = await skewed.handler(req('GET', '/security-events'));
      final sent = HttpDate.parse(r.headers['date']!);
      final diff = sent.difference(DateTime.now().toUtc()).inSeconds;
      expect(diff, inInclusiveRange(85, 95));
    });
  });

  group('device auth', () {
    test('device route without token is 401 device_revoked', () async {
      final r = await s.handler(req('GET', '/push/get'));
      expect(r.statusCode, 401);
      expect((await bodyOf(r))['data']['error'], 'device_revoked');
    });

    test('unknown token is 401', () async {
      final r = await s.handler(req('GET', '/push/get', token: 'nope'));
      expect(r.statusCode, 401);
    });

    test('revoke admin route invalidates the token', () async {
      final t = await pair(s);
      expect((await s.handler(req('GET', '/push/get', token: t))).statusCode, 200);
      await s.handler(req('POST', '/__revoke'));
      final r = await s.handler(req('GET', '/push/get', token: t));
      expect(r.statusCode, 401);
    });

    test('fcm-token update and self-unpair return 204', () async {
      final t = await pair(s);
      final u = await s.handler(
          req('PUT', '/devices/me/fcm-token', body: {'fcmToken': 'x'}, token: t));
      expect(u.statusCode, 204);
      final d = await s.handler(req('DELETE', '/devices/me', token: t));
      expect(d.statusCode, 204);
      expect((await s.handler(req('GET', '/push/get', token: t))).statusCode, 401);
    });
  });

  group('push requests', () {
    test('seeded pending request is listed with contract shape', () async {
      final t = await pair(s);
      final r = await s.handler(req('GET', '/push/get', token: t));
      final items = (await bodyOf(r))['data'] as List;
      expect(items, hasLength(1));
      final it = items.first as Map;
      expect(it.keys, containsAll(['id', 'requestId', 'createdAt', 'expiresAt', 'client']));
      expect(it.containsKey('email'), isFalse);
      expect((it['client'] as Map).keys,
          containsAll(['userAgentFamily', 'osFamily', 'deviceFamily', 'remoteAddress']));
    });

    test('admin __push creates a request and returns its otp', () async {
      final t = await pair(s);
      final c = await bodyOf(await s.handler(req('POST', '/__push')));
      expect(c['data']['otp'], matches(RegExp(r'^\d{6}$')));
      final items = (await bodyOf(await s.handler(req('GET', '/push/get', token: t))))['data'] as List;
      expect(items, hasLength(2));
    });

    test('verify with the right otp succeeds and removes the request', () async {
      final t = await pair(s);
      final c = (await bodyOf(await s.handler(req('POST', '/__push'))))['data'];
      final r = await s.handler(req('POST', '/push/verify',
          body: {'requestId': c['requestId'], 'otp': c['otp']}, token: t));
      expect(r.statusCode, 200);
      final again = await s.handler(req('POST', '/push/verify',
          body: {'requestId': c['requestId'], 'otp': c['otp']}, token: t));
      expect(again.statusCode, 404);
      expect((await bodyOf(again))['data']['error'], 'request_gone');
    });

    test('three wrong otps then gone', () async {
      final t = await pair(s);
      final c = (await bodyOf(await s.handler(req('POST', '/__push'))))['data'];
      final left = <int>[];
      for (var i = 0; i < 3; i++) {
        final r = await s.handler(req('POST', '/push/verify',
            body: {'requestId': c['requestId'], 'otp': '000000'}, token: t));
        expect(r.statusCode, 403);
        final b = await bodyOf(r);
        expect(b['data']['error'], 'otp_mismatch');
        left.add(b['data']['attemptsLeft'] as int);
      }
      expect(left, [2, 1, 0]);
      final r = await s.handler(req('POST', '/push/verify',
          body: {'requestId': c['requestId'], 'otp': c['otp']}, token: t));
      expect(r.statusCode, 404);
    });

    test('deny removes the request', () async {
      final t = await pair(s);
      final c = (await bodyOf(await s.handler(req('POST', '/__push'))))['data'];
      final r = await s.handler(
          req('POST', '/push/deny', body: {'requestId': c['requestId']}, token: t));
      expect(r.statusCode, 200);
      final again = await s.handler(
          req('POST', '/push/deny', body: {'requestId': c['requestId']}, token: t));
      expect(again.statusCode, 404);
    });

    test('expired requests disappear', () async {
      final t = await pair(s);
      final c = (await bodyOf(await s.handler(req('POST', '/__push'))))['data'];
      s.advanceClock(const Duration(minutes: 3));
      final items = (await bodyOf(await s.handler(req('GET', '/push/get', token: t))))['data'] as List;
      expect(items.where((e) => e['requestId'] == c['requestId']), isEmpty);
    });
  });

  group('security events', () {
    test('first page is newest-first and cursor walks the whole set', () async {
      final t = await pair(s);
      var r = await bodyOf(await s.handler(req('GET', '/security-events?limit=50', token: t)));
      final page1 = r['data']['items'] as List;
      expect(page1, hasLength(50));
      final t0 = DateTime.parse(page1.first['occurredAt']);
      final t1 = DateTime.parse(page1.last['occurredAt']);
      expect(t0.isAfter(t1), isTrue);
      var cursor = r['data']['nextCursor'] as String?;
      final ids = <String>{...page1.map((e) => e['id'] as String)};
      while (cursor != null) {
        r = await bodyOf(await s.handler(
            req('GET', '/security-events?limit=50&before=$cursor', token: t)));
        final items = r['data']['items'] as List;
        for (final e in items) {
          expect(ids.add(e['id'] as String), isTrue, reason: 'duplicate across pages');
        }
        cursor = r['data']['nextCursor'] as String?;
      }
      expect(ids.length, greaterThanOrEqualTo(120));
    });

    test('seed covers every type and method', () async {
      final t = await pair(s);
      final r = await bodyOf(await s.handler(req('GET', '/security-events?limit=200', token: t)));
      final items = r['data']['items'] as List;
      final types = items.map((e) => e['type']).toSet();
      final methods = items.map((e) => e['method']).whereType<String>().toSet();
      expect(types, containsAll(StubServer.eventTypes));
      expect(methods, containsAll(StubServer.loginMethods));
      final withActor = items.firstWhere((e) => e['actor'] != null);
      expect((withActor['actor'] as Map).keys, containsAll(['userAgentFamily', 'remoteAddress']));
      expect(withActor['details'], isA<Map>());
    });

    test('malformed cursor and malformed JSON body stay inside the envelope', () async {
      final t = await pair(s);
      final c = await s.handler(req('GET', '/security-events?before=!!!', token: t));
      expect(c.statusCode, 400);
      expect((await bodyOf(c))['data']['error'], 'bad_cursor');
      final bad = Request('POST', Uri.parse('http://stub/push/verify'),
          headers: {'content-type': 'application/json', 'authorization': 'Bearer $t'}, body: '{not json');
      final b = await s.handler(bad);
      expect(b.statusCode, 400);
      expect((await bodyOf(b))['code'], -1);
    });

    test('ids are UUIDs and device tokens are 32 bytes base64url', () async {
      final r = await bodyOf(await s.handler(req('POST', '/devices/pair', body: {
        'enrollmentToken': 'ok-1', 'name': 'p', 'platform': 'ios', 'appVersion': '0'})));
      expect(r['data']['deviceId'], matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(r['data']['deviceToken'], matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    });

    test('accepts an access token as well as a device token', () async {
      final r = await s.handler(req('GET', '/security-events', token: 'access-anything'));
      expect(r.statusCode, 200);
    });
  });
}
