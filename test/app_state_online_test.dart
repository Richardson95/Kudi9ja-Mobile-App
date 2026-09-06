import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kudi9ja/data/api/api_client.dart';
import 'package:kudi9ja/data/api/kudi9ja_api.dart';
import 'package:kudi9ja/data/api/token_store.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `AppState` when there is a server.
///
/// The point of these is that the server is the authority. Every figure the
/// customer sees must come from it, and every decision — is this passcode
/// right, may this money move — must be its decision, not one the phone makes
/// and the server is told about afterwards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Records what the app sent, so a test can assert on the request and not
  /// only on what the app did with the reply.
  late List<http.Request> sent;

  http.Response json(Object body, {int status = 200}) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Map<String, Object?> profile({bool admin = false}) => {
        'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'customerRef': 'K9-SERVER',
        'fullName': 'Chioma Grace Adeyemi',
        'email': 'chioma@example.com',
        'phone': '+2348012345678',
        'dateOfBirth': '1994-04-02',
        'gender': 'Female',
        'bvnLast4': '4321',
        'ninLast4': '8765',
        'address': '12 Marina',
        'state': 'Lagos',
        'payoutBank': 'Zenith Bank',
        'payoutAccountNumber': '1018548852',
        'kycTier': 'TIER2',
        'emailVerified': true,
        'themeMode': 'DARK',
        'hideBalance': false,
        'autoDebit': false,
        'admin': admin,
        'createdAt': '2026-01-01T00:00:00Z',
      };

  Map<String, Object?> session({bool admin = false}) => {
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'expiresInSeconds': 900,
        'sessionId': '11111111-1111-1111-1111-111111111111',
        'admin': admin,
        'profile': profile(admin: admin),
      };

  Map<String, Object?> dashboard({double balance = 125000, bool admin = false}) => {
        'profile': profile(admin: admin),
        'wallet': {
          'balance': balance,
          'totalSaved': 500000,
          'totalOwed': 0,
          'netWorth': balance + 500000,
          'totalInterestEarned': 42500,
          'pendingWithdrawals': 0,
          'customerRef': 'K9-SERVER',
        },
      };

  /// Answers the routine reads so a test can concentrate on one thing.
  http.Response? routine(http.Request request) {
    final path = request.url.path;
    if (path.endsWith('/me/dashboard')) return json(dashboard());
    if (path.endsWith('/transactions')) return json({'content': []});
    if (path.endsWith('/savings/plans')) return json([]);
    if (path.endsWith('/loans')) return json([]);
    if (path.endsWith('/circles')) return json([]);
    if (path.endsWith('/notifications')) return json({'content': []});
    if (path.endsWith('/wallet')) return json(dashboard()['wallet']!);
    return null;
  }

  Future<AppState> build(
    Future<http.Response> Function(http.Request) handler, {
    bool seenOnboarding = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (seenOnboarding) 'k9.onboarded': true,
    });
    final storage = await StorageService.init();

    sent = [];
    final client = ApiClient(
      tokens: InMemoryTokenStore(),
      baseUrl: 'https://api.test/api/v1',
      httpClient: MockClient((request) async {
        sent.add(request);
        return handler(request);
      }),
    );
    late final AppState state;
    state = AppState(storage, api: Kudi9jaApi(client));
    return state;
  }

  group('Signing in', () {
    test('the server decides, and the session is kept', () async {
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/signin')) return json(session());
        return routine(request) ?? json({});
      });

      final ok = await app.signInWithPassword('chioma@example.com', 'correct');

      expect(ok, isTrue);
      expect(app.user!.fullName, 'Chioma Grace Adeyemi');
      // Signing in proves the password. The passcode is a second gate, not a
      // formality, so the app lands locked rather than open.
      expect(app.stage, AuthStage.locked);
    });

    test('a refusal is reported in the server\'s own words', () async {
      final app = await build((request) async => json({
            'code': 'BAD_CREDENTIALS',
            'message': 'That email or password is not right.',
            'details': {},
          }, status: 401));

      final ok = await app.signInWithPassword('chioma@example.com', 'wrong');

      expect(ok, isFalse);
      expect(app.lastError, 'That email or password is not right.');
      expect(app.stage, isNot(AuthStage.unlocked));
    });

    /// The customer reference appears on bank transfers and is what an admin
    /// matches a statement against. A locally derived one would not be found.
    test('the customer reference is the server\'s, not one derived from the id',
        () async {
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/signin')) return json(session());
        return routine(request) ?? json({});
      });

      await app.signInWithPassword('chioma@example.com', 'correct');
      expect(app.user!.customerRef, 'K9-SERVER');
    });
  });

  group('Unlocking', () {
    test('the passcode goes to the server', () async {
      var verified = false;
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/passcode/verify')) {
          verified = true;
          expect(jsonDecode(request.body)['passcode'], '246810');
          return json({'ok': true});
        }
        return routine(request) ?? json({});
      });

      final ok = await app.unlock('246810');

      expect(verified, isTrue,
          reason: 'a passcode checked only on the device is checked by nobody');
      expect(ok, isTrue);
      expect(app.stage, AuthStage.unlocked);
    });

    /// A counter kept on the phone is reset by reinstalling the app, which
    /// makes it no counter at all. The server's count is the real one.
    test('the server\'s attempt count replaces the local one', () async {
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/passcode/verify')) {
          return json({
            'code': 'PASSCODE_INVALID',
            'message': 'That passcode is not right.',
            'details': {'attemptsLeft': 2},
          }, status: 401);
        }
        return routine(request) ?? json({});
      });

      final ok = await app.unlock('000000');

      expect(ok, isFalse);
      expect(app.attemptsLeft, 2);
    });

    test('a locked account is signed out rather than left at the keypad',
        () async {
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/passcode/verify')) {
          return json({
            'code': 'ACCOUNT_LOCKED',
            'message': 'Too many attempts.',
            'details': {},
          }, status: 401);
        }
        return json({});
      });

      await app.unlock('000000');
      expect(app.stage, AuthStage.signedOut);
    });
  });

  group('Refreshing', () {
    test('figures come from the dashboard, not from local arithmetic', () async {
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/signin')) return json(session());
        return routine(request) ?? json({});
      });

      await app.signInWithPassword('chioma@example.com', 'correct');
      await app.refreshFromServer();

      expect(app.balance, 125000.0);
      expect(app.user!.customerRef, 'K9-SERVER');
    });

    /// Losing the whole dashboard because one call timed out would be worse
    /// than showing figures a minute old.
    test('a failed refresh keeps the last known figures', () async {
      var failing = false;
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/signin')) return json(session());
        if (failing) throw http.ClientException('offline');
        return routine(request) ?? json({});
      });

      await app.signInWithPassword('chioma@example.com', 'correct');
      await app.refreshFromServer();
      expect(app.balance, 125000.0);

      failing = true;
      await app.refreshFromServer();

      expect(app.balance, 125000.0, reason: 'the figures survived');
      expect(app.lastError, isNotNull);
      expect(app.isSyncing, isFalse, reason: 'the spinner must not stick on');
    });
  });

  group('Withdrawing', () {
    test('the PIN travels with the request', () async {
      Map<String, dynamic>? body;
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/signin')) return json(session());
        if (request.url.path.endsWith('/withdrawals') && request.method == 'POST') {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return json({
            'id': 'w-1',
            'amount': 20000,
            'bank': 'Zenith Bank',
            'destinationAccount': '1018548852',
            'reference': 'K9-W-001',
            'status': 'PENDING',
            'requestedAt': '2026-09-06T10:00:00Z',
          });
        }
        return routine(request) ?? json({});
      });

      await app.signInWithPassword('chioma@example.com', 'correct');
      final request =
          await app.requestWithdrawal(20000, 'Zenith Bank', '1018548852', pin: '1234');

      expect(body!['pin'], '1234',
          reason: 'the server verifies the PIN with the operation itself');
      expect(body!['amount'], 20000);
      expect(request.reference, 'K9-W-001');
    });

    /// A money-moving call must be safe to send twice. The customer taps
    /// Withdraw, loses signal before the answer arrives, and taps again.
    test('carries an idempotency key', () async {
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/signin')) return json(session());
        if (request.url.path.endsWith('/withdrawals') && request.method == 'POST') {
          return json({
            'id': 'w-1',
            'amount': 20000,
            'status': 'PENDING',
            'requestedAt': '2026-09-06T10:00:00Z',
          });
        }
        return routine(request) ?? json({});
      });

      await app.signInWithPassword('chioma@example.com', 'correct');
      await app.requestWithdrawal(20000, 'Zenith Bank', '1018548852', pin: '1234');

      final withdrawal = sent.firstWhere(
          (r) => r.url.path.endsWith('/withdrawals') && r.method == 'POST');
      expect(withdrawal.headers['Idempotency-Key'], isNotNull);
      expect(withdrawal.headers['Idempotency-Key'], isNotEmpty);
    });

    /// The balance after a withdrawal is the ledger's, read back — not the old
    /// balance with the amount subtracted on the phone.
    test('the balance is read back rather than computed', () async {
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/signin')) return json(session());
        if (request.url.path.endsWith('/withdrawals') && request.method == 'POST') {
          return json({
            'id': 'w-1',
            'amount': 20000,
            'status': 'PENDING',
            'requestedAt': '2026-09-06T10:00:00Z',
          });
        }
        if (request.url.path.endsWith('/wallet')) {
          return json({...dashboard()['wallet']! as Map, 'balance': 105000});
        }
        return routine(request) ?? json({});
      });

      await app.signInWithPassword('chioma@example.com', 'correct');
      await app.requestWithdrawal(20000, 'Zenith Bank', '1018548852', pin: '1234');

      expect(app.balance, 105000.0);
    });
  });

  group('Losing the session', () {
    /// An app that empties itself because a token expired is a great deal more
    /// alarming than one that asks the customer to sign in again.
    test('signs out but keeps what was cached', () async {
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/signin')) return json(session());
        return routine(request) ?? json({});
      });

      await app.signInWithPassword('chioma@example.com', 'correct');
      await app.refreshFromServer();
      expect(app.balance, 125000.0);

      app.handleSessionLost();

      expect(app.stage, AuthStage.signedOut);
      expect(app.balance, 125000.0, reason: 'the figures are still there');
      expect(app.lastError, contains('sign in again'));
    });
  });

  group('Panel access', () {
    test('is the server\'s answer', () async {
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/signin')) {
          return json(session(admin: true));
        }
        return routine(request) ?? json({});
      });

      await app.signInWithPassword('owner@example.com', 'correct');
      expect(app.isAdmin, isTrue);
    });

    test('an ordinary customer is not shown the way in', () async {
      final app = await build((request) async {
        if (request.url.path.endsWith('/auth/signin')) return json(session());
        return routine(request) ?? json({});
      });

      await app.signInWithPassword('chioma@example.com', 'correct');
      expect(app.isAdmin, isFalse);
    });
  });
}
