import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kudi9ja/data/api/api_client.dart';
import 'package:kudi9ja/data/api/api_exception.dart';
import 'package:kudi9ja/data/api/kudi9ja_api.dart';
import 'package:kudi9ja/data/api/token_store.dart';
import 'package:kudi9ja/data/models/models.dart';
import 'package:kudi9ja/data/models/thrift.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Savings, lending, circles and pay-ins, against a server.
///
/// The theme is that the server does the arithmetic and the app reports it. The
/// app has a complete, correct copy of every formula — it was written first and
/// is still tested — and that is exactly the danger: two implementations that
/// agree today will disagree the first time a rate is edited from the admin
/// panel, and the customer would be shown the stale one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> sent;

  http.Response json(Object body, {int status = 200}) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  http.Response refusal(String code, String message, {int status = 409}) =>
      json({'code': code, 'message': message, 'details': {}}, status: status);

  Map<String, Object?> wallet(double balance) => {
        'balance': balance,
        'totalSaved': 0,
        'totalOwed': 0,
        'netWorth': balance,
        'totalInterestEarned': 0,
        'pendingWithdrawals': 0,
      };

  /// A signed-in app whose routine reads answer empty, with [handler] getting
  /// first refusal on every request.
  Future<AppState> app(Future<http.Response> Function(http.Request) handler) async {
    SharedPreferences.setMockInitialValues({'k9.onboarded': true});
    final storage = await StorageService.init();
    sent = [];

    final tokens = InMemoryTokenStore();
    await tokens.save(accessToken: 'a', refreshToken: 'r', expiresInSeconds: 900);

    final client = ApiClient(
      tokens: tokens,
      baseUrl: 'https://api.test/api/v1',
      httpClient: MockClient((request) async {
        sent.add(request);
        final answered = await handler(request);
        if (answered.statusCode != 599) return answered;

        final path = request.url.path;
        if (path.endsWith('/wallet')) return json(wallet(100000));
        if (path.endsWith('/transactions')) return json({'content': []});
        if (path.endsWith('/savings/plans')) return json([]);
        if (path.endsWith('/loans')) return json([]);
        if (path.endsWith('/circles')) return json([]);
        return json({});
      }),
    );

    return AppState(storage, api: Kudi9jaApi(client));
  }

  http.Response pass() => http.Response('', 599);

  Map<String, dynamic> bodyOf(String pathEnd, {String method = 'POST'}) {
    final request = sent.firstWhere(
        (r) => r.url.path.endsWith(pathEnd) && r.method == method);
    return jsonDecode(request.body) as Map<String, dynamic>;
  }

  group('Savings', () {
    test('a fixed plan is priced by the server, not on the phone', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/savings/plans/fixed')) {
          return json({
            'id': 'p-1',
            'title': 'School fees',
            'type': 'FIXED',
            'status': 'ACTIVE',
            'principal': 500000,
            'lockDays': 365,
            // Deliberately not 17% of the principal. If the app were still
            // computing this itself, it would show 85,000 and be wrong.
            'interestPaid': 91234.56,
            'startDate': '2026-09-06T00:00:00Z',
            'maturityDate': '2027-09-06T00:00:00Z',
          });
        }
        return pass();
      });

      final plan = await state.createFixedPlan(
        title: 'School fees',
        principal: 500000,
        days: 365,
        pin: '1234',
      );

      expect(plan.interestPaid, 91234.56,
          reason: "the server's figure, not the app's formula");
      expect(bodyOf('/savings/plans/fixed')['pin'], '1234');
    });

    test('creating a plan carries an idempotency key', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/savings/plans/fixed')) {
          return json({'id': 'p-1', 'title': 'x', 'type': 'FIXED'});
        }
        return pass();
      });

      await state.createFixedPlan(
          title: 'x', principal: 1000, days: 30, pin: '1234');

      final create = sent.firstWhere(
          (r) => r.url.path.endsWith('/savings/plans/fixed'));
      expect(create.headers['Idempotency-Key'], isNotNull);
    });

    /// Withdrawing a matured plan credits principal and possibly a bonus. Both
    /// figures come back from the server rather than being worked out twice.
    test('a plan withdrawal reports what the server credited', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/withdraw')) {
          return json({
            'planId': 'p-1',
            'principalReturned': 500000,
            'bonusPaid': 50000,
            'totalCredited': 550000,
            'newBalance': 650000,
          });
        }
        return pass();
      });

      final result = await state.withdrawPlan('p-1', pin: '1234');

      expect(result.principal, 500000.0);
      expect(result.bonus, 50000.0);
    });

    /// A fixed plan cannot be broken at all. The server refuses; the app must
    /// say so rather than pretending it worked.
    test('a refused break is reported and moves nothing', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/break')) {
          return refusal('PLAN_CANNOT_BREAK',
              'A Fixed Savings plan cannot be broken before it matures.');
        }
        return pass();
      });

      final received = await state.breakPlan('p-1', pin: '1234');

      expect(received, 0);
      expect(state.lastError,
          'A Fixed Savings plan cannot be broken before it matures.');
    });
  });

  group('Lending', () {
    test('the loan the server issues is the one recorded', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/loans') && request.method == 'POST') {
          return json({
            'id': 'l-1',
            'principal': 200000,
            'tenureMonths': 6,
            'flatRate': 0.45,
            'processingFee': 5000,
            'purpose': 'Stock',
            'status': 'PENDING',
            'requestedAt': '2026-09-06T00:00:00Z',
          });
        }
        return pass();
      });

      final loan = await state.requestLoan(
          principal: 200000, months: 6, purpose: 'Stock', pin: '1234');

      expect(loan.status, LoanStatus.pending,
          reason: 'a new loan is under review, not active');
      expect(bodyOf('/loans')['pin'], '1234');
    });

    /// Being refused a loan is normal and must reach the customer with the
    /// server's explanation, which names the amount they can actually borrow.
    test('an ineligible request surfaces the reason', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/loans') && request.method == 'POST') {
          return refusal('OFFER_EXCEEDED',
              'The most you can borrow right now is 120,000.');
        }
        return pass();
      });

      await expectLater(
        state.requestLoan(
            principal: 5000000, months: 6, purpose: 'x', pin: '1234'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', contains('120,000'))),
      );
    });

    test('early settlement reports what was paid and rebated', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/settle')) {
          return json({
            'loanId': 'l-1',
            'amountPaid': 180000,
            'rebate': 20000,
            'outstanding': 0,
            'status': 'REPAID',
          });
        }
        return pass();
      });

      final result = await state.payOffEarly('l-1', pin: '1234');

      expect(result.paid, 180000.0);
      expect(result.rebate, 20000.0);
    });
  });

  group('Thrift circles', () {
    /// Members are sent as customer references, and the customer is not one of
    /// them — the server knows who is asking.
    test('members are sent by reference, excluding the customer', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/circles') && request.method == 'POST') {
          return json({'id': 'c-1', 'name': 'Market women', 'members': []});
        }
        return pass();
      });

      await state.createCircle(
        name: 'Market women',
        emoji: '🤝',
        contribution: 10000,
        frequency: AutoFrequency.monthly,
        members: const [
          ThriftMember(customerRef: 'K9-AAA111', name: 'Me', initials: 'ME', isMe: true),
          ThriftMember(customerRef: 'K9-BBB222', name: 'Ngozi', initials: 'NG'),
          ThriftMember(customerRef: 'K9-CCC333', name: 'Tunde', initials: 'TU'),
        ],
        pin: '1234',
      );

      expect(bodyOf('/circles')['memberRefs'], ['K9-BBB222', 'K9-CCC333']);
    });

    /// A circle built around people who do not exist collects nothing from them
    /// and pays the pot out anyway, so the server checks each reference.
    test('an unknown member is refused with the reference named', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/circles') && request.method == 'POST') {
          return refusal('MEMBER_NOT_A_CUSTOMER',
              'K9-BBB222 is not a Kudi9ja account.');
        }
        return pass();
      });

      await expectLater(
        state.createCircle(
          name: 'x',
          emoji: '🤝',
          contribution: 1000,
          frequency: AutoFrequency.monthly,
          members: const [
            ThriftMember(customerRef: 'K9-BBB222', name: 'Ngozi', initials: 'NG'),
          ],
          pin: '1234',
        ),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', contains('K9-BBB222'))),
      );
    });

    test('collecting the pot reports the payout', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/payout')) {
          return json({'circleId': 'c-1', 'round': 2, 'payout': 60000});
        }
        return pass();
      });

      expect(await state.advanceCircle('c-1', pin: '1234'), 60000.0);
    });
  });

  group('Paying in', () {
    /// The reference is issued by the server and is what an admin matches
    /// against a bank statement. One invented on the phone would never be found.
    test('the reference comes from the server', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/payins/reference')) {
          return json({
            'reference': 'K9-A1B2C3-7F4K',
            'bank': 'Zenith Bank',
            'accountNumber': '1018548852',
            'accountName': 'Quadrilateral Technologies Ltd',
          });
        }
        return pass();
      });

      expect(await state.paymentReference(), 'K9-A1B2C3-7F4K');
    });

    /// Copying is the event worth recording, and it spends the reference — the
    /// next payment needs its own, or two transfers of the same amount on the
    /// same day are indistinguishable on the statement.
    test('copying records it and returns the next one', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/payins/reference/copied')) {
          return json({'reference': 'K9-A1B2C3-9M2P'});
        }
        return pass();
      });

      expect(await state.markReferenceCopied(), 'K9-A1B2C3-9M2P');
    });

    /// If the copy did not register, the reference on screen is still the live
    /// one. Replacing it would leave the customer quoting one the server has no
    /// record of.
    test('a failed copy leaves the reference alone', () async {
      final state = await app((request) async {
        if (request.url.path.endsWith('/payins/reference/copied')) {
          return refusal('INTERNAL', 'Something went wrong.', status: 500);
        }
        return pass();
      });

      expect(await state.markReferenceCopied(), '');
    });

    /// An unreachable server must not produce an invented reference: the
    /// customer would quote it on a real transfer and nobody would find it.
    test('an unreachable server yields no reference at all', () async {
      final state = await app((_) async => throw http.ClientException('offline'));

      expect(await state.paymentReference(), '');
      expect(state.lastError, isNotNull);
    });
  });
}
