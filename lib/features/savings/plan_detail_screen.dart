import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';
import '../../widgets/result_screen.dart';

class PlanDetailScreen extends StatelessWidget {
  const PlanDetailScreen({super.key, required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    SavingsPlan? plan;
    for (final p in app.plans) {
      if (p.id == planId) plan = p;
    }
    if (plan == null) return const Scaffold(body: SizedBox.shrink());

    final p = plan;
    final mature = p.status == SavingsStatus.matured;
    final open = p.isOpen;

    return Scaffold(
      appBar: AppBar(title: const Text('Savings plan')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _Hero(plan: p),
              const SizedBox(height: AppSpacing.xl),
              KCard(
                child: Column(
                  children: [
                    _Row('Principal locked', p.principal.asNaira),
                    const _Sep(),
                    _Row(
                      'Interest paid upfront',
                      '+${p.interestPaid.asNaira}',
                      color: AppColors.success,
                    ),
                    const _Sep(),
                    _Row('Total value', p.totalValue.asNaira, bold: true),
                    const _Sep(),
                    _Row('Plan type', p.type.label),
                    const _Sep(),
                    if (p.targetAmount != null) ...[
                      _Row('Target', p.targetAmount!.asNaira),
                      const _Sep(),
                    ],
                    if (p.contributions > 1) ...[
                      _Row('Deposits made', '${p.contributions}'),
                      const _Sep(),
                    ],
                    _Row('Rate', '17% per annum'),
                    const _Sep(),
                    _Row('Lock period', lockPeriodLabel(p.lockDays)),
                    const _Sep(),
                    _Row('Started', p.startDate.asDay),
                    const _Sep(),
                    _Row('Matures', p.maturityDate.asDay),
                    const _Sep(),
                    _Row('Status', p.status.label),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              if (p.isTarget && open) ...[
                _AutoCard(plan: p),
                const SizedBox(height: AppSpacing.xl),
              ],

              if (open) ...[
                if (mature)
                  GoldButton(
                    label: p.isTarget && !p.bonusPaid
                        ? 'Withdraw ${(p.principal + p.bonusEarned).asNairaFlat}'
                        : 'Withdraw ${p.principal.asNairaFlat}',
                    icon: Icons.lock_open_rounded,
                    onPressed: () => _withdraw(context, p),
                  )
                else if (p.isFixed) ...[
                  GoldButton(
                    label: 'Top up this plan',
                    icon: Icons.add_rounded,
                    onPressed: () => _topUp(context, p),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SealedNotice(),
                ] else ...[
                  GoldButton(
                    label: 'Add extra to this plan',
                    icon: Icons.add_rounded,
                    onPressed: () => _topUp(context, p),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GhostButton(
                    label: 'Break this plan',
                    icon: Icons.lock_open_outlined,
                    danger: true,
                    onPressed: () => _breakEarly(context, p),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.dangerWash,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Every naira you have saved comes back in full — but you forfeit the whole ${(p.bonusRate * 100).toStringAsFixed(1)}% bonus, currently worth ${p.bonusEarned.asNaira}. There is no partial payout.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _withdraw(BuildContext context, SavingsPlan p) async {
    final pin = await confirmWithPin(
      context,
      title: 'Withdraw savings',
      amountLabel: 'Releasing to your wallet',
      amount: p.principal,
      details: [('Plan', p.title), ('Matured', p.maturityDate.asDay)],
    );
    if (pin == null || !context.mounted) return;

    final result = await context.read<AppState>().withdrawPlan(p.id);
    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Savings released',
          message: result.bonus > 0
              ? 'You finished the plan. ${(result.principal + result.bonus).asNaira} is in your wallet, including your ${result.bonus.asNaira} bonus.'
              : '${result.principal.asNaira} is back in your wallet. You kept every naira of the ${p.interestPaid.asNaira} paid to you upfront.',
          details: [
            ('Plan', p.title),
            ('Principal returned', result.principal.asNaira),
            if (result.bonus > 0)
              (
                '${(p.bonusRate * 100).toStringAsFixed(1)}% completion bonus',
                result.bonus.asNaira,
              )
            else
              ('Interest kept', p.interestPaid.asNaira),
          ],
        ),
      ),
    );
  }

  Future<void> _breakEarly(BuildContext context, SavingsPlan p) async {
    final forfeited = p.bonusEarned;
    final payout = p.principal;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Break this plan?'),
        content: Text(
          'All ${payout.asNaira} you have saved comes back to your wallet. But you give up the ${(p.bonusRate * 100).toStringAsFixed(1)}% bonus — ${forfeited.asNaira} as things stand — and it cannot be recovered.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Keep saving',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Break and forfeit bonus',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final pin = await confirmWithPin(
      context,
      title: 'Break this plan',
      amountLabel: 'Returning to your wallet',
      amount: payout,
      details: [
        ('Saved so far', p.principal.asNaira),
        ('Bonus forfeited', '-${forfeited.asNaira}'),
      ],
    );
    if (pin == null || !context.mounted) return;

    final received = await context.read<AppState>().breakPlan(p.id);
    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          success: false,
          title: 'Plan broken',
          message:
              '${received.asNaira} has been returned to your wallet in full. The ${(p.bonusRate * 100).toStringAsFixed(1)}% bonus was forfeited.',
          details: [
            ('Returned to wallet', received.asNaira),
            ('Bonus given up', forfeited.asNaira),
          ],
        ),
      ),
    );
  }

  Future<void> _topUp(BuildContext context, SavingsPlan p) async {
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
              'Add extra to "${p.title}"',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Wallet: ${app.balance.asNaira}',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AmountField(controller: controller),
            const SizedBox(height: AppSpacing.xl),
            GoldButton(
              label: 'Add to savings',
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

    final pin = await confirmWithPin(
      context,
      title: 'Top up savings',
      amountLabel: 'Adding to "${p.title}"',
      amount: amount,
    );
    if (pin == null || !context.mounted) return;

    final done = await app.topUpPlan(p.id, amount);
    if (!context.mounted) return;
    showToast(
      context,
      !done
          ? 'This plan is closed and cannot take more money.'
          : (p.isFixed
                ? 'Added, and your return on it is already in your wallet.'
                : 'Added. It counts towards your bonus at the end.'),
      error: !done,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.plan});
  final SavingsPlan plan;

  @override
  Widget build(BuildContext context) {
    final mature = plan.status == SavingsStatus.matured;
    final accent = mature ? AppColors.success : AppColors.gold;

    final isGoal = plan.targetAmount != null;
    final ring = isGoal ? plan.goalProgress : plan.progress;

    return KCard(
      gradient: AppColors.cardGradient,
      borderColor: accent.withValues(alpha: 0.28),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Row(
            children: [
              if (plan.isTarget) ...[
                Text(plan.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusPill(
                label: plan.isFixed
                    ? plan.status.label.toUpperCase()
                    : plan.type.label.toUpperCase(),
                color: accent,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: 148,
            height: 148,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 148,
                  height: 148,
                  child: CircularProgressIndicator(
                    value: ring,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(ring * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                    ),
                    Text(
                      isGoal
                          ? 'of target'
                          : (mature ? 'Matured' : 'through lock'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            isGoal
                ? (plan.goalReached
                      ? 'Target reached'
                      : '${plan.amountLeftToTarget.asNaira} to go')
                : (mature ? 'Ready to withdraw' : plan.maturityDate.countdown),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          if (isGoal) ...[
            const SizedBox(height: 4),
            Text(
              '${plan.principal.asNaira} of ${plan.targetAmount!.asNaira}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
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
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: bold ? 14.5 : 13.5,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          color: color ?? AppColors.textPrimary,
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


/// Live controls for an Auto Save plan.
class _AutoCard extends StatelessWidget {
  const _AutoCard({required this.plan});
  final SavingsPlan plan;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return KCard(
      borderColor: plan.autoEnabled
          ? AppColors.success.withValues(alpha: 0.3)
          : null,
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.autorenew_rounded,
                color: plan.autoEnabled
                    ? AppColors.success
                    : AppColors.textTertiary,
                size: 44,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.autoEnabled ? 'Auto Save is on' : 'Auto Save paused',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(plan.autoAmount ?? 0).asNaira} ${plan.autoFrequency?.adverb ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: plan.autoEnabled,
                onChanged: (v) async {
                  await app.setAutoSaveEnabled(plan.id, v);
                  if (!context.mounted) return;
                  showToast(
                    context,
                    v ? 'Auto Save resumed' : 'Auto Save paused',
                  );
                },
              ),
            ],
          ),
          if (plan.autoEnabled && plan.nextAutoRun != null) ...[
            const SizedBox(height: AppSpacing.md),
            const HairLine(),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Next contribution ${plan.nextAutoRun!.asDay}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${plan.contributions} so far',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
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


/// Stands in for the action buttons on a running Fixed Savings plan, which
/// has no early exit of any kind.
class _SealedNotice extends StatelessWidget {
  const _SealedNotice();

  @override
  Widget build(BuildContext context) => KCard(
    borderColor: AppColors.info.withValues(alpha: 0.32),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(
          icon: Icons.shield_rounded,
          color: AppColors.info,
          size: 44,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Locked until maturity',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.info,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'You can add more at any time and each top-up earns its own return straight away. What you cannot do is take money out: the principal is released only on the maturity date.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
