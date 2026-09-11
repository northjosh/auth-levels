/// In-memory stand-in for the auth-levels backend.
///
/// Implements the routes the companion app calls, per
/// `.scratch/mobile-companion-app/api-contract.md`: device pairing and the
/// Device Token scheme, Push Requests (three-attempt Number Matching, deny,
/// expiry), Security Events with cursor paging, and the response envelope.
/// Two admin routes (`/__push`, `/__revoke`) drive scenarios from tests or curl.
library;

import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class StubServer {
  StubServer({int seed = 1, this.skew = Duration.zero})
      : _random = Random(seed) {
    _seedEvents();
    _seedPushRequest();
  }

  /// Added to the `Date` header so the app's clock-skew check can be exercised.
  final Duration skew;

  static const maxAttempts = 3;
  static const requestTtl = Duration(minutes: 2);

  final Random _random;
  Duration _clockOffset = Duration.zero;

  final _devices = <String, _Device>{};
  final _requests = <String, _PushRequest>{};
  final _events = <Map<String, Object?>>[];

  static const eventTypes = [
    'LOGIN_SUCCESS',
    'LOGIN_FAILURE',
    'SIGNUP',
    'EMAIL_VERIFIED',
    'TOTP_ENABLED',
    'TOTP_ACTIVATED',
    'TOTP_DISABLED',
    'RECOVERY_CODES_GENERATED',
    'PASSKEY_ADDED',
    'PASSKEY_REMOVED',
    'PASSWORD_RESET_REQUESTED',
    'PASSWORD_RESET_COMPLETED',
    'PUSH_REQUEST_CREATED',
    'PUSH_REQUEST_DENIED',
    'TRUSTED_DEVICE_PAIRED',
    'TRUSTED_DEVICE_REMOVED',
  ];

  static const loginMethods = [
    'PASSWORD',
    'TOTP',
    'RECOVERY_CODE',
    'PASSKEY',
    'MAGIC_LINK',
    'PUSH',
  ];

  /// The one user every pairing binds to.
  static const user = {'email': 'joshua@terydin.co', 'firstName': 'Joshua'};

  static const _clients = [
    {'userAgentFamily': 'Chrome', 'osFamily': 'Mac OS X', 'deviceFamily': 'Other', 'remoteAddress': '127.0.0.1'},
    {'userAgentFamily': 'Safari', 'osFamily': 'iOS', 'deviceFamily': 'iPhone', 'remoteAddress': '10.0.0.4'},
    {'userAgentFamily': 'Firefox', 'osFamily': 'Windows', 'deviceFamily': 'Other', 'remoteAddress': '82.1.9.20'},
  ];

  /// Simulated "now"; tests move it forward with [advanceClock].
  DateTime get now => DateTime.now().toUtc().add(_clockOffset);

  void advanceClock(Duration by) => _clockOffset += by;

  /// The OTP of the request seeded at startup, so a demo can approve it.
  String get seededOtp => _requests.values.first.otp;

  late final Handler handler = const Pipeline()
      .addMiddleware(_dateHeader)
      .addMiddleware(_envelope)
      .addHandler(_router.call);

  // ---------------------------------------------------------------- routing

  late final Router _router = Router(notFoundHandler: (_) => _fail(404, 'not_found', 'No such route'))
    ..post('/devices/pair', _pair)
    ..put('/devices/me/fcm-token', _deviceOnly(_updateFcmToken))
    ..delete('/devices/me', _deviceOnly(_unpair))
    ..get('/push/get', _either(_listRequests))
    ..post('/push/verify', _either(_verify))
    ..post('/push/deny', _deviceOnly(_deny))
    ..get('/security-events', _either(_listEvents))
    ..post('/__push', _adminPush)
    ..post('/__revoke', _adminRevoke);

  Future<Response> _pair(Request r) async {
    final body = await _body(r);
    final token = body['enrollmentToken'] as String? ?? '';
    if (!token.startsWith('ok-')) {
      return _fail(410, 'enrollment_expired', 'Enrollment token expired or unknown');
    }
    final device = _Device(
      id: _uuid(),
      token: _deviceToken(),
      name: body['name'] as String? ?? 'Unnamed',
      platform: body['platform'] as String? ?? 'android',
      fcmToken: body['fcmToken'] as String?,
    );
    _devices[device.token] = device;
    _record('TRUSTED_DEVICE_PAIRED', details: {'deviceName': device.name});
    return _ok({'deviceId': device.id, 'deviceToken': device.token, 'user': user});
  }

  Future<Response> _updateFcmToken(Request r, _Device d) async {
    d.fcmToken = (await _body(r))['fcmToken'] as String?;
    return Response(204);
  }

  Future<Response> _unpair(Request r, _Device d) async {
    _devices.remove(d.token);
    _record('TRUSTED_DEVICE_REMOVED', details: {'deviceName': d.name});
    return Response(204);
  }

  Future<Response> _listRequests(Request r, _Device? d) async {
    _sweep();
    return _ok(_requests.values.map((p) => p.toJson()).toList());
  }

  Future<Response> _verify(Request r, _Device? d) async {
    _sweep();
    final body = await _body(r);
    final p = _requests[body['requestId']];
    if (p == null) return _fail(404, 'request_gone', 'Login attempt does not exist');
    if (body['otp'] != p.otp) {
      p.attempts++;
      final left = maxAttempts - p.attempts;
      _record('LOGIN_FAILURE', method: 'PUSH', client: p.client, details: {'attemptsLeft': '$left'});
      if (left <= 0) _requests.remove(p.requestId);
      return _fail(403, 'otp_mismatch', 'Invalid code', extra: {'attemptsLeft': left});
    }
    _requests.remove(p.requestId);
    _record('LOGIN_SUCCESS', method: 'PUSH', client: p.client,
        details: {'deviceName': d?.name ?? 'web', 'requestId': p.requestId});
    return _ok({'message': 'Login Successful'});
  }

  Future<Response> _deny(Request r, _Device d) async {
    _sweep();
    final body = await _body(r);
    final p = _requests.remove(body['requestId']);
    if (p == null) return _fail(404, 'request_gone', 'Login attempt does not exist');
    _record('PUSH_REQUEST_DENIED', client: p.client,
        details: {'deviceName': d.name, 'requestId': p.requestId});
    return _ok({'message': 'Denied'});
  }

  Future<Response> _listEvents(Request r, _Device? d) async {
    final q = r.url.queryParameters;
    final limit = (int.tryParse(q['limit'] ?? '') ?? 50).clamp(1, 200);
    final before = q['before'];
    var start = 0;
    if (before != null && before.isNotEmpty) {
      final String key;
      try {
        key = utf8.decode(base64Url.decode(base64Url.normalize(before)));
      } on FormatException {
        return _fail(400, 'bad_cursor', 'Malformed cursor');
      }
      final idx = _events.indexWhere((e) => _cursorOf(e) == key);
      start = idx < 0 ? _events.length : idx + 1;
    }
    final page = _events.skip(start).take(limit).toList();
    final more = start + page.length < _events.length;
    return _ok({
      'items': page,
      'nextCursor': more ? base64Url.encode(utf8.encode(_cursorOf(page.last))) : null,
    });
  }

  Future<Response> _adminPush(Request r) async {
    final p = _newRequest();
    return _ok({'requestId': p.requestId, 'otp': p.otp, 'expiresAt': _iso(p.expiresAt)});
  }

  Future<Response> _adminRevoke(Request r) async {
    final names = _devices.values.map((d) => d.name).toList();
    _devices.clear();
    for (final n in names) {
      _record('TRUSTED_DEVICE_REMOVED', details: {'deviceName': n});
    }
    return _ok({'revoked': names.length});
  }

  // ------------------------------------------------------------------- auth

  String? _bearer(Request r) {
    final h = r.headers['authorization'];
    if (h == null || !h.startsWith('Bearer ')) return null;
    return h.substring(7);
  }

  /// Resolves the bearer to a paired device and bumps `lastSeenAt`.
  _Device? _deviceOf(Request r) {
    final d = _devices[_bearer(r)];
    d?.lastSeenAt = now;
    return d;
  }

  Response get _unauthorised => _fail(401, 'device_revoked', 'Unknown or revoked device token');

  /// Device Token or nothing.
  Handler _deviceOnly(Future<Response> Function(Request, _Device) f) {
    return (Request r) {
      final d = _deviceOf(r);
      return d == null ? _unauthorised : f(r, d);
    };
  }

  /// Device Token, or anything that looks like an access token (a JWT has two
  /// dots; the stub also accepts an `access-` prefix so curl is easy).
  Handler _either(Future<Response> Function(Request, _Device?) f) {
    return (Request r) {
      final d = _deviceOf(r);
      if (d != null) return f(r, d);
      final t = _bearer(r);
      final looksLikeAccess = t != null && (t.startsWith('access-') || '.'.allMatches(t).length == 2);
      return looksLikeAccess ? f(r, null) : _unauthorised;
    };
  }

  // --------------------------------------------------------------- envelope

  Middleware get _dateHeader => (inner) => (r) async {
        final res = await inner(r);
        return res.change(headers: {'date': HttpDate.format(now.add(skew))});
      };

  /// Wraps every JSON body the way `ResponseHandler` does on the backend.
  Middleware get _envelope => (inner) => (r) async {
        Response res;
        try {
          res = await inner(r);
        } on FormatException catch (e) {
          res = _fail(400, 'bad_request', 'Malformed request: ${e.message}');
        } catch (e) {
          res = _fail(500, 'internal', e.toString());
        }
        if (res.statusCode == 204) return res;
        final raw = await res.readAsString();
        final payload = raw.isEmpty ? null : jsonDecode(raw);
        final url = r.requestedUri.toString();
        final ok = res.statusCode < 400;
        final body = {
          'code': ok ? 0 : -1,
          'message': ok ? 'Success' : 'Failed',
          'data': ok ? payload : {...?(payload as Map?), 'url': url},
          'url': url,
        };
        return res.change(
          body: jsonEncode(body),
          headers: {'content-type': 'application/json'},
        );
      };

  Response _ok(Object? data) => Response.ok(jsonEncode(data));

  Response _fail(int status, String error, String message, {Map<String, Object?> extra = const {}}) {
    return Response(status,
        body: jsonEncode({'errorCode': status, 'errorMessage': message, 'error': error, ...extra}));
  }

  Future<Map<String, dynamic>> _body(Request r) async {
    final s = await r.readAsString();
    if (s.isEmpty) return {};
    return jsonDecode(s) as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------ state

  _PushRequest _newRequest() {
    final p = _PushRequest(
      id: _uuid(),
      requestId: _uuid(),
      otp: (_random.nextInt(900000) + 100000).toString(),
      createdAt: now,
      client: _clients[_random.nextInt(_clients.length)],
    );
    _requests[p.requestId] = p;
    _record('PUSH_REQUEST_CREATED', client: p.client, details: {'requestId': p.requestId});
    return p;
  }

  void _sweep() {
    _requests.removeWhere((_, p) => !p.expiresAt.isAfter(now));
  }

  void _seedPushRequest() => _newRequest();

  void _record(String type, {String? method, Map<String, String>? client, Map<String, String> details = const {}}) {
    _events.insert(0, {
      'id': _uuid(),
      'type': type,
      'method': method,
      'occurredAt': _iso(now),
      'actor': client,
      'details': details,
    });
  }

  /// ~120 events, one per hour going back, covering every type and method.
  void _seedEvents() {
    final base = now.subtract(const Duration(hours: 1));
    var i = 0;
    for (var round = 0; round < 8; round++) {
      for (final type in eventTypes) {
        final isLogin = type.startsWith('LOGIN_');
        final method = isLogin ? loginMethods[(i + round) % loginMethods.length] : null;
        final client = _clients[i % _clients.length];
        final details = <String, String>{
          if (method == 'PUSH' || type == 'PUSH_REQUEST_DENIED' || type.startsWith('TRUSTED_DEVICE'))
            'deviceName': 'Pixel 7',
          if (method == 'PUSH' || type.startsWith('PUSH_REQUEST')) 'requestId': 'seed-req-$i',
          if (type == 'PASSKEY_ADDED' || type == 'PASSKEY_REMOVED') 'credentialId': 'cred-$i',
          if (type == 'LOGIN_FAILURE' && method == 'PUSH') 'attemptsLeft': '${i % 3}',
        };
        _events.add({
          'id': _uuid(),
          'type': type,
          'method': method,
          'occurredAt': _iso(base.subtract(Duration(hours: i))),
          'actor': type.startsWith('TRUSTED_DEVICE') ? null : client,
          'details': details,
        });
        i++;
        if (i >= 120) return;
      }
    }
  }

  String _cursorOf(Map<String, Object?> e) => '${e['occurredAt']}|${e['id']}';

  /// RFC 4122 v4 layout, random bits from the seeded generator.
  String _uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// 32 random bytes, base64url without padding — the contract's Device Token shape.
  String _deviceToken() {
    final b = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(b).replaceAll('=', '');
  }

  static String _iso(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';

}

class _Device {
  _Device({required this.id, required this.token, required this.name, required this.platform, this.fcmToken});
  final String id;
  final String token;
  final String name;
  final String platform;
  String? fcmToken;
  DateTime? lastSeenAt;
}

class _PushRequest {
  _PushRequest({required this.id, required this.requestId, required this.otp, required this.createdAt, required this.client});
  final String id;
  final String requestId;
  final String otp;
  final DateTime createdAt;
  final Map<String, String> client;
  int attempts = 0;

  DateTime get expiresAt => createdAt.add(StubServer.requestTtl);

  Map<String, Object?> toJson() => {
        'id': id,
        'requestId': requestId,
        'createdAt': StubServer._iso(createdAt),
        'expiresAt': StubServer._iso(expiresAt),
        'client': client,
      };
}
