import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/core/constants/app_config.dart';
import 'package:kudi9ja/core/utils/formatters.dart';
import 'package:kudi9ja/data/legal/legal_documents.dart';
import 'package:kudi9ja/data/models/models.dart';
import 'package:kudi9ja/data/models/platform_settings.dart';
import 'package:kudi9ja/features/legal/legal_document_screen.dart';
import 'package:kudi9ja/features/legal/legal_screen.dart';

/// Every string in a document, flattened, so a test can assert on content
/// without caring which block it lives in.
List<String> _textOf(LegalDocument doc) => [
  doc.title,
  doc.summary,
  for (final section in doc.sections) ...[
    section.title,
    for (final block in section.blocks)
      ...switch (block) {
        LegalText(:final text) => [text],
        LegalList(:final items) => items,
        LegalDefs(:final entries) => [
          for (final (term, meaning) in entries) '$term $meaning',
        ],
        LegalNote(:final text, :final title) => [text, title ?? ''],
        LegalExample(:final title, :final rows) => [
          title,
          for (final (label, value) in rows) '$label $value',
        ],
      },
  ],
];

void main() {
  group('legal documents', () {
    test('all three exist and are addressable by id', () {
      final docs = allLegalDocuments();
      expect(docs.map((d) => d.id), ['terms', 'privacy', 'lending']);
      for (final doc in docs) {
        expect(legalDocumentById(doc.id).title, doc.title);
      }
    });

    test('every document is versioned, dated and substantial', () {
      for (final doc in allLegalDocuments()) {
        expect(doc.version, isNotEmpty, reason: doc.id);
        expect(doc.readMinutes, greaterThan(0), reason: doc.id);
        expect(doc.sections.length, greaterThanOrEqualTo(10), reason: doc.id);
        for (final section in doc.sections) {
          expect(section.title, isNotEmpty);
          expect(section.blocks, isNotEmpty, reason: section.title);
        }
      }
    });

    test('the company, not the product, is named as the contracting party', () {
      for (final doc in allLegalDocuments()) {
        final body = _textOf(doc).join('\n');
        expect(body, contains(AppConfig.legalEntity), reason: doc.id);
        expect(body, contains(AppConfig.rcNumber), reason: doc.id);
      }
    });

    test('each document routes the reader to the right inbox', () {
      final terms = _textOf(legalDocumentById('terms')).join('\n');
      final privacy = _textOf(legalDocumentById('privacy')).join('\n');
      expect(terms, contains(AppConfig.legalEmail));
      expect(privacy, contains(AppConfig.privacyEmail));
    });

    test('emphasis markers are always closed', () {
      for (final doc in allLegalDocuments()) {
        for (final line in _textOf(doc)) {
          expect(
            '**'.allMatches(line).length.isEven,
            isTrue,
            reason: 'unbalanced emphasis in "$line"',
          );
        }
      }
    });

    test('the lending agreement quotes the rates the app actually charges', () {
      final body = _textOf(legalDocumentById('lending')).join('\n');
      for (final months in const [1, 2, 3]) {
        expect(
          body,
          contains(
            '${settings.loanRateLabelFor(months)} flat',
          ),
          reason: 'rate for $months months',
        );
      }
      expect(body, contains(settings.flatProcessingFee.asNairaFlat));
      expect(body, contains(settings.minLoanAmount.asNairaFlat));
      expect(body, contains(settings.maxLoanAmount.asNairaFlat));
    });

    test('both documents state the tenure the rate belongs to', () {
      final lending = _textOf(legalDocumentById('lending')).join('\n');
      final terms = _textOf(legalDocumentById('terms')).join('\n');
      expect(lending, contains('Over 1 month'));
      expect(lending, contains('Over 3 months'));
      expect(terms, contains('12.5% over 1 month'));
      expect(terms, contains('25% over 3'));
    });

    test('the worked examples match Finance, to the naira', () {
      final body = _textOf(legalDocumentById('lending')).join('\n');

      for (final (principal, months) in const [
        (50000.0, 1),
        (200000.0, 1),
        (200000.0, 2),
        (200000.0, 3),
      ]) {
        expect(
          body,
          contains(Finance.netDisbursed(principal).asNairaFlat),
          reason: 'net disbursement for $principal',
        );
        expect(
          body,
          contains(Finance.loanTotal(principal, months).asNairaFlat),
          reason: 'total repayable for $principal',
        );
      }
    });

    test('the terms quote the savings rates the app actually pays', () {
      final body = _textOf(legalDocumentById('terms')).join('\n');
      expect(
        body,
        contains('${settings.savingsRatePct.toStringAsFixed(0)}% per annum'),
      );
      expect(
        body,
        contains('${settings.targetLongPct.toStringAsFixed(1)}% bonus'),
      );
    });

    test('documents follow the platform settings when an admin changes them', () {
      final original = settings;
      addTearDown(() => applySettings(original));

      applySettings(original.withLoanRate(3, 0.30));
      final body = _textOf(legalDocumentById('lending')).join('\n');
      expect(body, contains('30% flat'));
      expect(body, isNot(contains('25% flat')));
    });

    test('the fee rule is stated unambiguously in both documents', () {
      for (final id in const ['terms', 'lending']) {
        final body = _textOf(legalDocumentById(id)).join(' ');
        expect(body, contains('management fee'), reason: id);
        expect(
          body,
          contains('whole amount'),
          reason: '$id must rule out "1% of the excess"',
        );
        expect(body, contains('up to and including'), reason: id);
      }
    });

    test('the privacy policy states the promises we make about data', () {
      final body = _textOf(legalDocumentById('privacy')).join('\n');
      for (final promise in const [
        'never sell your personal data',
        'Nigeria Data Protection Act 2023',
        '72 hours',
        'human',
      ]) {
        expect(body, contains(promise), reason: promise);
      }
    });

    testWidgets('the hub lists every document and opens one', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LegalScreen()));
      await tester.pumpAndSettle();

      for (final doc in allLegalDocuments()) {
        expect(find.text(doc.title), findsOneWidget);
      }

      await tester.tap(find.text('Lending Agreement'));
      await tester.pumpAndSettle();
      expect(find.byType(LegalDocumentScreen), findsOneWidget);
      expect(find.text('What a loan costs'), findsOneWidget);
    });

    testWidgets('a document renders every section without overflowing', (
      tester,
    ) async {
      for (final doc in allLegalDocuments()) {
        await tester.pumpWidget(
          MaterialApp(
            home: LegalDocumentScreen(key: ValueKey(doc.id), document: doc),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(doc.title), findsWidgets);
        expect(
          find.text('Contents — ${doc.sections.length} sections'),
          findsOneWidget,
        );

        // Scroll the whole document, so a bad layout anywhere in it surfaces
        // and every section is proved to build.
        final list = find.byType(Scrollable).first;
        final seen = <String>{};
        for (var i = 0; i < 60; i++) {
          for (final section in doc.sections) {
            if (find.text(section.title).evaluate().isNotEmpty) {
              seen.add(section.title);
            }
          }
          await tester.drag(list, const Offset(0, -500));
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
        expect(
          seen,
          hasLength(doc.sections.length),
          reason: 'sections never built in ${doc.id}: '
              '${doc.sections.map((s) => s.title).toSet().difference(seen)}',
        );
      }
    });

    test('the lending agreement sets out collection conduct limits', () {
      final body = _textOf(legalDocumentById('lending')).join('\n');
      for (final commitment in const [
        'never contact your friends, family, employer or phone contacts',
        '8am and 8pm',
        'credit bureaux',
        'Equivalent annual rate',
      ]) {
        expect(body, contains(commitment), reason: commitment);
      }
    });
  });
}
