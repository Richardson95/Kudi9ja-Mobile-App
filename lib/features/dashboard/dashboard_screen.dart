import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/admin.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import '../admin/admin_shell.dart';
import '../loans/loan_detail_screen.dart';
import '../loans/loan_request_screen.dart';
import '../notifications/notifications_screen.dart';
import '../savings/create_plan_screen.dart';
import '../savings/new_plan_sheet.dart';
import '../savings/plan_detail_screen.dart';
import '../wallet/pay_in_screen.dart';
import '../wallet/transaction_list.dart';
import '../wallet/transfer_screen.dart';
import '../wallet/withdraw_screen.dart';
import 'balance_card.dart';
import '../../data/models/platform_settings.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    if (user == null) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 900)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _Greeting(user: user)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: const BalanceCard()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, curve: Curves.easeOutCubic),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            const SliverToBoxAdapter(child: _QuickActions()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            if (app.isAdmin) ...[
              const SliverToBoxAdapter(child: _AdminEntry()),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
            SliverToBoxAdapter(child: _EarningsStrip(app: app)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            SliverToBoxAdapter(child: _SavingsSection(app: app)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            if (app.nextRepayment != null) ...[
              SliverToBoxAdapter(child: _DueBanner(app: app)),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
            SliverToBoxAdapter(child: _CreditSection(app: app)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            SliverToBoxAdapter(child: _RecentActivity(app: app)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
          ],
        ),
      ),
    );
  }
}

// ── Greeting ──────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});
  final AppUser user;

  String get _timeOfDay {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldGradient,
            ),
            alignment: Alignment.center,
            child: Text(
              initialsOf(user.fullName),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textOnGold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _timeOfDay,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  user.firstName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          Consumer<AppState>(
            builder: (context, app, _) => _RoundIcon(
              icon: Icons.notifications_none_rounded,
              badge: app.unreadCount > 0,
              onTap: () => Navigator.of(
                context,
              ).push(slideRoute(const NotificationsScreen())),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, this.badge = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.stroke),
          ),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
        if (badge)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.black, width: 1.5),
              ),
            ),
          ),
      ],
    ),
  );
}

// ── Quick actions ─────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, Widget)>[
      (Icons.add_rounded, 'Add money', const PayInScreen()),
      (Icons.savings_outlined, 'Save', const CreatePlanScreen()),
      (Icons.bolt_rounded, 'Borrow', const LoanRequestScreen()),
      (Icons.send_rounded, 'Send', const TransferScreen()),
      (Icons.north_east_rounded, 'Withdraw', const WithdrawScreen()),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) {
          final (icon, label, page) = actions[i];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(slideRoute(page)),
            child: SizedBox(
              width: 72,
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: Icon(icon, size: 23, color: AppColors.gold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ).animate(delay: (60 * i).ms).fadeIn(duration: 320.ms).slideY(begin: 0.2);
        },
      ),
    );
  }
}

// ── Earnings strip ────────────────────────────────────────────────────────

class _EarningsStrip extends StatelessWidget {
  const _EarningsStrip({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Locked away',
            value: app.hideBalance ? '••••' : app.totalSaved.asShortNaira,
            icon: Icons.lock_outline_rounded,
            tint: AppColors.info,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MiniStat(
            label: 'Interest earned',
            value: app.hideBalance ? '••••' : app.totalInterestEarned.asShortNaira,
            icon: Icons.trending_up_rounded,
            tint: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MiniStat(
            label: 'You owe',
            value: app.hideBalance ? '••••' : app.totalOwed.asShortNaira,
            icon: Icons.receipt_outlined,
            tint: app.totalOwed > 0 ? AppColors.gold : AppColors.textTertiary,
          ),
        ),
      ],
    ),
  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.12);
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.stroke),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: tint),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
        ),
      ],
    ),
  );
}

// ── Savings ───────────────────────────────────────────────────────────────

class _SavingsSection extends StatelessWidget {
  const _SavingsSection({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final plans = app.activePlans;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Your savings',
            actionLabel: plans.isEmpty ? null : 'New plan',
            onAction: () => showNewPlanSheet(context),
          ),
          if (plans.isEmpty)
            _SavingsPitch()
          else
            ...plans
                .take(2)
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: PlanTile(plan: p),
                  ),
                ),
        ],
      ),
    ).animate(delay: 260.ms).fadeIn().slideY(begin: 0.1);
  }
}

class _SavingsPitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.gold.withValues(alpha: 0.22),
    onTap: () => showNewPlanSheet(context),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(
                label: '17% PAID UPFRONT',
                color: AppColors.gold,
                icon: Icons.bolt_rounded,
                dense: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Start your first plan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Lock from 1 month to 5 years. We pay your full return the moment it starts.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Icon(
          Icons.arrow_forward_rounded,
          color: AppColors.gold,
          size: 20,
        ),
      ],
    ),
  );
}

/// Compact savings-plan row, reused on the dashboard and the savings tab.
class PlanTile extends StatelessWidget {
  const PlanTile({super.key, required this.plan});
  final SavingsPlan plan;

  @override
  Widget build(BuildContext context) {
    final mature = plan.status == SavingsStatus.matured;
    final isGoal = plan.targetAmount != null;
    final ring = isGoal ? plan.goalProgress : plan.progress;

    return KCard(
      onTap: () =>
          Navigator.of(context).push(slideRoute(PlanDetailScreen(planId: plan.id))),
      child: Column(
        children: [
          Row(
            children: [
              if (plan.isTarget)
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: Text(
                      plan.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                )
              else
                IconBadge(
                  icon: mature ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: mature ? AppColors.success : AppColors.gold,
                  size: 42,
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGoal
                          ? (plan.goalReached
                                ? 'Target reached'
                                : '${plan.amountLeftToTarget.asShortNaira} to go')
                          : (mature
                                ? 'Ready to withdraw'
                                : plan.maturityDate.countdown),
                      style: TextStyle(
                        fontSize: 12,
                        color: mature || plan.goalReached
                            ? AppColors.success
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.principal.asShortNaira,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    '+${plan.interestPaid.asShortNaira} paid',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: ring,
              minHeight: 5,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(
                mature ? AppColors.success : AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Credit ────────────────────────────────────────────────────────────────

class _CreditSection extends StatelessWidget {
  const _CreditSection({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final loans = app.activeLoans;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Credit'),
          if (loans.isEmpty)
            KCard(
              onTap: () => Navigator.of(
                context,
              ).push(slideRoute(const LoanRequestScreen())),
              child: Row(
                children: [
                  IconBadge(icon: Icons.bolt_rounded, size: 42),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You are pre-approved',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Up to ${app.eligibleLoanAmount.asShortNaira} • from ${settings.loanRateLabelFor(1)} flat over 1 month',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            )
          else
            ...loans.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: LoanTile(loan: l),
              ),
            ),
        ],
      ),
    ).animate(delay: 320.ms).fadeIn().slideY(begin: 0.1);
  }
}

/// Compact loan row shared with the borrow tab.
class LoanTile extends StatelessWidget {
  const LoanTile({super.key, required this.loan, this.onTap});
  final Loan loan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = loan.status == LoanStatus.overdue;

    return KCard(
      onTap: onTap,
      borderColor: overdue ? AppColors.danger.withValues(alpha: 0.35) : null,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          loan.purpose,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        StatusPill(
                          label: loan.status.label.toUpperCase(),
                          color: overdue ? AppColors.danger : AppColors.gold,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Due ${loan.dueDate.asDay}',
                      style: TextStyle(
                        fontSize: 12,
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
                    loan.outstanding.asShortNaira,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'outstanding',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: loan.repaymentProgress,
              minHeight: 5,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(
                overdue ? AppColors.danger : AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent activity ───────────────────────────────────────────────────────

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final txns = app.transactions.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Recent activity'),
          if (txns.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'Nothing here yet',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            )
          else
            KCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < txns.length; i++) ...[
                    if (i > 0) const HairLine(indent: 52),
                    TransactionRow(tx: txns[i], hidden: app.hideBalance),
                  ],
                ],
              ),
            ),
        ],
      ),
    ).animate(delay: 380.ms).fadeIn().slideY(begin: 0.1);
  }
}


/// A standing reminder of the next instalment, shown on the dashboard.
class _DueBanner extends StatelessWidget {
  const _DueBanner({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final next = app.nextRepayment!;
    final days = next.installment.daysUntilDue;
    final late = days < 0;
    final accent = late
        ? AppColors.danger
        : (days <= 3 ? AppColors.gold : AppColors.info);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: KCard(
        borderColor: accent.withValues(alpha: 0.32),
        onTap: () => Navigator.of(
          context,
        ).push(slideRoute(LoanDetailScreen(loanId: next.loan.id))),
        child: Row(
          children: [
            IconBadge(
              icon: late ? Icons.priority_high_rounded : Icons.event_rounded,
              color: accent,
              size: 42,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    late
                        ? 'Repayment overdue'
                        : (days == 0
                              ? 'Repayment due today'
                              : 'Repayment in $days ${days == 1 ? 'day' : 'days'}'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${next.installment.amount.asNaira} • ${next.installment.dueDate.asDay}',
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
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1);
  }
}


/// The way into the admin panel. Rendered only when the signed-in account
/// appears on the admin team, so ordinary customers never see it.
class _AdminEntry extends StatelessWidget {
  const _AdminEntry();

  @override
  Widget build(BuildContext context) {
    final role = context.select<AppState, String>((s) => s.adminRole.label);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: KCard(
        gradient: AppColors.cardGradient,
        borderColor: AppColors.gold.withValues(alpha: 0.35),
        onTap: () => Navigator.of(context).push(slideRoute(const AdminShell())),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.admin_panel_settings_rounded,
                size: 23,
                color: AppColors.textOnGold,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Go to admin',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Signed in as $role',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 19,
              color: AppColors.gold,
            ),
          ],
        ),
      ),
    ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.1);
  }
}
