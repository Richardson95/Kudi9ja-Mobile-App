import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kudi9ja/data/api/api_client.dart';
import 'package:kudi9ja/data/api/kudi9ja_api.dart';
import 'package:kudi9ja/data/api/token_store.dart';
import 'package:kudi9ja/data/models/loan_application.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two decisions the web panel gained, against a server: recording a payout
/// already made by hand, and changing a loan's terms for the customer to
/// answer. In both, a wrong field on the wire costs money — Paystack sending
/// a payout a second time, or a loan lent on terms nobody agreed to.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> sent;

  http.Response json(Object body, {int status = 200}) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Map<String, Object?> application(String id, {String status = 'PENDING'}) => {
        'id': id,
        'amount': 200000,
        'tenureMonths': 3,
        'purpose': 'Stock',
        'status': status,
        'submittedAt': '2026-10-29T09:00:00Z',
        'repaymentFrequency': 'MONTHLY',
        'customerName': 'Chioma Grace Adeyemi',
      };

  /// An app signed in against a server. Whatever [answer] does not handle
  /// comes back empty.
  Future<AppState> signedIn(
      [Future<http.Response?> Function(http.Request)? answer]) async {
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
        final answered = answer == null ? null : await answer(request);
        if (answered != null) return answered;
        final path = request.url.path;
        if (path.endsWith('/admin/team/me')) {
          return json({'role': 'OWNER', 'name': 'Owner', 'active': true});
        }
        if (path.endsWith('/admin/team')) return json([]);
        return json({'content': []});
      }),
    );
    return AppState(storage, api: Kudi9jaApi(client));
  }

  Map<String, dynamic> bodyOf(http.Request r) =>
      (jsonDecode(r.body) as Map).cast<String, dynamic>();

  group('Approving a withdrawal', () {
    test('paid by hand tells the server, with the bank reference', () async {
      final app = await signedIn();
      await app.refreshAdminPanel();

      await app.approveWithdrawal('w-1',
          payoutReference: 'FT2610290001', paidByHand: true);

      final approve = sent.lastWhere((r) => r.url.path.endsWith('/approve'));
      expect(approve.url.path, endsWith('/admin/withdrawals/w-1/approve'));
      expect(bodyOf(approve), {
        'payoutReference': 'FT2610290001',
        'paidByHand': true,
      });
    });

    test('an ordinary approval does not claim it was paid by hand', () async {
      final app = await signedIn();
      await app.refreshAdminPanel();

      await app.approveWithdrawal('w-1');

      final approve = sent.lastWhere((r) => r.url.path.endsWith('/approve'));
      expect(bodyOf(approve).containsKey('paidByHand'), isFalse);
    });

    test("a refusal keeps the server's explanation", () async {
      final app = await signedIn((r) async => r.url.path.endsWith('/approve')
          ? json({
              'code': 'VALIDATION_FAILED',
              'message': 'Give the reference of the bank transfer that paid it.',
              'details': {},
            }, status: 400)
          : null);
      await app.refreshAdminPanel();

      await app.approveWithdrawal('w-1', paidByHand: true);

      expect(app.lastError, contains('reference of the bank transfer'));
    });
  });

  group('Changing the terms', () {
    test('the queue asks for open applications by name', () async {
      final app = await signedIn((r) async {
        if (!r.url.path.endsWith('/admin/loan-applications')) return null;
        final status = r.url.queryParameters['status'];
        return json({
          'content': [
            if (status == 'PENDING') application('a-1'),
            if (status == 'OFFERED') application('a-2', status: 'OFFERED'),
          ],
        });
      });
      await app.refreshAdminPanel();

      expect(app.adminLoanApplications.map((a) => a.id),
          unorderedEquals(['a-1', 'a-2']));
      expect(app.pendingLoanApplicationCount, 1,
          reason: 'one waits on the team, the other on the customer');
    });

    test('rates go as the percentages an admin types', () async {
      final app = await signedIn((r) async => r.url.path.endsWith('/offer')
          ? json({
              ...application('a-1', status: 'OFFERED'),
              'offer': {
                'months': 6,
                'flatRate': 0.175,
                'managementFee': 7500,
                'repaymentFeeRate': 0.025,
                'offeredAt': '2026-10-29T10:00:00Z',
                'offeredBy': 'Owner',
              },
            })
          : null);
      await app.refreshAdminPanel();

      final updated = await app.offerLoanApplicationTerms(
        'a-1',
        months: 6,
        flatRate: 0.175,
        managementFee: 7500,
        repaymentFeeRate: 0.025,
        note: '  Six months suits your income better.  ',
      );

      final offer = sent.lastWhere((r) => r.url.path.endsWith('/offer'));
      expect(offer.url.path, endsWith('/admin/loan-applications/a-1/offer'));
      expect(bodyOf(offer), {
        'months': 6,
        'interestRatePct': 17.5,
        'managementFee': 7500,
        'transactionFeePct': 2.5,
        'note': 'Six months suits your income better.',
      });
      expect(updated!.isOffered, isTrue);
      expect(updated.offer!.offeredBy, 'Owner');
    });

    test('an offer that changes nothing is refused with the reason', () async {
      final app = await signedIn((r) async => r.url.path.endsWith('/offer')
          ? json({
              'code': 'VALIDATION_FAILED',
              'message': 'Nothing has changed from the terms it is priced on now. '
                  'Approve it as it is instead.',
              'details': {},
            }, status: 400)
          : null);
      await app.refreshAdminPanel();

      final updated = await app.offerLoanApplicationTerms('a-1',
          months: 3, flatRate: 0.25, managementFee: 5000, repaymentFeeRate: 0.02);

      expect(updated, isNull);
      expect(app.lastError, contains('Nothing has changed'));
    });
  });

  group('The customer answering', () {
    test('agreeing sends the PIN and puts it back with the team', () async {
      final app = await signedIn((r) async {
        if (r.url.path.endsWith('/loans/applications')) {
          return json([application('a-1', status: 'OFFERED')]);
        }
        if (r.url.path.endsWith('/agree')) {
          return json(application('a-1'));
        }
        return null;
      });
      await app.refreshLoanApplications();
      expect(app.offeredLoanApplications, hasLength(1));

      final ok = await app.agreeToLoanTerms('a-1', pin: '1234');

      expect(ok, isTrue);
      final agree = sent.lastWhere((r) => r.url.path.endsWith('/agree'));
      expect(agree.url.path, endsWith('/loans/applications/a-1/agree'));
      expect(bodyOf(agree), {'pin': '1234'});
      expect(app.offeredLoanApplications, isEmpty);
      expect(app.pendingLoanApplication?.id, 'a-1');
    });

    test('a wrong PIN leaves the terms waiting', () async {
      final app = await signedIn((r) async {
        if (r.url.path.endsWith('/loans/applications')) {
          return json([application('a-1', status: 'OFFERED')]);
        }
        if (r.url.path.endsWith('/agree')) {
          return json({
            'code': 'INVALID_PIN',
            'message': 'That PIN is not right.',
            'details': {},
          }, status: 400);
        }
        return null;
      });
      await app.refreshLoanApplications();

      final ok = await app.agreeToLoanTerms('a-1', pin: '0000');

      expect(ok, isFalse);
      expect(app.lastError, contains('PIN'));
      expect(app.offeredLoanApplications, hasLength(1));
    });

    test('turning them down closes the application', () async {
      final app = await signedIn((r) async {
        if (r.url.path.endsWith('/loans/applications')) {
          return json([application('a-1', status: 'OFFERED')]);
        }
        if (r.url.path.endsWith('/turn-down')) {
          return json(application('a-1', status: 'TERMS_DECLINED'));
        }
        return null;
      });
      await app.refreshLoanApplications();

      final ok = await app.turnDownLoanTerms('a-1');

      expect(ok, isTrue);
      expect(sent.last.url.path, endsWith('/loans/applications/a-1/turn-down'));
      expect(app.loanApplications.single.status,
          LoanApplicationStatus.termsDeclined);
      expect(app.offeredLoanApplications, isEmpty);
      expect(app.pendingLoanApplication, isNull);
    });
  });
}
