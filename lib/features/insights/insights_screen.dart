import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';

/// A plain-language read on where this user's money actually went.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final txns = app.transactions;

    var moneyIn = 0.0;
    var moneyOut = 0.0;
    var interest = 0.0;
    var fees = 0.0;
    for (final t in txns) {
      if (t.kind == TxKind.interestPayout) interest += t.amount;
      if (t.kind == TxKind.fee) fees += t.amount;
      if (t.isCredit) {
        moneyIn += t.amount;
      } else {
        moneyOut += t.amount;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: txns.isEmpty
              ? const EmptyState(
                  icon: Icons.insights_rounded,
                  title: 'Nothing to analyse yet',
                  message:
                      'Once you start saving and spending, your patterns show up here.',
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    _NetWorthCard(app: app)
                        .animate()
                        .fadeIn()
                        .slideY(begin: 0.1),
                    const SizedBox(height: AppSpacing.xl),
                    _Split(moneyIn: moneyIn, moneyOut: moneyOut)
                        .animate(delay: 80.ms)
                        .fadeIn()
                        .slideY(begin: 0.1),
                    const SizedBox(height: AppSpacing.xl),
                    _EarningsCard(interest: interest, fees: fees)
                        .animate(delay: 140.ms)
                        .fadeIn()
                        .slideY(begin: 0.1),
                    const SizedBox(height: AppSpacing.xl),
                    _Breakdown(txns: txns)
                        .animate(delay: 200.ms)
                        .fadeIn()
                        .slideY(begin: 0.1),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.gold.withValues(alpha: 0.24),
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Everything you hold',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          app.netWorth.asNaira,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.3,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Bar(
          label: 'In your wallet',
          value: app.balance,
          total: app.netWorth,
          color: AppColors.gold,
        ),
        const SizedBox(height: AppSpacing.md),
        _Bar(
          label: 'Locked in savings',
          value: app.totalSaved,
          total: app.netWorth,
          color: AppColors.info,
        ),
        if (app.totalOwed > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          const HairLine(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Owed on loans',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '-${app.totalOwed.asNaira}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final double value;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value.asNaira,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: LinearProgressIndicator(
          value: total <= 0 ? 0 : (value / total).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: AppColors.surfaceHigh,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ],
  );
}

class _Split extends StatelessWidget {
  const _Split({required this.moneyIn, required this.moneyOut});
  final double moneyIn;
  final double moneyOut;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.south_west_rounded,
                size: 18,
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Money in',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  moneyIn.asNaira,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.north_east_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Money out',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  moneyOut.asNaira,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.interest, required this.fees});
  final double interest;
  final double fees;

  @override
  Widget build(BuildContext context) {
    final net = interest - fees;

    return KCard(
      gradient: AppColors.cardGradient,
      borderColor: AppColors.success.withValues(alpha: 0.26),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What Kudi9ja has paid you, net of fees',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            net.asNaira,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: net >= 0 ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const HairLine(),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Interest received',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '+${interest.asNaira}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fees and penalties',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '-${fees.asNaira}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Where the money went, by transaction type.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.txns});
  final List<Transaction> txns;

  @override
  Widget build(BuildContext context) {
    final totals = <TxKind, double>{};
    for (final t in txns) {
      if (t.isCredit) continue;
      totals[t.kind] = (totals[t.kind] ?? 0) + t.amount;
    }
    if (totals.isEmpty) return const SizedBox.shrink();

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final grand = entries.fold(0.0, (s, e) => s + e.value);

    const palette = [
      AppColors.gold,
      AppColors.info,
      AppColors.success,
      AppColors.goldSoft,
      AppColors.danger,
      AppColors.textTertiary,
    ];

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where your money went',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 42,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value,
                      color: palette[i % palette.length],
                      radius: 26,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: palette[i % palette.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      entries[i].key.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${(entries[i].value / grand * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    entries[i].value.asShortNaira,
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
