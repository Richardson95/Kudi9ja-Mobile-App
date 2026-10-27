import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kudi9ja/data/api/api_client.dart';
import 'package:kudi9ja/data/api/api_exception.dart';
import 'package:kudi9ja/data/api/kudi9ja_api.dart';
import 'package:kudi9ja/data/api/mappers.dart';
import 'package:kudi9ja/data/api/token_store.dart';
import 'package:kudi9ja/data/legal/legal_documents.dart';
import 'package:kudi9ja/data/models/lending_admin.dart';
import 'package:kudi9ja/data/models/models.dart';
import 'package:kudi9ja/data/models/platform_settings.dart';
import 'package:kudi9ja/data/models/support.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/features/admin/admin_reports_screen.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app against the server as it now is: weekly repayment and the
/// transaction fee on every instalment, loan-group pricing, the signature an
/// account opens with, documents served by the server, help and complaints,
/// and the rest of what the website was built against.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  http.Response json(Object body, {int status = 200}) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  group('A loan as the server sends it', () {
    final wire = {
      'id': 'loan-1',
      'principal': 125000,
      'tenureMonths': 3,
      'flatRate': 0,
      'processingFee': 5000,
      'transactionFee': 0,
      'netDisbursed': 120000,
      'purpose': 'Business',
      'status': 'ACTIVE',
      'requestedAt': '2026-10-23T09:00:00Z',
      'disbursedAt': '2026-10-23T09:00:00Z',
      'dueDate': '2027-01-22T09:00:00Z',
      'totalInterest': 0,
      'totalRepayable': 127508,
      'repaymentFrequency': 'WEEKLY',
      'repaymentFrequencyLabel': 'Weekly',
      'installmentCount': 12,
      'installmentAmount': 10626,
      'installmentBase': 10417,
      'installmentFee': 209,
      'repaymentFeeRate': 0.02,
      'repaymentFeeRateLabel': '2%',
      'totalRepaymentFees': 2508,
      'loanAndInterest': 125000,
      'amountRepaid': 10626,
      'rebateGranted': 0,
      'outstanding': 116882,
      'repaymentProgress': 0.0833,
      'installmentsPaid': 1,
      'earlySettlementRebate': 0,
      'earlySettlementAmount': 116882,
      'schedule': [
        {
          'number': 1,
          'dueDate': '2026-10-30T09:00:00Z',
          'amount': 10626,
          'amountPaid': 10626,
          'outstanding': 0,
          'status': 'PAID',
          'base': 10417,
          'fee': 209,
        },
        {
          'number': 2,
          'dueDate': '2026-11-06T09:00:00Z',
          'amount': 10626,
          'amountPaid': 0,
          'outstanding': 10626,
          'status': 'UPCOMING',
          'base': 10417,
          'fee': 209,
        },
      ],
    };

    test('reads its figures rather than working them out', () {
      final loan = loanFromApi(wire);
      expect(loan.frequency, RepaymentFrequency.weekly);
      expect(loan.installmentCount, 12);
      expect(loan.installmentAmount, 10626);
      expect(loan.installmentFee, 209);
      expect(loan.totalRepayable, 127508);
      expect(loan.outstanding, 116882);
      expect(loan.settlementAmount, 116882);
      expect(loan.netDisbursed, 120000);
      expect(loan.schedule.first.fee, 209);
      expect(loan.schedule.first.base, 10417);
      expect(loan.nextInstallment!.number, 2);
      expect(loan.termPhrase, '12 weeks, repaid weekly');
    });

    test('survives the round trip through the device cache', () {
      final cached = Loan.fromJson(loanFromApi(wire).toJson());
      expect(cached.frequency, RepaymentFrequency.weekly);
      expect(cached.totalRepayable, 127508);
      expect(cached.schedule.length, 2);
      expect(cached.schedule.first.status, InstallmentStatus.paid);
    });

    test('a loan from before the fee reads as it always did', () {
      final old = loanFromApi({
        'principal': 100000,
        'tenureMonths': 3,
        'flatRate': 0.25,
        'status': 'ACTIVE',
        'disbursedAt': '2026-01-01T00:00:00Z',
      });
      expect(old.frequency, RepaymentFrequency.monthly);
      expect(old.repaymentFeeRate, 0);
      expect(old.totalRepayable, closeTo(125000, 0.01));
    });
  });

  group('What prices a loan', () {
    test('eligibility carries the borrower’s own terms', () {
      final e = LoanEligibility.fromApi({
        'eligible': true,
        'minAmount': 50000,
        'maxAmount': 900000,
        'groupPricing': true,
        'terms': {
          'rates': {'1': 0.1, '3': 0.2},
          'maxTenureMonths': 3,
          'minAmount': 50000,
          'maxAmount': 900000,
          'flatProcessingFee': 4000,
          'processingFeeThreshold': 200000,
          'processingFeeRate': 0.02,
          'repaymentFeeRate': 0.01,
          'weeklyAllowed': true,
          'monthlyAllowed': false,
        },
      });
      expect(e.groupPricing, isTrue);
      expect(e.terms!.group, isTrue);
      expect(e.terms!.rateFor(2), 0.1);
      expect(e.terms!.frequencies, [RepaymentFrequency.weekly]);
      expect(e.terms!.processingFeeFor(100000), 4000);
    });

    test('the public settings are read as the server groups them', () {
      final s = PlatformSettings.fromPublicApi({
        'version': 42,
        'savings': {'annualRate': 0.17, 'minLockDays': 30},
        'lending': {
          'rates': {'1': 0.125, '2': 0.17},
          'maxTenureMonths': 2,
          'minAmount': 50000,
          'maxAmount': 5000000,
          'flatProcessingFee': 5000,
          'processingFeeThreshold': 250000,
          'processingFeeRate': 0.02,
          'repaymentFeeRate': 0.02,
          'weeklyAllowed': true,
          'monthlyAllowed': true,
        },
        'switches': {'lendingEnabled': false},
        'security': {'lockTimeoutMinutes': 3},
        'collectionAccount': {'bank': 'Zenith Bank', 'accountNumber': '1', 'accountName': 'Q'},
      });
      expect(s.version, 42);
      expect(s.processingFeeThreshold, 250000);
      expect(s.loanRepaymentFeeRate, 0.02);
      expect(s.maxLoanTenureMonths, 2);
      expect(s.lendingEnabled, isFalse);
      // Ten minutes is the floor, whatever was saved below it.
      expect(s.lockTimeoutMinutes, 10);
      // No group set sent: members borrow on a copy of the standard one.
      expect(s.groupLending.group, isTrue);
      expect(s.groupLending.rateFor(2), 0.17);
    });

    test('a settings save writes both sets of terms and no retired field', () {
      final json = const PlatformSettings().toJson();
      expect(json.containsKey('loanRepaymentFeeRate'), isTrue);
      expect(json.containsKey('groupLoanRates'), isTrue);
      expect(json.containsKey('groupLoanWeeklyAllowed'), isTrue);
      expect(json.containsKey('earlyPayoffRebateShare'), isFalse);
      expect(json.containsKey('loanCancellationHours'), isFalse);
    });
  });

  group('Documents the server holds', () {
    test('are read into the reader’s blocks', () {
      final doc = legalDocumentFromApi({
        'kind': 'terms',
        'title': 'Terms of Service',
        'shortTitle': 'Terms',
        'version': '1.2',
        'summary': 'The rules.',
        'readMinutes': 12,
        'effectiveFrom': '2026-11-22T00:00:00Z',
        'body': [
          {
            'title': 'One',
            'blocks': [
              {'type': 'text', 'text': 'Hello **you**.'},
              {'type': 'list', 'items': ['a', 'b'], 'ordered': true},
              {'type': 'definitions', 'entries': [{'term': 'T', 'meaning': 'M'}]},
              {'type': 'note', 'text': 'Careful', 'tone': 'caution', 'title': 'Note'},
              {'type': 'example', 'title': 'E', 'rows': [{'label': 'L', 'value': 'V'}]},
              {'type': 'something-new', 'text': 'skipped'},
            ],
          },
        ],
      })!;
      expect(doc.id, 'terms');
      expect(doc.version, '1.2');
      expect(doc.sections.single.blocks.length, 5);
      expect((doc.sections.single.blocks[3] as LegalNote).tone, LegalTone.caution);
    });

    test('replace the bundled copy, so sign-up accepts the version in force', () {
      final before = legalDocumentById('privacy').version;
      useServerLegalDocuments([
        legalDocumentFromApi({
          'kind': 'privacy',
          'title': 'Privacy Policy',
          'version': '9.9',
          'body': [
            {
              'title': 'x',
              'blocks': [
                {'type': 'text', 'text': 'y'},
              ],
            },
          ],
        })!,
      ]);
      expect(legalDocumentById('privacy').version, '9.9');
      expect(before, isNot('9.9'));
    });
  });

  group('Opening an account', () {
    test('sends the signature with the acceptance', () async {
      SharedPreferences.setMockInitialValues({'k9.onboarded': true});
      final storage = await StorageService.init();
      Map<String, dynamic>? body;
      final client = ApiClient(
        tokens: InMemoryTokenStore(),
        baseUrl: 'https://api.test/api/v1',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/complete')) {
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return json({
              'accessToken': 'a',
              'refreshToken': 'r',
              'expiresInSeconds': 900,
              'sessionId': 's',
              'admin': false,
              'profile': {'id': 'u1', 'fullName': 'Chioma Adeyemi', 'email': 'c@x.com', 'phone': '1'},
            });
          }
          return json({});
        }),
      );
      final api = Kudi9jaApi(client);
      final app = AppState(storage, api: api);
      await app.completeSignupFromDraft(
        api,
        'draft-1',
        acceptedVersions: const {'terms': '1.2', 'privacy': '1.2', 'lending': '1.1'},
        signatureImage: 'data:image/png;base64,iVBORw0KGgo=',
        typedName: 'Chioma Adeyemi',
      );
      expect(body!['accepted'], isTrue);
      expect(body!['acceptedVersions'], {'terms': '1.2', 'privacy': '1.2', 'lending': '1.1'});
      final signature = body!['signature'] as Map;
      expect(signature['image'], startsWith('data:image/png;base64,'));
      expect(signature['typedName'], 'Chioma Adeyemi');
      expect(app.stage, AuthStage.unlocked);
    });

    test('an application says how it will be repaid', () async {
      final parts = <String>[];
      final client = ApiClient(
        tokens: InMemoryTokenStore(),
        baseUrl: 'https://api.test/api/v1',
        httpClient: MockClient((request) async {
          parts.add(request.body);
          return json({'id': 'app-1', 'status': 'PENDING', 'repaymentFrequency': 'WEEKLY'});
        }),
      );
      final api = Kudi9jaApi(client);
      final application = await api.applyForLoan(
        amount: 100000,
        months: 3,
        frequency: RepaymentFrequency.weekly,
        purpose: 'Business',
        businessName: 'Shop',
        businessAddress: 'Lagos',
        monthlyIncome: 50000,
        guarantors: const [],
        bankStatement: const UploadPart(field: 'bankStatement', filename: 's.pdf', bytes: [1]),
        selfie: const UploadPart(field: 'selfie', filename: 'me.jpg', bytes: [1]),
        businessPhotos: const [],
        pin: '1234',
      );
      expect(parts.single, contains('"repaymentFrequency":"WEEKLY"'));
      expect(application.repaymentFrequency, RepaymentFrequency.weekly);
    });
  });

  group('Help and complaints', () {
    test('stream events are read by name', () {
      final message = supportEventFrom(ServerEvent(
        'message',
        jsonEncode({
          'conversation': {'id': 'c1', 'subject': 'Transfer', 'status': 'OPEN', 'unread': 1},
          'message': {'id': 'm1', 'conversationId': 'c1', 'author': 'STAFF', 'body': 'On it'},
        }),
      ));
      expect(message, isA<SupportMessageEvent>());
      expect((message as SupportMessageEvent).message.author, SupportAuthor.staff);

      final typing = supportEventFrom(ServerEvent(
        'typing',
        jsonEncode({'conversationId': 'c1', 'who': 'STAFF', 'name': 'Ada'}),
      ));
      expect((typing as SupportTypingEvent).name, 'Ada');

      expect(supportEventFrom(const ServerEvent('hello', '{}')), isNull);
      expect(supportEventFrom(const ServerEvent('message', 'not json')), isNull);
    });

    test('statuses map across the naming conventions', () {
      final c = SupportConversation.fromApi({'status': 'AWAITING_CUSTOMER', 'kind': 'COMPLAINT'});
      expect(c.status, SupportStatus.awaitingCustomer);
      expect(c.kind, SupportKind.complaint);
      expect(SupportStatus.awaitingCustomer.wire, 'AWAITING_CUSTOMER');
    });

    test('the server-sent event stream is parsed line by line', () async {
      final client = ApiClient(
        tokens: InMemoryTokenStore(),
        baseUrl: 'https://api.test/api/v1',
        httpClient: MockClient((request) async {
          expect(request.headers['Accept'], 'text/event-stream');
          return http.Response(
            ': heartbeat\n\n'
            'event: typing\ndata: {"conversationId":"c1","who":"STAFF","name":"Ada"}\n\n'
            'event: message\ndata: {"a":\ndata: 1}\n\n',
            200,
          );
        }),
      );
      final events = await client.events('/support/stream').toList();
      expect(events.map((e) => e.event), ['typing', 'message']);
      // Data split over two lines is joined back with a newline.
      expect(events.last.data, '{"a":\n1}');
    });

    test('a refused stream ends quietly', () async {
      final client = ApiClient(
        tokens: InMemoryTokenStore(),
        baseUrl: 'https://api.test/api/v1',
        httpClient: MockClient((_) async => http.Response('', 404)),
      );
      await expectLater(client.events('/support/stream'), emitsDone);
    });
  });

  group('The rest of the new endpoints', () {
    test('a withdrawal says where its payout has got to', () {
      final w = withdrawalFromApi({'status': 'APPROVED', 'payoutStatus': 'PROCESSING'});
      expect(w.isSending, isTrue);
      expect(w.stateLabel, 'Sending');
      final bounced = withdrawalFromApi({'status': 'APPROVED', 'payoutStatus': 'FAILED'});
      expect(bounced.stateLabel, 'Returned to wallet');
    });

    test('an account the team opened is not mistaken for a wrong password', () {
      final code = ApiErrorCode.parse('ACCOUNT_NOT_ACTIVATED');
      expect(code, ApiErrorCode.accountNotActivated);
    });

    test('repayment history reads the page and the totals', () {
      final h = RepaymentHistory.fromApi({
        'page': {
          'items': [
            {'id': 'r1', 'amount': 5000, 'source': 'BANK_TRANSFER', 'customerName': 'A'},
          ],
          'page': 0,
          'totalPages': 3,
          'hasNext': true,
        },
        'summary': {'total': 5000, 'count': 1, 'recordedByHand': 0},
      });
      expect(h.rows.single.source, RepaymentSource.bankTransfer);
      expect(h.hasMore, isTrue);
      expect(h.summary.total, 5000);
      expect(RepaymentSource.bankTransfer.wire, 'BANK_TRANSFER');
      expect(RepaymentMethod.bankTransfer.wire, 'BANK_TRANSFER');
    });

    test('a report becomes a spreadsheet, quoting where it must', () {
      final csv = toCsv(ExportReport.fromApi({
        'title': 'Loans',
        'period': 'All time',
        'generatedAt': '2026-10-26T10:00:00Z',
        'generatedBy': 'Ada',
        'company': 'Q',
        'columns': [
          {'label': 'Name', 'type': 'TEXT'},
          {'label': 'Amount', 'type': 'MONEY'},
        ],
        'rows': [
          ['Okafor, Ngozi', 125000],
          ['Said "hi"', null],
        ],
      }));
      final lines = const LineSplitter().convert(csv);
      expect(lines[3], 'Name,Amount');
      expect(lines[4], '"Okafor, Ngozi",125000');
      expect(lines[5], '"Said ""hi""",');
    });
  });
}
