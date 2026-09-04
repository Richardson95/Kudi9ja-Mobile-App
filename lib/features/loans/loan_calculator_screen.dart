import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
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

  double get _principal => parseAmount(_amount.text);
  double get _fee => Finance.processingFee(_principal);
  double get _net => _principal - _fee;
  double get _monthly => Finance.loanMonthly(_principal, _tenure);
  double get _total => Finance.loanTotal(_principal, _tenure);
  double get _interest => _total - _principal;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final over = _principal > settings.maxLoanAmount;
    final under =
        _principal > 0 && _principal < settings.minLoanAmount;

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
                                  ? 'The ceiling is ${settings.maxLoanAmount.asNairaFlat}'
                                  : 'The minimum loan is ${settings.minLoanAmount.asNairaFlat}',
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
                      onChanged: (t) => setState(() => _tenure = t),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _Headline(monthly: _monthly, tenure: _tenure, net: _net),
                    const SizedBox(height: AppSpacing.xl),
                    _Breakdown(
                      principal: _principal,
                      fee: _fee,
                      net: _net,
                      interest: _interest,
                      total: _total,
                      tenure: _tenure,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SchedulePreview(
                      monthly: _monthly,
                      tenure: _tenure,
                      total: _total,
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
  const _Headline({
    required this.monthly,
    required this.tenure,
    required this.net,
  });

  final double monthly;
  final int tenure;
  final double net;

  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.gold.withValues(alpha: 0.3),
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      children: [
        Text(
          'You repay each month',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            monthly.asNaira,
            key: ValueKey(monthly),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              color: AppColors.gold,
            ),
          ),
        ),
        Text(
          'for $tenure ${tenure == 1 ? 'month' : 'months'}',
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
              net.asNaira,
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
    required this.fee,
    required this.net,
    required this.interest,
    required this.total,
    required this.tenure,
  });

  final double principal;
  final double fee;
  final double net;
  final double interest;
  final double total;
  final int tenure;

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
          'Processing fee (${Finance.processingFeeBasis(principal).toLowerCase()})',
          '-${fee.asNaira}',
        ),
        _Row('You receive', net.asNaira, color: AppColors.success),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: HairLine(),
        ),
        _Row(
          'Interest rate',
          '${settings.loanRateLabelFor(tenure)} flat over '
              '$tenure ${tenure == 1 ? 'month' : 'months'}',
        ),
        _Row('Total interest', interest.asNaira),
        _Row('Total repayable', total.asNaira, bold: true),
      ],
    ),
  );
}

class _SchedulePreview extends StatelessWidget {
  const _SchedulePreview({
    required this.monthly,
    required this.tenure,
    required this.total,
  });

  final double monthly;
  final int tenure;
  final double total;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

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
          for (var i = 0; i < tenure; i++) ...[
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
                      Finance.addMonths(now, i + 1).asDay,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    monthly.asNaira,
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
                  total.asNaira,
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
