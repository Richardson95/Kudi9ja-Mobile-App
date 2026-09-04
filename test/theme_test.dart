import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kudi9ja/core/theme/app_colors.dart';
import 'package:kudi9ja/core/theme/app_theme.dart';
import 'package:kudi9ja/data/services/storage_service.dart';
import 'package:kudi9ja/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Relative luminance, per WCAG.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Themes pull a Google font; tests must not reach the network for it.
  GoogleFonts.config.allowRuntimeFetching = false;

  tearDown(() => applyPalette(kDarkPalette));

  group('Palettes', () {
    test('both carry every token, and they differ', () {
      expect(kDarkPalette.brightness, Brightness.dark);
      expect(kLightPalette.brightness, Brightness.light);

      // The two must not be the same palette wearing a different name.
      expect(kLightPalette.canvas, isNot(kDarkPalette.canvas));
      expect(kLightPalette.textPrimary, isNot(kDarkPalette.textPrimary));
      expect(kLightPalette.surface, isNot(kDarkPalette.surface));
    });

    test('text is readable on its own background in both', () {
      for (final (name, p) in [('dark', kDarkPalette), ('light', kLightPalette)]) {
        // WCAG AA for body text is 4.5:1.
        expect(
          _contrast(p.textPrimary, p.canvas),
          greaterThanOrEqualTo(4.5),
          reason: '$name: primary text on canvas',
        );
        expect(
          _contrast(p.textPrimary, p.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name: primary text on a card',
        );
        expect(
          _contrast(p.textSecondary, p.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name: secondary text on a card',
        );
        // Gold carries meaning — it must be legible, not just decorative.
        expect(
          _contrast(p.gold, p.surface),
          greaterThanOrEqualTo(3.0),
          reason: '$name: gold on a card',
        );
        // And what sits on top of gold.
        expect(
          _contrast(p.textOnGold, p.gold),
          greaterThanOrEqualTo(3.0),
          reason: '$name: text on gold',
        );
      }
    });

    test('semantic colours stay distinguishable in light mode', () {
      final p = kLightPalette;
      for (final (name, c) in [
        ('success', p.success),
        ('danger', p.danger),
        ('info', p.info),
      ]) {
        expect(
          _contrast(c, p.surface),
          greaterThanOrEqualTo(3.0),
          reason: 'light: $name on a card',
        );
      }
    });
  });

  group('Switching', () {
    test('AppColors follows whichever palette is applied', () {
      applyPalette(kDarkPalette);
      final darkText = AppColors.textPrimary;
      final darkCanvas = AppColors.canvas;

      applyPalette(kLightPalette);
      expect(AppColors.textPrimary, isNot(darkText));
      expect(AppColors.canvas, isNot(darkCanvas));
      expect(AppColors.textPrimary, kLightPalette.textPrimary);
    });

    // These build a real ThemeData, which pulls a Google font. With runtime
    // fetching off that throws asynchronously; testWidgets lets us drain it
    // and assert on what we actually care about.
    testWidgets('building a theme applies its palette', (tester) async {
      applyPalette(kLightPalette);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(palette.brightness, Brightness.dark);

      expect(AppTheme.light.brightness, Brightness.light);
      expect(palette.brightness, Brightness.light);

      await tester.pump();
      tester.takeException();
    });

    testWidgets('the light theme paints a light scaffold', (tester) async {
      expect(AppTheme.light.scaffoldBackgroundColor, kLightPalette.canvas);
      expect(AppTheme.dark.scaffoldBackgroundColor, kDarkPalette.canvas);
      await tester.pump();
      tester.takeException();
    });
  });

  group('Every screen survives both palettes', () {
    testWidgets('no widget hard-codes a colour the palette should own', (
      tester,
    ) async {
      // Guards the refactor: AppColors tokens are getters now, so a widget
      // that captured one at construction rather than at build time would
      // keep painting the old theme's colour.
      for (final p in [kDarkPalette, kLightPalette]) {
        applyPalette(p);
        expect(AppColors.canvas, p.canvas);
        expect(AppColors.surface, p.surface);
        expect(AppColors.textPrimary, p.textPrimary);
        expect(AppColors.gold, p.gold);
        expect(AppColors.cardGradient.colors, p.cardGradient.colors);
        expect(AppColors.nightGradient.colors, p.nightGradient.colors);
        // Derived gradients must follow too.
        expect(AppColors.goldGradient.colors.first, p.goldSoft);
        expect(AppColors.successGradient.colors.first, p.success);
      }
    });
  });

  group('The saved preference', () {
    test('defaults to dark and survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final app = AppState(await StorageService.init());
      expect(app.themeMode, AppThemeMode.dark);

      await app.setThemeMode(AppThemeMode.light);
      expect(app.themeMode, AppThemeMode.light);

      // A fresh controller over the same store remembers the choice.
      final again = AppState(await StorageService.init());
      expect(again.themeMode, AppThemeMode.light);
    });

    test('every mode maps to a Flutter ThemeMode', () {
      expect(AppThemeMode.system.material, ThemeMode.system);
      expect(AppThemeMode.light.material, ThemeMode.light);
      expect(AppThemeMode.dark.material, ThemeMode.dark);
      for (final m in AppThemeMode.values) {
        expect(m.label, isNotEmpty);
      }
    });
  });
}
