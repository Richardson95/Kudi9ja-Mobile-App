import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';
import '../dashboard/dashboard_screen.dart';
import '../shell/home_shell.dart';
import 'credit_score_screen.dart';
import 'loan_calculator_screen.dart';
import '../wallet/pay_in_screen.dart';
import 'loan_detail_screen.dart';
import 'loan_request_screen.dart';
import '../../data/models/platform_settings.dart';

class LoansScreen extends StatelessWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final active = app.activeLoans;
    final closed = app.loans.where((l) => !l.isOpen).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: TabHeader(
              title: 'Borrow',
              subtitle: 'Up to ₦500,000, repaid your way',
            ),
          ),
          SliverToBoxAdapter(child: _CreditCard(app: app)),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),

          if (app.nextRepayment != null) ...[
            SliverToBoxAdapter(child: _NextDueCard(app: app)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],

          if (active.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: SectionHeader(title: 'Active loans'),
              ),
            ),
            SliverList.separated(
              itemCount: active.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: _ActiveLoanCard(loan: active[i])
                    .animate(delay: (60 * i).ms)
                    .fadeIn()
                    .slideY(begin: 0.12),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ] else
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.bolt_rounded,
                title: 'No active loans',
                message:
                    'Borrow ${settings.minLoanAmount.asShortNaira} to ${settings.maxLoanAmount.asShortNaira} over 1 to ${settings.maxLoanTenureMonths} months. Interest is flat and set by the tenure — ${settings.loanRateLabelFor(1)} over 1 month, ${settings.loanRateLabelFor(3)} over 3. A flat ${settings.flatProcessingFee.asShortNaira} fee comes out of the amount you receive.',
                action: SizedBox(
                  width: 220,
                  child: GoldButton(
                    label: 'Request a loan',
                    onPressed: () => Navigator.of(
                      context,
                    ).push(slideRoute(const LoanRequestScreen())),
                  ),
                ),
              ),
            ),

          if (closed.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: SectionHeader(title: 'Loan history'),
              ),
            ),
            SliverList.separated(
              itemCount: closed.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: LoanTile(
                  loan: closed[i],
                  onTap: () => Navigator.of(
                    context,
                  ).push(slideRoute(LoanDetailScreen(loanId: closed[i].id))),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
        ],
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final score = app.creditScore;
    final pct = ((score - 300) / 550).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: KCard(
        gradient: AppColors.cardGradient,
        borderColor: AppColors.gold.withValues(alpha: 0.22),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available credit',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        app.eligibleLoanAmount.asNaira,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.1,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).push(slideRoute(const CreditScoreScreen())),
                  child: _ScoreRing(
                    score: score,
                    pct: pct,
                    band: app.creditBand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Calculate',
                    icon: Icons.calculate_outlined,
                    onPressed: () => Navigator.of(
                      context,
                    ).push(slideRoute(const LoanCalculatorScreen())),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: GoldButton(
                    label: 'Borrow',
                    icon: Icons.bolt_rounded,
                    height: 54,
                    onPressed: () => Navigator.of(
                      context,
                    ).push(slideRoute(const LoanRequestScreen())),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({
    required this.score,
    required this.pct,
    required this.band,
  });

  final int score;
  final double pct;
  final String band;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 78,
    height: 78,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 78,
          height: 78,
          child: CircularProgressIndicator(
            value: pct,
            strokeWidth: 6,
            strokeCap: StrokeCap.round,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation(AppColors.success),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              band,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ActiveLoanCard extends StatelessWidget {
  const _ActiveLoanCard({required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final overdue = loan.status == LoanStatus.overdue;
    final accent = overdue ? AppColors.danger : AppColors.gold;

    return KCard(
      borderColor: accent.withValues(alpha: 0.28),
      onTap: () => Navigator.of(
        context,
      ).push(slideRoute(LoanDetailScreen(loanId: loan.id))),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.bolt_rounded, color: accent, size: 42),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${loan.purpose} loan',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Borrowed ${loan.principal.asShortNaira} • ${loan.tenureMonths} months',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: loan.status.label.toUpperCase(),
                color: accent,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Outstanding',
                  value: loan.outstanding.asNaira,
                  color: accent,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Monthly',
                  value: loan.monthlyRepayment.asNaira,
                ),
              ),
              Expanded(
                child: _Metric(label: 'Due', value: loan.dueDate.asDay),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: loan.repaymentProgress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(loan.repaymentProgress * 100).toStringAsFixed(0)}% repaid',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                '${loan.amountRepaid.asShortNaira} of ${loan.totalRepayable.asShortNaira}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'From wallet',
                  onPressed: () =>
                      _repay(context, loan, loan.monthlyRepayment),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GoldButton(
                  label: 'Transfer',
                  height: 54,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PayInScreen(
                        loan: loan,
                        presetAmount: loan.monthlyRepayment,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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

    await app.repayLoan(loan.id, due);
    if (!context.mounted) return;

    final settled = due >= loan.outstanding - 0.01;
    showToast(
      context,
      settled
          ? 'Loan fully repaid. Your credit limit is restored.'
          : '${due.asNaira} repaid successfully.',
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
      ),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}


/// The single most urgent instalment across every open loan.
class _NextDueCard extends StatelessWidget {
  const _NextDueCard({required this.app});
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
              size: 44,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    late
                        ? 'Payment overdue by ${-days} ${days == -1 ? 'day' : 'days'}'
                        : (days == 0
                              ? 'Payment due today'
                              : 'Next payment in $days ${days == 1 ? 'day' : 'days'}'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${next.installment.amount.asNaira} • ${next.loan.purpose} loan • ${next.installment.dueDate.asDay}',
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
    ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.1);
  }
}
