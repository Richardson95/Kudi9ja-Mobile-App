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
import '../wallet/add_money_screen.dart';
import 'loan_officers_card.dart';

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
    final next = loan.nextInstallment;
    final nextDue = next?.outstanding ?? loan.installmentAmount;

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

              if (loan.status == LoanStatus.overdue) ...[
                const _OverdueNote(),
                const SizedBox(height: AppSpacing.lg),
              ],

              if (loan.isOpen) ...[
                GoldButton(
                  label: 'Pay ${nextDue.asNaira}',
                  icon: Icons.lock_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddMoneyScreen(
                        loan: loan,
                        presetAmount: nextDue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const _PayNote(),
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
                        label: 'Pay ${nextDue.asNaira}',
                        onPressed: () => _repay(context, loan, nextDue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                GhostButton(
                  label: 'Pay off the whole loan · ${loan.settlementAmount.asNaira}',
                  icon: Icons.flash_on_rounded,
                  onPressed: () => _payOffEarly(context, loan),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _AutoDebitRow(),
                const SizedBox(height: AppSpacing.xl),
              ],

              const LoanOfficersCard(),

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
                      'Management fee',
                      '-${loan.processingFee.asNaira}',
                    ),
                    if (loan.transactionFee > 0) ...[
                      const _Sep(),
                      _Line(
                        'Transaction fee (taken at payout)',
                        '-${loan.transactionFee.asNaira}',
                      ),
                    ],
                    const _Sep(),
                    _Line('Credited to wallet', loan.netDisbursed.asNaira),
                    const _Sep(),
                    _Line(
                      'Repaid',
                      '${loan.frequency.label} · ${loan.installmentCount} '
                          'payment${loan.installmentCount == 1 ? '' : 's'}',
                    ),
                    const _Sep(),
                    _Line(
                      '${loan.frequency.label} instalment',
                      loan.installmentAmount.asNaira,
                    ),
                    if (loan.totalRepaymentFees > 0) ...[
                      const _Sep(),
                      _Line(
                        'Of which transaction fee',
                        '${loan.installmentFee.asNaira} '
                            '(${PlatformSettings.ratePct(loan.repaymentFeeRate * 100)} '
                            'of each repayment)',
                      ),
                      const _Sep(),
                      _Line('Transaction fees in all', loan.totalRepaymentFees.asNaira),
                    ],
                    const _Sep(),
                    _Line('Total repayable', loan.totalRepayable.asNaira),
                    const _Sep(),
                    _Line('Repaid so far', loan.amountRepaid.asNaira),
                    if ((loan.figures?.rebateGranted ?? 0) > 0) ...[
                      const _Sep(),
                      _Line('Rebate', loan.figures!.rebateGranted.asNaira),
                    ],
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

  /// Clears the whole loan from the wallet. It costs exactly what is still
  /// owed, interest included — paying early earns no discount, and the
  /// screen says so before the PIN rather than after.
  Future<void> _payOffEarly(BuildContext context, Loan loan) async {
    final app = context.read<AppState>();
    final due = loan.settlementAmount;

    if (due > app.balance) {
      final topUp = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pay off the whole loan'),
          content: Text(
            'Clearing it needs ${due.asNaira} — everything still owed, interest '
            'included. Your wallet holds ${app.balance.asNaira}. Pay the rest '
            'with Paystack instead?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pay with Paystack'),
            ),
          ],
        ),
      );
      if (topUp == true && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddMoneyScreen(loan: loan, presetAmount: due),
          ),
        );
      }
      return;
    }

    final pin = await confirmWithPin(
      context,
      title: 'Pay off the whole loan',
      amountLabel: 'Clearing your ${loan.purpose} loan',
      amount: due,
      details: [
        ('Still owed', loan.outstanding.asNaira),
        ('From your wallet', due.asNaira),
      ],
    );
    if (pin == null || !context.mounted) return;

    final result = await app.payOffEarly(loan.id, pin: pin);
    if (!context.mounted) return;
    if (result.paid <= 0) {
      showToast(context, app.lastError ?? 'The loan was not settled.', error: true);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Loan cleared',
          message: 'Your ${loan.purpose} loan is fully settled.',
          details: [
            ('Amount paid', result.paid.asNaira),
            if (result.rebate > 0) ('Rebate', result.rebate.asNaira),
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
                '${loan.installmentsPaid} of ${loan.installmentCount} '
                '${loan.frequency.adjective} instalments paid',
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
                    // What is left on that instalment, not its full size: a
                    // borrower who has already paid part of it is told to find
                    // the whole thing again otherwise.
                    'Next: ${loan.nextInstallment!.outstanding.asNaira} due ${loan.nextInstallment!.dueDate.asDay}',
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

/// Said plainly at the top of an overdue loan, with what to do about it.
class _OverdueNote extends StatelessWidget {
  const _OverdueNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.dangerWash,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.priority_high_rounded, size: 16, color: AppColors.danger),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'This loan is overdue. Pay what is due as soon as you can. If '
            'something has changed, tell your loan officer or write to us from '
            'Help & complaints — we would rather agree a plan.',
            style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary),
          ),
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
              if (item.fee > 0)
                Text(
                  '${item.base.asNaira} + ${item.fee.asNaira} fee',
                  style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
                ),
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


/// Says where a payment goes and how fast.
class _PayNote extends StatelessWidget {
  const _PayNote();

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
            'Pay by card, bank transfer or USSD through Paystack. It comes off '
            'what you owe the moment Paystack confirms it — no receipt, no '
            'waiting.',
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
