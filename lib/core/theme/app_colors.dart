import 'package:flutter/material.dart';

/// Which palette the app is painting with.
enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  String get label => switch (this) {
    AppThemeMode.system => 'Match my phone',
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
  };

  ThemeMode get material => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

/// One complete set of colours. Both palettes carry the same tokens, so a
/// widget never has to know which one it is painting with.
class AppPalette {
  const AppPalette({
    required this.gold,
    required this.goldDeep,
    required this.goldSoft,
    required this.goldWash,
    required this.black,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceHigh,
    required this.stroke,
    required this.strokeSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnGold,
    required this.success,
    required this.successWash,
    required this.danger,
    required this.dangerWash,
    required this.info,
    required this.infoWash,
    required this.warning,
    required this.cardGradient,
    required this.nightGradient,
    required this.brightness,
  });

  final Color gold;
  final Color goldDeep;
  final Color goldSoft;
  final Color goldWash;
  final Color black;
  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceHigh;
  final Color stroke;
  final Color strokeSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnGold;
  final Color success;
  final Color successWash;
  final Color danger;
  final Color dangerWash;
  final Color info;
  final Color infoWash;
  final Color warning;
  final LinearGradient cardGradient;
  final LinearGradient nightGradient;
  final Brightness brightness;
}

/// Gold on black — the brand's home ground.
const kDarkPalette = AppPalette(
  gold: Color(0xFFF1A83B),
  goldDeep: Color(0xFFD09133),
  goldSoft: Color(0xFFF7C978),
  goldWash: Color(0x1AF1A83B),
  black: Color(0xFF000000),
  canvas: Color(0xFF000000),
  surface: Color(0xFF141212),
  surfaceAlt: Color(0xFF2A2626),
  surfaceHigh: Color(0xFF3B3838),
  stroke: Color(0xFF322E2E),
  strokeSoft: Color(0x1FFFFFFF),
  textPrimary: Color(0xFFFFFFFF),
  textSecondary: Color(0xFFB8B0A8),
  textTertiary: Color(0xFF7C7370),
  textOnGold: Color(0xFF120C02),
  success: Color(0xFF3FCE86),
  successWash: Color(0x1A3FCE86),
  danger: Color(0xFFFF6B6B),
  dangerWash: Color(0x1AFF6B6B),
  info: Color(0xFF5AA9E6),
  infoWash: Color(0x1A5AA9E6),
  warning: Color(0xFFF1A83B),
  cardGradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF241F1A), Color(0xFF120F0D)],
  ),
  nightGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF16120C), Color(0xFF000000)],
  ),
  brightness: Brightness.dark,
);

/// Gold on warm white.
///
/// The gold is deepened, because the brand gold is legible against black but
/// washes out on white — a 4.5:1 contrast floor matters more than an exact
/// hex match. Everything else is a warm neutral rather than a pure grey, so
/// the two palettes feel like the same product.
const kLightPalette = AppPalette(
  gold: Color(0xFF9A6510),
  goldDeep: Color(0xFF7A4F0A),
  goldSoft: Color(0xFFC98A2A),
  goldWash: Color(0x14C98A2A),
  black: Color(0xFF1A1614),
  canvas: Color(0xFFFBF8F4),
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFF2EDE6),
  surfaceHigh: Color(0xFFE3DBD1),
  stroke: Color(0xFFE6DFD6),
  strokeSoft: Color(0x14000000),
  textPrimary: Color(0xFF1A1614),
  textSecondary: Color(0xFF5A524B),
  textTertiary: Color(0xFF8A8078),
  textOnGold: Color(0xFFFFFFFF),
  success: Color(0xFF13804B),
  successWash: Color(0x1413804B),
  danger: Color(0xFFC0392B),
  dangerWash: Color(0x14C0392B),
  info: Color(0xFF1F6FA8),
  infoWash: Color(0x141F6FA8),
  warning: Color(0xFF9A6510),
  cardGradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFDF9), Color(0xFFF6F0E7)],
  ),
  nightGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBF8F4), Color(0xFFF3EDE4)],
  ),
  brightness: Brightness.light,
);

AppPalette _active = kDarkPalette;

/// The palette in force. Every [AppColors] token reads through here, so
/// switching is a single assignment followed by a rebuild.
AppPalette get palette => _active;

void applyPalette(AppPalette next) => _active = next;

/// The Kudi9ja palette, resolved for whichever theme is in force.
///
/// These were compile-time constants when the app was dark-only. They are
/// getters now so the same token name can mean white on black or ink on
/// warm white without every widget having to ask which.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────
  static Color get gold => _active.gold;
  static Color get goldDeep => _active.goldDeep;
  static Color get goldSoft => _active.goldSoft;
  static Color get goldWash => _active.goldWash;

  // ── Canvas & surfaces ──────────────────────────────────────────────────
  static Color get black => _active.black;
  static Color get canvas => _active.canvas;
  static Color get surface => _active.surface;
  static Color get surfaceAlt => _active.surfaceAlt;
  static Color get surfaceHigh => _active.surfaceHigh;
  static Color get stroke => _active.stroke;
  static Color get strokeSoft => _active.strokeSoft;

  // ── Text ───────────────────────────────────────────────────────────────
  static Color get textPrimary => _active.textPrimary;
  static Color get textSecondary => _active.textSecondary;
  static Color get textTertiary => _active.textTertiary;
  static Color get textOnGold => _active.textOnGold;

  // ── Semantic ───────────────────────────────────────────────────────────
  static Color get success => _active.success;
  static Color get successWash => _active.successWash;
  static Color get danger => _active.danger;
  static Color get dangerWash => _active.dangerWash;
  static Color get info => _active.info;
  static Color get infoWash => _active.infoWash;
  static Color get warning => _active.warning;

  // ── Gradients ──────────────────────────────────────────────────────────
  /// The brand gold sweep. Identical in both themes — it is the logo.
  static LinearGradient get goldGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_active.goldSoft, _active.gold, _active.goldDeep],
    stops: const [0.0, 0.45, 1.0],
  );

  static LinearGradient get cardGradient => _active.cardGradient;
  static LinearGradient get nightGradient => _active.nightGradient;

  static LinearGradient get successGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      _active.success,
      Color.lerp(_active.success, _active.black, 0.25)!,
    ],
  );
}
