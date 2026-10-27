import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/legal/legal_documents.dart';
import '../../../../state/app_state.dart';
import '../../../../widgets/inputs.dart';
import '../../../../widgets/primitives.dart';
import '../../../../widgets/signature_pad.dart';
import '../../../legal/legal_screen.dart';
import '../signup_draft.dart';
import 'step_scaffold.dart';

class ReviewStep extends StatefulWidget {
  const ReviewStep({
    super.key,
    required this.draft,
    required this.onNext,
    this.busy = false,
  });

  final SignupDraft draft;
  final VoidCallback onNext;

  /// Whether this step is being submitted to the server.
  ///
  /// A button that looks idle while a request is in flight reads as a
  /// button that did not work, and the customer taps it again.
  final bool busy;

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  final _pad = SignaturePadController();
  late final _typed = TextEditingController(text: widget.draft.typedName);
  bool _signing = false;

  @override
  void initState() {
    super.initState();
    _pad.addListener(_changed);
    // The documents in force, from the server, so the versions accepted are
    // the ones it holds — a bundled copy can be a version behind.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().loadLegalDocuments();
    });
  }

  @override
  void dispose() {
    _pad
      ..removeListener(_changed)
      ..dispose();
    _typed.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  bool get _nameOk => Validators.sameName(_typed.text, widget.draft.fullName);

  bool get _ready =>
      widget.draft.termsAccepted &&
      _nameOk &&
      !_pad.isEmpty &&
      widget.draft.signatureConsent;

  /// Turns the drawing into the image the server keeps, then opens the
  /// account.
  Future<void> _sign() async {
    if (_signing) return;
    setState(() => _signing = true);
    final image = await _pad.toPngDataUrl();
    if (!mounted) return;
    setState(() => _signing = false);
    if (image == null) {
      showToast(context, 'Draw your signature first.', error: true);
      return;
    }
    widget.draft
      ..typedName = _typed.text.trim()
      ..signatureImage = image;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    // Rebuilt when the server's copies of the documents arrive.
    context.watch<AppState>();

    return StepScaffold(
        loading: widget.busy || _signing,
      headline: 'Read, agree and sign',
      subhead: 'Check your details, accept the agreements and sign. '
          'They are between you and ${AppConfig.legalEntity} '
          '(${AppConfig.rcNumber}).',
      actionLabel: 'Sign and open my account',
      onAction: _ready ? _sign : null,
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
              _Line('NIN', maskTail(d.nin)),
              _Line('Payout bank', d.payoutBank),
              _Line('Payout account', d.payoutAccountNumber, last: true),
            ],
          ),
        ),
        const _SecurityChecklist(),
        const _Agreements(),
        _TermsBox(
          accepted: d.termsAccepted,
          onChanged: (v) => setState(() => d.termsAccepted = v),
        ),
        _SignatureCard(
          draft: d,
          pad: _pad,
          typed: _typed,
          nameOk: _nameOk,
          onChanged: () => setState(() {}),
        ),
        if (!_ready)
          _Checklist(
            items: [
              (d.termsAccepted, 'Accept the three agreements'),
              (_nameOk, 'Type your full name exactly as on your account'),
              (!_pad.isEmpty, 'Draw your signature'),
              (d.signatureConsent, 'Agree to sign electronically'),
            ],
          ),
      ],
    );
  }
}

/// The three documents, each with the version being accepted.
class _Agreements extends StatelessWidget {
  const _Agreements();

  @override
  Widget build(BuildContext context) {
    final docs = allLegalDocuments();
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE AGREEMENTS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final doc in docs)
            InkWell(
              onTap: () => openLegalDocument(context, doc.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 18, color: AppColors.gold),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Version ${doc.version} · ${doc.readMinutes} min read',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Read',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.gold),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The typed name, the drawn signature, and the consent that makes it one.
class _SignatureCard extends StatelessWidget {
  const _SignatureCard({
    required this.draft,
    required this.pad,
    required this.typed,
    required this.nameOk,
    required this.onChanged,
  });

  final SignupDraft draft;
  final SignaturePadController pad;
  final TextEditingController typed;
  final bool nameOk;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final mismatch = typed.text.trim().isNotEmpty && !nameOk;
    final done = nameOk && !pad.isEmpty && draft.signatureConsent;
    return KCard(
      borderColor: (done ? AppColors.success : AppColors.gold).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.draw_rounded, size: 18, color: AppColors.gold),
              const SizedBox(width: AppSpacing.sm),
              Text('Your signature', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          KField(
            label: 'Type your full legal name',
            hint: draft.fullName,
            controller: typed,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => onChanged(),
            helper: mismatch
                ? 'This has to match the name on your account: ${draft.fullName}'
                : nameOk
                ? 'Matches your account.'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Draw your signature',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SignaturePad(controller: pad),
          const SizedBox(height: AppSpacing.sm),
          _Line('Signing as', draft.fullName),
          _Line('Email', draft.email),
          _Line('Date', DateTime.now().asDay, last: true),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              draft.signatureConsent = !draft.signatureConsent;
              onChanged();
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Tick(on: draft.signatureConsent),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'I agree that my electronic signature above is the legal '
                    'equivalent of my handwritten signature, and that '
                    '${AppConfig.legalEntity} may keep a record of this '
                    'agreement — the version of each document, the date, the '
                    'time and this device — as evidence of it under section 93 '
                    'of the Evidence Act 2011.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What is still missing before the account can be opened.
class _Checklist extends StatelessWidget {
  const _Checklist({required this.items});
  final List<(bool, String)> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (ok, label) in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: ok ? AppColors.success : AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: ok ? AppColors.success : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _Tick extends StatelessWidget {
  const _Tick({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    margin: const EdgeInsets.only(top: 2),
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: on ? AppColors.gold : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: on ? AppColors.gold : AppColors.surfaceHigh,
        width: 1.6,
      ),
    ),
    child: on
        ? Icon(Icons.check_rounded, size: 15, color: AppColors.textOnGold)
        : null,
  );
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
                style: TextStyle(
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
      (Icons.verified_user_outlined, 'BVN & NIN confirmed'),
      (Icons.account_balance_outlined, 'Payout account set'),
      (Icons.password_rounded, 'Sign-in passcode set'),
      (Icons.pin_outlined, 'Transaction PIN set'),
    ];

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
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
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
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
    style: TextStyle(
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
                  ? Icon(
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
                  style: TextStyle(
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
      Padding(
        padding: EdgeInsets.only(left: 34, top: AppSpacing.sm),
        child: Text(
          'Tap any of the three to read it in full before you accept.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
        ),
      ),
    ],
  );
}
