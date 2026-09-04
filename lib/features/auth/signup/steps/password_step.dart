import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../widgets/inputs.dart';
import '../signup_draft.dart';
import 'step_scaffold.dart';

class PasswordStep extends StatefulWidget {
  const PasswordStep({super.key, required this.draft, required this.onNext});

  final SignupDraft draft;
  final VoidCallback onNext;

  @override
  State<PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends State<PasswordStep> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _answer = TextEditingController();
  String _value = '';
  String? _questionError;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _submit() {
    final missingQuestion = widget.draft.securityQuestion.isEmpty;
    setState(
      () => _questionError = missingQuestion ? 'Pick a question' : null,
    );
    if (!_form.currentState!.validate() || missingQuestion) return;

    widget.draft
      ..password = _password.text
      ..securityAnswer = _answer.text;
    widget.onNext();
  }

  void _pickQuestion() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Security question',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final q in kSecurityQuestions)
              ListTile(
                title: Text(q, style: const TextStyle(fontSize: 14.5)),
                trailing: widget.draft.securityQuestion == q
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.gold,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  setState(() {
                    widget.draft.securityQuestion = q;
                    _questionError = null;
                  });
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = Validators.passwordScore(_value);

    return Form(
      key: _form,
      child: StepScaffold(
        headline: 'Create your\npassword',
        subhead:
            'This is your account password — the key you use if you ever sign out completely. Day to day, you will use your passcode instead.',
        actionLabel: 'Continue',
        onAction: _submit,
        children: [
          KField(
            label: 'Password',
            hint: 'At least 8 characters',
            controller: _password,
            prefixIcon: Icons.lock_outline_rounded,
            obscure: true,
            onChanged: (v) => setState(() => _value = v),
            validator: Validators.password,
          ),
          _StrengthMeter(score: score, value: _value),
          KField(
            label: 'Confirm password',
            hint: 'Type it once more',
            controller: _confirm,
            prefixIcon: Icons.lock_reset_rounded,
            obscure: true,
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
          ),
          const Divider(height: AppSpacing.xxl),
          KPickerField(
            label: 'Security question',
            icon: Icons.help_outline_rounded,
            value: widget.draft.securityQuestion.isEmpty
                ? null
                : widget.draft.securityQuestion,
            hint: 'Choose a question',
            onTap: _pickQuestion,
            error: _questionError,
          ),
          KField(
            label: 'Your answer',
            hint: 'Something only you would know',
            controller: _answer,
            prefixIcon: Icons.short_text_rounded,
            validator: (v) => (v == null || v.trim().length < 2)
                ? 'Give a fuller answer'
                : null,
            helper: 'Used to recover your account. Not case sensitive.',
          ),
        ],
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.score, required this.value});

  final int score;
  final String value;

  @override
  Widget build(BuildContext context) {
    const labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong', 'Excellent'];
    const colors = [
      AppColors.danger,
      AppColors.danger,
      AppColors.warning,
      AppColors.gold,
      AppColors.success,
      AppColors.success,
    ];

    final checks = <(String, bool)>[
      ('8+ characters', value.length >= 8),
      ('Upper & lowercase', RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)),
      ('A number', RegExp(r'[0-9]').hasMatch(value)),
      ('A symbol', RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(value)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  height: 4,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i < score ? colors[score] : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 72,
              child: Text(
                value.isEmpty ? '' : labels[score],
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: colors[score],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: 6,
          children: [
            for (final (label, ok) in checks)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ok ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 13,
                    color: ok ? AppColors.success : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: ok ? AppColors.textSecondary : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
