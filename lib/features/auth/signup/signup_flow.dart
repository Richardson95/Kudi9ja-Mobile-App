import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/api/api_exception.dart';
import '../../../data/api/kudi9ja_api.dart';
import '../../../data/legal/legal_documents.dart';
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

  /// Set while a step is being sent, so a second tap cannot submit it twice.
  bool _working = false;

  bool get _online => context.read<AppState>().isOnline;

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

  void _next() => unawaited(_advance());

  /// Submits the step the customer just finished, then moves on.
  ///
  /// Each step is validated by the server as it is completed rather than all at
  /// the end. An email already in use is refused on the screen that asked for
  /// it, instead of after the customer has also typed a BVN, a bank account and
  /// three different codes — and been sent back to the beginning.
  Future<void> _advance() async {
    if (_working) return;

    final api = context.read<AppState>().api;
    if (api != null) {
      setState(() => _working = true);
      final problem = await _submitStep(api, _index);
      if (!mounted) return;
      setState(() => _working = false);

      if (problem != null) {
        showToast(context, problem, error: true);
        return;
      }
    }

    if (_index == _stepCount - 1) {
      unawaited(_finish());
      return;
    }
    setState(() => _index++);
    _pager.animateToPage(
      _index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  /// Sends one step to the server. Returns null, or what to tell the customer.
  ///
  /// The email step is absent: its code is verified inside [OtpStep] itself, so
  /// a wrong code is reported on the keypad rather than as a toast over a
  /// screen that has already moved on.
  Future<String?> _submitStep(Kudi9jaApi api, int index) async {
    try {
      switch (index) {
        case 0:
          final draft = await api.startSignup(
            fullName: _draft.fullName.trim(),
            email: _draft.email.trim().toLowerCase(),
            // Normalised, not as typed. The field accepts spaces and a +234
            // prefix because people write their number every way there is; the
            // server takes one form.
            phone: Validators.normalisePhone(_draft.phone),
            dateOfBirth: _draft.dateOfBirth!,
            gender: _draft.gender,
          );
          _draft.draftId = draft['draftId'] as String?;
          if (_draft.draftId == null) {
            return 'We could not start your application. Please try again.';
          }
        case 1:
          break; // Verified inside OtpStep.
        case 2:
          await api.submitIdentity(
            _draft.draftId!,
            bvn: _draft.bvn,
            nin: _draft.nin,
            address: _draft.address,
            state: _draft.stateOfResidence,
          );
        case 3:
          await api.submitPayout(
            _draft.draftId!,
            bank: _draft.payoutBank,
            accountNumber: _draft.payoutAccountNumber,
          );
        case 4:
          await api.submitPassword(
            _draft.draftId!,
            password: _draft.password,
            securityQuestion: _draft.securityQuestion,
            // The plain answer, not the local hash. The server hashes it with
            // its own pepper, and sending a hash it cannot reproduce would make
            // the answer permanently unverifiable.
            securityAnswer: _draft.securityAnswer.trim(),
          );
        case 5:
          await api.submitPasscode(
            _draft.draftId!,
            passcode: _draft.signInPasscode,
            confirmPasscode: _draft.signInPasscode,
          );
        case 6:
          await api.submitPin(
            _draft.draftId!,
            pin: _draft.transactionPin,
            confirmPin: _draft.transactionPin,
          );
        case 7:
          await api.acceptAgreements(
            _draft.draftId!,
            // Which version was accepted matters as much as the acceptance: the
            // Lending Agreement a customer agreed to is the one that governs
            // their loans.
            acceptedVersions: {
              for (final doc in allLegalDocuments()) doc.id: doc.version,
            },
          );
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
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

    final app = context.read<AppState>();
    final api = app.api;
    if (api != null) {
      try {
        await app.completeSignupFromDraft(api, _draft.draftId!);
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _submitting = false);
        showToast(context, e.message, error: true);
      }
      return;
    }

    // Offline: the account is made on the device, as it was before there was a
    // server.
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

  /// Checks the emailed code with the server.
  ///
  /// Null when the app is offline, which leaves [OtpStep] checking the code it
  /// issued itself — the old behaviour, kept for the tests.
  Future<String?> _verifyEmailCode(String code) {
    final api = context.read<AppState>().api;
    final draftId = _draft.draftId;
    if (api == null || draftId == null) {
      // No draft means no server. Say so rather than letting the customer
      // believe a code was checked when nothing checked it.
      return Future.value('We could not reach Kudi9ja. Please try again.');
    }
    return _run(() => api.verifySignupEmail(draftId, code));
  }

  Future<String?> _resendEmailCode() {
    final api = context.read<AppState>().api;
    final draftId = _draft.draftId;
    if (api == null || draftId == null) {
      return Future.value('We could not reach Kudi9ja. Please try again.');
    }
    return _run(() => api.sendSignupEmail(draftId));
  }

  /// Runs a call and turns a refusal into the message to show.
  static Future<String?> _run(Future<void> Function() call) async {
    try {
      await call();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
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
          decoration: BoxDecoration(gradient: AppColors.nightGradient),
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
                        // Absent offline, which leaves OtpStep checking the
                        // code it issued itself — the old behaviour.
                        onVerify: _online ? _verifyEmailCode : null,
                        onResend: _online ? _resendEmailCode : null,
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
                  shape: CircleBorder(
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
                      style: TextStyle(
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
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
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
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              steps[i],
                              style: TextStyle(
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
