import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/platform_settings.dart';
import '../../data/services/security_service.dart';
import '../../state/app_state.dart';
import '../../widgets/passcode.dart';
import '../../widgets/primitives.dart';

/// The gate the user meets every single time they open Kudi9ja.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _code = '';
  bool _error = false;
  bool _checking = false;
  bool _biometricReady = false;

  @override
  void initState() {
    super.initState();
    _maybeOfferBiometrics();
  }

  Future<void> _maybeOfferBiometrics() async {
    if (!context.read<AppState>().biometricsEnabled) return;
    final ready = await SecurityService.isBiometricAvailable;
    if (!mounted) return;
    setState(() => _biometricReady = ready);
    if (ready) _runBiometrics();
  }

  Future<void> _runBiometrics() async {
    final ok = await SecurityService.authenticate('Unlock your Kudi9ja account');
    if (ok && mounted) context.read<AppState>().unlockViaBiometrics();
  }

  void _digit(String d) {
    if (_code.length >= AppConfig.signInPasscodeLength || _checking) return;
    setState(() {
      _code += d;
      _error = false;
    });
    if (_code.length == AppConfig.signInPasscodeLength) _submit();
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    final ok = context.read<AppState>().unlock(_code);
    if (ok) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.vibrate();
    setState(() {
      _error = true;
      _checking = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _code = '';
      _error = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = app.user?.firstName ?? 'there';
    final left = app.attemptsLeft;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const BrandMark(size: 56, halo: true)
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.85, 0.85)),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Hello, $name',
                style: Theme.of(context).textTheme.headlineMedium,
              ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.2),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Enter your 6-digit passcode',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ).animate(delay: 180.ms).fadeIn(),
              const SizedBox(height: AppSpacing.xxl),

              Animate(
                key: ValueKey(_error),
                effects: _error
                    ? [ShakeEffect(duration: 420.ms, hz: 5, offset: const Offset(9, 0))]
                    : const [],
                child: PasscodeDots(
                  length: AppConfig.signInPasscodeLength,
                  filled: _code.length,
                  error: _error,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              AnimatedOpacity(
                opacity: _error && left < settings.maxPasscodeAttempts ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  left <= 2
                      ? 'Wrong passcode. $left ${left == 1 ? 'attempt' : 'attempts'} left before sign-out.'
                      : 'Wrong passcode. Please try again.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(),
              NumericKeypad(
                enabled: !_checking,
                onDigit: _digit,
                onBackspace: () {
                  if (_code.isNotEmpty) {
                    setState(() => _code = _code.substring(0, _code.length - 1));
                  }
                },
                leftAction: _biometricReady ? Icons.fingerprint_rounded : null,
                onLeftAction: _runBiometrics,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => _signOut(context),
                child: Text(
                  'Sign in with password instead',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  void _signOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          'You will need your email and password to get back in.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Stay',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AppState>().signOut();
            },
            child: Text(
              'Sign out',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}
