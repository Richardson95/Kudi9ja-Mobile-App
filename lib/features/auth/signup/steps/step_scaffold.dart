import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/primitives.dart';

/// Shared layout for every signup step: an intro, a scrolling body and a
/// pinned primary action.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.headline,
    required this.subhead,
    required this.children,
    required this.actionLabel,
    this.onAction,
    this.footer,
    this.loading = false,
  });

  final String headline;
  final String subhead;
  final List<Widget> children;
  final String actionLabel;
  final VoidCallback? onAction;
  final Widget? footer;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              Text(
                headline,
                style: Theme.of(context).textTheme.headlineLarge,
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.12),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subhead,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ).animate(delay: 60.ms).fadeIn(duration: 300.ms),
              const SizedBox(height: AppSpacing.xxl),
              ...children.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: c,
                ),
              ),
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
            border: Border(top: BorderSide(color: AppColors.stroke)),
            color: AppColors.black,
          ),
          child: Column(
            children: [
              if (footer != null) ...[
                footer!,
                const SizedBox(height: AppSpacing.md),
              ],
              GoldButton(
                label: actionLabel,
                onPressed: onAction,
                loading: loading,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small informational strip used to explain why data is being requested.
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.text,
    this.icon = Icons.lock_outline_rounded,
    this.color = AppColors.info,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
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
