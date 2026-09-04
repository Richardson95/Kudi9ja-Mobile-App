import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../app.dart';
import '../../widgets/primitives.dart';
import 'receipt_screen.dart';

IconData iconForTx(TxKind kind) => switch (kind) {
  TxKind.deposit => Icons.add_rounded,
  TxKind.withdrawal => Icons.north_east_rounded,
  TxKind.transfer => Icons.send_rounded,
  TxKind.savingsLock => Icons.lock_rounded,
  TxKind.interestPayout => Icons.trending_up_rounded,
  TxKind.savingsRelease => Icons.lock_open_rounded,
  TxKind.loanDisbursement => Icons.bolt_rounded,
  TxKind.loanRepayment => Icons.receipt_long_rounded,
  TxKind.fee => Icons.remove_circle_outline_rounded,
};

Color colorForTx(Transaction tx) {
  if (tx.kind == TxKind.interestPayout) return AppColors.success;
  if (tx.kind == TxKind.fee) return AppColors.danger;
  return tx.isCredit ? AppColors.success : AppColors.textSecondary;
}

/// One line in any transaction list.
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.tx,
    this.hidden = false,
    this.onTap,
  });

  final Transaction tx;
  final bool hidden;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = colorForTx(tx);

    return InkWell(
      onTap: onTap ?? () => showTransactionDetail(context, tx),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            IconBadge(icon: iconForTx(tx.kind), color: tint, size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        tx.date.relative,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      if (tx.status != TxStatus.successful) ...[
                        const SizedBox(width: 6),
                        StatusPill(
                          label: tx.status == TxStatus.pending
                              ? 'PENDING'
                              : 'REVERSED',
                          color: tx.status == TxStatus.pending
                              ? AppColors.gold
                              : AppColors.danger,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              hidden
                  ? '••••'
                  : '${tx.isCredit ? '+' : '-'}${tx.amount.asNaira}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: tx.status == TxStatus.reversed
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: AppColors.textTertiary,
                color: tx.status == TxStatus.reversed
                    ? AppColors.textTertiary
                    : (tx.isCredit
                          ? AppColors.success
                          : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showTransactionDetail(BuildContext context, Transaction tx) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(
              icon: iconForTx(tx.kind),
              color: colorForTx(tx),
              size: 58,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${tx.isCredit ? '+' : '-'}${tx.amount.asNaira}',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: tx.isCredit ? AppColors.success : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tx.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            KCard(
              child: Column(
                children: [
                  _Row('Type', tx.kind.label),
                  const _Sep(),
                  _Row('Date', tx.date.asDayTime),
                  if (tx.counterparty.isNotEmpty) ...[
                    const _Sep(),
                    _Row('Counterparty', tx.counterparty),
                  ],
                  const _Sep(),
                  _Row('Balance after', tx.balanceAfter.asNaira),
                  const _Sep(),
                  _Row('Reference', tx.reference),
                  const _Sep(),
                  _Row(
                    'Status',
                    tx.status.label,
                    color: switch (tx.status) {
                      TxStatus.successful => AppColors.success,
                      TxStatus.pending => AppColors.gold,
                      TxStatus.reversed => AppColors.danger,
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            GoldButton(
              label: 'View receipt',
              icon: Icons.receipt_long_rounded,
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(slideRoute(ReceiptScreen(tx: tx)));
              },
            ),
            const SizedBox(height: AppSpacing.md),
            GhostButton(
              label: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.textPrimary,
          ),
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
