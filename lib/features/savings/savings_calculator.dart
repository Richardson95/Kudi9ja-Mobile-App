import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import 'create_plan_screen.dart';
import '../../data/models/platform_settings.dart';

/// A what-if tool: move the amount and the term, watch the 17% respond.
class SavingsCalculatorScreen extends StatefulWidget {
  const SavingsCalculatorScreen({super.key});

  @override
  State<SavingsCalculatorScreen> createState() =>
      _SavingsCalculatorScreenState();
}

class _SavingsCalculatorScreenState extends State<SavingsCalculatorScreen> {
  final _amount = TextEditingController(text: '100,000');
  int _days = 365;

  double get _principal => parseAmount(_amount.text);
  double get _interest => Finance.savingsInterest(_principal, _days);
  double get _total => _principal + _interest;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// Value across the term, for the growth line. The return accrues evenly
  /// by the day, so a straight line through 40 sample points is exact.
  List<FlSpot> get _spots {
    const samples = 40;
    return List.generate(samples + 1, (i) {
      final day = (_days * i / samples).round();
      return FlSpot(
        day.toDouble(),
        _principal + Finance.savingsInterest(_principal, day),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings calculator')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'If I save...',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AmountField(
                            controller: _amount,
                            autofocus: false,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          QuickAmounts(
                            amounts: const [
                              50000,
                              100000,
                              500000,
                              1000000,
                              5000000,
                            ],
                            onPick: (a) => setState(
                              () => _amount.text = a.toInt().asPlain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'FOR HOW LONG',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text(
                          _termLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _days.toDouble().clamp(
                        settings.minLockDays.toDouble(),
                        settings.maxLockDays.toDouble(),
                      ),
                      min: settings.minLockDays.toDouble(),
                      max: settings.maxLockDays.toDouble(),
                      onChanged: (v) => setState(() => _days = v.round()),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '1 month',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text(
                          '5 years',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _Payout(interest: _interest, total: _total, days: _days),
                    const SizedBox(height: AppSpacing.xl),
                    _GrowthChart(spots: _spots, days: _days),
                    const SizedBox(height: AppSpacing.xl),
                    _Comparison(principal: _principal),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.black,
                  border: Border(top: BorderSide(color: AppColors.stroke)),
                ),
                child: GoldButton(
                  label: 'Save this way',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => Navigator.of(
                    context,
                  ).pushReplacement(slideRoute(const CreatePlanScreen())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _termLabel => lockPeriodLabel(_days);
}

class _Payout extends StatelessWidget {
  const _Payout({
    required this.interest,
    required this.total,
    required this.days,
  });

  final double interest;
  final double total;
  final int days;

  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.gold.withValues(alpha: 0.3),
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      children: [
        const Text(
          'You receive today',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            interest.asNaira,
            key: ValueKey(interest),
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.6,
              color: AppColors.success,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        StatusPill(
          label: '${Finance.effectiveYieldPct(days).toStringAsFixed(1)}% OVER THE TERM',
          color: AppColors.success,
          dense: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        const HairLine(),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Value at maturity',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      total.asNaira,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 32, color: AppColors.strokeSoft),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Rate',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '17% p.a.',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.spots, required this.days});
  final List<FlSpot> spots;
  final int days;

  @override
  Widget build(BuildContext context) {
    final maxY = spots.isEmpty
        ? 1.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total value over the term',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY <= 0 ? 1 : maxY * 1.12,
                minX: 0,
                maxX: days.toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY <= 0 ? 1 : maxY) / 3,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.stroke, strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    barWidth: 2.6,
                    gradient: AppColors.goldGradient,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.gold.withValues(alpha: 0.3),
                          AppColors.gold.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              Text(
                lockPeriodShort(days),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.principal});
  final double principal;

  @override
  Widget build(BuildContext context) {
    // Illustrative one-year comparison against typical alternatives.
    const rows = <(String, double, Color)>[
      ('Kudi9ja Lock Save', 0.17, AppColors.gold),
      ('Typical savings account', 0.04, AppColors.textTertiary),
      ('Money kept at home', 0.0, AppColors.textTertiary),
    ];

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'One year on ${principal.asShortNaira}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (label, rate, color) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: rate == 0.17
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: rate == 0.17
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '+${(principal * rate).asNairaFlat}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      value: rate / 0.17,
                      minHeight: 5,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Comparison rates are illustrative. Kudi9ja pays your 17% upfront rather than at maturity.',
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
