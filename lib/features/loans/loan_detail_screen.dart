import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/models/platform_settings.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';
import '../../widgets/result_screen.dart';
import '../wallet/pay_in_screen.dart';

/// A loan, its full amortisation schedule, and every way to settle it.
class LoanDetailScreen extends StatelessWidget {
  const LoanDetailScreen({super.key, required this.loanId});
  final String loanId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    Loan? found;
    for (final l in app.loans) {
      if (l.id == loanId) found = l;
    }
    if (found == null) return const Scaffold(body: SizedBox.shrink());

    final loan = found;
    final schedule = loan.schedule;
    final rebate = Finance.earlyPayoffRebate(loan);

    return Scaffold(
      appBar: AppBar(title: Text('${loan.purpose} loan')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _Hero(loan: loan),
              const SizedBox(height: AppSpacing.xl),

              if (loan.isOpen) ...[
                if (rebate > 0)
                  _RebateBanner(
                    rebate: rebate,
                    payoff: Finance.earlyPayoffAmount(loan),
                    onTap: () => _payOffEarly(context, loan),
                  ),
                if (rebate > 0) const SizedBox(height: AppSpacing.md),
                GoldButton(
                  label: 'Repay by bank transfer',
                  icon: Icons.receipt_long_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PayInScreen(
                        loan: loan,
                        presetAmount: loan.monthlyRepayment,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const _TransferNote(),
                const SizedBox(height: AppSpacing.lg),
                const _OrDivider(),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: GhostButton(
                        label: 'Custom amount',
                        onPressed: () => _customRepay(context, loan),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: GhostButton(
                        label: 'Pay ${loan.monthlyRepayment.asShortNaira}',
                        onPressed: () =>
                            _repay(context, loan, loan.monthlyRepayment),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const _AutoDebitRow(),
                const SizedBox(height: AppSpacing.xl),
              ],

              const _Label('REPAYMENT SCHEDULE'),
              const SizedBox(height: AppSpacing.md),
              KCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < schedule.length; i++) ...[
                      if (i > 0) const HairLine(indent: 44),
                      _InstallmentRow(item: schedule[i])
                          .animate(delay: (30 * i).ms)
                          .fadeIn(),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              const _Label('LOAN TERMS'),
              const SizedBox(height: AppSpacing.md),
              KCard(
                child: Column(
                  children: [
                    _Line('Principal', loan.principal.asNaira),
                    const _Sep(),
                    _Line(
                      'Interest rate',
                      '${PlatformSettings.ratePct(loan.flatRate * 100)} flat on the '
                      'amount borrowed',
                    ),
                    const _Sep(),
                    _Line('Total interest', loan.totalInterest.asNaira),
                    const _Sep(),
                    _Line(
                      'Processing fee',
                      '-${loan.processingFee.asNaira}',
                    ),
                    const _Sep(),
                    _Line(
                      'Credited to wallet',
                      Finance.netDisbursed(loan.principal).asNaira,
                    ),
                    const _Sep(),
                    _Line('Total repayable', loan.totalRepayable.asNaira),
                    const _Sep(),
                    _Line('Monthly instalment', loan.monthlyRepayment.asNaira),
                    const _Sep(),
                    _Line('Disbursed', loan.disbursedAt.asDay),
                    const _Sep(),
                    _Line('Final due date', loan.dueDate.asDay),
                    const _Sep(),
                    _Line('Status', loan.status.label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _repay(BuildContext context, Loan loan, double amount) async {
    final app = context.read<AppState>();
    final due = amount > loan.outstanding ? loan.outstanding : amount;

    if (due > app.balance) {
      showToast(
        context,
        'You need ${due.asNaira} in your wallet. Add money first.',
        error: true,
      );
      return;
    }

    final pin = await confirmWithPin(
      context,
      title: 'Repay your loan',
      amountLabel: 'Paying towards ${loan.purpose} loan',
      amount: due,
      details: [
        ('Outstanding now', loan.outstanding.asNaira),
        ('After this payment', (loan.outstanding - due).asNaira),
      ],
    );
    if (pin == null || !context.mounted) return;

    await app.repayLoan(loan.id, due, pin: pin);
    if (!context.mounted) return;
    showToast(context, '${due.asNaira} repaid successfully.');
  }

  Future<void> _customRepay(BuildContext context, Loan loan) async {
    final controller = TextEditingController();
    final app = context.read<AppState>();

    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How much are you paying?',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Outstanding: ${loan.outstanding.asNaira}',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AmountField(controller: controller),
            const SizedBox(height: AppSpacing.xl),
            GoldButton(
              label: 'Continue',
              onPressed: () =>
                  Navigator.pop(sheetContext, parseAmount(controller.text)),
            ),
          ],
        ),
      ),
    );

    if (amount == null || amount <= 0 || !context.mounted) return;
    if (amount > app.balance) {
      showToast(context, 'Not enough in your wallet', error: true);
      return;
    }
    await _repay(context, loan, amount);
  }

  Future<void> _payOffEarly(BuildContext context, Loan loan) async {
    final app = context.read<AppState>();
    final rebate = Finance.earlyPayoffRebate(loan);
    final due = Finance.earlyPayoffAmount(loan);

    if (due > app.balance) {
      showToast(
        context,
        'Settling early needs ${due.asNaira} in your wallet.',
        error: true,
      );
      return;
    }

    final pin = await confirmWithPin(
      context,
      title: 'Settle early',
      amountLabel: 'Clearing your ${loan.purpose} loan',
      amount: due,
      details: [
        ('Outstanding', loan.outstanding.asNaira),
        ('Early-settlement rebate', '-${rebate.asNaira}'),
        ('You pay', due.asNaira),
      ],
    );
    if (pin == null || !context.mounted) return;

    final result = await app.payOffEarly(loan.id, pin: pin);
    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Loan cleared',
          message:
              'Your ${loan.purpose} loan is fully settled and you saved ${result.rebate.asNaira} in interest by paying early.',
          details: [
            ('Amount paid', result.paid.asNaira),
            ('Interest saved', result.rebate.asNaira),
            ('Credit limit restored', loan.principal.asNaira),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final overdue = loan.status == LoanStatus.overdue;
    final settled = loan.status == LoanStatus.repaid;
    final accent = settled
        ? AppColors.success
        : (overdue ? AppColors.danger : AppColors.gold);

    return KCard(
      gradient: AppColors.cardGradient,
      borderColor: accent.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  settled ? 'Fully repaid' : 'Still to pay',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              StatusPill(
                label: loan.status.label.toUpperCase(),
                color: accent,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              loan.outstanding.asNaira,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                color: settled ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: loan.repaymentProgress,
              minHeight: 7,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${loan.installmentsPaid} of ${loan.tenureMonths} instalments paid',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                '${(loan.repaymentProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (loan.nextInstallment != null) ...[
            const SizedBox(height: AppSpacing.lg),
            const HairLine(),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 15,
                  color: overdue ? AppColors.danger : AppColors.textTertiary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Next: ${loan.nextInstallment!.amount.asNaira} due ${loan.nextInstallment!.dueDate.asDay}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: overdue
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RebateBanner extends StatelessWidget {
  const _RebateBanner({
    required this.rebate,
    required this.payoff,
    required this.onTap,
  });

  final double rebate;
  final double payoff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KCard(
    onTap: onTap,
    gradient: AppColors.cardGradient,
    borderColor: AppColors.success.withValues(alpha: 0.32),
    child: Row(
      children: [
        IconBadge(
          icon: Icons.savings_rounded,
          color: AppColors.success,
          size: 44,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settle early, save ${rebate.asNaira}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Clear the whole loan today for ${payoff.asNaira}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: AppColors.success,
          size: 20,
        ),
      ],
    ),
  );
}

class _AutoDebitRow extends StatelessWidget {
  const _AutoDebitRow();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return KCard(
      child: Row(
        children: [
          Icon(
            Icons.event_repeat_rounded,
            size: 21,
            color: AppColors.gold,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-debit repayments',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'We take each instalment from your wallet on its due date',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: app.autoDebit,
            onChanged: (v) async {
              await app.setAutoDebit(v);
              if (!context.mounted) return;
              showToast(
                context,
                v
                    ? 'Auto-debit is on. Keep your wallet funded before each due date.'
                    : 'Auto-debit is off. You will repay manually.',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({required this.item});
  final Installment item;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (item.status) {
      InstallmentStatus.paid => (AppColors.success, Icons.check_rounded),
      InstallmentStatus.partial => (AppColors.gold, Icons.timelapse_rounded),
      InstallmentStatus.overdue => (
        AppColors.danger,
        Icons.priority_high_rounded,
      ),
      InstallmentStatus.upcoming => (
        AppColors.textTertiary,
        Icons.schedule_rounded,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instalment ${item.number}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.dueDate.asDay,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.amount.asNaira,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  decoration: item.status == InstallmentStatus.paid
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: AppColors.textTertiary,
                  color: item.status == InstallmentStatus.paid
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.status.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: HairLine(),
  );
}


/// Explains why a transfer needs a receipt while a wallet payment does not.
class _TransferNote extends StatelessWidget {
  const _TransferNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.infoWash,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppColors.info.withValues(alpha: 0.22)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 15, color: AppColors.info),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'Transfer to the Kudi9ja account, upload the receipt, and we apply it to this loan once the payment is confirmed.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: HairLine()),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Text(
          'or pay from your wallet',
          style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
        ),
      ),
      Expanded(child: HairLine()),
    ],
  );
}
