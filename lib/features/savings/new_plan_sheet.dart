import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/platform_settings.dart';
import '../../widgets/primitives.dart';
import 'create_plan_screen.dart';
import 'target_save_screen.dart';
import 'thrift/thrift_screen.dart';

/// The entry point to both savings products, plus group circles.
void showNewPlanSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How do you want to save?',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Two savings plans. One pays you today, the other pays you at the end.',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            if (!settings.savingsEnabled) ...[
              const _Paused(
                message:
                    'Savings is switched off right now. Please check back shortly.',
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            _ProductCard(
              index: 0,
              icon: Icons.lock_rounded,
              tint: AppColors.gold,
              title: 'Fixed Savings',
              tag: 'PAID TODAY',
              blurb:
                  'Lock one amount away for a set term. Your ${settings.savingsRatePct.toStringAsFixed(0)}% lands in your wallet immediately.',
              highlight:
                  'Cannot be broken — the principal stays locked until maturity.',
              highlightIcon: Icons.shield_rounded,
              highlightTint: AppColors.info,
              onTap: () => const CreatePlanScreen(),
            ),
            const SizedBox(height: AppSpacing.md),
            _ProductCard(
              index: 1,
              icon: Icons.calendar_month_rounded,
              tint: AppColors.success,
              title: 'Target Savings',
              tag: 'PAID AT THE END',
              blurb:
                  'Name a total and a term. We work out the daily amount and pay a bonus of up to ${settings.targetLongPct.toStringAsFixed(0)}% on the final day.',
              highlight:
                  'Break it any time — but breaking it forfeits the whole bonus.',
              highlightIcon: Icons.lock_open_rounded,
              highlightTint: AppColors.gold,
              onTap: () => const TargetSaveScreen(),
            ),

            const SizedBox(height: AppSpacing.xl),
            const Text(
              'SAVE AS A GROUP',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            KCard(
              onTap: () {
                Navigator.pop(context);
                Navigator.of(
                  context,
                ).push(slideRoute(const ThriftScreen()));
              },
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const IconBadge(
                    icon: Icons.groups_rounded,
                    color: AppColors.goldSoft,
                    size: 40,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ajo Circle',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Contribute with friends and take turns collecting the pot',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ).animate(delay: 160.ms).fadeIn(),
          ],
        ),
      ),
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.index,
    required this.icon,
    required this.tint,
    required this.title,
    required this.tag,
    required this.blurb,
    required this.highlight,
    required this.highlightIcon,
    required this.highlightTint,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final Color tint;
  final String title;
  final String tag;
  final String blurb;
  final String highlight;
  final IconData highlightIcon;
  final Color highlightTint;
  final Widget Function() onTap;

  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: tint.withValues(alpha: 0.3),
    onTap: () {
      Navigator.pop(context);
      Navigator.of(context).push(slideRoute(onTap()));
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconBadge(icon: icon, color: tint, size: 46),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusPill(label: tag, color: tint, dense: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    blurb,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: highlightTint.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: highlightTint.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            children: [
              Icon(highlightIcon, size: 14, color: highlightTint),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  highlight,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: highlightTint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ).animate(delay: (80 * index).ms).fadeIn().slideY(begin: 0.15);
}

class _Paused extends StatelessWidget {
  const _Paused({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.dangerWash,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.28)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.pause_circle_outline_rounded,
          size: 17,
          color: AppColors.danger,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Emoji options offered when naming a plan or a circle.
const kPlanEmojis = <String>[
  '🎯', '🏠', '🚗', '🎓', '💍', '✈️', '💼', '🏥',
  '📱', '👶', '🎉', '🛠️', '🌍', '💡', '🏦', '🤝',
];

/// A horizontal emoji picker used by plan and circle creation.
class EmojiPicker extends StatelessWidget {
  const EmojiPicker({
    super.key,
    required this.selected,
    required this.onPick,
  });

  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Pick an icon',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kPlanEmojis.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, i) {
            final e = kPlanEmojis[i];
            final on = e == selected;
            return GestureDetector(
              onTap: () => onPick(e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? AppColors.goldWash : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: on ? AppColors.gold : AppColors.stroke,
                    width: on ? 1.4 : 1,
                  ),
                ),
                child: Text(e, style: const TextStyle(fontSize: 22)),
              ),
            );
          },
        ),
      ),
    ],
  );
}
