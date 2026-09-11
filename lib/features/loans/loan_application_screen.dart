import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/loan_application.dart';
import '../../state/app_state.dart';
import '../../widgets/company_account.dart';
import '../../widgets/inputs.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';
import '../../widgets/result_screen.dart';

/// The second half of asking to borrow: the evidence.
///
/// The amount and the tenure were settled on the screen before this one, where
/// the pricing is. What this collects is everything a person needs in order to
/// decide: where the business is and what it takes, a bank statement, three
/// photographs of the premises, and two guarantors in full.
///
/// It is deliberately not a single scroll of thirty fields. Three steps, each
/// of which can be finished in a sitting, and the customer can see how far
/// through they are — an application abandoned halfway is a loan not written.
class LoanApplicationScreen extends StatefulWidget {
  const LoanApplicationScreen({
    super.key,
    required this.principal,
    required this.months,
    required this.purpose,
  });

  final double principal;
  final int months;
  final String purpose;

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  static const _steps = 3;

  int _step = 0;
  bool _busy = false;

  // Step one — the business.
  final _businessName = TextEditingController();
  final _businessAddress = TextEditingController();
  final _income = TextEditingController();

  // Step two — the evidence.
  String _statementPath = '';
  final List<String> _photos = ['', '', ''];

  // Step three — the guarantors.
  final List<_GuarantorFields> _guarantors = [
    _GuarantorFields(),
    _GuarantorFields(),
  ];

  @override
  void dispose() {
    _businessName.dispose();
    _businessAddress.dispose();
    _income.dispose();
    for (final g in _guarantors) {
      g.dispose();
    }
    super.dispose();
  }

  bool get _businessDone =>
      _businessName.text.trim().isNotEmpty &&
      _businessAddress.text.trim().isNotEmpty &&
      parseAmount(_income.text) > 0;

  bool get _evidenceDone =>
      _statementPath.isNotEmpty && _photos.every((p) => p.isNotEmpty);

  bool get _guarantorsDone => _guarantors.every((g) => g.toGuarantor().isComplete);

  bool get _stepDone => switch (_step) {
        0 => _businessDone,
        1 => _evidenceDone,
        _ => _guarantorsDone,
      };

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final pin = await confirmWithPin(
      context,
      title: 'Send your application',
      amountLabel: 'You are asking for',
      amount: widget.principal,
      details: [
        ('Over', '${widget.months} ${widget.months == 1 ? 'month' : 'months'}'),
        ('Purpose', widget.purpose),
        ('Documents attached', '4'),
        ('Guarantors', '2'),
      ],
    );
    if (pin == null || !mounted) return;

    setState(() => _busy = true);

    final LoanApplication application;
    try {
      application = await context.read<AppState>().submitLoanApplication(
            principal: widget.principal,
            months: widget.months,
            purpose: widget.purpose,
            businessName: _businessName.text.trim(),
            businessAddress: _businessAddress.text.trim(),
            monthlyIncome: parseAmount(_income.text),
            guarantors: [for (final g in _guarantors) g.toGuarantor()],
            bankStatementPath: _statementPath,
            businessPhotoPaths: _photos,
            pin: pin,
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, e.message, error: true);
      return;
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Application received',
          // The one thing they must not misread. Nothing has moved.
          message:
              'Your application to borrow ${application.amount.asNaira} is with our team. '
              'We read the statement, the pictures and both guarantors before deciding, '
              'so this is not instant. Nothing has been added to your wallet yet — '
              'we will let you know either way.',
          details: [
            ('You asked for', application.amount.asNaira),
            ('Over', '${application.tenureMonths} months'),
            ('Purpose', application.purpose),
            ('Business', application.businessName),
            ('Status', application.status.label),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_step) {
          0 => 'Your business',
          1 => 'Your documents',
          _ => 'Your guarantors',
        }),
      ),
      body: Column(
        children: [
          _Progress(step: _step, of: _steps),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: switch (_step) {
                0 => _businessStep(),
                1 => _evidenceStep(),
                _ => _guarantorStep(),
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: GhostButton(
                        label: 'Back',
                        onPressed: _busy ? null : () => setState(() => _step--),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    flex: 2,
                    child: GoldButton(
                      label: _step == _steps - 1 ? 'Send application' : 'Continue',
                      loading: _busy,
                      onPressed: !_stepDone || _busy
                          ? null
                          : () {
                              if (_step == _steps - 1) {
                                _submit();
                              } else {
                                setState(() => _step++);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Step one -----------------------------------------------------------

  Widget _businessStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Explainer(
            'Tell us about the business the money is going into. An admin '
            'checks this against the statement and the pictures.',
          ),
          const SizedBox(height: AppSpacing.lg),
          KField(
            label: 'Business name',
            controller: _businessName,
            textCapitalization: TextCapitalization.words,
            prefixIcon: Icons.storefront_outlined,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          KField(
            label: 'Business address',
            controller: _businessAddress,
            textCapitalization: TextCapitalization.words,
            prefixIcon: Icons.location_on_outlined,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          KField(
            label: 'Monthly income',
            controller: _income,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            prefixIcon: Icons.trending_up_rounded,
            helper: 'What the business takes in a typical month, before expenses.',
            onChanged: (_) => setState(() {}),
          ),
        ],
      );

  // -- Step two -----------------------------------------------------------

  Widget _evidenceStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Explainer(
            'A recent bank statement and three pictures of your business. '
            'A clear screenshot of your banking app is fine for the statement.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Bank statement'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 150,
            child: ReceiptPicker(
              path: _statementPath,
              onPicked: (p) => setState(() => _statementPath = p),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Your business premises'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Three pictures: the front, inside, and your stock or equipment.',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < _photos.length; i++) ...[
            SizedBox(
              height: 150,
              child: ReceiptPicker(
                path: _photos[i],
                onPicked: (p) => setState(() => _photos[i] = p),
              ),
            ),
            if (i < _photos.length - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      );

  // -- Step three ---------------------------------------------------------

  Widget _guarantorStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Explainer(
            'Two people who will vouch for you. Tell them you have named them '
            'we may call to check.',
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < _guarantors.length; i++) ...[
            SectionHeader(title: 'Guarantor ${i + 1}'),
            const SizedBox(height: AppSpacing.sm),
            _GuarantorForm(
              fields: _guarantors[i],
              onChanged: () => setState(() {}),
            ),
            if (i < _guarantors.length - 1) const SizedBox(height: AppSpacing.xl),
          ],
        ],
      );
}

/// One guarantor's controllers, kept together so the form stays readable.
class _GuarantorFields {
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final relationship = TextEditingController();
  final bvn = TextEditingController();
  final occupation = TextEditingController();

  Guarantor toGuarantor() => Guarantor(
        fullName: name.text,
        phone: phone.text,
        address: address.text,
        relationship: relationship.text,
        bvn: bvn.text,
        occupation: occupation.text,
      );

  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    relationship.dispose();
    bvn.dispose();
    occupation.dispose();
  }
}

class _GuarantorForm extends StatelessWidget {
  const _GuarantorForm({required this.fields, required this.onChanged});

  final _GuarantorFields fields;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KField(
          label: 'Full name',
          controller: fields.name,
          textCapitalization: TextCapitalization.words,
          prefixIcon: Icons.person_outline,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.md),
        KField(
          label: 'Phone number',
          controller: fields.phone,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          prefixIcon: Icons.phone_outlined,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.md),
        KField(
          label: 'Address',
          controller: fields.address,
          textCapitalization: TextCapitalization.words,
          prefixIcon: Icons.location_on_outlined,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.md),
        KField(
          label: 'What they are to you',
          hint: 'Sister, employer, landlord',
          controller: fields.relationship,
          textCapitalization: TextCapitalization.sentences,
          prefixIcon: Icons.people_outline,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.md),
        KField(
          label: 'BVN',
          controller: fields.bvn,
          keyboardType: TextInputType.number,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          prefixIcon: Icons.badge_outlined,
          // Said plainly, because handing over somebody else's BVN is a
          // reasonable thing to hesitate over.
          helper: 'Recorded with their permission. We do not check it against '
              'their bank.',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.md),
        KField(
          label: 'Occupation (optional)',
          controller: fields.occupation,
          textCapitalization: TextCapitalization.words,
          prefixIcon: Icons.work_outline,
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.of});

  final int step;
  final int of;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < of; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 3,
                decoration: BoxDecoration(
                  color: i <= step ? AppColors.gold : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < of - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
    );
  }
}
