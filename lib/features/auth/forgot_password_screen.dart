import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../data/api/api_exception.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/passcode.dart';
import '../../widgets/primitives.dart';

/// Resetting a forgotten password with a code sent to the account's email.
///
/// Two steps: ask for the code, then send it back with the new password. The
/// server answers the first step the same way whether or not the email has an
/// account, so this screen never says which it was — that would let anyone
/// check who banks here.
///
/// Pops with the email on success, so sign-in can fill it in.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String _code = '';
  bool _codeSent = false;
  bool _busy = false;

  static const _codeLength = 6;

  @override
  void dispose() {
    _email.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailForm.currentState!.validate()) return;
    final api = context.read<AppState>().api;
    if (api == null) {
      showToast(context, 'Resetting a password needs a connection to Kudi9ja',
          error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await api.forgotPassword(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeSent = true;
      });
      showToast(context, 'If that email has an account, a code is on its way');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, e.message, error: true);
    }
  }

  Future<void> _reset() async {
    if (_code.length != _codeLength) {
      showToast(context, 'Enter the $_codeLength-digit code from your email',
          error: true);
      return;
    }
    if (!_resetForm.currentState!.validate()) return;
    final api = context.read<AppState>().api!;

    setState(() => _busy = true);
    try {
      await api.resetPassword(
        email: _email.text.trim(),
        code: _code,
        newPassword: _next.text,
      );
      if (!mounted) return;
      Navigator.pop(context, _email.text.trim());
      showToast(context, 'Password reset. Sign in with your new password');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // The server tells a wrong or expired code apart from a weak password.
      showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              KCard(
                child: Row(
                  children: [
                    IconBadge(
                      icon: Icons.mark_email_read_outlined,
                      color: AppColors.gold,
                      size: 44,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        _codeSent
                            ? 'Enter the code we sent to ${_email.text.trim()} '
                                'and choose a new password. Every device will '
                                'be signed out.'
                            : 'Enter the email you signed up with and we will '
                                'send you a $_codeLength-digit code.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Form(
                key: _emailForm,
                child: KField(
                  label: 'Email address',
                  hint: 'you@example.com',
                  controller: _email,
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  enabled: !_codeSent,
                  autofillHints: const [AutofillHints.email],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!_codeSent)
                GoldButton(
                  label: 'Send code',
                  loading: _busy,
                  onPressed: _busy ? null : _sendCode,
                )
              else ...[
                OtpBoxes(
                  length: _codeLength,
                  onChanged: (v) => setState(() => _code = v),
                  onCompleted: (v) => setState(() => _code = v),
                ),
                const SizedBox(height: AppSpacing.xl),
                Form(
                  key: _resetForm,
                  child: Column(
                    children: [
                      KField(
                        label: 'New password',
                        hint: 'At least 8 characters',
                        controller: _next,
                        prefixIcon: Icons.lock_rounded,
                        obscure: true,
                        validator: Validators.password,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      KField(
                        label: 'Confirm new password',
                        hint: 'Type it once more',
                        controller: _confirm,
                        prefixIcon: Icons.lock_reset_rounded,
                        obscure: true,
                        validator: (v) =>
                            v != _next.text ? 'Passwords do not match' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                GoldButton(
                  label: 'Reset password',
                  loading: _busy,
                  onPressed: _busy ? null : _reset,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: Text(
                    'Send a new code',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
