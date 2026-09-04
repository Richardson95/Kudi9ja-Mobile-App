import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../widgets/primitives.dart';
import '../../../legal/legal_screen.dart';
import '../signup_draft.dart';
import 'step_scaffold.dart';

class ReviewStep extends StatefulWidget {
  const ReviewStep({super.key, required this.draft, required this.onNext});

  final SignupDraft draft;
  final VoidCallback onNext;

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;

    return StepScaffold(
      headline: 'Almost there',
      subhead: 'Check everything reads correctly, then open your account.',
      actionLabel: 'Open my account',
      onAction: d.termsAccepted ? widget.onNext : null,
      children: [
        KCard(
          gradient: AppColors.cardGradient,
          borderColor: AppColors.gold.withValues(alpha: 0.2),
          child: Column(
            children: [
              _Line('Full name', d.fullName),
              _Line('Email', d.email),
              _Line('Phone', d.phone),
              _Line('Date of birth', d.dateOfBirth?.asDay ?? '-'),
              _Line('Gender', d.gender),
              _Line('State', d.stateOfResidence),
              _Line('BVN', maskTail(d.bvn)),
              _Line('NIN', maskTail(d.nin), last: true),
            ],
          ),
        ),
        const _SecurityChecklist(),
        _TermsBox(
          accepted: d.termsAccepted,
          onChanged: (v) => setState(() => d.termsAccepted = v),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '-' : value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: HairLine(),
          ),
      ],
    ),
  );
}

class _SecurityChecklist extends StatelessWidget {
  const _SecurityChecklist();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.mark_email_read_outlined, 'Email verified'),
      (Icons.sms_outlined, 'Phone verified'),
      (Icons.verified_user_outlined, 'BVN & NIN confirmed'),
      (Icons.password_rounded, 'Sign-in passcode set'),
      (Icons.pin_outlined, 'Transaction PIN set'),
    ];

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SECURITY SET UP',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (icon, label) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: AppColors.success,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The acceptance box. Each of the three documents is a live link — a
/// customer must be able to read what they are agreeing to before they agree
/// to it, not after.
class _TermsBox extends StatefulWidget {
  const _TermsBox({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  State<_TermsBox> createState() => _TermsBoxState();
}

class _TermsBoxState extends State<_TermsBox> {
  late final Map<String, TapGestureRecognizer> _links = {
    for (final id in const ['terms', 'privacy', 'lending'])
      id: TapGestureRecognizer()
        ..onTap = () => openLegalDocument(context, id),
  };

  @override
  void dispose() {
    for (final r in _links.values) {
      r.dispose();
    }
    super.dispose();
  }

  TextSpan _link(String id, String label) => TextSpan(
    text: label,
    recognizer: _links[id],
    style: const TextStyle(
      color: AppColors.gold,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.gold,
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: () => widget.onChanged(!widget.accepted),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(top: 2),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: widget.accepted ? AppColors.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.accepted
                      ? AppColors.gold
                      : AppColors.surfaceHigh,
                  width: 1.6,
                ),
              ),
              child: widget.accepted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: AppColors.textOnGold,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    const TextSpan(
                      text:
                          'I confirm the details above are mine and I accept '
                          'the ',
                    ),
                    _link('terms', 'Terms of Service'),
                    const TextSpan(text: ', '),
                    _link('privacy', 'Privacy Policy'),
                    const TextSpan(text: ' and '),
                    _link('lending', 'Lending Agreement'),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(left: 34, top: AppSpacing.sm),
        child: Text(
          'Tap any of the three to read it in full before you accept.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
        ),
      ),
    ],
  );
}
