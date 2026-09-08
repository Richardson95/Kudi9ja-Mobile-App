import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/platform_settings.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import 'signup/signup_flow.dart';

/// Shown when there is no active session: welcome, sign in, or create account.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  /// Whether the customer has asked for the sign-in form.
  ///
  /// [AppState.hasAccount] answers a narrower question than it looks: whether
  /// this *device* remembers an account, which is left over from the build that
  /// kept everything on the phone. On a server it is the wrong question — a
  /// customer with a perfectly good account is a stranger to a new phone, a
  /// reinstall, or cleared storage — and asking it turned "I already have an
  /// account" into a dead end that told them no account existed. It exists on
  /// the server; the phone had simply never met it.
  bool _wantsToSignIn = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill for a returning user whose session simply expired.
    final app = context.read<AppState>();
    final u = app.user;
    if (u != null) _email.text = u.email;

    // Wake the server while the customer is typing, so the wait does not land
    // on the button they press.
    unawaited(app.warmUp());
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final ok = await context.read<AppState>().signInWithPassword(
      _email.text,
      _password.text,
    );
    setState(() => _busy = false);
    if (!ok && mounted) {
      showToast(context, 'Email or password is incorrect', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAccount = context.select<AppState, bool>((s) => s.hasAccount);
    // Remembered here, or asked for. Either way the credentials are checked by
    // the server, which is the only thing that ever decides.
    final signingIn = hasAccount || _wantsToSignIn;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                const Center(child: BrandMark(size: 62, halo: true))
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  signingIn ? 'Welcome back' : 'Money that works\nas hard as you do',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  signingIn
                      ? 'Sign in to continue to your dashboard'
                      : 'Save at ${settings.savingsRatePct.toStringAsFixed(0)}% paid upfront. Borrow up to ${settings.maxLoanAmount.asNairaFlat}.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ).animate(delay: 180.ms).fadeIn(),
                const SizedBox(height: AppSpacing.huge),

                if (signingIn) ...[
                  Form(
                    key: _form,
                    child: Column(
                      children: [
                        KField(
                          label: 'Email address',
                          hint: 'you@example.com',
                          controller: _email,
                          prefixIcon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                          autofillHints: const [AutofillHints.email],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        KField(
                          label: 'Password',
                          hint: 'Enter your password',
                          controller: _password,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscure: true,
                          validator: (v) => Validators.required(v, 'Password'),
                        ),
                      ],
                    ),
                  ).animate(delay: 260.ms).fadeIn().slideY(begin: 0.15),
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _showRecovery(context),
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GoldButton(
                    label: 'Sign in',
                    loading: _busy,
                    onPressed: _submit,
                  ).animate(delay: 340.ms).fadeIn().slideY(begin: 0.2),
                  if (!hasAccount) ...[
                    const SizedBox(height: AppSpacing.md),
                    GhostButton(
                      label: 'Create an account instead',
                      onPressed: () => Navigator.of(context)
                          .push(slideRoute(const SignupFlow())),
                    ).animate(delay: 380.ms).fadeIn(),
                  ],
                ] else ...[
                  GoldButton(
                    label: 'Create your account',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () =>
                        Navigator.of(context).push(slideRoute(const SignupFlow())),
                  ).animate(delay: 260.ms).fadeIn().slideY(begin: 0.2),
                  const SizedBox(height: AppSpacing.md),
                  GhostButton(
                    label: 'I already have an account',
                    onPressed: () => setState(() => _wantsToSignIn = true),
                  ).animate(delay: 320.ms).fadeIn(),
                  const SizedBox(height: AppSpacing.huge),
                  const _TrustRow().animate(delay: 400.ms).fadeIn(),
                ],

                const SizedBox(height: AppSpacing.xxl),
                if (hasAccount)
                  Center(
                    child: TextButton(
                      onPressed: () => _confirmReset(context),
                      child: Text(
                        'Use a different account',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRecovery(BuildContext context) {
    final email = context.read<AppState>().user?.email ?? 'your email';
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: Icons.mark_email_read_outlined, size: 52),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Reset your password',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'We will send a secure reset link to $email. The link expires in 15 minutes and can only be used once.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            GoldButton(
              label: 'Send reset link',
              onPressed: () {
                Navigator.pop(context);
                showToast(context, 'Reset link sent to $email');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this account?'),
        content: Text(
          // Two different truths. On a device talking to the server the account
          // survives and the customer can sign back in; without one, the device
          // is the only place it exists and removing it really is final.
          context.read<AppState>().isOnline
              ? 'This signs you out and clears everything Kudi9ja keeps on this '
                  'phone. Your account, savings and history are safe — sign back '
                  'in with your email and password to see them again.'
              : 'This clears the Kudi9ja account stored on this device, '
                  'including its savings plans and history. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AppState>().deleteAccount();
            },
            child: Text(
              'Remove',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.shield_outlined, 'Bank-grade\nencryption'),
      (Icons.fingerprint_rounded, 'Biometric\nsign-in'),
      (Icons.gpp_good_outlined, 'BVN & NIN\nverified'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (icon, label) in items)
          Column(
            children: [
              Icon(icon, size: 22, color: AppColors.gold),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
