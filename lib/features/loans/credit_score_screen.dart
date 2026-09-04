import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';

/// Shows exactly how the credit score is built, and what raises it.
class CreditScoreScreen extends StatelessWidget {
  const CreditScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final factors = app.creditFactors;

    return Scaffold(
      appBar: AppBar(title: const Text('Credit score')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _ScoreDial(score: app.creditScore, band: app.creditBand)
                  .animate()
                  .fadeIn()
                  .scale(begin: const Offset(0.9, 0.9)),
              const SizedBox(height: AppSpacing.xl),
              KCard(
                gradient: AppColors.cardGradient,
                borderColor: AppColors.gold.withValues(alpha: 0.22),
                child: Row(
                  children: [
                    const IconBadge(icon: Icons.bolt_rounded, size: 44),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What this unlocks',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${app.eligibleLoanAmount.asNaira} available to borrow',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              const _Label('WHAT MAKES UP YOUR SCORE'),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < factors.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _FactorCard(factor: factors[i])
                      .animate(delay: (70 * i).ms)
                      .fadeIn()
                      .slideY(begin: 0.12),
                ),

              const SizedBox(height: AppSpacing.lg),
              const _Label('HOW TO RAISE IT'),
              const SizedBox(height: AppSpacing.md),
              KCard(
                child: Column(
                  children: [
                    for (final (icon, text) in const [
                      (
                        Icons.savings_outlined,
                        'Open more savings plans and keep money locked — the single biggest lever.',
                      ),
                      (
                        Icons.event_available_outlined,
                        'Repay every instalment on or before its due date.',
                      ),
                      (
                        Icons.speed_rounded,
                        'Settle a loan early. It clears the debt and earns you an interest rebate.',
                      ),
                      (
                        Icons.groups_outlined,
                        'Stay active in an Ajo circle — consistent contributions show reliability.',
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 16, color: AppColors.gold),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Your Kudi9ja score is calculated from your activity on this app alone. It is not a credit bureau score and is refreshed every time you save or repay.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreDial extends StatelessWidget {
  const _ScoreDial({required this.score, required this.band});
  final int score;
  final String band;

  @override
  Widget build(BuildContext context) {
    final pct = ((score - 300) / 550).clamp(0.0, 1.0);
    final color = score >= 680
        ? AppColors.success
        : (score >= 560 ? AppColors.gold : AppColors.danger);

    return KCard(
      gradient: AppColors.cardGradient,
      borderColor: color.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          SizedBox(
            width: 176,
            height: 176,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 176,
                  height: 176,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 11,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 300, end: score.toDouble()),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Text(
                        v.round().toString(),
                        style: const TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                    Text(
                      band,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '300',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              Text(
                'out of 850',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              Text(
                '850',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FactorCard extends StatelessWidget {
  const _FactorCard({required this.factor});
  final CreditFactor factor;

  @override
  Widget build(BuildContext context) {
    final color = factor.negative
        ? AppColors.danger
        : (factor.isMaxed ? AppColors.success : AppColors.gold);

    return KCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factor.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      factor.detail,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                factor.negative
                    ? '${factor.points}'
                    : '+${factor.points}${factor.maxPoints > 0 ? ' / ${factor.maxPoints}' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          if (factor.maxPoints > 0) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: LinearProgressIndicator(
                value: factor.fill,
                minHeight: 5,
                backgroundColor: AppColors.surfaceHigh,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
      color: AppColors.textTertiary,
    ),
  );
}
