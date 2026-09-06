import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/api/api_exception.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/pin_sheet.dart';
import '../legal/legal_screen.dart';
import 'tenure_slider.dart';
import '../../widgets/primitives.dart';
import '../../widgets/result_screen.dart';
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
  bool _busy = false;

  double get _principal => parseAmount(_amount.text);
  double get _fee => Finance.processingFee(_principal);
  double get _net => _principal - _fee;
  double get _monthly => Finance.loanMonthly(_principal, _tenure);
  double get _total => Finance.loanTotal(_principal, _tenure);

  String? _error(AppState app) {
    if (_principal == 0) return null;
    if (_principal < settings.minLoanAmount) {
      return 'Minimum loan is ${settings.minLoanAmount.asNairaFlat}';
    }
    if (_principal > settings.maxLoanAmount) {
      return 'Maximum loan is ${settings.maxLoanAmount.asNairaFlat}';
    }
    if (_principal > app.eligibleLoanAmount) {
      return 'Your current limit is ${app.eligibleLoanAmount.asNairaFlat}';
    }
    return null;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final pin = await confirmWithPin(
      context,
      title: 'Confirm your loan',
      amountLabel: 'You will receive',
      amount: _net,
      details: [
        ('You requested', _principal.asNaira),
        ('Processing fee', '-${_fee.asNaira}'),
        ('Credited to wallet', _net.asNaira),
        ('Monthly repayment', _monthly.asNaira),
        ('Total repayable', _total.asNaira),
      ],
    );
    if (pin == null || !mounted) return;

    setState(() => _busy = true);
    // Stands in for the underwriting decision.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final Loan loan;
    try {
      loan = await context.read<AppState>().requestLoan(
        principal: _principal,
        months: _tenure,
        purpose: _purpose,
        pin: pin,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // NOT_ELIGIBLE and OFFER_EXCEEDED both come back with the figure the
      // customer can actually borrow, which is the useful part.
      showToast(context, e.message, error: true);
      return;
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Loan approved',
          message:
              '${Finance.netDisbursed(loan.principal).asNaira} is in your wallet — your ${loan.principal.asNaira} loan less the ${loan.processingFee.asNaira} processing fee. Your first repayment is due ${Finance.addMonths(DateTime.now(), 1).asDay}.',
          details: [
            ('Loan amount', loan.principal.asNaira),
            ('Processing fee deducted', '-${loan.processingFee.asNaira}'),
            ('Credited to your wallet', Finance.netDisbursed(loan.principal).asNaira),
            ('Monthly repayment', loan.monthlyRepayment.asNaira),
            ('Total repayable', loan.totalRepayable.asNaira),
            ('Final due date', loan.dueDate.asDay),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final limit = app.eligibleLoanAmount;
    final error = _error(app);
    final canSubmit =
        _principal >= settings.minLoanAmount && error == null && !_busy;

    if (limit < settings.minLoanAmount) {
      return Scaffold(
        appBar: AppBar(title: const Text('Borrow')),
        body: EmptyState(
          icon: Icons.lock_clock_outlined,
          title: 'No headroom right now',
          message:
              'You have reached your ${settings.maxLoanAmount.asShortNaira} limit. Repay an active loan to free up credit.',
          action: SizedBox(
            width: 200,
            child: GhostButton(
              label: 'Go back',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      );
    }

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
                    _LimitCard(app: app).animate().fadeIn().slideY(begin: 0.1),
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
                          if (_principal >= settings.minLoanAmount &&
                              error == null) ...[
                            const SizedBox(height: AppSpacing.md),
                            _NetBanner(
                              fee: _fee,
                              net: _net,
                              principal: _principal,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          QuickAmounts(
                            amounts: [
                              50000,
                              100000,
                              250000,
                              if (limit >= 500000) 500000,
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
                      onChanged: (t) => setState(() => _tenure = t),
                    ),

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
                      fee: _fee,
                      net: _net,
                      monthly: _monthly,
                      total: _total,
                      tenure: _tenure,
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
                      label: _busy
                          ? 'Reviewing...'
                          : (canSubmit
                                ? 'Borrow and receive ${_net.asNairaFlat}'
                                : 'Request loan'),
                      loading: _busy,
                      onPressed: canSubmit ? _submit : null,
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

class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.app});
  final AppState app;

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
            StatusPill(
              label: 'PRE-APPROVED',
              color: AppColors.success,
              icon: Icons.verified_rounded,
              dense: true,
            ),
            const Spacer(),
            Text(
              '${app.creditScore} • ${app.creditBand}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Available to borrow',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          app.eligibleLoanAmount.asNaira,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: LinearProgressIndicator(
            value: app.eligibleLoanAmount / settings.maxLoanAmount,
            minHeight: 5,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation(AppColors.gold),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Of a ${settings.maxLoanAmount.asShortNaira} ceiling. Save more to raise your limit.',
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
    required this.fee,
    required this.net,
    required this.monthly,
    required this.total,
    required this.tenure,
  });

  final double principal;
  final double fee;
  final double net;
  final double monthly;
  final double total;
  final int tenure;

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
                    'Every month',
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
                      monthly.asNaira,
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
                      'For $tenure ${tenure == 1 ? 'month' : 'months'}',
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
                        total.asNaira,
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
          'Processing fee (${Finance.processingFeeBasis(principal).toLowerCase()})',
          '-${fee.asNaira}',
        ),
        _Line('Lands in your wallet', net.asNaira, highlight: true),
        _Line(
          'Interest rate',
          '${settings.loanRateLabelFor(tenure)} flat over '
              '$tenure ${tenure == 1 ? 'month' : 'months'}',
        ),
        _Line('Total interest', (total - principal).asNaira),
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
              'You receive ${net.asNaira}',
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
          '${principal.asNairaFlat} less ${fee.asNairaFlat} processing fee',
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
