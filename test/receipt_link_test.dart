import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/core/constants/app_config.dart';
import 'package:kudi9ja/data/api/mappers.dart';
import 'package:kudi9ja/data/models/admin.dart';

/// Two things the panel got wrong at once, both about what the server hands
/// back rather than about what it does.
///
/// A receipt arrived as a path with no host on it, so every one of them drew as
/// a broken image over the words "Receipt image unavailable" — and enlarging
/// one blamed an expired link, which was never the problem. A role arrived only
/// once the panel had been opened, so an owner's own dashboard called them a
/// Viewer until they had been somewhere else and come back.
void main() {
  group('A signed receipt link', () {
    test('is given the host the app is talking to', () {
      final resolved = AppConfig.absoluteUrl(
          '/api/v1/admin/receipts/a2V5?expires=99&signature=sig');

      final base = Uri.parse(AppConfig.apiBaseUrl);
      final url = Uri.parse(resolved);
      expect(url.scheme, base.scheme);
      expect(url.host, base.host);
      expect(url.path, '/api/v1/admin/receipts/a2V5');
      // The query is what makes the link openable at all — dropping either
      // half of it turns every receipt into a 403.
      expect(url.queryParameters['expires'], '99');
      expect(url.queryParameters['signature'], 'sig');
    });

    test('is left alone when it already names a host', () {
      const already = 'https://files.example.com/receipt.jpg?x=1';
      expect(AppConfig.absoluteUrl(already), already);
    });

    test('stays empty when there is no receipt', () {
      expect(AppConfig.absoluteUrl(''), '');
    });

    test('reaches the model resolved, not raw', () {
      final claim = claimFromApi({
        'id': '1',
        'amount': 13000,
        'reference': 'K9-255B9A-MLFM',
        'receiptUrl': '/api/v1/admin/receipts/a2V5?expires=99&signature=sig',
      });

      expect(Uri.parse(claim.receiptUrl).hasScheme, isTrue);
      expect(claim.hasReceipt, isTrue);
    });
  });

  group('A role off the wire', () {
    test('is read whatever case or punctuation it arrives in', () {
      expect(adminRoleFromApi('OWNER'), AdminRole.owner);
      expect(adminRoleFromApi('owner'), AdminRole.owner);
      expect(adminRoleFromApi('Support'), AdminRole.support);
    });

    test('is null when there is no grant, which is not the same as viewer', () {
      expect(adminRoleFromApi(null), isNull);
      expect(adminRoleFromApi(''), isNull);
      expect(adminRoleFromApi(7), isNull);
    });
  });
}
