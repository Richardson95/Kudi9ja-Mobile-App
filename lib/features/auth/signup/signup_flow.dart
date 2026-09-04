import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/security_service.dart';
import '../../../state/app_state.dart';
import '../../../widgets/primitives.dart';
import 'signup_draft.dart';
import 'steps/identity_step.dart';
import 'steps/otp_step.dart';
import 'steps/passcode_step.dart';
import 'steps/payout_step.dart';
import 'steps/password_step.dart';
import 'steps/personal_step.dart';
import 'steps/review_step.dart';

/// The full account-opening journey. Each screen must pass before the next
/// unlocks.
///
/// Only the email address is verified with a one-time code — there is no SMS
/// step. The phone number is collected so we can reach a customer, not as a
/// second factor.
class SignupFlow extends StatefulWidget {
  const SignupFlow({super.key});

  @override
  State<SignupFlow> createState() => _SignupFlowState();
}

class _SignupFlowState extends State<SignupFlow> {
  final _draft = SignupDraft();
  final _pager = PageController();
  int _index = 0;
  bool _submitting = false;

  static const _titles = [
    'Your details',
    'Verify email',
    'Identity check',
    'Payout account',
    'Secure your account',
    'Sign-in passcode',
    'Transaction PIN',
    'Review',
  ];

  int get _stepCount => _titles.length;

  void _next() {
    if (_index == _stepCount - 1) {
      _finish();
      return;
    }
    setState(() => _index++);
    _pager.animateToPage(
      _index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index--);
    _pager.animateToPage(
      _index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    // Simulates the account-opening call to the Kudi9ja core banking service.
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    final user = AppUser(
      id: const Uuid().v4(),
      fullName: _draft.fullName.trim(),
      email: _draft.email.trim().toLowerCase(),
      phone: _draft.phone.trim(),
      dateOfBirth: _draft.dateOfBirth!,
      gender: _draft.gender,
      bvn: _draft.bvn,
      nin: _draft.nin,
      address: _draft.address,
      state: _draft.stateOfResidence,
      payoutBank: _draft.payoutBank,
      payoutAccountNumber: _draft.payoutAccountNumber,
      createdAt: DateTime.now(),
      // Only the email is verified at sign-up; there is no SMS check.
      phoneVerified: false,
      securityQuestion: _draft.securityQuestion,
      securityAnswer: SecurityService.hash(
        _draft.securityAnswer.trim().toLowerCase(),
      ),
    );

    await context.read<AppState>().createAccount(
      user: user,
      password: _draft.password,
      signInPasscode: _draft.signInPasscode,
      transactionPin: _draft.transactionPin,
    );

    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitting) return const _CreatingAccount();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.nightGradient),
          child: SafeArea(
            child: Column(
              children: [
                _Header(
                  index: _index,
                  total: _stepCount,
                  title: _titles[_index],
                  onBack: _back,
                ),
                Expanded(
                  child: PageView(
                    controller: _pager,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      PersonalStep(draft: _draft, onNext: _next),
                      OtpStep(
                        key: const ValueKey('email-otp'),
                        onNext: () {
                          _draft.emailVerified = true;
                          _next();
                        },
                        draft: _draft,
                      ),
                      IdentityStep(draft: _draft, onNext: _next),
                      PayoutStep(draft: _draft, onNext: _next),
                      PasswordStep(draft: _draft, onNext: _next),
                      PasscodeStep(
                        key: const ValueKey('signin-passcode'),
                        mode: PasscodeMode.signIn,
                        onDone: (code) {
                          _draft.signInPasscode = code;
                          _next();
                        },
                      ),
                      PasscodeStep(
                        key: const ValueKey('txn-pin'),
                        mode: PasscodeMode.transaction,
                        onDone: (code) {
                          _draft.transactionPin = code;
                          _next();
                        },
                      ),
                      ReviewStep(draft: _draft, onNext: _next),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.index,
    required this.total,
    required this.title,
    required this.onBack,
  });

  final int index;
  final int total;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.stroke),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${index + 1} of $total',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const BrandMark(size: 30),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: List.generate(total, (i) {
              final done = i <= index;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOut,
                  height: 3.5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    gradient: done ? AppColors.goldGradient : null,
                    color: done ? null : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CreatingAccount extends StatelessWidget {
  const _CreatingAccount();

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Validating your identity',
      'Opening your wallet',
      'Encrypting your passcodes',
      'Activating your account',
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: const BrandMark(size: 64, halo: true)
                      .animate(onPlay: (c) => c.repeat())
                      .rotate(duration: 2400.ms, curve: Curves.easeInOut),
                ),
                const SizedBox(height: AppSpacing.huge),
                Center(
                  child: Text(
                    'Setting up your account',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child:
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              steps[i],
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ).animate(delay: (250 * i).ms).fadeIn().slideX(
                          begin: -0.1,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
