import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import '../dashboard/dashboard_screen.dart';
import '../shell/home_shell.dart';
import 'new_plan_sheet.dart';
import 'plan_detail_screen.dart';
import 'savings_calculator.dart';
import 'thrift/thrift_screen.dart';
import '../../data/models/platform_settings.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final active = app.activePlans;
    final closed = app.plans.where((p) => !p.isOpen).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: TabHeader(
              title: 'Savings',
              subtitle: '17% a year, paid the day you start',
              action: GestureDetector(
                onTap: () => showNewPlanSheet(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: AppColors.textOnGold,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _SummaryCard(app: app)),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),

          if (app.plans.isNotEmpty) ...[
            SliverToBoxAdapter(child: _GrowthChart(plans: app.plans)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],

          const SliverToBoxAdapter(child: _CalculatorStrip()),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),

          if (app.autoSavePlans.isNotEmpty) ...[
            SliverToBoxAdapter(child: _AutoSaveSection(app: app)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],

          if (app.circles.isNotEmpty) ...[
            SliverToBoxAdapter(child: _CirclesSection(app: app)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: SectionHeader(
                title: active.isEmpty ? 'Get started' : 'Active plans',
              ),
            ),
          ),

          if (active.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.savings_outlined,
                title: 'No plans yet',
                message:
                    'Lock any amount from ${settings.minSavingsAmount.asShortNaira} for as little as one month and collect your 17% straight away.',
                action: SizedBox(
                  width: 220,
                  child: GoldButton(
                    label: 'Create a plan',
                    onPressed: () => showNewPlanSheet(context),
                  ),
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: active.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: PlanTile(plan: active[i])
                    .animate(delay: (60 * i).ms)
                    .fadeIn()
                    .slideY(begin: 0.12),
              ),
            ),

          if (closed.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: SectionHeader(title: 'Closed plans'),
              ),
            ),
            SliverList.separated(
              itemCount: closed.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: _ClosedTile(plan: closed[i]),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: KCard(
      gradient: AppColors.cardGradient,
      borderColor: AppColors.gold.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total locked away',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 5),
          Text(
            app.hideBalance ? '••••••' : app.totalSaved.asNaira,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Interest received',
                  value: app.totalInterestEarned.asNaira,
                  color: AppColors.success,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.strokeSoft),
              Expanded(
                child: _Stat(
                  label: 'Active plans',
                  value: '${app.activePlans.length}',
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ).animate().fadeIn().slideY(begin: 0.1);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
      ),
      const SizedBox(height: 3),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: color,
          ),
        ),
      ),
    ],
  );
}

/// Cumulative interest received, plan by plan.
class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.plans});
  final List<SavingsPlan> plans;

  @override
  Widget build(BuildContext context) {
    final ordered = [...plans]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    var running = 0.0;
    final spots = <FlSpot>[const FlSpot(0, 0)];
    for (var i = 0; i < ordered.length; i++) {
      running += ordered[i].interestPaid;
      spots.add(FlSpot((i + 1).toDouble(), running));
    }
    final maxY = running <= 0 ? 1.0 : running * 1.25;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Interest earned over time',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  running.asShortNaira,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 130,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 3,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.stroke,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.32,
                      barWidth: 2.6,
                      gradient: AppColors.goldGradient,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.gold,
                          strokeWidth: 2,
                          strokeColor: AppColors.black,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.gold.withValues(alpha: 0.28),
                            AppColors.gold.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.1);
  }
}

class _ClosedTile extends StatelessWidget {
  const _ClosedTile({required this.plan});
  final SavingsPlan plan;

  @override
  Widget build(BuildContext context) {
    final broken = plan.status == SavingsStatus.broken;

    return KCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconBadge(
            icon: broken ? Icons.lock_open_rounded : Icons.check_rounded,
            color: broken ? AppColors.danger : AppColors.textTertiary,
            size: 38,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${plan.status.label} • ${plan.startDate.asDay}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            plan.principal.asShortNaira,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}


/// A shortcut into the what-if calculator.
class _CalculatorStrip extends StatelessWidget {
  const _CalculatorStrip();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: KCard(
      onTap: () => Navigator.of(
        context,
      ).push(slideRoute(const SavingsCalculatorScreen())),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconBadge(icon: Icons.calculate_rounded, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Savings calculator',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'See what any amount earns before you commit',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
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
  ).animate(delay: 140.ms).fadeIn();
}

class _AutoSaveSection extends StatelessWidget {
  const _AutoSaveSection({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final plans = app.autoSavePlans;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Running automatically'),
          for (final p in plans)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: KCard(
                onTap: () => Navigator.of(
                  context,
                ).push(slideRoute(PlanDetailScreen(planId: p.id))),
                child: Row(
                  children: [
                    Text(p.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(p.autoAmount ?? 0).asShortNaira} ${p.autoFrequency?.adverb ?? ''} • next ${p.nextAutoRun?.asDay ?? '-'}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: p.autoEnabled,
                      onChanged: (v) => app.setAutoSaveEnabled(p.id, v),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.1);
  }
}

class _CirclesSection extends StatelessWidget {
  const _CirclesSection({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Ajo circles',
          actionLabel: 'See all',
          onAction: () =>
              Navigator.of(context).push(slideRoute(const ThriftScreen())),
        ),
        for (final c in app.circles.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: CircleTile(circle: c),
          ),
      ],
    ),
  ).animate(delay: 220.ms).fadeIn().slideY(begin: 0.1);
}
