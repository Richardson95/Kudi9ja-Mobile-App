import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/models/thrift.dart';
import '../../../state/app_state.dart';
import '../../../widgets/primitives.dart';
import 'circle_detail_screen.dart';
import 'create_circle_screen.dart';

class ThriftScreen extends StatelessWidget {
  const ThriftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final circles = context.watch<AppState>().circles;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajo Circles')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: circles.isEmpty
              ? _Intro()
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    for (var i = 0; i < circles.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: CircleTile(circle: circles[i])
                            .animate(delay: (60 * i).ms)
                            .fadeIn()
                            .slideY(begin: 0.12),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    GhostButton(
                      label: 'Start another circle',
                      icon: Icons.add_rounded,
                      onPressed: () => Navigator.of(
                        context,
                      ).push(slideRoute(const CreateCircleScreen())),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Center(
          child:
              Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [AppColors.goldWash, Colors.transparent],
                      ),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      size: 40,
                      color: AppColors.gold,
                    ),
                  )
                  .animate()
                  .fadeIn()
                  .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Ajo, done properly',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.15),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'The savings circle you already know — with the record-keeping, the reminders and the payout schedule handled for you.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ).animate(delay: 160.ms).fadeIn(),
        const SizedBox(height: AppSpacing.xxl),
        KCard(
          gradient: AppColors.cardGradient,
          borderColor: AppColors.gold.withValues(alpha: 0.22),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOW A CIRCLE WORKS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final (n, text) in const [
                ('1', 'Everyone puts in the same amount each cycle.'),
                ('2', 'One member collects the whole pot that round.'),
                ('3', 'The turn rotates until everybody has collected.'),
                ('4', 'Kudi9ja tracks who has paid and whose turn is next.'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.goldWash,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.35),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          n,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 13,
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
        ).animate(delay: 220.ms).fadeIn().slideY(begin: 0.12),
        const SizedBox(height: AppSpacing.xl),
        GoldButton(
          label: 'Start a circle',
          icon: Icons.add_rounded,
          onPressed: () => Navigator.of(
            context,
          ).push(slideRoute(const CreateCircleScreen())),
        ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2),
      ],
    );
  }
}

/// Summary row for one circle, used on the hub and the savings tab.
class CircleTile extends StatelessWidget {
  const CircleTile({super.key, required this.circle});
  final ThriftCircle circle;

  @override
  Widget build(BuildContext context) {
    final myTurn = circle.currentRound == circle.myRound;
    final accent = circle.isComplete
        ? AppColors.textTertiary
        : (myTurn ? AppColors.success : AppColors.gold);

    return KCard(
      borderColor: accent.withValues(alpha: 0.28),
      onTap: () => Navigator.of(
        context,
      ).push(slideRoute(CircleDetailScreen(circleId: circle.id))),
      child: Column(
        children: [
          Row(
            children: [
              Text(circle.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      circle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${circle.size} members • ${circle.contribution.asShortNaira} ${circle.frequency.adverb}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: circle.isComplete
                    ? 'COMPLETE'
                    : (myTurn ? 'YOUR TURN' : 'ROUND ${circle.currentRound}'),
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
                  label: 'Pot each round',
                  value: circle.potSize.asShortNaira,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Your turn',
                  value: circle.iHaveCollected
                      ? 'Collected'
                      : 'Round ${circle.myRound}',
                  color: circle.iHaveCollected ? AppColors.success : null,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'This round',
                  value: circle.hasPaidThisRound ? 'Paid' : 'Due',
                  color: circle.hasPaidThisRound
                      ? AppColors.success
                      : AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: circle.progress,
              minHeight: 5,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
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
