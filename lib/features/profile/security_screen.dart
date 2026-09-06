import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_exception.dart';
import '../../data/services/security_service.dart';
import '../../state/app_state.dart';
import '../../widgets/passcode.dart';
import '../../widgets/primitives.dart';
import '../auth/signup/steps/passcode_step.dart';
import 'change_password_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    SecurityService.isBiometricAvailable.then((v) {
      if (mounted) setState(() => _biometricAvailable = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              KCard(
                gradient: AppColors.cardGradient,
                borderColor: AppColors.success.withValues(alpha: 0.25),
                child: Row(
                  children: [
                    IconBadge(
                      icon: Icons.shield_rounded,
                      color: AppColors.success,
                      size: 46,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your account is protected',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Two independent codes guard your money — one to get in, one to move funds.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              _Tile(
                icon: Icons.password_rounded,
                title: 'Sign-in passcode',
                subtitle:
                    '${AppConfig.signInPasscodeLength} digits, required every time you open the app',
                onTap: () => _change(context, PasscodeMode.signIn),
              ),
              const SizedBox(height: AppSpacing.md),
              _Tile(
                icon: Icons.pin_outlined,
                title: 'Transaction PIN',
                subtitle:
                    '${AppConfig.transactionPinLength} digits, required for every transaction',
                onTap: () => _change(context, PasscodeMode.transaction),
              ),
              const SizedBox(height: AppSpacing.md),
              _Tile(
                icon: Icons.lock_reset_rounded,
                title: 'Password',
                subtitle: 'Signs you in on a new phone, and after five wrong passcodes',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              KCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.fingerprint_rounded,
                      size: 22,
                      color: _biometricAvailable
                          ? AppColors.gold
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Biometric unlock',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _biometricAvailable
                                ? 'Use your fingerprint or face instead of typing'
                                : 'Not available on this device',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: app.biometricsEnabled,
                      onChanged: _biometricAvailable
                          ? (v) async {
                              if (v) {
                                final ok = await SecurityService.authenticate(
                                  'Enable biometric unlock',
                                );
                                if (!ok) return;
                              }
                              if (!context.mounted) return;
                              await app.setBiometrics(v);
                              if (!context.mounted) return;
                              showToast(
                                context,
                                v
                                    ? 'Biometric unlock enabled'
                                    : 'Biometric unlock disabled',
                              );
                            }
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
              Text(
                'HOW WE PROTECT YOU',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              KCard(
                child: Column(
                  children: [
                    for (final (icon, text) in const [
                      (
                        Icons.enhanced_encryption_outlined,
                        'Your passcodes are salted and hashed. They are never stored in readable form.',
                      ),
                      (
                        Icons.lock_clock_outlined,
                        'The app locks itself after two minutes in the background.',
                      ),
                      (
                        Icons.block_rounded,
                        'Five wrong passcodes signs you out and requires your full password.',
                      ),
                      (
                        Icons.verified_user_outlined,
                        'BVN and NIN verification ties this account to your real identity.',
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 16, color: AppColors.gold),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Verifies the existing code, then collects a new one.
  Future<void> _change(BuildContext context, PasscodeMode mode) async {
    final app = context.read<AppState>();
    final isSignIn = mode == PasscodeMode.signIn;

    final verified = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _VerifyCurrentScreen(mode: mode),
      ),
    );
    if (verified == null || !context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(
            title: Text(
              isSignIn ? 'New sign-in passcode' : 'New transaction PIN',
            ),
          ),
          body: Container(
            decoration: BoxDecoration(gradient: AppColors.nightGradient),
            child: SafeArea(
              top: false,
              child: PasscodeStep(
                mode: mode,
                embedded: true,
                onDone: (code) async {
                  try {
                    if (isSignIn) {
                      await app.changeSignInPasscode(code, current: verified);
                    } else {
                      await app.changeTransactionPin(code, current: verified);
                    }
                  } on ApiException catch (e) {
                    if (!routeContext.mounted) return;
                    showToast(routeContext, e.message, error: true);
                    return;
                  }
                  if (!routeContext.mounted) return;
                  Navigator.pop(routeContext);
                  showToast(
                    routeContext,
                    isSignIn
                        ? 'Sign-in passcode updated'
                        : 'Transaction PIN updated',
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for the code the user has today before allowing a change.
class _VerifyCurrentScreen extends StatefulWidget {
  const _VerifyCurrentScreen({required this.mode});
  final PasscodeMode mode;

  @override
  State<_VerifyCurrentScreen> createState() => _VerifyCurrentScreenState();
}

class _VerifyCurrentScreenState extends State<_VerifyCurrentScreen> {
  String _code = '';
  bool _error = false;

  bool get _isSignIn => widget.mode == PasscodeMode.signIn;
  int get _length => _isSignIn
      ? AppConfig.signInPasscodeLength
      : AppConfig.transactionPinLength;

  void _digit(String d) {
    if (_code.length >= _length) return;
    setState(() {
      _code += d;
      _error = false;
    });
    if (_code.length == _length) _check();
  }

  Future<void> _check() async {
    final app = context.read<AppState>();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final ok = _isSignIn
        ? await app.verifySignInPasscode(_code)
        : await app.verifyTransactionPin(_code);
    if (!mounted) return;

    if (ok) {
      // The code itself goes back, not just the fact that it was right. The
      // server will not change a passcode without the current one, and asking
      // the customer to type it a second time on the next screen would be
      // asking for something they have just proved.
      Navigator.pop(context, _code);
      return;
    }
    setState(() => _error = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _code = '';
      _error = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm it is you')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              children: [
                const Spacer(),
                Text(
                  _isSignIn
                      ? 'Enter your current passcode'
                      : 'Enter your current PIN',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xxl),
                PasscodeDots(
                  length: _length,
                  filled: _code.length,
                  error: _error,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 20,
                  child: _error
                      ? Text(
                          'That is not correct',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        )
                      : null,
                ),
                const Spacer(),
                NumericKeypad(
                  onDigit: _digit,
                  onBackspace: () {
                    if (_code.isNotEmpty) {
                      setState(
                        () => _code = _code.substring(0, _code.length - 1),
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KCard(
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon, size: 22, color: AppColors.gold),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.textTertiary,
        ),
      ],
    ),
  );
}
