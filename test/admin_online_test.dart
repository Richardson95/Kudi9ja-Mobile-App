import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kudi9ja/data/api/api_client.dart';
import 'package:kudi9ja/data/api/kudi9ja_api.dart';
import 'package:kudi9ja/data/api/token_store.dart';
import 'package:kudi9ja/data/models/admin.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The admin panel against a server.
///
/// The panel acts on other people's money, so the things worth pinning are the
/// ones where being wrong is expensive: that a decision is the server's and not
/// the phone's, that a queue is re-read after an action rather than guessed at,
/// and that losing panel access mid-session is noticed rather than leaving
/// somebody looking at buttons that all fail.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> sent;

  http.Response json(Object body, {int status = 200}) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Map<String, Object?> claim(String id, {String status = 'PENDING'}) => {
        'id': id,
        'customerName': 'Chioma Grace Adeyemi',
        'customerRef': 'K9-A1B2C3',
        'amount': 50000,
        'reference': 'K9-A1B2C3-7F4K',
        'purpose': 'WALLET',
        'senderName': 'Chioma Adeyemi',
        'status': status,
        'claimedAt': '2026-09-06T09:00:00Z',
      };

  Map<String, Object?> withdrawal(String id, {String status = 'PENDING'}) => {
        'id': id,
        'customerName': 'Chioma Grace Adeyemi',
        'customerRef': 'K9-A1B2C3',
        'amount': 20000,
        'bank': 'Zenith Bank',
        'destinationAccount': '1018548852',
        'reference': 'K9-W-001',
        'status': status,
        'requestedAt': '2026-09-06T09:30:00Z',
      };

  /// A panel whose queues answer with [claims] and [withdrawals], and whose
  /// role is [role]. Anything else the panel asks for comes back empty.
  Future<AppState> panel({
    String role = 'OWNER',
    List<Map<String, Object?>>? claims,
    List<Map<String, Object?>>? withdrawals,
    Future<http.Response> Function(http.Request)? override,
  }) async {
    SharedPreferences.setMockInitialValues({'k9.onboarded': true});
    final storage = await StorageService.init();
    sent = [];

    final tokens = InMemoryTokenStore();
    await tokens.save(
        accessToken: 'a', refreshToken: 'r', expiresInSeconds: 900);

    final client = ApiClient(
      tokens: tokens,
      baseUrl: 'https://api.test/api/v1',
      httpClient: MockClient((request) async {
        sent.add(request);
        if (override != null) {
          final answered = await override(request);
          if (answered.statusCode != 599) return answered;
        }
        final path = request.url.path;
        if (path.endsWith('/admin/team/me')) {
          return json({'role': role, 'name': 'Owner', 'active': true});
        }
        if (path.endsWith('/admin/customers')) return json({'content': []});
        if (path.endsWith('/admin/payins')) {
          return json({'content': claims ?? [claim('c-1')]});
        }
        if (path.endsWith('/admin/withdrawals')) {
          return json({'content': withdrawals ?? [withdrawal('w-1')]});
        }
        if (path.endsWith('/admin/team')) return json([]);
        if (path.endsWith('/admin/audit')) return json({'content': []});
        return json({});
      }),
    );

    return AppState(storage, api: Kudi9jaApi(client));
  }

  group('Opening the panel', () {
    test('reads the role, the queues and the team from the server', () async {
      final app = await panel();
      await app.refreshAdminPanel();

      expect(app.adminRole, AdminRole.owner);
      expect(app.isAdmin, isTrue);
      expect(app.pendingDepositCount, 1);
      expect(app.pendingWithdrawalCount, 1);
    });

    /// The panel hides controls a person cannot use. That is courtesy, not
    /// security — the server checks again on every call — but showing a support
    /// user an owner's buttons wastes their time and looks broken.
    test("the role is the server's, not one stored on the device", () async {
      final app = await panel(role: 'SUPPORT');
      await app.refreshAdminPanel();

      expect(app.adminRole, AdminRole.support);
    });

    /// Access revoked while the panel is open. Better to say so than to leave
    /// somebody pressing buttons that all fail.
    test('losing access mid-session closes the panel', () async {
      final app = await panel(override: (request) async {
        if (request.url.path.endsWith('/admin/team/me')) {
          return http.Response(
              jsonEncode({
                'code': 'NOT_AN_ADMIN',
                'message': 'You no longer have panel access.',
                'details': {},
              }),
              403,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('', 599);
      });

      await app.refreshAdminPanel();

      expect(app.isAdmin, isFalse);
      expect(app.lastError, contains('panel access'));
    });
  });

  group('Confirming a pay-in', () {
    test('credits through the server and re-reads the queue', () async {
      var confirmed = false;
      var queueReads = 0;

      final app = await panel(override: (request) async {
        final path = request.url.path;
        if (path.endsWith('/confirm')) {
          confirmed = true;
          return http.Response(jsonEncode(claim('c-1', status: 'CONFIRMED')), 200,
              headers: {'content-type': 'application/json'});
        }
        if (path.endsWith('/admin/payins')) {
          queueReads++;
          // Empty the second time: the claim has been dealt with.
          return http.Response(
              jsonEncode({'content': queueReads > 1 ? [] : [claim('c-1')]}),
              200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('', 599);
      });

      await app.refreshAdminPanel();
      expect(app.pendingDepositCount, 1);

      await app.confirmDeposit('c-1');

      expect(confirmed, isTrue);
      expect(app.pendingDepositCount, 0,
          reason: 'the queue is re-read, not guessed at');
    });

    /// Confirming credits a real wallet. If the request is sent twice — a tap
    /// on a slow connection, a retry — the server must recognise the second.
    test('carries an idempotency key', () async {
      final app = await panel(override: (request) async {
        if (request.url.path.endsWith('/confirm')) {
          return http.Response(jsonEncode(claim('c-1', status: 'CONFIRMED')), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('', 599);
      });

      await app.confirmDeposit('c-1');

      final confirm =
          sent.firstWhere((r) => r.url.path.endsWith('/confirm'));
      expect(confirm.headers['Idempotency-Key'], isNotNull);
    });

    /// A refusal — already reviewed by another admin, or no permission — is
    /// reported rather than swallowed, and the queue is left alone.
    test('a refusal is surfaced', () async {
      final app = await panel(override: (request) async {
        if (request.url.path.endsWith('/confirm')) {
          return http.Response(
              jsonEncode({
                'code': 'ALREADY_REVIEWED',
                'message': 'Another admin has already reviewed this claim.',
                'details': {},
              }),
              409,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('', 599);
      });

      await app.confirmDeposit('c-1');

      expect(app.lastError, 'Another admin has already reviewed this claim.');
    });
  });

  group('Rejecting and declining', () {
    /// The reason is what the customer is told. "Rejected" on its own leaves
    /// them with nothing to act on.
    test('the reason reaches the server', () async {
      String? note;
      final app = await panel(override: (request) async {
        if (request.url.path.endsWith('/reject')) {
          note = (jsonDecode(request.body) as Map)['note'] as String?;
          return http.Response(jsonEncode(claim('c-1', status: 'REJECTED')), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('', 599);
      });

      await app.rejectDeposit('c-1', 'The receipt does not match the amount.');

      expect(note, 'The receipt does not match the amount.');
    });

    test('declining a withdrawal sends its reason too', () async {
      String? reason;
      final app = await panel(override: (request) async {
        if (request.url.path.endsWith('/decline')) {
          reason = (jsonDecode(request.body) as Map)['reason'] as String?;
          return http.Response(
              jsonEncode(withdrawal('w-1', status: 'DECLINED')), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('', 599);
      });

      await app.declineWithdrawal('w-1', 'Account name does not match.');

      expect(reason, 'Account name does not match.');
    });
  });

  group('The team', () {
    /// The server refuses to remove the last owner and refuses to let an admin
    /// lock themselves out. Both come back saying which, so the message is
    /// passed through rather than replaced with something vaguer.
    test("a refusal keeps the server's explanation", () async {
      final app = await panel(override: (request) async {
        if (request.method == 'DELETE' && request.url.path.contains('/admin/team/')) {
          return http.Response(
              jsonEncode({
                'code': 'LAST_OWNER',
                'message': 'There has to be at least one owner.',
                'details': {},
              }),
              409,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('', 599);
      });

      final result = await app.removeAdmin('admin-1');

      expect(result.ok, isFalse);
      expect(result.message, 'There has to be at least one owner.');
    });
  });
}
