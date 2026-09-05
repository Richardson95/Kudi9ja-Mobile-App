import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/platform_settings.dart';
import '../../../../data/services/security_service.dart';
import '../../../../widgets/passcode.dart';
import '../../../../widgets/primitives.dart';
import '../signup_draft.dart';
import 'step_scaffold.dart';

/// The email one-time-code screen.
///
/// Email is the only channel we verify at sign-up. The phone number is
/// collected so support can reach a customer, not as a second factor, so
/// there is no SMS code to wait for.
class OtpStep extends StatefulWidget {
  const OtpStep({super.key, required this.onNext, required this.draft});

  final VoidCallback onNext;
  final SignupDraft draft;

  @override
  State<OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<OtpStep> {
  final _otpKey = GlobalKey<OtpBoxesState>();
  String _issued = SecurityService.issueOtp();
  String _entered = '';
  bool _error = false;
  bool _verifying = false;
  int _secondsLeft = settings.otpResendSeconds;
  Timer? _timer;

  /// Read at build time — the draft may have been edited after this step
  /// was first constructed.
  String get _destination => widget.draft.email;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = settings.otpResendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  void _resend() {
    setState(() {
      _issued = SecurityService.issueOtp();
      _error = false;
    });
    _otpKey.currentState?.clear();
    _startCountdown();
    showToast(context, 'A new code is on its way to $_destination');
  }

  Future<void> _verify() async {
    if (_entered.length != 6) return;
    setState(() => _verifying = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    if (_entered == _issued) {
      HapticFeedback.heavyImpact();
      _timer?.cancel();
      widget.onNext();
      return;
    }

    HapticFeedback.vibrate();
    setState(() {
      _error = true;
      _verifying = false;
    });
    _otpKey.currentState?.clear();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final masked = _maskEmail(_destination);

    return StepScaffold(
      headline: 'Check your inbox',
      subhead:
          'We sent a 6-digit code to $masked. It expires in 10 minutes.',
      actionLabel: 'Verify and continue',
      loading: _verifying,
      onAction: _entered.length == 6 ? _verify : null,
      children: [
        const SizedBox(height: AppSpacing.sm),
        OtpBoxes(
          key: _otpKey,
          error: _error,
          onChanged: (v) => setState(() {
            _entered = v;
            _error = false;
          }),
          onCompleted: (_) => _verify(),
        ),
        if (_error)
          Center(
            child: Text(
              'That code is not correct. Check and try again.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn().shake(hz: 4, offset: const Offset(4, 0)),
          ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: _secondsLeft > 0
              ? Text(
                  'Resend code in ${_secondsLeft}s',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                )
              : TextButton.icon(
                  onPressed: _resend,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Resend code'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                ),
        ),
      ],
    );
  }

  static String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final name = email.substring(0, at);
    final shown = name.length <= 2 ? name : name.substring(0, 2);
    return '$shown${'*' * (name.length - shown.length)}${email.substring(at)}';
  }

}
