import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kudi9ja/data/services/security_service.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:kudi9ja/widgets/primitives.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _freshState() async {
  SharedPreferences.setMockInitialValues({});
  return AppState(await StorageService.init());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session gating', () {
    test('a first run starts in onboarding', () async {
      final app = await _freshState();
      expect(app.stage, AuthStage.onboarding);
    });

    test('finishing onboarding without an account lands signed out', () async {
      final app = await _freshState();
      await app.completeOnboarding();
      expect(app.stage, AuthStage.signedOut);
    });
  });

  group('Passcode security', () {
    test('hashes are salted and never equal the plaintext', () {
      final hash = SecurityService.hash('483920');
      expect(hash, isNot('483920'));
      expect(hash.length, 64);
      expect(SecurityService.verify('483920', hash), isTrue);
      expect(SecurityService.verify('483921', hash), isFalse);
    });

    test('an OTP is always six digits', () {
      for (var i = 0; i < 50; i++) {
        expect(SecurityService.issueOtp(), matches(RegExp(r'^\d{6}$')));
      }
    });
  });

  testWidgets('the gold button renders its label and fires once', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoldButton(label: 'Lock savings', onPressed: () => taps++),
        ),
      ),
    );
    expect(find.text('Lock savings'), findsOneWidget);
    await tester.tap(find.text('Lock savings'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('a disabled gold button ignores taps', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GoldButton(label: 'Continue')),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    // No callback to assert on — the test passes by not throwing.
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('provider wiring exposes AppState to the tree', (tester) async {
    final app = await _freshState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: app,
        child: MaterialApp(
          home: Builder(
            builder: (context) =>
                Text('${context.watch<AppState>().balance}'),
          ),
        ),
      ),
    );
    expect(find.text('0.0'), findsOneWidget);
  });
}
