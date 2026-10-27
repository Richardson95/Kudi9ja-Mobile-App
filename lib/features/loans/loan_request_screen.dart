import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../legal/legal_screen.dart';
import 'loan_application_screen.dart';
import 'tenure_slider.dart';
import '../../widgets/primitives.dart';
import '../../data/models/platform_settings.dart';

const _purposes = <(IconData, String)>[
  (Icons.storefront_outlined, 'Business'),
  (Icons.school_outlined, 'Education'),
  (Icons.medical_services_outlined, 'Medical'),
  (Icons.home_work_outlined, 'Rent'),
  (Icons.directions_car_outlined, 'Vehicle'),
  (Icons.more_horiz_rounded, 'Personal'),
];

class LoanRequestScreen extends StatefulWidget {
  const LoanRequestScreen({super.key});

  @override
  State<LoanRequestScreen> createState() => _LoanRequestScreenState();
}

class _LoanRequestScreenState extends State<LoanRequestScreen> {
  final _amount = TextEditingController();
  int _tenure = 3;
  String _purpose = 'Business';

  /// Weekly or monthly. Has to be chosen; the server refuses an application
  /// that does not say.
  RepaymentFrequency? _frequency;

  double get _principal => parseAmount(_amount.text);

  /// What this customer borrows on — the loan-group terms for a member of a
  /// group — and the loan priced on them.
  LendingTerms _terms(AppState app) => app.lendingTerms;

  RepaymentFrequency _chosen(AppState app) {
    final offered = _terms(app).frequencies;
    final f = _frequency;
    if (f != null && offered.contains(f)) return f;
    return offered.isEmpty ? RepaymentFrequency.monthly : offered.first;
  }

  LoanPreview _preview(AppState app) => Finance.loanPreview(
    _principal,
    _tenure,
    frequency: _chosen(app),
    terms: _terms(app),
  );

  String? _error(AppState app) {
    final t = _terms(app);
    if (_principal == 0) return null;
    if (_principal < t.minAmount) {
      return 'Minimum loan is ${t.minAmount.asNairaFlat}';
    }
    if (_principal > t.maxAmount) {
      return 'Maximum loan is ${t.maxAmount.asNairaFlat}';
    }
    return null;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// Moves on to the evidence, rather than to a disbursement.
  ///
  /// This used to confirm with a PIN and come back with money in the wallet.
  /// It cannot any more: the amount and the tenure are only half of what the
  /// decision rests on, and the other half — the statement, the business, the
  /// guarantors — is collected on the screen after this one and read by a
  /// person before anything moves.
  void _continue() {
    FocusScope.of(context).unfocus();
    final app = context.read<AppState>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoanApplicationScreen(
          principal: _principal,
          months: _tenure,
          frequency: _chosen(app),
          purpose: _purpose,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final terms = _terms(app);
    final error = _error(app);
    final canSubmit = _principal >= terms.minAmount && error == null;
    final preview = _preview(app);
    final frequency = _chosen(app);
    if (_tenure > terms.maxTenureMonths) _tenure = terms.maxTenureMonths;

    return Scaffold(
      appBar: AppBar(title: const Text('Request a loan')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  children: [
                    _RangeCard(terms: terms, group: app.groupPricing)
                        .animate()
                        .fadeIn()
                        .slideY(begin: 0.1),
                    const SizedBox(height: AppSpacing.xxl),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'How much do you need?',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AmountField(
                            controller: _amount,
                            onChanged: (_) => setState(() {}),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              error,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                          if (_principal >= terms.minAmount &&
                              error == null) ...[
                            const SizedBox(height: AppSpacing.md),
                            _NetBanner(
                              fee: preview.fee,
                              net: preview.net,
                              principal: _principal,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          QuickAmounts(
                            amounts: [
                              50000,
                              100000,
                              250000,
                              500000,
                              1000000,
                            ],
                            onPick: (a) => setState(
                              () => _amount.text = a.toInt().asPlain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    const _Label('REPAYMENT PERIOD'),
                    const SizedBox(height: AppSpacing.md),
                    TenureSlider(
                      tenure: _tenure,
                      terms: terms,
                      onChanged: (t) => setState(() => _tenure = t),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    const _Label('HOW WILL YOU REPAY?'),
                    const SizedBox(height: AppSpacing.md),
                    for (final f in terms.frequencies) ...[
                      KOptionTile(
                        title: f.label,
                        subtitle: _principal > 0
                            ? '${f.paymentsPhrase(_tenure)} of about '
                                  '${Finance.loanPreview(_principal, _tenure, frequency: f, terms: terms).each.asNaira}'
                            : f.paymentsPhrase(_tenure),
                        icon: f == RepaymentFrequency.weekly
                            ? Icons.view_week_outlined
                            : Icons.calendar_month_outlined,
                        selected: frequency == f,
                        onTap: () => setState(() => _frequency = f),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    const _Label('WHAT IS IT FOR?'),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final (icon, name) in _purposes)
                          _Chip(
                            label: name,
                            icon: icon,
                            selected: _purpose == name,
                            onTap: () => setState(() => _purpose = name),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    _Breakdown(
                      principal: _principal,
                      preview: preview,
                      tenure: _tenure,
                      terms: terms,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  border: Border(top: BorderSide(color: AppColors.stroke)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => openLegalDocument(context, 'lending'),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Confirming this loan accepts the ',
                              ),
                              TextSpan(
                                text: 'Lending Agreement',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.gold,
                                ),
                              ),
                              TextSpan(text: ' — read it first.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    GoldButton(
                      // Not "Borrow and receive X" any more: this button no
                      // longer produces money, it moves on to the documents.
                      // A label that promises a disbursement two screens before
                      // a person has read the file is the cruellest kind of
                      // wrong.
                      label: 'Continue to your documents',
                      onPressed: canSubmit ? _continue : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The range a customer may ask within, and who decides.
///
/// This was a "pre-approved" card with a limit worked out from a score and
/// savings, and a progress bar towards the ceiling. There is no such limit:
/// a customer asks for what they need and a person reads the application.
/// Saying "pre-approved" over a figure the customer had not asked for was
/// also a promise nobody had made.
class _RangeCard extends StatelessWidget {
  const _RangeCard({required this.terms, required this.group});

  final LendingTerms terms;
  final bool group;

  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.gold.withValues(alpha: 0.24),
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Borrow from',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
            if (group)
              StatusPill(label: 'LOAN GROUP TERMS', color: AppColors.info, dense: true),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${terms.minAmount.asNairaFlat} to ${terms.maxAmount.asShortNaira}',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Ask for what your business needs. Our team reads your bank '
          'statement, your business and your guarantor, and decides.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
        ),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
      color: AppColors.textTertiary,
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.goldWash : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.stroke,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: selected ? AppColors.gold : AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.gold : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.principal,
    required this.preview,
    required this.tenure,
    required this.terms,
  });

  final double principal;
  final LoanPreview preview;
  final int tenure;
  final LendingTerms terms;

  @override
  Widget build(BuildContext context) => KCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('YOUR REPAYMENT PLAN'),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Every ${preview.frequency.unit}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      preview.each.asNaira,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 38, color: AppColors.stroke),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In ${preview.frequency.paymentsPhrase(tenure, count: preview.count)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        preview.total.asNaira,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const HairLine(),
        const SizedBox(height: AppSpacing.md),
        _Line('Loan amount', principal.asNaira),
        _Line(
          'Management fee (${terms.feeBasisFor(principal).toLowerCase()})',
          '-${preview.fee.asNaira}',
        ),
        _Line('Lands in your wallet if approved', preview.net.asNaira, highlight: true),
        _Line(
          'Interest rate',
          '${PlatformSettings.ratePct(preview.rate * 100)} flat over '
              '$tenure ${tenure == 1 ? 'month' : 'months'}',
        ),
        _Line('Total interest', preview.interest.asNaira),
        if (preview.fees > 0) ...[
          _Line(
            'Each ${preview.frequency.unit}',
            '${preview.base.asNaira} + ${preview.instalmentFee.asNaira} fee',
          ),
          _Line(
            'Transaction fees (${PlatformSettings.ratePct(preview.feeRate * 100)} of each repayment)',
            preview.fees.asNaira,
          ),
        ],
        _Line('Total to repay', preview.total.asNaira),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}


/// Sits under the amount field so the deduction is never a surprise at
/// the confirmation step.
class _NetBanner extends StatelessWidget {
  const _NetBanner({
    required this.fee,
    required this.net,
    required this.principal,
  });

  final double fee;
  final double net;
  final double principal;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    decoration: BoxDecoration(
      color: AppColors.successWash,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.success.withValues(alpha: 0.28)),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 15,
              color: AppColors.success,
            ),
            const SizedBox(width: 7),
            Text(
              'If approved, you receive ${net.asNaira}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${principal.asNairaFlat} less ${fee.asNairaFlat} management fee',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
