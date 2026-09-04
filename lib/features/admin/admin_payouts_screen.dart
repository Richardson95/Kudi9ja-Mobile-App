import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/admin.dart';
import '../../data/models/deposit.dart';
import '../../data/models/withdrawal.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import 'admin_deposits_section.dart';
import 'admin_shell.dart';

/// Every withdrawal request lands here for a human decision before money
/// leaves the platform.
class AdminPayoutsScreen extends StatefulWidget {
  const AdminPayoutsScreen({super.key});

  @override
  State<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends State<AdminPayoutsScreen> {
  /// false = money coming in, true = money going out.
  bool _outgoing = false;
  WithdrawalStatus? _outFilter = WithdrawalStatus.pending;
  DepositStatus? _inFilter = DepositStatus.pending;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final outgoing = app.withdrawals;
    final incoming = app.deposits;

    final released = outgoing
        .where((w) => w.status == WithdrawalStatus.approved)
        .fold(0.0, (s, w) => s + w.amount);
    final collected = incoming
        .where((d) => d.status == DepositStatus.confirmed)
        .fold(0.0, (s, d) => s + d.amount);

    final outList = _outFilter == null
        ? outgoing
        : outgoing.where((w) => w.status == _outFilter).toList();
    final inList = _inFilter == null
        ? incoming
        : incoming.where((d) => d.status == _inFilter).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const AdminSectionLabel('PAYMENTS'),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'To confirm',
                value: '${app.pendingDepositCount}',
                icon: Icons.south_west_rounded,
                tint: app.pendingDepositCount > 0
                    ? AppColors.gold
                    : AppColors.textTertiary,
                footnote: app.pendingDepositCount > 0
                    ? app.pendingDepositValue.asShortNaira
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricTile(
                label: 'To pay out',
                value: '${app.pendingWithdrawalCount}',
                icon: Icons.north_east_rounded,
                tint: app.pendingWithdrawalCount > 0
                    ? AppColors.gold
                    : AppColors.textTertiary,
                footnote: app.pendingWithdrawalCount > 0
                    ? app.pendingWithdrawalValue.asShortNaira
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Collected to date',
                value: collected.asShortNaira,
                icon: Icons.savings_rounded,
                tint: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricTile(
                label: 'Released to date',
                value: released.asShortNaira,
                icon: Icons.task_alt_rounded,
                tint: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Money in / money out switch.
        Row(
          children: [
            Expanded(
              child: _Segment(
                label: 'Money in',
                count: app.pendingDepositCount,
                selected: !_outgoing,
                onTap: () => setState(() => _outgoing = false),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Segment(
                label: 'Money out',
                count: app.pendingWithdrawalCount,
                selected: _outgoing,
                onTap: () => setState(() => _outgoing = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        if (!_outgoing) ...[
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(
                  label: 'To confirm',
                  count: app.pendingDepositCount,
                  selected: _inFilter == DepositStatus.pending,
                  onTap: () =>
                      setState(() => _inFilter = DepositStatus.pending),
                ),
                const SizedBox(width: AppSpacing.sm),
                _Chip(
                  label: 'Confirmed',
                  selected: _inFilter == DepositStatus.confirmed,
                  onTap: () =>
                      setState(() => _inFilter = DepositStatus.confirmed),
                ),
                const SizedBox(width: AppSpacing.sm),
                _Chip(
                  label: 'Rejected',
                  selected: _inFilter == DepositStatus.rejected,
                  onTap: () =>
                      setState(() => _inFilter = DepositStatus.rejected),
                ),
                const SizedBox(width: AppSpacing.sm),
                _Chip(
                  label: 'Everything',
                  selected: _inFilter == null,
                  onTap: () => setState(() => _inFilter = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AdminDepositList(claims: inList),
          const SizedBox(height: AppSpacing.lg),
          const _Footnote(
            text:
                'Match each receipt against the Kudi9ja collection account statement before confirming. Nothing reaches a wallet or a loan until you approve it.',
          ),
        ] else ...[
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(
                  label: 'Pending',
                  count: app.pendingWithdrawalCount,
                  selected: _outFilter == WithdrawalStatus.pending,
                  onTap: () =>
                      setState(() => _outFilter = WithdrawalStatus.pending),
                ),
                const SizedBox(width: AppSpacing.sm),
                _Chip(
                  label: 'Approved',
                  selected: _outFilter == WithdrawalStatus.approved,
                  onTap: () =>
                      setState(() => _outFilter = WithdrawalStatus.approved),
                ),
                const SizedBox(width: AppSpacing.sm),
                _Chip(
                  label: 'Declined',
                  selected: _outFilter == WithdrawalStatus.declined,
                  onTap: () =>
                      setState(() => _outFilter = WithdrawalStatus.declined),
                ),
                const SizedBox(width: AppSpacing.sm),
                _Chip(
                  label: 'Everything',
                  selected: _outFilter == null,
                  onTap: () => setState(() => _outFilter = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (outList.isEmpty)
            const EmptyState(
              icon: Icons.inbox_rounded,
              title: 'Nothing waiting',
              message:
                  'Withdrawal requests appear here the moment a customer submits one.',
            )
          else
            for (var i = 0; i < outList.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _RequestCard(request: outList[i])
                    .animate(delay: (40 * i).ms)
                    .fadeIn()
                    .slideY(begin: 0.08),
              ),
          const SizedBox(height: AppSpacing.lg),
          const _Footnote(
            text:
                'The amount leaves the customer wallet the moment they request it, so it cannot be spent twice while you review. Declining refunds it in full and tells them why.',
          ),
        ],

        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.goldWash : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.stroke,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.gold : AppColors.textSecondary,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11.5,
      height: 1.5,
      color: AppColors.textTertiary,
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.goldWash : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: selected ? AppColors.gold : AppColors.stroke),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.gold : AppColors.textSecondary,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textOnGold,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final WithdrawalRequest request;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final canAct = app.adminRole.canActOnLoans;

    final tint = switch (request.status) {
      WithdrawalStatus.pending => AppColors.gold,
      WithdrawalStatus.approved => AppColors.success,
      WithdrawalStatus.declined => AppColors.danger,
    };

    return KCard(
      borderColor: tint.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.north_east_rounded,
                color: tint,
                size: 44,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.amount.asNaira,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: request.status.label.toUpperCase(),
                color: tint,
                dense: true,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const HairLine(),
          const SizedBox(height: AppSpacing.md),

          _Line('Destination', '${request.bank} • ${request.destinationAccount}'),
          _Line('Requested', request.requestedAt.asDayTime),
          _Line('Reference', request.reference),
          if (request.reviewedAt != null)
            _Line(
              request.status == WithdrawalStatus.approved
                  ? 'Approved by'
                  : 'Declined by',
              '${request.reviewedBy} • ${request.reviewedAt!.asDay}',
            ),
          if (request.note.isNotEmpty) _Line('Reason', request.note),

          if (request.isPending) ...[
            const SizedBox(height: AppSpacing.lg),
            if (request.age.inHours >= 24)
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
                      'Waiting ${request.age.inHours ~/ 24} day(s)',
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
                    label: 'Decline',
                    danger: true,
                    onPressed: canAct
                        ? () => _decline(context, app, request)
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: GoldButton(
                    label: 'Approve',
                    height: 54,
                    onPressed: canAct
                        ? () => _approve(context, app, request)
                        : null,
                  ),
                ),
              ],
            ),
            if (!canAct)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Your role is read-only, so you cannot action payouts.',
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

  Future<void> _approve(
    BuildContext context,
    AppState app,
    WithdrawalRequest w,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Release this payout?'),
        content: Text(
          '${w.amount.asNaira} will be sent to ${w.customerName} at ${w.bank} ${w.destinationAccount}. This cannot be undone.',
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
              'Approve',
              style: TextStyle(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await app.approveWithdrawal(w.id);
    if (!context.mounted) return;
    showToast(context, '${w.amount.asNaira} released to ${w.customerName}');
  }

  Future<void> _decline(
    BuildContext context,
    AppState app,
    WithdrawalRequest w,
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
              'Decline this payout',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${w.amount.asNaira} goes straight back to ${w.customerName}. Tell them why.',
              style: const TextStyle(
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
                hintText: 'e.g. Account name does not match our records',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GhostButton(
              label: 'Decline and refund',
              danger: true,
              onPressed: () =>
                  Navigator.pop(sheetContext, controller.text.trim()),
            ),
          ],
        ),
      ),
    );

    if (reason == null || !context.mounted) return;

    await app.declineWithdrawal(w.id, reason);
    if (!context.mounted) return;
    showToast(
      context,
      '${w.amount.asNaira} refunded to ${w.customerName}',
      error: true,
    );
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
          width: 92,
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
