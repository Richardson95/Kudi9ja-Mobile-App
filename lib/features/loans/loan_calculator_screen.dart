import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import 'tenure_slider.dart';
import 'loan_request_screen.dart';
import '../../data/models/platform_settings.dart';

/// Model a loan before committing to one — full schedule, no application.
class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _amount = TextEditingController(text: '200,000');
  int _tenure = 6;
  RepaymentFrequency _frequency = RepaymentFrequency.monthly;

  double get _principal => parseAmount(_amount.text);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This customer's own terms — a member of a loan group is priced on the
    // group's.
    final terms = context.watch<AppState>().lendingTerms;
    if (!terms.allows(_frequency) && terms.frequencies.isNotEmpty) {
      _frequency = terms.frequencies.first;
    }
    if (_tenure > terms.maxTenureMonths) _tenure = terms.maxTenureMonths;
    final preview = Finance.loanPreview(
      _principal,
      _tenure,
      frequency: _frequency,
      terms: terms,
    );
    final over = _principal > terms.maxAmount;
    final under = _principal > 0 && _principal < terms.minAmount;

    return Scaffold(
      appBar: AppBar(title: const Text('Loan calculator')),
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
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'If I borrow...',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AmountField(
                            controller: _amount,
                            autofocus: false,
                            onChanged: (_) => setState(() {}),
                          ),
                          if (over || under) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              over
                                  ? 'The ceiling is ${terms.maxAmount.asNairaFlat}'
                                  : 'The minimum loan is ${terms.minAmount.asNairaFlat}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          QuickAmounts(
                            amounts: const [50000, 100000, 250000, 500000],
                            onPick: (a) => setState(
                              () => _amount.text = a.toInt().asPlain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'OVER',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TenureSlider(
                      tenure: _tenure,
                      terms: terms,
                      onChanged: (t) => setState(() => _tenure = t),
                    ),
                    if (terms.frequencies.length > 1) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          for (final f in terms.frequencies) ...[
                            if (f != terms.frequencies.first)
                              const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: KOptionTile(
                                title: f.label,
                                selected: _frequency == f,
                                onTap: () => setState(() => _frequency = f),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    _Headline(preview: preview, tenure: _tenure),
                    const SizedBox(height: AppSpacing.xl),
                    _Breakdown(
                      principal: _principal,
                      preview: preview,
                      tenure: _tenure,
                      terms: terms,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SchedulePreview(preview: preview),
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
                child: GoldButton(
                  label: 'Apply for this loan',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: over || under || _principal <= 0
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                          slideRoute(const LoanRequestScreen()),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.preview, required this.tenure});

  final LoanPreview preview;
  final int tenure;

  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.gold.withValues(alpha: 0.3),
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      children: [
        Text(
          'You repay each ${preview.frequency.unit}',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            preview.each.asNaira,
            key: ValueKey(preview.each),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              color: AppColors.gold,
            ),
          ),
        ),
        Text(
          '${preview.frequency.paymentsPhrase(tenure, count: preview.count)}'
          ' over $tenure ${tenure == 1 ? 'month' : 'months'}',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.lg),
        const HairLine(),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 15,
              color: AppColors.success,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Lands in your wallet (after fee)',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              preview.net.asNaira,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
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
        Text(
          'THE NUMBERS',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Row('Loan amount', principal.asNaira),
        _Row(
          'Management fee (${terms.feeBasisFor(principal).toLowerCase()})',
          '-${preview.fee.asNaira}',
        ),
        _Row('You receive', preview.net.asNaira, color: AppColors.success),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: HairLine(),
        ),
        _Row(
          'Interest rate',
          '${PlatformSettings.ratePct(preview.rate * 100)} flat over '
              '$tenure ${tenure == 1 ? 'month' : 'months'}',
        ),
        _Row('Total interest', preview.interest.asNaira),
        if (preview.fees > 0)
          _Row(
            'Transaction fees (${PlatformSettings.ratePct(preview.feeRate * 100)} of each repayment)',
            preview.fees.asNaira,
          ),
        _Row('Total repayable', preview.total.asNaira, bold: true),
      ],
    ),
  );
}

class _SchedulePreview extends StatelessWidget {
  const _SchedulePreview({required this.preview});

  final LoanPreview preview;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final plan = Finance.instalmentPlan(
      preview.loanTotal,
      preview.count,
      preview.feeRate,
    );

    return KCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR REPAYMENT DATES',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < plan.length; i++) ...[
            if (i > 0) const HairLine(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      preview.frequency.due(now, i + 1).asDay,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    plan[i].total.asNaira,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const HairLine(),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  preview.total.asNaira,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
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

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.color, this.bold = false});
  final String label;
  final String value;
  final Color? color;
  final bool bold;

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
            fontSize: bold ? 14.5 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}
