import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/platform_settings.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import 'admin_repayments_screen.dart';
import 'admin_shell.dart';
import 'admin_support_screen.dart';

class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final m = app.platformMetrics;
    final book = app.book;
    final waitingOnTeam = app.supportSummary.open;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        if (settings.maintenanceMode) ...[
          _MaintenanceBanner().animate().fadeIn(),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (app.pendingPaymentCount > 0) ...[
          _PayoutCallout(
            deposits: app.pendingDepositCount,
            withdrawals: app.pendingWithdrawalCount,
            value: app.pendingDepositValue + app.pendingWithdrawalValue,
          ).animate().fadeIn(),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (waitingOnTeam > 0) ...[
          KCard(
            borderColor: AppColors.info.withValues(alpha: 0.4),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminSupportScreen()),
            ),
            child: Row(
              children: [
                IconBadge(icon: Icons.support_agent_rounded, color: AppColors.info, size: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '$waitingOnTeam conversation${waitingOnTeam == 1 ? '' : 's'} '
                    'waiting on the team'
                    '${app.supportSummary.overdue > 0 ? ' · ${app.supportSummary.overdue} late' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.info),
              ],
            ),
          ).animate().fadeIn(),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (book != null) ...[
          const AdminSectionLabel('THE LENDING BOOK'),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Still owed on running loans',
                  value: book.outstanding.asNaira,
                  icon: Icons.account_balance_outlined,
                  tint: AppColors.gold,
                  footnote: '${book.activeLoans + book.overdueLoans} running',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminRepaymentsScreen()),
                  ),
                  child: MetricTile(
                    label: 'Repaid by customers',
                    value: book.totalRepaid.asNaira,
                    icon: Icons.payments_outlined,
                    tint: AppColors.success,
                    footnote: '${book.repaidThisMonth.asNaira} this month',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        const AdminSectionLabel('BOOK AT A GLANCE'),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Customers',
                value: '${m.customers}',
                icon: Icons.people_alt_outlined,
                tint: AppColors.info,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricTile(
                label: 'Wallet deposits',
                value: m.deposits.asNaira,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Locked in savings',
                value: m.saved.asNaira,
                icon: Icons.lock_outline_rounded,
                tint: AppColors.info,
                footnote: '${m.activePlans} plans',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricTile(
                label: 'Out on loan',
                value: m.lent.asNaira,
                icon: Icons.request_quote_outlined,
                tint: AppColors.gold,
                // A paper loan whose borrower has not signed up is on nobody's
                // account and so counts nowhere else on this screen. Saying so
                // here is the difference between a quiet omission and a queue.
                footnote: app.waitingLoans.isEmpty
                    ? '${m.activeLoans} loans'
                    : '${m.activeLoans} loans • ${app.waitingLoans.length} waiting',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Interest paid out',
                value: m.interestPaid.asNaira,
                icon: Icons.trending_up_rounded,
                tint: AppColors.success,
                footnote: 'to savers',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricTile(
                label: 'Interest charged',
                value: m.interestCharged.asNaira,
                icon: Icons.percent_rounded,
                tint: AppColors.gold,
                footnote: 'on every loan paid out',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Overdue',
                value: m.overdue.asNaira,
                icon: Icons.warning_amber_rounded,
                tint: m.overdue > 0 ? AppColors.danger : AppColors.textTertiary,
                // Owed on every instalment past its day — not only on loans
                // past their last.
                footnote: book == null
                    ? null
                    : '${book.loansBehind} with missed payments',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricTile(
                label: 'Fees charged',
                value: m.feesCharged.asNaira,
                icon: Icons.receipt_long_outlined,
                tint: AppColors.gold,
                footnote: 'management and transaction',
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xxl),
        const AdminSectionLabel('LIVE RATES'),
        _RatesCard().animate(delay: 100.ms).fadeIn().slideY(begin: 0.08),

        const SizedBox(height: AppSpacing.xxl),
        const AdminSectionLabel('SAVED VS LENT'),
        _BalanceChart(saved: m.saved, lent: m.lent, deposits: m.deposits)
            .animate(delay: 160.ms)
            .fadeIn()
            .slideY(begin: 0.08),

        const SizedBox(height: AppSpacing.xxl),
        const AdminSectionLabel('COLLECTION ACCOUNT'),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.companyAccountNumber,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                settings.companyAccountName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                settings.companyBank,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),
        const AdminSectionLabel('PRODUCT SWITCHES'),
        _SwitchSummary().animate(delay: 220.ms).fadeIn(),

        const SizedBox(height: AppSpacing.xl),
        Text(
          'Figures cover every customer on the server — loans running and '
          'closed, and loans entered from paper.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.5,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }
}

class _MaintenanceBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => KCard(
    borderColor: AppColors.danger.withValues(alpha: 0.4),
    child: Row(
      children: [
        IconBadge(
          icon: Icons.build_rounded,
          color: AppColors.danger,
          size: 42,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maintenance mode is on',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Customers cannot open plans or take loans until you switch it off in Controls.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
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

class _RatesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.gold.withValues(alpha: 0.24),
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
                    'Savings rate',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${settings.savingsRatePct.toStringAsFixed(settings.savingsRatePct % 1 == 0 ? 0 : 1)}%',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: AppColors.gold,
                    ),
                  ),
                  Text(
                    'per annum, paid upfront',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 46, color: AppColors.strokeSoft),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loan rate',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      settings.loanRateRange,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'flat, any tenure',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textTertiary,
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
        _Line(
          'Lock range',
          '${settings.minLockDays} - ${settings.maxLockDays} days',
        ),
        _Line(
          'Loan range',
          '${settings.minLoanAmount.asNairaFlat} - ${settings.maxLoanAmount.asNairaFlat}',
        ),
        _Line(
          'Management fee',
          'Flat ${settings.flatProcessingFee.asNairaFlat} to ${settings.processingFeeThreshold.asNairaFlat}, then ${PlatformSettings.ratePct(settings.feeRatePct)}',
        ),
        _Line(
          'Transaction fee',
          '${PlatformSettings.ratePct(settings.loanRepaymentFeeRate * 100)} of each repayment',
        ),
        _Line(
          'Repayment',
          [
            if (settings.loanWeeklyAllowed) 'Weekly',
            if (settings.loanMonthlyAllowed) 'Monthly',
          ].join(' or '),
        ),
        _Line(
          'Target bonus tiers',
          '${settings.targetShortPct.toStringAsFixed(1)}% / ${settings.targetMediumPct.toStringAsFixed(1)}% / ${settings.targetLongPct.toStringAsFixed(1)}%',
        ),
        _Line(
          'Target Savings minimum',
          '${settings.minTargetMonths} months',
        ),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _BalanceChart extends StatelessWidget {
  const _BalanceChart({
    required this.saved,
    required this.lent,
    required this.deposits,
  });

  final double saved;
  final double lent;
  final double deposits;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, double, Color)>[
      ('Locked in savings', saved, AppColors.info),
      ('Out on loan', lent, AppColors.gold),
      ('Sitting in wallets', deposits, AppColors.success),
    ];
    final total = rows.fold(0.0, (s, r) => s + r.$2);
    if (total <= 0) {
      return KCard(
        child: Text(
          'No balances to chart yet.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
        ),
      );
    }

    return KCard(
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: [
                  for (final (_, value, color) in rows)
                    if (value > 0)
                      PieChartSectionData(
                        value: value,
                        color: color,
                        radius: 24,
                        showTitle: false,
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (label, value, color) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${(value / total * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    value.asNaira,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SwitchSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rows = <(String, bool, IconData)>[
      ('Savings', settings.savingsEnabled, Icons.savings_outlined),
      ('Lending', settings.lendingEnabled, Icons.bolt_rounded),
      ('Ajo circles', settings.thriftEnabled, Icons.groups_outlined),
    ];

    return KCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: HairLine(),
              ),
            Row(
              children: [
                Icon(
                  rows[i].$3,
                  size: 18,
                  color: rows[i].$2 ? AppColors.gold : AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                StatusPill(
                  label: rows[i].$2 ? 'ON' : 'OFF',
                  color: rows[i].$2 ? AppColors.success : AppColors.danger,
                  dense: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}


/// Pulls the eye to withdrawals waiting on a decision.
class _PayoutCallout extends StatelessWidget {
  const _PayoutCallout({
    required this.deposits,
    required this.withdrawals,
    required this.value,
  });

  final int deposits;
  final int withdrawals;
  final double value;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (deposits > 0)
        '$deposits payment${deposits == 1 ? '' : 's'} to confirm',
      if (withdrawals > 0)
        '$withdrawals withdrawal${withdrawals == 1 ? '' : 's'} to approve',
    ];

    return KCard(
      borderColor: AppColors.gold.withValues(alpha: 0.4),
      child: Row(
        children: [
          IconBadge(
            icon: Icons.pending_actions_rounded,
            color: AppColors.gold,
            size: 44,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parts.join(' and '),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${value.asNaira} waiting on you in Payments.',
                  style: TextStyle(
                    fontSize: 12,
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
}
