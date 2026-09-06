import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/models/platform_settings.dart';
import 'features/auth/lock_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/splash/splash_screen.dart';
import 'state/app_state.dart';

class Kudi9jaApp extends StatefulWidget {
  const Kudi9jaApp({super.key});

  @override
  State<Kudi9jaApp> createState() => _Kudi9jaAppState();
}

class _Kudi9jaAppState extends State<Kudi9jaApp> with WidgetsBindingObserver {
  bool _booting = true;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Hold the splash long enough for the brand animation to land.
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _booting = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Leaving the app arms the passcode gate; coming back after the idle
  /// window demands it again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final app = context.read<AppState>();
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _backgroundedAt = DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        if (since != null &&
            DateTime.now().difference(since) >=
                Duration(minutes: settings.lockTimeoutMinutes)) {
          app.lock();
        } else if (app.stage == AuthStage.unlocked) {
          // Back within the idle window, so no passcode — but the world moved
          // while the app was away. An admin may have confirmed a payment, a
          // plan may have matured. Coming back to figures from two minutes ago
          // is how a customer decides the balance is wrong.
          unawaited(app.refreshFromServer());
        }
        _backgroundedAt = null;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppState>().themeMode;

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode.material,
      // Both themes are built above, and each build applies its palette
      // globally as a side effect — so the last one built would win. Pin the
      // palette to whichever theme is actually being painted.
      builder: (context, child) {
        applyPalette(
          Theme.of(context).brightness == Brightness.dark
              ? kDarkPalette
              : kLightPalette,
        );
        return MediaQuery.withNoTextScaling(child: child!);
      },
      home: _booting ? const SplashScreen() : const _Gate(),
    );
  }
}

/// Routes the user to the right root screen for their session state.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final stage = context.select<AppState, AuthStage>((s) => s.stage);

    final child = switch (stage) {
      AuthStage.onboarding => const OnboardingScreen(),
      AuthStage.signedOut => const SignInScreen(),
      AuthStage.locked => const LockScreen(),
      AuthStage.unlocked => const HomeShell(),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (c, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.985, end: 1.0).animate(anim),
          child: c,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(stage), child: child),
    );
  }
}

/// Shared page transition — a soft slide used by every push in the app.
Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 320),
  reverseTransitionDuration: const Duration(milliseconds: 260),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, anim, _, child) => FadeTransition(
    opacity: anim,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.035),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ),
);
