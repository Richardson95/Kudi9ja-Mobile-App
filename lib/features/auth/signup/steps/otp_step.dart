import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/security_service.dart';
import '../../../../widgets/passcode.dart';
import '../../../../widgets/primitives.dart';
import '../signup_draft.dart';
import 'step_scaffold.dart';

enum OtpChannel { email, sms }

/// A one-time-code screen used for both the email and the phone check.
class OtpStep extends StatefulWidget {
  const OtpStep({
    super.key,
    required this.channel,
    required this.destination,
    required this.onNext,
    required this.draft,
  });

  final OtpChannel channel;
  final String destination;
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
  int _secondsLeft = 45;
  Timer? _timer;

  bool get _isEmail => widget.channel == OtpChannel.email;

  /// The live destination, read at build time — the draft may have been
  /// edited after this step was first constructed.
  String get _destination =>
      _isEmail ? widget.draft.email : widget.draft.phone;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 45);
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
    final masked = _isEmail ? _maskEmail(_destination) : _maskPhone(_destination);

    return StepScaffold(
      headline: _isEmail ? 'Check your inbox' : 'Check your messages',
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
              style: const TextStyle(
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
                  style: const TextStyle(
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
        const SizedBox(height: AppSpacing.sm),
        // Demo affordance: a real build never reveals the code client-side.
        _DemoCode(code: _issued),
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

  static String _maskPhone(String phone) =>
      phone.length < 8 ? phone : '${phone.substring(0, 4)}****${phone.substring(phone.length - 3)}';
}

class _DemoCode extends StatelessWidget {
  const _DemoCode({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppColors.stroke),
    ),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Text(
            'Demo mode — your code is',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ),
        SelectableText(
          code,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: AppColors.gold,
          ),
        ),
      ],
    ),
  );
}
