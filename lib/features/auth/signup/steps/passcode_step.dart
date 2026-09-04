import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../widgets/passcode.dart';

enum PasscodeMode { signIn, transaction }

/// Sets a passcode with a mandatory confirmation pass. Used twice in signup
/// and again from settings.
class PasscodeStep extends StatefulWidget {
  const PasscodeStep({
    super.key,
    required this.mode,
    required this.onDone,
    this.embedded = false,
  });

  final PasscodeMode mode;
  final ValueChanged<String> onDone;

  /// When true the widget renders its own headline padding for use outside
  /// the signup wizard.
  final bool embedded;

  @override
  State<PasscodeStep> createState() => _PasscodeStepState();
}

class _PasscodeStepState extends State<PasscodeStep> {
  String _first = '';
  String _current = '';
  bool _confirming = false;
  bool _error = false;
  String? _message;

  bool get _isSignIn => widget.mode == PasscodeMode.signIn;
  int get _length => _isSignIn
      ? AppConfig.signInPasscodeLength
      : AppConfig.transactionPinLength;

  void _digit(String d) {
    if (_current.length >= _length) return;
    setState(() {
      _current += d;
      _error = false;
      _message = null;
    });
    if (_current.length == _length) _evaluate();
  }

  Future<void> _evaluate() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    if (!_confirming) {
      final weak = Validators.passcodeStrength(_current);
      if (weak != null) {
        _fail(weak);
        return;
      }
      setState(() {
        _first = _current;
        _current = '';
        _confirming = true;
      });
      HapticFeedback.selectionClick();
      return;
    }

    if (_current == _first) {
      HapticFeedback.heavyImpact();
      widget.onDone(_current);
      return;
    }
    _fail('Those did not match. Start again.');
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _first = '';
    });
  }

  void _fail(String message) {
    HapticFeedback.vibrate();
    setState(() {
      _error = true;
      _message = message;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _current = '';
        _error = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final headline = _isSignIn
        ? (_confirming ? 'Confirm your\npasscode' : 'Create your\nsign-in passcode')
        : (_confirming ? 'Confirm your\ntransaction PIN' : 'Create your\ntransaction PIN');

    final subhead = _isSignIn
        ? 'You will type this every time you open Kudi9ja. Six digits, no repeats, no straight runs.'
        : 'A separate four-digit PIN that authorises every transfer, saving and repayment.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          if (widget.embedded) const SizedBox(height: AppSpacing.lg),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.12),
          const SizedBox(height: AppSpacing.md),
          Text(
            _confirming ? 'Enter it once more to be sure.' : subhead,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const Spacer(),
          Animate(
            key: ValueKey('$_error$_confirming'),
            effects: _error
                ? [ShakeEffect(duration: 420.ms, hz: 5, offset: const Offset(9, 0))]
                : const [],
            child: PasscodeDots(
              length: _length,
              filled: _current.length,
              error: _error,
              size: _isSignIn ? 15 : 17,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 34,
            child: AnimatedOpacity(
              opacity: _message == null ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: Text(
                _message ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),
          const Spacer(),
          NumericKeypad(
            onDigit: _digit,
            onBackspace: () {
              if (_current.isNotEmpty) {
                setState(
                  () => _current = _current.substring(0, _current.length - 1),
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
