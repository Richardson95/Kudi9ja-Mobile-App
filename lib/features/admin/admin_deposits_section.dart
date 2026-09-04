import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/admin.dart';
import '../../data/models/deposit.dart';
import '../../state/app_state.dart';
import '../../widgets/company_account.dart';
import '../../widgets/primitives.dart';

/// Incoming payments a customer says they have made, each with the receipt
/// they uploaded. Nothing is credited until one of these is approved.
class AdminDepositList extends StatelessWidget {
  const AdminDepositList({super.key, required this.claims});
  final List<DepositClaim> claims;

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_rounded,
        title: 'Nothing to confirm',
        message:
            'Payments customers submit with a receipt appear here for you to match against the bank statement.',
      );
    }

    return Column(
      children: [
        for (var i = 0; i < claims.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ClaimCard(claim: claims[i])
                .animate(delay: (40 * i).ms)
                .fadeIn()
                .slideY(begin: 0.08),
          ),
      ],
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim});
  final DepositClaim claim;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final canAct = app.adminRole.canApprovePayments;

    final tint = switch (claim.status) {
      DepositStatus.pending => AppColors.gold,
      DepositStatus.confirmed => AppColors.success,
      DepositStatus.rejected => AppColors.danger,
    };

    return KCard(
      borderColor: tint.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: claim.isLoanRepayment
                    ? Icons.bolt_rounded
                    : Icons.south_west_rounded,
                color: tint,
                size: 44,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claim.amount.asNaira,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${claim.customerName} • ${claim.purpose.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: claim.status.label.toUpperCase(),
                color: tint,
                dense: true,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // The receipt is the whole point, so it is shown, not hidden.
          if (claim.hasReceipt)
            GestureDetector(
              onTap: () => showReceipt(context, claim.receiptPath),
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.stroke),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(claim.receiptPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.surfaceAlt,
                        child: Center(
                          child: Text(
                            'Receipt image unavailable',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              size: 13,
                              color: AppColors.gold,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Tap to enlarge',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.dangerWash,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.24),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 15,
                    color: AppColors.danger,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'No receipt was attached to this claim.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.md),
          _Line('Narration', claim.reference),
          if (claim.senderName.isNotEmpty) _Line('Paid from', claim.senderName),
          if (claim.isLoanRepayment)
            _Line('Applies to', '${claim.loanPurpose} loan'),
          _Line('Submitted', claim.claimedAt.asDayTime),
          _Line('Customer account', claim.customerAccount),
          if (claim.reviewedAt != null)
            _Line(
              claim.status == DepositStatus.confirmed
                  ? 'Confirmed by'
                  : 'Rejected by',
              '${claim.reviewedBy} • ${claim.reviewedAt!.asDay}',
            ),
          if (claim.note.isNotEmpty) _Line('Reason', claim.note),

          if (claim.isPending) ...[
            const SizedBox(height: AppSpacing.lg),
            if (claim.age.inHours >= 12)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Waiting ${claim.age.inHours} hours',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Reject',
                    danger: true,
                    onPressed: canAct
                        ? () => _reject(context, app, claim)
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: GoldButton(
                    label: 'Confirm payment',
                    height: 54,
                    onPressed: canAct
                        ? () => _confirm(context, app, claim)
                        : null,
                  ),
                ),
              ],
            ),
            if (!canAct)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Your role is read-only, so you cannot confirm payments.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    AppState app,
    DepositClaim c,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm this payment?'),
        content: Text(
          c.isLoanRepayment
              ? 'Check the receipt against the ${c.reference} entry on the bank statement. Confirming applies ${c.amount.asNaira} to ${c.customerName}’s ${c.loanPurpose} loan.'
              : 'Check the receipt against the ${c.reference} entry on the bank statement. Confirming credits ${c.amount.asNaira} to ${c.customerName}’s wallet.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Confirm',
              style: TextStyle(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await app.confirmDeposit(c.id);
    if (!context.mounted) return;
    showToast(
      context,
      c.isLoanRepayment
          ? '${c.amount.asNaira} applied to the loan'
          : '${c.amount.asNaira} credited to ${c.customerName}',
    );
  }

  Future<void> _reject(
    BuildContext context,
    AppState app,
    DepositClaim c,
  ) async {
    final controller = TextEditingController();

    final reason = await showModalBottomSheet<String>(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject this payment',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Nothing was credited, so nothing is reversed. Tell them what went wrong.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 140,
              style: const TextStyle(fontSize: 14.5),
              decoration: const InputDecoration(
                hintText: 'e.g. No matching credit on the statement',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GhostButton(
              label: 'Reject payment',
              danger: true,
              onPressed: () =>
                  Navigator.pop(sheetContext, controller.text.trim()),
            ),
          ],
        ),
      ),
    );

    if (reason == null || !context.mounted) return;
    await app.rejectDeposit(c.id, reason);
    if (!context.mounted) return;
    showToast(context, 'Payment rejected', error: true);
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
