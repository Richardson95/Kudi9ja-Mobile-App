import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/application_banner.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';
import '../dashboard/dashboard_screen.dart';
import '../shell/home_shell.dart';
import 'loan_calculator_screen.dart';
import '../wallet/add_money_screen.dart';
import 'loan_detail_screen.dart';
import 'loan_officers_card.dart';
import 'loan_request_screen.dart';
import 'terms_offer_card.dart';
import '../../data/models/platform_settings.dart';

class LoansScreen extends StatelessWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final active = app.activeLoans;
    final closed = app.loans.where((l) => !l.isOpen).toList();
    final terms = app.lendingTerms;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: app.refreshFromServer,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
          SliverToBoxAdapter(
            child: TabHeader(
              title: 'Borrow',
              subtitle: 'Flat rates from ${terms.rateRange}, over up to '
                  '${terms.maxTenureMonths} months, repaid weekly or monthly',
            ),
          ),
          SliverToBoxAdapter(child: _CreditCard(app: app)),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          if (!settings.lendingEnabled || app.eligibility?.eligible == false) ...[
            SliverToBoxAdapter(
              child: _Notice(
                text: !settings.lendingEnabled
                    ? 'New loans are paused for now. Repayments work as normal.'
                    : (app.eligibility!.reason.isEmpty
                          ? 'You cannot apply just yet.'
                          : app.eligibility!.reason),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: LoanOfficersCard(),
            ),
          ),

          // What happened to the last application, before anything else. A
          // customer waiting on a decision, or holding a refusal they could
          // act on, should not have to go looking for either.
          // Changed terms are answered here, where the loan was asked for.
          if (app.offeredLoanApplications.isNotEmpty) ...[
            for (final offered in app.offeredLoanApplications) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: TermsOfferCard(application: offered),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ] else if (app.pendingLoanApplication != null) ...[
            SliverToBoxAdapter(
              child: ApplicationBanner(application: app.pendingLoanApplication!),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ] else if (app.lastDeclinedApplication != null) ...[
            SliverToBoxAdapter(
              child: ApplicationBanner(application: app.lastDeclinedApplication!),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],

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
                    'Borrow ${terms.minAmount.asNairaFlat} to ${terms.maxAmount.asNairaFlat} over 1 to ${terms.maxTenureMonths} months, and repay weekly or monthly. Interest is flat and set by the tenure — ${PlatformSettings.ratePct(terms.rateFor(1) * 100)} over 1 month, ${PlatformSettings.ratePct(terms.rateFor(3) * 100)} over 3. A ${terms.flatProcessingFee.asNairaFlat} management fee comes out of the amount you receive, and each repayment carries a ${terms.repaymentFeeLabel} transaction fee.',
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
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final terms = app.lendingTerms;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: KCard(
        gradient: AppColors.cardGradient,
        borderColor: AppColors.gold.withValues(alpha: 0.22),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Borrow for your business',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                // A member of a loan group borrows on the group's own terms,
                // and should know that is what the figures here are.
                if (app.groupPricing)
                  StatusPill(
                    label: 'LOAN GROUP TERMS',
                    color: AppColors.info,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // The range, not an offer. There is no score and no limit worked
            // out from savings: a customer asks for what they need and a
            // person reads the application and decides.
            Text(
              '${terms.minAmount.asNairaFlat} – ${terms.maxAmount.asNairaFlat}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tell us what you need and show us the business. '
              'Our team reads every application and decides.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
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
                      'Borrowed ${loan.principal.asNaira} • ${loan.termPhrase}',
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
                  label: loan.frequency.label,
                  value: loan.installmentAmount.asNaira,
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
                '${loan.amountRepaid.asNaira} of ${loan.totalRepayable.asNaira}',
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
                  onPressed: () => _repay(
                    context,
                    loan,
                    loan.nextInstallment?.outstanding ?? loan.installmentAmount,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GoldButton(
                  label: 'Pay',
                  icon: Icons.lock_rounded,
                  height: 54,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddMoneyScreen(
                        loan: loan,
                        presetAmount:
                            loan.nextInstallment?.outstanding ?? loan.installmentAmount,
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

    await app.repayLoan(loan.id, due, pin: pin);
    if (!context.mounted) return;

    final error = app.lastError;
    if (error != null) {
      showToast(context, error, error: true);
      return;
    }
    final settled = due >= loan.outstanding - 0.01;
    showToast(
      context,
      settled
          ? 'Loan fully repaid.'
          : '${due.asNaira} repaid successfully.',
    );
  }
}

/// A line of context the customer should see before trying to borrow.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.goldWash,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.gold),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    ),
  );
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

