import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kudi9ja/data/api/api_client.dart';
import 'package:kudi9ja/data/api/api_exception.dart';
import 'package:kudi9ja/data/api/token_store.dart';

/// The transport layer, tested where it is most likely to be wrong.
///
/// Everything here is about the two things that are invisible until they fail
/// in front of a customer: what happens when a token expires mid-session, and
/// what happens when several screens notice at the same moment. The server
/// rotates the refresh token on every use and treats a second use of a spent
/// one as theft — it destroys the session — so "refresh twice at once" is not a
/// performance problem, it is a customer being signed out for no reason.
void main() {
  http.Response json(Object body, {int status = 200}) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  http.Response apiError(String code, String message, {int status = 400}) =>
      json({'code': code, 'message': message, 'details': {}, 'path': '/x'},
          status: status);

  Map<String, Object> session({
    String access = 'access-1',
    String refresh = 'refresh-1',
    int expiresIn = 900,
  }) =>
      {
        'accessToken': access,
        'refreshToken': refresh,
        'expiresInSeconds': expiresIn,
        'sessionId': '11111111-1111-1111-1111-111111111111',
      };

  Future<TokenStore> signedIn({int expiresIn = 900}) async {
    final tokens = InMemoryTokenStore();
    await tokens.save(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresInSeconds: expiresIn,
    );
    return tokens;
  }

  group('Requests', () {
    test('sends the bearer token when there is a session', () async {
      String? seen;
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          seen = request.headers['Authorization'];
          return json({'balance': 0});
        }),
      );

      await client.get('/wallet');
      expect(seen, 'Bearer access-1');
    });

    test('omits the token on an endpoint that must not carry one', () async {
      String? seen;
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          seen = request.headers['Authorization'];
          return json(session());
        }),
      );

      await client.post('/auth/signin', body: {}, authenticated: false);
      expect(seen, isNull,
          reason: 'signing in with a stale token attached is how a '
              'half-expired session produces a confusing 401');
    });

    test('passes the idempotency key through', () async {
      String? seen;
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          seen = request.headers['Idempotency-Key'];
          return json({'ok': true});
        }),
      );

      await client.post('/withdrawals', body: {}, idempotencyKey: 'key-123');
      expect(seen, 'key-123');
    });

    test('drops null query parameters rather than sending "null"', () async {
      Uri? seen;
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          seen = request.url;
          return json([]);
        }),
      );

      await client.get('/transactions', query: {'page': 0, 'filter': null});
      expect(seen!.queryParameters, {'page': '0'});
    });
  });

  group('Errors', () {
    test('decodes the error envelope into a typed code', () async {
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((_) async => apiError(
            'INSUFFICIENT_FUNDS', 'You do not have enough in your wallet.')),
      );

      await expectLater(
        client.post('/withdrawals', body: {}),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.insufficientFunds)
            .having((e) => e.message, 'message',
                'You do not have enough in your wallet.')),
      );
    });

    /// A server that grows a new error code must not crash an app that has not
    /// been updated. The message still reaches the customer.
    test('an unrecognised code degrades to unknown, keeping the message',
        () async {
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient(
            (_) async => apiError('SOMETHING_NEW', 'A new rule stopped that.')),
      );

      await expectLater(
        client.get('/wallet'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.unknown)
            .having((e) => e.message, 'message', 'A new rule stopped that.')),
      );
    });

    /// Render's proxy returns HTML while the service wakes. That is not the
    /// application refusing anything, and must not be shown as though it were.
    test('a non-JSON body is reported as unreachable, not as a server bug',
        () async {
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((_) async => http.Response('<html>502</html>', 502)),
      );

      await expectLater(
        client.get('/wallet'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.network)),
      );
    });

    test('a dropped connection becomes an offline error', () async {
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((_) async => throw http.ClientException('no route')),
      );

      await expectLater(
        client.get('/wallet'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.network)),
      );
    });

    test('validation details survive as field errors', () async {
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((_) async => json({
              'code': 'VALIDATION_FAILED',
              'message': 'Check the form.',
              'details': {
                'fields': {'email': 'That is not an email address.'}
              },
            }, status: 422)),
      );

      try {
        await client.post('/auth/signup/personal', body: {});
        fail('should have thrown');
      } on ApiException catch (e) {
        expect(e.fieldErrors['email'], 'That is not an email address.');
      }
    });
  });

  group('A server that is still waking up', () {
    /// The free hosting tier sleeps, and a sleeping instance does not refuse a
    /// request politely — the proxy in front of it answers 502 with an HTML
    /// page while the container starts. Reporting that as "we could not reach
    /// Kudi9ja" is what a customer saw at the first screen of sign-up.
    test('a proxy 502 is retried once and then succeeds', () async {
      var calls = 0;
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((_) async {
          calls++;
          if (calls == 1) {
            return http.Response('<html>502 Bad Gateway</html>', 502,
                headers: {'content-type': 'text/html'});
          }
          return json({'ok': true});
        }),
      );

      expect(await client.get('/banks'), {'ok': true});
      expect(calls, 2);
    });

    test('a timeout is retried once', () async {
      var calls = 0;
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((_) async {
          calls++;
          if (calls == 1) throw http.ClientException('connection closed');
          return json({'ok': true});
        }),
      );

      expect(await client.get('/banks'), {'ok': true});
      expect(calls, 2);
    });

    test('it gives up after one retry rather than looping', () async {
      var calls = 0;
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((_) async {
          calls++;
          throw http.ClientException('still down');
        }),
      );

      await expectLater(
        client.get('/banks'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.network)),
      );
      expect(calls, 2);
    });

    /// The application itself returns 503 for maintenance mode, in the usual
    /// envelope. That is a real answer and must reach the customer, not be
    /// retried behind their back and then reported as a connection problem.
    test('a real maintenance 503 is not retried', () async {
      var calls = 0;
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((_) async {
          calls++;
          return json({
            'code': 'MAINTENANCE',
            'message': 'Kudi9ja is down for maintenance until 6am.',
            'details': {},
          }, status: 503);
        }),
      );

      await expectLater(
        client.get('/banks'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.maintenance)
            .having((e) => e.message, 'message', contains('maintenance'))),
      );
      expect(calls, 1, reason: 'an answer is not a failure to answer');
    });

    /// Asking twice must not move money twice. Every money call carries a key,
    /// and the retry reuses the same one so the server recognises the repeat.
    test('a retried money call keeps the same idempotency key', () async {
      final keys = <String?>[];
      var calls = 0;
      final client = ApiClient(
        tokens: await signedIn(),
        baseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          keys.add(request.headers['Idempotency-Key']);
          calls++;
          if (calls == 1) {
            return http.Response('<html>502</html>', 502,
                headers: {'content-type': 'text/html'});
          }
          return json({'id': 'w-1'});
        }),
      );

      await client.post('/withdrawals', body: {}, idempotencyKey: 'key-abc');

      expect(keys, ['key-abc', 'key-abc'],
          reason: 'a different key on the retry would be a second withdrawal');
    });
  });

  group('Session refresh', () {
    test('refreshes and retries when the access token has expired', () async {
      final tokens = await signedIn();
      var calls = <String>[];

      final client = ApiClient(
        tokens: tokens,
        baseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          calls.add(request.url.path);
          if (request.url.path == '/auth/refresh') {
            return json(session(access: 'access-2', refresh: 'refresh-2'));
          }
          // Refuse the first attempt, accept the one carrying the new token.
          if (request.headers['Authorization'] == 'Bearer access-1') {
            return apiError('TOKEN_EXPIRED', 'Please sign in again.', status: 401);
          }
          return json({'balance': 5000});
        }),
      );

      final wallet = await client.get('/wallet');

      expect(wallet, {'balance': 5000});
      expect(calls, ['/wallet', '/auth/refresh', '/wallet']);
      expect(tokens.accessToken, 'access-2');
      expect(tokens.refreshToken, 'refresh-2',
          reason: 'the rotated token must replace the spent one');
    });

    /// The property this whole class exists for. Six screens loading at once on
    /// a cold start must produce **one** refresh, because the second use of a
    /// rotated token destroys the session server-side.
    test('concurrent requests share a single refresh', () async {
      final tokens = await signedIn(expiresIn: -1); // already expired
      var refreshes = 0;

      final client = ApiClient(
        tokens: tokens,
        baseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/refresh') {
            refreshes++;
            // A real refresh takes a round trip; without the delay the futures
            // would resolve in order and the test would pass by accident.
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return json(session(access: 'access-2', refresh: 'refresh-2'));
          }
          return json({'path': request.url.path});
        }),
      );

      await Future.wait([
        client.get('/wallet'),
        client.get('/transactions'),
        client.get('/loans'),
        client.get('/savings/plans'),
        client.get('/notifications'),
        client.get('/me'),
      ]);

      expect(refreshes, 1);
    });

    test('a refused refresh clears the session and reports it once', () async {
      final tokens = await signedIn();
      var lost = 0;

      final client = ApiClient(
        tokens: tokens,
        baseUrl: 'https://api.test',
        onSessionLost: () => lost++,
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/refresh') {
            return apiError('TOKEN_INVALID', 'Session ended.', status: 401);
          }
          return apiError('TOKEN_EXPIRED', 'Please sign in again.', status: 401);
        }),
      );

      await expectLater(client.get('/wallet'), throwsA(isA<ApiException>()));

      expect(tokens.hasSession, isFalse);
      expect(lost, 1);
    });

    /// A 401 that is not about the token — an admin endpoint reached by a
    /// customer — must not spend the refresh token trying to fix it.
    test('does not refresh on a 401 that is not a token problem', () async {
      final tokens = await signedIn();
      var refreshes = 0;

      final client = ApiClient(
        tokens: tokens,
        baseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/refresh') refreshes++;
          return apiError('NOT_AN_ADMIN', 'You do not have panel access.',
              status: 401);
        }),
      );

      await expectLater(
        client.get('/admin/overview'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.notAnAdmin)),
      );
      expect(refreshes, 0);
      expect(tokens.hasSession, isTrue);
    });

    /// Being offline is not the same as being signed out. Losing the session
    /// because a train went into a tunnel would make the customer sign in again
    /// for no reason.
    test('an unreachable server during refresh keeps the session', () async {
      final tokens = await signedIn(expiresIn: -1);
      var lost = 0;

      final client = ApiClient(
        tokens: tokens,
        baseUrl: 'https://api.test',
        onSessionLost: () => lost++,
        httpClient: MockClient((_) async => throw http.ClientException('offline')),
      );

      await expectLater(
        client.get('/wallet'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.network)),
      );
      expect(tokens.hasSession, isTrue);
      expect(lost, 0);
    });

    test('retries only once, then gives up', () async {
      final tokens = await signedIn();
      var walletCalls = 0;

      final client = ApiClient(
        tokens: tokens,
        baseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/refresh') {
            return json(session(access: 'access-2', refresh: 'refresh-2'));
          }
          walletCalls++;
          return apiError('TOKEN_EXPIRED', 'Please sign in again.', status: 401);
        }),
      );

      await expectLater(client.get('/wallet'), throwsA(isA<ApiException>()));
      expect(walletCalls, 2, reason: 'one attempt, one retry, no loop');
    });
  });

  group('TokenStore', () {
    test('reports an expired access token before it is actually spent', () async {
      final tokens = InMemoryTokenStore();
      await tokens.save(
        accessToken: 'a',
        refreshToken: 'r',
        expiresInSeconds: 10, // inside the safety margin
      );

      expect(tokens.isAccessExpired, isTrue,
          reason: 'a token with seconds left will expire in flight');
      expect(tokens.hasSession, isTrue);
    });

    test('a fresh token is not expired', () async {
      final tokens = InMemoryTokenStore();
      await tokens.save(
          accessToken: 'a', refreshToken: 'r', expiresInSeconds: 900);
      expect(tokens.isAccessExpired, isFalse);
    });

    test('clearing forgets everything', () async {
      final tokens = InMemoryTokenStore();
      await tokens.save(
          accessToken: 'a', refreshToken: 'r', expiresInSeconds: 900);
      await tokens.clear();

      expect(tokens.hasSession, isFalse);
      expect(tokens.accessToken, isNull);
      expect(tokens.refreshToken, isNull);
    });
  });
}
