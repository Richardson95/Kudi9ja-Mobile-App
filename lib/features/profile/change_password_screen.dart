import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../data/api/api_exception.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';

/// Changing the account password.
///
/// The password is the credential that gets a customer back in on a new phone,
/// which makes it the one worth changing after a scare — and the first thing an
/// attacker changes if they can. So the current one is required, and it is the
/// server that checks it: a device deciding for itself whether the old password
/// was right is a device that can be told to say yes.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      await context.read<AppState>().changePassword(
            current: _current.text,
            next: _next.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      showToast(context, 'Password updated');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // The server's own words. It tells a wrong current password apart from a
      // new one that is too weak, and those ask different things of a customer.
      showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                KCard(
                  child: Row(
                    children: [
                      IconBadge(
                        icon: Icons.lock_reset_rounded,
                        color: AppColors.gold,
                        size: 44,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Text(
                          'Your password is what signs you in on a new phone. '
                          'Changing it will not sign you out here.',
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

                KField(
                  label: 'Current password',
                  hint: 'The one you sign in with today',
                  controller: _current,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscure: true,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
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
                const SizedBox(height: AppSpacing.xl),

                GoldButton(
                  label: 'Update password',
                  loading: _busy,
                  onPressed: _busy ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
