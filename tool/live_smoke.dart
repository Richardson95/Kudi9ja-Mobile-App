// Talks to the real Kudi9ja server through the app's own ApiClient.
//
// The unit tests prove the client behaves correctly against a fake server. This
// proves the fake and the real one agree — the base URL is right, the paths
// exist, the JSON decodes, and a refused request comes back in the envelope the
// app expects. Those are exactly the mistakes a mock cannot catch.
//
// Deliberately not part of the normal suite: a test that needs the internet
// fails on a train, and a suite that fails for reasons unrelated to the code
// stops being believed. Run it by hand, or from CI against a known deployment.
//
//   flutter test tool/live_smoke.dart
//
// It runs under the Flutter test harness rather than `dart run` because the
// token store talks to the platform keystore, which makes this a Flutter
// package and not a plain Dart one. It lives outside test/ so `flutter test`
// never picks it up with the rest of the suite.
//
// The free Render tier sleeps, so the first call can take the best part of a
// minute while the service wakes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/data/api/api_client.dart';
import 'package:kudi9ja/data/api/api_exception.dart';
import 'package:kudi9ja/data/api/token_store.dart';

void main() {
  // The service can take the best part of a minute to wake, and there are
  // several calls; the harness default would cut it off mid-run.
  test('live backend smoke test', _run, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _run() async {
  const baseUrl = String.fromEnvironment(
    'KUDI9JA_API',
    defaultValue: 'https://kudi9ja-mobile-backend.onrender.com/api/v1',
  );

  stdout.writeln('Kudi9ja live smoke test');
  stdout.writeln(baseUrl);
  stdout.writeln('');

  final client = ApiClient(tokens: InMemoryTokenStore(), baseUrl: baseUrl);
  var passed = 0;
  var failed = 0;

  Future<void> check(String what, Future<void> Function() body) async {
    try {
      await body();
      stdout.writeln('  PASS  $what');
      passed++;
    } on ApiException catch (e) {
      stdout.writeln('  FAIL  $what');
      stdout.writeln('        ${e.code.wire}: ${e.message}');
      failed++;
    } catch (e) {
      stdout.writeln('  FAIL  $what');
      stdout.writeln('        $e');
      failed++;
    }
  }

  // ── Reachability and decoding ──────────────────────────────────────────────

  await check('the bank directory loads', () async {
    final banks = await client.get('/banks');
    if (banks is! List || banks.isEmpty) {
      throw StateError('expected a non-empty list, got $banks');
    }
    final first = banks.first as Map<String, dynamic>;
    if (first['code'] == null || first['name'] == null) {
      throw StateError('a bank should have a code and a name: $first');
    }
    stdout.writeln('        ${banks.length} banks');
  });

  await check('the states list loads', () async {
    final states = await client.get('/states');
    if (states is! List || states.isEmpty) {
      throw StateError('expected a non-empty list');
    }
    stdout.writeln('        ${states.length} states');
  });

  // The rates and limits the app displays. If these ever disagree with
  // AppConfig, the app is quoting a price the server will not honour.
  await check('public settings load, and carry the rate card', () async {
    final settings = await client.get('/settings/public') as Map<String, dynamic>;
    if (settings.isEmpty) throw StateError('empty settings');
    stdout.writeln('        keys: ${settings.keys.take(6).join(', ')}...');
  });

  await check('the legal documents load', () async {
    for (final kind in ['terms', 'privacy', 'lending']) {
      final doc = await client.get('/legal/$kind') as Map<String, dynamic>;
      if (doc['body'] == null && doc['sections'] == null) {
        throw StateError('$kind has no content: ${doc.keys.join(', ')}');
      }
    }
  });

  // ── Refusals arrive in the shape the app expects ───────────────────────────

  await check('an unauthenticated call is refused, not crashed', () async {
    try {
      await client.get('/wallet');
      throw StateError('the server let an anonymous caller read a wallet');
    } on ApiException catch (e) {
      if (!e.isAuthFailure) {
        throw StateError('expected an auth failure, got ${e.code.wire}');
      }
      stdout.writeln('        ${e.code.wire}');
    }
  });

  await check('bad credentials come back as BAD_CREDENTIALS', () async {
    try {
      await client.post('/auth/signin',
          authenticated: false,
          body: {
            'email': 'nobody-${DateTime.now().millisecondsSinceEpoch}@example.com',
            'password': 'not-the-password',
            'device': 'live smoke test',
          });
      throw StateError('the server accepted a password it should not have');
    } on ApiException catch (e) {
      const acceptable = {
        ApiErrorCode.badCredentials,
        ApiErrorCode.unauthenticated,
        ApiErrorCode.rateLimited,
      };
      if (!acceptable.contains(e.code)) {
        throw StateError('unexpected code ${e.code.wire}');
      }
      stdout.writeln('        ${e.code.wire}: ${e.message}');
    }
  });

  await check('a missing record is a clean NOT_FOUND', () async {
    try {
      await client.get('/legal/not-a-real-document');
      throw StateError('expected a refusal');
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.internal) {
        throw StateError('a bad path produced a server error, not a refusal');
      }
      stdout.writeln('        ${e.code.wire}');
    }
  });

  client.close();

  stdout.writeln('');
  stdout.writeln('$passed passed, $failed failed');
  expect(failed, 0, reason: 'the live server disagreed with the app in $failed place(s)');
}
