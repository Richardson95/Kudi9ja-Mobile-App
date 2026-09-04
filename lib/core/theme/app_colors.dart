import 'package:flutter/material.dart';

/// Kudi9ja brand palette — gold on black.
/// Core brand tokens come from the official brand guide; the supporting
/// neutrals and semantic colours are tuned so the system reads as one piece.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────
  static const gold = Color(0xFFF1A83B);
  static const goldDeep = Color(0xFFD09133);
  static const goldSoft = Color(0xFFF7C978);
  static const goldWash = Color(0x1AF1A83B); // 10% gold — tints & halos

  // ── Canvas & surfaces ──────────────────────────────────────────────────
  static const black = Color(0xFF000000);
  static const canvas = Color(0xFF000000);
  static const surface = Color(0xFF141212);
  static const surfaceAlt = Color(0xFF2A2626);
  static const surfaceHigh = Color(0xFF3B3838);
  static const stroke = Color(0xFF322E2E);
  static const strokeSoft = Color(0x1FFFFFFF);

  // ── Text ───────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB8B0A8);
  static const textTertiary = Color(0xFF7C7370);
  static const textOnGold = Color(0xFF120C02);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const success = Color(0xFF3FCE86);
  static const successWash = Color(0x1A3FCE86);
  static const danger = Color(0xFFFF6B6B);
  static const dangerWash = Color(0x1AFF6B6B);
  static const info = Color(0xFF5AA9E6);
  static const infoWash = Color(0x1A5AA9E6);
  static const warning = Color(0xFFF1A83B);

  // ── Gradients ──────────────────────────────────────────────────────────
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7C978), gold, goldDeep],
    stops: [0.0, 0.45, 1.0],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF241F1A), Color(0xFF120F0D)],
  );

  static const nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF16120C), Color(0xFF000000)],
  );

  static const successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4FE39A), Color(0xFF23A768)],
  );
}
